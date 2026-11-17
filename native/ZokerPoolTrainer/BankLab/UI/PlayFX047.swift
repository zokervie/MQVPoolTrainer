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
            let x = Float(e["x"]?.doubleValue ?? 0), y = Float(e["y"]?.doubleValue ?? 0)
            fx047?.pocketSparks(at: SIMD3(x, 0.02, y))
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
