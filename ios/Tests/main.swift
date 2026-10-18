import Foundation

// Kiểm thử engine Swift (chạy trên macOS bằng swiftc, không cần Xcode project):
//   swiftc -O ios/PoolTrainer/Core/*.swift ios/Tests/main.swift -o coretests && ./coretests ios/Tests/fixture.json
// 1) Đối chiếu từng cú với engine web (fixture.json sinh bởi make-fixture.mjs).
// 2) Các định luật vật lý như test/physics.test.js.
// 3) Mọi cú mẫu của bài tập đều thành công.

var failures = 0, passes = 0
func check(_ cond: Bool, _ name: String, _ detail: @autoclosure () -> String = "") {
    if cond { passes += 1 } else { failures += 1; print("✗ \(name) \(detail())") }
}
let deg = { (r: Double) in r * 180 / .pi }

// MARK: 1. Đối chiếu với bản web
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ios/Tests/fixture.json"
let data = try! Data(contentsOf: URL(fileURLWithPath: path))
let fx = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

for e in fx["demos"] as! [[String: Any]] {
    let id = e["drill"] as! String, si = e["stage"] as! Int
    let dr = drillById(id)!
    let st = buildStage(dr, si, seed: 12345)
    let name = "\(id)#\(si + 1)"
    // vị trí bày bi
    if let c = e["cue"] as? [String: Double], let cue = st.cue {
        check(abs(c["x"]! - cue.x) < 1e-9 && abs(c["z"]! - cue.z) < 1e-9, "\(name) vị trí bi cái", "\(c) vs \(cue)")
    }
    let jb = e["balls"] as! [[String: Any]]
    check(jb.count == st.balls.count, "\(name) số bi")
    for (j, b) in zip(jb, st.balls) {
        check(j["id"] as! Int == b.id && abs((j["x"] as! Double) - b.p.x) < 1e-9 && abs((j["z"] as! Double) - b.p.z) < 1e-9, "\(name) bi \(b.id)")
    }
    guard let jdir = e["dir"] as? Double, let demo = st.demo, let cue = st.cue else { continue }
    let d = demoShot(st)!
    check(abs(d.dir - jdir) < 1e-7, "\(name) hướng cú mẫu", "\(d.dir) vs \(jdir)")
    check(d.ok == (e["ok"] as! Bool), "\(name) kết quả cú mẫu")
    check(d.ok, "\(name) cú mẫu phải thành công")
    let sim = Simulation([Ball(0, cue)] + st.balls.map { Ball($0.id, $0.p) })
    sim.trackRotation = false
    sim.strike(0, dir: jdir, speed: demo.speed, a: demo.a, b: demo.b, elev: 0, squirt: 0.02)
    sim.runUntilRest(20, dt: 1.0 / 1500)
    check(sim.events.count == e["events"] as! Int, "\(name) số sự kiện", "\(sim.events.count) vs \(e["events"]!)")
    for f in e["final"] as! [[String: Any]] {
        let b = sim.ball(f["id"] as! Int)!
        let dd = hypot(b.x - (f["x"] as! Double), b.z - (f["z"] as! Double))
        check(dd < 1e-6 && b.pocketed == (f["pocketed"] as! Bool), "\(name) vị trí cuối bi \(b.id)", "lệch \(dd)")
    }
}
for s in fx["shots"] as! [[String: Any]] {
    let sim = Simulation([Ball(0, -0.4, 0.1), Ball(1, 0.3, 0.25), Ball(2, 0.6, -0.2)])
    sim.strike(0, dir: s["dir"] as! Double, speed: s["speed"] as! Double, a: s["a"] as! Double, b: s["b"] as! Double,
               elev: s["elev"] as! Double, squirt: s["sq"] as! Double)
    sim.runUntilRest(20)
    check(sim.events.count == s["events"] as! Int, "cú tự do \(s["dir"]!) số sự kiện", "\(sim.events.count) vs \(s["events"]!)")
    for f in s["final"] as! [[String: Any]] {
        let b = sim.ball(f["id"] as! Int)!
        let dd = hypot(b.x - (f["x"] as! Double), b.z - (f["z"] as! Double))
        check(dd < 1e-6 && b.pocketed == (f["pocketed"] as! Bool), "cú tự do \(s["dir"]!) bi \(b.id)", "lệch \(dd)")
        let q = f["q"] as! [Double]
        check(abs(q[0] - b.q.x) + abs(q[1] - b.q.y) + abs(q[2] - b.q.z) + abs(q[3] - b.q.w) < 1e-5, "cú tự do \(s["dir"]!) quaternion bi \(b.id)")
    }
}

