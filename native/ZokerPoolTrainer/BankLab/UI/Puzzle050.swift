import UIKit

/// 0.50 "Thế bí" — the UI slice on top of the C core (Puzzle.h): room map with locks (T1), the puzzle screen with its one-line task (T2),
/// instant retry with a real measurement (T3), hint jar with levels 1–2 (T4, level 3 not built), stars (T5).
/// Judging is BLDrillJudge on the puzzle's own spec — the same call as a normal drill (TC+ShotLoop.catalogJudge).
enum PuzzleText {
    static let skillNames = ["Cú thẳng", "Lực", "Dừng · theo · lùi", "Bi ma", "Quy tắc 30°", "Quy tắc 90°", "Đi bi", "Gương 1 băng", "Corner-5", "Hệ Plus", "Gương bank", "Giấu bi"]
    /// T2: one symbol per tool (SF Symbols).
    static let skillSymbols = ["arrow.right", "speedometer", "arrow.triangle.2.circlepath", "circle.dashed", "30.circle", "90.circle", "scope",
                               "arrow.left.arrow.right", "plus.circle", "5.circle", "arrow.triangle.turn.up.right.diamond", "eye.slash"]
    static func symbol(_ s: Int32) -> String { skillSymbols.indices.contains(Int(s)) ? skillSymbols[Int(s)] : "questionmark.circle" }
    static func skill(_ s: Int32) -> String { skillNames.indices.contains(Int(s)) ? skillNames[Int(s)] : "" }
    static func task(style: Int32) -> String {
        switch Int(style) {
        case Int(BL_PUZZLE_REACH): return "Chạm bi 1. Bi xám chắn đường thẳng."
        case Int(BL_PUZZLE_POSITION): return "Ăn bi 1, bi cái dừng trong vòng."
        case Int(BL_PUZZLE_HIDE): return "Chạm bi 1 rồi giấu nó sau bi xám."
        default: return "Đưa bi 1 vào lỗ. Bi cái chạm bi 1 trước."
        }
    }
}

struct PuzzleSession {
    var index: Int            // BLPuzzleTable index
    var drillIndex: Int       // Drill.all index of the puzzle's drill
    var tries = 0, hintLevel = 0
    var found = Set<Int32>()  // routes (BLPuzzleSolutionIndex) found
    var solved = false
    var mirrored = false      // a review: the left–right twin of the puzzle (T6), no stars
    var viaPractice = false   // came back from "Ra bàn tập" (T8)
    var reviewStep = 0
    var userSpec: BLPuzzleSpec?   // 0.51 N3: a friend's puzzle (index −1), checked again on this device
    var userCode = ""
    var dailyDay: Int64?      // 0.51 N1: today's daily puzzle (6 tries, no hints, no stars)
}

enum PuzzleRooms {
    static func puzzles(in room: Int) -> [Int] {
        var idx = [Int32](repeating: 0, count: 64); let n = Int(BLPuzzleRoomCount(Int32(room), &idx, 64)); return (0..<n).map { Int(idx[$0]) }
    }
    static func key(_ i: Int) -> String { BLPuzzleAt(Int32(i)).map { String(cString: $0.pointee.spec.key) } ?? "" }
    /// Stars earned in each room (index 1…BL_DRILL_CHAPTERS).
    static func starsByRoom(_ s: PlayerStore = .shared) -> [Int32] {
        var out = [Int32](repeating: 0, count: Int(BL_DRILL_CHAPTERS) + 1)
        for r in 1...Int(BL_DRILL_CHAPTERS) { out[r] = Int32(puzzles(in: r).reduce(0) { $0 + s.puzzleStars(key($1)) }) }
        return out
    }
    static func open(_ room: Int, _ s: PlayerStore = .shared) -> Bool { let stars = starsByRoom(s); return BLRoomOpen(Int32(room), stars) != 0 }
    /// "Còn N sao nữa là mở phòng k" for a locked room k: stars still missing in the room that blocks it.
    static func starsMissing(for room: Int, _ s: PlayerStore = .shared) -> Int {
        let stars = starsByRoom(s)
        for r in stride(from: room - 1, through: 1, by: -1) where BLRoomBlocks(Int32(r)) != 0 {
            let need = (3 * Int(BLPuzzleRoomCount(Int32(r), nil, 0)) * Int(BL_ROOM_UNLOCK_PERCENT) + 99) / 100
            return max(0, need - Int(stars[r]))
        }
        return 0
    }
}

