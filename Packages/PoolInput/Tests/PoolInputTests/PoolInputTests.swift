import XCTest
@testable import PoolInput

final class StrokeAnalyzerTests: XCTestCase {

    /// Tạo cú vuốt: lùi `back` mm với tốc độ vb, rồi đẩy với tốc độ vf, mẫu 240 Hz.
    func stroke(back: Double, vb: Double, vf: Double, lateral: Double = 0) -> [TouchSample] {
        var out: [TouchSample] = []
        let dt = 1.0 / 240
        var t = 0.0, y = 0.0, x = 0.0
        out.append(TouchSample(time: t, position: SIMD2(x, y)))
        while y < back { t += dt; y += vb * dt; out.append(TouchSample(time: t, position: SIMD2(x, y))) }
        while y > -20 { t += dt; y -= vf * dt; x += lateral * dt; out.append(TouchSample(time: t, position: SIMD2(x, y))) }
        return out
    }

    func run(_ samples: [TouchSample]) -> StrokeOutcome {
        var a = StrokeAnalyzer()
        a.begin(samples[0])
        for s in samples.dropFirst() {
            let r = a.add(s)
            if case .struck = r { return r }
        }
        return a.end()
    }

    func testSpeedMeasuredAtContactLine() {
        guard case .struck(let r) = run(stroke(back: 30, vb: 200, vf: 600)) else { return XCTFail() }
        XCTAssertEqual(r.fingerSpeed, 600, accuracy: 1)
        XCTAssertEqual(r.lateralRatio, 0, accuracy: 1e-9)
    }

    func testSameStrokeSameResult() {
        let s = stroke(back: 25, vb: 150, vf: 420, lateral: 30)
        XCTAssertEqual(run(s), run(s))
    }

    func testShortBackswingIsIgnored() {
        // Lùi 5 mm < 10 mm tối thiểu → không tính là ra cơ, nhấc tay = ngưng.
        XCTAssertEqual(run(stroke(back: 5, vb: 200, vf: 600)), .cancelled)
    }

    func testLateralDeviationDetected() {
        guard case .struck(let r) = run(stroke(back: 30, vb: 200, vf: 500, lateral: 50)) else { return XCTFail() }
        XCTAssertEqual(abs(r.lateralRatio), 0.1, accuracy: 0.01)
    }

    func testMappingIsMonotonicAndBounded() {
        let m = StrokeMapping()
        XCTAssertEqual(m.cueSpeed(fingerSpeed: m.fingerMin), m.cueMin, accuracy: 1e-9)
        XCTAssertEqual(m.cueSpeed(fingerSpeed: m.fingerMax), m.cueMax, accuracy: 1e-9)
        var last = 0.0
        for f in stride(from: m.fingerMin, through: m.fingerMax, by: 20) {
            let c = m.cueSpeed(fingerSpeed: f)
            XCTAssertGreaterThan(c, last)
            last = c
        }
    }
}

final class InteractionTests: XCTestCase {
    func testLockFlow() {
        var m = InteractionMachine()
        XCTAssertTrue(m.showsEffectBall)
        XCTAssertEqual(m.handle(.lockTap), .lock)
        XCTAssertFalse(m.showsEffectBall)
        XCTAssertTrue(m.swipeStrokes)
        XCTAssertEqual(m.handle(.lockTap), .unlock)
        XCTAssertEqual(m.state, .aiming)
    }

    func testCancelledStrokeStaysLocked() {
        var m = InteractionMachine()
        m.handle(.lockTap)
        m.handle(.strokeCancelled)
        XCTAssertEqual(m.state, .locked)
    }

    func testLockZoneRejectsLongPressAndPalm() {
        let z = LockZone()
        let p = SIMD2<Double>(0.1, 0.9)
        XCTAssertTrue(z.isLockTap(start: p, end: p, duration: 0.15, maxRadius: 15))
        XCTAssertFalse(z.isLockTap(start: p, end: p, duration: 0.6, maxRadius: 15))
        XCTAssertTrue(z.isLockTap(start: p, end: p, duration: 0.2, maxRadius: 45), "ngón cái (≈45 pt) phải khóa được")
        XCTAssertFalse(z.isLockTap(start: p, end: p, duration: 0.15, maxRadius: 100), "lòng bàn tay không khóa")
        XCTAssertFalse(z.isLockTap(start: SIMD2(0.6, 0.5), end: SIMD2(0.6, 0.5), duration: 0.1, maxRadius: 10))
    }
}

/// Lực mượt: cùng chuyển động ngón cho cùng tốc độ ở mọi tần số lấy mẫu; nhiễu cảm ứng không làm lực giật.
final class StrokeSmoothnessTests: XCTestCase {
    func samples(rate: Double, vf: Double, jitter: Double = 0) -> [TouchSample] {
        var out: [TouchSample] = []
        let dt = 1 / rate
        var t = 0.0, y = 0.0, k = 0
        out.append(TouchSample(time: 0, position: SIMD2(0, 0)))
        while y < 30 { t += dt; y += 200 * dt; out.append(TouchSample(time: t, position: SIMD2(0, y))) }
        while y > -20 {
            t += dt; y -= vf * dt; k += 1
            // Nhiễu xen kẽ ±jitter mm (không ngẫu nhiên: lặp lại được).
            out.append(TouchSample(time: t, position: SIMD2(0, y + (k % 2 == 0 ? jitter : -jitter))))
        }
        return out
    }

    func speed(_ s: [TouchSample]) -> Double {
        var a = StrokeAnalyzer()
        a.begin(s[0])
        for x in s.dropFirst() { if case .struck(let r) = a.add(x) { return r.fingerSpeed } }
        return -1
    }

    func testSameMotionSameSpeedAtAnySampleRate() {
        for rate in [60.0, 120, 240] {
            XCTAssertEqual(speed(samples(rate: rate, vf: 500)), 500, accuracy: 2, "\(rate) Hz")
        }
    }

    func testTouchJitterBarelyMovesPower() {
        let clean = speed(samples(rate: 120, vf: 500))
        let noisy = speed(samples(rate: 120, vf: 500, jitter: 0.4))
        print(String(format: "REPORT: finger speed clean %.1f, jitter ±0.4 mm %.1f mm/s", clean, noisy))
        XCTAssertEqual(noisy, clean, accuracy: clean * 0.06)
    }

    func testFinePowerSteps() {
        // 10 % tốc độ ngón → đổi lực cơ không quá ~11 % ở mọi mức.
        let m = StrokeMapping()
        var f = m.fingerMin
        while f * 1.1 <= m.fingerMax {
            XCTAssertLessThan(m.cueSpeed(fingerSpeed: f * 1.1) / m.cueSpeed(fingerSpeed: f), 1.11)
            f *= 1.1
        }
    }

    func testOldRecordingsReplayWithCountWindow() throws {
        let json = #"{"forward":[0,-1],"minBackswing":10,"regressionWindow":5}"#
        let c = try JSONDecoder().decode(StrokeConfig.self, from: Data(json.utf8))
        XCTAssertNil(c.regressionDuration)
        XCTAssertEqual(StrokeConfig().regressionDuration, 0.035)
    }
}
