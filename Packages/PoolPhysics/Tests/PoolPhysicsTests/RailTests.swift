import XCTest
import simd
@testable import PoolPhysics

/// Băng 1–4 và effect (M1.2b). Kiểm tra quy luật đã công bố, không ép theo hệ kim cương:
/// - Xoáy ngang tắt với dω_z/dt trong 5–15 rad/s² (Dr. Dave; pooltool u_sp ≈ 0,0127 → ≈ 10,9 rad/s²).
/// - Effect thuận (running) làm góc bật "dài" hơn, effect nghịch làm "ngắn" hơn (Alciatore, *The Illustrated
///   Principles of Pool and Billiards*, mục kick/bank; Dr. Dave FAQ "running and reverse english").
/// - Hệ số phục hồi băng giảm khi lao vào băng nhanh hơn (cao su đàn nhớt; Dr. Dave: e băng 0,6–0,9
///   và "thay đổi theo tốc độ"). Độ dốc là **giả định**, chờ đo ở M3.
final class RailTests: XCTestCase {
    let table = TableSpec.nineFoot
    var R: Double { table.ballRadius }
    var m: Double { table.ballMass }

    // MARK: Xoáy ngang

    func testSideSpinDecayRateWithinPublishedRange() {
        let p = PhysicsParameters()
        let rate = 5 * p.spinFriction * p.gravity / (2 * R)
        print(String(format: "REPORT: dω_z/dt = %.1f rad/s²", rate))
        XCTAssertGreaterThanOrEqual(rate, 5)
        XCTAssertLessThanOrEqual(rate, 15)
        // Bi đứng yên chỉ xoay tại chỗ: thời gian tắt khớp công thức.
        let w0 = 30.0
        let b = Ball(id: 0, position: SIMD3(1, 0.6, R), angularVelocity: SIMD3(0, 0, w0))
        let t = FreeMotion.timeToTransition(b, p, radius: R)
        XCTAssertEqual(t ?? 0, w0 / rate, accuracy: 1e-9)
    }

    // MARK: Hệ số phục hồi băng theo tốc độ

    func reboundRatio(speed: Double, _ p: PhysicsParameters) -> Double {
        // Bi lăn tự nhiên lao thẳng vào băng y = 0 (pháp tuyến vào trong +y).
        let v = SIMD3(0, -speed, 0)
        let w = cross(SIMD3<Double>(0, 0, 1), v) / R
        let b = Ball(id: 0, position: SIMD3(1, R, R), velocity: v, angularVelocity: w)
        let (out, _) = CushionCollision.resolve(b, inward: SIMD2(0, 1), cushionHeight: table.cushionHeight, p,
                                                mass: m, radius: R)
        return out.velocity.y / speed
    }

    func testCushionRestitutionFallsWithSpeed() {
        let p = PhysicsParameters()
        let soft = reboundRatio(speed: 0.5, p), hard = reboundRatio(speed: 3.5, p)
        print(String(format: "REPORT: rebound speed ratio 0.5 m/s %.3f, 3.5 m/s %.3f", soft, hard))
        XCTAssertGreaterThan(soft, hard + 0.05)
        XCTAssertEqual(p.cushionRestitution(atApproachSpeed: 1), p.cushionRestitution, accuracy: 1e-12)
        XCTAssertGreaterThanOrEqual(p.cushionRestitution(atApproachSpeed: 20), 0.6)
        XCTAssertLessThanOrEqual(p.cushionRestitution(atApproachSpeed: 0), 0.95)
        // Độ dốc 0 → mô hình cũ (hằng số), dùng cho đối chứng Han 2005.
        var flat = p; flat.cushionRestitutionSpeedSlope = 0
        XCTAssertEqual(reboundRatio(speed: 0.5, flat), reboundRatio(speed: 3.5, flat), accuracy: 1e-9)
    }

    // MARK: Nhiều băng

