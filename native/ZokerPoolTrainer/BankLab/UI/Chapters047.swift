import UIKit

/// 0.47 M0 — Kho bài theo chương: dễ → khó, mỗi chương một mẹo dễ nhớ. Swift keeps the catalogue (drill ids in ladder
/// order, the tip, its source); what is open comes from BankLab/UI/Chapters.h (Tests/ChapterTests.cpp).
/// Difficulty stars (M3) and kinds (M2 interleaving) live here too, next to the ladder they describe.
struct Chapter {
    let number: Int            // 1…6
    let title: String
    let tip: String            // the one sentence to remember (≤ 8 words where the brief allows)
    let tipMore: String        // one extra line (chapter 3: throw correction measured on the app's physics)
    let source: String
    let drills: [String]       // stable ids, ladder order (rung 1 first)
}

enum Chapters {
    /// Kinds for BLDailyPickMixed (any distinct integers; same kind = blocked practice).
    enum Kind: Int32 { case straight = 0, speed, cut, cueBallPath, kick, bank, special }

    static let all: [Chapter] = [
        Chapter(number: 1, title: "Cú thẳng", tip: "Thẳng – dừng – theo – lùi", tipMore: "",
                source: "Bài stop / theo / lùi của Kinister và Dr. Dave Alciatore",
                drills: ["first-shot", "stop-hold", "follow-zone", "draw-zone"]),
        Chapter(number: 2, title: "Lực", tip: "Lực là quãng lăn", tipMore: "",
                source: "Thang Lực 1–30 của app",
                drills: ["speed-1", "speed-2", "speed-3"]),
        Chapter(number: 3, title: "Ngắm cắt", tip: "Nửa bi = 30°", tipMore: "Đánh chậm: cắt mỏng hơn một chút",
                source: "Ngắm theo phần bi (hình học); độ ném đo trên vật lý của app",
                drills: ["cut-30-r", "cut-45-l"]),
        Chapter(number: 4, title: "Đường bi cái", tip: "Bi đứng đi vuông 90° · bi lăn lệch 30°", tipMore: "Trô gấp 3 lần góc",
                source: "Quy tắc 90° và 30° (Dr. Dave Alciatore); hệ trisect cho trô",
                drills: []),   // bài mới (90° né bi cản → 30° tránh lỗ → trô chéo): chờ thế bi + test C++ quét
        Chapter(number: 5, title: "Băng", tip: "Gương và số nút", tipMore: "",
                source: "Gương 1 băng; Corner-5 (Walter Harris / Robert Byrne)",
                drills: ["kick1-mirror-a", "kick1-mirror-b", "kick1-blocker", "kick1-blocker-far", "kick2-double-mirror", "kick2-blocker",
                         "kick2-plus", "kick3-corner5", "kick3-blocker-mid", "kick3-blocker-high", "kick4", "bank1", "bank2", "bank3"]),
        Chapter(number: 6, title: "Kỹ thuật đặc biệt", tip: "Cơ dựng – bi bay/cong", tipMore: "",
                source: "Jump / massé (Dr. Dave Alciatore, TP 7.x)",
                drills: ["trick-combo", "trick-jump", "trick-masse", "trick-kick3-cluster", "trick-reverse-zigzag"]),
    ]

    /// M3: difficulty 1–5 per drill. GIẢ ĐỊNH (design): the brief wants it from the aim-window margin of the computer
    /// opponent's sweep (BLStarsFromMargin); until that sweep is run per drill in C++, this table orders the ladder.
    static let difficulty: [String: Int32] = [
        "first-shot": 1, "stop-hold": 2, "follow-zone": 2, "draw-zone": 3, "speed-1": 1, "speed-2": 2, "speed-3": 2,
        "cut-30-r": 2, "cut-45-l": 3, "kick1-mirror-a": 2, "kick1-mirror-b": 2, "kick1-blocker": 3, "kick1-blocker-far": 3,
        "kick2-double-mirror": 3, "kick2-blocker": 4, "kick2-plus": 4, "kick3-corner5": 4, "kick3-blocker-mid": 4,
        "kick3-blocker-high": 5, "kick4": 5, "bank1": 3, "bank2": 4, "bank3": 5, "trick-combo": 3, "trick-jump": 4,
        "trick-masse": 5, "trick-kick3-cluster": 5, "trick-reverse-zigzag": 5]
    static func kind(_ id: String) -> Kind {
        if id.hasPrefix("speed") { return .speed }
        if id.hasPrefix("cut") { return .cut }
        if id.hasPrefix("kick") { return .kick }
        if id.hasPrefix("bank") { return .bank }
        if id.hasPrefix("trick") { return .special }
        return .straight
    }
    static func index(of id: String) -> Int? { Drill.all.firstIndex { $0.id == id } }
    /// (chapter number, rung 0-based) of a drill, if it is on a ladder.
    static func locate(_ id: String) -> (chapter: Int, rung: Int)? {
        for c in all { if let r = c.drills.firstIndex(of: id) { return (c.number, r) } }
        return nil
    }
    static func chapter(_ n: Int) -> Chapter? { all.first { $0.number == n } }
    static func examKind(_ n: Int) -> String { "chapter-\(n)" }

