import Foundation
import Observation
import QuartzCore
import simd
import PoolPhysics
import PoolInput
import PoolDrills
import PoolAudio

enum CameraMode: Equatable { case firstPerson, overview }

/// Số liệu sau cú đánh (docs/05-feedback.md). Chỉ hiển thị khi bi đã dừng.
struct ShotFeedback: Equatable {
    var cueSpeed: Double
    var speedLevel: Int
    /// Quãng bi cái tự lăn nếu không chạm gì, tính theo số chiều dài bàn.
    var tableLengths: Double
    var lateralRatio: Double?
    var followThroughRatio: Double?
    var miscue: Bool
    var drillSuccess: Bool?
    var conditionLines: [String]
    var cueBallDistance: Double?
    /// Sai số ngắm (độ, dương = cần ngắm sang trái) và độ rộng khoảng ngắm đạt — chỉ khi bài có mục tiêu.
    var aimErrorDegrees: Double?
    var aimWindowDegrees: Double?
    var aimErrorMillimetersAtPocket: Double?
    var aimPending: Bool
    var shotLab: Bool
}

@MainActor @Observable
final class GameModel {
    let settings: AppSettings
    let history: HistoryStore
    let tables: TableStore
    let audio = ShotAudio()
    let strokeMapping = StrokeMapping()

    private(set) var drill: Drill?
    private(set) var attempt = 0
    private(set) var balls: [Ball] = []
    private(set) var machine = InteractionMachine()
    var aimAngle: Double = 0
    /// Điểm chạm: x = ngang (+ phải), y = dọc (+ trên), theo bán kính bi.
    private(set) var tip = SIMD2<Double>(0, 0)
    var effectExpanded = false
    var cameraMode: CameraMode = .firstPerson
    var shotLabOpen = false

    private(set) var result: ShotResult?
    private(set) var isPlaying = false
    @ObservationIgnored private var playbackStart: CFTimeInterval = 0
    private(set) var playbackRate: Double = 1
    private(set) var feedback: ShotFeedback?
    private(set) var lastStrike: CueStrike?
    @ObservationIgnored private var lastStroke: StrokeResult?
    @ObservationIgnored private var lastRecording: TouchRecording?
    @ObservationIgnored private var shotCounter: UInt64 = 0
    @ObservationIgnored private var preShotBalls: [Ball] = []

    init(settings: AppSettings, history: HistoryStore, tables: TableStore) {
        self.settings = settings
        self.history = history
        self.tables = tables
        startFree()
    }

    var table: TableSpec { drill?.tableSpec ?? tables.definition.geometry }
    var simulation: Simulation { Simulation(table: table, parameters: tables.parameters) }
    var mapping: RenderMapping { RenderMapping(table: table) }
    var state: InteractionState { machine.state }

    // MARK: Bố trí bàn

    func startFree() {
        drill = nil
        attempt = 0
        let t = tables.definition.geometry
        balls = [Ball(id: 0, position: SIMD3(t.length / 4, t.width / 2, t.ballRadius)),
                 Ball(id: 1, position: SIMD3(3 * t.length / 4, t.width / 2, t.ballRadius))]
        resetForAim()
    }

    func startRack() {
        drill = nil
        let t = tables.definition.geometry
        balls = [Ball(id: 0, position: SIMD3(t.length / 4, t.width / 2, t.ballRadius))]
            + Rack.triangle(apex: SIMD2(3 * t.length / 4, t.width / 2), radius: t.ballRadius, gap: 2e-4)
        resetForAim()
    }

    func startDrill(_ d: Drill, attempt a: Int = 0) {
        drill = d
        attempt = a
        balls = d.initialBalls(attempt: a)
        let g = d.huongDan.diemCham
        tip = SIMD2(g.ngang, g.doc)
        resetForAim(keepTip: true)
    }

    func nextAttempt() {
        if let d = drill { startDrill(d, attempt: attempt + 1) } else { dismissReview() }
    }

