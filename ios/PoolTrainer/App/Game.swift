import SwiftUI
import UIKit
import QuartzCore

// Điều phối: vòng lặp game, luồng bài tập, luật chơi tự do, dự đoán đường đi (giống src/main.js).

enum Phase { case menu, aim, placing, rolling, result, demo }
enum GameMode { case free8, free9, drill }

struct Toast: Equatable { var msg: String; var kind: Kind; var id = UUID()
    enum Kind { case info, ok, bad }
}

/// Phiếu (sheet) hiển thị trên màn hình.
enum Card: Identifiable {
    case drill(Drill, inGame: Bool)
    case finished(title: String, lead: String, stats: String?, again: String)
    case settings, help, sources
    var id: String {
        switch self {
        case .drill(let d, let g): return "d-\(d.id)-\(g)"
        case .finished(let t, _, _, _): return "f-\(t)"
        case .settings: return "settings"
        case .help: return "help"
        case .sources: return "sources"
        }
    }
}

struct StripBall: Identifiable { let id: Int; let gone: Bool }

struct FreeState { var kind: String; var shots = 0; var fouls = 0; var potted = Set<Int>() }

/// Số liệu bi cái theo thời gian thực (bảng thông số).
struct Telemetry: Equatable { var speed = 0.0, top = 0.0, side = 0.0, sliding = false, vmax = 0.0, rails = 0 }

final class Game: NSObject, ObservableObject {
    // trạng thái hiển thị
    @Published var phase: Phase = .menu
    @Published var mode: GameMode? = nil
    @Published var title = ""
    @Published var ballInHand = false
    @Published var hintOn = true
    @Published var toast: Toast? = nil
    @Published var card: Card? = nil
    @Published var sysInfo: String? = nil
    @Published var settings: Settings { didSet { if settings != oldValue { applySettings(old: oldValue) } } }
    @Published var stats: [String: DrillStat]
    @Published var tick = 0                 // tăng mỗi khi danh sách bi đổi (dải bi)
    @Published var telemetry = Telemetry()
    @Published var slow = false

    // ngắm
    @Published var dir = 0.0 { didSet { if dir != oldValue { previewDirty = true } } }
    @Published var spinA = 0.0 { didSet { previewDirty = true } }
    @Published var spinB = 0.0 { didSet { previewDirty = true } }
    @Published var elev = 0.0 { didSet { previewDirty = true } }      // độ
    @Published var locked = false
    @Published var lastPower = 0.35 { didSet { previewDirty = true } }
    @Published var shownPower: Double? = nil
    var pull = 0.0
    var camYawOffset = 0.0, camLookAround = false

    // bài tập
    private(set) var drill: Drill? = nil
    @Published private(set) var stageIdx = 0
    private(set) var stage: Stage? = nil
    private var stageState = StageState()
    private var free: FreeState? = nil
    var freeSummary: String { free.map { "\($0.shots) cú · \($0.fouls) lỗi" } ?? "" }

    private(set) var sim = Simulation()
    let scene = PoolScene()
    private var link: CADisplayLink?
    private var lastT: CFTimeInterval = 0
    private var previewDirty = true
    private var lastPreview: CFTimeInterval = 0
    private var toastWork: DispatchWorkItem?
    private var frameN = 0
    private var resultToken = 0

    override init() {
        settings = Store.load("mqv-settings", Settings())
        stats = Store.load("mqv-stats", [String: DrillStat]())
        super.init()
        applySettings(old: nil)
        setupBalls(fromDiamond(2, 2), rackBalls("9"))
        scene.cam.pitch = 0.5; scene.cam.dist = 2.2
        link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link?.preferredFramesPerSecond = 60
        link?.add(to: .main, forMode: .common)
        runAutomation()
    }