    /// Bi cái đánh tâm-ngang với effect `side` (tỉ lệ R, + phải), cơ không squirt để tách riêng tác dụng ở băng.
    func run(side: Double, speed: Double = 2.6, _ p: PhysicsParameters = PhysicsParameters()) -> [CollisionRecord] {
        var cue = CueSpec(); cue.endMass = 1e-9
        let start = SIMD3(0.6, 0.3, R)
        let target = SIMD2(1.0, table.width - R)
        let aim = atan2(target.y - start.y, target.x - start.x)
        let sim = Simulation(table: table, parameters: p, cue: cue)
        let r = sim.run(balls: [Ball(id: 0, position: start)],
                        strike: CueStrike(aimAngle: aim, cueSpeed: speed, tipVertical: 0.2, tipHorizontal: side))
        XCTAssertEqual(r.status, .completed)
        return r.collisions.filter { $0.kind == .cushion }
    }

    func testRailSequenceIsOrderedAndDistinct() {
        let rails = run(side: 0)
        XCTAssertGreaterThanOrEqual(rails.count, 4, "đủ 4 băng để luyện bài nút số")
        for (a, b) in zip(rails, rails.dropFirst()) {
            XCTAssertLessThan(a.time, b.time)
            // Không có va chạm lặp ở cùng một chỗ (mỗi lần chạm băng đếm đúng một lần).
            XCTAssertGreaterThan(simd_distance(a.position, b.position), 0.2)
        }
        // Băng 1 ở băng dài trên, băng 2 ở băng dài dưới.
        XCTAssertGreaterThan(rails[0].position.y, table.width - 2 * R)
        XCTAssertLessThan(rails[1].position.y, 2 * R)
    }

    /// Effect thuận (ở đây: phải) → bi chạy dọc băng xa hơn ở băng 2 và 3; effect nghịch → ngắn hơn.
    func testRunningEnglishLengthensReverseShortens() {
        let none = run(side: 0), running = run(side: 0.4), reverse = run(side: -0.4)
        for k in 1...2 {
            let x0 = none[k].position.x, xr = running[k].position.x, xv = reverse[k].position.x
            print(String(format: "REPORT: rail %d x: reverse %.3f none %.3f running %.3f m", k + 1, xv, x0, xr))
            XCTAssertGreaterThan(xr, x0 + 0.02, "băng \(k + 1): effect thuận phải dài hơn")
            XCTAssertLessThan(xv, x0 - 0.02, "băng \(k + 1): effect nghịch phải ngắn hơn")
        }
    }

    /// Xoáy ngang tắt chậm (đúng khoảng công bố) → effect còn tác dụng rõ ở băng 3.
    func testEnglishStillMattersAtThirdRail() {
        var fast = PhysicsParameters(); fast.spinFriction = 0.044
        let gap = abs(run(side: 0.4)[2].position.x - run(side: 0)[2].position.x)
        let gapOld = abs(run(side: 0.4, fast)[2].position.x - run(side: 0, fast)[2].position.x)
        print(String(format: "REPORT: rail 3 english gap %.3f m (old spinFriction %.3f m)", gap, gapOld))
        XCTAssertGreaterThan(gap, gapOld)
    }

    func testMultiRailIsDeterministic() {
        XCTAssertEqual(run(side: 0.3), run(side: 0.3))
    }

    /// Báo cáo cho bài tập nút số (Drills/11, 12): bi cái ở kim cương (6; 3), ngắm điểm băng dài trên kim cương 3,
    /// lực 5 (1,9 m/s), đánh hơi cao, không effect / effect thuận / nghịch. In vị trí 3 băng đầu và chỗ dừng.
    func testReportDiamondKickLayout() {
        for side in [0.0, -0.35, 0.35] {
            for speed in [1.4, 1.9, 2.6] {
                let start = SIMD3(6 * table.length / 8, 3 * table.width / 4, R)
                let aimPt = SIMD2(3 * table.length / 8, table.width)
                let aim = atan2(aimPt.y - start.y, aimPt.x - start.x)
                let r = Simulation(table: table, parameters: PhysicsParameters())
                    .run(balls: [Ball(id: 0, position: start)],
                         strike: CueStrike(aimAngle: aim, cueSpeed: speed, tipVertical: 0.15, tipHorizontal: side))
                let d = { (p: SIMD3<Double>) in String(format: "(%.2f; %.2f)", p.x * 8 / self.table.length, p.y * 4 / self.table.width) }
                let rails = r.collisions.filter { $0.kind == .cushion }.prefix(4).map { d($0.position) }.joined(separator: " ")
                print("REPORT: kick side \(side) v \(speed): rails \(rails) stop \(d(r.finalBalls[0].position)) pocketed \(r.pocketed.count)")
            }
        }
    }
}
