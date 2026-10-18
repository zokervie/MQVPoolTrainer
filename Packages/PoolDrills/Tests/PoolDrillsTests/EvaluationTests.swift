import XCTest
import simd
import PoolPhysics
@testable import PoolDrills

final class EvaluationTests: XCTestCase {

    func testConditionParsing() {
        XCTAssertEqual(DrillCondition.parse("bi_1_vao_lo"), .ballPocketed(ball: 1, pocket: nil))
        XCTAssertEqual(DrillCondition.parse("bi_2_vao_lo_goc_tren_phai"), .ballPocketed(ball: 2, pocket: "goc_tren_phai"))
        XCTAssertEqual(DrillCondition.parse("bi_cai_trong_vung_dich"), .cueBallInTarget)
        XCTAssertEqual(DrillCondition.parse("bi_cai_cham_bang_2"), .cueBallCushions(2))
        XCTAssertEqual(DrillCondition.parse("abc"), .unknown("abc"))
    }

    /// Mọi bài tập đi kèm app phải đọc được và không có điều kiện lạ.
    func testBundledDrillsAreValid() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../Drills").standardized
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertGreaterThanOrEqual(files.count, 10)
        for f in files {
            let d = try DrillLoader.load(Data(contentsOf: f))
            for c in d.parsedConditions {
                if case .unknown(let s) = c { XCTFail("\(f.lastPathComponent): điều kiện lạ \(s)") }
            }
            XCTAssertTrue(d.bi.contains { $0.so == 0 }, "\(f.lastPathComponent) thiếu bi cái")
            for b in d.initialBalls() {
                XCTAssertTrue(b.position.x > 0 && b.position.x < d.tableSpec.length)
                XCTAssertTrue(b.position.y > 0 && b.position.y < d.tableSpec.width)
            }
        }
    }

    /// Cú thẳng xa: đánh đúng hướng theo thẻ hướng dẫn thì đạt; ngắm lệch 3° thì trượt.
    func testStraightDrillEvaluation() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../Drills/04-thang-xa.json").standardized
        let drill = try DrillLoader.load(Data(contentsOf: url))
        let balls = drill.initialBalls()
        let sim = Simulation(table: drill.tableSpec, parameters: PhysicsParameters())
        let cue = balls.first { $0.id == 0 }!, ob = balls.first { $0.id == 1 }!
        let aim = atan2(ob.position.y - cue.position.y, ob.position.x - cue.position.x)
        let good = drill.evaluate(sim.run(balls: balls, strike: drill.guideStrike(aimAngle: aim)))
        XCTAssertTrue(good.success, "\(good.conditions)")
        let bad = drill.evaluate(sim.run(balls: balls, strike: drill.guideStrike(aimAngle: aim + 3 * .pi / 180)))
        XCTAssertFalse(bad.success)
    }

    func testRandomOffsetIsDeterministicPerAttempt() throws {
        var d = try DrillLoader.load(Data(contentsOf: Bundle.module.url(forResource: "sample", withExtension: "json", subdirectory: "Fixtures")!))
        d.lechNgauNhien = 0.2
        XCTAssertEqual(d.initialBalls(attempt: 3), d.initialBalls(attempt: 3))
        XCTAssertNotEqual(d.initialBalls(attempt: 3), d.initialBalls(attempt: 4))
    }

    func testSpeedLevelRoundTrip() {
        for l in 1...7 { XCTAssertEqual(SpeedScale.level(forCueSpeed: SpeedScale.cueSpeed(level: l)), l) }
    }

    func testInsightsDetectAimBiasAndInconsistency() {
        var logs: [ShotLog] = []
        for k in 0..<10 {
            logs.append(ShotLog(date: Date(timeIntervalSince1970: Double(k)), drillId: "thang-xa", attempt: k, success: false,
                                cueSpeed: k % 2 == 0 ? 1.5 : 3.0, aimErrorDegrees: 0.8, lateralRatio: 0.02, followThroughRatio: 0.95))
        }
        let codes = ErrorAnalysis.insights(logs).map(\.code)
        XCTAssertTrue(codes.contains(.aimBiasRight))
        XCTAssertTrue(codes.contains(.inconsistentSpeed))
        XCTAssertFalse(codes.contains(.crookedStroke))
    }

    func testStats() {
        let logs = (0..<4).map { ShotLog(date: Date(), drillId: "x", attempt: $0, success: $0 < 3, cueSpeed: 2) }
        let s = DrillStats(logs)
        XCTAssertEqual(s.successRate, 0.75)
        XCTAssertEqual(s.speedCV ?? -1, 0, accuracy: 1e-12)
    }
}