/// T1: the map of rooms (rooms replace the chapter list for puzzles; each room: its puzzles, locked until the room before has enough stars).
final class PuzzleListController: UITableViewController {
    var open: ((Int, Bool) -> Void)?
    /// T6: reviews due today come first ("Thế bí hôm nay"), each as the left–right twin.
    private var reviews: [(key: String, step: Int)] = PlayerStore.shared.puzzleReviewsDue()
    private var reviewOffset: Int { reviews.isEmpty ? 0 : 1 }
    private let rooms = (1...Int(BL_DRILL_CHAPTERS)).filter { !PuzzleRooms.puzzles(in: $0).isEmpty }
    override func viewDidLoad() {
        super.viewDidLoad(); title = L10n.tr("Thế bí")
        tableView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1); tableView.accessibilityIdentifier = "Puzzles"
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 64
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.tr("Xong"), style: .done, target: self, action: #selector(close))
        let book = UIBarButtonItem(title: L10n.tr("Sổ lời giải"), style: .plain, target: self, action: #selector(openBook)); book.accessibilityIdentifier = "PuzzleBookOpen"
        let stats = UIBarButtonItem(title: L10n.tr("Đo cục bộ"), style: .plain, target: self, action: #selector(openStats)); stats.accessibilityIdentifier = "PuzzleStatsOpen"
        navigationItem.leftBarButtonItems = [book, stats]
    }
    @objc private func close() { dismiss(animated: true) }
    @objc private func openBook() { navigationController?.pushViewController(PuzzleBookController(style: .insetGrouped), animated: true) }
    @objc private func openStats() { navigationController?.pushViewController(PuzzleStatsController(style: .insetGrouped), animated: true) }
    override func numberOfSections(in tableView: UITableView) -> Int { rooms.count + reviewOffset }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if reviewOffset == 1 && section == 0 { return reviews.count }
        return PuzzleRooms.puzzles(in: rooms[section - reviewOffset]).count
    }
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if reviewOffset == 1 && section == 0 {
            let title = UILabel(); title.font = Wood.titleFont(24); title.textColor = ZDesign.Color.gold; title.text = L10n.tr("Thế bí hôm nay")
            let sub = UILabel(); sub.font = .systemFont(ofSize: 13); sub.textColor = UIColor(white: 0.72, alpha: 1); sub.text = L10n.tr("Ôn lại thế đã giải (lật gương trái–phải)")
            let stack = UIStackView(arrangedSubviews: [title, sub]); stack.axis = .vertical; stack.spacing = 2
            stack.isLayoutMarginsRelativeArrangement = true; stack.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 6, right: 20)
            stack.accessibilityIdentifier = "PuzzleReviewHeader"; return stack
        }
        let room = rooms[section - reviewOffset], isOpen = PuzzleRooms.open(room)
        let title = UILabel(); title.font = Wood.titleFont(24); title.textColor = isOpen ? ZDesign.Color.gold : UIColor(white: 0.55, alpha: 1)
        let chapterTitle = Chapters.chapter(room)?.title ?? ""
        title.text = L10n.tr("Phòng") + " \(room) · " + chapterTitle
        let state = UILabel(); state.font = .systemFont(ofSize: 13); state.textColor = UIColor(white: 0.72, alpha: 1); state.numberOfLines = 0
        let stars = PuzzleRooms.starsByRoom()[room], max = 3 * PuzzleRooms.puzzles(in: room).count
        state.text = isOpen ? "\(stars)/\(max) ★" : String(format: L10n.tr("Còn %d sao nữa là mở phòng %d"), PuzzleRooms.starsMissing(for: room), room)
        let stack = UIStackView(arrangedSubviews: [title, state]); stack.axis = .vertical; stack.spacing = 2
        stack.isLayoutMarginsRelativeArrangement = true; stack.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 6, right: 20)
        stack.accessibilityIdentifier = "PuzzleRoom-\(room)"; stack.isAccessibilityElement = true
        stack.accessibilityLabel = (title.text ?? "") + ". " + (state.text ?? "")
        return stack
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if reviewOffset == 1 && indexPath.section == 0 {
            let r = reviews[indexPath.row], cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); cell.backgroundColor = UIColor(white: 0.14, alpha: 1)
            cell.textLabel?.textColor = .white; cell.detailTextLabel?.textColor = UIColor(white: 0.78, alpha: 1)
            cell.textLabel?.text = L10n.tr("Ôn") + " " + r.key; cell.detailTextLabel?.text = String(format: L10n.tr("Ôn sau %d ngày"), r.step)
            cell.imageView?.image = UIImage(systemName: "arrow.left.arrow.right"); cell.imageView?.tintColor = ZDesign.Color.gold
            cell.accessoryType = .disclosureIndicator; cell.accessibilityIdentifier = "PuzzleReview-" + r.key; return cell
        }
        let room = rooms[indexPath.section - reviewOffset], i = PuzzleRooms.puzzles(in: room)[indexPath.row], p = BLPuzzleAt(Int32(i))!.pointee
        let key = PuzzleRooms.key(i), stars = PlayerStore.shared.puzzleStars(key), isOpen = PuzzleRooms.open(room)
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); cell.backgroundColor = UIColor(white: 0.14, alpha: 1)
        cell.textLabel?.textColor = .white; cell.detailTextLabel?.textColor = UIColor(white: 0.78, alpha: 1); cell.detailTextLabel?.numberOfLines = 2
        cell.textLabel?.text = "\(L10n.tr("Thế")) \(indexPath.row + 1)   " + Drill.starText3(stars)
        cell.detailTextLabel?.text = isOpen ? L10n.tr(PuzzleText.task(style: Int32(p.style))) + " · " + L10n.tr(PuzzleText.skill(p.spec.skill)) : L10n.tr("Chưa mở")
        cell.imageView?.image = UIImage(systemName: !isOpen ? "lock.fill" : PuzzleText.symbol(p.spec.skill))
        cell.imageView?.tintColor = !isOpen ? .gray : (stars > 0 ? .systemGreen : ZDesign.Color.gold)
        cell.accessoryType = isOpen ? .disclosureIndicator : .none; cell.accessibilityIdentifier = "Puzzle-" + key
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if reviewOffset == 1 && indexPath.section == 0 {
            let r = reviews[indexPath.row], i = Int(BLPuzzleIndex(r.key))
            dismiss(animated: true) { [open] in open?(i, true) }; return
        }
        let room = rooms[indexPath.section - reviewOffset]
        guard PuzzleRooms.open(room) else { return }
        let i = PuzzleRooms.puzzles(in: room)[indexPath.row]
        dismiss(animated: true) { [open] in open?(i, false) }
    }
}
extension Drill { static func starText3(_ n: Int) -> String { String(repeating: "★", count: max(0, min(3, n))) + String(repeating: "☆", count: 3 - max(0, min(3, n))) } }

