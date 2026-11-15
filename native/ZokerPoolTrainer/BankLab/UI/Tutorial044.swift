import UIKit

/// 0.44 (owner item 19: "hướng dẫn dắt tay chỉ điểm cho người lần đầu, chú thích từng phím như nhiều game đã làm,
/// thay vì chỉ hướng dẫn trong menu hay file").
///
/// A coach-mark overlay: the screen dims, ONE control stays lit inside a soft spotlight with an arrowed bubble, and the
/// first six steps advance only when the player really does the action (aim, contact point, elevation, the stroke,
/// replay, undo). Then a quick tour of the remaining keys (tap to go on). The lit control keeps working through the
/// hole; everything else is blocked so the player cannot get lost. "Bỏ qua" at any time; Menu → "Hướng dẫn chơi"
/// replays it; Tuỳ chỉnh can switch the first-launch tour off (tutorialEnabled044).
final class TutorialOverlay: UIView {
    struct Step {
        let target: () -> CGRect?          // in the overlay's coordinates; nil = no hole
        let title: String
        let text: String
        let done: (() -> Bool)?             // nil = advances with "Tiếp"
        var passThrough = false             // the action happens outside the lit control (the stroke on the table)
    }
    private var steps: [Step] = []
    private var index = 0
    private let dim = CAShapeLayer(), ring = CAShapeLayer()
    private let bubble = UIView(), titleLabel = UILabel(), textLabel = UILabel(), counter = UILabel()
    private let next = UIButton(type: .system), skip = UIButton(type: .system)
    private var timer: Timer?
    private var hole: CGRect = .null
    var finished: (() -> Void)?

