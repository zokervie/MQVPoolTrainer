import UIKit

/// 0.46 M1 — Sảnh mới. Thẻ "Tiếp tục" (bài/trận gần nhất, một chạm vào bàn) đứng đầu; dưới là 4 ô: Tập tự do · Bài tập ·
/// Đấu · Thư viện bàn‑cơ; hàng chip cuối giữ mọi mục cũ (Nhật ký, Cú đã lưu, Tài khoản, Tuỳ chỉnh, Hướng dẫn, Phòng thử).
/// Nền: Sảnh được present `.overFullScreen` trên TrainingController, nền là UIVisualEffectView → thấy bàn 3D thật phía
/// sau (không có scene thứ hai). viewDidAppear của TrainingController KHÔNG chạy lại khi Sảnh đóng, nên `onClosed` gọi
/// tường minh phần việc sau Sảnh (hướng dẫn, Game Center).

/// Bài gần nhất, lưu khi chơi để "Tiếp tục" mở đúng (UserDefaults, cục bộ).
enum RecentPlay {
    static let key = Prefs.recentPlay
    enum Kind { case free, drill(Int), computer(level: Int, rule: String, race: Int) }
    static func saveFree() { UserDefaults.standard.set(["kind": "free"], forKey: key) }
    static func saveDrill(_ index: Int) { UserDefaults.standard.set(["kind": "drill", "drill": index], forKey: key) }
    static func saveComputer(level: Int, rule: String, race: Int) {
        UserDefaults.standard.set(["kind": "computer", "level": level, "rule": rule, "race": race], forKey: key)
    }
    static var current: Kind? {
        guard let d = UserDefaults.standard.dictionary(forKey: key), let kind = d["kind"] as? String else { return nil }
        switch kind {
        case "free": return .free
        case "drill": if let i = d["drill"] as? Int, Drill.all.indices.contains(i) { return .drill(i) }; return nil
        case "computer":
            if let l = d["level"] as? Int, let r = d["rule"] as? String, let n = d["race"] as? Int,
               TrainingController.computerLevelTitles.indices.contains(l) { return .computer(level: l, rule: r, race: n) }
            return nil
        default: return nil
        }
    }
}

extension TrainingController {
    /// Tên + mô tả + việc làm của thẻ "Tiếp tục". Lần đầu (chưa có bài nào): "Cú đầu tiên".
    func continueCard() -> LobbyController.Resume {
        func free(_ title: String, _ subtitle: String) -> LobbyController.Resume {
            .init(title: title, subtitle: subtitle, run: { [weak self] in if self?.matchPlay.active != true { RecentPlay.saveFree() }; self?.setMenu(false) })
        }
        if matchPlay.active { return free("Tiếp tục", "Trận đang chơi") }
        guard let recent = RecentPlay.current else { return free("Cú đầu tiên", "Vào bàn và đánh thử ngay") }
        switch recent {
        case .free: return free("Tiếp tục", "Tập tự do")
        case .drill(let i):
            return .init(title: "Tiếp tục", subtitle: "Bài tập · " + Drill.all[i].title, run: { [weak self] in guard let self = self, !self.shotActive, self.replayIndex == nil, self.localTurn else { return }; self.setMenu(false); self.beginDrill(i, guided: false) })
        case .computer(let level, let rule, let race):
            let name = matchDisciplines.first { $0.0 == rule }?.1 ?? rule
            return .init(title: "Tiếp tục", subtitle: "Đấu với máy · " + Self.computerLevelTitles[level] + " · " + name + " · race \(race)",
                         run: { [weak self] in guard let self = self, !self.shotActive, self.replayIndex == nil, self.localTurn else { return }; self.setMenu(false); self.startComputerMatch(level: level, rule: rule, race: race) })
        }
    }
    /// Phần việc sau khi Sảnh đóng và hành động đã chọn đã chạy (viewDidAppear không chạy lại với `.overFullScreen`).
    /// 0.45 M5.3: lần mở app → AppFlow bước tiếp (hướng dẫn → bàn); Sảnh mở lại sau đó → kiểm tra hướng dẫn ngay, không hẹn giờ.
    func afterLobbyClosed() {
        if appFlow.step == .lobby { appFlow.done(.lobby); return }
        if presentedViewController == nil && !gameCenterAsked && !QA.anyFlag { gameCenterAsked = true; GameCenterHub.shared.authenticate() }
        maybeStartTutorial()
    }
}

