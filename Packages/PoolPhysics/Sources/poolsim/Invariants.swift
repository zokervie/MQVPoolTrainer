// R1.7 — Kiểm tra M2–M6 (UPGRADE.md 3.1) trên bộ cú ngẫu nhiên có seed, chạy bản release.
// Dùng: poolsim --invariants <số cú> <seed> [chỉ số cú để tái hiện riêng]
// Mỗi cú có seed riêng = seed gốc + chỉ số → một cú lỗi tái hiện được độc lập.
import Foundation
import PoolPhysics
import simd

/// Một cú trong bộ kiểm tra: vị trí bi + cú đánh, sinh xác định từ seed của cú.
struct InvariantShot {
    enum Kind: String { case random, cluster, rail, breakShot }
    let kind: Kind
    let balls: [Ball]
    let strike: CueStrike
}

func makeInvariantShot(index k: Int, baseSeed: UInt64, table: TableSpec) -> InvariantShot {
    var rng = SplitMix64(seed: baseSeed &+ UInt64(k) &* 0x9E37_79B9_7F4A_7C15)
    let R = table.ballRadius
    func free(_ p: SIMD3<Double>, _ balls: [Ball], gap: Double = 1e-4) -> Bool {
        balls.allSatisfy { simd_distance($0.position, p) > 2 * R + gap }
    }
    func randomPoint(margin: Double) -> SIMD3<Double> {
        SIMD3(R + margin + rng.unit() * (table.length - 2 * R - 2 * margin),
              R + margin + rng.unit() * (table.width - 2 * R - 2 * margin), R)
    }
    let strike = { (speedMax: Double) -> CueStrike in
        CueStrike(aimAngle: rng.unit() * 2 * .pi, cueSpeed: 0.3 + rng.unit() * speedMax,
                  tipVertical: (rng.unit() - 0.5) * 1.0, tipHorizontal: (rng.unit() - 0.5) * 1.0)
    }

    // 10% phá bi, 20% cụm bi chạm nhau, 20% bi sát băng, 50% ngẫu nhiên.
    let roll = k % 10
    if roll == 0 {
        let gap = rng.unit() < 0.5 ? 1e-6 : 2e-4
        let cue = Ball(id: 0, position: SIMD3(0.635, 0.635 + (rng.unit() - 0.5) * 0.4, R))
        let rack = Rack.triangle(apex: SIMD2(1.905, 0.635), radius: R, gap: gap)
        let s = CueStrike(aimAngle: (rng.unit() - 0.5) * 0.1, cueSpeed: 3 + rng.unit() * 6,
                          tipVertical: (rng.unit() - 0.5) * 0.8, tipHorizontal: (rng.unit() - 0.5) * 0.4)
        return InvariantShot(kind: .breakShot, balls: [cue] + rack, strike: s)
    }
    if roll == 1 || roll == 2 {
        // Cụm: chuỗi bi gần như chạm nhau (khe 1 µm) — cú combination, bi dính.
        var balls = [Ball(id: 0, position: randomPoint(margin: 0.05))]
        while balls.count < 2 + Int(rng.unit() * 8) {
            let base = balls[Int(rng.unit() * Double(balls.count))].position
            let a = rng.unit() * 2 * .pi
            let p = base + (2 * R + 1e-6) * SIMD3(cos(a), sin(a), 0)
            let inside = p.x > R + 1e-3 && p.x < table.length - R - 1e-3 && p.y > R + 1e-3 && p.y < table.width - R - 1e-3
            if inside && free(p, balls, gap: 1e-7) { balls.append(Ball(id: balls.count, position: p)) }
        }
        return InvariantShot(kind: .cluster, balls: balls, strike: strike(5))
    }
    if roll == 3 || roll == 4 {
        // Bi sát băng (khe 0,5 mm tới 5 mm), cả bi cái.
        var balls: [Ball] = []
        while balls.count < 2 + Int(rng.unit() * 6) {
            let gap = 5e-4 + rng.unit() * 4.5e-3
            var p = randomPoint(margin: 0.02)
            switch Int(rng.unit() * 4) {
            case 0: p.x = R + gap
            case 1: p.x = table.length - R - gap
            case 2: p.y = R + gap
            default: p.y = table.width - R - gap
            }
            if free(p, balls) { balls.append(Ball(id: balls.count, position: p)) }
        }
        return InvariantShot(kind: .rail, balls: balls, strike: strike(6))
    }
    var balls: [Ball] = []
    while balls.count < 2 + Int(rng.unit() * 14) {
        let p = randomPoint(margin: 0.01)
        if free(p, balls) { balls.append(Ball(id: balls.count, position: p)) }
    }
    return InvariantShot(kind: .random, balls: balls, strike: strike(7))
}

