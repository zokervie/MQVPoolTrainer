import Foundation

/// Thang lực 1–7 (docs/04-drills.md của bộ đặc tả): mỗi mức gắn với một tốc độ bi cái cố định (m/s).
enum SpeedScale {
    static let speeds: [Double] = [0.8, 1.3, 2.0, 3.0, 4.3, 6.0, 8.0]
    static func speed(level: Int) -> Double { speeds[min(max(level, 1), 7) - 1] }
    /// Mức (có phần lẻ) ứng với một tốc độ – nội suy giữa hai mức gần nhất.
    static func level(speed v: Double) -> Double {
        if v <= speeds[0] { return max(0.5, v / speeds[0]) }
        for i in 1..<speeds.count where v <= speeds[i] {
            return Double(i) + (v - speeds[i - 1]) / (speeds[i] - speeds[i - 1])
        }
        return 7
    }
}

/// Thông số một cú đánh (đủ để phát lại y hệt – mô phỏng deterministic).
struct ShotParams: Equatable {
    var dir: Double
    var speed: Double
    var a: Double
    var b: Double
    var elev: Double      // rad
    var squirt: Double
}

/// Kết quả phân tích cú vuốt (StrokeAnalyzer của bộ đặc tả): lệch ngang và ngắt cơ.
struct StrokeInfo: Equatable {
    var lateralRatio = 0.0        // tốc độ ngang / tốc độ đẩy tại vạch chạm (0 = thẳng tuyệt đối)
    var followThrough = 1.0       // tốc độ tại vạch / tốc độ đẩy lớn nhất (<1 = ngắt cơ, giảm tốc trước vạch)
}

/// Số liệu sau cú đánh (chỉ hiện SAU cú đánh – docs/05-feedback.md).
struct ShotFeedback: Equatable {
    var params: ShotParams
    var level: Double
    var rollLengths: Double             // nếu lăn thuần: đi được bao nhiêu chiều dài bàn
    var stroke: StrokeInfo? = nil
    var aimErrorDeg: Double? = nil      // hướng cơ − hướng lý tưởng (độ, + = lệch sang phải người đánh)
    var obErrorDeg: Double? = nil       // hướng bi mục tiêu − hướng tới điểm nhắm ở lỗ (+ = lệch phải)
    var obMissMM: Double? = nil         // độ lệch quy ra mm tại miệng lỗ
    var throwDeg: Double? = nil         // góc giữa hướng bi mục tiêu và đường nối tâm lúc va
    var cutDeg: Double? = nil           // góc cắt thực tế
    var firstRail: (rail: Rail, diamond: Double)? = nil
    var predictedRailDiamond: Double? = nil
    var cueRails = 0
    var cueTravel = 0.0                 // quãng bi cái đi (m)
    var zoneMissCM: Double? = nil

    static func == (l: ShotFeedback, r: ShotFeedback) -> Bool { l.params == r.params && l.level == r.level && l.cueTravel == r.cueTravel }
}

/// Đọc số nút (0..8 băng dài, 0..4 băng ngắn) của một điểm chạm băng theo đường nút.
func railDiamond(_ p: P2, _ rail: Rail) -> Double {
    let f = toRailFrame(p)
    switch rail {
    case .top, .bottom: return f.dx
    case .left, .right: return f.dz
    case .jaw: return f.dx
    }
}

