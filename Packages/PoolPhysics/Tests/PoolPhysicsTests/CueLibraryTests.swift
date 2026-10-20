import XCTest
import simd
@testable import PoolPhysics

/// Thư viện cơ (cơ thường / nhảy / massé) và mô hình đầu cơ chạm lại bi khi cơ dốc.
/// Quy luật kiểm tra (Dr. Dave, jump shot FAQ; Alciatore TP A.30): cơ nhảy nhẹ + đầu cứng → bi nảy cao hơn
/// với cùng cú vuốt, vì đầu cơ nhẹ không đuổi kịp bi sau khi bi nảy khỏi mặt bàn. Số định lượng chờ video (M3).
final class CueLibraryTests: XCTestCase {
    let big = TableSpec(length: 30, width: 30)
    var R: Double { big.ballRadius }
    var m: Double { big.ballMass }

    func strike(_ cue: CueSpec, refSpeed: Double, elevationDeg: Double, tipV: Double = 0, tipH: Double = 0) -> StrikeOutcome {
        let s = CueStrike(aimAngle: 0, cueSpeed: refSpeed * cue.strokeSpeedFactor, tipVertical: tipV,
                          tipHorizontal: tipH, elevation: elevationDeg * .pi / 180, cueId: cue.id)
        return CueModel.strike(s, cue: cue, ball: Ball(id: 0, position: SIMD3(15, 15, R)), mass: m, radius: R)
    }

    func run(_ cue: CueSpec, refSpeed: Double, elevationDeg: Double, tipH: Double = 0) -> ShotResult {
        let s = CueStrike(aimAngle: 0, cueSpeed: refSpeed * cue.strokeSpeedFactor, tipHorizontal: tipH,
                          elevation: elevationDeg * .pi / 180, cueId: cue.id)
        return Simulation(table: big, parameters: PhysicsParameters())
            .run(balls: [Ball(id: 0, position: SIMD3(15, 15, big.ballRadius))], strike: s)
    }

    func flight(_ r: ShotResult) -> (height: Double, landingX: Double) {
        var h = 0.0, t = 0.0, landing = 15.0, wasUp = false
        while t < min(r.trajectory.duration, 3) {
            let b = r.trajectory.state(at: t).first { $0.id == 0 }!
            let z = b.position.z - R
            h = max(h, z)
            if z > 1e-4 { wasUp = true } else if wasUp { landing = b.position.x; break }
            t += 0.0005
        }
        return (h, landing - 15)
    }

    func testLibraryWithinPublishedRanges() {
        XCTAssertEqual(Set(CueSpec.library.map(\.kind)), Set(CueKind.allCases))
        XCTAssertEqual(Set(CueSpec.library.map(\.id)).count, CueSpec.library.count)
        for c in CueSpec.library {
            XCTAssertLessThanOrEqual(c.tipDiameter, 0.014, "WPA: đầu tẩy tối đa 14 mm")
            XCTAssertGreaterThan(c.mass, 0.15); XCTAssertLessThan(c.mass, 0.71, "WPA: tối đa 25 oz")
        }
        XCTAssertTrue((0.71...0.75).contains(CueSpec.playing.tipRestitution), "đầu da")
        XCTAssertTrue((0.81...0.87).contains(CueSpec.jump.tipRestitution), "đầu phenolic")
        XCTAssertGreaterThan(CueSpec.jump.strokeSpeedFactor, 1)
        XCTAssertEqual(CueSpec.playing.strokeSpeedFactor, 1, accuracy: 1e-12)
    }

    func testJumpCueEscapesWhilePlayingCueDoubleHits() {
        let playing = strike(.playing, refSpeed: 4, elevationDeg: 45)
        let jump = strike(.jump, refSpeed: 4, elevationDeg: 45)
        print(String(format: "REPORT: 45° vz playing %.2f m/s (double hits %d), jump %.2f m/s (double hits %d)",
                     playing.ball.velocity.z, playing.doubleHits, jump.ball.velocity.z, jump.doubleHits))
        XCTAssertGreaterThan(playing.doubleHits, 0)
        XCTAssertEqual(jump.doubleHits, 0)
        XCTAssertGreaterThan(jump.ball.velocity.z, 1.3 * playing.ball.velocity.z)
    }

    func testJumpCueClearsBlockerPlayingCueCannot() {
        let blocker = Ball(id: 1, position: SIMD3(15.45, 15, big.ballRadius))
        func hits(_ cue: CueSpec) -> Bool {
            let s = CueStrike(aimAngle: 0, cueSpeed: 4 * cue.strokeSpeedFactor, elevation: 45 * .pi / 180, cueId: cue.id)
            let r = Simulation(table: big, parameters: PhysicsParameters())
                .run(balls: [Ball(id: 0, position: SIMD3(15, 15, big.ballRadius)), blocker], strike: s)
            return r.collisions.contains { $0.kind == .ballBall }
        }
        XCTAssertFalse(hits(.jump), "cơ nhảy bay qua bi chắn cách 0,45 m")
        XCTAssertTrue(hits(.playing), "cơ thường cùng cú vuốt: bi nảy thấp, chạm bi chắn")
    }

    /// Nhảy gần / nhảy xa: cùng cơ, cùng góc, đánh mạnh hơn → bay cao hơn và rơi xa hơn.
    func testHarderJumpGoesHigherAndFarther() {
        var last = (height: 0.0, landingX: 0.0)
        for v in [3.0, 4.0, 5.0, 6.0] {
            let f = flight(run(.jump, refSpeed: v, elevationDeg: 45))
            print(String(format: "REPORT: jump cue 45° ref %.1f m/s: height %.0f mm, first landing %.2f m", v, 1000 * f.height, f.landingX))
            XCTAssertGreaterThan(f.height, last.height)
            XCTAssertGreaterThan(f.landingX, last.landingX)
            last = f
        }
    }

    func testMasseCueCurvesTowardEnglishSymmetrically() {
        let r = run(.masse, refSpeed: 2.5, elevationDeg: 70, tipH: 0.4)
        let l = run(.masse, refSpeed: 2.5, elevationDeg: 70, tipH: -0.4)
        let yr = r.trajectory.state(at: 1.5).first { $0.id == 0 }!.position.y - 15
        let yl = l.trajectory.state(at: 1.5).first { $0.id == 0 }!.position.y - 15
        print(String(format: "REPORT: massé cue 70°: lateral right %.3f m, left %.3f m", yr, yl))
        XCTAssertLessThan(yr, -0.2)
        XCTAssertEqual(yr, -yl, accuracy: 1e-6)
        XCTAssertEqual(r.status, .completed)
    }

    func testStrikeRecordsCueAndOldRecordsDecode() throws {
        let s = CueStrike(aimAngle: 0.1, cueSpeed: 3, elevation: 0.7, cueId: "jump")
        let back = try JSONDecoder().decode(CueStrike.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
        let old = try JSONDecoder().decode(CueStrike.self, from: Data(#"{"aimAngle":0,"cueSpeed":2}"#.utf8))
        XCTAssertNil(old.cueId)
        // Simulation dùng cơ ghi trong cú đánh.
        XCTAssertNotEqual(flight(run(.jump, refSpeed: 4, elevationDeg: 45)).height,
                          flight(run(.playing, refSpeed: 4 / CueSpec.jump.strokeSpeedFactor, elevationDeg: 45)).height)
    }
}