func runInvariants(count: Int, baseSeed: UInt64, only: Int?) -> Int32 {
    let table = TableSpec.nineFoot, R = table.ballRadius, m = table.ballMass
    let params = PhysicsParameters()
    let sim = Simulation(table: table, parameters: params)
    let I = 0.4 * m * R * R
    func energy(_ balls: [Ball]) -> Double {
        balls.filter { $0.state != .pocketed }.reduce(0) {
            $0 + 0.5 * m * simd_length_squared($1.velocity) + 0.5 * I * simd_length_squared($1.angularVelocity)
        }
    }
    func overlap(_ balls: [Ball]) -> (Double, Int, Int) {
        var worst = (-Double.infinity, -1, -1)
        let live = balls.filter { $0.state != .pocketed }
        for i in live.indices { for j in (i + 1)..<live.count {
            let d = live[j].position - live[i].position   // 3D: bi nhảy qua bi khác không phải chồng lấn
            let o = 2 * R - simd_length(d)
            if o > worst.0 { worst = (o, live[i].id, live[j].id) }
        } }
        return worst
    }

    let range = only.map { $0..<($0 + 1) } ?? 0..<count
    var m2Fail: [Int] = [], m3Fail: [Int] = [], m4Fail: [Int] = [], m6Fail: [Int] = []
    var worstOverlapEvent = -Double.infinity, worstOverlapDense = -Double.infinity
    var worstEnergyRise = 0.0          // tăng tương đối lớn nhất giữa hai thời điểm liên tiếp
    var events: [Int] = [], denseSamples = 0
    var kinds: [String: Int] = [:]
    let t0 = DispatchTime.now().uptimeNanoseconds

    for k in range {
        let shot = makeInvariantShot(index: k, baseSeed: baseSeed, table: table)
        kinds[shot.kind.rawValue, default: 0] += 1
        let r = sim.run(balls: shot.balls, strike: shot.strike)
        events.append(r.trajectory.snapshots.count)

        // M6: không chạm giới hạn sự kiện.
        if r.status != .completed { m6Fail.append(k) }

        // M2: chạy lại → giống từng bit (va chạm, mọi snapshot).
        let again = sim.run(balls: shot.balls, strike: shot.strike)
        if again.collisions != r.collisions || again.trajectory.snapshots != r.trajectory.snapshots { m2Fail.append(k) }

        // M3 tại mọi sự kiện + M4 qua mọi sự kiện (snapshot đầu đã là trạng thái ngay sau cú cơ).
        var shotWorst = -Double.infinity
        var lastE = Double.infinity, rose = false
        for snap in r.trajectory.snapshots {
            shotWorst = max(shotWorst, overlap(snap.balls).0)
            let e = energy(snap.balls)
            if lastE.isFinite, e > lastE {
                let rel = (e - lastE) / max(lastE, 1e-12)
                worstEnergyRise = max(worstEnergyRise, rel)
                if e > lastE * (1 + 1e-9) + 1e-12 { rose = true }
            }
            lastE = e
        }
        worstOverlapEvent = max(worstOverlapEvent, shotWorst)

        // M3 giữa các sự kiện: lấy mẫu dày 2 ms trên quỹ đạo nội suy (bắt va chạm bị bỏ sót).
        var t = 0.0, lastDenseE = Double.infinity
        let step = 0.002
        while t < r.trajectory.duration {
            let s = r.trajectory.state(at: t)
            let o = overlap(s).0
            shotWorst = max(shotWorst, o)
            worstOverlapDense = max(worstOverlapDense, o)
            let e = energy(s)
            if e > lastDenseE * (1 + 1e-9) + 1e-12 {
                rose = true
                worstEnergyRise = max(worstEnergyRise, (e - lastDenseE) / max(lastDenseE, 1e-12))
            }
            lastDenseE = e
            denseSamples += 1
            t += step
        }
        if shotWorst >= 1e-6 { m3Fail.append(k) }
        if rose { m4Fail.append(k) }

        if only != nil {
            let o = overlap(r.finalBalls)
            print("shot \(k) [\(shot.kind.rawValue)] balls \(shot.balls.count) strike \(shot.strike) status \(r.status) events \(r.trajectory.snapshots.count) duration \(r.trajectory.duration) s; worst overlap \(shotWorst) m; final worst pair \(o)")
        }
    }

    // M5: động lượng ngang cặp bi trong va chạm cô lập, cùng số lượng.
    var m5Worst = 0.0
    var rng = SplitMix64(seed: baseSeed ^ 0x5555)
    for _ in 0..<range.count {
        let ang = rng.unit() * 2 * .pi
        let n = SIMD3(cos(ang), sin(ang), 0)
        let a = Ball(id: 0, position: SIMD3(1, 0.6, R),
                     velocity: SIMD3((rng.unit() - 0.5) * 16, (rng.unit() - 0.5) * 16, 0) + (0.01 + rng.unit() * 8) * n,
                     angularVelocity: SIMD3((rng.unit() - 0.5) * 600, (rng.unit() - 0.5) * 600, (rng.unit() - 0.5) * 600))
        let b = Ball(id: 1, position: a.position + 2 * R * n,
                     velocity: SIMD3((rng.unit() - 0.5) * 2, (rng.unit() - 0.5) * 2, 0),
                     angularVelocity: SIMD3((rng.unit() - 0.5) * 100, (rng.unit() - 0.5) * 100, (rng.unit() - 0.5) * 100))
        // Chỉ xét cặp đang tiến lại gần nhau (điều kiện va chạm).
        guard simd_dot(a.velocity - b.velocity, n) > 0 else { continue }
        let (a2, b2) = BallBallCollision.resolve(a, b, params, mass: m, radius: R)
        let d = (a.velocity + b.velocity) - (a2.velocity + b2.velocity)
        m5Worst = max(m5Worst, max(abs(d.x), abs(d.y)))
    }

    let secs = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e9
    events.sort()
    func list(_ a: [Int]) -> String { a.isEmpty ? "" : " — shots \(a.prefix(10).map(String.init).joined(separator: ","))\(a.count > 10 ? ",…" : "")" }
    let n = range.count
    let mix = kinds.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
    print("REPORT: R1.7 \(n) seeded shots (seed \(baseSeed); \(mix)); events median \(events[events.count / 2]), max \(events.last!); \(denseSamples) dense samples; \(String(format: "%.1f", secs)) s")
    print("REPORT: M2 bit-identical rerun: \(n - m2Fail.count)/\(n)\(list(m2Fail))")
    print(String(format: "REPORT: M3 worst overlap: at events %.3g m, between events (2 ms) %.3g m; shots ≥ 1e-6 m: %d", worstOverlapEvent, worstOverlapDense, m3Fail.count) + list(m3Fail))
    print(String(format: "REPORT: M4 kinetic energy never rises: violations %d, worst relative rise %.3g", m4Fail.count, worstEnergyRise) + list(m4Fail))
    print(String(format: "REPORT: M5 pair momentum (isolated ball–ball): worst |Δp/m| %.3g m/s (limit 1e-9)", m5Worst))
    print("REPORT: M6 event-limit hits: \(m6Fail.count)\(list(m6Fail))")

    let ok = m2Fail.isEmpty && m3Fail.isEmpty && m4Fail.isEmpty && m5Worst <= 1e-9 && m6Fail.isEmpty
    if !ok { print("Error: R1.7 invariants failed (rerun one shot: poolsim --invariants \(count) \(baseSeed) <shot>)") }
    return ok ? 0 : 1
}