    init(frame: CGRect, steps: [Step]) {
        self.steps = steps
        super.init(frame: frame)
        accessibilityIdentifier = "TutorialOverlay"
        dim.fillRule = .evenOdd; dim.fillColor = UIColor(white: 0, alpha: 0.62).cgColor; layer.addSublayer(dim)
        ring.fillColor = UIColor.clear.cgColor; ring.strokeColor = UIColor.rgb(0xEAC583).cgColor; ring.lineWidth = 2.5
        ring.shadowColor = UIColor.rgb(0xEAC583).cgColor; ring.shadowOpacity = 0.9; ring.shadowRadius = 8; ring.shadowOffset = .zero
        layer.addSublayer(ring)
        let pulse = CABasicAnimation(keyPath: "lineWidth"); pulse.fromValue = 2; pulse.toValue = 4.5; pulse.duration = 0.8
        pulse.autoreverses = true; pulse.repeatCount = .infinity; ring.add(pulse, forKey: "pulse")
        bubble.backgroundColor = UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.96); bubble.layer.cornerRadius = 14
        bubble.layer.borderColor = UIColor.rgb(0xEAC583).withAlphaComponent(0.7).cgColor; bubble.layer.borderWidth = 1
        titleLabel.font = .systemFont(ofSize: 16, weight: .heavy); titleLabel.textColor = .rgb(0xEAC583); titleLabel.numberOfLines = 0
        textLabel.font = .systemFont(ofSize: 14, weight: .medium); textLabel.textColor = .white; textLabel.numberOfLines = 0
        counter.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold); counter.textColor = UIColor(white: 1, alpha: 0.55)
        next.setTitle("Tiếp ›", for: .normal); next.tintColor = .rgb(0xEAC583); next.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        next.accessibilityIdentifier = "TutorialNext"
        skip.setTitle("Bỏ qua", for: .normal); skip.tintColor = UIColor(white: 1, alpha: 0.7); skip.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        skip.accessibilityIdentifier = "TutorialSkip"
        next.addAction(UIAction { [weak self] _ in self?.advance() }, for: .touchUpInside)
        skip.addAction(UIAction { [weak self] _ in self?.close() }, for: .touchUpInside)
        for v in [titleLabel, textLabel, counter, next, skip] as [UIView] { bubble.addSubview(v) }
        addSubview(bubble)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func start() {
        show(0)
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.poll() }
    }
    private func poll() {
        guard steps.indices.contains(index) else { return }
        if let done = steps[index].done, done() { advance(); return }
        layoutStep(animated: false)   // the lit control can move (HUD relayout, rotation)
    }
    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if index + 1 >= steps.count { close(); return }
        show(index + 1)
    }
    private func show(_ i: Int) {
        index = i
        let step = steps[i]
        titleLabel.text = step.title; textLabel.text = step.text
        counter.text = "\(i + 1)/\(steps.count)"
        next.setTitle(step.done == nil ? (i + 1 == steps.count ? "Xong ✓" : "Tiếp ›") : "Làm thử ↑", for: .normal)
        next.isEnabled = step.done == nil
        next.alpha = step.done == nil ? 1 : 0.55
        layoutStep(animated: true)
        UIAccessibility.post(notification: .announcement, argument: step.title + ". " + step.text)
    }
    private func layoutStep(animated: Bool) {
        let target = steps[index].target() ?? .null
        let lit = target.isNull ? CGRect.null : target.insetBy(dx: -10, dy: -10)
        if lit == hole && !animated { return }
        hole = lit
        let full = UIBezierPath(rect: bounds)
        if !lit.isNull { full.append(UIBezierPath(roundedRect: lit, cornerRadius: min(22, lit.height / 2))) }
        CATransaction.begin(); CATransaction.setAnimationDuration(animated ? 0.3 : 0)
        dim.path = full.cgPath
        ring.path = lit.isNull ? nil : UIBezierPath(roundedRect: lit, cornerRadius: min(22, lit.height / 2)).cgPath
        CATransaction.commit()
        // bubble: beside the lit area, on the side with the most room, never over it
        let width = min(340, bounds.width - 32)
        titleLabel.frame = CGRect(x: 16, y: 14, width: width - 32, height: 0); titleLabel.sizeToFit()
        textLabel.frame = CGRect(x: 16, y: titleLabel.frame.maxY + 6, width: width - 32, height: 0); textLabel.sizeToFit()
        let rowY = textLabel.frame.maxY + 10
        counter.frame = CGRect(x: 16, y: rowY + 8, width: 60, height: 20)
        skip.frame = CGRect(x: width - 196, y: rowY, width: 80, height: 36)
        next.frame = CGRect(x: width - 112, y: rowY, width: 100, height: 36)
        let height = rowY + 46
        var origin: CGPoint
        if lit.isNull { origin = CGPoint(x: bounds.midX - width / 2, y: bounds.midY - height / 2) }
        else {
            let room = [("right", bounds.maxX - lit.maxX), ("left", lit.minX), ("above", lit.minY), ("below", bounds.maxY - lit.maxY)]
            let side = room.max { $0.1 < $1.1 }!.0
            switch side {
            case "right": origin = CGPoint(x: lit.maxX + 16, y: lit.midY - height / 2)
            case "left": origin = CGPoint(x: lit.minX - 16 - width, y: lit.midY - height / 2)
            case "above": origin = CGPoint(x: lit.midX - width / 2, y: lit.minY - 16 - height)
            default: origin = CGPoint(x: lit.midX - width / 2, y: lit.maxY + 16)
            }
        }
        let safe = bounds.inset(by: safeAreaInsets).insetBy(dx: 8, dy: 8)
        origin.x = max(safe.minX, min(safe.maxX - width, origin.x)); origin.y = max(safe.minY, min(safe.maxY - height, origin.y))
        let frame = CGRect(origin: origin, size: CGSize(width: width, height: height))
        if animated { UIView.animate(withDuration: 0.3) { self.bubble.frame = frame } } else { bubble.frame = frame }
    }
    /// Touches inside the lit hole reach the real control; the bubble works; everything else is blocked.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if bubble.frame.contains(point) { return super.hitTest(point, with: event) }
        if !hole.isNull && hole.contains(point) { return nil }
        if steps.indices.contains(index) && steps[index].passThrough { return nil }
        return self
    }
    override func layoutSubviews() { super.layoutSubviews(); dim.frame = bounds; ring.frame = bounds; if steps.indices.contains(index) { layoutStep(animated: false) } }
    private func close() {
        timer?.invalidate(); timer = nil
        UIView.animate(withDuration: 0.25, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview(); self.finished?() }
    }
}