    // MARK: unlock state (Chapters.h)
    static func examPassed(_ n: Int, _ s: PlayerStore = .shared) -> Bool {
        BLExamPassed(Int32(s.data.examBest[examKind(n)] ?? 0), Int32(BL_EXAM_SHOTS)) != 0
    }
    static func openChapters(_ s: PlayerStore = .shared) -> [Bool] {
        let counts = all.map { Int32($0.drills.count) }
        let exams = all.map { Int32(examPassed($0.number, s) ? 1 : 0) }
        let best = all.map { c in Int32(c.drills.map { s.stars($0) }.max() ?? 0) }
        var open = [Int32](repeating: 0, count: all.count)
        _ = BLChaptersOpen(Int32(all.count), counts, exams, best, &open)
        return open.map { $0 != 0 }
    }
    static func rungOpen(_ c: Chapter, _ rung: Int, _ s: PlayerStore = .shared) -> Bool {
        BLRungOpen(Int32(rung), Int32(rung > 0 ? s.stars(c.drills[rung - 1]) : 0), Int32(s.stars(c.drills[rung]))) != 0
    }
    static func examOpen(_ c: Chapter, _ s: PlayerStore = .shared) -> Bool {
        let stars = c.drills.map { Int32(s.stars($0)) }
        return BLExamOpen(stars, Int32(stars.count)) != 0
    }
    /// Drill is playable now (chapter open and rung open). Drills outside every ladder are always playable.
    static func playable(_ id: String, _ s: PlayerStore = .shared) -> Bool {
        guard FeatureFlags.chapters, let at = locate(id), let c = chapter(at.chapter) else { return true }
        return openChapters(s)[at.chapter - 1] && rungOpen(c, at.rung, s)
    }
    /// Next rung after `id` on its ladder, if open now.
    static func nextRung(after id: String, _ s: PlayerStore = .shared) -> Int? {
        guard let at = locate(id), let c = chapter(at.chapter), at.rung + 1 < c.drills.count, rungOpen(c, at.rung + 1, s) else { return nil }
        return index(of: c.drills[at.rung + 1])
    }
    /// The 10 shots of a chapter exam: spread over the ladder (a 3-drill chapter plays each about three times).
    static func examDrills(_ c: Chapter) -> [Int] {
        let idx = c.drills.compactMap { index(of: $0) }
        guard !idx.isEmpty else { return [] }
        return (0..<Int(BL_EXAM_SHOTS)).map { idx[$0 * idx.count / Int(BL_EXAM_SHOTS)] }
    }
}

// MARK: - Chapter list ("Bài tập" when the flag is on)
final class ChaptersController: UITableViewController {
    var load: ((Int) -> Void)?
    var guidedLoad: ((Int) -> Void)?
    var exam: ((Int) -> Void)?
    private var open: [Bool] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        navigationController?.navigationBar.barStyle = .black
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 70
        tableView.accessibilityIdentifier = "Chapters"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Xong", style: .done, target: self, action: #selector(close))
        let book = UIBarButtonItem(title: "Sổ mẹo", style: .plain, target: self, action: #selector(openTipBook))
        book.accessibilityIdentifier = "TipBook"; navigationItem.leftBarButtonItem = book
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        open = Chapters.openChapters()
        let cleared = Chapters.all.flatMap { $0.drills }.filter { PlayerStore.shared.stars($0) >= Int(BL_RUNG_PASS_STARS) }.count
        title = "Bài tập · \(cleared)/\(Chapters.all.flatMap { $0.drills }.count) bài đã qua"
        tableView.reloadData()
    }
    @objc private func close() { dismiss(animated: true) }
    @objc private func openTipBook() { navigationController?.pushViewController(TipBookController(), animated: true) }

