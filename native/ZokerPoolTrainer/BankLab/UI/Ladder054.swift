import UIKit

/// 0.54 M2/M3/M4 — the ring-ladder round flow. Rules come from Mastery.h (warm-up, stars, ring unlocking, title band, take-back budget); this file only drives the table.
extension TrainingController {
    var currentChapter: Chapter? {
        guard lessonActive, !matchPlay.active, Drill.all.indices.contains(drillIndex), let at = Chapters.locate(Drill.all[drillIndex].id) else { return nil }
        return Chapters.chapter(at.chapter)
    }
    /// A player's own "Lùi cú" inside a chapter drill is counted against the chapter's budget; with no budget left nothing happens (progress stays).
    func userTakeBack(_ run: () -> Void) {
        if let c = currentChapter {
            guard Mastery.undoAllowed(c) else { notifyStatus(L10n.tr("Hết quỹ lùi cú của chương này")); return }
            PlayerStore.shared.noteUndo(c.key); run(); updateControls(); return
        }
        run()
    }
    /// 0.56 K2: after a scored round — a miss counts toward "failed rounds in a row", a pass clears it.
    func noteRoundForRescue(_ d: Drill, cleared: Bool) { failedRounds[d.id] = cleared ? 0 : (failedRounds[d.id] ?? 0) + 1 }
    /// 0.56 K2: when a chapter drill starts and BLPowerBarRescue says yes, ask ONCE (per drill) — "Dùng" shows the power bar for this drill only (and costs "Tay sạch").
    func maybeOfferRescue(_ d: Drill) {
        guard let c = currentChapter, !rescueAsked.contains(d.id), rescueBarDrill != drillIndex,
              Mastery.rescue(c, makePercent: Int(d.spec?.makePercent ?? 100), failedRounds: failedRounds[d.id] ?? 0) else { return }
        rescueAsked.insert(d.id)
        let index = drillIndex
        let alert = UIAlertController(title: nil, message: L10n.tr("Bài này khó. Dùng thanh lực trợ giúp? (mất dấu Tay sạch)"), preferredStyle: .alert)
        alert.view.accessibilityIdentifier = "RescueCard"
        alert.addAction(UIAlertAction(title: L10n.tr("Dùng"), style: .default) { [weak self] _ in
            guard let self = self, self.drillIndex == index else { return }
            PlayerStore.shared.noteRescue(c.key); self.rescueBarDrill = index; self.syncPowerBar(); self.view.setNeedsLayout()
        })
        alert.addAction(UIAlertAction(title: L10n.tr("Tự đánh tiếp"), style: .cancel))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.topPresenter.present(alert, animated: true) }
    }
    /// The line shown when a ring is opened: warm-up progress or the shot requirement.
    func ladderIntro(_ d: Drill) {
        ladderRoundStartedAt = Date(); roundShots = []
        guard let spec = d.spec, spec.tier > 0 else { return }
        let ladder = Mastery.ladderName(of: d.id), warm = PlayerStore.shared.warmMade(ladder)
        if spec.tier == 1 && !Mastery.warmDone(warm) {
            scoreLabel.text = String(format: L10n.tr("Khởi động %d/5"), min(5, warm))
            notifyStatus(String(format: L10n.tr("Khởi động %d/5"), min(5, warm)) + " · " + ladderRequirement(spec))
        } else {
            scoreLabel.text = L10n.tr("Lượt 5 cú") + " · 0 / 5"
            notifyStatus(ladderRequirement(spec))
        }
    }
    func ladderRequirement(_ spec: BLDrillSpec) -> String {
        spec.rails > 0 ? String(format: L10n.tr("Chạm đúng %d băng rồi dừng trong vòng"), Int(spec.rails)) : L10n.tr("Dừng trong vòng")
    }
    func ladderShot(_ d: Drill, passed shotPassed: Bool, railCount: Int) {
        guard var spec = d.spec else { return }
        let passed = shotPassed || QA.has("--ring-pass-qa")   // 0.58c QA: every shot counts, so a ring closes with 3 stars
        let index = drillIndex, ladder = Mastery.ladderName(of: d.id), tier = Int(spec.tier), store = PlayerStore.shared
        var missLine = ""
        if spec.rails > 0 && !passed && railCount != Int(spec.rails) { missLine = " · " + String(format: L10n.tr("Sai số băng: %d"), abs(railCount - Int(spec.rails))) }
        func rerack(_ n: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                guard let self = self, self.lessonActive, self.drillIndex == index, !self.shotActive, self.replayIndex == nil, !self.isPlacingBalls else { return }
                if self.drillHasVariants() { self.relayDrill(variant: n) }
                else { if self.shotBack.isEmpty { self.undo() } else { self.stepShot(-1) } }
            }
        }
        // warm-up: shots made in the big ring count up to 5, nothing is scored yet
        if tier == 1 && !Mastery.warmDone(store.warmMade(ladder)) {
            if passed { store.addWarm(ladder, made: 1) }
            let made = store.warmMade(ladder)
            if Mastery.warmDone(made) {
                statusLabel.text = L10n.tr("Khởi động xong") + " · " + L10n.tr("bắt đầu lượt chấm"); scoreLabel.text = L10n.tr("Lượt 5 cú") + " · 0 / 5"
            } else {
                statusLabel.text = String(format: L10n.tr("Khởi động %d/5"), made) + " · " + (passed ? L10n.tr("ĐẠT") : L10n.tr("Chưa đạt")) + missLine
                scoreLabel.text = String(format: L10n.tr("Khởi động %d/5"), made)
            }
            notifyStatus(statusLabel.text ?? ""); lessonScores = []; lessonPasses = 0; rerack(0); return
        }
        lessonScores.append(passed ? 100 : 0); if passed { lessonPasses += 1 }
        roundShots.append(passed)
        let n = lessonScores.count
        statusLabel.text = String(format: L10n.tr("Cú %d/5"), n) + " · " + (passed ? L10n.tr("ĐẠT") : L10n.tr("Chưa đạt")) + missLine
        scoreLabel.text = L10n.tr("Lượt 5 cú") + " · " + String(format: L10n.tr("đạt %d / %d"), lessonPasses, n)
        notifyStatus(statusLabel.text ?? "")
        if n < 5 { rerack(n); return }
        // a scored round: stars from BLRoundStars, best kept, the next ring opens on 3 stars
        let stars = Int(BLRoundStars(&spec, Int32(lessonPasses), 5)), made = lessonPasses
        let chapter = currentChapter
        let before = chapter.map { Mastery.percent($0) } ?? 0, nextOpenBefore = ladderNextRing(d).map { Mastery.ringOpen($0) } ?? false
        noteRoundForRescue(d, cleared: stars > 0)
        let newBest = store.recordLadderRound(id: d.id, stars: stars, made: made, average: Double(made) * 20)
        lessonScores = []; lessonPasses = 0
        let after = chapter.map { Mastery.percent($0) } ?? 0
        // 0.58 T2: the round is kept (stars, %, take-backs, rescue, longest run, seconds, date): best + the last 20 per ring, and per chapter
        var run = 0, longest = 0; for v in roundShots { run = v ? run + 1 : 0; longest = max(longest, run) }
        let attempt = AchievementAttempt(stars: stars, percent: after, undoUsed: chapter.map { store.undoUsed($0.key) } ?? 0, usedPowerBar: chapter.map { store.rescueUsed($0.key) > 0 } ?? false,
                                         longestRun: longest, seconds: Date().timeIntervalSince(ladderRoundStartedAt ?? Date()), date: Date().timeIntervalSince1970)
        store.recordAchievement(d.id, attempt)
        if let c = chapter, !c.key.isEmpty { var ca = attempt; ca.stars = Mastery.titleIndex(after); store.recordAchievement("chapter-" + c.key, ca) }
        ladderRoundStartedAt = Date(); roundShots = []
        let next = ladderNextRing(d), nextOpened = next.map { !nextOpenBefore && Mastery.ringOpen($0) } ?? false
        var message = String(format: L10n.tr("%d/5 cú vào vòng"), made) + "\n" + (newBest ? L10n.tr("Kỷ lục mới của vòng này") + "\n" : "")
        if nextOpened { message += L10n.tr("Đã mở vòng kế tiếp") + "\n" }
        message += "\(after) %" + (chapter != nil ? " · " + L10n.tr(Mastery.titles[Mastery.titleIndex(after)]) : "")
        if let line = ringChallengeResultLine(drill: d, made: made) { message += "\n" + line }   // 0.58 P2
        let nextRingOpen = next.map { Mastery.ringOpen($0) } ?? false
        let chapterFinished = chapter.map { c in c.drills.filter { Mastery.tier($0) > 0 }.allSatisfy { store.ladderStars($0) >= 3 } } ?? false
        let decision = AutoAdvance.decide(stars: stars, nextRingOpen: nextRingOpen, chapterFinished: chapterFinished)   // 0.58 T1
        if case .autoNext = decision { message += "\n" + L10n.tr("Tự lên vòng sau 1,5 s — bấm Ở lại để dừng") }
        else if let nextId = next, !Mastery.ringOpen(nextId), stars < 3 { message += "\n" + L10n.tr("Vòng kế còn khoá: cần 3 sao ở vòng này") }   // 0.58c item 6: say what is missing
        let alert = UIAlertController(title: L10n.tr("Vòng") + " \(tier) · " + Drill.starText(stars), message: message, preferredStyle: .alert)
        alert.view.accessibilityIdentifier = "LadderRound"
        var autoTimer: Timer?
        let cancelAuto = { autoTimer?.invalidate(); autoTimer = nil }
        var startAuto: (() -> Void)?
        var goNext: UIAlertAction?
        if let nextId = next, Mastery.ringOpen(nextId), let nextIndex = Chapters.index(of: nextId) {
            let go = decision == .hold && stars < 3 ? L10n.tr("Vòng nhỏ hơn") : L10n.tr("Lên vòng tiếp ▶")
            let action = UIAlertAction(title: go, style: .default) { [weak self] _ in cancelAuto(); self?.goToDrillAtAim(nextIndex) }
            alert.addAction(action); goNext = action
            if case .autoNext = decision {   // 0.58c item 6: 1.5 s AFTER the card is on screen (it used to count from its creation); "Ở lại" cancels
                startAuto = { [weak self, weak alert] in
                    autoTimer = Timer.scheduledTimer(withTimeInterval: ResultNext.ladderAutoNextSeconds, repeats: false) { _ in
                        guard let alert = alert, alert.presentingViewController != nil else { return }
                        alert.dismiss(animated: true) { self?.goToDrillAtAim(nextIndex) }
                    }
                }
                AlertTapCancel058.attach(to: alert) { cancelAuto() }
            }
        }
        let again = UIAlertAction(title: stars >= 3 ? L10n.tr("Đánh lại lấy điểm cao hơn") : L10n.tr("Tập lại lượt mới"), style: .default) { [weak self] _ in cancelAuto(); self?.beginDrill(index, guided: false) }
        alert.addAction(again)
        alert.addAction(UIAlertAction(title: L10n.tr("Thách bạn"), style: .default) { [weak self] _ in self?.shareRingChallenge(d, stars: stars, made: made) })   // 0.58 P2
        let stayTitle: String = { if case .autoNext = decision { return L10n.tr("Ở lại") }; return L10n.tr("Đóng") }()
        alert.addAction(UIAlertAction(title: stayTitle, style: .cancel) { [weak self] _ in cancelAuto(); self?.lessonActive = false; self?.celebrateTitleIfNew(chapter); if decision == .chapterEnd { self?.presentChapterMedal(chapter) } })
        alert.preferredAction = goNext ?? again   // the main button: on to the next ring when it is open, else the missing piece = this ring again
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.present(alert, animated: true) { startAuto?() } }
        _ = before
    }
    func ladderNextRing(_ d: Drill) -> String? {
        guard let i = Chapters.index(of: d.id), i + 1 < Drill.all.count, let s = Drill.all[i + 1].spec, s.tier == (d.spec?.tier ?? 0) + 1,
              Mastery.ladderName(of: Drill.all[i + 1].id) == Mastery.ladderName(of: d.id) else { return nil }
        return Drill.all[i + 1].id
    }
    /// M3: moving up a title shows one card, once, with "Khoe" (the share card, M5).
    func celebrateTitleIfNew(_ chapter: Chapter?) {
        guard let c = chapter, Mastery.hasLadders(c) else { return }
        let pct = Mastery.percent(c), idx = Mastery.titleIndex(pct)
        guard idx > PlayerStore.shared.titleSeen(c.key), idx > 0 else { return }
        PlayerStore.shared.markTitleSeen(c.key, idx)
        titleCardShown = idx
        let alert = UIAlertController(title: L10n.tr(Mastery.titles[idx]), message: "“" + L10n.tr(Mastery.nickname) + "” · \(pct) %" + (Mastery.cleanSeal(c) ? "\n✓ " + L10n.tr("Tay sạch") : ""), preferredStyle: .alert)
        alert.view.accessibilityIdentifier = "TitleCard"
        alert.addAction(UIAlertAction(title: L10n.tr("Khoe"), style: .default) { [weak self] _ in self?.shareMasteryCard(c) })
        alert.addAction(UIAlertAction(title: L10n.tr("Đóng"), style: .cancel))
        topPresenter.present(alert, animated: true)
    }
    func shareMasteryCard(_ c: Chapter, present: Bool = true) {
        let pct = Mastery.percent(c)
        let image = Mastery.cardImage(player: UserDefaults.standard.string(forKey: "playerName0") ?? L10n.tr("Bạn"), title: L10n.tr(Mastery.titles[Mastery.titleIndex(pct)]),
                                       nickname: L10n.tr(Mastery.nickname), percent: pct, seal: Mastery.cleanSeal(c), tier: MedalTier.forTitle(Mastery.titleIndex(pct)))
        masteryCardBytes = image.pngData()?.count ?? 0
        guard present else { return }
        let share = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        topPresenter.present(share, animated: true)
    }
}

/// 0.58 T1: lets a tap on the result card cancel the auto-advance (the recogniser keeps its target weakly, so the alert owns it).
final class AlertTapCancel058: NSObject {
    private static var key = 0
    private let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
    @objc func fire() { run() }
    static func attach(to alert: UIAlertController, _ run: @escaping () -> Void) {
        let owner = AlertTapCancel058(run)
        let tap = UITapGestureRecognizer(target: owner, action: #selector(fire)); tap.cancelsTouchesInView = false
        alert.view.addGestureRecognizer(tap)
        objc_setAssociatedObject(alert, &key, owner, .OBJC_ASSOCIATION_RETAIN)
    }
}
