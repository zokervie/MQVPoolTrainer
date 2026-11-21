import UIKit

/// 0.49c G2 — solid wood UI. The Menu / "Đấu với máy" / chapter picker used translucent glass with a different font size on every
/// line (auto-shrink). Now: an OPAQUE wood panel (dark walnut, raised border, soft drop shadow), one wood card per entry, all the
/// same size. TITLES (screen name, level name) are Petemoss, a brush hand burnt into the wood: burnt brown, warm light edge.
/// CONTENT stays system sans. Three fixed sizes — title 28, main line 17, sub line 13 — no auto-shrink; long lines wrap to two.
/// Petemoss: SIL Open Font License 1.1, © 2008–2021 The Petemoss Project Authors (BankLab/Fonts/OFL.txt, shown in Pháp lý).
enum Wood {
    static let titleSize: CGFloat = 28, mainSize: CGFloat = 17, subSize: CGFloat = 13
    static let burnt = UIColor(red: 0.29, green: 0.13, blue: 0.04, alpha: 1)        // burnt brown on the light plank
    static let edgeGlow = UIColor(red: 1.0, green: 0.86, blue: 0.62, alpha: 0.85)   // warm light edge of the burn
    static let cardTop = UIColor(red: 0.80, green: 0.60, blue: 0.37, alpha: 1), cardBottom = UIColor(red: 0.69, green: 0.49, blue: 0.28, alpha: 1)
    static let ink = UIColor(red: 0.13, green: 0.07, blue: 0.03, alpha: 1), inkSoft = UIColor(red: 0.30, green: 0.18, blue: 0.09, alpha: 1)

    /// Petemoss at `size`; falls back to a bold serif only if the file is missing from the bundle (never silently another brand font).
    static func titleFont(_ size: CGFloat = titleSize) -> UIFont { UIFont(name: "Petemoss-Regular", size: size) ?? .systemFont(ofSize: size, weight: .heavy) }
    static var fontAvailable: Bool { UIFont(name: "Petemoss-Regular", size: 12) != nil }
    /// A title label: burnt brown, a 1 pt warm light edge below (the "burnt into wood" look).
    static func titleLabel(_ text: String, size: CGFloat = titleSize) -> UILabel {
        let l = UILabel(); l.text = text; l.font = titleFont(size); l.textColor = burnt; l.numberOfLines = 0
        l.layer.shadowColor = edgeGlow.cgColor; l.layer.shadowOpacity = 1; l.layer.shadowRadius = 0; l.layer.shadowOffset = CGSize(width: 0, height: 1)
        return l
    }
    static func plain(_ text: String, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let l = UILabel(); l.text = text; l.numberOfLines = 0   // wraps, never shrinks
        l.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: size, weight: weight)); l.adjustsFontForContentSizeCategory = true
        l.textColor = color; return l
    }
    /// The solid panel look on `view`: walnut pattern, raised border, drop shadow. Opaque on purpose.
    static func panel(_ view: UIView, radius: CGFloat = 18) {
        view.backgroundColor = MenuSkin.frameWood
        view.layer.cornerRadius = radius; view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 3; view.layer.borderColor = UIColor(red: 0.43, green: 0.27, blue: 0.13, alpha: 1).cgColor
        view.layer.shadowColor = UIColor.black.cgColor; view.layer.shadowOpacity = 0.55; view.layer.shadowRadius = 16; view.layer.shadowOffset = CGSize(width: 0, height: 8)
    }
}

/// One wood card: tan plank with a fine grain, a raised light top edge and a dark lower edge; identical height for every entry.
final class WoodCard: UIControl {
    private let gradient = CAGradientLayer()
    init(title: String, sub: String?, titleIsBrush: Bool = false) {
        super.init(frame: .zero)
        layer.cornerRadius = 12; layer.cornerCurve = .continuous; layer.masksToBounds = true
        gradient.colors = [Wood.cardTop.cgColor, Wood.cardBottom.cgColor]; layer.insertSublayer(gradient, at: 0)
        layer.borderWidth = 1; layer.borderColor = UIColor(red: 0.36, green: 0.21, blue: 0.09, alpha: 0.9).cgColor
        let main = titleIsBrush ? Wood.titleLabel(title, size: 24) : Wood.plain(title, size: Wood.mainSize, weight: .semibold, color: Wood.ink)
        var rows: [UIView] = [main]
        if let sub = sub, !sub.isEmpty { rows.append(Wood.plain(sub, size: Wood.subSize, weight: .regular, color: Wood.inkSoft)) }
        let stack = UIStackView(arrangedSubviews: rows); stack.axis = .vertical; stack.spacing = 3; stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
                                     stack.topAnchor.constraint(equalTo: topAnchor, constant: 10), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
                                     heightAnchor.constraint(greaterThanOrEqualToConstant: 56)])
        isAccessibilityElement = true; accessibilityLabel = [title, sub].compactMap { $0 }.joined(separator: ". "); accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); gradient.frame = bounds }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.75 : 1 } }
}

