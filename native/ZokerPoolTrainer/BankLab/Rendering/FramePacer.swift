import SceneKit
import simd

/// 0.39 (owner: balls still judder, "không trôi"). Root cause: the physics/controller tick runs on our CADisplayLink on the
/// main thread while SCNView renders from its own display link on its render thread. Both fire once per refresh, but
/// their order is not fixed, so a rendered frame sometimes shows two physics steps and sometimes none — visible
/// judder at a constant frame rate. Earlier fixes (targetTimestamp, 60 Hz cap, quality drops) could not cure that.
///
/// Fix: the tick still advances physics to the frame's target time, but only *records* each moving ball's pose with
/// that timestamp. SceneKit asks this pacer, on its render thread right before drawing, to place every paced node at
/// the render time by interpolating the last two samples (≤ 1 frame of extrapolation if the tick is late). Motion is
/// then sampled by the renderer's own clock, so every displayed frame advances by exactly its share of time.
final class FramePacer: NSObject, SCNSceneRendererDelegate {
    private struct Pose { var time: Double; var position: SIMD3<Float>; var orientation: simd_quatf; var shadow: SIMD3<Float> }
    private struct Track { let node: SCNNode; let shadow: SCNNode?; var previous: Pose; var current: Pose }
    private let lock = NSLock()
    private var tracks: [Int: Track] = [:]
    /// Owner switch in Tuỳ chỉnh → Hình ảnh ("Đồng bộ khung hình"). Read on the main thread only.
    static var enabled: Bool { Tuning.flag("tuneFramePacing039", true) }

    /// Main thread: record the pose the solver reached for `time` (CADisplayLink.targetTimestamp, CACurrentMediaTime base).
    func push(id: Int, node: SCNNode, shadow: SCNNode?, time: Double, position: SIMD3<Float>, orientation: simd_quatf, shadowAt: SIMD3<Float>) {
        let pose = Pose(time: time, position: position, orientation: orientation, shadow: shadowAt)
        lock.lock(); defer { lock.unlock() }
        if var track = tracks[id], track.node === node, time > track.current.time, time - track.current.time < 0.25 {
            track.previous = track.current; track.current = pose; tracks[id] = track
        } else {
            tracks[id] = Track(node: node, shadow: shadow, previous: pose, current: pose)
        }
    }
    /// Main thread: stop pacing one ball (sunk, removed) or all of them (the scene is driven directly again).
    func remove(_ id: Int) { lock.lock(); tracks.removeValue(forKey: id); lock.unlock() }
    func clear() { lock.lock(); tracks.removeAll(keepingCapacity: true); lock.unlock() }
    var isActive: Bool { lock.lock(); defer { lock.unlock() }; return !tracks.isEmpty }

    /// Pure interpolation, shared with tests/QA: fraction of the way from the previous to the current sample.
    static func fraction(render: Double, previous: Double, current: Double) -> Float {
        let span = current - previous
        guard span > 1e-6 else { return 1 }
        let raw = (render - previous) / span
        // 0.39b: samples are stamped with the vsync they are meant for (targetTimestamp); the render callback knows its
        // vsync only up to its own wake-up latency (±1–2 ms). Snap to the vsync grid when close, so every displayed
        // frame advances by exactly one sample — the newest one, or one frame of extrapolation when the main-thread
        // tick is late (that late tick was the "two steps / no step" judder). Off-grid (frame-rate change): continuous.
        let snapped = raw.rounded()
        let value = abs(raw - snapped) < 0.35 ? snapped : raw
        return Float(max(0, min(2, value)))
    }
    /// Seconds from the render callback to the vsync it renders for (one frame at the active rate). Main thread sets it.
    private var leadValue: Double = 1.0 / 60.0
    var lead: Double {
        get { lock.lock(); defer { lock.unlock() }; return leadValue }
        set { lock.lock(); leadValue = newValue; lock.unlock() }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        guard !tracks.isEmpty else { return }
        let target = time + leadValue
        for (_, track) in tracks {
            let f = Self.fraction(render: target, previous: track.previous.time, current: track.current.time)
            let a = track.previous, b = track.current
            let p = a.position + (b.position - a.position) * f
            // A paced ball never leaves the cloth plane by extrapolation (jumps keep their recorded height curve).
            track.node.simdPosition = SIMD3<Float>(p.x, f > 1 ? max(b.position.y, min(a.position.y, b.position.y)) : p.y, p.z)
            track.node.simdOrientation = f <= 1 ? simd_slerp(a.orientation, b.orientation, f) : b.orientation
            if let shadow = track.shadow { shadow.simdPosition = a.shadow + (b.shadow - a.shadow) * f }
        }
    }
}
