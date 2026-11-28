import UIKit
import SceneKit

/// 0.47 M4 — Hiệu ứng khi chơi, reusing ShotFX of the 0.44.1 intro (Intro0441.swift): gold sparks at the pocket mouth
/// when a ball drops, a haptic tap scaled by the stroke power, and a very light camera shake on a hard break.
/// Switch: Tuỳ chỉnh → Hiển thị (Prefs.playFX, default on) and FeatureFlags.playFX. Reduce Motion: no shake.
/// Budget (brief): "Cảnh 3D" p95 +0,5 ms at most. Sparks are one short particle burst per pocketed ball (created only
/// on that event, removed after 1,4 s); the shake is a Core Animation transform on the view's layer (no per-frame
/// scene work); streaks / flash / chalk of the intro stay off in play. Perf QA: NOT RUN (Simulator broken).
extension TrainingController {
    /// QA launches keep the scene unchanged (screenshot probes) unless `--play-fx-qa`.
    var playFXOn: Bool { FeatureFlags.playFX && Tuning.flag(Prefs.playFX, true) && (!QA.anyFlag || QA.has("--play-fx-qa")) }
    /// Strong break threshold for the camera shake (m/s). GIẢ ĐỊNH (design): a break stroke is ~6–9 m/s.
    static let shakeSpeed = 6.0
    private var fx047: ShotFX? {
        if let fx = playFX { return fx }
        guard let scene = table?.scene, let host = scn else { return nil }
        var o = ShotFXOptions(); o.flash = false; o.shockRing = false; o.chalk = false; o.streaks = false; o.shake = false; o.pocketSparks = true
        let fx = ShotFX(scene: scene, hostView: host, options: o); playFX = fx; return fx
    }
    /// Live events of the running shot (TC+ShotLoop, right after the impact sounds).
    func playFXEvents(_ events: [[String: NSNumber]]) {
        guard playFXOn, replayIndex == nil else { return }
        for e in events where e["kind"]?.intValue == 2 && (e["b"]?.intValue ?? -1) >= 0 {
            let x = Float(e["x"]?.doubleValue ?? 0), y = Float(e["y"]?.doubleValue ?? 0), id = e["b"]?.intValue ?? 0
            // 0.59 (owner 28/11): a puff of coloured smoke in the ball's colour rises from the pocket (was gold sparks
            // that read as confetti). Cue ball / 8 ball: pale smoke. One short burst per ball, ≤ 14 soft particles.
            if fx047 != nil, let scene = table?.scene { PocketSmoke059.puff(in: scene, at: SIMD3(x, 0.01, y), color: PocketSmoke059.color(ball: id)) }
        }
    }
    /// The strike: haptic by power (was a fixed light tap), shake on a hard break.
    func strikeFX047(_ speed: Double) {
        guard playFXOn else { feedback.impactOccurred(); return }
        let k = max(0, min(1, speed / max(1, BL_POWER_MAX_SPEED * Tuning.maxPower)))
        feedback.impactOccurred(intensity: CGFloat(0.3 + 0.7 * k))
        if speed >= Self.shakeSpeed, !UIAccessibility.isReduceMotionEnabled, let layer = scn?.layer {
            let a = CAKeyframeAnimation(keyPath: "transform.translation")
            let amp = 2.5 * min(1.5, speed / Self.shakeSpeed)
            a.values = [CGSize.zero, CGSize(width: amp, height: -amp * 0.6), CGSize(width: -amp * 0.7, height: amp * 0.4),
                        CGSize(width: amp * 0.35, height: -amp * 0.2), CGSize.zero].map { NSValue(cgSize: $0) }
            a.duration = 0.24; a.isAdditive = true
            layer.add(a, forKey: "breakShake")
        }
    }
}

/// 0.59 (owner 28/11): "bi rơi lỗ hiện lên khói màu thay vì tung giấy". Soft round sprite (drawn once), additive-free
/// alpha blend so it reads as smoke, grows while it rises and fades out in ~1,3 s. Budget: one burst per pocketed ball.
enum PocketSmoke059 {
    static let sprite: UIImage = {
        let size = CGSize(width: 64, height: 64)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(white: 1, alpha: 0.9).cgColor, UIColor(white: 1, alpha: 0.35).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.45, 1]) {
                ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0, endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
            }
        }
    }()
    static func color(ball id: Int) -> UIColor {
        if id == 0 { return UIColor(white: 0.95, alpha: 1) }
        if id == 8 { return UIColor(white: 0.55, alpha: 1) }
        let c = TableScene.colors
        return c[min(c.count - 1, max(1, id <= 8 ? id : id - 8))]
    }
    static func puff(in scene: SCNScene, at p: SIMD3<Float>, color: UIColor) {
        let s = SCNParticleSystem()
        s.particleImage = sprite; s.birthRate = 110; s.emissionDuration = 0.12; s.loops = false   // ≈ 13 puffs
        s.particleLifeSpan = 1.1; s.particleLifeSpanVariation = 0.35
        s.particleSize = 0.035; s.particleSizeVariation = 0.015
        s.particleColor = color.withAlphaComponent(0.55); s.particleColorVariation = SCNVector4(0, 0, 0.08, 0)
        s.blendMode = .alpha; s.isLightingEnabled = false; s.sortingMode = .distance
        s.particleVelocity = 0.32; s.particleVelocityVariation = 0.15; s.spreadingAngle = 28
        s.emittingDirection = SCNVector3(0, 1, 0); s.acceleration = SCNVector3(0, 0.12, 0)   // drifts up, slowing
        s.dampingFactor = 1.6; s.particleAngularVelocity = 40; s.particleAngularVelocityVariation = 60
        s.emitterShape = SCNSphere(radius: 0.03)
        let grow = CAKeyframeAnimation(); grow.values = [0.6, 1.6, 2.4]; grow.keyTimes = [0, 0.5, 1]; grow.duration = 1
        let fade = CAKeyframeAnimation(); fade.values = [0.0, 0.85, 0.0]; fade.keyTimes = [0, 0.15, 1]; fade.duration = 1
        s.propertyControllers = [.size: SCNParticlePropertyController(animation: grow), .opacity: SCNParticlePropertyController(animation: fade)]
        let n = SCNNode(); n.simdPosition = p; n.renderingOrder = 2500; scene.rootNode.addChildNode(n); n.addParticleSystem(s)
        n.runAction(.sequence([.wait(duration: 1.8), .removeFromParentNode()]))
    }
}
