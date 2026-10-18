import XCTest
import simd
@testable import PoolPhysics

/// Tầng 1.5 — đối chiếu với số liệu/quy luật thực nghiệm ĐÃ CÔNG BỐ (độc lập với pooltool).
/// Nguồn: D. Alciatore, "What is the most throw I can get…" (drdavepoolinfo.com/FAQ/throw/maximum),
/// Technical Proofs TP 3.3, TP 4.1, TP A.14, TP A.31. Ngưỡng là khoảng tham khảo từ các nguồn này,
/// không phải số đo của dự án — ghi rõ trong từng test.
final class LiteratureTests: XCTestCase {
    let R = TableSpec.nineFoot.ballRadius
    let m = TableSpec.nineFoot.ballMass
    let p = PhysicsParameters()
    let zHat = SIMD3<Double>(0, 0, 1)

    /// Góc throw (độ, dương = bi mục tiêu lệch về phía hướng đi của bi cái) cho cú cắt `cutDeg`.
    /// - spin: "stun" (không xoáy), "roll" (lăn tự nhiên), hoặc xoáy ngang `side` (tỉ lệ R, + là bên phải).
    func throwAngle(cutDeg: Double, speed v: Double, roll: Bool = false, side: Double = 0) -> Double {
        let cut = cutDeg * .pi / 180
        // Bi cái đi theo +x; bi mục tiêu đặt sao cho đường nối tâm lệch `cut` sang trái (+y).
        let n = SIMD3(cos(cut), sin(cut), 0)
        var w = SIMD3<Double>.zero
        let vel = SIMD3(v, 0, 0)
        if roll { w = cross(zHat, vel) / R }
        // Xoáy ngang tại thời điểm va chạm: ω_z = 5·v·s/(2R) (TP 4.2), phải → ngược chiều kim đồng hồ.
        w.z = 5 * v * side / (2 * R)
        let cue = Ball(id: 0, position: SIMD3(1, 0.6, R), velocity: vel, angularVelocity: w)
        let ob = Ball(id: 1, position: cue.position + 2 * R * n)
        let (_, b) = BallBallCollision.resolve(cue, ob, p, mass: m, radius: R)
        let dirDeg = atan2(b.velocity.y, b.velocity.x) * 180 / .pi
        return cutDeg - dirDeg   // dương: bi mục tiêu bị kéo về phía +x (hướng bi cái)
    }

    let slow = 0.45, medium = 1.3, fast = 3.1   // ≈ 1, 3, 7 mph

    /// Bảng throw do cắt (stun) theo góc cắt và tốc độ — in ra để xem.
    func testReportCutInducedThrowTable() {
        var rows: [String] = []
        for cut in stride(from: 5.0, through: 60, by: 5) {
            rows.append(String(format: "%2.0f°: slow %.2f° medium %.2f° fast %.2f° | roll-slow %.2f°", cut,
                               throwAngle(cutDeg: cut, speed: slow), throwAngle(cutDeg: cut, speed: medium),
                               throwAngle(cutDeg: cut, speed: fast), throwAngle(cutDeg: cut, speed: slow, roll: true)))
        }
        print("REPORT: CIT table (stun; last column natural roll):\n" + rows.map { "REPORT:   " + $0 }.joined(separator: "\n"))
    }

    /// Throw tối đa ≈ 5° (≈ 1 inch mỗi foot), ở cú stun chậm, quanh nửa bi (30°).
    func testMaximumCutInducedThrowNearFiveDegreesAtHalfBall() {
        let cuts = Array(stride(from: 5.0, through: 60, by: 1))
        let values = cuts.map { throwAngle(cutDeg: $0, speed: slow) }
        let k = values.indices.max { values[$0] < values[$1] }!
        XCTAssertGreaterThan(values[k], 4.0, "throw tối đa \(values[k])°")
        XCTAssertLessThan(values[k], 6.5, "throw tối đa \(values[k])°")
        XCTAssertTrue((22.0...42.0).contains(cuts[k]), "throw lớn nhất ở góc cắt \(cuts[k])°")
    }

    /// Dưới khoảng 20° góc cắt, tốc độ (gần như) không ảnh hưởng tới throw do cắt.
    func testSmallCutThrowIndependentOfSpeed() {
        for cut in [5.0, 10.0, 15.0] {
            let a = throwAngle(cutDeg: cut, speed: slow), b = throwAngle(cutDeg: cut, speed: fast)
            XCTAssertEqual(a, b, accuracy: 0.25, "cắt \(cut)°: chậm \(a)°, nhanh \(b)°")
        }
    }

