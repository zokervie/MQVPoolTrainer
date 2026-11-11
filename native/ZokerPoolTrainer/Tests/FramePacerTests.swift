import SceneKit
import simd

// Only the preference provider is stubbed; the real production FramePacer and
// real SCNNodes are compiled into this standalone macOS test executable.
enum Tuning { static func flag(_ key: String, _ fallback: Bool) -> Bool { fallback } }

@main struct FramePacerTests {
    struct Failure: Error { let message: String }
    static var checks = 0
    static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message: message) }
        checks += 1
    }
    static func near(_ value: Float, _ expected: Float, _ message: String) throws {
        try check(abs(value - expected) < 0.00005, "\(message): \(value) != \(expected)")
    }
    static func push(_ pacer: FramePacer, _ node: SCNNode, _ shadow: SCNNode,
                     time: Double, x: Float, height: Float = 0.03, angle: Float = 0) {
        pacer.push(id: 0, node: node, shadow: shadow, time: time,
                   position: SIMD3(x, height, 0),
                   orientation: simd_quatf(angle: angle, axis: SIMD3(0, 1, 0)),
                   shadowAt: SIMD3(x, 0.001, 0))
    }
    static func main() throws {
        // The old 0.35-wide rounding window returned 0 here, making a plateau.
        try near(FramePacer.fraction(render: 0.1, previous: 0, current: 1), 0.1, "no phase quantization")
        try near(FramePacer.fraction(render: 1.8, previous: 0, current: 1), 1, "no extrapolation")
        try near(FramePacer.fraction(render: -1, previous: 0, current: 1), 0, "before history")
        // Alternate main-before-render/main-after-render, with jittered callback
        // phase. Both 60 and 120 Hz must trace the same constant-speed trajectory.
        for fps in [60.0, 120.0] {
            let h = 1 / fps, base = 1000.0
            let pacer = FramePacer(), node = SCNNode(), shadow = SCNNode()
            pacer.interval = h; pacer.resetDiagnostics()
            push(pacer, node, shadow, time: base, x: 0)
            push(pacer, node, shadow, time: base + h, x: Float(h))
            for i in 1...240 {
                let before = i % 2 == 0
                let producer = base + Double(i + 1) * h
                if before { push(pacer, node, shadow, time: producer, x: Float(producer - base)) }
                let phase = Double((i % 5) - 2) * h * 0.04
                let render = base + Double(i) * h + phase
                pacer.render(at: render)
                let expected = Float(max(0, render - h - base))
                try near(node.simdPosition.x, expected, "\(fps) Hz callback order")
                try near(shadow.simdPosition.x, expected, "contact shadow stays with ball")
                if !before { push(pacer, node, shadow, time: producer, x: Float(producer - base)) }
            }
            try check(pacer.diagnostics.starvedFrames == 0, "no starvation under either callback order")
            try check(pacer.diagnostics.intervals.count == 239, "measures render callbacks")
            pacer.endDiagnostics()
            pacer.render(at: base + 10)
            try check(pacer.diagnostics.sampledFrames == 240, "idle cannot contaminate shot report")
        }
        let p = FramePacer(), n = SCNNode(), s = SCNNode()
        p.interval = 0.02; p.resetDiagnostics()
        push(p, n, s, time: 10, x: 0, height: 0.03, angle: 0)
        push(p, n, s, time: 10.02, x: 1, height: 0.13, angle: 1)
        push(p, n, s, time: 10.04, x: 0, height: 0.03, angle: 2)
        p.render(at: 10.05)
        try near(n.simdPosition.x, 0.5, "interpolate rebound without predicting through rail")
        try near(n.simdPosition.y, 0.08, "interpolate jump height")
        try near(abs(simd_dot(n.simdOrientation.vector, simd_quatf(angle: 1.5, axis: SIMD3(0, 1, 0)).vector)), 1, "orientation follows position clock")
        p.render(at: 10.08)
        try near(n.simdPosition.x, 0, "producer stall holds at known collision endpoint")
        try check(p.diagnostics.starvedFrames == 1, "producer stall is observable")
        push(p, n, s, time: 10.04, x: 99) // duplicate cannot replace known state
        p.render(at: 10.06)
        try near(n.simdPosition.x, 0, "duplicate sample ignored")
        p.remove(0); n.simdPosition.x = 7; p.render(at: 11)
        try near(n.simdPosition.x, 7, "removed node no longer written")
        push(p, n, s, time: 12, x: 3)
        p.clear(); n.simdPosition.x = 9; p.render(at: 12.1)
        try near(n.simdPosition.x, 9, "seek/reset clears old tracks")
        push(p, n, s, time: 13, x: 3)
        push(p, n, s, time: 14, x: 4); p.render(at: 14)
        try near(n.simdPosition.x, 4, "long gap resets history")
        push(p, n, s, time: 12, x: 2); p.render(at: 12)
        try near(n.simdPosition.x, 2, "backward seek resets history")
        let replacement = SCNNode()
        push(p, replacement, s, time: 12.02, x: 6); p.render(at: 12.02)
        try near(replacement.simdPosition.x, 6, "new node identity resets history")
        // Fast spin: 229° between samples. Shortest-path slerp would show -65.5° at the midpoint (backwards).
        let axis = SIMD3<Float>(0, 1, 0), qa = simd_quatf(angle: 0, axis: axis), qb = simd_quatf(angle: 4.0, axis: axis)
        let mid = FramePacer.orientation(qa, qb, spin: axis * 200, span: 0.02, fraction: 0.5)
        try near(abs(simd_dot(mid.vector, simd_quatf(angle: 2.0, axis: axis).vector)), 1, "spin-aware midpoint follows angular velocity")
        let end = FramePacer.orientation(qa, qb, spin: axis * 200, span: 0.02, fraction: 1)
        try near(abs(simd_dot(end.vector, qb.vector)), 1, "spin-aware end-point is the recorded sample")
        // Velocity that does not explain the samples (slow-motion replay / collision): plain slerp, no overshoot.
        let slow = FramePacer.orientation(qa, simd_quatf(angle: 0.2, axis: axis), spin: axis * 200, span: 0.02, fraction: 0.5)
        try near(abs(simd_dot(slow.vector, simd_quatf(angle: 0.1, axis: axis).vector)), 1, "inconsistent spin falls back to slerp")
        print("PASS FramePacer: \(checks) checks; real SCNNodes, continuous time, 60/120 Hz callback ordering, rebound, jump, rotation, stalls, reset")
    }
}
