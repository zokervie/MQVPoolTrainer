import XCTest
import simd
@testable import PoolPhysics

// MARK: - Đa thức

final class PolynomialTests: XCTestCase {
    func testQuarticRoots() {
        // (t−1)(t−2)(t−3)(t−4) = t⁴ − 10t³ + 35t² − 50t + 24
        let r = Polynomial.realRoots([24, -50, 35, -10, 1], in: 0, 10)
        XCTAssertEqual(r.count, 4)
        for (k, x) in r.enumerated() { XCTAssertEqual(x, Double(k + 1), accuracy: 1e-9) }
    }

    func testDoubleRootFound() {
        // (t − 0,5)² — trường hợp va chạm sượt
        let r = Polynomial.realRoots([0.25, -1, 1], in: 0, 1)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0], 0.5, accuracy: 1e-6)
    }

    func testNoRootsOutsideInterval() {
        XCTAssertTrue(Polynomial.realRoots([-4, 0, 1], in: 0, 1).isEmpty) // nghiệm ±2
    }
}

// MARK: - Bộ giải

final class SolverTests: XCTestCase {
    let table = TableSpec.nineFoot
    var R: Double { table.ballRadius }
    var m: Double { table.ballMass }
    let params = PhysicsParameters()
    var sim: Simulation { Simulation(table: table, parameters: params) }

    func kineticEnergy(_ balls: [Ball]) -> Double {
        let I = 0.4 * m * R * R
        return balls.filter { $0.state != .pocketed }.reduce(0) {
            $0 + 0.5 * m * simd_length_squared($1.velocity) + 0.5 * I * simd_length_squared($1.angularVelocity)
        }
    }

    func ball(_ id: Int, _ x: Double, _ y: Double) -> Ball { Ball(id: id, position: SIMD3(x, y, R)) }

