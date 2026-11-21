import UIKit

/// 0.50 "Thế bí" — the UI slice on top of the C core (Puzzle.h): room map with locks (T1), the puzzle screen with its one-line task (T2),
/// instant retry with a real measurement (T3), hint jar with levels 1–2 (T4, level 3 not built), stars (T5).
/// Judging is BLDrillJudge on the puzzle's own spec — the same call as a normal drill (TC+ShotLoop.catalogJudge).
enum PuzzleText {
    static let skillNames = ["Cú thẳng", "Lực", "Dừng · theo · lùi", "Bi ma", "Quy tắc 30°", "Quy tắc 90°", "Đi bi", "Gương 1 băng", "Corner-5", "Hệ Plus", "Gương bank", "Giấu bi"]
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
    var open: ((Int) -> Void)?
    private let rooms = (1...Int(BL_DRILL_CHAPTERS)).filter { !PuzzleRooms.puzzles(in: $0).isEmpty }
    override func viewDidLoad() {
        super.viewDidLoad(); title = L10n.tr("Thế bí")
        tableView.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1); tableView.accessibilityIdentifier = "Puzzles"
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 64
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L10n.tr("Xong"), style: .done, target: self, action: #selector(close))
    }
    @objc private func close() { dismiss(animated: true) }
    override func numberOfSections(in tableView: UITableView) -> Int { rooms.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { PuzzleRooms.puzzles(in: rooms[section]).count }
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let room = rooms[section], isOpen = PuzzleRooms.open(room)
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
        let room = rooms[indexPath.section], i = PuzzleRooms.puzzles(in: room)[indexPath.row], p = BLPuzzleAt(Int32(i))!.pointee
        let key = PuzzleRooms.key(i), stars = PlayerStore.shared.puzzleStars(key), isOpen = PuzzleRooms.open(room)
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); cell.backgroundColor = UIColor(white: 0.14, alpha: 1)
        cell.textLabel?.textColor = .white; cell.detailTextLabel?.textColor = UIColor(white: 0.78, alpha: 1); cell.detailTextLabel?.numberOfLines = 2
        cell.textLabel?.text = "\(L10n.tr("Thế")) \(indexPath.row + 1)   " + Drill.starText3(stars)
        cell.detailTextLabel?.text = isOpen ? L10n.tr(PuzzleText.task(style: Int32(p.style))) + " · " + L10n.tr(PuzzleText.skill(p.spec.skill)) : L10n.tr("Chưa mở")
        cell.imageView?.image = UIImage(systemName: !isOpen ? "lock.fill" : (stars > 0 ? "checkmark.seal.fill" : "circle"))
        cell.imageView?.tintColor = !isOpen ? .gray : (stars > 0 ? .systemGreen : ZDesign.Color.gold)
        cell.accessoryType = isOpen ? .disclosureIndicator : .none; cell.accessibilityIdentifier = "Puzzle-" + key
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let room = rooms[indexPath.section]
        guard PuzzleRooms.open(room) else { return }
        let i = PuzzleRooms.puzzles(in: room)[indexPath.row]
        dismiss(animated: true) { [open] in open?(i) }
    }
}
extension Drill { static func starText3(_ n: Int) -> String { String(repeating: "★", count: max(0, min(3, n))) + String(repeating: "☆", count: 3 - max(0, min(3, n))) } }