    func resetLayout() {
        if let d = drill { startDrill(d, attempt: attempt) } else if !preShotBalls.isEmpty {
            balls = preShotBalls; resetForAim()
        }
    }

    private func resetForAim(keepTip: Bool = false) {
        audio.stop()
        isPlaying = false
        result = nil
        feedback = nil
        machine = InteractionMachine()
        if !keepTip { tip = .zero }
        // Hướng ban đầu: về phía bi mục tiêu gần nhất (không phải đường ngắm gợi ý).
        if let cue = balls.first(where: { $0.id == 0 }) {
            let others = balls.filter { $0.id != 0 && $0.state != .pocketed }
            if let ob = others.min(by: { simd_distance($0.position, cue.position) < simd_distance($1.position, cue.position) }) {
                aimAngle = atan2(ob.position.y - cue.position.y, ob.position.x - cue.position.x)
            } else {
                aimAngle = 0
            }
        }
    }

    // MARK: Ngắm, điểm chạm, khóa

    func rotateAim(by delta: Double) {
        guard machine.swipeAims else { return }
        aimAngle = remainder(aimAngle + delta, 2 * .pi)
    }

    /// Đặt điểm chạm; trả về true nếu bị chặn ở vòng giới hạn trượt cơ.
    @discardableResult
    func setTip(_ p: SIMD2<Double>) -> Bool {
        guard machine.showsEffectBall else { return false }
        let limit = CueSpec().miscueLimit
        let len = simd_length(p)
        if len > limit {
            tip = p / len * limit
            return true
        }
        tip = p
        return false
    }

    func resetTip() { if machine.showsEffectBall { tip = .zero } }

    func lockTapped() {
        switch machine.handle(.lockTap) {
        case .lock: Haptics.lock(); effectExpanded = false
        case .unlock: Haptics.unlock()
        case .none: break
        }
        if !settings.seenLockHint { settings.seenLockHint = true; settings.save() }
    }

    // MARK: Ra cơ

    func strokeCancelled() { machine.handle(.strokeCancelled) }

    func strokeCompleted(_ r: StrokeResult, recording: TouchRecording) {
        guard machine.swipeStrokes else { return }
        let speed = strokeMapping.cueSpeed(fingerSpeed: r.fingerSpeed)
        guard speed > 0 else { machine.handle(.strokeCancelled); return }
        // Vuốt lệch sang phải (lateral > 0) đẩy cơ sang phải (góc giảm) và tạo xoáy phải ngoài ý muốn.
        let aim = aimAngle - strokeMapping.aimError(r)
        let english = max(-1, min(1, tip.x + strokeMapping.unintendedEnglish(r)))
        let strike = CueStrike(aimAngle: aim, cueSpeed: speed, tipVertical: tip.y, tipHorizontal: english)
        lastStroke = r
        lastRecording = recording
        machine.handle(.strokeCompleted)
        shoot(strike, shotLab: false)
    }

    /// Shot Lab: đánh trực tiếp bằng thông số nhập tay (không có trợ giúp ngắm).
    func shootShotLab(_ strike: CueStrike) {
        guard machine.state == .aiming || machine.state == .locked else { return }
        if machine.state == .aiming { machine.handle(.lockTap) }
        lastStroke = nil
        lastRecording = nil
        machine.handle(.strokeCompleted)
        shoot(strike, shotLab: true)
    }

    private func shoot(_ strike: CueStrike, shotLab: Bool) {
        shotCounter &+= 1
        let shotId = shotCounter
        let sim = simulation
        let start = balls
        preShotBalls = balls
        lastStrike = strike
        let listener = listenerPose()
        let spatial = settings.spatialAudio, headphones = settings.headphoneMode
        let scheduler = audio.scheduler
        Haptics.cueContact(speed: strike.cueSpeed)

        Task { [weak self] in
            let (shot, sound) = await Task.detached(priority: .userInitiated) {
                let r = sim.run(balls: start, strike: strike)
                let s = ShotAudio.render(records: r.collisions, shotId: shotId, listener: listener, rate: 1,
                                         spatial: spatial, headphones: headphones, scheduler: scheduler)
                return (r, s)
            }.value
            guard let self else { return }
            self.beginPlayback(shot, sound: sound, rate: 1)
            self.computeFeedback(shot, strike: strike, start: start, shotLab: shotLab)
        }
    }