/// Mô phỏng lại cú đánh từ trạng thái trước cú để đo các đại lượng (không ảnh hưởng ván đang chơi).
/// - idealDir: hướng cơ "đúng" (từ lời giải gợi ý), targetBall/targetPoint: bi mục tiêu và điểm nhắm ở lỗ.
func analyzeShot(before: [Ball], params p: ShotParams, idealDir: Double?, targetBall: Int?, targetPoint: P2?,
                 predictedRail: P2? = nil, zone: Zone? = nil) -> ShotFeedback {
    let sim = Simulation(before.map { $0.clone() })
    sim.trackRotation = false
    sim.strike(0, dir: p.dir, speed: p.speed, a: p.a, b: p.b, elev: p.elev, squirt: p.squirt)
    var fb = ShotFeedback(params: p, level: SpeedScale.level(speed: p.speed),
                          rollLengths: p.speed * p.speed / (2 * PHYS.muRoll * G) / TL)
    if let ideal = idealDir {
        var d = (p.dir - ideal) * 180 / .pi
        while d > 180 { d -= 360 }; while d < -180 { d += 360 }
        fb.aimErrorDeg = d
    }
    guard let cb = sim.ball(0) else { return fb }
    var last = cb.pos
    var hitDone = false, measured = false, stepsAfterHit = 0
    var impactCue = P2(0, 0), impactOB = P2(0, 0), obId: Int? = nil
    var railDone = false
    let maxSteps = Int(25 / PHYS.dt)
    for _ in 0..<maxSteps {
        let n0 = sim.events.count
        sim.step()
        if !cb.pocketed { fb.cueTravel += cb.pos.dist(last); last = cb.pos }
        if sim.events.count > n0 {
            for e in sim.events[n0...] {
                switch e {
                case .hit(_, let a, let b, _) where !hitDone && (a == 0 || b == 0):
                    hitDone = true; obId = a == 0 ? b : a
                    if let ob = sim.ball(obId!) { impactCue = cb.pos; impactOB = ob.pos }
                case .cushion(_, 0, let rail, _) where !railDone && rail != .jaw:
                    railDone = true
                    // điểm chạm trên mũi băng → chiếu ra đường nút
                    var q = cb.pos
                    switch rail {
                    case .top: q.z = -TW / 2
                    case .bottom: q.z = TW / 2
                    case .left: q.x = -TL / 2
                    case .right: q.x = TL / 2
                    case .jaw: break
                    }
                    fb.firstRail = (rail, railDiamond(projectToRailLine(q, rail), rail))
                default: break
                }
            }
        }
        if hitDone && !measured {
            stepsAfterHit += 1
            if stepsAfterHit == 4, let id = obId, let ob = sim.ball(id) {
                measured = true
                let vdir = atan2(ob.vz, ob.vx)
                let n = impactOB - impactCue
                let lineOfCenters = atan2(n.z, n.x)
                // chỉ đo throw/góc cắt cho cú chạm 1 bi tách biệt (cú phá / chùm bi: số đo vô nghĩa)
                let isolated = sim.events.filter { if case .hit = $0 { return true }; return false }.count == 1
                let th = wrapDeg((vdir - lineOfCenters) * 180 / .pi)
                if isolated && abs(th) < 15 {
                    fb.throwDeg = th
                    let c0 = before.first { $0.id == 0 }!
                    let inDir = atan2(impactCue.z - c0.z, impactCue.x - c0.x)
                    fb.cutDeg = abs(wrapDeg((lineOfCenters - inDir) * 180 / .pi))
                }
                if id == targetBall, let tp = targetPoint {
                    let want = atan2(tp.z - ob.z, tp.x - ob.x)
                    let e = wrapDeg((vdir - want) * 180 / .pi)
                    fb.obErrorDeg = e
                    fb.obMissMM = tan(e * .pi / 180) * ob.pos.dist(tp) * 1000
                }
            }
        }
        if !sim.moving { break }
    }
    fb.cueRails = sim.events.cushions(of: 0).filter { $0.rail != .jaw }.count
    if let pr = predictedRail, let fr = fb.firstRail { fb.predictedRailDiamond = railDiamond(projectToRailLine(pr, fr.rail), fr.rail) }
    if let z = zone, !cb.pocketed { fb.zoneMissCM = max(0, cb.pos.dist(z.c) - z.r) * 100 }
    return fb
}

private func wrapDeg(_ d0: Double) -> Double { var d = d0; while d > 180 { d -= 360 }; while d < -180 { d += 360 }; return d }

/// Điểm chạm băng (mũi băng / đường tâm bi) → điểm tương ứng trên đường nút (mặt gỗ), cùng toạ độ dọc băng.
func projectToRailLine(_ p: P2, _ rail: Rail) -> P2 {
    switch rail {
    case .top: return P2(p.x, -TW / 2 - DIAMOND_OFF)
    case .bottom: return P2(p.x, TW / 2 + DIAMOND_OFF)
    case .left: return P2(-TL / 2 - DIAMOND_OFF, p.z)
    case .right: return P2(TL / 2 + DIAMOND_OFF, p.z)
    case .jaw: return p
    }
}

/// Thống kê một chuỗi số (thử thách ổn định lực / kiểm tra ngắm).
struct Stats1D {
    let values: [Double]
    var mean: Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
    var sd: Double {
        guard values.count > 1 else { return 0 }
        let m = mean
        return (values.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(values.count - 1)).squareRoot()
    }
    var meanAbs: Double { values.isEmpty ? 0 : values.map(abs).reduce(0, +) / Double(values.count) }
}
