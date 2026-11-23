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
    var key: String = ""       // 0.49b: BLDrillChapterKey (exam progress is saved under it); "" = ≤ 0.48 list
    var legacy: [String] = []  // 0.54: ≤ 0.53 drills of a ring-ladder chapter, listed under "Bài cũ", never counted in the %
    var blocking: Bool = true  // false: the chapters after it open without passing its exam (0.49b D2: Bank)
}

enum Chapters {
    /// Kinds for BLDailyPickMixed (any distinct integers; same kind = blocked practice).
    enum Kind: Int32 { case straight = 0, speed, cut, cueBallPath, kick, bank, special }

    static let all: [Chapter] = FeatureFlags.drillCatalog ? DrillCatalog.chapters() : legacyAll
    static let legacyAll: [Chapter] = [
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
    /// 0.49b X1: stars 1–5 of a drill — MEASURED (BLDrillStars) with the catalogue, the table below otherwise.
    static func stars(_ id: String) -> Int32 {
        if FeatureFlags.drillCatalog, let s = DrillCatalog.spec(id) { var spec = s; return BLDrillStars(&spec) }
        return difficulty[id] ?? 0
    }
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
        for c in all { if let r = c.legacy.firstIndex(of: id) { return (c.number, c.drills.count + r) } }   // 0.54 "Bài cũ": still a chapter drill (5-shot lessons), no ladder rung
        return nil
    }
    static func chapter(_ n: Int) -> Chapter? { all.first { $0.number == n } }
    /// Exam progress key: the catalogue's stable chapter key (0.49b), "chapter-<n>" for the ≤ 0.48 list.
    static func examKind(_ n: Int) -> String { chapter(n).map { $0.key.isEmpty ? "chapter-\(n)" : $0.key } ?? "chapter-\(n)" }

