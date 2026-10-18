import XCTest
import PoolPhysics
@testable import PoolAudio

final class PoolAudioTests: XCTestCase {
    let mapping = AcousticMapping()

    /// A1: âm lượng, độ sáng âm sắc, lớp lực không giảm khi xung lực tăng.
    func testMappingIsMonotonic() {
        for kind in CollisionKind.allCases {
            var last = (gain: -Double.infinity, cutoff: 0.0, layer: -1.0)
            var j = 0.001
            while j < 3 {
                let b = mapping.layerBlend(kind, impulse: j)
                let layer = Double(b.lower) + b.mix
                let now = (gain: mapping.gainDB(kind, impulse: j), cutoff: mapping.cutoffHz(kind, impulse: j), layer: layer)
                XCTAssertGreaterThanOrEqual(now.gain, last.gain, "\(kind) gain @ \(j)")
                XCTAssertGreaterThanOrEqual(now.cutoff, last.cutoff, "\(kind) cutoff @ \(j)")
                XCTAssertGreaterThanOrEqual(now.layer, last.layer - 1e-12, "\(kind) layer @ \(j)")
                last = now
                j *= 1.07
            }
        }
    }

    /// Va chạm mạnh khác va chạm nhẹ ở nhiều đặc tính, không chỉ âm lượng.
    func testStrongHitDiffersBeyondVolume() {
        let soft = 0.01, hard = 1.0
        XCTAssertGreaterThan(mapping.cutoffHz(.ballBall, impulse: hard), 2 * mapping.cutoffHz(.ballBall, impulse: soft))
        XCTAssertGreaterThan(mapping.layerBlend(.ballBall, impulse: hard).lower, mapping.layerBlend(.ballBall, impulse: soft).lower)
        XCTAssertGreaterThan(mapping.transient(speed: 5), mapping.transient(speed: 0.3))
    }

    func breakEvents() -> [AudioEvent] {
        let table = TableSpec.nineFoot, R = table.ballRadius
        let balls = [Ball(id: 0, position: SIMD3(0.635, 0.635, R))] + Rack.triangle(apex: SIMD2(1.905, 0.635), radius: R)
        let r = Simulation(table: table, parameters: PhysicsParameters()).run(balls: balls, strike: CueStrike(aimAngle: 0, cueSpeed: 7))
        return AudioEventBuilder.events(from: r.collisions, shotId: 42)
    }

    /// A2: lịch phát xác định.
    func testScheduleIsDeterministic() {
        let events = breakEvents()
        let s = AudioScheduler()
        let pose = ListenerPose(position: SIMD2(0.2, 0.635), yaw: 0)
        XCTAssertEqual(s.schedule(events, listener: pose), s.schedule(events, listener: pose))
        XCTAssertFalse(s.schedule(events, listener: pose).isEmpty)
    }

    /// A3: cú phá bi không tràn (đỉnh ≤ −1 dBFS) và không vượt giới hạn giọng.
    func testBreakDoesNotClipOrExceedVoices() {
        let events = breakEvents()
        let s = AudioScheduler()
        let voices = s.schedule(events, listener: ListenerPose(position: SIMD2(0.2, 0.635), yaw: 0))
        for v in voices {
            let active = voices.filter { v.startTime - $0.startTime >= 0 && v.startTime - $0.startTime < s.config.voiceDuration }
            XCTAssertLessThanOrEqual(active.count, s.config.maxVoices)
        }
        let out = OfflineRenderer().render(voices) { PlaceholderSynth.render($0) }
        XCTAssertLessThanOrEqual(out.peakDB, -1 + 1e-6)
        XCTAssertGreaterThan(out.frames, 0)
    }

    /// Replay chậm: thời điểm giãn đúng tỉ lệ, không đổi thứ tự.
    func testSlowMotionStretchesTime() {
        let events = breakEvents()
        let s = AudioScheduler()
        let pose = ListenerPose(position: SIMD2(0.2, 0.635), yaw: 0)
        let normal = s.schedule(events, listener: pose)
        let slow = s.schedule(events, listener: pose, rate: 0.25)
        guard let firstSlow = slow.first, let match = normal.first(where: { $0.sourceEvent == firstSlow.sourceEvent }) else {
            return XCTFail("thiếu giọng")
        }
        XCTAssertEqual(firstSlow.startTime, match.startTime * 4, accuracy: 1e-9)
    }

    /// A5: mọi mẫu có giấy phép thương mại và đủ loại × lớp × biến thể.
    func testPlaceholderLibraryLicensed() throws {
        let lib = SampleLibrary.placeholder()
        XCTAssertNoThrow(try lib.validate(layers: mapping.layers, variants: SchedulerConfig().variants))
        XCTAssertTrue(lib.isPlaceholder)
        var bad = lib
        bad.entries[0].license.commercialUse = false
        XCTAssertThrowsError(try bad.validate(layers: mapping.layers, variants: SchedulerConfig().variants))
    }

    func testSynthIsDeterministicAndBounded() {
        let id = SampleID(kind: .ballBall, layer: 3, variant: 1)
        let a = PlaceholderSynth.render(id), b = PlaceholderSynth.render(id)
        XCTAssertEqual(a, b)
        XCTAssertLessThanOrEqual(a.map { abs($0) }.max() ?? 0, 0.9001)
    }

    func testPanFollowsListener() {
        let pose = ListenerPose(position: SIMD2(0, 0), yaw: 0) // nhìn theo +x, bên trái là +y
        XCTAssertLessThan(pose.spatial(SIMD3(1, 0.5, 0)).pan, 0)   // bên trái → pan âm
        XCTAssertGreaterThan(pose.spatial(SIMD3(1, -0.5, 0)).pan, 0)
    }
}