/// T8: local measures (never sent anywhere): hint jar run dry, practice trips that ended in a solve, puzzles solved, the most abandoned puzzle.
final class PuzzleStatsController: UITableViewController {
    private var lines: [(String, String)] = []
    override func viewDidLoad() {
        super.viewDidLoad(); title = L10n.tr("Đo cục bộ"); tableView.accessibilityIdentifier = "PuzzleStats"
        tableView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        let d = PlayerStore.shared.data
        let solved = d.puzzleStars.filter { $0.value > 0 }.count
        let trips = d.practiceTrips, back = d.practiceReturnSolved
        let worst = d.puzzleTries.filter { (d.puzzleStars[$0.key] ?? 0) == 0 }.max { $0.value < $1.value }
        let daily = PlayerStore.shared.dailyStats()
        lines = [(L10n.tr("Thế đã giải"), "\(solved)"),
                 (L10n.tr("Thế của ngày: đã chơi / giải được"), "\(daily.played) / \(daily.solved)"),
                 (L10n.tr("Thế của ngày: số cơ trung bình"), daily.solved > 0 ? String(format: "%.1f", daily.averageTries) : "–"),
                 (L10n.tr("Lần bấm Khoe"), "\(d.dailyShares)"),
                 (L10n.tr("Lần cạn bình gợi ý"), "\(d.hintsEmptied)"),
                 (L10n.tr("Ra bàn tập rồi quay lại giải được"), trips > 0 ? "\(back)/\(trips) (\(back * 100 / trips) %)" : "–"),
                 (L10n.tr("Thế bị bỏ nhiều nhất"), worst.map { "\($0.key) · \($0.value) " + L10n.tr("cú") } ?? "–")]
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { lines.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil); cell.backgroundColor = UIColor(white: 0.14, alpha: 1)
        cell.textLabel?.text = lines[indexPath.row].0; cell.textLabel?.textColor = .white; cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.text = lines[indexPath.row].1; cell.detailTextLabel?.textColor = ZDesign.Color.gold
        return cell
    }
}

