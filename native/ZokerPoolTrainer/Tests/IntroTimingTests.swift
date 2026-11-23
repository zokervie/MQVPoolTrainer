import Foundation

// 0.57 I1/I3: the intro timeline (one place), the break/drop moments and the music duck. Foundation only (no UIKit).
@main enum IntroTimingTests {
    static var checks = 0
    static func check(_ ok: Bool, _ msg: String) { checks += 1; if !ok { print("FAIL: \(msg)"); exit(1) } }
    static func main() {
        check(IntroTiming.fullSeconds <= 3.2 + 1e-9 && IntroTiming.fullSeconds >= 3.0, "the first-launch intro lasts ≤ 3.2 s")
        check(IntroTiming.strike == 0.95, "the cue meets the ball at 0.95 s")
        check(abs(IntroTiming.dropWall(firstDrop: 1.0) - 1.95) < 1e-9, "ball 8 drops at 1.95 s (strike + 1.000 s)")
        check(IntroTiming.logoStart == 2.15 && IntroTiming.logoEnd == 3.0 && IntroTiming.logoEnd < IntroTiming.fullSeconds, "title window 2.15–3.00 s, then the hand-over")
        // simulated time follows the wall clock 1:1 after the strike (no slow-motion segment)
        check(IntroTiming.simTime(wall: 0.5) == 0 && abs(IntroTiming.simTime(wall: 1.95) - 1.0) < 1e-9 && abs(IntroTiming.simTime(wall: 2.45) - 1.5) < 1e-9, "sim time = wall − 0.95, linear")
        // the cue: still until 0.45, back 12 cm by 0.79, a 80 ms stop, forward and gone at the strike
        check(IntroTiming.pull(0.2) == 0 && IntroTiming.pull(IntroTiming.pullEnd) == 1, "cue pull: 0 before 0.45 s, full at the end of the draw-back")
        check(abs(IntroTiming.holdEnd - IntroTiming.pullEnd - 0.08) < 1e-9 && IntroTiming.pull(IntroTiming.pullEnd + 0.04) == 1, "stop of 80 ms at full draw")
        check(IntroTiming.pull(IntroTiming.strike) == 0 && IntroTiming.pull(0.91) > 0 && IntroTiming.pull(0.91) < 1, "the stroke goes forward to the ball at 0.95 s")
        var last = -1.0; var monotone = true
        for i in 0...34 { let v = IntroTiming.pull(0.45 + Double(i) * 0.01); if i <= 34 && 0.45 + Double(i) * 0.01 <= IntroTiming.pullEnd { if v < last - 1e-12 { monotone = false }; last = v } }
        check(monotone, "the draw-back never goes the wrong way")
        // field of view: −3° punch right after the strike, then back
        check(IntroTiming.fovDelta(0.5) == 0 && abs(IntroTiming.fovDelta(IntroTiming.strike + 0.12) - (-3)) < 0.05 && IntroTiming.fovDelta(IntroTiming.strike + 0.5) == 0, "FOV −3° at the strike, then wide again")
        // music duck: −6 dB in 80 ms after the strike, held ~1.2 s, back over 450 ms
        let g6 = pow(10.0, -6.0 / 20)
        check(IntroTiming.duckGain(0.9) == 1 && IntroTiming.duckGain(IntroTiming.strike) == 1, "no duck before the strike")
        check(abs(IntroTiming.duckGain(IntroTiming.strike + 0.08) - g6) < 1e-6, "−6 dB after 80 ms")
        check(abs(IntroTiming.duckGain(IntroTiming.strike + 0.08 + 1.2 - 0.01) - g6) < 1e-6, "held for about 1.2 s")
        check(IntroTiming.duckGain(IntroTiming.strike + 0.08 + 1.2 + 0.225) > g6 && IntroTiming.duckGain(IntroTiming.strike + 0.08 + 1.2 + 0.225) < 1, "recovering")
        check(abs(IntroTiming.duckGain(IntroTiming.strike + 0.08 + 1.2 + 0.45) - 1) < 1e-9, "back to full after 450 ms")
        // dust and sparks stay small (≤ 60 particles at once)
        check(IntroTiming.dustCount + IntroTiming.pocketSparkCount <= 60 && IntroTiming.dustCount <= 50 && IntroTiming.pocketSparkCount <= 10, "particle budget")
        print("PASS IntroTiming: \(checks) checks")
    }
}
