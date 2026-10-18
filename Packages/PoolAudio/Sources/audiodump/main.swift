// audiodump — xuất file WAV để nghe thử âm thanh (CI đẩy lên nhánh shots/zoker).
// Dùng: swift run --package-path Packages/PoolAudio audiodump <thư-mục-ra>
import Foundation
import PoolPhysics
import PoolAudio

func writeWAV(_ interleaved: [Float], channels: Int, sampleRate: Int, to url: URL) throws {
    var data = Data()
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    let bytes = interleaved.count * 2
    data.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + bytes))
    data.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(UInt16(channels))
    u32(UInt32(sampleRate)); u32(UInt32(sampleRate * channels * 2)); u16(UInt16(channels * 2)); u16(16)
    data.append("data".data(using: .ascii)!); u32(UInt32(bytes))
    for x in interleaved { u16(UInt16(bitPattern: Int16(max(-1, min(1, x)) * 32_767))) }
    try data.write(to: url)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "audio")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let scheduler = AudioScheduler()
var renderer = OfflineRenderer()

func render(_ events: [AudioEvent], listener: ListenerPose = ListenerPose(position: SIMD2(0.3, 0.635), yaw: 0)) -> [Float] {
    renderer.render(scheduler.schedule(events, listener: listener)) { PlaceholderSynth.render($0) }.interleaved
}

// 1. Dãy va chạm bi–bi từ rất nhẹ tới rất mạnh, cách nhau 0,6 s.
for kind in [CollisionKind.ballBall, .ballCushion, .cueTip, .ballDrop] {
    let impulses = [0.01, 0.03, 0.1, 0.3, 1.0]
    let events = impulses.enumerated().map { k, j in
        AudioEvent(kind: kind, time: Double(k) * 0.6, position: SIMD3(1.2, 0.635, 0), relativeNormalSpeed: j / 0.17,
                   impulse: j, tangentialSlip: 0, materials: AudioEventBuilder.material(for: kind),
                   sourceIds: [0, k + 1], shotId: 7, index: k)
    }
    try writeWAV(render(events), channels: 2, sampleRate: 44_100, to: out.appendingPathComponent("ladder-\(kind.rawValue).wav"))
}

// 2. Một cú phá bi thật từ bộ giải vật lý.
let table = TableSpec.nineFoot, R = table.ballRadius
let balls = [Ball(id: 0, position: SIMD3(0.635, 0.635, R))] + Rack.triangle(apex: SIMD2(1.905, 0.635), radius: R, gap: 2e-4)
let shot = Simulation(table: table, parameters: PhysicsParameters()).run(balls: balls, strike: CueStrike(aimAngle: 0, cueSpeed: 6))
try writeWAV(render(AudioEventBuilder.events(from: shot.collisions, shotId: 1)), channels: 2, sampleRate: 44_100,
             to: out.appendingPathComponent("break.wav"))

// 3. Cú thẳng vào lỗ ở lực vừa.
let straight = [Ball(id: 0, position: SIMD3(1.0, 0.4, R)), Ball(id: 1, position: SIMD3(1.8, 0.8, R))]
let aim = atan2(0.4, 0.8)
let s2 = Simulation(table: table, parameters: PhysicsParameters()).run(balls: straight, strike: CueStrike(aimAngle: aim, cueSpeed: 1.4))
try writeWAV(render(AudioEventBuilder.events(from: s2.collisions, shotId: 2)), channels: 2, sampleRate: 44_100,
             to: out.appendingPathComponent("medium-shot.wav"))
print("audiodump: \(try FileManager.default.contentsOfDirectory(atPath: out.path).sorted())")
