import UIKit

/// 0.58 T2/T3 — "Thành tích luyện tập": per chapter its medal (= the title), percent, best and the last attempts; tap a chapter for the details,
/// and the medal turns over to the numbers. Reached from the chapter list ("Thành tích"). Local only.
final class AchievementsController: UITableViewController {
    private let chapters = Chapters.all.filter { Mastery.hasLadders($0) }
    override func viewDidLoad() {
        super.viewDidLoad(); title = L10n.tr("Thành tích luyện tập"); tableView.accessibilityIdentifier = "Achievements"
        tableView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1); tableView.rowHeight = 96
        addPushedClose()
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(1, chapters.count) }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); cell.backgroundColor = UIColor(white: 0.14, alpha: 1)
        cell.textLabel?.textColor = .white; cell.detailTextLabel?.textColor = UIColor(white: 0.78, alpha: 1); cell.detailTextLabel?.numberOfLines = 0
        guard indexPath.row < chapters.count else { cell.textLabel?.text = L10n.tr("Chưa có thành tích. Chơi một vòng ở Bài tập."); return cell }
        let c = chapters[indexPath.row], pct = Mastery.percent(c), idx = Mastery.titleIndex(pct)
        cell.accessibilityIdentifier = "Achievement-\(c.number)"
        cell.imageView?.image = MedalArt.image(tier: MedalTier.forTitle(idx), size: 120, ribbon: Mastery.cleanSeal(c))
        cell.imageView?.contentMode = .scaleAspectFit
        cell.textLabel?.text = L10n.tr("Chương") + " \(c.number) · " + c.title
        cell.detailTextLabel?.text = L10n.tr(Mastery.titles[idx]) + " · \(pct) %"
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < chapters.count else { return }
        navigationController?.pushViewController(AchievementDetailController(chapter: chapters[indexPath.row]), animated: true)
    }
}

final class AchievementDetailController: UIViewController {
    private let chapter: Chapter
    private var medal: MedalView?, back = UILabel(), flipped = false
    init(chapter: Chapter) { self.chapter = chapter; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    /// Numbers of the chapter's rings: best stars, undo used, rescue, longest run, seconds, date of the best attempt.
    static func lines(_ c: Chapter) -> [String] {
        let s = PlayerStore.shared, book = s.data.achievements
        var out = [String(format: L10n.tr("Lùi cú đã dùng: %d"), s.undoUsed(c.key)),
                   s.rescueUsed(c.key) > 0 ? L10n.tr("Đã dùng thanh lực trợ giúp") : L10n.tr("Chưa dùng thanh lực trợ giúp")]
        for id in c.drills where Mastery.tier(id) > 0 {
            guard let best = book.best(id) else { continue }
            let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .none
            out.append(Drill.starText(best.stars) + String(format: " · " + L10n.tr("chuỗi trúng %d") + " · %d s · ", best.longestRun, Int(best.seconds)) + df.string(from: Date(timeIntervalSince1970: best.date)) + " · " + id)
        }
        return out
    }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        title = L10n.tr("Chương") + " \(chapter.number)"; addPushedClose()
        let pct = Mastery.percent(chapter), idx = Mastery.titleIndex(pct)
        let m = MedalView(tier: MedalTier.forTitle(idx), ribbon: Mastery.cleanSeal(chapter), size: 240); medal = m
        m.isUserInteractionEnabled = true; m.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(flip)))
        back.numberOfLines = 0; back.textColor = .white; back.font = .systemFont(ofSize: 14); back.isHidden = true; back.accessibilityIdentifier = "MedalBack"
        back.text = Self.lines(chapter).joined(separator: "\n")
        let head = UILabel(); head.textColor = ZDesign.Color.gold; head.font = .systemFont(ofSize: 22, weight: .heavy); head.textAlignment = .center
        head.text = L10n.tr(Mastery.titles[idx]) + " · \(pct) %"
        let hint = UILabel(); hint.textColor = UIColor(white: 0.7, alpha: 1); hint.font = .systemFont(ofSize: 13); hint.text = L10n.tr("Chạm huy chương để lật xem số liệu"); hint.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [m, head, hint, back]); stack.axis = .vertical; stack.alignment = .center; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(stack)
        m.widthAnchor.constraint(equalToConstant: 240).isActive = true; m.heightAnchor.constraint(equalToConstant: 240).isActive = true
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12), stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24)])
    }
    @objc private func flip() {
        flipped.toggle()
        let duration = UIAccessibility.isReduceMotionEnabled ? 0 : 0.35
        UIView.transition(with: view, duration: duration, options: .transitionFlipFromRight) { self.medal?.isHidden = self.flipped; self.back.isHidden = !self.flipped }
    }
}

extension TrainingController {
    /// T3: end of a chapter — its medal, then the hint for the next chapter.
    func presentChapterMedal(_ c: Chapter?) {
        guard let c = c, Mastery.hasLadders(c) else { return }
        let pct = Mastery.percent(c), idx = Mastery.titleIndex(pct)
        let vc = UIViewController(); vc.view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        let medal = MedalView(tier: MedalTier.forTitle(idx), ribbon: Mastery.cleanSeal(c), size: 220)
        let head = UILabel(); head.textColor = ZDesign.Color.gold; head.font = .systemFont(ofSize: 24, weight: .heavy); head.numberOfLines = 0; head.textAlignment = .center
        head.text = L10n.tr(Mastery.titles[idx]) + " · \(pct) %"
        let next = Chapters.all.first { $0.number == c.number + 1 }
        let sub = UILabel(); sub.textColor = .white; sub.font = .systemFont(ofSize: 15); sub.numberOfLines = 0; sub.textAlignment = .center
        sub.text = next.map { String(format: L10n.tr("Chương kế tiếp: %@"), $0.title) } ?? L10n.tr("Bạn đã đi hết các chương.")
        let ok = UIButton(type: .system); ok.setTitle(L10n.tr("Đóng"), for: .normal); ok.accessibilityIdentifier = "MedalCardClose"
        ok.addAction(UIAction { [weak vc] _ in vc?.dismiss(animated: true) }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [medal, head, sub, ok]); stack.axis = .vertical; stack.alignment = .center; stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false; vc.view.addSubview(stack)
        medal.widthAnchor.constraint(equalToConstant: 220).isActive = true; medal.heightAnchor.constraint(equalToConstant: 220).isActive = true
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor), stack.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)])
        vc.modalPresentationStyle = .formSheet; vc.view.accessibilityIdentifier = "ChapterMedalCard"
        topPresenter.present(vc, animated: true)
    }
}