/// A modal wood panel with a Petemoss title, an optional message and a list of equal wood cards (+ a close card).
final class WoodPickerController: UIViewController {
    struct Item { let title: String; let sub: String?; let run: () -> Void }
    private let heading: String, message: String?, items: [Item]
    init(title: String, message: String? = nil, items: [Item]) {
        heading = title; self.message = message; self.items = items; super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen; modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6); view.accessibilityIdentifier = "WoodPicker"
        let panel = UIView(); Wood.panel(panel); panel.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(panel)
        // light plank under the title so the burnt letters read
        let plank = UIView(); plank.backgroundColor = Wood.cardTop; plank.layer.cornerRadius = 10; plank.layer.cornerCurve = .continuous
        let head = Wood.titleLabel(heading); head.accessibilityIdentifier = "WoodPickerTitle"; head.textAlignment = .center
        plank.addSubview(head); head.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([head.leadingAnchor.constraint(equalTo: plank.leadingAnchor, constant: 12), head.trailingAnchor.constraint(equalTo: plank.trailingAnchor, constant: -12),
                                     head.topAnchor.constraint(equalTo: plank.topAnchor, constant: 6), head.bottomAnchor.constraint(equalTo: plank.bottomAnchor, constant: -6)])
        let list = UIStackView(); list.axis = .vertical; list.spacing = 10
        if let m = message, !m.isEmpty { list.addArrangedSubview(Wood.plain(m, size: Wood.subSize, weight: .regular, color: UIColor(white: 0.95, alpha: 1))) }
        var cards: [WoodCard] = []
        for (i, item) in items.enumerated() {
            let card = WoodCard(title: item.title, sub: item.sub); card.accessibilityIdentifier = "WoodItem-\(i)"
            cards.append(card)
            card.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) { item.run() } }, for: .touchUpInside)
            list.addArrangedSubview(card)
            if cards.count > 1 { card.heightAnchor.constraint(equalTo: cards[0].heightAnchor).isActive = true }   // every card the same size (after it is in the stack)
        }
        let close = WoodCard(title: L10n.tr("Đóng"), sub: nil); close.accessibilityIdentifier = "WoodClose"
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside); list.addArrangedSubview(close)
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; list.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(list); plank.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(plank); panel.addSubview(scroll)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor), panel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panel.widthAnchor.constraint(lessThanOrEqualToConstant: 560), panel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            panel.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
            panel.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, constant: -20),
            plank.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16), plank.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16), plank.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: plank.bottomAnchor, constant: 12), scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16), scroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
            list.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), list.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            list.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), list.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            list.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
        let natural = scroll.heightAnchor.constraint(equalTo: list.heightAnchor); natural.priority = .defaultHigh; natural.isActive = true
    }
}

/// Pháp lý · giấy phép: credits and licences of third-party material shipped in the app.
final class LegalController: UITableViewController {
    struct Entry { let title: String; let detail: String; let licenseFile: String? }
    static let entries: [Entry] = [
        Entry(title: "Petemoss (phông chữ tiêu đề)", detail: "© 2008–2021 The Petemoss Project Authors · SIL Open Font License 1.1", licenseFile: "OFL")]
    override func viewDidLoad() {
        super.viewDidLoad(); title = L10n.tr("Pháp lý · giấy phép")
        tableView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1); tableView.accessibilityIdentifier = "Legal"
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 70
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.tr("Xong"), style: .done, target: self, action: #selector(close))
    }
    @objc private func close() { dismiss(animated: true) }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Self.entries.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let e = Self.entries[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); cell.backgroundColor = UIColor(white: 0.14, alpha: 1)
        cell.textLabel?.text = e.title; cell.textLabel?.textColor = .white; cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = e.detail; cell.detailTextLabel?.textColor = UIColor(white: 0.75, alpha: 1); cell.detailTextLabel?.numberOfLines = 0
        cell.accessoryType = e.licenseFile != nil ? .disclosureIndicator : .none; cell.accessibilityIdentifier = "LegalEntry-\(indexPath.row)"
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let file = Self.entries[indexPath.row].licenseFile else { return }
        let text = Bundle.main.url(forResource: file, withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "OFL.txt"
        let page = UIViewController(); page.view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1); page.title = "OFL.txt"
        let tv = UITextView(); tv.isEditable = false; tv.text = text; tv.textColor = UIColor(white: 0.88, alpha: 1); tv.backgroundColor = .clear
        tv.font = .monospacedSystemFont(ofSize: 12, weight: .regular); tv.accessibilityIdentifier = "LegalLicenseText"; tv.frame = page.view.bounds
        tv.autoresizingMask = [.flexibleWidth, .flexibleHeight]; page.view.addSubview(tv)
        navigationController?.pushViewController(page, animated: true)
    }
}