    /// Kịch bản tự chạy cho kiểm thử trên Simulator (CI chụp màn hình): -auto <bước,...>
    /// Bước: drill:<id> · demo · free:<8|9> · shoot:<lực> · card · menu · view2d · view3d · guide:<n> · wait:<giây>
    private func runAutomation() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-auto"), i + 1 < args.count else { return }
        var t = 1.5
        for step in args[i + 1].split(separator: ",").map(String.init) {
            let parts = step.split(separator: ":").map(String.init)
            if parts[0] == "wait", parts.count > 1 { t += Double(parts[1]) ?? 1; continue }
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                guard let self else { return }
                switch parts[0] {
                case "drill": if let d = drillById(parts[1]) { self.card = nil; self.startDrill(d) }
                case "demo": self.playDemo()
                case "free": self.card = nil; self.startFree(parts.count > 1 ? parts[1] : "9")
                case "shoot": self.ballInHand = false; self.phase = .aim; self.shoot(Double(parts[1]) ?? 0.5)
                case "card": if let d = self.drill { self.card = .drill(d, inGame: true) }
                case "menucard": if let d = drillById(parts[1]) { self.card = .drill(d, inGame: false) }
                case "close": self.card = nil
                case "menu": self.openMenu()
                case "view2d": self.settings.view3D = false
                case "view3d": self.settings.view3D = true
                case "guide": self.settings.guide = Int(parts[1]) ?? 1
                case "light": self.scene.setLightScale(Double(parts[1]) ?? 1, env: parts.count > 2 ? Double(parts[2]) : nil)
                case "hdr": self.scene.setHDR(parts[1] == "1")
                case "spin": self.spinA = Double(parts[1]) ?? 0; self.spinB = Double(parts[2]) ?? 0
                default: break
                }
            }
            t += 0.3
        }
    }

    // MARK: - cài đặt
    private func applySettings(old: Settings?) {
        Store.save("mqv-settings", settings)
        scene.setCloth(settings.clothHex)
        if old?.view3D != settings.view3D { scene.setMode3D(settings.view3D); scene.snapCamera(cueBall) }
        SoundFX.shared.enabled = settings.sound
        SoundFX.shared.haptics = settings.haptics
        refreshLabels()
        previewDirty = true
    }

    func cycleGuide() {
        settings.guide = (settings.guide + 1) % 3
        showToast(["Tắt hỗ trợ ngắm", "Hỗ trợ ngắm: cơ bản (tới điểm chạm)", "Hỗ trợ ngắm: đầy đủ (dự đoán vật lý)"][settings.guide])
    }
    func toggleView() { settings.view3D.toggle() }
    func toggleHint() { hintOn.toggle(); previewDirty = true; showToast(hintOn ? "Hiện đường hệ thống" : "Ẩn đường hệ thống") }

    // MARK: - dựng bàn
    var cueBall: Ball? { sim.ball(0) }

    private func setupBalls(_ cue: P2?, _ balls: [BallSpec]) {
        var list: [Ball] = []
        if let cue { list.append(Ball(0, cue)) }
        for b in balls {
            let nb = Ball(b.id, b.p)
            // xoay ngẫu nhiên để số không cùng một hướng
            let ax = V3(Double.random(in: -1...1), Double.random(in: -1...1), Double.random(in: -1...1))
            let m = max(1e-6, ax.length), ang = Double.random(in: 0..<(2 * .pi))
            nb.q = Quat(x: ax.x / m * sin(ang / 2), y: ax.y / m * sin(ang / 2), z: ax.z / m * sin(ang / 2), w: cos(ang / 2))
            list.append(nb)
        }
        sim = Simulation(list)
        scene.syncBalls(sim.balls)
        scene.updateBalls(sim.balls, dt: 0)
        tick += 1
    }

    private func aimAtDefault() {
        guard let cb = cueBall else { return }
        if let h = currentHint() { dir = h.dir; return }
        var best: Ball? = nil, bd = Double.infinity
        for b in sim.balls where b.id != 0 && !b.pocketed { let d = b.pos.dist(cb.pos); if d < bd { bd = d; best = b } }
        if let best { dir = atan2(best.z - cb.z, best.x - cb.x) }
    }

    private func enterAim() {
        phase = ballInHand ? .placing : .aim
        if settings.autoUnlock { setLock(false) }
        scene.cam.overview = 0
        scene.cam.yaw = dir
        previewDirty = true
        tick += 1
    }

    // MARK: - chơi tự do
    func startFree(_ kind: String) {
        mode = kind == "8" ? .free8 : .free9
        drill = nil; stage = nil
        free = FreeState(kind: kind)
        scene.setZones([])
        setupBalls(fromDiamond(1.6, 2), rackBalls(kind))
        ballInHand = true
        dir = 0; spinA = 0; spinB = 0; elev = 0
        showGame(kind == "8" ? "Tập tự do 8 bi" : "Tập tự do 9 bi")
        enterAim()
        showToast("Kéo bi cái để đặt, rồi khoá cơ và đẩy lực để phá")
    }

    private func freeAfterShot(_ events: [SimEvent]) {
        guard var F = free else { return }
        F.shots += 1
        let potted = events.pottedIds
        for id in potted where id != 0 { F.potted.insert(id) }
        let scratch = potted.contains(0)
        let first = events.firstCueHit?.other
        var foul: String? = nil
        if scratch { foul = "Bi cái rơi lỗ" } else if first == nil { foul = "Không chạm bi nào" }
        if F.kind == "9" && foul == nil {
            let remaining = sim.balls.filter { $0.id != 0 && (!$0.pocketed || potted.contains($0.id)) }.map { $0.id }
            if let lowest = remaining.min(), first != lowest { foul = "Phải chạm bi \(lowest) trước" }
        }
        if let foul {
            F.fouls += 1
            if F.kind == "9" && potted.contains(9) { respot(9) }
            showToast("Lỗi: \(foul) – bi trong tay", .bad); SoundFX.shared.fail()
            if scratch, let cb = cueBall {
                cb.pocketed = false; cb.pocket = nil; cb.pos = fromDiamond(2, 2); cb.vx = 0; cb.vz = 0; cb.w = .zero
                while sim.balls.contains(where: { $0 !== cb && !$0.pocketed && $0.pos.dist(cb.pos) < 2 * R }) { cb.z += 0.06 }
                scene.syncBalls(sim.balls)
            }
            ballInHand = true
        } else {
            ballInHand = false
            let ids = potted.filter { $0 != 0 }
            if !ids.isEmpty { showToast("Vào " + ids.map { "bi \($0)" }.joined(separator: ", "), .ok) }
        }
        free = F
        let left = sim.balls.filter { $0.id != 0 && !$0.pocketed }.count
        let nineDown = F.kind == "9" && (sim.ball(9)?.pocketed ?? false)
        if left == 0 || nineDown {
            card = .finished(title: F.kind == "9" ? "Hết ván 9 bi!" : "Dọn sạch bàn!", lead: "\(F.shots) cú · \(F.fouls) lỗi", stats: nil, again: "Xếp lại")
        }
        enterAim()
    }

    private func respot(_ id: Int) {
        guard let b = sim.ball(id) else { return }
        b.pocketed = false; b.pocket = nil; b.pos = FOOT_SPOT; b.vx = 0; b.vz = 0; b.w = .zero
        while sim.balls.contains(where: { $0 !== b && !$0.pocketed && $0.pos.dist(b.pos) < 2 * R }) { b.x += 0.005 }
        scene.syncBalls(sim.balls)
    }

    // MARK: - bài tập
    func drillStat(_ id: String) -> DrillStat { stats[id] ?? DrillStat() }

    func startDrill(_ d: Drill, stage idx: Int = 0) {
        mode = .drill; drill = d; stageIdx = idx; free = nil
        loadStage()
        showGame(d.title)
    }

    func loadStage() {
        guard let d = drill else { return }
        let st = buildStage(d, stageIdx)
        stage = st; stageState = StageState()
        setupBalls(st.cue, st.balls)
        ballInHand = st.ballInHand
        scene.setZones(st.goal.cueZone.map { [$0] } ?? [])
        spinA = 0; spinB = 0; elev = 0
        aimAtDefault()
        scene.cam.yaw = dir
        refreshLabels()
        enterAim()
    }

    func currentHint() -> HintSolution? {
        guard mode == .drill, let st = stage, let cb = cueBall, !cb.pocketed else { return nil }
        var hint = st.hint
        let pos: (Int) -> P2? = { [weak self] id in
            guard let b = self?.sim.ball(id), !b.pocketed else { return nil }
            return b.pos
        }
        if let clear = st.goal.clear {
            let left = clear.filter { pos($0) != nil }
            guard var id = left.first else { return nil }
            if !st.goal.ordered {
                var bs = Double.infinity
                for i in left {
                    guard let b = pos(i), let p = bestPocket(cb.pos, b) else { continue }
                    let s = cutAngle(cb.pos, b, pocketAimPoint(p)) + b.dist(cb.pos) * 20
                    if s < bs { bs = s; id = i }
                }
            }
            hint = .ghost(ball: id, pocket: nil)
        }
        if case .ghost(_, nil) = hint, st.rack != nil {
            guard let b = pos(1) else { return nil }
            return HintSolution(dir: atan2(b.z - cb.z, b.x - cb.x))
        }
        return solveHint(hint, cue: cb.pos, ballPos: pos)
    }

    private func drillAfterShot(_ events: [SimEvent]) {
        guard let st = stage, let d = drill else { return }
        let res = evaluate(st, events, sim.balls, &stageState)
        if !res.done { showToast(res.msg, res.ok ? .ok : .info); ballInHand = false; enterAim(); return }
        var s = drillStat(d.id)
        s.att += 1
        if res.ok { s.ok += 1; s.streak += 1; s.best = max(s.best, s.streak); SoundFX.shared.ok() } else { s.streak = 0; SoundFX.shared.fail() }
        stats[d.id] = s
        Store.save("mqv-stats", stats)
        showToast(res.msg, res.ok ? .ok : .bad)
        phase = .result
        resultToken += 1
        let token = resultToken
        let last = stageIdx >= d.stageCount - 1
        DispatchQueue.main.asyncAfter(deadline: .now() + (res.ok ? 1.3 : 1.7)) { [weak self] in
            guard let self, self.phase == .result, self.resultToken == token else { return }
            if res.ok && !last {
                self.stageIdx += 1; self.loadStage(); self.showToast("Chặng \(self.stageIdx + 1)/\(d.stageCount)")
            } else if res.ok && last && d.stageCount > 1 {
                self.card = .finished(title: "Hoàn thành bài!", lead: "\(d.title) – cả \(d.stageCount) chặng.",
                                      stats: "Tổng: \(s.ok)/\(s.att) lần thành công · chuỗi tốt nhất \(s.best)", again: "Tập lại từ đầu")
            } else { self.loadStage() }
        }
    }

    /// Nút trên phiếu kết thúc: tập lại.
    func again() {
        if mode == .drill { stageIdx = 0; loadStage() } else if let f = free { startFree(f.kind) }
    }

    func reset() {
        if mode == .drill { loadStage() } else if let f = free { startFree(f.kind) }
    }

    // MARK: - đánh
    static func powerToSpeed(_ p: Double) -> Double { 0.25 + 8.75 * p * p }

    func shoot(_ power0: Double) {
        guard phase == .aim || phase == .placing, let cb = cueBall, !cb.pocketed else { return }
        let power = min(1, max(0.02, power0))
        lastPower = power
        sim.events = []
        sim.strike(0, dir: dir, speed: Game.powerToSpeed(power), a: spinA, b: spinB, elev: elev * .pi / 180, squirt: settings.squirt ? 0.02 : 0)
        SoundFX.shared.cue(power)
        phase = .rolling
        ballInHand = false
        scene.setPaths([]); scene.setGhost(nil)
        pull = 0
        telemetry = Telemetry()
        showPower(power, final: true)
    }

    private func onShotEnd() {
        let events = sim.events
        if phase == .demo { endDemo(); return }
        if mode == .drill { drillAfterShot(events) } else { freeAfterShot(events) }
    }

    // MARK: - cú mẫu
    var hasDemo: Bool { mode == .drill && stage?.demo != nil && stage?.cue != nil }

    func playDemo() {
        guard mode == .drill, stage?.demo != nil, phase != .rolling, phase != .demo else { return }
        loadStage()
        guard let st = stage, let demo = st.demo else { return }
        showToast("Đang tính cú mẫu…")
        DispatchQueue.global(qos: .userInitiated).async {
            let d = demoShot(st)
            DispatchQueue.main.async { [weak self] in
                guard let self, let d else { self?.showToast("Bài này không có cú mẫu"); return }
                self.dir = d.dir; self.spinA = demo.a; self.spinB = demo.b
                self.scene.cam.yaw = self.dir
                self.showToast("Cú mẫu: lực \(vn(demo.speed)) m/s, điểm đánh \(self.spinText)")
                self.phase = .result
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    guard self.phase == .result else { return }
                    self.sim.events = []
                    self.sim.strike(0, dir: self.dir, speed: demo.speed, a: demo.a, b: demo.b, elev: 0, squirt: 0.02)
                    SoundFX.shared.cue(0.4)
                    self.phase = .demo
                    self.scene.setPaths([]); self.scene.setGhost(nil)
                }
            }
        }
    }
    private func endDemo() {
        phase = .result
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in self?.loadStage(); self?.showToast("Đến lượt bạn") }
    }

    // MARK: - dự đoán đường đi
    private func computePreview() {
        var paths: [GuidePath] = []
        var ghost: P2? = nil
        let aiming = phase == .aim || phase == .placing
        if settings.guide > 0, aiming, let cb = cueBall, !cb.pocketed {
            let s = sim.clone()
            s.events = []
            s.strike(0, dir: dir, speed: Game.powerToSpeed(lastPower), a: spinA, b: spinB, elev: elev * .pi / 180, squirt: settings.squirt ? 0.02 : 0)
            let full = settings.guide == 2
            var cbPts = [cb.pos], obPts: [P2] = []
            var hitId: Int? = nil, hitT = 0.0, cbEvents = 0, obEvents = 0, k = 0
            let scb = s.ball(0)!
            let dt = 1.0 / 1000
            for _ in 0..<5000 {
                let n0 = s.events.count
                s.step(dt)
                if s.events.count > n0 { for e in s.events[n0...] {
                    switch e {
                    case .hit(_, let a, let b, _) where a == 0 || b == 0:
                        cbEvents += 1
                        if hitId == nil { hitId = a == 0 ? b : a; hitT = s.time; ghost = scb.pos; if let ob = s.ball(hitId!) { obPts.append(ob.pos) } }
                    case .cushion(_, let bl, _, _) where bl == 0: cbEvents += 1
                    case .cushion(_, let bl, _, _) where bl == hitId: obEvents += 1
                    case .pocket(_, let bl, _):
                        if bl == 0 { cbEvents = 99 } else if bl == hitId { obEvents += 1 }
                    default: break
                    }
                } }
                k += 1
                if k % 6 == 0 {
                    if !scb.pocketed { cbPts.append(scb.pos) }
                    if let h = hitId, let ob = s.ball(h), !ob.pocketed { obPts.append(ob.pos) }
                }
                if !full {
                    if cbEvents >= 1 && hitId == nil { cbPts.append(scb.pos); break }
                    if hitId != nil && s.time - hitT > 0.35 { break }
                } else {
                    let obDone = hitId == nil || obEvents >= 2 || (s.ball(hitId!)?.pocketed ?? true)
                    if (cbEvents >= 4 || scb.pocketed) && obDone { break }
                    if !s.moving { break }
                }
            }
            if !scb.pocketed { cbPts.append(scb.pos) }
            if let h = hitId, let ob = s.ball(h) { obPts.append(ob.pocketed ? (ob.dropFrom ?? ob.pos) : ob.pos) }
            if let g = ghost {
                var idx = 0, bd = Double.infinity
                for (i, p) in cbPts.enumerated() { let dd = p.dist(g); if dd < bd { bd = dd; idx = i } }
                paths.append(GuidePath(pts: Array(cbPts[0...idx]) + [g], color: .white, width: 0.006, opacity: 0.9))
                paths.append(GuidePath(pts: [g] + Array(cbPts[(idx + 1)...]), color: UIColor(hex: 0xd7ecff), width: 0.005, opacity: 0.65, dash: (0.02, 0.015)))
                paths.append(GuidePath(pts: obPts, color: UIColor(hex: 0xffd166), width: 0.007, opacity: 0.95))
            } else {
                paths.append(GuidePath(pts: cbPts, color: .white, width: 0.006, opacity: 0.9))
            }
        }
        var info: String? = nil
        if mode == .drill && hintOn && aiming, let h = currentHint() {
            for (a, b, kind) in h.lines {
                if kind == .sys { paths.append(GuidePath(pts: [a, b], color: UIColor(hex: 0xff9f1c), width: 0.007, opacity: 0.9, dash: (0.04, 0.025))) }
                else if kind == .ob && settings.guide == 0 { paths.append(GuidePath(pts: [a, b], color: UIColor(hex: 0xffd166), width: 0.003, opacity: 0.5, dash: (0.02, 0.02))) }
            }
            for m in h.marks where m.kind != .ghost {
                paths.append(GuidePath(pts: circlePts(m.p, m.kind == .image ? R : 0.012), color: UIColor(hex: 0xff9f1c), width: 0.003, opacity: 0.9))
            }
            info = h.info
        }
        if sysInfo != info { sysInfo = info }
        scene.setPaths(paths)
        scene.setGhost(ghost)
    }

    private func circlePts(_ p: P2, _ r: Double) -> [P2] { (0...40).map { i in let a = Double(i) / 40 * 2 * .pi; return P2(p.x + cos(a) * r, p.z + sin(a) * r) } }

    func refreshLabels() {
        let kind: LabelKind? = drill?.labels ?? (settings.labels ? .std : nil)
        scene.setLabels(kind.map(systemLabels) ?? [])
    }

    // MARK: - vòng lặp khung hình
    @objc private func frame(_ l: CADisplayLink) {
        let t = l.timestamp
        let dt = lastT == 0 ? 1.0 / 60 : min(0.05, t - lastT)
        lastT = t
        let s = sim
        if phase == .rolling || phase == .demo {
            let simDt = dt * (slow ? 0.2 : 1)
            let steps = min(400, Int((simDt / PHYS.dt).rounded()))
            let n0 = s.events.count
            for _ in 0..<steps { s.step() }
            if s.events.count > n0 { for e in s.events[n0...] {
                switch e {
                case .hit(_, _, _, let sp): SoundFX.shared.ball(sp)
                case .cushion(_, _, _, let sp): SoundFX.shared.cushion(sp)
                case .pocket: SoundFX.shared.pocket(); tick += 1
                default: break
                }
            } }
            scene.cam.overview = min(1, scene.cam.overview + dt * 1.5)
            if settings.telemetry, let cb = s.ball(0) { updateTelemetry(cb, s) }
            if !s.moving { onShotEnd() }
        } else if phase == .aim || phase == .placing {
            scene.cam.overview = max(0, scene.cam.overview - dt * 2)
            if !(locked && camLookAround) { scene.cam.yaw = dir + camYawOffset }
            if previewDirty && t - lastPreview > 0.06 { previewDirty = false; lastPreview = t; computePreview() }
        }
        scene.updateBalls(s.balls, dt: dt)
        let cb = cueBall
        let aiming = (phase == .aim || phase == .placing) && cb != nil && !(cb!.pocketed) && mode != nil
        scene.setCue(visible: aiming, cb: cb, dir: dir, a: spinA, b: spinB, pull: pull, elev: elev * .pi / 180)
        scene.updateCamera(dt: dt, cb: cb.flatMap { $0.pocketed ? nil : $0 })
    }

    private func updateTelemetry(_ cb: Ball, _ s: Simulation) {
        frameN += 1
        guard frameN % 4 == 0 else { return }
        let sp = cb.speed
        let ux = cb.vx + R * cb.w.z, uz = cb.vz - R * cb.w.x
        let dx = sp > 1e-6 ? cb.vx / sp : cos(dir), dz = sp > 1e-6 ? cb.vz / sp : sin(dir)
        // xoáy dọc: thành phần ω vuông góc hướng đi (dương = xoáy theo); xoáy ngang: ω quanh trục đứng
        let top = (dz * cb.w.x - dx * cb.w.z) * R / max(sp, 0.05)
        var t = telemetry
        t.speed = sp; t.top = top; t.side = cb.w.y / (2 * .pi); t.sliding = hypot(ux, uz) > 1e-3 && sp > 0.005
        t.vmax = max(t.vmax, sp); t.rails = s.events.cushions(of: 0).count
        telemetry = t
    }

    // MARK: - điều khiển
    func setLock(_ on: Bool) {
        locked = on
        if !on { camYawOffset = 0; camLookAround = false }
    }
    func toggleLock() { setLock(!locked); SoundFX.shared.tick() }

    func nudge(_ rad: Double) {
        guard !locked, phase == .aim || phase == .placing else { return }
        dir += rad
    }

    func placeCue(_ p: P2) {
        guard let cb = cueBall else { return }
        let x = min(TL / 2 - R - 0.002, max(-TL / 2 + R + 0.002, p.x)), z = min(TW / 2 - R - 0.002, max(-TW / 2 + R + 0.002, p.z))
        if sim.balls.contains(where: { $0.id != 0 && !$0.pocketed && hypot($0.x - x, $0.z - z) < 2 * R + 0.001 }) { return }
        cb.x = x; cb.z = z; cb.pocketed = false
        previewDirty = true
    }

    func toggleHand() {
        guard ballInHand else { return }
        phase = phase == .placing ? .aim : .placing
        showToast(phase == .placing ? "Kéo bi cái tới vị trí mới" : "Xong đặt bi")
    }

    func markPreviewDirty() { previewDirty = true }

    var spinText: String {
        func f(_ v: Double) -> String { (v > 0 ? "+" : "") + vn(v, 2) }
        if spinA == 0 && spinB == 0 { return "tâm bi" }
        var parts: [String] = []
        if spinB != 0 { parts.append("\(spinB > 0 ? "theo" : "kéo") \(f(spinB))R") }
        if spinA != 0 { parts.append("\(spinA > 0 ? "phải" : "trái") \(f(spinA))R") }
        return parts.joined(separator: " · ")
    }
    var aimText: String { var d = (dir * 180 / .pi).truncatingRemainder(dividingBy: 360); if d < 0 { d += 360 }; return "Hướng \(vn(d, 2))°" }

    func showPower(_ p: Double, final: Bool) {
        shownPower = p
        if final { DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in if self?.phase != .aim { self?.shownPower = nil } } }
    }

    // MARK: - HUD / menu
    private func showGame(_ t: String) {
        title = t
        scene.cam.pitch = 0.3; scene.cam.dist = 1.0
        scene.snapCamera(cueBall)
        refreshLabels()
    }

    var subtitle: String {
        if mode == .drill, let d = drill {
            let s = drillStat(d.id), n = d.stageCount
            return (n > 1 ? "Chặng \(stageIdx + 1)/\(n) · " : "") + "Thành công \(s.ok)/\(s.att) · Chuỗi \(s.streak)"
        }
        return freeSummary
    }

    func openMenu() {
        phase = .menu; mode = nil; drill = nil; stage = nil; free = nil; card = nil
        scene.setZones([]); scene.setPaths([]); scene.setGhost(nil); sysInfo = nil
        setupBalls(fromDiamond(2, 2), rackBalls("9"))
        scene.cam.pitch = 0.5; scene.cam.dist = 2.2; scene.cam.overview = 0; scene.cam.yaw = 0
        refreshLabels()
    }

    func showToast(_ msg: String, _ kind: Toast.Kind = .info) {
        toast = Toast(msg: msg, kind: kind)
        toastWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9, execute: w)
    }

    /// Dải bi: các bi mục tiêu + trạng thái đã vào lỗ.
    var ballStrip: [StripBall] { _ = tick; return sim.balls.filter { $0.id != 0 }.map { StripBall(id: $0.id, gone: $0.pocketed) } }
}
