import Foundation
import CoreHaptics

/// 0.57 I2 — intro haptics through CoreHaptics: 0.87 s cue stops (soft 0.25) · 0.95 s tip meets the ball (sharp 0.85 / strong 0.9) · 2–3 small taps at the
/// real ball–ball impacts of the break (events of the intro's own BLWorld, never hard-coded times) · 1.95 s ball 8 drops (dull 0.25 / 0.65).
/// A device without haptics, or the player's "in-play effects" switch off, makes every call a silent no-op; skipping the intro stops it at once.
final class IntroHaptics {
    private var engine: CHHapticEngine?
    private(set) var fired: [(label: String, intensity: Float, sharpness: Float)] = []   // for the QA probe
    private var collisionTaps = 0, lastCollision = -1.0
    let enabled: Bool
    init() {
        let allowed = UserDefaults.standard.object(forKey: Prefs.playFX) as? Bool ?? true
        enabled = allowed && CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard enabled else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.stoppedHandler = { _ in }; engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? engine?.start()
    }
    func tap(_ label: String, intensity: Float, sharpness: Float) {
        fired.append((label, intensity, sharpness))
        guard enabled, let engine = engine else { return }
        let e = CHHapticEvent(eventType: .hapticTransient, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                                                                         CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)], relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [e], parameters: []), let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
    func cueStops() { tap("stop", intensity: 0.25, sharpness: 0.25) }
    func tipMeetsBall() { tap("strike", intensity: 0.9, sharpness: 0.85) }
    func pocketDrop() { tap("drop", intensity: 0.65, sharpness: 0.25) }
    /// A real ball–ball impact (`time` in solver seconds after the strike, `impact` m/s): at most 3 small taps, 0.1 s apart.
    func ballImpact(time: Double, impact: Double) {
        guard collisionTaps < 3, time - lastCollision >= 0.1, impact > 0.3 else { return }
        collisionTaps += 1; lastCollision = time
        tap("click", intensity: Float(min(0.55, 0.25 + impact * 0.04)), sharpness: 0.5)
    }
    func stop() { engine?.stop(completionHandler: nil) }
}
