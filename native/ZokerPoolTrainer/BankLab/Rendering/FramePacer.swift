import SceneKit
import QuartzCore
import simd

/// Presentation only; the native fixed-step solver remains authoritative.
/// Consume a short history one refresh behind SceneKit's clock. Either callback
/// ordering then gives the same position. Never snap time to a guessed vsync or
/// extrapolate through an unknown collision. A real producer stall holds at the
/// last known pose and is counted rather than hidden by a fabricated trajectory.
final class FramePacer: NSObject, SCNSceneRendererDelegate {
    private struct Pose {
        var time: Double
        var position: SIMD3<Float>
        var orientation: simd_quatf
        var shadow: SIMD3<Float>
        /// Angular velocity in scene axes (rad/s), left-multiplied like the solver's rotate().
        var spin: SIMD3<Float>
    }
    private struct Track {
        let node: SCNNode
        let shadow: SCNNode?
        var samples: [Pose]
    }
    private struct DrawPose {
        let node: SCNNode
        let shadow: SCNNode?
        let position: SIMD3<Float>
        let orientation: simd_quatf
        let shadowAt: SIMD3<Float>
    }
    struct Diagnostics {
        var intervals: [Double] = []
        var sampledFrames = 0
        var starvedFrames = 0
        var maximumSampleAge = 0.0
        /// SceneKit's `updateAtTime` minus CACurrentMediaTime() at the callback (s): Apple documents only "current
        /// system time"; this tells on the device whether it is a timestamp, a target time or "now".
        var clockOffsets: [Double] = []
        var lastRenderTime: Double?
        var interval = 1.0 / 60.0
    }
    private let lock = NSLock()
    private var tracks: [Int: Track] = [:]
    private var intervalValue = 1.0 / 60.0
    private var measured = Diagnostics()
    private var measuring = false
    static var enabled: Bool { Tuning.flag("tuneFramePacing039", true) }

    /// Main thread: targetTimestamp poses. Duplicates must not destroy history.
    func push(id: Int, node: SCNNode, shadow: SCNNode?, time: Double, position: SIMD3<Float>, orientation: simd_quatf, shadowAt: SIMD3<Float>, spin: SIMD3<Float> = .zero) {
        guard time.isFinite else { return }
        let pose = Pose(time: time, position: position, orientation: orientation, shadow: shadowAt, spin: spin)
        lock.lock(); defer { lock.unlock() }
        if var track = tracks[id], track.node === node, let last = track.samples.last,
           time >= last.time, time - last.time < 0.25 {
            guard time > last.time else { return }
            track.samples.append(pose)
            if track.samples.count > 8 { track.samples.removeFirst(track.samples.count - 8) }
            tracks[id] = track
        } else {
            tracks[id] = Track(node: node, shadow: shadow, samples: [pose])
        }
    }
    func remove(_ id: Int) { lock.lock(); tracks.removeValue(forKey: id); lock.unlock() }
    func clear() { lock.lock(); tracks.removeAll(keepingCapacity: true); measuring = false; lock.unlock() }
    var isActive: Bool { lock.lock(); defer { lock.unlock() }; return !tracks.isEmpty }

    static func fraction(render: Double, previous: Double, current: Double) -> Float {
        let span = current - previous
        guard span > 1e-6 else { return 1 }
        return Float(max(0, min(1, (render - previous) / span)))
    }
    /// 0.39c: one orientation rule for live and replay. A fast ball turns more than 180° between two samples
    /// (5 m/s rolling = 167° per 60 Hz frame, a break = 270°), so a shortest-path slerp runs the wrong way and any
    /// jitter in the sampling phase shows as the spots/stripes wobbling. Follow the recorded angular velocity and
    /// spread the small end-point residual; fall back to slerp when the velocity does not explain the two samples
    /// (slow-motion replay, a collision inside the interval).
    static func orientation(_ a: simd_quatf, _ b: simd_quatf, spin: SIMD3<Float>, span: Float, fraction f: Float) -> simd_quatf {
        let mag = simd_length(spin)
        guard span > 0, mag * span > 0.2 else { return simd_slerp(a, b, f) }
        let axis = spin / mag, full = mag * span
        let residual = simd_normalize(b * (simd_quatf(angle: full, axis: axis) * a).inverse)
        guard 2 * acos(min(1, abs(residual.real))) < 0.6 else { return simd_slerp(a, b, f) }
        let identity = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        return simd_normalize(simd_slerp(identity, residual, f) * simd_quatf(angle: full * f, axis: axis) * a)
    }
    /// Fixed presentation delay for this motion segment (normally one refresh).
    var interval: Double {
        get { lock.lock(); defer { lock.unlock() }; return intervalValue }
        set {
            guard newValue.isFinite, newValue > 0, newValue <= 0.1 else { return }
            lock.lock(); intervalValue = newValue; lock.unlock()
        }
    }
    func resetDiagnostics() { lock.lock(); measured = Diagnostics(); measuring = true; lock.unlock() }
    func endDiagnostics() { lock.lock(); measuring = false; lock.unlock() }
    var diagnostics: Diagnostics { lock.lock(); defer { lock.unlock() }; return measured }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) { render(at: time) }

    /// Shared with native tests using real SCNNodes (no mock interpolation).
    func render(at time: Double) {
        guard time.isFinite else { return }
        lock.lock()
        guard !tracks.isEmpty else { lock.unlock(); return }
        let target = time - intervalValue
        var draw: [DrawPose] = []
        var starved = false
        var age = 0.0
        for (_, track) in tracks {
            guard let first = track.samples.first, let last = track.samples.last else { continue }
            // Newest-two-only interpolation fails when the producer gets ahead.
            let upper = track.samples.firstIndex { $0.time >= target }
            let b = upper.map { track.samples[$0] } ?? last
            let a = upper.map { track.samples[max(0, $0 - 1)] } ?? last
            let f = Self.fraction(render: target, previous: a.time, current: b.time)
            draw.append(DrawPose(node: track.node, shadow: track.shadow,
                                 position: a.position + (b.position - a.position) * f,
                                 orientation: Self.orientation(a.orientation, b.orientation, spin: (a.spin + b.spin) * 0.5, span: Float(b.time - a.time), fraction: f),
                                 shadowAt: a.shadow + (b.shadow - a.shadow) * f))
            if target > last.time + 1e-6 && target >= first.time { starved = true }
            age = max(age, max(0, time - last.time))
        }
        if measuring {
            if let last = measured.lastRenderTime, time > last {
                measured.intervals.append(time - last)
                if measured.intervals.count > 3600 { measured.intervals.removeFirst(measured.intervals.count - 3600) }
            }
            measured.lastRenderTime = time
            if measured.clockOffsets.count < 600 { measured.clockOffsets.append(time - CACurrentMediaTime()) }
            measured.interval = intervalValue
            measured.sampledFrames += 1
            if starved { measured.starvedFrames += 1 }
            measured.maximumSampleAge = max(measured.maximumSampleAge, age)
        }
        // Keep removal/reset serialized with these writes. Once remove/clear
        // returns, an in-flight callback must never restore an obsolete pose.
        for pose in draw {
            pose.node.simdPosition = pose.position
            pose.node.simdOrientation = pose.orientation
            pose.shadow?.simdPosition = pose.shadowAt
        }
        lock.unlock()
    }
}
