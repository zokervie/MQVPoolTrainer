import SwiftUI
import UIKit
import QuartzCore

// Điều phối: vòng lặp game, luồng bài tập, luật chơi tự do, dự đoán đường đi (giống src/main.js).

enum Phase { case menu, aim, placing, rolling, result, demo, replay }
enum GameMode { case free8, free9, drill, challengePower, challengeAim }

/// Một cú đã đánh: đủ dữ liệu để phân tích và phát lại y hệt.
struct ShotRecord {
    var before: [Ball]
    var params: ShotParams
    var stroke: StrokeInfo?
    var idealDir: Double?
    var targetBall: Int?
    var targetPoint: P2?
    var predictedRail: P2?
    var zone: Zone?
}

/// Trạng thái thử thách (ổn định lực / kiểm tra ngắm).
struct Challenge {
    var level = 3                 // ổn định lực: mức cần đạt
    var total = 10
    var speeds: [Double] = []     // ổn định lực
    var errors: [Double] = []     // kiểm tra ngắm: sai số góc (độ, + = lệch trái)
    var hits = 0
    var seed: UInt32 = 1
}

struct Toast: Equatable { var msg: String; var kind: Kind; var id = UUID()
    enum Kind { case info, ok, bad }
}

/// Phiếu (sheet) hiển thị trên màn hình.
enum Card: Identifiable {
    case drill(Drill, inGame: Bool)
    case finished(title: String, lead: String, stats: String?, again: String)
    case settings, help, sources, tables, tableEditor
    var id: String {
        switch self {
        case .drill(let d, let g): return "d-\(d.id)-\(g)"
        case .finished(let t, _, _, _): return "f-\(t)"
        case .settings: return "settings"
        case .help: return "help"
        case .sources: return "sources"
        case .tables: return "tables"
        case .tableEditor: return "tableEditor"
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
    @Published var feedback: ShotFeedback? = nil      // bảng số liệu sau cú đánh
    @Published var feedbackPending = false            // đang chờ người chơi bấm "Tiếp" để sang chặng/lần sau
    @Published var challenge: Challenge? = nil
    @Published var attempt = 0                        // lần thứ mấy (bài lặp nhiều lần)
    @Published var attemptOK = 0
    private(set) var lastShot: ShotRecord? = nil
    private var postShot: [Ball] = []
    private var trailNow: [Int: [P2]] = [:], trailPrev: [Int: [P2]] = [:]
    private var pendingAdvance: (() -> Void)? = nil
    var pendingStroke: StrokeInfo? = nil

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
                case "table": if let t = TableSpec.preset(parts[1]) { self.selectTable(t) }
                case "realistic": self.settings.realistic = parts.count > 1 ? parts[1] == "1" : true
                case "challenge": self.startChallenge(parts[1] == "aim" ? .challengeAim : .challengePower, level: 3)
                case "tables": self.card = .tables
                case "editor": self.card = .tableEditor
                case "next": self.continueAfterFeedback()
                case "replay": self.replay()
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
        let tableChanged = old == nil || old!.table != settings.table
        if tableChanged {
            applyTable(settings.table)
            scene.syncBalls(sim.balls)
        }
        scene.setTable(settings.table, clothHex: settings.clothHex)
        if tableChanged && old != nil { reloadAfterTableChange() }
        scene.setQuality(settings.quality)
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
    func toggleRealistic() {
        settings.realistic.toggle()
        showToast(settings.realistic ? "Luyện thật: không đường ngắm, không số độ, chỉ số liệu sau cú" : "Tắt chế độ luyện thật")
    }

    /// Đổi bàn khi đang tập: dựng lại thế bi trên bàn mới.
    private func reloadAfterTableChange() {
        switch mode {
        case .drill: loadStage()
        case .free8, .free9: if let f = free { startFree(f.kind) }
        case .challengePower, .challengeAim: nextChallengeShot()
        case nil: setupBalls(fromDiamond(2, 2), rackBalls("9"))
        }
        refreshLabels()
    }

    /// Chọn hồ sơ bàn (màu nỉ theo hồ sơ).
    func selectTable(_ t: TableSpec) {
        var s = settings
        if t.id == "custom" { s.customTable = t }
        s.tableId = t.id
        s.cloth = t.clothColor
        settings = s
        showToast("Bàn: \(t.brand) \(t.model)")
    }
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
        if let h = currentHint() {
            // luyện thật: không lộ hướng bi ma – cơ chĩa thẳng vào tâm bi mục tiêu, người chơi tự ngắm
            if settings.realistic, let id = currentHintBall(), let ob = sim.ball(id), !ob.pocketed {
                dir = atan2(ob.z - cb.z, ob.x - cb.x); return
            }
            dir = h.dir; return
        }
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
        mode = .drill; drill = d; stageIdx = idx; free = nil; challenge = nil
        attempt = 0; attemptOK = 0; trailPrev = [:]; trailNow = [:]; lastShot = nil
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
        scene.setMarkers(st.markers)
        feedback = nil; feedbackPending = false; pendingAdvance = nil
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
        let advance: () -> Void = { [weak self] in
            guard let self, self.resultToken == token else { return }
            if d.repeats > 1 {
                // bài lặp nhiều lần (so_lan): đếm số lần đạt
                self.attempt += 1; if res.ok { self.attemptOK += 1 }
                if self.attempt >= d.repeats {
                    self.card = .finished(title: "Xong \(d.repeats) lần!", lead: "\(d.title): đạt \(self.attemptOK)/\(d.repeats) (\(Int((Double(self.attemptOK) / Double(d.repeats) * 100).rounded()))%).",
                                          stats: "Tổng: \(s.ok)/\(s.att) · chuỗi tốt nhất \(s.best)", again: "Tập lại")
                    self.attempt = 0; self.attemptOK = 0
                }
                self.loadStage()
            } else if res.ok && !last {
                self.stageIdx += 1; self.loadStage(); self.showToast("Chặng \(self.stageIdx + 1)/\(d.stageCount)")
            } else if res.ok && last && d.stageCount > 1 {
                self.card = .finished(title: "Hoàn thành bài!", lead: "\(d.title) – cả \(d.stageCount) chặng.",
                                      stats: "Tổng: \(s.ok)/\(s.att) lần thành công · chuỗi tốt nhất \(s.best)", again: "Tập lại từ đầu")
            } else { self.loadStage() }
        }
        if settings.feedback {
            // chờ người chơi xem số liệu / phát lại rồi bấm "Tiếp"
            pendingAdvance = advance; feedbackPending = true
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + (res.ok ? 1.3 : 1.7)) { [weak self] in
                guard let self, self.phase == .result else { return }
                advance()
            }
        }
    }