    /// Góc cắt lớn: đánh nhanh thì throw nhỏ hơn (ma sát giảm theo tốc độ trượt).
    func testLargeCutThrowDecreasesWithSpeed() {
        for cut in [35.0, 45.0, 55.0] {
            XCTAssertGreaterThan(throwAngle(cutDeg: cut, speed: slow), throwAngle(cutDeg: cut, speed: fast), "cắt \(cut)°")
        }
    }

    /// Bi lăn (xoáy trên) throw ít hơn bi stun.
    func testRollingThrowsLessThanStun() {
        for cut in [15.0, 30.0, 45.0] {
            XCTAssertLessThan(throwAngle(cutDeg: cut, speed: medium, roll: true),
                              throwAngle(cutDeg: cut, speed: medium), "cắt \(cut)°")
        }
    }

    /// Throw do xoáy ngang ở cú thẳng: có, ngược phía xoáy, và lớn nhất quanh ~50% mức xoáy TỐI ĐA ở tốc độ chậm.
    /// Mức xoáy tối đa ≈ 0,5R (giới hạn trượt cơ) → 50% ≈ 0,25R.
    func testSpinInducedThrowStraightShot() {
        let sides = Array(stride(from: 0.1, through: 0.8, by: 0.05))
        let values = sides.map { abs(throwAngle(cutDeg: 0, speed: slow, side: $0)) }
        let k = values.indices.max { values[$0] < values[$1] }!
        print(String(format: "REPORT: SIT straight slow: max %.2f° at side %.2fR; at 0.25R %.2f°", values[k], sides[k], values[3]))
        // Xoáy phải (bên phải bi cái) đẩy bi mục tiêu sang trái (+y).
        let signed = throwAngle(cutDeg: 0, speed: slow, side: 0.4)
        XCTAssertLessThan(signed, 0, "xoáy phải phải làm bi mục tiêu lệch trái (góc hướng dương)")
        XCTAssertTrue((0.15...0.35).contains(sides[k]), "SIT lớn nhất ở \(sides[k])R")
        XCTAssertLessThan(values[k], 6.5)
    }

    /// Quy tắc 30° (TP 3.3): bi lăn tự nhiên, độ dày 1/4 → 3/4 bi, bi cái lệch trong khoảng ~27°–34°
    /// (không ma sát, e = 1 — đúng giả thiết của quy tắc).
    func testThirtyDegreeRuleRange() {
        var q = p; q.ballBallFriction = 0; q.ballBallRestitution = 1
        for fraction in stride(from: 0.25, through: 0.75, by: 0.05) {
            let cut = asin(1 - fraction)
            let n = SIMD3(cos(cut), sin(cut), 0)
            let v = SIMD3(1.0, 0, 0)
            var cue = Ball(id: 0, position: SIMD3(1, 0.6, R), velocity: v, angularVelocity: cross(zHat, v) / R)
            cue.state = cue.classified(radius: R)
            let ob = Ball(id: 1, position: cue.position + 2 * R * n)
            var (a, _) = BallBallCollision.resolve(cue, ob, q, mass: m, radius: R)
            a.state = a.classified(radius: R)
            let rolled = FreeMotion.advanceToTransition(a, q, radius: R)!.0
            let deflection = abs(atan2(rolled.velocity.y, rolled.velocity.x)) * 180 / .pi
            XCTAssertTrue((27.0...34.0).contains(deflection), "độ dày \(fraction): lệch \(deflection)°")
        }
    }

    /// Quãng trượt của bi stun tới khi lăn: d = 12·v²/(49·μ·g) (TP 4.1).
    func testStunSlidingDistance() {
        var b = Ball(id: 0, position: SIMD3(0.3, 0.6, R), velocity: SIMD3(2, 0, 0))
        b.state = b.classified(radius: R)
        let (rolled, _) = FreeMotion.advanceToTransition(b, p, radius: R)!
        let expected = 12 * 4 / (49 * p.slidingFriction * p.gravity)
        XCTAssertEqual(rolled.position.x - 0.3, expected, accuracy: 1e-9)
    }

    /// Squirt ở 0,5R với đầu cơ 7 g: báo cáo (khoảng thường gặp 1–3°, tùy ngọn cơ).
    func testReportSquirt() {
        var rows: [String] = []
        for s in [0.1, 0.2, 0.3, 0.4, 0.5] {
            let out = CueModel.strike(CueStrike(aimAngle: 0, cueSpeed: 2, tipHorizontal: s),
                                      ball: Ball(id: 0, position: SIMD3(1, 0.6, R)), mass: m, radius: R)
            rows.append(String(format: "%.1fR → %.2f°", s, out.squirtAngle * 180 / .pi))
        }
        print("REPORT: squirt (end mass 7 g): " + rows.joined(separator: ", "))
    }
}
