import UIKit

/// 0.51 N2 — "Đoán đường bi": a layout and a stroke are shown (aim arrow, pace, tip), the player marks where the CUE BALL will stop, the app
/// plays that stroke on the real solver and scores the distance (BLPredictScore). The score moves the "Chỉ số Mắt" (Elo, BLEyeUpdate);
/// only the first 5 predictions a day count. Analysis mode: the stroke is drawn on purpose; never part of the main (no-help) mode.
/// Not built yet: the 0.5× slow replay of the last part, and the loupe while dragging.
final class PredictBoardView: UIView {
    var spec: BLPuzzleSpec?
    var angle = 0.0, speed = 0.0, top = 0.0
    var mark: (x: Double, y: Double)?
    var truth: (x: Double, y: Double)?
    var onMark: (() -> Void)?
    private let long = 2.54, short = 1.27
    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = UIColor(red: 0.07, green: 0.045, blue: 0.03, alpha: 1); layer.cornerRadius = 12; clipsToBounds = true
        accessibilityIdentifier = "PredictBoard"; isAccessibilityElement = true; accessibilityLabel = "Predict board"
        let tap = UITapGestureRecognizer(target: self, action: #selector(touch(_:))), pan = UIPanGestureRecognizer(target: self, action: #selector(touch(_:)))
        addGestureRecognizer(tap); addGestureRecognizer(pan)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var scale: CGFloat { min((bounds.width - 6) / 3.28, (bounds.height - 22) / 1.64) }
    private var centre: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY - 8) }
    private func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: centre.x + CGFloat(y) * scale, y: centre.y + CGFloat(x) * scale) }
    /// The inverse of `point` (same mapping as the drill diagram).
    func table(_ p: CGPoint) -> (Double, Double) { (Double((p.y - centre.y) / scale), Double((p.x - centre.x) / scale)) }
    @objc private func touch(_ g: UIGestureRecognizer) {
        guard truth == nil else { return }
        let (x, y) = table(g.location(in: self))
        mark = (max(-0.6, min(0.6, x)), max(-1.24, min(1.24, y)))
        setNeedsDisplay(); onMark?()
    }
    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        if let picture = DrillTableImage.image() {
            c.saveGState(); c.translateBy(x: centre.x, y: centre.y); c.scaleBy(x: 1, y: -1)
            picture.draw(in: CGRect(x: -1.64 * scale, y: -0.82 * scale, width: 3.28 * scale, height: 1.64 * scale)); c.restoreGState()
        } else {
            let t = CGRect(x: centre.x - CGFloat(long / 2) * scale, y: centre.y - CGFloat(short / 2) * scale, width: CGFloat(long) * scale, height: CGFloat(short) * scale)
            UIColor(red: 0.06, green: 0.38, blue: 0.34, alpha: 1).setFill(); c.fill(t)
        }
        guard let s = spec else { return }
        let r = max(5, CGFloat(0.0286) * scale * 1.25)
        var cueAt: (Double, Double)?
        withUnsafePointer(to: s.spec.balls) { p in
            p.withMemoryRebound(to: BLDrillBall.self, capacity: Int(BL_DRILL_MAX_BALLS)) { b in
                for i in 0..<Int(s.spec.ballCount) {
                    let q = point(b[i].x, b[i].y), box = CGRect(x: q.x - r, y: q.y - r, width: 2 * r, height: 2 * r)
                    let id = b[i].id
                    (id == 0 ? UIColor.white : (id == 1 ? UIColor(red: 1, green: 0.63, blue: 0.1, alpha: 1) : UIColor(white: 0.35, alpha: 1))).setFill()
                    c.fillEllipse(in: box); c.setStrokeColor(UIColor.black.withAlphaComponent(0.55).cgColor); c.setLineWidth(1); c.strokeEllipse(in: box)
                    if id == 0 { cueAt = (b[i].x, b[i].y) }
                }
            }
        }
        // the stroke: arrow from the cue ball along the aim, length grows with pace; tip offset as a small dot
        if let (cx, cy) = cueAt {
            let from = point(cx, cy)
            let end = point(cx + cos(angle) * (0.12 + 0.10 * speed), cy + sin(angle) * (0.12 + 0.10 * speed))
            c.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor); c.setLineWidth(2.5); c.move(to: from); c.addLine(to: end); c.strokePath()
            let dx = end.x - from.x, dy = end.y - from.y, l = max(1, hypot(dx, dy)), ux = dx / l, uy = dy / l
            c.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            c.move(to: end); c.addLine(to: CGPoint(x: end.x - ux * 12 - uy * 6, y: end.y - uy * 12 + ux * 6)); c.addLine(to: CGPoint(x: end.x - ux * 12 + uy * 6, y: end.y - uy * 12 - ux * 6)); c.closePath(); c.fillPath()
        }
        if let m = mark {
            let q = point(m.x, m.y)
            c.setStrokeColor(UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1).cgColor); c.setLineWidth(2.5); c.strokeEllipse(in: CGRect(x: q.x - r * 1.6, y: q.y - r * 1.6, width: r * 3.2, height: r * 3.2))
            c.move(to: CGPoint(x: q.x - r, y: q.y)); c.addLine(to: CGPoint(x: q.x + r, y: q.y)); c.move(to: CGPoint(x: q.x, y: q.y - r)); c.addLine(to: CGPoint(x: q.x, y: q.y + r)); c.strokePath()
        }
        if let t = truth {
            let q = point(t.x, t.y)
            if let m = mark { c.setStrokeColor(UIColor.systemGreen.withAlphaComponent(0.8).cgColor); c.setLineWidth(1.5); c.setLineDash(phase: 0, lengths: [4, 3]); c.move(to: point(m.x, m.y)); c.addLine(to: q); c.strokePath(); c.setLineDash(phase: 0, lengths: []) }
            c.setFillColor(UIColor.white.cgColor); c.fillEllipse(in: CGRect(x: q.x - r, y: q.y - r, width: 2 * r, height: 2 * r))
            c.setStrokeColor(UIColor.systemGreen.cgColor); c.setLineWidth(3); c.strokeEllipse(in: CGRect(x: q.x - r * 1.5, y: q.y - r * 1.5, width: r * 3, height: r * 3))
        }
    }
}