    override func numberOfSections(in tableView: UITableView) -> Int { Chapters.all.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let c = Chapters.all[section]; return c.drills.isEmpty ? 1 : c.drills.count + 1
    }
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let c = Chapters.all[section], isOpen = open.indices.contains(section) && open[section]
        let title = UILabel(); title.text = "Chương \(c.number) · \(c.title)"; title.font = .systemFont(ofSize: 17, weight: .heavy)
        title.textColor = isOpen ? ZDesign.Color.gold : UIColor(white: 0.55, alpha: 1)
        let tip = UILabel(); tip.text = "Mẹo: " + c.tip; tip.font = .systemFont(ofSize: 14, weight: .semibold); tip.numberOfLines = 0
        tip.textColor = isOpen ? .white : UIColor(white: 0.5, alpha: 1)
        let done = c.drills.filter { PlayerStore.shared.stars($0) >= Int(BL_RUNG_PASS_STARS) }.count
        let state = UILabel(); state.font = .systemFont(ofSize: 12, weight: .medium); state.textColor = UIColor(white: 0.7, alpha: 1)
        state.text = !isOpen ? "Chưa mở · qua bài thi chương trước (7/10)" : (c.drills.isEmpty ? "Bài mới đang soạn" : "\(done)/\(c.drills.count) bài đã qua" + (Chapters.examPassed(c.number) ? " · đã qua thi chương" : ""))
        let stack = UIStackView(arrangedSubviews: [title, tip, state]); stack.axis = .vertical; stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true; stack.layoutMargins = UIEdgeInsets(top: 14, left: 20, bottom: 6, right: 20)
        stack.accessibilityIdentifier = "Chapter-\(c.number)"
        return stack
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = Chapters.all[indexPath.section], chapterOpen = open.indices.contains(indexPath.section) && open[indexPath.section]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = UIColor(white: 0.14, alpha: 1)
        cell.textLabel?.textColor = .white; cell.detailTextLabel?.textColor = UIColor(white: 0.78, alpha: 1)
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .semibold); cell.detailTextLabel?.font = .systemFont(ofSize: 12); cell.detailTextLabel?.numberOfLines = 2
        if c.drills.isEmpty {
            cell.textLabel?.text = "Bài mới đang soạn"; cell.detailTextLabel?.text = "Chương này không chặn chương sau"
            cell.imageView?.image = UIImage(systemName: "hammer"); cell.imageView?.tintColor = .gray; cell.selectionStyle = .none
            return cell
        }
        if indexPath.row == c.drills.count {
            let examOpen = chapterOpen && Chapters.examOpen(c), best = PlayerStore.shared.data.examBest[Chapters.examKind(c.number)]
            cell.textLabel?.text = "Thi chương · 10 cú không trợ giúp"
            cell.detailTextLabel?.text = examOpen ? "Đạt từ 7/10 để mở chương sau" + (best.map { " · tốt nhất \($0)/10" } ?? "") : "Qua mọi bài của chương để mở"
            cell.imageView?.image = UIImage(systemName: Chapters.examPassed(c.number) ? "rosette" : (examOpen ? "flag.checkered" : "lock.fill"))
            cell.imageView?.tintColor = examOpen ? ZDesign.Color.gold : .gray
            cell.accessibilityIdentifier = "ChapterExam-\(c.number)"
            cell.accessoryType = examOpen ? .disclosureIndicator : .none
            return cell
        }
        let id = c.drills[indexPath.row], rungOpen = chapterOpen && Chapters.rungOpen(c, indexPath.row)
        let drill = Chapters.index(of: id).map { Drill.all[$0] }, best = PlayerStore.shared.stars(id)
        cell.textLabel?.text = "\(indexPath.row + 1). " + (drill?.title ?? id) + "   " + Drill.starText(best)
        let level = Int(Chapters.difficulty[id] ?? 0)
        cell.detailTextLabel?.text = (FeatureFlags.progress && level > 0 ? "Độ khó " + Drill.starText(level) + " · " : "") + (rungOpen ? (drill?.note ?? "") : "Đạt 3/5 ở bài trước để mở")
        cell.imageView?.image = UIImage(systemName: best >= Int(BL_RUNG_PASS_STARS) ? "checkmark.seal.fill" : (rungOpen ? "circle" : "lock.fill"))
        cell.imageView?.tintColor = best >= Int(BL_RUNG_PASS_STARS) ? .systemGreen : (rungOpen ? ZDesign.Color.gold : .gray)
        cell.accessoryType = rungOpen ? .disclosureIndicator : .none
        cell.accessibilityIdentifier = "ChapterDrill-" + id
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let c = Chapters.all[indexPath.section]
        guard open.indices.contains(indexPath.section), open[indexPath.section], !c.drills.isEmpty else { return }
        let go = { [weak self] in
            guard let self = self else { return }
            if indexPath.row == c.drills.count {
                guard Chapters.examOpen(c) else { return }
                self.dismiss(animated: true) { self.exam?(c.number) }
                return
            }
            guard Chapters.rungOpen(c, indexPath.row), let index = Chapters.index(of: c.drills[indexPath.row]) else { return }
            let lesson = DrillLessonController(drill: Drill.all[index])
            lesson.start = { [weak self] in guard let self = self else { return }; self.dismiss(animated: true) { self.load?(index) } }
            lesson.guidedStart = { [weak self] in guard let self = self else { return }; self.dismiss(animated: true) { self.guidedLoad?(index) } }
            self.navigationController?.pushViewController(lesson, animated: true)
        }
        // First time into a chapter: its ONE tip card, then it lives in Sổ mẹo.
        if !PlayerStore.shared.data.tipsSeen.contains(c.number) {
            PlayerStore.shared.markTipSeen(c.number)
            present(TipCardController(chapter: c, done: go), animated: true)
        } else { go() }
    }
}

