import XCTest
import simd
@testable import PoolPhysics

final class MotionTests: XCTestCase {
    let table = TableSpec.nineFoot
    var R: Double { table.ballRadius }
    let zHat = SIMD3<Double>(0, 0, 1)

    func rollingBall(speed: Double, along dir: SIMD3<Double> = SIMD3(1, 0, 0)) -> Ball {
        let v = speed * dir
        var b = Ball(id: 0, position: SIMD3(0.5, 0.6, R), velocity: v,
                     angularVelocity: cross(zHat, v) / R)
        b.state = b.classified(radius: R)
        return b
    }

    /// Bi lăn: quãng đường d = v0² / (2·μr·g).
    func testRollingDistance() {
        let p = PhysicsParameters()
        let b = rollingBall(speed: 1.5)
        XCTAssertEqual(b.state, .rolling)
        let events = FreeMotion.runToRest(b, p, radius: R)
        let end = events.last!.ball
        let expected = 1.5 * 1.5 / (2 * p.rollingResistance * p.gravity)
        XCTAssertEqual(end.position.x - b.position.x, expected, accuracy: 1e-9)
        XCTAssertEqual(end.state, .stationary)
    }

    /// Bi trượt không xoáy (stun) chuyển sang lăn ở 5/7 tốc độ ban đầu. Nguồn: Alciatore TP 4.1.
    func testStunBallReachesFiveSevenths() {
        let p = PhysicsParameters()
        var b = Ball(id: 0, position: SIMD3(0.5, 0.6, R), velocity: SIMD3(2, 0, 0))
        b.state = b.classified(radius: R)
        XCTAssertEqual(b.state, .sliding)
        let (next, _) = FreeMotion.advanceToTransition(b, p, radius: R)!
        XCTAssertEqual(next.state, .rolling)
        XCTAssertEqual(simd_length(next.velocity), 2.0 * 5 / 7, accuracy: 1e-9)
    }

    /// Đánh giữa tâm ở độ cao 2/5 R cho lăn tự nhiên ngay (không có pha trượt).
    func testNaturalRollHeight() {
        let strike = CueStrike(aimAngle: 0, cueSpeed: 1, tipVertical: 0.4)
        let b = CueModel.apply(strike, to: Ball(id: 0, position: SIMD3(0.5, 0.6, R)), radius: R)
        XCTAssertEqual(b.classified(radius: R), .rolling)
    }

    /// Quy tắc 90°: bi trượt (stun) chạm cắt, hai bi tách vuông góc (va chạm đàn hồi).
    func testNinetyDegreeRule() {
        var p = PhysicsParameters()
        p.ballBallRestitution = 1
        let cut = 25.0 * .pi / 180
        let n = SIMD3(cos(cut), sin(cut), 0)
        let cue = Ball(id: 0, position: SIMD3(1, 0.6, R), velocity: SIMD3(1.5, 0, 0))
        let obj = Ball(id: 1, position: cue.position + 2 * R * n)
        let (a, b) = BallBallCollision.resolve(cue, obj, p)
        XCTAssertEqual(simd_dot(a.velocity, b.velocity), 0, accuracy: 1e-12)
    }

    /// Quy tắc 30°: bi lăn chạm nửa bi, sau khi lăn trở lại bi cái lệch ≈ 33,7°.
    /// Nguồn: Alciatore TP 3.3 ("30° rule").
    func testThirtyDegreeRule() {
        var p = PhysicsParameters()
        p.ballBallRestitution = 1
        let cue = rollingBall(speed: 1.0)
        let cut = 30.0 * .pi / 180 // va chạm nửa bi
        let n = SIMD3(cos(cut), sin(cut), 0)
        let obj = Ball(id: 1, position: cue.position + 2 * R * n)
        var (a, _) = BallBallCollision.resolve(cue, obj, p)
        a.state = a.classified(radius: R)
        XCTAssertEqual(a.state, .sliding)
        let (rolled, _) = FreeMotion.advanceToTransition(a, p, radius: R)!
        let angle = abs(atan2(rolled.velocity.y, rolled.velocity.x)) * 180 / .pi
        XCTAssertEqual(angle, 33.7, accuracy: 0.5)
    }

    /// Cùng đầu vào → cùng kết quả từng bit.
    func testDeterministic() {
        let p = PhysicsParameters()
        let strike = CueStrike(aimAngle: 0.3, cueSpeed: 2.2, tipVertical: -0.3, tipHorizontal: 0.2)
        let start = Ball(id: 0, position: SIMD3(0.7, 0.4, R))
        let r1 = FreeMotion.runToRest(CueModel.apply(strike, to: start, radius: R), p, radius: R)
        let r2 = FreeMotion.runToRest(CueModel.apply(strike, to: start, radius: R), p, radius: R)
        XCTAssertEqual(r1.count, r2.count)
        XCTAssertEqual(r1.last!.ball, r2.last!.ball)
        XCTAssertEqual(r1.last!.time, r2.last!.time)
    }

    func testDiamondConversionRoundTrip() {
        let d = SIMD2<Double>(2.5, 1.25)
        let back = table.diamonds(fromMeters: table.meters(fromDiamonds: d))
        XCTAssertEqual(back.x, d.x, accuracy: 1e-12)
        XCTAssertEqual(back.y, d.y, accuracy: 1e-12)
        let corner = table.meters(fromDiamonds: SIMD2(8, 4))
        XCTAssertEqual(corner.x, table.length, accuracy: 1e-12)
        XCTAssertEqual(corner.y, table.width, accuracy: 1e-12)
    }
}