/// T5 "Sổ lời giải": per solved puzzle, the player's own stroke next to the listed reference stroke (opens only after the puzzle is solved).
final class PuzzleBookController: UITableViewController {
    private let keys = PlayerStore.shared.data.puzzleBook.keys.sorted()
    override func viewDidLoad() {
        super.viewDidLoad(); title = L10n.tr("Sổ lời giải"); tableView.accessibilityIdentifier = "PuzzleBook"
        tableView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1); tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 70
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(1, keys.count) }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); cell.backgroundColor = UIColor(white: 0.14, alpha: 1)
        cell.textLabel?.textColor = .white; cell.detailTextLabel?.textColor = UIColor(white: 0.78, alpha: 1); cell.detailTextLabel?.numberOfLines = 0
        guard !keys.isEmpty else { cell.textLabel?.text = L10n.tr("Chưa có lời giải nào. Giải một thế bí để xem ở đây."); cell.textLabel?.numberOfLines = 0; return cell }
        let key = keys[indexPath.row], mine = PlayerStore.shared.data.puzzleBook[key]!
        cell.textLabel?.text = key + "  " + Drill.starText3(PlayerStore.shared.puzzleStars(key))
        cell.accessibilityIdentifier = "PuzzleBookEntry-" + key
        if let i = BLPuzzleIndex(key) as Int32?, i >= 0, let p = BLPuzzleAt(i)?.pointee {
            var q = p; let route = BLPuzzleSolutionIndex(&q, Int32(mine.signature))
            let ref = p.solutions.0
            let dAngle = (mine.angle - ref.angle) * 180 / .pi, dSpeed = ref.speed > 0 ? (mine.speed / ref.speed - 1) * 100 : 0
            cell.detailTextLabel?.text = String(format: L10n.tr("Của bạn: lực %.1f m/s · %lld lần thử · Mẫu: lực %.1f m/s. Lệch góc %+.1f° · lệch lực %+.0f %%"), mine.speed, mine.tries, ref.speed, dAngle, dSpeed)
                + (route >= 0 ? "\n" + String(format: L10n.tr("Bạn đã tìm lời giải số %d"), Int(route) + 1) : "")
        }
        return cell
    }
}