final class PredictController: UIViewController {
    private let board = PredictBoardView(frame: .zero)
    private let info = UILabel(), result = UILabel(), eyeLabel = UILabel()
    private var lock: UIButton!, nextButton: UIButton!
    private var roundNumber = 0
    private var spec: BLPuzzleSpec?, solutionIndex = 0, pace = 1.0
    var onResult: ((Int, Double, Double, Bool) -> Void)?   // score, error cm, eye after, counted
    static var lastScore = -1, lastErrorCm = -1.0, rounds = 0

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1); view.accessibilityIdentifier = "Predict"
        let title = Wood.titleLabel(L10n.tr("Đoán đường bi"), size: 26); title.textColor = ZDesign.Color.gold; title.layer.shadowOpacity = 0
        info.textColor = .white; info.font = .systemFont(ofSize: 14, weight: .semibold); info.numberOfLines = 0; info.accessibilityIdentifier = "PredictInfo"
        result.textColor = ZDesign.Color.gold; result.font = .systemFont(ofSize: 16, weight: .bold); result.numberOfLines = 0; result.accessibilityIdentifier = "PredictResult"
        eyeLabel.textColor = UIColor(white: 0.85, alpha: 1); eyeLabel.font = .systemFont(ofSize: 13); eyeLabel.accessibilityIdentifier = "PredictEye"
        func button(_ t: String, _ id: String, filled: Bool) -> UIButton {
            var c = filled ? UIButton.Configuration.filled() : UIButton.Configuration.tinted(); c.title = t; c.cornerStyle = .capsule
            if filled { c.baseBackgroundColor = ZDesign.Color.gold; c.baseForegroundColor = .black }
            let b = UIButton(configuration: c); b.accessibilityIdentifier = id; b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true; return b
        }
        lock = button(L10n.tr("Chốt"), "PredictLock", filled: true); nextButton = button(L10n.tr("Lượt tiếp theo"), "PredictNext", filled: false)
        let close = button(L10n.tr("Đóng"), "PredictClose", filled: false)
        lock.addAction(UIAction { [weak self] _ in self?.commit() }, for: .touchUpInside)
        nextButton.addAction(UIAction { [weak self] _ in self?.newRound() }, for: .touchUpInside)
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        let side = UIStackView(arrangedSubviews: [title, info, result, eyeLabel, lock, nextButton, close]); side.axis = .vertical; side.spacing = 10
        board.translatesAutoresizingMaskIntoConstraints = false; side.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(board); view.addSubview(side)
        NSLayoutConstraint.activate([
            board.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12), board.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            board.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            board.trailingAnchor.constraint(equalTo: side.leadingAnchor, constant: -12),
            side.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12), side.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            side.widthAnchor.constraint(equalToConstant: 230)])
        board.onMark = { [weak self] in self?.lock.isEnabled = true }
        newRound()
    }
    /// The task of today's n-th round (deterministic per date, BLPredictTask); a stroke that pockets the cue ball is skipped.
    private func newRound() {
        let day = DailyPuzzle.today()
        var number = day * 16 + Int64(roundNumber)
        var chosen: (BLPuzzleSpec, Int, Double, (Double, Double))?
        for _ in 0..<12 {
            var sol: Int32 = 0, pace = 1.0
            let i = BLPredictTask(number, &sol, &pace)
            number += 1; roundNumber += 1
            guard i >= 0, var p = BLPuzzleAt(i)?.pointee else { continue }
            let r = withUnsafePointer(to: p.solutions) { s in s.withMemoryRebound(to: BLPuzzleSolution.self, capacity: Int(BL_PUZZLE_MAX_SOLUTIONS)) { $0[Int(sol)] } }
            if let end = Self.simulateCue(&p, r, pace) { chosen = (p, Int(sol), pace, end); break }
        }
        guard let (p, sol, pace, end) = chosen else { return }
        spec = p; solutionIndex = sol; self.pace = pace; truthPoint = end
        let r = withUnsafePointer(to: p.solutions) { s in s.withMemoryRebound(to: BLPuzzleSolution.self, capacity: Int(BL_PUZZLE_MAX_SOLUTIONS)) { $0[sol] } }
        board.spec = p; board.angle = r.angle; board.speed = r.speed * pace; board.top = r.top; board.mark = nil; board.truth = nil
        board.setNeedsDisplay(); lock.isEnabled = false; lock.isHidden = false; nextButton.isHidden = true
        let scoredLeft = PlayerStore.shared.data.predictDay == day ? max(0, PlayerStore.scoredPredictionsPerDay - PlayerStore.shared.data.predictCount) : PlayerStore.scoredPredictionsPerDay
        info.text = L10n.tr("Chạm chỗ bạn nghĩ bi cái sẽ dừng, rồi bấm Chốt.") + "\n" + String(format: L10n.tr("Lực %.1f m/s"), r.speed * pace) + " · " + L10n.tr("điểm chạm") + String(format: " %+.0f%%", r.top * 100)
            + "\n" + String(format: L10n.tr("Còn %d lượt tính điểm hôm nay"), scoredLeft)
        result.text = ""
        eyeLabel.text = L10n.tr("Chỉ số Mắt") + " \(Int(PlayerStore.shared.data.eye.rounded()))"
    }
    private var truthPoint: (Double, Double) = (0, 0)
    /// The real solver, fresh world (= Config::app), the same stroke: where the cue ball stops. nil when it is pocketed.
    static func simulateCue(_ p: inout BLPuzzleSpec, _ r: BLPuzzleSolution, _ pace: Double) -> (Double, Double)? {
        let world = BLWorld()
        let balls: [[String: NSNumber]] = withUnsafePointer(to: p.spec.balls) { b in
            b.withMemoryRebound(to: BLDrillBall.self, capacity: Int(BL_DRILL_MAX_BALLS)) { q in
                (0..<Int(p.spec.ballCount)).map { ["id": NSNumber(value: q[$0].id), "x": NSNumber(value: q[$0].x), "y": NSNumber(value: q[$0].y)] }
            }
        }
        world.loadLayout(balls)
        let out = world.simulate(angle: r.angle, speed: r.speed * pace, side: 0, top: r.top)
        guard let end = out["balls"] as? [[String: NSNumber]], let cue = end.first(where: { $0["id"]?.intValue == 0 }), cue["sunk"]?.intValue != 1,
              let x = cue["x"]?.doubleValue, let y = cue["y"]?.doubleValue else { return nil }
        return (x, y)
    }
    private func commit() {
        guard let p = spec, let m = board.mark else { return }
        let err = hypot(m.x - truthPoint.0, m.y - truthPoint.1)
        let score = Int(BLPredictScore(err))
        let r = withUnsafePointer(to: p.solutions) { s in s.withMemoryRebound(to: BLPuzzleSolution.self, capacity: Int(BL_PUZZLE_MAX_SOLUTIONS)) { $0[solutionIndex] } }
        let counted = PlayerStore.shared.notePrediction(day: DailyPuzzle.today())
        let before = PlayerStore.shared.data.eye
        var after = before
        if counted {
            after = BLEyeUpdate(before, BLPredictTaskRating(r.signature, r.speed * pace), Double(score) / 100)
            PlayerStore.shared.setEye(after)
        }
        board.truth = truthPoint; board.setNeedsDisplay(); lock.isHidden = true; nextButton.isHidden = false
        result.text = String(format: L10n.tr("Lệch %.0f cm · %d điểm"), err * 100, score)
        let delta = Int((after - before).rounded())
        eyeLabel.text = L10n.tr("Chỉ số Mắt") + " \(Int(PlayerStore.shared.data.eye.rounded()))" + (counted ? String(format: " (%+d)", delta) : " · " + L10n.tr("luyện thêm, không tính điểm"))
        Self.lastScore = score; Self.lastErrorCm = err * 100; Self.rounds += 1
    }
}

extension TrainingController {
    func openPredict() {
        guard !shotActive, replayIndex == nil else { return }
        let vc = PredictController(); vc.modalPresentationStyle = .fullScreen
        topPresenter.present(vc, animated: true)
    }
}