// MARK: 2. Định luật vật lý
do { // trượt rồi lăn với 5/7 vận tốc
    let s = Simulation([Ball(0, -0.8, 0)]); s.strike(0, dir: 0, speed: 2)
    for _ in 0..<2000 { s.step() }
    let b = s.ball(0)!
    check(abs(b.w.z + b.vx / R) < 1e-6 && b.vx < 2 * 5 / 7 && b.vx > 2 * 5 / 7 - 0.3, "trượt → lăn 5/7", "vx=\(b.vx)")
}
do { let s = Simulation([Ball(0, 0, 0)]); s.strike(0, dir: 0, speed: 1.5, b: 0.4); let b = s.ball(0)!; check(abs(b.vx + R * b.w.z) < 1e-9, "đánh 0,4R lăn ngay") }
do { // stop shot
    let cb = Ball(0, -0.3, 0), ob = Ball(1, 0, 0); let s = Simulation([cb, ob])
    s.strike(0, dir: 0, speed: 2, b: -0.22)
    for _ in 0..<40000 { s.step(); if s.events.cushions(of: 1).count > 0 || !s.moving { break } }
    check(abs(cb.x + 2 * R) < 0.05 && ob.x > 0.5, "bi dừng", "cb.x=\(cb.x)")
}
do { // quy tắc 90°
    let cb = Ball(0, -0.4, 0), ob = Ball(1, 0, R); let s = Simulation([cb, ob])
    s.strike(0, dir: 0, speed: 2.5, b: -0.1)
    for _ in 0..<2000 { s.step(); if s.events.firstCueHit != nil { break } }
    for _ in 0..<5 { s.step() }
    let between = abs(deg(atan2(cb.vz, cb.vx) - atan2(ob.vz, ob.vx)))
    check(abs(between - 90) < 8, "quy tắc 90°", "\(between)")
}
do { // english phải bật về bên phải sau băng
    func run(_ a: Double) -> Double {
        let cb = Ball(0, 0.5, 0); let s = Simulation([cb]); s.strike(0, dir: 0, speed: 1.5, a: a, squirt: 0)
        for _ in 0..<20000 { s.step(); if !s.events.cushions(of: 0).isEmpty { break } }
        for _ in 0..<300 { s.step() }
        return cb.vz
    }
    check(run(0.5) > 0.05 && run(-0.5) < -0.05 && abs(run(0)) < 1e-6, "english đổi góc nảy")
}
do { // quãng đường lăn
    let cb = Ball(0, -1.1, 0); let s = Simulation([cb]); s.strike(0, dir: 0, speed: speedForDistance(1.5), b: 0.4); s.runUntilRest()
    check(abs(cb.x - 0.4) < 0.03, "v = √(2μgd)", "x=\(cb.x)")
}
do { // phá 15 bi: không bi nào ra ngoài bàn
    var balls = [Ball(0, -0.635, 0)]
    for b in rackBalls("8") { balls.append(Ball(b.id, b.p)) }
    let s = Simulation(balls); s.strike(0, dir: 0, speed: 8); s.runUntilRest(30)
    check(s.balls.allSatisfy { $0.pocketed || (abs($0.x) <= TL / 2 && abs($0.z) <= TW / 2) } && !s.moving, "phá bi 15 bi")
}

// MARK: 3. Bài ngẫu nhiên: nhiều seed đều dựng được và có hướng gợi ý
for seed in [UInt32(1), 7, 99, 2024, 123456789] {
    let st = buildStage(drillById("a-random")!, 0, seed: seed)
    let h = solveHint(st.hint, cue: st.cue, ballPos: { id in st.balls.first { $0.id == id }?.p })
    check(h != nil && st.cue != nil, "a-random seed \(seed)")
}

