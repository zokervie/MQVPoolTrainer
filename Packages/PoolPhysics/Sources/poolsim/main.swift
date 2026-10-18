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