    private func beginPlayback(_ shot: ShotResult, sound: OfflineRenderer.Output?, rate: Double) {
        result = shot
        playbackRate = rate * AutoTest.timeScale
        let startAt = CACurrentMediaTime() + 0.05
        playbackStart = startAt
        isPlaying = true
        if let sound, !settings.muted {
            audio.play(sound, at: startAt, volume: settings.effectsVolume)
        }
    }

    func replay(rate: Double) {
        guard let shot = result, !isPlaying else { return }
        let listener = listenerPose()
        let spatial = settings.spatialAudio, headphones = settings.headphoneMode
        let scheduler = audio.scheduler
        let id = shotCounter
        Task { [weak self] in
            let sound = await Task.detached(priority: .userInitiated) {
                ShotAudio.render(records: shot.collisions, shotId: id, listener: listener, rate: rate,
                                 spatial: spatial, headphones: headphones, scheduler: scheduler)
            }.value
            self?.beginPlayback(shot, sound: sound, rate: rate)
        }
    }

    /// Trạng thái bi để vẽ ở thời điểm hiện tại.
    func displayBalls(now: CFTimeInterval) -> [Ball] {
        guard isPlaying, let shot = result else { return balls }
        let t = max(0, (now - playbackStart) * playbackRate)
        if t >= shot.trajectory.duration {
            finishPlayback(shot)
            return balls
        }
        return shot.trajectory.state(at: t)
    }

    private func finishPlayback(_ shot: ShotResult) {
        isPlaying = false
        guard machine.state == .shotRunning else { return } // replay: giữ nguyên trạng thái
        var final = shot.finalBalls
        if let i = final.firstIndex(where: { $0.id == 0 }), final[i].state == .pocketed {
            // Bi cái rơi lỗ: đặt lại ở điểm đầu bàn.
            final[i] = Ball(id: 0, position: SIMD3(table.length / 4, table.width / 2, table.ballRadius))
        }
        balls = final
        machine.handle(.ballsStopped)
    }

    func dismissReview() {
        guard machine.state == .reviewing else { return }
        machine.handle(.reviewDismissed)
        feedback = nil
        let cue = balls.first { $0.id == 0 }
        if let cue, let ob = balls.filter({ $0.id != 0 && $0.state != .pocketed })
            .min(by: { simd_distance($0.position, cue.position) < simd_distance($1.position, cue.position) }) {
            aimAngle = atan2(ob.position.y - cue.position.y, ob.position.x - cue.position.x)
        }
    }

    private func listenerPose() -> ListenerPose {
        let cue = balls.first { $0.id == 0 }?.position ?? .zero
        return ListenerPose(position: SIMD2(cue.x - cos(aimAngle) * 0.8, cue.y - sin(aimAngle) * 0.8), yaw: aimAngle)
    }

    // MARK: Phản hồi sau cú