extension TrainingController {
    func openPuzzles() {
        guard !shotActive, replayIndex == nil else { return }
        let list = PuzzleListController(style: .insetGrouped); list.open = { [weak self] i in self?.beginPuzzle(i) }
        let nav = UINavigationController(rootViewController: list); nav.overrideUserInterfaceStyle = .dark
        topPresenter.present(nav, animated: true)
    }
    /// T2: load the puzzle as the table: its layout, nothing drawn (no aim help in the main mode), one line of task.
    func beginPuzzle(_ i: Int) {
        guard let p = BLPuzzleAt(Int32(i))?.pointee else { return }
        let key = String(cString: p.spec.key)
        guard let drillIndex = Drill.all.firstIndex(where: { $0.id == key }) else { return }
        if testRun != nil { endTestRun(cancelled: true) }
        if let previous = guidedCoachBefore { coaching = previous; guidedCoachBefore = nil }
        coaching = false; applyCoachVisibility()
        setMenu(false)
        // ROOT CAUSE of "the listed route misses in the app" (0.50): `loadDrill` silently refuses while the shot camera is returning or a
        // sheet is still dismissing, so the puzzle's session started on the PREVIOUS layout and the reference stroke missed it by 10 cm.
        // Wait until the table really holds this puzzle's drill, then start the session.
        func attempt(_ left: Int) {
            guard testRun == nil else { return }
            // SECOND ROOT CAUSE (found by comparing engine.settings with Config::app): the player's last stroke kind (Jump: cue 45°, 3D on) is
            // saved between launches and made the same reference stroke miss by 9–10 cm. A puzzle is always played with the normal cue.
            if !shotActive && !presentationBusy && localTurn { if shotKind != 0 { chooseShotKind(0) }; loadDrill(drillIndex) }
            guard self.drillIndex == drillIndex, !shotActive, shotKind == 0 else {
                if left > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { attempt(left - 1) } }
                return
            }
            lessonActive = false
            puzzleSession = PuzzleSession(index: i, drillIndex: drillIndex)
            buildPuzzleBarIfNeeded(); syncPuzzleBar()
            statusLabel.text = L10n.tr(PuzzleText.task(style: Int32(p.style)))
        }
        attempt(100)
    }
    func endPuzzle() { puzzleSession = nil; table.target(nil); syncPuzzleBar() }
    private func buildPuzzleBarIfNeeded() {
        guard puzzleBar == nil else { return }
        let bar = UIView(); bar.accessibilityIdentifier = "PuzzleBar"; ZPill.apply(to: bar)
        let task = UILabel(); task.font = .systemFont(ofSize: 13, weight: .semibold); task.textColor = .white; task.numberOfLines = 2; task.accessibilityIdentifier = "PuzzleTask"
        func button(_ symbol: String, _ id: String, _ title: String? = nil) -> UIButton {
            var c = UIButton.Configuration.filled(); c.image = UIImage(systemName: symbol); c.title = title; c.cornerStyle = .capsule; c.imagePadding = 4
            c.baseBackgroundColor = UIColor(white: 0.03, alpha: 0.6); c.baseForegroundColor = .white
            let b = UIButton(configuration: c); b.accessibilityIdentifier = id
            b.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true; return b
        }
        let hint = button("lightbulb", "PuzzleHint", "3"), retry = button("arrow.counterclockwise", "PuzzleRetry")
        hint.addAction(UIAction { [weak self] _ in self?.puzzleHint() }, for: .touchUpInside)
        retry.addAction(UIAction { [weak self] _ in self?.retryPuzzle() }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [task, hint, retry]); stack.spacing = 8; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false; bar.addSubview(stack); bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12), stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: bar.topAnchor, constant: 4), stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -4),
            bar.centerXAnchor.constraint(equalTo: view.centerXAnchor), bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            bar.widthAnchor.constraint(lessThanOrEqualToConstant: 460), bar.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -260)])
        puzzleBar = bar; puzzleTaskLabel = task; puzzleHintButton = hint
    }
    func syncPuzzleBar() {
        guard let bar = puzzleBar else { return }
        bar.isHidden = puzzleSession == nil || menuOpen || replayIndex != nil
        guard let s = puzzleSession, let p = BLPuzzleAt(Int32(s.index))?.pointee else { return }
        let found = "\(L10n.tr("Đã tìm")) \(s.found.count)/\(p.solutionCount)"
        puzzleTaskLabel?.text = L10n.tr(PuzzleText.task(style: Int32(p.style))) + "\n" + L10n.tr(PuzzleText.skill(p.spec.skill)) + " · " + found
        let jar = currentHintJar()
        puzzleHintButton?.configuration?.title = "\(jar.count)"
        puzzleHintButton?.isEnabled = !shotActive
    }
    // MARK: T3 retry
    /// One tap: the balls go back, no dialog. Waits (0.25 s steps) while the shot camera is still returning — the same silent-refusal trap as the exam.
    func retryPuzzle() {
        guard let s = puzzleSession else { return }
        let t0 = CACurrentMediaTime()
        func go() {
            guard let s = puzzleSession else { return }
            if shotActive || presentationBusy || !localTurn { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { go() }; return }
            loadDrill(s.drillIndex); table.target(nil)
            puzzleSession?.solved = false
            puzzleRetryMs = (CACurrentMediaTime() - t0) * 1000;puzzleRetries += 1
            if let p = BLPuzzleAt(Int32(s.index))?.pointee { statusLabel.text = L10n.tr(PuzzleText.task(style: Int32(p.style))) }
            syncPuzzleBar()
        }
        _ = s; go()
    }
    // MARK: T4 hint jar
    func currentHintJar(now: Double = Date().timeIntervalSince1970) -> BLHintJar {
        var jar = BLHintJar(); let d = PlayerStore.shared.data
        if d.hintJarCount < 0 { BLHintJarInit(&jar, now) } else { jar.count = Int32(d.hintJarCount); jar.refillFrom = d.hintJarRefillFrom }
        BLHintJarUpdate(&jar, now); return jar
    }
    func puzzleHint() {
        guard var session = puzzleSession, !shotActive, let p = BLPuzzleAt(Int32(session.index))?.pointee else { return }
        let level = min(2, session.hintLevel + 1)   // level 3 (the route replays once) is not built yet
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
        if level == 1 {
            statusLabel.text = L10n.tr("Công cụ cần dùng") + ": " + L10n.tr(PuzzleText.skill(p.spec.skill))
        } else if p.solutionCount > 0 {
            let s = p.solutions.0
            var along = 0.0, across = 0.0; BLDrillDiamonds(s.hintX, s.hintY, &along, &across)
            table.target(PracticeGoal(x: s.hintX, y: s.hintY, radius: 0.03, potRequired: false))
            statusLabel.text = String(format: L10n.tr("Điểm gợi ý: nút dài %@ · nút ngắn %@"), RealTableCardController.diamonds(along), RealTableCardController.diamonds(across))
        }
        syncPuzzleBar()
    }
    // MARK: T5 shot result
    /// Called from finishShot after the drill judging (`passed`) for a puzzle drill.
    func puzzleShotFinished(_ d: Drill, passed: Bool, scratch: Bool, timedOut: Bool, railCount: Int, events: [[String: NSNumber]]) {
        guard var s = puzzleSession, s.drillIndex == drillIndex, var p = BLPuzzleAt(Int32(s.index))?.pointee else { return }
        s.tries += 1
        if passed {
            let kinds = events.map { Int32($0["kind"]?.intValue ?? 0) }, a = events.map { Int32($0["a"]?.intValue ?? 0) }, b = events.map { Int32($0["b"]?.intValue ?? 0) }
            let sig = BLDrillSignature(Int32(events.count), kinds, a, b)
            let route = BLPuzzleSolutionIndex(&p, sig)
            if route >= 0 { s.found.insert(route) }
            let small = catalogJudge(d, events: events, goalScale: 0.6) == true
            let stars = Int(BLPuzzleSessionStars(&p, Int32(s.tries), Int32(s.hintLevel), 0, Date().timeIntervalSince1970, Int32(s.found.count), small ? 1 : 0))
            let key = String(cString: p.spec.key)
            PlayerStore.shared.recordPuzzle(key: key, stars: stars, tries: s.tries)
            s.solved = true
            statusLabel.text = L10n.tr("Giải được") + " " + Drill.starText3(stars) + " · " + String(format: L10n.tr("%d lần thử"), s.tries)
            notifyStatus(statusLabel.text ?? "")
        } else {
            let (_, detail) = lessonShotScore(d, passed: false, scratch: scratch, timedOut: timedOut, railCount: railCount)
            statusLabel.text = detail.isEmpty ? L10n.tr("Chưa được. Thử lại.") : detail   // the real measurement, nothing invented
        }
        puzzleSession = s; syncPuzzleBar()
    }
}

