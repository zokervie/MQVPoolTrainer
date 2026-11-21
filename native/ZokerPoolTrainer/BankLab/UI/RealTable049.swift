import UIKit

/// 0.49b X7 — "Ra bàn thật": a card that says where to put the balls on a real table, in diamonds (BLDrillDiamonds, 9 ft table),
/// what to do, and takes the number made out of 10 (stored in PlayerStore.realTable, shown on the Tiến bộ screen next to the app's own).
final class RealTableCardController: UIViewController {
    let drill: Drill
    private var made = 5
    private let value = UILabel()
    init(drill: Drill) { self.drill = drill; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// "2,3" in Vietnamese, "2.3" in English.
    static func diamonds(_ v: Double) -> String {
        let t = String(format: "%.1f", v)
        return L10n.code == "vi" ? t.replacingOccurrences(of: ".", with: ",") : t
    }
    /// One line per ball: "Bi cái: nút dài 2,3 · nút ngắn 1,1".
    static func lines(for drill: Drill) -> [String] {
        drill.balls.map { b in
            var along = 0.0, across = 0.0
            BLDrillDiamonds(b.x, b.y, &along, &across)
            let name = b.id == 0 ? L10n.tr("Bi cái") : (b.id == 1 ? L10n.tr("Bi 1") : L10n.tr("Bi") + " \(b.id)")
            return name + ": " + String(format: L10n.tr("nút dài %@ · nút ngắn %@"), diamonds(along), diamonds(across))
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad(); title = L10n.tr("Ra bàn thật"); view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        view.accessibilityIdentifier = "RealTableCard"
        func label(_ t: String, _ size: CGFloat, _ color: UIColor, _ weight: UIFont.Weight = .regular) -> UILabel {
            let l = UILabel(); l.text = t; l.textColor = color; l.font = .systemFont(ofSize: size, weight: weight); l.numberOfLines = 0; return l
        }
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(scroll); scroll.addSubview(stack)
        stack.addArrangedSubview(label(drill.title, 22, MenuSkin.gold, .bold))
        stack.addArrangedSubview(label("Xếp bi theo nút (bàn 9 ft)", 16, MenuSkin.gold, .bold))
        for line in Self.lines(for: drill) { stack.addArrangedSubview(label(line, 17, .white, .semibold)) }
        stack.addArrangedSubview(label("Bàn 7–8 ft: đo theo nút, không theo cm.", 12, UIColor(white: 0.65, alpha: 1)))
        stack.addArrangedSubview(label("Mục tiêu: " + drill.goalText, 15, .white))
        if let at = Chapters.locate(drill.id), let c = Chapters.chapter(at.chapter), !c.tip.isEmpty { stack.addArrangedSubview(label("Mẹo: " + c.tip, 15, .white, .semibold)) }
        stack.addArrangedSubview(label("Đánh 10 cú, ghi số cú đạt", 16, MenuSkin.gold, .bold))
        func step(_ title: String, _ delta: Int, _ id: String) -> UIButton {
            var cfg = UIButton.Configuration.tinted(); cfg.title = title
            let b = UIButton(configuration: cfg); b.accessibilityIdentifier = id
            b.addAction(UIAction { [weak self] _ in guard let self = self else { return }; self.made = max(0, min(10, self.made + delta)); self.value.text = "\(self.made)/10" }, for: .touchUpInside)
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true; b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            return b
        }
        value.text = "\(made)/10"; value.font = .monospacedDigitSystemFont(ofSize: 28, weight: .bold); value.textColor = .white; value.textAlignment = .center
        value.accessibilityIdentifier = "RealTableValue"
        let row = UIStackView(arrangedSubviews: [step("−", -1, "RealTableMinus"), value, step("+", 1, "RealTablePlus")]); row.spacing = 12; row.distribution = .fill; row.alignment = .center
        value.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(row)
        var cfg = UIButton.Configuration.filled(); cfg.title = L10n.tr("Lưu"); cfg.baseBackgroundColor = MenuSkin.gold; cfg.baseForegroundColor = .black
        let save = UIButton(configuration: cfg); save.accessibilityIdentifier = "RealTableSave"
        save.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            PlayerStore.shared.recordRealTable(drill: self.drill.id, made: self.made)
            self.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)
        stack.addArrangedSubview(save)
        let past = PlayerStore.shared.realTable(drill.id).suffix(10).map { "\($0.made)" }.joined(separator: " · ")
        if !past.isEmpty { stack.addArrangedSubview(label(L10n.tr("Các lần trước") + ": " + past, 13, UIColor(white: 0.7, alpha: 1))) }
        NSLayoutConstraint.activate([scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20), scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12), scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)])
    }
}