    private func computeFeedback(_ shot: ShotResult, strike: CueStrike, start: [Ball], shotLab: Bool) {
        let t = table
        let params = tables.parameters
        var lines: [String] = []
        var success: Bool? = nil
        var distance: Double? = nil
        if let d = drill {
            let o = d.evaluate(shot)
            success = o.success
            distance = o.cueBallDistanceToTarget
            if o.cueBallScratched { lines.append("Bi cái rơi lỗ") }
            for (c, ok) in o.conditions { lines.append("\(ok ? "✓" : "✗") \(Self.describe(c))") }
        }
        // Quãng tự lăn của bi cái.
        let cueStart = start.first { $0.id == 0 } ?? Ball(id: 0, position: .zero)
        let struck = CueModel.strike(strike, ball: cueStart, mass: t.ballMass, radius: t.ballRadius)
        let path = FreeMotion.runToRest(struck.ball, params, radius: t.ballRadius)
        let travelled = simd_distance(path.last!.ball.position, cueStart.position)

        let stroke = lastStroke
        feedback = ShotFeedback(
            cueSpeed: strike.cueSpeed, speedLevel: SpeedScale.level(forCueSpeed: strike.cueSpeed),
            tableLengths: travelled / t.length, lateralRatio: stroke?.lateralRatio,
            followThroughRatio: stroke?.followThroughRatio, miscue: shot.miscue,
            drillSuccess: success, conditionLines: lines, cueBallDistance: distance,
            aimErrorDegrees: nil, aimWindowDegrees: nil, aimErrorMillimetersAtPocket: nil,
            aimPending: drill?.primaryPocketTarget != nil && !shot.miscue, shotLab: shotLab)

        let log = ShotLog(date: Date(), drillId: drill?.id, attempt: attempt, success: success,
                          cueSpeed: strike.cueSpeed, lateralRatio: stroke?.lateralRatio,
                          followThroughRatio: stroke?.followThroughRatio,
                          cueBallDistanceToTarget: distance, shotLab: shotLab)

        // Khoảng ngắm: chỉ khi bài có mục tiêu vào lỗ cụ thể.
        guard let d = drill, let target = d.primaryPocketTarget, !shot.miscue else {
            history.append(log); return
        }
        let sim = simulation
        let geometry = TableGeometry(t)
        let pocketName = Dictionary(uniqueKeysWithValues: geometry.pockets.map { ($0.id, $0.name) })
        let pocketCenter = geometry.pockets.first { target.pocket == nil || $0.name == target.pocket }?.center
        let obStart = start.first { $0.id == target.ball }
        let counter = shotCounter
        Task { [weak self] in
            let window = await Task.detached(priority: .utility) {
                AimWindow.search(simulation: sim, balls: start, strike: strike) { r in
                    r.pocketed.contains { $0.ballId == target.ball && (target.pocket == nil || pocketName[$0.pocketId] == target.pocket) }
                }
            }.value
            guard let self, self.shotCounter == counter else { return }
            var log = log
            if var fb = self.feedback {
                fb.aimPending = false
                if let w = window {
                    let err = w.error(for: strike.aimAngle) * 180 / .pi
                    fb.aimErrorDegrees = err
                    fb.aimWindowDegrees = w.width * 180 / .pi
                    if let pc = pocketCenter, let ob = obStart {
                        let dist = simd_distance(pc, SIMD2(ob.position.x, ob.position.y))
                        fb.aimErrorMillimetersAtPocket = abs(err) * .pi / 180 * dist * 1000
                    }
                    log.aimErrorDegrees = err
                    log.aimWindowDegrees = fb.aimWindowDegrees
                }
                self.feedback = fb
            }
            self.history.append(log)
        }
    }

    /// Tên lỗ hiển thị (tiếng Việt có dấu) từ mã trong JSON bài tập.
    static func pocketLabel(_ code: String) -> String {
        [
            "goc_duoi_trai": "góc dưới trái", "goc_duoi_phai": "góc dưới phải",
            "goc_tren_trai": "góc trên trái", "goc_tren_phai": "góc trên phải",
            "giua_duoi": "giữa dưới", "giua_tren": "giữa trên"
        ][code] ?? code.replacingOccurrences(of: "_", with: " ")
    }

    static func describe(_ c: DrillCondition) -> String {
        switch c {
        case let .ballPocketed(b, p): "Bi \(b) vào lỗ" + (p.map { " (\(pocketLabel($0)))" } ?? "")
        case .cueBallInTarget: "Bi cái dừng trong vùng đích"
        case let .cueBallCushions(n): "Bi cái chạm ít nhất \(n) băng"
        case let .unknown(s): "Điều kiện lạ: \(s)"
        }
    }
}
