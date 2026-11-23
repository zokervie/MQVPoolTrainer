import Foundation

/// 0.57 I1/I3 — the first-launch intro timeline in ONE place (seconds on the wall clock). Pure Foundation so Tests/IntroTimingTests.swift can check it.
enum IntroTiming {
    static let fullSeconds = 3.2        // hand-over to the Lobby / first set-up at 3.0–3.2
    static let slideStart = 0.45        // the camera slides 8 cm sideways 0.45 → 0.95
    static let pullEnd = 0.79           // cue drawn back 12 cm …
    static let holdEnd = 0.87           // … stopped for 80 ms …
    static let strike = 0.95            // … and the tip meets the ball
    static let logoStart = 2.15, logoEnd = 3.0
    static let dustCount = 40, pocketSparkCount = 10   // total particles at once ≤ 60
    static let duckDown = 0.08, duckHold = 1.2, duckUp = 0.45
    static let duckLevel = 0.5011872336272722          // −6 dB
    static func dropWall(firstDrop: Double) -> Double { strike + firstDrop }
    /// Solver time for a wall-clock time: the break runs in real time (the old 0.5 s slow-motion is gone).
    static func simTime(wall t: Double) -> Double { max(0, t - strike) }
    /// Cue draw-back 0…1 (1 = 12 cm): still until 0.45, eased back to 0.79, held to 0.87, stroke forward to the ball at 0.95.
    static func pull(_ t: Double) -> Double {
        if t < slideStart { return 0 }
        if t < pullEnd { let k = (t - slideStart) / (pullEnd - slideStart); return k * k * (3 - 2 * k) }
        if t < holdEnd { return 1 }
        if t < strike { let k = (t - holdEnd) / (strike - holdEnd); return 1 - k * k }
        return 0
    }
    /// Field-of-view change in degrees: −3° (a punch-in) over the first 0.12 s after the strike, then back out by 0.4 s.
    static func fovDelta(_ t: Double) -> Double {
        let s = t - strike
        if s <= 0 || s >= 0.4 { return 0 }
        if s < 0.12 { return -3 * (s / 0.12) }
        return -3 * (1 - (s - 0.12) / 0.28)
    }
    /// Gain of the music / bed layers: 1 → −6 dB in 80 ms after the strike, held, back over 450 ms.
    static func duckGain(_ t: Double) -> Double {
        let s = t - strike
        if s <= 0 { return 1 }
        if s < duckDown { return 1 + (duckLevel - 1) * (s / duckDown) }
        if s < duckDown + duckHold { return duckLevel }
        if s < duckDown + duckHold + duckUp { return duckLevel + (1 - duckLevel) * ((s - duckDown - duckHold) / duckUp) }
        return 1
    }
}