    /// Nút "Tiếp" trên bảng phản hồi.
    func continueAfterFeedback() {
        feedbackPending = false
        if let a = pendingAdvance { pendingAdvance = nil; a() } else { feedback = nil; markPreviewDirty() }
    }

    /// Nút trên phiếu kết thúc: tập lại.
    func again() {
        if mode == .drill { stageIdx = 0; attempt = 0; attemptOK = 0; loadStage() }
        else if let f = free { startFree(f.kind) }
        else if mode == .challengePower || mode == .challengeAim { startChallenge(mode!, level: challenge?.level ?? 3) }
    }

    func reset() {
        if mode == .drill { loadStage() } else if let f = free { startFree(f.kind) }
        else if mode == .challengePower || mode == .challengeAim { nextChallengeShot() }
    }

    /// Cue-specific transfer approximation, using openly editable parameters.
    /// Not a manufacturer measurement; calibration fixtures must validate future values.
    private var cueProfile: (speed: Double, squirt: Double, maxElev: Double) {
        let id = UserDefaults.standard.string(forKey: "zoker-cue-choice") ?? "playing"
        switch id {
        case "jump": return (0.86, 0.80, 65)
        case "breakCue": return (1.10, 1.18, 35)
        default: return (1.0, 1.0, 65)
        }
    }

    // MARK: - đánh
    static func powerToSpeed(_ p: Double) -> Double { 0.25 + 8.75 * p * p }

