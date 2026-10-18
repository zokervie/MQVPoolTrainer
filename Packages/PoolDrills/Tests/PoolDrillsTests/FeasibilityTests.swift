import XCTest
import simd
import PoolPhysics
@testable import PoolDrills

/// Mỗi bài tập đi kèm app phải làm được trong mô hình vật lý: với điểm chạm theo thẻ hướng dẫn và lực
/// quanh mức hướng dẫn (người chơi điều chỉnh lực liên tục), tồn tại một khoảng hướng ngắm đạt mọi điều kiện.
/// Báo độ rộng khoảng ngắm (độ khó) cho từng bài; bài không làm được thì in gợi ý lực/điểm chạm.
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

    struct Found { var speed: Double; var window: AimWindow }

    func search(_ d: Drill, speeds: [Double], tip: (Double, Double), halfRange: Double = 0.35) -> Found? {
        let balls = d.initialBalls()
        let sim = Simulation(table: d.tableSpec, parameters: PhysicsParameters())
        let aim = startAim(d, balls)
        var best: Found?
        for v in speeds {
            let s = CueStrike(aimAngle: aim, cueSpeed: v, tipVertical: tip.0, tipHorizontal: tip.1)
            if let w = AimWindow.search(simulation: sim, balls: balls, strike: s, halfRange: halfRange, step: 0.004,
                                        succeeds: { d.evaluate($0).success }),
               w.width > (best?.window.width ?? -1) {
                best = Found(speed: v, window: w)
            }
        }
        return best
    }

    func testEveryDrillIsAchievable() throws {
        var failures: [String] = []
        for (file, d) in try loadDrills() {
            let guide = SpeedScale.cueSpeed(level: d.huongDan.luc)
            // Lực trong khoảng ±1 mức quanh mức hướng dẫn.
            let lo = SpeedScale.cueSpeed(level: d.huongDan.luc - 1) * (d.huongDan.luc == 1 ? 0.7 : 1)
            let hi = SpeedScale.cueSpeed(level: d.huongDan.luc + 1)
            let speeds = (0..<9).map { lo * pow(hi / lo, Double($0) / 8) }
            let tip = (d.huongDan.diemCham.doc, d.huongDan.diemCham.ngang)
            if let f = search(d, speeds: speeds, tip: tip) {
                print(String(format: "REPORT: drill %@ OK: window %.2f° at %.2f m/s (guide %.2f, level %d)",
                             file, f.window.width * 180 / .pi, f.speed, guide, SpeedScale.level(forCueSpeed: f.speed)))
            } else {
                failures.append(file)
                // Gợi ý: quét rộng lực và điểm chạm dọc.
                var hint = "none found"
                var bestW = 0.0
                for doc in stride(from: -0.5, through: 0.5, by: 0.1) {
                    let wide = (0..<10).map { 0.35 * pow(4.0 / 0.35, Double($0) / 9) }
                    if let f = search(d, speeds: wide, tip: (doc, tip.1)), f.window.width > bestW {
                        bestW = f.window.width
                        hint = String(format: "doc %+.1f, %.2f m/s (level %d), window %.2f°",
                                      doc, f.speed, SpeedScale.level(forCueSpeed: f.speed), f.window.width * 180 / .pi)
                    }
                }
                print("REPORT: drill \(file) NOT achievable with guide; suggestion: \(hint)")
            }
        }
        XCTAssertTrue(failures.isEmpty, "Bài không làm được: \(failures)")
    }
}
