import XCTest
@testable import PoolInput

final class TouchRecordingTests: XCTestCase {

    func makeSamples() -> [TouchSample] {
        var out: [TouchSample] = []
        let dt = 1.0 / 240
        var t = 0.0, y = 0.0, x = 0.0
        out.append(TouchSample(time: t, position: SIMD2(x, y)))
        while y < 25 { t += dt; y += 150 * dt; out.append(TouchSample(time: t, position: SIMD2(x, y))) }
        while y > -15 { t += dt; y -= 450 * dt; x += 20 * dt; out.append(TouchSample(time: t, position: SIMD2(x, y))) }
        return out
    }

    /// KPI U2: phát lại cùng bản ghi → cùng kết quả.
    func testReplayIsIdentical() {
        let rec = TouchRecording(deviceModel: "test", mmPerPoint: 0.16, samples: makeSamples())
        XCTAssertEqual(rec.replay(), rec.replay())
        guard case .struck = rec.replay() else { return XCTFail("phải ra cú đánh") }
    }

    /// Lưu ra JSON rồi đọc lại vẫn phát lại ra đúng kết quả cũ.
    func testReplayAfterCodableRoundTrip() throws {
        let rec = TouchRecording(deviceModel: "test", mmPerPoint: 0.16, samples: makeSamples())
        let decoded = try JSONDecoder().decode(TouchRecording.self, from: JSONEncoder().encode(rec))
        XCTAssertEqual(decoded, rec)
        XCTAssertEqual(decoded.replay(), rec.replay())
    }

    func testEmptyRecordingIsCancelled() {
        XCTAssertEqual(TouchRecording(deviceModel: "test", mmPerPoint: 0.16, samples: []).replay(), .cancelled)
    }
}
