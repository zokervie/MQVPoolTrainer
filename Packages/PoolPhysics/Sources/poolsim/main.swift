// poolsim — chạy PoolPhysics trên các kịch bản JSON (Tools/validation, tầng 2 đối chứng).
// Dùng: swift run -c release --package-path Packages/PoolPhysics poolsim <vào.json> <ra.json>
import Foundation
import PoolPhysics

struct ScenarioFile: Codable {
    struct TableIn: Codable { var length: Double; var width: Double; var ballRadius: Double; var ballMass: Double }
    struct BallIn: Codable { var id: Int; var r: [Double]; var v: [Double]; var w: [Double] }
    struct Shot: Codable { var id: Int; var category: String; var balls: [BallIn] }
    var table: TableIn
    var params: PhysicsParameters
    var shots: [Shot]
}

struct ResultFile: Codable {
    struct BallOut: Codable { var id: Int; var x: Double; var y: Double; var pocketed: Bool }
    struct Shot: Codable {
        var id: Int
        var status: String
        var final: [BallOut]
        var ballBall: Int
        var cushion: Int
        var duration: Double
    }
    var shots: [Shot]
}

let args = CommandLine.arguments

// Chế độ đo hiệu năng (bản release): 200 cú phá có seed; báo p50/p95/max và số sự kiện.
if args.count == 2, args[1] == "--bench" {
    let table = TableSpec.nineFoot, R = table.ballRadius
    let sim = Simulation(table: table, parameters: PhysicsParameters())
    var rng = SplitMix64(seed: 2026)
    var times: [Double] = [], events: [Int] = [], limited = 0
    for k in 0..<250 {
        let balls = [Ball(id: 0, position: SIMD3(0.635, 0.635 + (rng.unit() - 0.5) * 0.3, R))]
            + Rack.triangle(apex: SIMD2(1.905, 0.635), radius: R, gap: 2e-4)
        let strike = CueStrike(aimAngle: (rng.unit() - 0.5) * 0.08, cueSpeed: 4 + rng.unit() * 4,
                               tipVertical: (rng.unit() - 0.5) * 0.4)
        let t0 = DispatchTime.now().uptimeNanoseconds
        let r = sim.run(balls: balls, strike: strike)
        let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6
        if k >= 50 { times.append(ms); events.append(r.trajectory.snapshots.count) }   // bỏ 50 cú khởi động
        if r.status != .completed { limited += 1 }
    }
    times.sort(); events.sort()
    func q(_ a: [Double], _ p: Double) -> Double { a[min(a.count - 1, Int(Double(a.count - 1) * p))] }
    print(String(format: "REPORT: H1 bench (release, CI macOS runner — not iPhone): 200 breaks p50 %.2f ms, p95 %.2f ms, max %.2f ms; events median %d, max %d; event-limit hits %d",
                 q(times, 0.5), q(times, 0.95), times.last!, events[events.count / 2], events.last!, limited))
    exit(0)
}

guard args.count == 3 else {
    FileHandle.standardError.write("dùng: poolsim <vào.json> <ra.json>\n".data(using: .utf8)!)
    exit(2)
}
let input = try JSONDecoder().decode(ScenarioFile.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let spec = TableSpec(length: input.table.length, width: input.table.width,
                     ballRadius: input.table.ballRadius, ballMass: input.table.ballMass)
let sim = Simulation(table: spec, parameters: input.params)

var out: [ResultFile.Shot] = []
for shot in input.shots {
    let balls = shot.balls.map { b -> Ball in
        var ball = Ball(id: b.id, position: SIMD3(b.r[0], b.r[1], spec.ballRadius),
                        velocity: SIMD3(b.v[0], b.v[1], 0), angularVelocity: SIMD3(b.w[0], b.w[1], b.w[2]))
        ball.state = ball.classified(radius: spec.ballRadius)
        return ball
    }
    let (traj, records, status) = sim.simulate(balls)
    let final = traj.snapshots.last!.balls.map {
        ResultFile.BallOut(id: $0.id, x: $0.position.x, y: $0.position.y, pocketed: $0.state == .pocketed)
    }
    out.append(ResultFile.Shot(id: shot.id, status: status == .completed ? "completed" : "eventLimit",
                               final: final,
                               ballBall: records.filter { $0.kind == .ballBall }.count,
                               cushion: records.filter { $0.kind == .ballCushion || $0.kind == .ballJaw }.count,
                               duration: traj.duration))
}
let enc = JSONEncoder()
enc.outputFormatting = [.prettyPrinted, .sortedKeys]
try enc.encode(ResultFile(shots: out)).write(to: URL(fileURLWithPath: args[2]))
print("poolsim: \(out.count) kịch bản")