extension TrainingController {
    static let tutorialSeenKey = "tutorial044Seen"
    /// First launch (after the intro), practice mode. QA: --tutorial-qa forces it; visual/G1 QA never shows it.
    func maybeStartTutorial() {
        let args = ProcessInfo.processInfo.arguments
        let qa = args.contains("--tutorial-qa")
        if !qa && (args.contains("--visual-qa") || args.contains("--g1-default-qa") || args.contains { $0.hasPrefix("--ux0") || $0.hasPrefix("--g1-") }) { return }
        guard qa || ((UserDefaults.standard.object(forKey: "tutorialEnabled044") as? Bool ?? true) && !UserDefaults.standard.bool(forKey: Self.tutorialSeenKey)) else { return }
        let delay = qa ? 0.5 : (UserDefaults.standard.bool(forKey: "intro043Seen") ? 6.2 : 1.0)   // after the intro
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.startTutorial() }
    }
    /// Menu → "Hướng dẫn chơi".
    func startTutorial() {
        guard view.window != nil, !matchPlay.active, replayIndex == nil, view.subviews.first(where: { $0 is TutorialOverlay }) == nil else { return }
        UserDefaults.standard.set(true, forKey: Self.tutorialSeenKey)
        let startAngle = angle, startSide = side, startTop = top, startElevation = table.cueElevation
        var shotsAtStart = attempts
        func frame(_ v: UIView?) -> CGRect? {
            guard let v = v, v.window != nil, !v.isHidden, v.alpha > 0.01 else { return nil }
            return v.convert(v.bounds, to: view)
        }
        let tableRect: () -> CGRect? = { [weak self] in
            guard let self = self else { return nil }
            let b = self.view.bounds; return CGRect(x: b.width * 0.30, y: b.height * 0.25, width: b.width * 0.40, height: b.height * 0.40)
        }
        var steps: [TutorialOverlay.Step] = [
            .init(target: { nil }, title: "Chào mừng tới Zoker Pool 👋",
                  text: "Một phút để đánh cú đầu tiên. Làm theo phần được chiếu sáng — mỗi bước chỉ cần một thao tác.", done: nil),
            .init(target: tableRect, title: "1 · Ngắm",
                  text: "Kéo MỘT ngón trên mặt bàn để xoay hướng đánh. Hai ngón: xoay / kéo camera, chụm để phóng to.",
                  done: { [weak self] in guard let self = self else { return false }; return abs(self.angle - startAngle) > 0.05 }),
            .init(target: { [weak self] in frame(self?.spin) }, title: "2 · Điểm chạm đầu cơ (bi effect)",
                  text: "Chạm và kéo trên bi trắng nhỏ để chọn điểm đánh: trên = theo, dưới = kéo, trái/phải = effect. Vòng cam là giới hạn thật.",
                  done: { [weak self] in guard let self = self else { return false }; return abs(self.side - startSide) + abs(self.top - startTop) > 0.08 }),
            .init(target: { [weak self] in frame(self?.elevationPad) }, title: "3 · Độ dốc cơ",
                  text: "Kéo cung này để nâng đuôi cơ (cho Jump, Massé hoặc khi bi sát băng). Cú thường để gần 0°.",
                  done: { [weak self] in guard let self = self else { return false }; return abs(self.table.cueElevation - startElevation) > 2 }),
            .init(target: { [weak self] in frame(self?.lockButton) }, title: "4 · Ra cơ",
                  text: "Chạm giữ B để khoá hướng, rồi vuốt LÙI trên bàn và ĐẨY tới. Đẩy càng nhanh cú càng mạnh — thang lực 7 màu hiện ở góc trên.",
                  done: { [weak self] in guard let self = self else { return false }; return self.attempts > shotsAtStart }, passThrough: true),
            .init(target: { [weak self] in frame(self?.quickReplay) }, title: "5 · Xem lại",
                  text: "Xem lại cú vừa đánh với nhiều góc máy, tua chậm, và xuất video MP4 để chia sẻ.",
                  done: { [weak self] in self?.replayIndex != nil }),
            .init(target: { [weak self] in frame(self?.retryButton) }, title: "6 · Lùi cú",
                  text: "Đưa bi về trước cú đánh — giữ nguyên góc ngắm, điểm chạm, độ dốc và loại cơ để thử lại ngay.",
                  done: nil)
        ]
        let tour: [(UIView?, String, String)] = [
            (cueIcons.first?.superview == nil ? nil : cueIcons.first, "Loại cú", "Đánh · Jump · Massé · Break — mỗi phím dùng cây cơ tương ứng trong bao."),
            (quickPlace, "Đặt bi", "Kéo bi tới vị trí bất kỳ, kể cả sát băng hoặc chạm bi khác."),
            (quickAdd, "Thêm bi", "Thêm bi mục tiêu để dựng thế bài tập của riêng bạn."),
            (quickRole, "Bao cơ", "Xem cơ trong bao, thêm cơ mới (10 mẫu Zoker) — màu, đầu tẩy hiện ngay trên các phím cơ."),
            (quickCamera, "Camera", "Chạm: đổi góc ngắm / toàn cảnh. Giữ: nhìn tạm góc kia, thả là quay lại."),
            (coachButton, "Coach", "Bật trợ giúp: nút số kim cương và điểm ngắm. \"Chấm cú\" bật bảng chấm điểm khi bạn muốn."),
            (menuButton, "Menu", "Bài tập, đấu với máy, chơi Wi‑Fi, phòng chơi, bàn, Tuỳ chỉnh — và \"Hướng dẫn chơi\" để xem lại hướng dẫn này.")
        ]
        for (control, name, text) in tour {
            steps.append(.init(target: { frame(control) }, title: name, text: text, done: nil))
        }
        steps.append(.init(target: { nil }, title: "Sẵn sàng!", text: "Chúc bạn đánh hay. Mọi lúc: Menu → Hướng dẫn chơi.", done: nil))
        let overlay = TutorialOverlay(frame: view.bounds, steps: steps)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.finished = { [weak self] in self?.notifyStatus("Menu → Hướng dẫn chơi để xem lại") }
        view.addSubview(overlay)
        shotsAtStart = attempts
        overlay.start()
    }
}