    // MARK: unlock state (Chapters.h)
    static func examPassed(_ n: Int, _ s: PlayerStore = .shared) -> Bool {
        BLExamPassed(Int32(s.data.examBest[examKind(n)] ?? 0), Int32(BL_EXAM_SHOTS)) != 0
    }
    static func openChapters(_ s: PlayerStore = .shared) -> [Bool] {
        let counts = all.map { Int32($0.blocking ? $0.drills.count : 0) }
        let exams = all.map { Int32(examPassed($0.number, s) ? 1 : 0) }
        let best = all.map { c in Int32(c.drills.map { s.stars($0) }.max() ?? 0) }
        var open = [Int32](repeating: 0, count: all.count)
        _ = BLChaptersOpen(Int32(all.count), counts, exams, best, &open)
        return open.map { $0 != 0 }
    }
    static func rungOpen(_ c: Chapter, _ rung: Int, _ s: PlayerStore = .shared) -> Bool {
        if Mastery.tier(c.drills[rung]) > 0 { return Mastery.ringOpen(c.drills[rung], s) }   // 0.54: a ring opens on the stars of the ring before it (BLTierOpen)
        return BLRungOpen(Int32(rung), Int32(rung > 0 ? s.stars(c.drills[rung - 1]) : 0), Int32(s.stars(c.drills[rung]))) != 0
    }
    static func examOpen(_ c: Chapter, _ s: PlayerStore = .shared) -> Bool {
        if Mastery.hasLadders(c) { return Mastery.ladders(c).allSatisfy { ($0.rings.first.map { s.ladderStars($0) } ?? 0) >= 1 } }   // 0.54 GIẢ ĐỊNH: every ladder's big ring passed
        let stars = c.drills.map { Int32(s.stars($0)) }
        return BLExamOpen(stars, Int32(stars.count)) != 0
    }
    /// Drill is playable now (chapter open and rung open). Drills outside every ladder are always playable.
    static func playable(_ id: String, _ s: PlayerStore = .shared) -> Bool {
        guard FeatureFlags.chapters, let at = locate(id), let c = chapter(at.chapter), at.rung < c.drills.count else { return true }
        return openChapters(s)[at.chapter - 1] && rungOpen(c, at.rung, s)
    }
    /// Next rung after `id` on its ladder, if open now.
    static func nextRung(after id: String, _ s: PlayerStore = .shared) -> Int? {
        guard let at = locate(id), let c = chapter(at.chapter), at.rung + 1 < c.drills.count, rungOpen(c, at.rung + 1, s) else { return nil }
        return index(of: c.drills[at.rung + 1])
    }
    /// The 10 shots of a chapter exam: spread over the ladder (a 3-drill chapter plays each about three times).
    static func examDrills(_ c: Chapter) -> [Int] {
        if Mastery.hasLadders(c) {   // 0.54 M1: 5 set-ups drawn from the open rings (seeded by the number of tests taken), 2 shots each = the 10-shot exam
            let pool = c.drills.enumerated().filter { Mastery.ringOpen($0.element) }.compactMap { index(of: $0.element) }
            guard !pool.isEmpty else { return [] }
            var seed = UInt64(PlayerStore.shared.data.tests.count) &* 6364136223846793005 &+ 1442695040888963407, picked: [Int] = []
            var rest = pool
            while picked.count < 5 { if rest.isEmpty { rest = pool }; seed = seed &* 6364136223846793005 &+ 1442695040888963407; picked.append(rest.remove(at: Int((seed >> 33) % UInt64(rest.count)))) }
            return picked.flatMap { [$0, $0] }
        }
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
        tableView.backgroundColor = MenuSkin.frameWood   // 0.49c G2: wood behind, tan wood cards
        navigationController?.navigationBar.barStyle = .black
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 70
        tableView.accessibilityIdentifier = "Chapters"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Xong", style: .done, target: self, action: #selector(close))
        let book = UIBarButtonItem(title: "Sổ mẹo", style: .plain, target: self, action: #selector(openTipBook))
        book.accessibilityIdentifier = "TipBook"
        let achievements = UIBarButtonItem(title: L10n.tr("Thành tích"), style: .plain, target: self, action: #selector(openAchievements)); achievements.accessibilityIdentifier = "AchievementsOpen"   // 0.58 T2
        navigationItem.leftBarButtonItems = [book, achievements]
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        open = Chapters.openChapters()
        let cleared = Chapters.all.flatMap { $0.drills }.filter { PlayerStore.shared.stars($0) >= Int(BL_RUNG_PASS_STARS) }.count
        title = "Bài tập · \(cleared)/\(Chapters.all.flatMap { $0.drills }.count) bài đã qua"
        tableView.reloadData()
    }
    @objc private func close() { dismiss(animated: true) }
    @objc private func openAchievements() { navigationController?.pushViewController(AchievementsController(style: .plain), animated: true) }
    @objc private func openTipBook() { navigationController?.pushViewController(TipBookController(), animated: true) }

    // 0.54: a chapter's rows. Ring-ladder chapters show one card per ladder (3 rings with their best stars), the exam, "Bài cũ", the chapter settings.
    private enum Row { case ladder(Mastery.Ladder), drill(Int), legacyTitle, legacy(String), exam, settings }
    private func rows(_ c: Chapter) -> [Row] {
        if c.drills.isEmpty { return [.settings] }
        var r: [Row] = Mastery.hasLadders(c) ? Mastery.ladders(c).map { .ladder($0) } : c.drills.indices.map { .drill($0) }
        r.append(.exam)
        if !c.legacy.isEmpty { r.append(.legacyTitle); r += c.legacy.map { .legacy($0) } }
        r.append(.settings); return r
    }
    override func numberOfSections(in tableView: UITableView) -> Int { Chapters.all.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows(Chapters.all[section]).count }
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let c = Chapters.all[section], isOpen = open.indices.contains(section) && open[section]
        let title = UILabel(); title.text = "Chương \(c.number) · \(L10n.tr(c.title))"; title.font = Wood.titleFont(24)   // 0.49c G2: chapter names in Petemoss
        title.textColor = isOpen ? ZDesign.Color.gold : UIColor(white: 0.55, alpha: 1)
        let tip = UILabel(); tip.text = "Mẹo: " + c.tip; tip.font = .systemFont(ofSize: 14, weight: .semibold); tip.numberOfLines = 0
        tip.textColor = isOpen ? .white : UIColor(white: 0.5, alpha: 1)
        let done = c.drills.filter { PlayerStore.shared.stars($0) >= Int(BL_RUNG_PASS_STARS) }.count
        let state = UILabel(); state.font = .systemFont(ofSize: 12, weight: .medium); state.textColor = UIColor(white: 0.7, alpha: 1); state.numberOfLines = 0
        state.text = !isOpen ? "Chưa mở · qua bài thi chương trước (7/10)" : (c.drills.isEmpty ? "Bài mới đang soạn" : "\(done)/\(c.drills.count) bài đã qua" + (Chapters.examPassed(c.number) ? " · đã qua thi chương" : ""))
        var views: [UIView] = [title, tip, state]
        if isOpen, !c.drills.isEmpty {
            let left = Mastery.undoLeft(c)
            let undo = UILabel(); undo.font = .systemFont(ofSize: 12, weight: .medium); undo.textColor = UIColor(white: 0.7, alpha: 1)
            undo.text = L10n.tr("Lùi cú còn") + " " + (left < 0 ? "∞" : "\(left)"); undo.accessibilityIdentifier = "ChapterUndo-\(c.number)"
            views.append(undo)
            if Mastery.hasLadders(c) {
                let pct = Mastery.percent(c), idx = Mastery.titleIndex(pct)
                let intro = UILabel(); intro.text = L10n.tr(Mastery.intro); intro.font = .italicSystemFont(ofSize: 12); intro.numberOfLines = 0; intro.textColor = UIColor(white: 0.85, alpha: 1)
                let head = UILabel(); head.font = .systemFont(ofSize: 15, weight: .bold); head.textColor = ZDesign.Color.gold; head.numberOfLines = 0
                var line = L10n.tr(Mastery.titles[idx]) + " · \(pct) % · “" + L10n.tr(Mastery.nickname) + "”"
                if Mastery.cleanSeal(c) { line += " · ✓ " + L10n.tr("Tay sạch") }
                if let next = Mastery.nextTitle(pct) { line += "\n" + String(format: L10n.tr("còn %d %% nữa lên %@"), next.remaining, L10n.tr(next.name)) }
                head.text = line; head.accessibilityIdentifier = "ChapterTitle-\(c.number)"
                views.insert(head, at: 1); views.insert(intro, at: 2)
            }
        }
        let stack = UIStackView(arrangedSubviews: views); stack.axis = .vertical; stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true; stack.layoutMargins = UIEdgeInsets(top: 14, left: 20, bottom: 6, right: 20)
        stack.accessibilityIdentifier = "Chapter-\(c.number)"
        return stack
    }
    private func ringStars(_ id: String) -> String { Drill.starText(PlayerStore.shared.ladderStars(id)).replacingOccurrences(of: "☆", with: "☆") }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = Chapters.all[indexPath.section], chapterOpen = open.indices.contains(indexPath.section) && open[indexPath.section]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = Wood.cardTop
        cell.textLabel?.textColor = Wood.ink; cell.detailTextLabel?.textColor = Wood.inkSoft
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .semibold); cell.detailTextLabel?.font = .systemFont(ofSize: 12); cell.detailTextLabel?.numberOfLines = 2
        switch rows(c)[indexPath.row] {
        case .settings:
            cell.textLabel?.text = c.drills.isEmpty ? "Bài mới đang soạn" : L10n.tr("Cài đặt chương")
            cell.detailTextLabel?.text = c.drills.isEmpty ? "Chương này không chặn chương sau" : L10n.tr("Chơi lại chương từ đầu")
            cell.imageView?.image = UIImage(systemName: c.drills.isEmpty ? "hammer":"gearshape"); cell.imageView?.tintColor = .gray
            cell.accessibilityIdentifier = "ChapterSettings-\(c.number)"; cell.selectionStyle = c.drills.isEmpty ? .none:.default
        case .legacyTitle:
            cell.textLabel?.text = L10n.tr("Bài cũ"); cell.detailTextLabel?.text = L10n.tr("Không tính vào % hoàn thiện"); cell.selectionStyle = .none
            cell.imageView?.image = UIImage(systemName: "clock.arrow.circlepath"); cell.imageView?.tintColor = .gray
        case .legacy(let id):
            let drill = Chapters.index(of: id).map { Drill.all[$0] }
            cell.textLabel?.text = (drill?.title ?? id) + "   " + Drill.starText(PlayerStore.shared.stars(id)); cell.detailTextLabel?.text = drill?.note ?? ""
            cell.imageView?.image = UIImage(systemName: "circle"); cell.imageView?.tintColor = ZDesign.Color.gold; cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "ChapterDrill-" + id
        case .ladder(let l):
            let rings = l.rings.map { id -> String in
                let t = Mastery.tier(id), open = Mastery.ringOpen(id)
                return "V\(t) " + (open ? ringStars(id) : "🔒")
            }
            cell.textLabel?.text = L10n.tr(Mastery.ladderTitles[l.name] ?? l.name)
            cell.detailTextLabel?.text = rings.joined(separator: "   ")
            let best = l.rings.map { PlayerStore.shared.ladderStars($0) }.min() ?? 0
            cell.imageView?.image = UIImage(systemName: best >= 3 ? "checkmark.seal.fill" : "target"); cell.imageView?.tintColor = best >= 3 ? .systemGreen : ZDesign.Color.gold
            cell.accessoryType = .disclosureIndicator; cell.accessibilityIdentifier = "ChapterLadder-" + l.name
        case .exam:
            let examOpen = chapterOpen && Chapters.examOpen(c), best = PlayerStore.shared.data.examBest[Chapters.examKind(c.number)]
            cell.textLabel?.text = Mastery.hasLadders(c) ? L10n.tr("Bài thi") + " · 5 " + L10n.tr("thế") : "Thi chương · 10 cú không trợ giúp"
            cell.detailTextLabel?.text = examOpen ? "Đạt từ 7/10 để mở chương sau" + (best.map { " · tốt nhất \($0)/10" } ?? "") : (Mastery.hasLadders(c) ? L10n.tr("Qua vòng to của cả 9 thang để mở") : "Qua mọi bài của chương để mở")
            cell.imageView?.image = UIImage(systemName: Chapters.examPassed(c.number) ? "rosette" : (examOpen ? "flag.checkered" : "lock.fill"))
            cell.imageView?.tintColor = examOpen ? ZDesign.Color.gold : .gray
            cell.accessibilityIdentifier = "ChapterExam-\(c.number)"
            cell.accessoryType = examOpen ? .disclosureIndicator : .none
        case .drill(let rung):
            let id = c.drills[rung], rungOpen = chapterOpen && Chapters.rungOpen(c, rung)
            let drill = Chapters.index(of: id).map { Drill.all[$0] }, best = PlayerStore.shared.stars(id)
            cell.textLabel?.text = "\(rung + 1). " + (drill?.title ?? id) + "   " + Drill.starText(best) + PlayerStore.shared.badges(id).map { "  " + $0.symbol }.joined()   // 0.49b X8: small badges
            let level = Int(Chapters.stars(id))
            cell.detailTextLabel?.text = (FeatureFlags.progress && level > 0 ? "Độ khó " + Drill.starText(level) + " · " : "") + (rungOpen ? (drill?.note ?? "") : "Đạt 3/5 ở bài trước để mở")
            cell.imageView?.image = UIImage(systemName: best >= Int(BL_RUNG_PASS_STARS) ? "checkmark.seal.fill" : (rungOpen ? "circle" : "lock.fill"))
            cell.imageView?.tintColor = best >= Int(BL_RUNG_PASS_STARS) ? .systemGreen : (rungOpen ? ZDesign.Color.gold : .gray)
            cell.accessoryType = rungOpen ? .disclosureIndicator : .none
            cell.accessibilityIdentifier = "ChapterDrill-" + id
        }
        return cell
    }
    private func openLesson(_ index: Int) {
        let lesson = DrillLessonController(drill: Drill.all[index])
        lesson.start = { [weak self] in guard let self = self else { return }; self.dismiss(animated: true) { self.load?(index) } }
        lesson.guidedStart = { [weak self] in guard let self = self else { return }; self.dismiss(animated: true) { self.guidedLoad?(index) } }
        navigationController?.pushViewController(lesson, animated: true)
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let c = Chapters.all[indexPath.section]
        guard open.indices.contains(indexPath.section), open[indexPath.section], !c.drills.isEmpty else { return }
        let row = rows(c)[indexPath.row]
        let go = { [weak self] in
            guard let self = self else { return }
            switch row {
            case .exam:
                guard Chapters.examOpen(c) else { return }
                self.dismiss(animated: true) { self.exam?(c.number) }
            case .drill(let rung):
                guard Chapters.rungOpen(c, rung), let index = Chapters.index(of: c.drills[rung]) else { return }
                self.openLesson(index)
            case .legacy(let id): if let index = Chapters.index(of: id) { self.openLesson(index) }
            case .ladder(let l):
                let sheet = UIAlertController(title: L10n.tr(Mastery.ladderTitles[l.name] ?? l.name), message: L10n.tr("Chọn vòng: to → vừa → nhỏ"), preferredStyle: .actionSheet)
                for id in l.rings {
                    let open = Mastery.ringOpen(id), t = Mastery.tier(id)
                    let action = UIAlertAction(title: "\(L10n.tr("Vòng")) \(t) · " + (open ? self.ringStars(id) : L10n.tr("Đạt 3 sao vòng trước để mở")), style: .default) { [weak self] _ in
                        guard open, let index = Chapters.index(of: id) else { return }; self?.openLesson(index)
                    }
                    action.isEnabled = open; sheet.addAction(action)
                }
                sheet.addAction(UIAlertAction(title: L10n.tr("Đóng"), style: .cancel))
                if let pop = sheet.popoverPresentationController, let cell = self.tableView.cellForRow(at: indexPath) { pop.sourceView = cell; pop.sourceRect = cell.bounds }
                self.present(sheet, animated: true)
            case .settings: self.chapterSettings(c)
            case .legacyTitle: break
            }
        }
        // First time into a chapter: its ONE tip card, then it lives in Sổ mẹo.
        if case .settings = row { go(); return }
        if !PlayerStore.shared.data.tipsSeen.contains(c.number) {
            PlayerStore.shared.markTipSeen(c.number)
            present(TipCardController(chapter: c, done: go), animated: true)
        } else { go() }
    }
    /// M4: "Chơi lại chương từ đầu", two confirmations: clears this chapter's stars, warm-ups and take-backs (the only way back to "Tay sạch").
    private func chapterSettings(_ c: Chapter) {
        let sheet = UIAlertController(title: L10n.tr("Cài đặt chương"), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: L10n.tr("Chơi lại chương từ đầu"), style: .destructive) { [weak self] _ in
            let sure = UIAlertController(title: L10n.tr("Xoá sao của chương này?"), message: L10n.tr("Sao, khởi động và quỹ lùi cú của chương này sẽ về từ đầu. Các chương khác giữ nguyên."), preferredStyle: .alert)
            sure.view.accessibilityIdentifier = "ChapterResetSure"
            sure.addAction(UIAlertAction(title: L10n.tr("Tiếp tục"), style: .destructive) { [weak self] _ in
                let really = UIAlertController(title: L10n.tr("Chắc chắn chơi lại chương?"), message: L10n.tr("Không hoàn tác được."), preferredStyle: .alert)
                really.view.accessibilityIdentifier = "ChapterResetReally"
                really.addAction(UIAlertAction(title: L10n.tr("Chơi lại chương"), style: .destructive) { [weak self] _ in
                    PlayerStore.shared.resetChapter(key: c.key, drills: c.drills + c.legacy, ladders: Mastery.ladders(c).map { $0.name })
                    self?.viewWillAppear(false)
                })
                really.addAction(UIAlertAction(title: L10n.tr("Hủy"), style: .cancel)); self?.present(really, animated: true)
            })
            sure.addAction(UIAlertAction(title: L10n.tr("Hủy"), style: .cancel)); self?.present(sure, animated: true)
        })
        sheet.addAction(UIAlertAction(title: L10n.tr("Đóng"), style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.sourceView = tableView; pop.sourceRect = CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 1, height: 1) }
        present(sheet, animated: true)
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
        super.viewDidLoad(); title = "Sổ mẹo"; addPushedClose()
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