    func shoot(_ power0: Double, stroke: StrokeInfo? = nil) {
        guard phase == .aim || phase == .placing, let cb = cueBall, !cb.pocketed else { return }
        let power = min(1, max(0.02, power0))
        lastPower = power
        // lỗi cú vuốt thật (không ngẫu nhiên): vuốt lệch ngang → lệch hướng cơ + xoáy ngang ngoài ý muốn
        var d = dir, a = spinA
        if settings.strokeErrors, let st = stroke {
            d += st.lateralRatio * 0.05
            a = max(-0.6, min(0.6, a + st.lateralRatio * 0.3))
        }
        let profile = cueProfile
        let params = ShotParams(dir: d, speed: Game.powerToSpeed(power) * profile.speed, a: a, b: spinB, elev: min(elev, profile.maxElev) * .pi / 180, squirt: settings.squirt ? 0.02 * profile.squirt : 0)
        lastShot = makeRecord(params, stroke: stroke)
        trailPrev = trailNow; trailNow = [:]
        feedback = nil; feedbackPending = false
        sim.events = []
        sim.strike(0, dir: params.dir, speed: params.speed, a: params.a, b: params.b, elev: params.elev, squirt: params.squirt)
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
        if phase == .replay { finishReplay(); return }
        postShot = sim.balls.map { $0.clone() }
        if let rec = lastShot, settings.feedback || mode == .challengeAim || mode == .challengePower { analyze(rec) }
        switch mode {
        case .drill: drillAfterShot(events)
        case .challengePower, .challengeAim: challengeAfterShot(events)
        default: freeAfterShot(events)
        }
    }

    // MARK: - phân tích, phát lại, bóng ma cú trước
    private func makeRecord(_ p: ShotParams, stroke: StrokeInfo?) -> ShotRecord {
        var rec = ShotRecord(before: sim.balls.map { $0.clone() }, params: p, stroke: stroke)
        if mode == .challengeAim, let t = aimTarget { rec.idealDir = t.dir; rec.targetBall = 1; rec.targetPoint = t.point; return rec }
        if let h = currentHint() {
            var isDir = false
            if let hh = stage?.hint, case .dir = hh { isDir = true }
            if !isDir { rec.idealDir = h.dir }
            if let ob = h.lines.first(where: { $0.2 == .ob }) { rec.targetPoint = ob.1; rec.targetBall = stage?.hint.ball ?? currentHintBall() }
            rec.predictedRail = h.marks.first(where: { $0.kind == .contact })?.p
        }
        rec.zone = stage?.goal.cueZone
        return rec
    }

    private func currentHintBall() -> Int? {
        guard let st = stage else { return nil }
        if let clear = st.goal.clear { return clear.first { id in sim.ball(id).map { !$0.pocketed } ?? false } }
        return st.hint.ball
    }

    private func analyze(_ rec: ShotRecord) {
        let rb = rec
        DispatchQueue.global(qos: .userInitiated).async {
            var fb = analyzeShot(before: rb.before, params: rb.params, idealDir: rb.idealDir, targetBall: rb.targetBall,
                                 targetPoint: rb.targetPoint, predictedRail: rb.predictedRail, zone: rb.zone)
            fb.stroke = rb.stroke
            DispatchQueue.main.async { [weak self] in
                guard let self, self.lastShot?.params == rb.params else { return }
                if self.settings.feedback { self.feedback = fb; self.showTrails() }
                if self.mode == .challengeAim, var c = self.challenge, let e = fb.aimErrorDeg, c.errors.count < c.total {
                    c.errors.append(e); self.challenge = c; self.checkChallengeDone()
                }
            }
        }
    }

    /// Đường đi của cú vừa đánh (sáng) và cú trước (mờ) để so sánh.
    private func showTrails() {
        guard settings.ghostTrail else { return }
        var paths: [GuidePath] = []
        for (id, pts) in trailPrev where pts.count > 1 {
            paths.append(GuidePath(pts: pts, color: UIColor(white: 0.75, alpha: 1), width: 0.004, opacity: 0.45, dash: (0.015, 0.012)))
            _ = id
        }
        for (id, pts) in trailNow where pts.count > 1 {
            paths.append(GuidePath(pts: pts, color: id == 0 ? .white : UIColor(hex: 0xffd166), width: 0.005, opacity: 0.85))
        }
        scene.setPaths(paths); scene.setGhost(nil)
    }

    private var replayRestore: [Ball] = []
    private var phaseBeforeReplay: Phase = .aim
    var canReplay: Bool { lastShot != nil && (phase == .aim || phase == .placing || phase == .result) }

    /// Phát lại cú vừa đánh (chậm), xong trả bàn về trạng thái hiện tại.
    func replay() {
        guard let rec = lastShot, canReplay else { return }
        replayRestore = sim.balls.map { $0.clone() }
        phaseBeforeReplay = phase
        sim = Simulation(rec.before.map { $0.clone() })
        scene.syncBalls(sim.balls)
        sim.strike(0, dir: rec.params.dir, speed: rec.params.speed, a: rec.params.a, b: rec.params.b, elev: rec.params.elev, squirt: rec.params.squirt)
        scene.setPaths([]); scene.setGhost(nil)
        phase = .replay
        SoundFX.shared.cue(min(1, rec.params.speed / 8))
    }
    private func finishReplay() {
        sim = Simulation(replayRestore)
        scene.syncBalls(sim.balls)
        scene.updateBalls(sim.balls, dt: 0)
        phase = phaseBeforeReplay
        showTrails()
        tick += 1
    }