    /// Cú thẳng vào lỗ góc trên phải: bi 1 phải vào lỗ 3.
    func testStraightShotIntoCornerPocket() {
        let d = SIMD2<Double>(1, 1) / 2.0.squareRoot()
        let corner = SIMD2(table.length, table.width)
        let ob = corner - 0.45 * d, cb = corner - 1.0 * d
        let result = sim.run(balls: [ball(0, cb.x, cb.y), ball(1, ob.x, ob.y)],
                             strike: CueStrike(aimAngle: .pi / 4, cueSpeed: 2.0))
        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.firstObjectBallHit, 1)
        XCTAssertTrue(result.pocketed.contains { $0.ballId == 1 && $0.pocketId == 3 }, "\(result.pocketed)")
        XCTAssertTrue(result.collisions.contains { $0.kind == .cueTip })
    }

    /// Bi lăn vuông góc vào băng dưới: bật ngược lên, chậm hơn, gần như không lệch ngang.
    func testPerpendicularCushionRebound() {
        let result = sim.run(balls: [ball(0, 0.6, 0.6)],
                             strike: CueStrike(aimAngle: -.pi / 2, cueSpeed: 1.5, tipVertical: 0.4))
        guard let hit = result.collisions.first(where: { $0.kind == .ballCushion }) else { return XCTFail("không chạm băng") }
        let before = result.trajectory.state(at: hit.time - 1e-6)[0]
        let after = result.trajectory.state(at: hit.time + 1e-6)[0]
        XCTAssertLessThan(before.velocity.y, 0)
        XCTAssertGreaterThan(after.velocity.y, 0)
        XCTAssertLessThan(simd_length(after.velocity), simd_length(before.velocity))
        XCTAssertEqual(after.velocity.x, 0, accuracy: 1e-6)
        XCTAssertGreaterThan(hit.impulse, 0)
    }

    /// Xoáy ngang trái và phải cho hướng bật băng ngược nhau.
    func testSidespinChangesReboundDirection() {
        func vxAfterCushion(_ english: Double) -> Double {
            let r = sim.run(balls: [ball(0, 0.6, 0.6)],
                            strike: CueStrike(aimAngle: -.pi / 2, cueSpeed: 1.5, tipVertical: 0.2, tipHorizontal: english))
            let hit = r.collisions.first { $0.kind == .ballCushion }!
            return r.trajectory.state(at: hit.time + 1e-4)[0].velocity.x
        }
        let right = vxAfterCushion(0.35), left = vxAfterCushion(-0.35)
        XCTAssertNotEqual(right.sign, left.sign)
        XCTAssertGreaterThan(abs(right), 0.01)
    }

    /// Throw do cắt: bi trượt cắt 30°, bi mục tiêu lệch về phía hướng đi của bi cái.
    /// Nguồn số liệu: Alciatore, throw do cắt ở tốc độ vừa khoảng vài độ.
    func testCutInducedThrow() {
        let cut = 30.0 * .pi / 180
        let n = SIMD3(cos(cut), sin(cut), 0)
        let cue = Ball(id: 0, position: SIMD3(1, 0.6, R), velocity: SIMD3(1.0, 0, 0))
        let obj = Ball(id: 1, position: cue.position + 2 * R * n)
        let (_, b) = BallBallCollision.resolve(cue, obj, params, mass: m, radius: R)
        let angle = atan2(b.velocity.y, b.velocity.x) * 180 / .pi
        let throwDeg = 30 - angle
        XCTAssertGreaterThan(throwDeg, 1, "throw phải lệch về phía hướng bi cái")
        XCTAssertLessThan(throwDeg, 6)
    }

    /// Squirt: đánh bên phải → bi lệch sang trái, cỡ 1–4° ở 0,5R với đầu cơ 7 g.
    func testSquirtDirectionAndSize() {
        let out = CueModel.strike(CueStrike(aimAngle: 0, cueSpeed: 2, tipHorizontal: 0.5),
                                  ball: ball(0, 1, 0.6), mass: m, radius: R)
        let deg = out.squirtAngle * 180 / .pi
        XCTAssertGreaterThan(deg, 1); XCTAssertLessThan(deg, 4)
        XCTAssertGreaterThan(out.ball.velocity.y, 0) // lệch trái (+y khi ngắm +x)
        XCTAssertGreaterThan(out.ball.angularVelocity.z, 0) // xoáy phải: quay ngược chiều kim đồng hồ nhìn từ trên
    }

    func testMiscueBeyondLimit() {
        let out = CueModel.strike(CueStrike(aimAngle: 0, cueSpeed: 3, tipVertical: 0.6),
                                  ball: ball(0, 1, 0.6), mass: m, radius: R)
        XCTAssertTrue(out.miscue)
    }

    /// M2: cú phá bi lặp lại giống hệt từng bit.
    func testBreakIsDeterministic() {
        let balls = [ball(0, 0.635, 0.635)] + Rack.triangle(apex: SIMD2(1.905, 0.635), radius: R)
        let s = CueStrike(aimAngle: 0, cueSpeed: 7)
        let a = sim.run(balls: balls, strike: s), b = sim.run(balls: balls, strike: s)
        XCTAssertEqual(a.status, .completed)
        XCTAssertEqual(a.collisions, b.collisions)
        XCTAssertEqual(a.finalBalls, b.finalBalls)
        XCTAssertGreaterThan(a.collisions.filter { $0.kind == .ballBall }.count, 15)
    }

    /// M3, M4, M6 trên các cú ngẫu nhiên có seed (bộ rút gọn; bộ 10.000 cú R1.7: `poolsim --invariants`, job CI `invariants`).
    func testInvariantsOnRandomShots() {
        var rng = SplitMix64(seed: 2026)
        let shots = 300
        var worstOverlap = 0.0
        for shot in 0..<shots {
            var balls: [Ball] = []
            let count = 2 + Int(rng.unit() * 6)
            while balls.count < count {
                let x = R + 0.02 + rng.unit() * (table.length - 2 * R - 0.04)
                let y = R + 0.02 + rng.unit() * (table.width - 2 * R - 0.04)
                let p = SIMD3(x, y, R)
                if balls.allSatisfy({ simd_distance($0.position, p) > 2 * R + 1e-4 }) {
                    balls.append(Ball(id: balls.count, position: p))
                }
            }
            let strike = CueStrike(aimAngle: rng.unit() * 2 * .pi, cueSpeed: 0.5 + rng.unit() * 6,
                                   tipVertical: (rng.unit() - 0.5) * 0.8, tipHorizontal: (rng.unit() - 0.5) * 0.6)
            let r = sim.run(balls: balls, strike: strike)
            XCTAssertEqual(r.status, .completed, "shot \(shot)")

            var lastEnergy = Double.infinity
            for snap in r.trajectory.snapshots.dropFirst() {
                let live = snap.balls.filter { $0.state != .pocketed }
                for i in live.indices { for j in (i + 1)..<live.count {
                    var d = live[j].position - live[i].position; d.z = 0
                    worstOverlap = max(worstOverlap, 2 * R - simd_length(d))
                } }
                let e = kineticEnergy(snap.balls)
                XCTAssertLessThanOrEqual(e, lastEnergy * (1 + 1e-9) + 1e-12, "năng lượng tăng ở shot \(shot), t=\(snap.time)")
                lastEnergy = e
            }
        }
        XCTAssertLessThan(worstOverlap, 1e-6, "chồng lấn lớn nhất \(worstOverlap) m")
    }

    /// M5: động lượng ngang của cặp bi bảo toàn trong va chạm cô lập (có ma sát).
    func testPairMomentumConserved() {
        var rng = SplitMix64(seed: 7)
        for _ in 0..<200 {
            let ang = rng.unit() * 2 * .pi
            let n = SIMD3(cos(ang), sin(ang), 0)
            let a = Ball(id: 0, position: SIMD3(1, 0.6, R),
                         velocity: SIMD3((rng.unit() - 0.5) * 6, (rng.unit() - 0.5) * 6, 0) + 2 * n,
                         angularVelocity: SIMD3((rng.unit() - 0.5) * 200, (rng.unit() - 0.5) * 200, (rng.unit() - 0.5) * 200))
            let b = Ball(id: 1, position: a.position + 2 * R * n)
            let (a2, b2) = BallBallCollision.resolve(a, b, params, mass: m, radius: R)
            let p0 = a.velocity + b.velocity, p1 = a2.velocity + b2.velocity
            XCTAssertEqual(p0.x, p1.x, accuracy: 1e-9)
            XCTAssertEqual(p0.y, p1.y, accuracy: 1e-9)
        }
    }

    /// M7: đo độ nhạy với thứ tự xử lý va chạm đồng thời (báo cáo, chưa đặt ngưỡng).
    func testOrderSensitivityIsReported() {
        let balls = [ball(0, 0.635, 0.635)] + Rack.triangle(apex: SIMD2(1.905, 0.635), radius: R, gap: 0)
        let s = CueStrike(aimAngle: 0, cueSpeed: 7)
        var reversed = sim; reversed.options.reverseTieOrder = true
        let a = sim.run(balls: balls, strike: s).finalBalls
        let b = reversed.run(balls: balls, strike: s).finalBalls
        let spread = zip(a, b).map { simd_distance($0.position, $1.position) }
        let mean = spread.reduce(0, +) / Double(spread.count)
        print("REPORT: M7 order sensitivity: mean final-position spread = \(mean) m, max = \(spread.max() ?? 0) m")
        XCTAssertTrue(mean.isFinite)
    }

    /// Nội suy quỹ đạo khớp đúng snapshot tại thời điểm sự kiện.
    func testTrajectoryInterpolationMatchesSnapshots() {
        let r = sim.run(balls: [ball(0, 0.5, 0.5), ball(1, 1.2, 0.5)], strike: CueStrike(aimAngle: 0, cueSpeed: 2))
        let snaps = r.trajectory.snapshots
        for (k, snap) in snaps.enumerated() where k + 1 == snaps.count || snaps[k + 1].time > snap.time {
            if k == 0 { continue }
            XCTAssertEqual(r.trajectory.state(at: snap.time), snap.balls)
        }
        XCTAssertGreaterThan(r.trajectory.duration, 0)
    }

    /// Khoảng ngắm: cú thẳng vào lỗ góc có một khoảng góc thành công chứa góc thẳng.
    func testAimWindowContainsStraightShot() {
        let d = SIMD2<Double>(1, 1) / 2.0.squareRoot()
        let corner = SIMD2(table.length, table.width)
        let ob = corner - 0.45 * d, cb = corner - 1.0 * d
        let balls = [ball(0, cb.x, cb.y), ball(1, ob.x, ob.y)]
        let w = AimWindow.search(simulation: sim, balls: balls, strike: CueStrike(aimAngle: .pi / 4, cueSpeed: 2),
                                 halfRange: 0.06, step: 0.004) { r in r.pocketed.contains { $0.ballId == 1 } }
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.error(for: .pi / 4), 0)
        XCTAssertGreaterThan(w?.width ?? 0, 0)
    }
}