/// One tip card: chapter, the sentence to remember, one more line, source. No long text.
final class TipCardController: UIViewController {
    let chapter: Chapter
    let done: (() -> Void)?
    init(chapter: Chapter, done: (() -> Void)?) {
        self.chapter = chapter; self.done = done; super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen; modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55); view.accessibilityIdentifier = "TipCard"
        let card = UIView(); card.backgroundColor = UIColor.rgb(0x171B20); card.layer.cornerRadius = 22
        card.layer.borderColor = ZDesign.Color.gold.withAlphaComponent(0.7).cgColor; card.layer.borderWidth = 1
        card.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(card)
        let head = UILabel(); head.text = "Chương \(chapter.number) · \(chapter.title)"; head.font = .systemFont(ofSize: 15, weight: .bold); head.textColor = ZDesign.Color.gold
        let tip = UILabel(); tip.text = chapter.tip; tip.font = .systemFont(ofSize: 30, weight: .heavy); tip.textColor = .white
        tip.numberOfLines = 0; tip.textAlignment = .center; tip.adjustsFontSizeToFitWidth = true; tip.minimumScaleFactor = 0.6
        let more = UILabel(); more.text = chapter.tipMore; more.font = .systemFont(ofSize: 17, weight: .semibold); more.textColor = UIColor(white: 0.85, alpha: 1)
        more.isHidden = chapter.tipMore.isEmpty; more.textAlignment = .center; more.numberOfLines = 0
        let source = UILabel(); source.text = chapter.source; source.font = .systemFont(ofSize: 12); source.textColor = UIColor(white: 0.6, alpha: 1)
        source.numberOfLines = 0; source.textAlignment = .center
        var cfg = UIButton.Configuration.filled(); cfg.title = "Đã hiểu"; cfg.baseBackgroundColor = ZDesign.Color.gold; cfg.baseForegroundColor = .black; cfg.cornerStyle = .capsule
        let ok = UIButton(configuration: cfg); ok.accessibilityIdentifier = "TipCardOK"
        ok.addAction(UIAction { [weak self] _ in let d = self?.done; self?.dismiss(animated: true) { d?() } }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [head, tip, more, source, ok]); stack.axis = .vertical; stack.spacing = 12; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(stack)
        NSLayoutConstraint.activate([card.centerXAnchor.constraint(equalTo: view.centerXAnchor), card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 520), card.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20), stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            ok.heightAnchor.constraint(greaterThanOrEqualToConstant: 44), ok.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)])
    }
}

/// Sổ mẹo: every tip already shown (and the chapters still to come, locked).
final class TipBookController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Sổ mẹo"
        tableView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 60
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Chapters.all.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = Chapters.all[indexPath.row], seen = PlayerStore.shared.data.tipsSeen.contains(c.number)
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); cell.backgroundColor = UIColor(white: 0.14, alpha: 1)
        cell.textLabel?.textColor = .white; cell.detailTextLabel?.textColor = UIColor(white: 0.7, alpha: 1); cell.detailTextLabel?.numberOfLines = 0
        cell.textLabel?.text = seen ? c.tip : "Chương \(c.number) · chưa mở mẹo"
        cell.detailTextLabel?.text = seen ? "Chương \(c.number) · \(c.title)" + (c.tipMore.isEmpty ? "" : "\n" + c.tipMore) : nil
        cell.imageView?.image = UIImage(systemName: seen ? "lightbulb.fill" : "lock.fill"); cell.imageView?.tintColor = seen ? ZDesign.Color.gold : .gray
        cell.selectionStyle = seen ? .default : .none
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let c = Chapters.all[indexPath.row]
        guard PlayerStore.shared.data.tipsSeen.contains(c.number) else { return }
        present(TipCardController(chapter: c, done: nil), animated: true)
    }
}
