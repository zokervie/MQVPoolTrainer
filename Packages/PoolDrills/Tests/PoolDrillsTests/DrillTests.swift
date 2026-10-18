import XCTest
@testable import PoolDrills

final class DrillTests: XCTestCase {
    func testLoadSampleAndRoundTrip() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample", withExtension: "json", subdirectory: "Fixtures"))
        let drill = try DrillLoader.load(Data(contentsOf: url))
        XCTAssertEqual(drill.id, "keo-bi-ve-giua")
        XCTAssertEqual(drill.bi.count, 2)
        XCTAssertEqual(drill.huongDan.diemCham.doc, -0.5)
        let again = try DrillLoader.load(DrillLoader.export(drill))
        XCTAssertEqual(drill, again)
    }

    func testSpeedScaleIsMonotonicAndClamped() {
        for l in 1..<7 {
            XCTAssertLessThan(SpeedScale.cueSpeed(level: l), SpeedScale.cueSpeed(level: l + 1))
        }
        XCTAssertEqual(SpeedScale.cueSpeed(level: 0), SpeedScale.cueSpeed(level: 1))
        XCTAssertEqual(SpeedScale.cueSpeed(level: 9), SpeedScale.cueSpeed(level: 7))
    }
}
