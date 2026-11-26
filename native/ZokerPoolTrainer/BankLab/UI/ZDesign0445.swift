import UIKit

/// 0.45 M3 — ZDesign: one place for the app's look. Tokens (colour, type, radius, spacing, motion) and the shared
/// components that replace every black box: ZPill (frosted glass), ZButton (one line, shrinks to 70 %, never breaks
/// inside a word), ZToast (status line on a pill), ZSheet (sheet presentation defaults). 0.46 redraws screens with it.
enum ZDesign {
    enum Color {
        static let background = UIColor(red: 0.020, green: 0.031, blue: 0.059, alpha: 1)
        static let textPrimary = UIColor.white
        static let textSecondary = UIColor(white: 0.78, alpha: 1)
        static let gold = UIColor(red: 0xEA / 255.0, green: 0xC5 / 255.0, blue: 0x83 / 255.0, alpha: 1)   // = LobbyController.gold
        static let goldRim = gold.withAlphaComponent(0.75)
        static let danger = UIColor.systemRed, success = UIColor.systemGreen
    }
    enum Radius { static let pill: CGFloat = 18, card: CGFloat = 14, button: CGFloat = 10 }
    enum Space { static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24 }
    enum Motion { static let quick = 0.15, standard = 0.25, slow = 0.45 }
    /// Dynamic Type, never below 13 pt on iPhone.
    static func font(_ style: UIFont.TextStyle, weight: UIFont.Weight = .regular, minimum: CGFloat = 13) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style).pointSize
        return UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: max(minimum, base), weight: weight))
    }
}

/// Frosted glass with a fine gold rim (was GlassPill in 0.44.1; GlassPill stays as an alias for its call sites).
enum ZPill {
    static func apply(to view: UIView, cornerRadius: CGFloat = ZDesign.Radius.pill) { GlassPill.apply(to: view, cornerRadius: cornerRadius) }
    static func styleCaption(_ label: UILabel, size: CGFloat) { GlassPill.styleCaption(label, size: size) }
}

/// One-line button that shrinks its title to fit (≥ 70 %), never wraps or clips inside a word.
enum ZButton {
    static func make(_ title: String, symbol: String? = nil, filled: Bool = false, size: CGFloat = 13, action: @escaping () -> Void) -> UIButton {
        var c = filled ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        c.title = title; c.titleLineBreakMode = .byClipping
        if let symbol = symbol { c.image = UIImage(systemName: symbol); c.imagePlacement = .top; c.imagePadding = 3 }
        c.baseForegroundColor = filled ? .black : ZDesign.Color.textPrimary
        c.baseBackgroundColor = ZDesign.Color.gold
        c.background.cornerRadius = ZDesign.Radius.button
        if !filled { c.background.backgroundColor = UIColor(white: 0.03, alpha: 0.42) }
        c.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        let b = UIButton(configuration: c, primaryAction: UIAction { _ in action() })
        b.configurationUpdateHandler = { button in fit(button, size: size) }
        return b
    }
    /// The shrink rule (also used by the 0.44.1 Coach toggles).
    static func fit(_ button: UIButton, size: CGFloat) {
        guard var c = button.configuration, let title = c.title, button.bounds.width > 0 else { return }
        let full = (title as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: .semibold)]).width
        let scaled = size * max(0.7, min(1, (button.bounds.width - 12) / max(1, full)))
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in var a = a; a.font = .systemFont(ofSize: scaled, weight: .semibold); return a }
        button.configuration = c
    }
}

/// Status line on a pill (replaces the black toast).
enum ZToast {
    static func style(_ label: UILabel) {
        label.backgroundColor = .clear; label.textColor = ZDesign.Color.textPrimary
        label.font = ZDesign.font(.footnote, weight: .semibold)
        if let host = label.superview, host !== label.window, host.accessibilityIdentifier == "ZToastPill" { ZPill.apply(to: host, cornerRadius: ZDesign.Radius.card) }
    }
}

/// Sheet presentation defaults (grabber, medium + large detents, dark).
enum ZSheet {
    static func configure(_ vc: UIViewController) {
        vc.overrideUserInterfaceStyle = .dark
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController { sheet.detents = [.medium(), .large()]; sheet.prefersGrabberVisible = true }
    }
}

// MARK: - 0.59 ZCard (result card)

/// Collects what the round-result extras used to put on a UIAlertController (message lines + extra buttons), so the same
/// code feeds the ZCard: `message` lines become the small notes, `add` becomes a text button under the main row.
final class ZCardDraft {
    struct Item { let title: String; let handler: () -> Void }
    var message: String? = ""
    var challengeAction: (() -> Void)?
    private(set) var items: [Item] = []
    func add(_ title: String, _ handler: @escaping () -> Void) { items.append(Item(title: title, handler: handler)) }
    var noteLines: [String] { (message ?? "").split(separator: "\n").map(String.init).filter { !$0.isEmpty } }
}

