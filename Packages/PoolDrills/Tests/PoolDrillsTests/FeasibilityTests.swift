import XCTest
import simd
import PoolPhysics
@testable import PoolDrills

/// Mỗi bài tập đi kèm app phải làm được trong mô hình vật lý: với lực và điểm chạm theo thẻ hướng dẫn,
/// tồn tại một khoảng hướng ngắm đạt mọi điều kiện. Báo độ rộng khoảng (độ khó) cho từng bài.
final class FeasibilityTests: XCTestCase {

    func loadDrills() throws -> [(String, Drill)] {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../Drills").standardized
        return try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { ($0.lastPathComponent, try DrillLoader.load(Data(contentsOf: $0))) }
    }

    /// Hướng ban đầu để quét: về bi mục tiêu đầu tiên, hoặc về điểm băng / vùng đích nếu bài chỉ có bi cái.
    func startAim(_ d: Drill, _ balls: [Ball]) -> Double {
        let cue = balls.first { $0.id == 0 }!.position
        let t = d.tableSpec
        var target: SIMD2<Double>?
        if let ob = balls.first(where: { $0.id != 0 }) { target = SIMD2(ob.position.x, ob.position.y) }
        else if let m = d.danhDau.first(where: { $0.loai == "diem_bang" }), let k = m.kimCuong {
            let a = k * t.diamondSize
            switch m.canh {
            case "dai_duoi": target = SIMD2(a, 0)
            case "dai_tren": target = SIMD2(a, t.width)
            case "ngan_trai": target = SIMD2(0, a)
            default: target = SIMD2(t.length, a)
            }
        } else if let z = d.targetZones.first { target = z.center }
        let p = target ?? SIMD2(cue.x + 1, cue.y)
        return atan2(p.y - cue.y, p.x - cue.x)
    }

    func testEveryDrillIsAchievable() throws {
        var failures: [String] = []
        for (file, d) in try loadDrills() {
            let balls = d.initialBalls()
            let sim = Simulation(table: d.tableSpec, parameters: PhysicsParameters())
            let aim = startAim(d, balls)
            let window = AimWindow.search(simulation: sim, balls: balls, strike: d.guideStrike(aimAngle: aim),
                                          halfRange: 0.35, step: 0.003) { d.evaluate($0).success }
            if let w = window {
                print(String(format: "REPORT: drill %@ achievable, window %.2f° wide, center %+.2f° from start aim",
                             file, w.width * 180 / .pi, (w.center - aim) * 180 / .pi))
            } else {
                failures.append(file)
                print("REPORT: drill \(file) NOT achievable with guide speed/tip")
            }
        }
        XCTAssertTrue(failures.isEmpty, "Bài không làm được: \(failures)")
    }
}
