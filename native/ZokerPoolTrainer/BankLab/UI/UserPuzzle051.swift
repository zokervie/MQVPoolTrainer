import UIKit

/// 0.51 N3 — "Đặt thế bí cho bạn": arrange the cue ball, ball 1 and 0–2 grey balls, pick the kind (pocket / reach / hide), "Kiểm thế" runs the checker's
/// quick route search off the main thread (BLDrillQuickFamilies), and only a layout with at least one route can be sent. The code is 15 characters
/// (BLUserPuzzleEncode), shown XXXXX-XXXXX-XXXXX with the line "Thế bí của tôi: <mã>". A receiver types it in, the app rebuilds the layout and
/// RE-CHECKS it on the receiving device, then it plays like any puzzle (no room stars). Not built yet: using the 3D table for the arrangement.
final class PuzzleEditBoardView: UIView {
    var balls: [(x: Double, y: Double)] = [(-0.25, -0.55), (0.2, 0.45)]   // cue, ball 1, blockers…
    var onChange: (() -> Void)?
    private var dragging: Int?
    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = UIColor(red: 0.07, green: 0.045, blue: 0.03, alpha: 1); layer.cornerRadius = 12; clipsToBounds = true
        accessibilityIdentifier = "PuzzleEditBoard"; isAccessibilityElement = true; accessibilityLabel = "Puzzle arrangement board"
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var scale: CGFloat { min((bounds.width - 6) / 3.28, (bounds.height - 22) / 1.64) }
    private var centre: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY - 8) }
    private func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: centre.x + CGFloat(y) * scale, y: centre.y + CGFloat(x) * scale) }
    private func table(_ p: CGPoint) -> (Double, Double) { (Double((p.y - centre.y) / scale), Double((p.x - centre.x) / scale)) }
    @objc private func pan(_ g: UIPanGestureRecognizer) {
        let t = table(g.location(in: self))
        switch g.state {
        case .began:
            let start = table(g.location(in: self))
            dragging = balls.indices.min { hypot(balls[$0].x - start.0, balls[$0].y - start.1) < hypot(balls[$1].x - start.0, balls[$1].y - start.1) }
            if let i = dragging, hypot(balls[i].x - start.0, balls[i].y - start.1) > 0.12 { dragging = nil }
        case .changed:
            if let i = dragging { balls[i] = ((t.0 * 100).rounded() / 100, (t.1 * 100).rounded() / 100); setNeedsDisplay(); onChange?() }
        default: dragging = nil
        }
    }
    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        if let picture = DrillTableImage.image() {
            c.saveGState(); c.translateBy(x: centre.x, y: centre.y); c.scaleBy(x: 1, y: -1)
            picture.draw(in: CGRect(x: -1.64 * scale, y: -0.82 * scale, width: 3.28 * scale, height: 1.64 * scale)); c.restoreGState()
        }
        let r = max(6, CGFloat(0.0286) * scale * 1.4)
        for (i, b) in balls.enumerated() {
            let q = point(b.x, b.y), box = CGRect(x: q.x - r, y: q.y - r, width: 2 * r, height: 2 * r)
            (i == 0 ? UIColor.white : (i == 1 ? UIColor(red: 1, green: 0.63, blue: 0.1, alpha: 1) : UIColor(white: 0.35, alpha: 1))).setFill()
            c.fillEllipse(in: box); c.setStrokeColor(UIColor.black.withAlphaComponent(0.6).cgColor); c.setLineWidth(1.2); c.strokeEllipse(in: box)
        }
    }
}