extension TrainingController {
    func openPuzzles() {
        guard !shotActive, replayIndex == nil else { return }
        let list = PuzzleListController(style: .insetGrouped); list.open = { [weak self] i, mirrored in self?.beginPuzzle(i, mirrored: mirrored) }
        let nav = UINavigationController(rootViewController: list); nav.overrideUserInterfaceStyle = .dark
        topPresenter.present(nav, animated: true)
    }
    func puzzleSpec(_ s: PuzzleSession) -> BLPuzzleSpec? {
        if let u = s.userSpec { return u }
        guard var p = BLPuzzleAt(Int32(s.index))?.pointee else { return nil }
        guard s.mirrored else { return p }
        var out = BLPuzzleSpec(); BLPuzzleMirror(&p, &out); return out
    }
    /// T2: load the puzzle as the table: its layout, nothing drawn (no aim help in the main mode), one line of task.
    /// T6: `mirrored` = the left–right twin used by the reviews (no stars).
    func beginPuzzle(_ i: Int, mirrored: Bool = false, carry: PuzzleSession? = nil, reviewStep: Int = 0, daily: Int64? = nil, user: BLPuzzleSpec? = nil, userCode: String = "", userDrillIndex: Int = -1) {
        guard let p = user ?? BLPuzzleAt(Int32(i))?.pointee else { return }
        let key = user != nil ? "user" : String(cString: p.spec.key)
        guard let drillIndex = user != nil ? userDrillIndex : Drill.all.firstIndex(where: { $0.id == (mirrored ? "m-" : "") + key }), drillIndex >= 0 else { return }
        // T7 "kết thúc đẹp": the puzzle being left was not solved → count it; after two in a row offer an easier open one.
        if let old = puzzleSession, !old.solved, old.tries > 0, old.index != i || old.mirrored != mirrored { puzzleFailedInRow += 1 } else if puzzleSession?.solved == true { puzzleFailedInRow = 0 }
        if testRun != nil { endTestRun(cancelled: true) }
        if let previous = guidedCoachBefore { coaching = previous; guidedCoachBefore = nil }
        coaching = false; applyCoachVisibility()
        setMenu(false)
        // ROOT CAUSE of "the listed route misses in the app" (0.50): `loadDrill` silently refuses while the shot camera is returning or a
        // sheet is still dismissing, so the puzzle's session started on the PREVIOUS layout and the reference stroke missed it.
        // SECOND ROOT CAUSE (found by comparing engine.settings with Config::app): the player's last stroke kind (Jump: cue 45°, 3D on) is
        // saved between launches and made the same stroke miss by 9–10 cm. A puzzle is always played with the normal cue.
        func attempt(_ left: Int) {
            guard testRun == nil else { return }
            if !shotActive && !presentationBusy && localTurn { if shotKind != 0 { chooseShotKind(0) }; loadDrill(drillIndex) }
            guard self.drillIndex == drillIndex, !shotActive, shotKind == 0 else {
                if left > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { attempt(left - 1) } }
                return
            }
            lessonActive = false
            var session = carry ?? PuzzleSession(index: i, drillIndex: drillIndex)
            session.index = i; session.drillIndex = drillIndex; session.mirrored = mirrored; session.reviewStep = reviewStep; session.solved = false; session.dailyDay = daily; session.userSpec = user; session.userCode = userCode
            if let day = daily { session.tries = PlayerStore.shared.dailyState(day).grades.count }
            if QA.has("--puzzle-hint3-qa") { session.hintLevel = 2 }   // QA: the jar holds 3 and level 3 costs 2 after two earlier hints, so a test starts at level 2
            puzzleSession = session
            buildPuzzleBarIfNeeded(); syncPuzzleBar(); puzzleAction()
            statusLabel.text = L10n.tr(PuzzleText.task(style: Int32(p.style)))
            if BLPuzzleOfferEasier(Int32(puzzleFailedInRow)) != 0 { offerEasierPuzzle() }
        }
        attempt(100)
    }
    func endPuzzle() { puzzleSession = nil; table.target(nil); table.trails([:]); syncPuzzleBar() }
    /// T7: two puzzles left unsolved in a row → suggest an open, unsolved one that most players solve.
    func offerEasierPuzzle() {
        puzzleFailedInRow = 0
        let stars = PuzzleRooms.starsByRoom()
        var best: (Int, Int32)?
        for i in 0..<Int(BLPuzzleCount()) {
            guard let p = BLPuzzleAt(Int32(i))?.pointee, PlayerStore.shared.puzzleStars(String(cString: p.spec.key)) == 0, BLRoomOpen(p.spec.chapter, stars) != 0, p.solutionCount > 0 else { continue }
            if best == nil || p.solutions.0.percent > best!.1 { best = (i, p.solutions.0.percent) }
        }
        guard let target = best?.0 else { return }
        let alert = UIAlertController(title: L10n.tr("Nghỉ một chút?"), message: L10n.tr("Hai thế liền chưa được. Thử một thế vừa sức hơn nhé."), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.tr("Thử thế này"), style: .default) { [weak self] _ in self?.beginPuzzle(target) })
        alert.addAction(UIAlertAction(title: L10n.tr("Đóng"), style: .cancel))
        alert.view.accessibilityIdentifier = "PuzzleEasier"
        topPresenter.present(alert, animated: true)
    }
    /// T7: a rest reminder after 45 minutes of puzzles in one go (`RestNudge`, logic tested with a fake clock). Every puzzle action calls this.
    func puzzleAction() {
        if QA.has("--rest-nudge-qa") && restNudge.threshold > 10 { restNudge.threshold = 3; restNudge.gap = 60 }
        guard restNudge.action(at: Date().timeIntervalSince1970) else { return }
        restNudges += 1
        notifyStatus(L10n.tr("Bạn chơi đã 45 phút. Nghỉ mắt một chút nhé."))
        statusLabel.text = L10n.tr("Bạn chơi đã 45 phút. Nghỉ mắt một chút nhé.")
    }
    private func buildPuzzleBarIfNeeded() {
        guard puzzleBar == nil else { return }
        let bar = UIView(); bar.accessibilityIdentifier = "PuzzleBar"; ZPill.apply(to: bar)
        let icon = UIImageView(); icon.tintColor = ZDesign.Color.gold; icon.contentMode = .scaleAspectFit; icon.accessibilityIdentifier = "PuzzleSkillIcon"
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
        let task = UILabel(); task.font = .systemFont(ofSize: 13, weight: .semibold); task.textColor = .white; task.numberOfLines = 3; task.accessibilityIdentifier = "PuzzleTask"
        func button(_ symbol: String, _ id: String, _ title: String? = nil) -> UIButton {
            var c = UIButton.Configuration.filled(); c.image = UIImage(systemName: symbol); c.title = title; c.cornerStyle = .capsule; c.imagePadding = 4
            c.baseBackgroundColor = UIColor(white: 0.03, alpha: 0.6); c.baseForegroundColor = .white
            let b = UIButton(configuration: c); b.accessibilityIdentifier = id
            b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true; return b
        }
        let hint = button("lightbulb", "PuzzleHint", "3"), retry = button("arrow.counterclockwise", "PuzzleRetry"), book = button("book", "PuzzleBookButton"), more = button("list.bullet", "PuzzleListButton")
        more.addAction(UIAction { [weak self] _ in self?.openPuzzles() }, for: .touchUpInside)
        hint.addAction(UIAction { [weak self] _ in self?.puzzleHint() }, for: .touchUpInside)
        retry.addAction(UIAction { [weak self] _ in self?.retryPuzzle() }, for: .touchUpInside)
        book.addAction(UIAction { [weak self] _ in let nav = UINavigationController(rootViewController: PuzzleBookController(style: .insetGrouped)); nav.overrideUserInterfaceStyle = .dark; self?.topPresenter.present(nav, animated: true) }, for: .touchUpInside)
        book.isHidden = true
        let stack = UIStackView(arrangedSubviews: [icon, task, hint, retry, book, more]); stack.spacing = 8; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false; bar.addSubview(stack); bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12), stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: bar.topAnchor, constant: 4), stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -4),
            bar.centerXAnchor.constraint(equalTo: view.centerXAnchor), bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            bar.widthAnchor.constraint(lessThanOrEqualToConstant: 500), bar.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -260)])
        puzzleBar = bar; puzzleTaskLabel = task; puzzleHintButton = hint; puzzleIcon = icon; puzzleBookButton = book
    }
    func syncPuzzleBar() {
        guard let bar = puzzleBar else { return }
        bar.isHidden = puzzleSession == nil || menuOpen || replayIndex != nil
        guard let s = puzzleSession, let p = puzzleSpec(s) else { return }
        let found = "\(L10n.tr("Đã tìm")) \(s.found.count)/\(p.solutionCount)"
        if let day = s.dailyDay {
            let st = PlayerStore.shared.dailyState(day)
            puzzleTaskLabel?.text = L10n.tr("Thế bí của ngày") + " #\(BLDailyNumber(day)) · \(st.grades.count)/\(DailyPuzzleState.maxTries) " + DailyPuzzle.dots(st.grades) + "\n" + L10n.tr(PuzzleText.task(style: Int32(p.style)))
        } else { puzzleTaskLabel?.text = (s.mirrored ? L10n.tr("Ôn lại (lật gương)") + ": " : "") + L10n.tr(PuzzleText.task(style: Int32(p.style))) + "\n" + L10n.tr(PuzzleText.skill(p.spec.skill)) + " · " + found }
        puzzleIcon?.image = UIImage(systemName: PuzzleText.symbol(p.spec.skill))
        let jar = currentHintJar()
        puzzleHintButton?.configuration?.title = "\(jar.count)"
        puzzleHintButton?.isEnabled = !shotActive && !s.mirrored
        puzzleHintButton?.isHidden = s.mirrored || s.dailyDay != nil || s.userSpec != nil   // a review and the daily puzzle are played without hints
        puzzleBookButton?.isHidden = !s.solved
    }
    // MARK: T3 retry
    /// One tap: the balls go back, no dialog. Waits (0.1 s steps) while the shot camera is still returning — the same silent-refusal trap as the exam.
    func retryPuzzle() {
        guard puzzleSession != nil else { return }
        puzzleAction()
        let t0 = CACurrentMediaTime()
        func go() {
            guard let s = puzzleSession else { return }
            if shotActive || presentationBusy || !localTurn { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { go() }; return }
            let previous = paths[0]   // the path of the try just played (N4 "bóng của chính mình")
            loadDrill(s.drillIndex); table.target(nil); table.trails([:])
            ghostPathShown = false
            if let prev = previous, prev.count > 1, UserDefaults.standard.object(forKey: Prefs.puzzleGhostPath) as? Bool ?? true, puzzleSession?.dailyDay == nil || true {
                table.trails([0: prev]); ghostPathShown = true; ghostPathCount += 1; wakeRendering()   // cleared when the next stroke starts (shoot → table.trails([:]))
            }
            puzzleSession?.solved = false
            puzzleRetryMs = (CACurrentMediaTime() - t0) * 1000; puzzleRetries += 1
            if let p = puzzleSpec(s) { statusLabel.text = L10n.tr(PuzzleText.task(style: Int32(p.style))) }
            syncPuzzleBar()
        }
        go()
    }
    // MARK: T4 hint jar
    func currentHintJar(now: Double = Date().timeIntervalSince1970) -> BLHintJar {
        var jar = BLHintJar(); let d = PlayerStore.shared.data
        if d.hintJarCount < 0 { BLHintJarInit(&jar, now) } else { jar.count = Int32(d.hintJarCount); jar.refillFrom = d.hintJarRefillFrom }
        BLHintJarUpdate(&jar, now); return jar
    }
    var puzzleGhostActive: Bool { Date().timeIntervalSince1970 < puzzleGhostUntil }
    func puzzleHint() {
        guard var session = puzzleSession, !session.mirrored, session.dailyDay == nil, session.userSpec == nil, !shotActive, !puzzleGhostActive, let p = puzzleSpec(session) else { return }
        let level = min(3, session.hintLevel + 1)
        let now = Date().timeIntervalSince1970
        var jar = currentHintJar(now: now)
        guard BLHintJarSpend(&jar, Int32(level), now) != 0 else {
            let minutes = Int((BLHintJarNextIn(&jar, now) / 60).rounded(.up))
            statusLabel.text = String(format: L10n.tr("Hết gợi ý. Còn %d phút nữa có thêm 1 lượt."), minutes)
            if jar.count == 0 { PlayerStore.shared.saveHintJar(count: 0, refillFrom: jar.refillFrom, emptied: true) }
            syncPuzzleBar(); return
        }
        PlayerStore.shared.saveHintJar(count: Int(jar.count), refillFrom: jar.refillFrom, emptied: jar.count == 0)
        session.hintLevel = max(session.hintLevel, level); puzzleSession = session
        let key = String(cString: p.spec.key)
        switch level {
        case 1:
            let skill = PuzzleText.skill(p.spec.skill)
            statusLabel.text = L10n.tr("Công cụ cần dùng") + ": " + L10n.tr(skill)
            let alert = UIAlertController(title: L10n.tr("Công cụ cần dùng"), message: L10n.tr(skill), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("Ra bàn tập"), style: .default) { [weak self] _ in self?.goPractice(skill: p.spec.skill) })
            alert.addAction(UIAlertAction(title: L10n.tr("Đóng"), style: .cancel))
            alert.view.accessibilityIdentifier = "PuzzleHint1"
            topPresenter.present(alert, animated: true)
        case 2:
            if p.solutionCount > 0 {
                let s = p.solutions.0
                var along = 0.0, across = 0.0; BLDrillDiamonds(s.hintX, s.hintY, &along, &across)
                table.target(PracticeGoal(x: s.hintX, y: s.hintY, radius: 0.03, potRequired: false))
                statusLabel.text = String(format: L10n.tr("Điểm gợi ý: nút dài %@ · nút ngắn %@"), RealTableCardController.diamonds(along), RealTableCardController.diamonds(across))
            }
        default:
            // Level 3: the listed route plays once, faint; the player cannot strike while it runs. Costs 2 and caps the stars at 1.
            guard p.solutionCount > 0 else { break }
            let r = p.solutions.0
            let samples = engine.prediction(angle: r.angle, speed: r.speed, side: 0, top: r.top)
            var paths: [Int: [SIMD3<Float>]] = [:]
            for q in samples { guard let id = q["id"]?.intValue, id <= 1, let x = q["x"]?.doubleValue, let y = q["y"]?.doubleValue else { continue }
                paths[id, default: []].append(SIMD3<Float>(Float(x), 0.004, Float(y))) }
            puzzleGhostUntil = now + 4; table.trails(paths); wakeRendering()
            PlayerStore.shared.markPuzzleWatched(key: key, at: now)
            statusLabel.text = L10n.tr("Đường bi mẫu (chạy một lần)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.1) { [weak self] in self?.table.trails([:]); self?.syncPuzzleBar(); self?.wakeRendering() }   // wake: an idle table does not refresh the probe
        }
        syncPuzzleBar()
    }
    /// T4 level 1: the lesson of the tool, then back to the same puzzle ("Quay lại thế bí" after a cleared round).
    func goPractice(skill: Int32) {
        let lesson = BLSkillLesson(skill)
        guard lesson >= 0, let spec = BLDrillAt(lesson), let index = Chapters.index(of: String(cString: spec.pointee.key)), var back = puzzleSession else { return }
        back.viaPractice = true; puzzleReturn = back
        PlayerStore.shared.notePracticeTrip()
        endPuzzle(); beginDrill(index, guided: false)
    }
    /// Called by the round alert after a cleared lesson that was started from a hint: the jar gets one back and the puzzle can be resumed.
    func puzzleRoundClearedFromHint(_ alert: UIAlertController) {
        guard let back = puzzleReturn else { return }
        let now = Date().timeIntervalSince1970; var jar = currentHintJar(now: now)
        BLHintJarEarn(&jar, now); PlayerStore.shared.saveHintJar(count: Int(jar.count), refillFrom: jar.refillFrom)
        alert.addAction(UIAlertAction(title: L10n.tr("Quay lại thế bí"), style: .default) { [weak self] _ in
            self?.puzzleReturn = nil; self?.beginPuzzle(back.index, mirrored: back.mirrored, carry: back)
        })
    }
    // MARK: T5 shot result
    /// Called from finishShot after the drill judging (`passed`) for a puzzle drill.
    func puzzleShotFinished(_ d: Drill, passed: Bool, scratch: Bool, timedOut: Bool, railCount: Int, events: [[String: NSNumber]]) {
        guard var s = puzzleSession, s.drillIndex == drillIndex, var p = puzzleSpec(s) else { return }
        s.tries += 1; puzzleAction()
        if let day = s.dailyDay { puzzleSession = s; dailyShotFinished(s, day: day, d: d, passed: passed, events: events); return }
        if passed, let user = s.userSpec {   // a friend's puzzle: no stars, no book; a line to challenge back
            s.solved = true
            PlayerStore.shared.noteCodeSolved()   // 0.55 R5
            let line = String(format: L10n.tr("Tôi giải mã %@ trong %d cơ"), UserPuzzleController.pretty(s.userCode), s.tries)
            statusLabel.text = L10n.tr("Giải được") + " · " + String(format: L10n.tr("%d lần thử"), s.tries); userChallengeLine = line; _ = user
            puzzleSession = s; syncPuzzleBar()
            let alert = UIAlertController(title: L10n.tr("Giải được"), message: line, preferredStyle: .alert)
            alert.view.accessibilityIdentifier = "UserPuzzleSolved"
            alert.addAction(UIAlertAction(title: L10n.tr("Thách lại"), style: .default) { [weak self] _ in
                guard let self = self else { return }
                let share = UIActivityViewController(activityItems: [line], applicationActivities: nil)
                share.popoverPresentationController?.sourceView = self.view
                share.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
                self.topPresenter.present(share, animated: true)
            })
            alert.addAction(UIAlertAction(title: L10n.tr("Đóng"), style: .cancel)); topPresenter.present(alert, animated: true)
            return
        }
        if passed {
            let kinds = events.map { Int32($0["kind"]?.intValue ?? 0) }, a = events.map { Int32($0["a"]?.intValue ?? 0) }, b = events.map { Int32($0["b"]?.intValue ?? 0) }
            let sig = BLDrillSignature(Int32(events.count), kinds, a, b)
            let route = BLPuzzleSolutionIndex(&p, sig)
            if route >= 0 { s.found.insert(route) }
            let key = String(cString: BLPuzzleAt(Int32(s.index))!.pointee.spec.key)
            s.solved = true
            if s.mirrored {
                PlayerStore.shared.markPuzzleReviewDone(key: key, step: s.reviewStep)
                statusLabel.text = L10n.tr("Ôn xong") + " · " + String(format: L10n.tr("%d lần thử"), s.tries)
            } else {
                let small = catalogJudge(d, events: events, goalScale: 0.6) == true
                let now = Date().timeIntervalSince1970
                let stars = Int(BLPuzzleSessionStars(&p, Int32(s.tries), Int32(s.hintLevel), PlayerStore.shared.data.puzzleWatched[key] ?? 0, now, Int32(s.found.count), small ? 1 : 0))
                PlayerStore.shared.recordPuzzle(key: key, stars: stars, tries: s.tries)
                // "Chỉ số Mắt": a puzzle solved within three tries counts 1, otherwise 0, against the puzzle's measured rating
                PlayerStore.shared.setEye(BLEyeUpdate(PlayerStore.shared.data.eye, BLPuzzleTaskRating(p.solutions.0.percent), s.tries <= 3 ? 1 : 0))
                let shot = lastShot
                PlayerStore.shared.recordPuzzleSolve(key: key, record: PuzzleRecord(angle: shot?.strikeAngle ?? shot?.aimAngle ?? angle, speed: shot?.speed ?? 0, top: shot?.top ?? 0, signature: Int(sig), day: PlayerStore.shared.day(Date()), tries: s.tries))
                if s.viaPractice { PlayerStore.shared.notePracticeTrip(returnedAndSolved: true); s.viaPractice = false }
                statusLabel.text = L10n.tr("Giải được") + " " + Drill.starText3(stars) + " · " + String(format: L10n.tr("%d lần thử"), s.tries)
                // the third-star task, when it is still open
                if stars < 3, s.hintLevel < 2 {
                    switch Int(BLPuzzleThirdStarTask(&p)) {
                    case Int(BL_PUZZLE_THIRD_SECOND_ROUTE): statusLabel.text = (statusLabel.text ?? "") + " · " + L10n.tr("Sao 3: tìm lời giải thứ hai")
                    case Int(BL_PUZZLE_THIRD_SMALL_TARGET): statusLabel.text = (statusLabel.text ?? "") + " · " + L10n.tr("Sao 3: dừng trong vùng nhỏ")
                    default: statusLabel.text = (statusLabel.text ?? "") + " · " + L10n.tr("Sao 3: giải ngay lần đầu")
                    }
                }
            }
            notifyStatus(statusLabel.text ?? "")
        } else {
            let (_, detail) = lessonShotScore(d, passed: false, scratch: scratch, timedOut: timedOut, railCount: railCount)
            statusLabel.text = detail.isEmpty ? L10n.tr("Chưa được. Thử lại.") : detail   // the real measurement, nothing invented
        }
        puzzleSession = s; syncPuzzleBar()
    }
}