    // MARK: - thử thách
    private var aimTarget: (dir: Double, point: P2)? = nil

    func startChallenge(_ m: GameMode, level: Int = 3) {
        mode = m; drill = nil; stage = nil; free = nil
        challenge = Challenge(level: level, seed: UInt32(truncatingIfNeeded: Int(Date().timeIntervalSince1970)))
        trailPrev = [:]; trailNow = [:]; lastShot = nil
        scene.setZones([]); scene.setMarkers([])
        showGame(m == .challengePower ? "Ổn định lực – mức \(level)/7" : "Kiểm tra ngắm")
        nextChallengeShot()
        showToast(m == .challengePower ? "Đánh 10 cú cùng mức \(level) (≈ \(vn(SpeedScale.speed(level: level))) m/s). Số liệu hiện sau mỗi cú."
                                         : "10 cú cắt ngẫu nhiên, không có đường ngắm. Đo sai số góc và thiên lệch trái/phải.")
    }

    func nextChallengeShot() {
        guard var c = challenge else { return }
        feedback = nil; feedbackPending = false
        if mode == .challengePower {
            setupBalls(fromDiamond(1, 2), [])
            dir = 0; aimTarget = nil
        } else {
            var r = LCG(c.seed &+ UInt32(c.errors.count * 7919))
            let ids = [POCKET_IDS.TR, POCKET_IDS.TL, POCKET_IDS.BR, POCKET_IDS.BL]
            var placed = false
            for _ in 0..<100 {
                let ob = fromDiamond(2 + r.next() * 4, 0.9 + r.next() * 2.2)
                let pk = pocketById(ids[Int(r.next() * 4) % 4])!
                let tgt = pocketAimPoint(pk)
                let cue = placeForCut(ob, tgt, r.next() * 45, 0.4 + r.next() * 0.7, r.next() < 0.5 ? -1 : 1)
                guard abs(cue.x) < TL / 2 - 0.08, abs(cue.z) < TW / 2 - 0.08 else { continue }
                setupBalls(cue, [BallSpec(id: 1, p: ob)])
                let g = ghostBall(ob, tgt)
                aimTarget = (atan2(g.z - cue.z, g.x - cue.x), tgt)
                // hướng xuất phát: thẳng vào tâm bi (người chơi tự ngắm)
                dir = atan2(ob.z - cue.z, ob.x - cue.x)
                placed = true; break
            }
            if !placed { setupBalls(fromDiamond(3, 2), [BallSpec(id: 1, p: fromDiamond(6, 3))]) }
        }
        c.seed = c.seed &+ 1
        challenge = c
        ballInHand = false
        spinA = 0; spinB = 0; elev = 0
        scene.cam.yaw = dir
        enterAim()
    }

    private func challengeAfterShot(_ events: [SimEvent]) {
        guard var c = challenge, let rec = lastShot else { return }
        if mode == .challengePower {
            c.speeds.append(rec.params.speed)
            let lv = SpeedScale.level(speed: rec.params.speed)
            showToast("Cú \(c.speeds.count)/\(c.total): \(vn(rec.params.speed, 2)) m/s – mức \(vn(lv))", abs(lv - Double(c.level)) < 0.35 ? .ok : .info)
        } else if events.pottedIds.contains(1) { c.hits += 1 }
        challenge = c
        phase = .result
        if mode == .challengePower { checkChallengeDone() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.phase == .result, self.card == nil, let c = self.challenge else { return }
            if (self.mode == .challengePower ? c.speeds.count : c.errors.count) < c.total { self.nextChallengeShot() }
        }
    }