/// Thời gian mô phỏng cú phá bi trên máy chạy test (thông tin; KPI H1 phải đo trên iPhone thật).
final class SolverTimingReport: XCTestCase {
    func testReportBreakSimulationTime() {
        let table = TableSpec.nineFoot, R = table.ballRadius
        let sim = Simulation(table: table, parameters: PhysicsParameters())
        var rng = SplitMix64(seed: 99)
        var times: [Double] = []
        var events: [Int] = []
        for _ in 0..<30 {
            let balls = [Ball(id: 0, position: SIMD3(0.635, 0.635 + (rng.unit() - 0.5) * 0.2, R))]
                + Rack.triangle(apex: SIMD2(1.905, 0.635), radius: R)
            let s = CueStrike(aimAngle: (rng.unit() - 0.5) * 0.05, cueSpeed: 5 + rng.unit() * 3)
            let t0 = Date()
            let r = sim.run(balls: balls, strike: s)
            times.append(Date().timeIntervalSince(t0) * 1000)
            events.append(r.trajectory.snapshots.count)
            XCTAssertEqual(r.status, .completed)
        }
        times.sort()
        let p50 = times[times.count / 2], p95 = times[Int(Double(times.count) * 0.95)]
        print("REPORT: break simulation on CI runner (not iPhone): p50 \(String(format: "%.1f", p50)) ms, p95 \(String(format: "%.1f", p95)) ms, max \(String(format: "%.1f", times.last!)) ms; events max \(events.max() ?? 0), median \(events.sorted()[events.count / 2])")
    }
}