final class LobbyController: UIViewController {
    struct Action { let title: String; let icon: String; let id: String; let run: () -> Void }
    struct Card { let title: String; let subtitle: String; let icon: String; let color: UIColor; let actions: [Action] }
    struct Resume { let title: String; let subtitle: String; let run: () -> Void }
    var resume: Resume?
    var cards: [Card] = []
    var footer: [Action] = []
    /// Gọi (trước khi chạy hành động đã chọn) khi Sảnh đã đóng.
    var onClosed: (() -> Void)?
    static let practice = UIColor.rgb(0x2FA36E), match = UIColor.rgb(0xE8833A), profile = UIColor.rgb(0x3D86DA), gold = UIColor.rgb(0xEAC583)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        view.accessibilityViewIsModal = true   // review 0.46: VoiceOver/XCUITest never reach the HUD behind the lobby
        super.viewDidLoad()
        view.backgroundColor = .clear; view.accessibilityIdentifier = "Lobby"
        // Bàn 3D thật phía sau, mờ nhẹ.
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(blur)
        let dim = UIView(); dim.backgroundColor = UIColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 0.42)
        dim.translatesAutoresizingMaskIntoConstraints = false; blur.contentView.addSubview(dim)
        NSLayoutConstraint.activate([blur.leadingAnchor.constraint(equalTo: view.leadingAnchor), blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                     blur.topAnchor.constraint(equalTo: view.topAnchor), blur.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                                     dim.leadingAnchor.constraint(equalTo: blur.leadingAnchor), dim.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
                                     dim.topAnchor.constraint(equalTo: blur.topAnchor), dim.bottomAnchor.constraint(equalTo: blur.bottomAnchor)])
        let title = UILabel(); title.attributedText = {
            let t = NSMutableAttributedString(string: "ZOKER POOL", attributes: [.font: UIFont.systemFont(ofSize: 24, weight: .heavy), .foregroundColor: UIColor.white, .kern: 2])
            t.append(NSAttributedString(string: "  TRAINER", attributes: [.font: UIFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: Self.gold, .kern: 5]))
            return t }()
        var rows: [UIView] = [title]
        if let r = resume { rows.append(makeContinue(r)) }
        let tiles = UIStackView(); tiles.axis = .horizontal; tiles.spacing = 10; tiles.distribution = .fillEqually; tiles.alignment = .fill
        for card in cards { tiles.addArrangedSubview(makeTile(card)) }
        rows.append(tiles)
        let chips = UIStackView(); chips.axis = .horizontal; chips.spacing = 8; chips.alignment = .center
        for a in footer { chips.addArrangedSubview(chip(a)) }
        let chipScroll = UIScrollView(); chipScroll.showsHorizontalScrollIndicator = false; chipScroll.accessibilityIdentifier = "LobbyChips"
        chips.translatesAutoresizingMaskIntoConstraints = false; chipScroll.addSubview(chips)
        NSLayoutConstraint.activate([chips.leadingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.leadingAnchor), chips.trailingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.trailingAnchor),
                                     chips.topAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.topAnchor), chips.bottomAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.bottomAnchor),
                                     chips.heightAnchor.constraint(equalTo: chipScroll.frameLayoutGuide.heightAnchor), chipScroll.heightAnchor.constraint(equalToConstant: 38)])
        rows.append(chipScroll)
        let main = UIStackView(arrangedSubviews: rows); main.axis = .vertical; main.spacing = 10; main.translatesAutoresizingMaskIntoConstraints = false
        // Cuộn dọc phòng khi iPhone nhỏ / chữ lớn: nội dung không bao giờ bị cắt.
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.showsVerticalScrollIndicator = false; scroll.alwaysBounceVertical = false
        view.addSubview(scroll); scroll.addSubview(main)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo: g.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: g.topAnchor), scroll.bottomAnchor.constraint(equalTo: g.bottomAnchor),
            main.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20), main.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            main.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 10), main.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -10),
            main.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)])
    }

    /// Đóng Sảnh rồi: hành động đã chọn, sau đó `onClosed` (bước tiếp của AppFlow: hướng dẫn chỉ khi hành động không
    /// mở màn khác — trước 0.45 việc này dựa vào hẹn giờ 0,4 s).
    private func choose(_ run: @escaping () -> Void) {
        let closed = onClosed
        dismiss(animated: true) { run(); closed?() }
    }
    private func makeContinue(_ r: Resume) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title = r.title; cfg.subtitle = r.subtitle
        cfg.image = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .bold))
        cfg.imagePlacement = .leading; cfg.imagePadding = 16; cfg.titleAlignment = .leading
        cfg.baseBackgroundColor = ZDesign.Color.gold; cfg.baseForegroundColor = .black; cfg.cornerStyle = .large
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in var a = a; a.font = UIFont.systemFont(ofSize: 22, weight: .heavy); return a }
        cfg.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in var a = a; a.font = UIFont.systemFont(ofSize: 13, weight: .semibold); return a }
        let b = UIButton(configuration: cfg); b.accessibilityIdentifier = "LobbyContinue"; b.contentHorizontalAlignment = .leading
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
        b.addAction(UIAction { [weak self] _ in self?.choose(r.run) }, for: .touchUpInside)
        return b
    }
    /// Ô một việc = cả ô là nút (định danh của việc đó); ô nhiều việc = tiêu đề + các nút gọn.
    private func makeTile(_ c: Card) -> UIView {
        if c.actions.count == 1, let a = c.actions.first {
            var cfg = UIButton.Configuration.filled()
            cfg.title = c.title; cfg.subtitle = c.subtitle
            cfg.image = UIImage(systemName: c.icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .bold))
            cfg.imagePlacement = .top; cfg.imagePadding = 8; cfg.titleAlignment = .center
            cfg.baseBackgroundColor = UIColor.rgb(0x171B20).withAlphaComponent(0.86); cfg.baseForegroundColor = .white
            cfg.background.cornerRadius = 18; cfg.background.strokeColor = c.color.withAlphaComponent(0.6); cfg.background.strokeWidth = 1
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { x in var x = x; x.font = UIFont.systemFont(ofSize: 17, weight: .bold); return x }
            cfg.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { x in var x = x; x.font = UIFont.systemFont(ofSize: 12, weight: .medium); x.foregroundColor = UIColor(white: 0.72, alpha: 1); return x }
            let b = UIButton(configuration: cfg); b.tintColor = c.color; b.accessibilityIdentifier = a.id
            b.addAction(UIAction { [weak self] _ in self?.choose(a.run) }, for: .touchUpInside)
            return b
        }
        let v = UIView(); v.backgroundColor = UIColor.rgb(0x171B20).withAlphaComponent(0.86); v.layer.cornerRadius = 18; v.layer.borderWidth = 1
        v.layer.borderColor = c.color.withAlphaComponent(0.6).cgColor; v.accessibilityIdentifier = "LobbyCard-" + c.title
        let icon = UIImageView(image: UIImage(systemName: c.icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold))); icon.tintColor = c.color
        let t = UILabel(); t.text = c.title; t.font = .systemFont(ofSize: 17, weight: .bold); t.textColor = .white
        let head = UIStackView(arrangedSubviews: [icon, t]); head.spacing = 8; head.alignment = .center
        let list = UIStackView(arrangedSubviews: c.actions.map { action(button: $0, color: c.color) }); list.axis = .vertical; list.spacing = 5
        let stack = UIStackView(arrangedSubviews: [head, list]); stack.axis = .vertical; stack.spacing = 8; stack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12), stack.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: v.topAnchor, constant: 10), stack.bottomAnchor.constraint(lessThanOrEqualTo: v.bottomAnchor, constant: -10)])
        return v
    }
    private func action(button a: Action, color: UIColor) -> UIButton {
        var cfg = UIButton.Configuration.filled(); cfg.title = a.title; cfg.titleLineBreakMode = .byClipping
        cfg.baseBackgroundColor = color.withAlphaComponent(0.2); cfg.baseForegroundColor = .white; cfg.cornerStyle = .large
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        let b = UIButton(configuration: cfg); b.accessibilityIdentifier = a.id
        b.configurationUpdateHandler = { ZButton.fit($0, size: 13) }   // một dòng, co đến 70 %, không cắt giữa chữ
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        b.addAction(UIAction { [weak self] _ in self?.choose(a.run) }, for: .touchUpInside)
        return b
    }
    private func chip(_ a: Action) -> UIButton {
        var cfg = UIButton.Configuration.gray(); cfg.title = a.title; cfg.image = UIImage(systemName: a.icon); cfg.imagePadding = 6
        cfg.baseForegroundColor = UIColor(white: 0.9, alpha: 1); cfg.cornerStyle = .capsule
        cfg.background.backgroundColor = UIColor(white: 1, alpha: 0.1)
        let b = UIButton(configuration: cfg); b.accessibilityIdentifier = a.id
        b.addAction(UIAction { [weak self] _ in self?.choose(a.run) }, for: .touchUpInside)
        return b
    }
}