    private func checkChallengeDone() {
        guard let c = challenge else { return }
        if mode == .challengePower, c.speeds.count >= c.total {
            let st = Stats1D(values: c.speeds), target = SpeedScale.speed(level: c.level)
            card = .finished(title: "Ổn định lực – mức \(c.level)",
                             lead: "Trung bình \(vn(st.mean, 2)) m/s (mục tiêu \(vn(target, 2))) · độ lệch chuẩn \(vn(st.sd, 2)) m/s (\(vn(st.sd / max(st.mean, 0.01) * 100))%).",
                             stats: c.speeds.map { vn($0, 2) }.joined(separator: " · "), again: "Làm lại")
        }
        if mode == .challengeAim, c.errors.count >= c.total {
            let st = Stats1D(values: c.errors)
            let bias = st.mean
            card = .finished(title: "Kiểm tra ngắm",
                             lead: "Vào \(c.hits)/\(c.total) · sai số trung bình \(vn(st.meanAbs, 2))° · thiên lệch \(abs(bias) < 0.05 ? "không đáng kể" : (bias > 0 ? "sang phải" : "sang trái")) \(vn(abs(bias), 2))°.",
                             stats: c.errors.map { ($0 >= 0 ? "+" : "") + vn($0, 2) + "°" }.joined(separator: " · "), again: "Làm lại")
        }
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
        if settings.effectiveGuide > 0, aiming, mode != .challengeAim, let cb = cueBall, !cb.pocketed {
            let s = sim.clone()
            s.events = []
            s.strike(0, dir: dir, speed: Game.powerToSpeed(lastPower), a: spinA, b: spinB, elev: elev * .pi / 180, squirt: settings.squirt ? 0.02 : 0)
            let full = settings.effectiveGuide == 2
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
        if mode == .drill && hintOn && !settings.realistic && aiming, let h = currentHint() {
            for (a, b, kind) in h.lines {
                if kind == .sys { paths.append(GuidePath(pts: [a, b], color: UIColor(hex: 0xff9f1c), width: 0.007, opacity: 0.9, dash: (0.04, 0.025))) }
                else if kind == .ob && settings.effectiveGuide == 0 { paths.append(GuidePath(pts: [a, b], color: UIColor(hex: 0xffd166), width: 0.003, opacity: 0.5, dash: (0.02, 0.02))) }
            }
            for m in h.marks where m.kind != .ghost {
                paths.append(GuidePath(pts: circlePts(m.p, m.kind == .image ? R : 0.012), color: UIColor(hex: 0xff9f1c), width: 0.003, opacity: 0.9))
            }
            info = h.info
        }
        if sysInfo != info { sysInfo = info }
        // sau cú đánh: thêm đường đi thực tế của cú vừa rồi và bóng ma cú trước
        if feedback != nil && settings.ghostTrail {
            for (_, pts) in trailPrev where pts.count > 1 { paths.append(GuidePath(pts: pts, color: UIColor(white: 0.75, alpha: 1), width: 0.004, opacity: 0.4, dash: (0.015, 0.012))) }
            for (id, pts) in trailNow where pts.count > 1 { paths.append(GuidePath(pts: pts, color: id == 0 ? .white : UIColor(hex: 0xffd166), width: 0.004, opacity: 0.55)) }
        }
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
        if phase == .rolling || phase == .demo || phase == .replay {
            let simDt = dt * (slow ? 0.2 : (phase == .replay ? 0.4 : 1))
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
            if phase == .rolling {   // lấy mẫu đường đi (bi cái + bi được chạm đầu tiên)
                let ids = [0] + (s.events.firstCueHit.map { [$0.other] } ?? [])
                for id in ids { if let b = s.ball(id), !b.pocketed { trailNow[id, default: []].append(b.pos) } }
            }
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
            let rep = d.repeats > 1 ? "Lần \(attempt + 1)/\(d.repeats) · đạt \(attemptOK) · " : ""
            return rep + (n > 1 ? "Chặng \(stageIdx + 1)/\(n) · " : "") + "Thành công \(s.ok)/\(s.att) · Chuỗi \(s.streak)"
        }
        if let c = challenge {
            if mode == .challengePower { return "Cú \(min(c.speeds.count + 1, c.total))/\(c.total) · mục tiêu \(vn(SpeedScale.speed(level: c.level))) m/s" }
            return "Cú \(min(c.errors.count + 1, c.total))/\(c.total) · vào \(c.hits)"
        }
        return freeSummary + " · \(TABLE.brand) \(TABLE.model)" 
    }

    func openMenu() {
        phase = .menu; mode = nil; drill = nil; stage = nil; free = nil; card = nil
        challenge = nil; feedback = nil; feedbackPending = false; pendingAdvance = nil; lastShot = nil
        trailNow = [:]; trailPrev = [:]; scene.setMarkers([])
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