// MARK: 4. Hồ sơ bàn các hãng
for t in TableSpec.presets {
    applyTable(t)
    check(CUSHIONS.count == 18 && POCKETS.count == 6, "\(t.id) hình học")
    check(abs(CORNER_MOUTH - t.cornerMouth) < 1e-12 && TL == t.length, "\(t.id) áp dụng thông số")
    // bi thẳng vào lỗ góc dưới phải
    let p = pocketById("c11")!
    let s = Simulation([Ball(0, 0, 0)]); s.strike(0, dir: atan2(p.mouth.z, p.mouth.x), speed: 2, b: 0.3); s.runUntilRest()
    check(s.ball(0)!.pocketed, "\(t.id) bi thẳng vào lỗ góc")
    // bi chạy dọc sát băng vào lỗ góc
    let s2 = Simulation([Ball(0, 0.3, TW / 2 - R - 0.001)]); s2.strike(0, dir: 0, speed: 2, b: 0.3); s2.runUntilRest()
    check(s2.ball(0)!.pocketed, "\(t.id) bi sát băng vào lỗ góc")
    // phá 15 bi: không bi nào văng ra ngoài
    var balls = [Ball(0, HEAD_SPOT)]
    for b in rackBalls("8") { balls.append(Ball(b.id, b.p)) }
    let s3 = Simulation(balls); s3.strike(0, dir: 0, speed: 8); s3.runUntilRest(30)
    check(s3.balls.allSatisfy { $0.pocketed || (abs($0.x) <= TL / 2 && abs($0.z) <= TW / 2) } && !s3.moving, "\(t.id) phá bi")
    // mọi bài tập dựng được trên bàn này, bi nằm trong bàn và không chồng nhau
    for d in DRILLS { for i in 0..<d.stageCount {
        let st = buildStage(d, i, seed: 99)
        let all = (st.cue.map { [$0] } ?? []) + st.balls.map { $0.p }
        let inside = all.allSatisfy { abs($0.x) < TL / 2 - R + 1e-9 && abs($0.z) < TW / 2 - R + 1e-9 }
        check(inside, "\(t.id) \(d.id)#\(i + 1) bi trong bàn")
    } }
    // độ nảy băng (WPA: bi từ điểm đầu bàn qua điểm chân bàn, lực chắc, đi 4–4,5 chiều dài bàn)
    let s4 = Simulation([Ball(0, HEAD_SPOT)]); s4.strike(0, dir: 0, speed: 3.6); s4.runUntilRest(40)
    var travel = 0.0; do { let s5 = Simulation([Ball(0, HEAD_SPOT)]); s5.strike(0, dir: 0, speed: 3.6)
        var last = s5.ball(0)!.pos
        for _ in 0..<80000 { s5.step(); let b = s5.ball(0)!; if b.pocketed { break }; travel += b.pos.dist(last); last = b.pos; if !s5.moving { break } } }
    print("ℹ︎ \(t.id): v=3,6 m/s đi \(vn(travel / TL, 2)) chiều dài bàn")
}
applyTable(.standard)

// MARK: 5. Bài tập JSON (định dạng bộ đặc tả)
let jdir = URL(fileURLWithPath: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "ios/Drills")
DrillLibrary.reload(bundleDir: jdir)
check(DrillLibrary.custom.count >= 3 && DrillLibrary.errors.isEmpty, "đọc bài JSON", "\(DrillLibrary.custom.count) bài, lỗi: \(DrillLibrary.errors)")
for d in DrillLibrary.custom {
    let st = buildStage(d, 0, seed: 5)
    check(st.cue != nil && solveHint(st.hint, cue: st.cue, ballPos: { id in st.balls.first { $0.id == id }?.p }) != nil, "\(d.id) dựng bài")
    let j = JDrill.from(d)!
    let back = try! JDrill.decode(j.encoded())
    check(back == j, "\(d.id) xuất/nhập JSON giữ nguyên")
}
for d in DRILLS where d.generate == nil { if let j = JDrill.from(d) { check((try? j.toDrill()) != nil, "\(d.id) xuất sang JSON đọc lại được") } }

// MARK: 6. Phân tích cú đánh
do {
    applyTable(.standard)
    let st = buildStage(drillById("a-half")!, 0, seed: 1)
    let before = [Ball(0, st.cue!)] + st.balls.map { Ball($0.id, $0.p) }
    let h = solveHint(st.hint, cue: st.cue, ballPos: { id in st.balls.first { $0.id == id }?.p })!
    let tp = pocketAimPoint(pocketById(POCKET_IDS.TR)!)
    let fb = analyzeShot(before: before, params: ShotParams(dir: h.dir, speed: 2.2, a: 0, b: 0.2, elev: 0, squirt: 0.02),
                         idealDir: h.dir, targetBall: 1, targetPoint: tp)
    check(abs(fb.aimErrorDeg ?? 9) < 1e-9, "phân tích: sai số ngắm 0 khi đánh đúng hướng gợi ý")
    check(abs((fb.cutDeg ?? 0) - 30) < 2, "phân tích: góc cắt ≈ 30°", "\(fb.cutDeg ?? -1)")
    check(fb.throwDeg != nil && abs(fb.throwDeg!) < 4, "phân tích: throw vài độ", "\(fb.throwDeg ?? -1)")
    check(abs(fb.obMissMM ?? 99) < 25, "phân tích: bi mục tiêu đi gần đúng lỗ", "\(fb.obMissMM ?? -1) mm")
    check(abs(SpeedScale.level(speed: 2.0) - 3) < 1e-9 && abs(SpeedScale.level(speed: 8) - 7) < 1e-9, "thang lực 1–7")
}

print("\(passes) đạt, \(failures) lỗi")
exit(failures == 0 ? 0 : 1)
