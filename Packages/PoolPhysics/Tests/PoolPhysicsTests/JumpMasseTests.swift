import XCTest
import simd
@testable import PoolPhysics

/// Nhảy bi, massé, swerve (cơ dốc). Kiểm tra định tính theo mô tả của Alciatore (bi cong về phía đánh lệch,
/// cơ dốc + lực đủ thì bi rời bàn và bay qua bi chắn) và các bất biến (năng lượng cơ học không tăng, lặp lại
/// từng bit). Bàn rất rộng (30 m) để băng không xen vào đường cong. Số liệu định lượng chờ video bàn thật (R4).
final class JumpMasseTests: XCTestCase {
    let big = TableSpec(length: 30, width: 30)
    var R: Double { big.ballRadius }
    var m: Double { big.ballMass }

    func run(_ strike: CueStrike, extra: [Ball] = []) -> ShotResult {
        let cue = Ball(id: 0, position: SIMD3(15, 15, big.ballRadius))
        return Simulation(table: big, parameters: PhysicsParameters()).run(balls: [cue] + extra, strike: strike)
    }

    func maxHeight(_ r: ShotResult, id: Int = 0) -> Double {
        var h = 0.0, t = 0.0
        while t < r.trajectory.duration {
            if let b = r.trajectory.state(at: t).first(where: { $0.id == id }) { h = max(h, b.position.z - R) }
            t += 0.002
        }
        return h
    }

    /// Độ lệch ngang (m, dương = bên trái) của bi cái so với đường ngắm (trục +x) tại t = 1,5 s
    /// (trước khi chạm băng của bàn 30 m).
    func lateral(_ r: ShotResult) -> Double {
        r.trajectory.state(at: 1.5).first { $0.id == 0 }!.position.y - 15
    }

    func testFlatCueNeverLeavesTable() {
        let r = run(CueStrike(aimAngle: 0, cueSpeed: 4, tipVertical: -0.4))
        XCTAssertEqual(maxHeight(r), 0, accuracy: 1e-9)
    }

    func testJumpShotLeavesTableAndClearsBlocker() {
        // Cơ dốc 35°, 4,5 m/s, đánh tâm: bi nảy khỏi bàn và bay qua bi chắn cách 0,8 m.
        let blocker = Ball(id: 1, position: SIMD3(15.8, 15, big.ballRadius))
        let r = run(CueStrike(aimAngle: 0, cueSpeed: 4.5, elevation: 35 * Double.pi / 180), extra: [blocker])
        let h = maxHeight(r)
        print(String(format: "REPORT: jump 35°/4.5 m/s: max height %.1f mm", 1000 * h))
        XCTAssertGreaterThan(h, 0.1)
        XCTAssertFalse(r.collisions.contains { $0.kind == .ballBall }, "bi cái phải bay qua bi chắn")
        XCTAssertGreaterThan(r.finalBalls.first { $0.id == 0 }!.position.x, 15.8)
        XCTAssertEqual(r.status, .completed)
    }

    func testLowJumpHitsBlocker() {
        // Cơ dốc nhẹ: nảy thấp, không qua được bi chắn.
        let blocker = Ball(id: 1, position: SIMD3(15.3, 15, big.ballRadius))
        let r = run(CueStrike(aimAngle: 0, cueSpeed: 3, elevation: 20 * Double.pi / 180), extra: [blocker])
        XCTAssertTrue(r.collisions.contains { $0.kind == .ballBall })
    }

    func testMasseCurvesTowardEnglishSide() {
        let el = 70 * Double.pi / 180
        let right = run(CueStrike(aimAngle: 0, cueSpeed: 2.5, tipHorizontal: 0.4, elevation: el))
        let left = run(CueStrike(aimAngle: 0, cueSpeed: 2.5, tipHorizontal: -0.4, elevation: el))
        let lr = lateral(right), ll = lateral(left)
        print(String(format: "REPORT: massé 70°/2.5 m/s, 0.4R: lateral right %.3f m, left %.3f m", lr, ll))
        // Đánh lệch phải → cong về phải (y âm) dù squirt ban đầu lệch trái; đối xứng với lệch trái.
        XCTAssertLessThan(lr, -0.3)
        XCTAssertGreaterThan(ll, 0.3)
        XCTAssertEqual(lr, -ll, accuracy: 1e-6)
    }

    func testSwerveCurvesTowardEnglishSide() {
        // Cơ hơi dốc (10°): squirt lệch trái lúc đầu, rồi cong về phải.
        let r = run(CueStrike(aimAngle: 0, cueSpeed: 2, tipHorizontal: 0.4, elevation: 10 * Double.pi / 180))
        let start = r.trajectory.snapshots[0].balls[0].velocity
        XCTAssertGreaterThan(start.y, 0, "squirt ban đầu lệch trái")
        XCTAssertLessThan(lateral(r), 0, "cong về phía đánh lệch (phải)")
        // Cơ ngang: không cong (chỉ squirt thẳng).
        let flat = run(CueStrike(aimAngle: 0, cueSpeed: 2, tipHorizontal: 0.4))
        XCTAssertGreaterThan(lateral(flat), 0)
    }

    func testJumpMechanicalEnergyNeverRisesAndIsDeterministic() {
        let s = CueStrike(aimAngle: 0.3, cueSpeed: 5, tipVertical: -0.2, tipHorizontal: 0.1, elevation: 40 * Double.pi / 180)
        let a = run(s), b = run(s)
        XCTAssertEqual(a.trajectory.snapshots, b.trajectory.snapshots)
        let I = 0.4 * m * R * R, g = PhysicsParameters().gravity
        var last = Double.infinity
        for snap in a.trajectory.snapshots {
            let e = snap.balls.reduce(0.0) {
                $0 + 0.5 * m * simd_length_squared($1.velocity) + 0.5 * I * simd_length_squared($1.angularVelocity)
                    + m * g * ($1.position.z - R)
            }
            XCTAssertLessThanOrEqual(e, last * (1 + 1e-9) + 1e-12)
            last = e
        }
        XCTAssertEqual(a.status, .completed)
    }

    func testOldRecordsWithoutElevationStillDecode() throws {
        let json = #"{"aimAngle":0.5,"cueSpeed":2,"tipVertical":0.1,"tipHorizontal":0}"#
        let s = try JSONDecoder().decode(CueStrike.self, from: Data(json.utf8))
        XCTAssertEqual(s.elevation, 0)
        let p = try JSONDecoder().decode(PhysicsParameters.self, from: Data(#"{"slidingFriction":0.25}"#.utf8))
        XCTAssertEqual(p.slidingFriction, 0.25)
        XCTAssertEqual(p.tableRestitution, 0.5)
    }
}