final class UserPuzzleController: UIViewController {
    private let board = PuzzleEditBoardView(frame: .zero)
    private let style = UISegmentedControl(items: [L10n.tr("Vào lỗ"), L10n.tr("Chạm bi 1"), L10n.tr("Giấu bi")])
    private let status = UILabel(), codeLabel = UILabel()
    private var checkButton: UIButton!, sendButton: UIButton!, spinner = UIActivityIndicatorView(style: .medium)
    private var checked: (spec: BLPuzzleSpec, code: String)?
    private var gate = CheckGate()   // 0.55 R1
    private let tally = UILabel(), beta = UILabel(), shareNote = UILabel()
    var onPlay: ((BLPuzzleSpec, String) -> Void)?
    static var lastCode = "", lastCheck = "", lastShare = ""
    /// 0.55 R3: the line sent to a friend — name, kind, code, a question; no aim line and no solution.
    static func shareLine(style: String, code: String) -> String {
        "Zokervie · " + L10n.tr("Thế bí của tôi") + " (\(style)): " + code + " — " + L10n.tr("bạn giải được không?")
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    static func styleIndex(_ s: Int) -> Int { s == Int(BL_PUZZLE_REACH) ? 1 : (s == Int(BL_PUZZLE_HIDE) ? 2 : 0) }
    var currentStyle: Int32 { [Int32(BL_PUZZLE_POT), Int32(BL_PUZZLE_REACH), Int32(BL_PUZZLE_HIDE)][max(0, min(2, style.selectedSegmentIndex))] }

    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1); view.accessibilityIdentifier = "UserPuzzle"
        let title = Wood.titleLabel(L10n.tr("Đặt thế bí cho bạn"), size: 26); title.textColor = ZDesign.Color.gold; title.layer.shadowOpacity = 0
        beta.text = L10n.tr("Thử nghiệm"); beta.font = .systemFont(ofSize: 10, weight: .bold); beta.textColor = .black; beta.backgroundColor = ZDesign.Color.gold
        beta.textAlignment = .center; beta.layer.cornerRadius = 4; beta.clipsToBounds = true; beta.accessibilityIdentifier = "UserPuzzleBeta"
        beta.widthAnchor.constraint(equalToConstant: 76).isActive = true
        #if !DEBUG
        beta.isHidden = true   // 0.59 App Review 2.2: no "beta/trial" labelling in the store build (UI tests run Debug)
        #endif
        tally.font = .systemFont(ofSize: 10); tally.textColor = UIColor(white: 0.7, alpha: 1); tally.numberOfLines = 0; tally.accessibilityIdentifier = "UserPuzzleTally"
        shareNote.font = .systemFont(ofSize: 10); shareNote.textColor = UIColor(white: 0.85, alpha: 1); shareNote.numberOfLines = 0; shareNote.accessibilityIdentifier = "UserPuzzleShareLine"
        style.selectedSegmentIndex = 0; style.accessibilityIdentifier = "UserPuzzleStyle"; style.addAction(UIAction { [weak self] _ in self?.changed() }, for: .valueChanged)
        status.textColor = .white; status.font = .systemFont(ofSize: 14, weight: .semibold); status.numberOfLines = 0; status.accessibilityIdentifier = "UserPuzzleStatus"
        codeLabel.textColor = ZDesign.Color.gold; codeLabel.font = .monospacedSystemFont(ofSize: 18, weight: .bold); codeLabel.numberOfLines = 0; codeLabel.accessibilityIdentifier = "UserPuzzleCode"
        func button(_ t: String, _ id: String, filled: Bool = false) -> UIButton {
            var c = filled ? UIButton.Configuration.filled() : UIButton.Configuration.tinted(); c.title = t; c.cornerStyle = .capsule
            if filled { c.baseBackgroundColor = ZDesign.Color.gold; c.baseForegroundColor = .black }
            let b = UIButton(configuration: c); b.accessibilityIdentifier = id; b.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true; return b
        }
        let add = button(L10n.tr("Thêm bi xám"), "UserPuzzleAdd"), remove = button(L10n.tr("Bớt bi xám"), "UserPuzzleRemove")
        checkButton = button(L10n.tr("Kiểm thế"), "UserPuzzleCheck", filled: true); sendButton = button(L10n.tr("Gửi"), "UserPuzzleSend")
        let enter = button(L10n.tr("Nhập mã"), "UserPuzzleEnter"), close = button(L10n.tr("Đóng"), "UserPuzzleClose")
        sendButton.isEnabled = false
        add.addAction(UIAction { [weak self] _ in guard let s = self, s.board.balls.count < 4 else { return }; s.board.balls.append((0, 0.1 * Double(s.board.balls.count))); s.board.setNeedsDisplay(); s.changed() }, for: .touchUpInside)
        remove.addAction(UIAction { [weak self] _ in guard let s = self, s.board.balls.count > 2 else { return }; s.board.balls.removeLast(); s.board.setNeedsDisplay(); s.changed() }, for: .touchUpInside)
        checkButton.addAction(UIAction { [weak self] _ in self?.check() }, for: .touchUpInside)
        sendButton.addAction(UIAction { [weak self] _ in self?.send() }, for: .touchUpInside)
        enter.addAction(UIAction { [weak self] _ in self?.enterCode() }, for: .touchUpInside)
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        let side = UIStackView(arrangedSubviews: [title, beta, style, add, remove, checkButton, spinner, status, sendButton, codeLabel, shareNote, enter, close, tally]); side.axis = .vertical; side.spacing = 8
        board.translatesAutoresizingMaskIntoConstraints = false; side.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(side)
        view.addSubview(board); view.addSubview(scroll)
        NSLayoutConstraint.activate([
            board.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12), board.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            board.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12), board.trailingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: -12),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12), scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12), scroll.widthAnchor.constraint(equalToConstant: 250),
            side.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), side.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            side.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), side.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            side.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
        board.onChange = { [weak self] in self?.changed() }
        if QA.has("--user-puzzle-qa"), let p = BLPuzzleAt(0)?.pointee {   // QA: start from the catalogue puzzle p-1-01 (it has routes), so the test is deterministic
            board.balls = withUnsafePointer(to: p.spec.balls) { b in b.withMemoryRebound(to: BLDrillBall.self, capacity: Int(BL_DRILL_MAX_BALLS)) { q in (0..<Int(p.spec.ballCount)).map { (q[$0].x, q[$0].y) } } }
        }
        status.text = L10n.tr("Kéo bi để xếp thế, rồi bấm Kiểm thế.")
        showTally()
    }
    private func showTally() {
        let (sent, received, solved) = PlayerStore.shared.codeCounts()
        tally.text = String(format: L10n.tr("Mã đã gửi: %d · mã đã nhận và chơi: %d · mã giải được: %d"), sent, received, solved)
    }
    private func changed() { gate.bump(); checked = nil; sendButton.isEnabled = false; codeLabel.text = ""; shareNote.text = ""; status.text = L10n.tr("Kéo bi để xếp thế, rồi bấm Kiểm thế.") }
    /// Layout → code → spec (what the receiver gets), or nil with the reason shown.
    private func buildSpec() -> (BLPuzzleSpec, String)? {
        let xs = board.balls.map { $0.x }, ys = board.balls.map { $0.y }
        guard BLUserPuzzleValid(currentStyle, Int32(xs.count), xs, ys) != 0 else {
            status.text = L10n.tr("Thế chưa hợp lệ: bi cách băng ≥ 4 cm, cách nhau ≥ 7 cm; Chạm bi 1 và Giấu bi cần một bi xám."); return nil
        }
        var buf = [CChar](repeating: 0, count: 32)
        guard BLUserPuzzleEncode(currentStyle, Int32(xs.count), xs, ys, &buf) != 0 else { status.text = L10n.tr("Không mã hoá được thế này (làm tròn làm bi chạm nhau)."); return nil }
        let code = String(cString: buf)
        var spec = BLPuzzleSpec()
        guard BLUserPuzzleDecode(code, &spec) != 0 else { status.text = L10n.tr("Thế chưa hợp lệ."); return nil }
        spec.style = currentStyle
        return (spec, code)
    }
    private func setEditing(_ on: Bool) {
        board.isUserInteractionEnabled = on
        for v in view.subviews.flatMap({ $0.subviews }) where v is UIStackView { (v as? UIStackView)?.arrangedSubviews.forEach { if $0 is UIButton && $0 !== checkButton || $0 is UISegmentedControl { ($0 as? UIControl)?.isEnabled = on } } }
        sendButton.isEnabled = on && checked != nil
    }
    private func check() {
        guard var (spec, code) = buildSpec() else { Self.lastCheck = "invalid"; return }
        spinner.startAnimating(); checkButton.isEnabled = false; status.text = L10n.tr("Đang kiểm thế…")
        let ticket = gate.begin(); setEditing(false)   // 0.55 R1: no dragging while the check runs, and a stale result is never published
        let race = QA.has("--user-puzzle-race-qa")   // QA: a change "slips through" 0.5 s into a deliberately slow check
        if race { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.changed() } }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if race { Thread.sleep(forTimeInterval: 2.5) }
            var routes = [BLPuzzleSolution](repeating: BLPuzzleSolution(), count: Int(BL_PUZZLE_MAX_SOLUTIONS))
            let n = Int(BLDrillQuickFamilies(&spec.spec, &routes, Int32(BL_PUZZLE_MAX_SOLUTIONS)))
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.spinner.stopAnimating(); self.checkButton.isEnabled = true; self.setEditing(true)
                guard self.gate.accepts(ticket) else { return }   // the layout changed meanwhile
                guard n > 0 else { self.status.text = L10n.tr("Chưa tìm thấy lời giải, dời một bi."); Self.lastCheck = "none"; return }
                withUnsafeMutablePointer(to: &spec.solutions) { s in s.withMemoryRebound(to: BLPuzzleSolution.self, capacity: Int(BL_PUZZLE_MAX_SOLUTIONS)) { for i in 0..<n { $0[i] = routes[i] } } }
                spec.solutionCount = Int32(n)
                let best = routes.prefix(n).map { Int($0.percent) }.max() ?? 0
                self.status.text = String(format: L10n.tr("%d lời giải, dễ nhất vào %d %%"), n, best)
                self.checked = (spec, code); self.sendButton.isEnabled = true; Self.lastCheck = "ok:\(n):\(best)"
            }
        }
    }
    static func pretty(_ code: String) -> String { stride(from: 0, to: code.count, by: 5).map { String(code.dropFirst($0).prefix(5)) }.joined(separator: "-") }
    private func send() {
        guard let (_, code) = checked else { return }
        let pretty = Self.pretty(code); codeLabel.text = pretty; Self.lastCode = code
        PlayerStore.shared.noteCodeSent(); showTally()
        let styleName = [L10n.tr("Vào lỗ"), L10n.tr("Chạm bi 1"), L10n.tr("Giấu bi")][max(0, min(2, style.selectedSegmentIndex))]
        let line = Self.shareLine(style: styleName, code: pretty); Self.lastShare = line; shareNote.text = line
        let share = UIActivityViewController(activityItems: [line], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = sendButton; share.popoverPresentationController?.sourceRect = sendButton.bounds
        present(share, animated: true)
    }
    private func enterCode() {
        let alert = UIAlertController(title: L10n.tr("Nhập mã thế bí"), message: L10n.tr("15 ký tự, ví dụ XXXXX-XXXXX-XXXXX"), preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "XXXXX-XXXXX-XXXXX"; field.autocapitalizationType = .allCharacters; field.accessibilityIdentifier = "UserPuzzleCodeField"
            // 0.55 R4: "Dán" reads the clipboard only when the player taps it
            var c = UIButton.Configuration.plain(); c.title = L10n.tr("Dán"); c.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
            let paste = UIButton(configuration: c); paste.accessibilityIdentifier = "UserPuzzlePaste"
            paste.addAction(UIAction { [weak field] _ in if let s = UIPasteboard.general.string { field?.text = s } }, for: .touchUpInside)
            paste.sizeToFit(); field.rightView = paste; field.rightViewMode = .always
        }
        alert.addAction(UIAlertAction(title: L10n.tr("Kiểm tra và chơi"), style: .default) { [weak self, weak alert] _ in self?.receive(alert?.textFields?.first?.text ?? "") })
        alert.addAction(UIAlertAction(title: L10n.tr("Đóng"), style: .cancel)); present(alert, animated: true)
    }
    /// A received code: decode, then verify again HERE with the quick route search; refused when it cannot be solved.
    func receive(_ text: String) {
        var spec = BLPuzzleSpec()
        guard BLUserPuzzleDecode(text, &spec) != 0 else { status.text = L10n.tr("Mã không đúng."); Self.lastCheck = "badcode"; return }
        spinner.startAnimating(); status.text = L10n.tr("Đang kiểm thế…")
        let ticket = gate.begin(); setEditing(false)
        let code = text.filter { $0 != "-" && $0 != " " }.uppercased()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var routes = [BLPuzzleSolution](repeating: BLPuzzleSolution(), count: Int(BL_PUZZLE_MAX_SOLUTIONS))
            let n = Int(BLDrillQuickFamilies(&spec.spec, &routes, Int32(BL_PUZZLE_MAX_SOLUTIONS)))
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.spinner.stopAnimating(); self.setEditing(true)
                guard self.gate.accepts(ticket) else { return }
                guard n > 0 else { self.status.text = L10n.tr("Thế này không giải được, mã bị từ chối."); Self.lastCheck = "refused"; return }
                withUnsafeMutablePointer(to: &spec.solutions) { s in s.withMemoryRebound(to: BLPuzzleSolution.self, capacity: Int(BL_PUZZLE_MAX_SOLUTIONS)) { for i in 0..<n { $0[i] = routes[i] } } }
                spec.solutionCount = Int32(n); Self.lastCheck = "received:\(n)"
                // 0.55 R4: before playing, what the check found
                let best = routes.prefix(n).map { Int($0.percent) }.max() ?? 0
                let ready = UIAlertController(title: String(format: L10n.tr("%d lời giải · dễ nhất vào %d %%"), n, best), message: L10n.tr("Thế đã được kiểm lại trên máy này."), preferredStyle: .alert)
                ready.view.accessibilityIdentifier = "UserPuzzleReady"
                ready.addAction(UIAlertAction(title: L10n.tr("Chơi"), style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    PlayerStore.shared.noteCodeReceived(); self.showTally()
                    self.dismiss(animated: true) { self.onPlay?(spec, code) }
                })
                ready.addAction(UIAlertAction(title: L10n.tr("Đóng"), style: .cancel))
                self.present(ready, animated: true)
            }
        }
    }
}

extension TrainingController {
    func openUserPuzzle() {
        guard !shotActive, replayIndex == nil else { return }
        let vc = UserPuzzleController(); vc.modalPresentationStyle = .fullScreen
        vc.onPlay = { [weak self] spec, code in self?.beginUserPuzzle(spec, code: code) }
        topPresenter.present(vc, animated: true)
    }
    /// A friend's puzzle: the layout becomes a drill (registered after the catalogue), played like any puzzle — no room stars, no hints.
    func beginUserPuzzle(_ spec: BLPuzzleSpec, code: String) {
        var d = DrillCatalog.make(spec.spec, old: nil, title: L10n.tr("Thế bí của bạn bè")); d.id = "user"; d.level = 0
        let index = Drill.registerUser(d)
        beginPuzzle(-1, user: spec, userCode: code, userDrillIndex: index)
    }
}