/// 0.59 (đợt 1): the result of a 5-shot round — big stars, three numbers, one hint line, then Tập lại / Bài tiếp / Thách bạn.
/// Replaces the system alert "Qua bài · ★★★☆☆". Extra choices (Xem chi tiết, Bài hôm nay tiếp theo, Quay lại thế bí) stay as text buttons.
final class ZCardController: UIViewController {
    struct Model {
        var cleared: Bool, stars: Int
        var numbers: [(value: String, caption: String)]
        var hint: String
        var notes: [String]
        var retry: () -> Void
        var next: (() -> Void)?
        var challenge: (() -> Void)?
        var extras: [ZCardDraft.Item]
        var close: () -> Void
    }
    private let model: Model
    private var starLabels: [UILabel] = []
    init(_ model: Model) { self.model = model; super.init(nibName: nil, bundle: nil); modalPresentationStyle = .overFullScreen; modalTransitionStyle = .crossDissolve }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0, alpha: 0.55)
        view.accessibilityIdentifier = "RoundResultCard"
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        card.layer.cornerRadius = 20; card.clipsToBounds = true
        card.layer.borderWidth = 1; card.layer.borderColor = ZDesign.Color.goldRim.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        let title = UILabel()
        title.text = L10n.tr(model.cleared ? "Qua bài" : "Chưa qua")
        title.accessibilityLabel = L10n.tr(model.cleared ? "Qua bài · " : "Chưa qua · ") + Drill.starText(model.stars)
        title.accessibilityIdentifier = "RoundResultTitle"
        title.font = ZDesign.font(.title2, weight: .bold, minimum: 20); title.adjustsFontSizeToFitWidth = true; title.minimumScaleFactor = 0.7
        title.textColor = model.cleared ? ZDesign.Color.gold : ZDesign.Color.textPrimary; title.textAlignment = .center

        let starRow = UIStackView(); starRow.axis = .horizontal; starRow.spacing = 6; starRow.distribution = .fillEqually
        starRow.isAccessibilityElement = false
        for i in 0..<5 {
            let l = UILabel(); l.text = "★"; l.font = .systemFont(ofSize: 40, weight: .bold); l.textAlignment = .center
            l.textColor = i < model.stars ? ZDesign.Color.gold : UIColor(white: 1, alpha: 0.22)
            l.adjustsFontSizeToFitWidth = true; l.minimumScaleFactor = 0.6
            l.isAccessibilityElement = false
            starLabels.append(l); starRow.addArrangedSubview(l)
        }

        let numbers = UIStackView(); numbers.axis = .horizontal; numbers.distribution = .fillEqually; numbers.spacing = 8
        for n in model.numbers {
            let v = UILabel(); v.text = n.value; v.font = .monospacedDigitSystemFont(ofSize: 28, weight: .bold); v.textColor = .white; v.textAlignment = .center
            v.adjustsFontSizeToFitWidth = true; v.minimumScaleFactor = 0.6
            let c = UILabel(); c.text = L10n.tr(n.caption); c.font = ZDesign.font(.caption1); c.textColor = ZDesign.Color.textSecondary; c.textAlignment = .center
            c.adjustsFontSizeToFitWidth = true; c.minimumScaleFactor = 0.7
            let s = UIStackView(arrangedSubviews: [v, c]); s.axis = .vertical; s.spacing = 2
            numbers.addArrangedSubview(s)
        }

        let hint = UILabel(); hint.text = model.hint; hint.numberOfLines = 3; hint.textAlignment = .center
        hint.font = ZDesign.font(.subheadline); hint.textColor = ZDesign.Color.textPrimary; hint.accessibilityIdentifier = "RoundResultHint"

        let notes = UILabel(); notes.numberOfLines = 0; notes.textAlignment = .center
        notes.text = model.notes.joined(separator: "\n"); notes.font = ZDesign.font(.footnote); notes.textColor = ZDesign.Color.textSecondary
        notes.accessibilityIdentifier = "RoundResultNotes"; notes.isHidden = model.notes.isEmpty

        let main = UIStackView(); main.axis = .horizontal; main.spacing = 8; main.distribution = .fillEqually
        func button(_ t: String, filled: Bool, _ a: @escaping () -> Void) -> UIButton {
            let b = ZButton.make(L10n.tr(t), filled: filled, size: 15) { [weak self] in self?.dismiss(animated: true) { a() } }
            b.accessibilityIdentifier = "RoundResult-" + t; b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            return b
        }
        main.addArrangedSubview(button("Tập lại", filled: model.next == nil, model.retry))
        if let next = model.next { main.addArrangedSubview(button("Bài tiếp", filled: true, next)) }
        if let ch = model.challenge { main.addArrangedSubview(button("Thách bạn", filled: false, ch)) }

        var rows: [UIView] = [title, starRow, numbers, hint, notes, main]
        for e in model.extras {
            let b = UIButton(type: .system); b.setTitle(L10n.tr(e.title), for: .normal)
            b.titleLabel?.font = ZDesign.font(.subheadline, weight: .semibold); b.setTitleColor(ZDesign.Color.gold, for: .normal)
            b.titleLabel?.adjustsFontSizeToFitWidth = true; b.titleLabel?.minimumScaleFactor = 0.7
            b.accessibilityIdentifier = "RoundResult-" + e.title; b.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
            let h = e.handler; b.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) { h() } }, for: .touchUpInside)
            rows.append(b)
        }
        let close = UIButton(type: .system); close.setTitle(L10n.tr("Đóng"), for: .normal); close.accessibilityIdentifier = "RoundResultClose"
        close.titleLabel?.font = ZDesign.font(.subheadline); close.setTitleColor(ZDesign.Color.textSecondary, for: .normal)
        close.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) { self?.model.close() } }, for: .touchUpInside)
        rows.append(close)

        let stack = UIStackView(arrangedSubviews: rows); stack.axis = .vertical; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(18, after: hint)
        card.contentView.addSubview(stack)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: guide.centerXAnchor), card.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -20),
            card.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: 12),
            card.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 20), stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -20)
        ])
        let wide = card.widthAnchor.constraint(equalToConstant: 380); wide.priority = .defaultHigh; wide.isActive = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        // Stars light up one after another (0.09 s apart); the earned ones pop once.
        for (i, l) in starLabels.enumerated() where i < model.stars {
            l.transform = CGAffineTransform(scaleX: 0.4, y: 0.4); l.alpha = 0.2
            UIView.animate(withDuration: 0.28, delay: 0.09 * Double(i), usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: []) { l.transform = .identity; l.alpha = 1 }
        }
    }
}
