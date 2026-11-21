import UIKit

/// 0.47 M0 / M5 — a test without help: 10 shots, Coach off, no result between shots, the score only at the end.
/// Used for the chapter exam (≥ 7/10 opens the next chapter, Chapters.h) and the weekly "Bài kiểm không trợ giúp"
/// (the "real progress" line on the Tiến bộ screen). Progress is written by PlayerStore.recordTest only.
struct TestRun {
    let kind: String          // "chapter-<n>" or "weekly"
    let title: String
    let drills: [Int]         // Drill.all index of each of the 10 shots
    var shot = 0, made = 0
    let coachBefore: Bool
}

extension TrainingController {
    func startChapterExam(_ chapter: Int) {
        guard let c = Chapters.chapter(chapter), Chapters.examOpen(c) else { return }
        startTestRun(TestRun(kind: Chapters.examKind(chapter), title: "Thi chương \(chapter) · \(c.title)", drills: Chapters.examDrills(c), coachBefore: coaching))
    }
    func startTestRun(_ run: TestRun) {
        guard !run.drills.isEmpty, matchAllowsEditing, !shotActive, replayIndex == nil else { return }
        if let previous = guidedCoachBefore { coaching = previous; guidedCoachBefore = nil }
        var r = run; r.shot = 0; r.made = 0
        testRun = r
        coaching = false
        loadDrill(r.drills[0]); applyCoachVisibility()
        statusLabel.text = r.title + " · cú 1/10 · không trợ giúp"
        notifyStatus(statusLabel.text ?? "")
    }
    /// Called once per finished shot while a test runs (TC+ShotLoop). Only the shot count is shown.
    func testRunShotFinished(passed: Bool) {
        guard var r = testRun else { return }
        r.shot += 1; if passed { r.made += 1 }
        testRun = r
        statusLabel.text = r.title + " · đã đánh \(r.shot)/10"
        notifyStatus(statusLabel.text ?? "")
        if r.shot < Int(BL_EXAM_SHOTS) {
            let next = r.drills[r.shot % r.drills.count], kind = r.kind, done = r.shot
            // Same pause as the 5-shot round: the player sees where the balls stopped, then the next layout.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.loadNextTestShot(next, kind: kind, done: done, title: r.title) }
            return
        }
        endTestRun(cancelled: false)
    }
    /// 0.49b ROOT CAUSE of testChapterOneLadderAndExam (CI 159–163, and a real bug): the next layout was loaded once, 1.6 s after the
    /// shot, and `loadDrill` silently refuses while the shot camera is still returning (presentationBusy). The label said
    /// "cú 2/10" but the table kept the last layout (cue ball gone), nothing could be played and no result ever came. A slow
    /// runner (camera clock advances ≤ 0.1 s per frame) hits it every time; a phone hits it when the camera return is slow.
    /// Now it waits for the table to be free (every 0.25 s) instead of giving up; a cancelled / restarted run stops the wait.
    func loadNextTestShot(_ next: Int, kind: String, done: Int, title: String) {
        guard let run = testRun, run.kind == kind, run.shot == done, replayIndex == nil else { return }
        if shotActive || presentationBusy || !localTurn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.loadNextTestShot(next, kind: kind, done: done, title: title) }
            return
        }
        loadDrill(next)
        applyDrillVariant(run.drills.prefix(done).filter { $0 == next }.count)   // 0.49b X3: first time a drill comes up = catalogue layout
        statusLabel.text = title + " · cú \(done + 1)/10"
    }
    func endTestRun(cancelled: Bool) {
        guard let r = testRun else { return }
        testRun = nil
        coaching = r.coachBefore; applyCoachVisibility()
        guard !cancelled else { return }
        let before = Chapters.openChapters()
        PlayerStore.shared.recordTest(kind: r.kind, made: r.made, shots: r.shot)
        let passed = BLExamPassed(Int32(r.made), Int32(r.shot)) != 0
        var message = "Đạt \(r.made)/10."
        if r.kind == "weekly" {
            message += "\nĐây là số tiến bộ thật: xem trên màn Tiến bộ."
        } else {
            let after = Chapters.openChapters()
            let opened = zip(before, after).enumerated().first { !$0.element.0 && $0.element.1 }.map { Chapters.all[$0.offset] }
            message += passed ? (opened.map { "\nĐã mở chương \($0.number) · \($0.title)." } ?? "\nQua bài thi chương.") : "\nCần đạt từ 7/10 để mở chương sau."
        }
        let alert = UIAlertController(title: (passed ? "Qua · " : "Chưa qua · ") + r.title, message: message, preferredStyle: .alert)
        alert.view.accessibilityIdentifier = "TestResult"
        alert.addAction(UIAlertAction(title: "Thi lại", style: .default) { [weak self] _ in
            var again = r; again.shot = 0; again.made = 0; self?.startTestRun(again) })
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.topPresenter.present(alert, animated: true) }
    }
    /// 0.47 QA launch flags (Debug only through `QA`): `--chapter-unlock-qa` clears chapter 1's rungs so its exam is
    /// open; `--auto-shot-qa` plays every drill/test shot by itself at the drill's suggested aim (UI tests walk a
    /// whole round or exam without gestures); `--progress-demo-qa` loads 30 days of made-up progress (Tiến bộ photo).
    func qa047Launch() {
        #if DEBUG
        if QA.has("--progress-demo-qa") {
            PlayerStore.shared.loadDemo(drills: Chapters.all.flatMap { $0.drills })
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in if self?.presentedViewController == nil { self?.openProgress() } }
        }
        if QA.has("--chapter-unlock-qa"), let c = Chapters.chapter(1) {
            for id in c.drills where PlayerStore.shared.stars(id) < 3 { PlayerStore.shared.recordRound(drill: id, stars: 3, average: 70, made: 3) }
        }
        if QA.has("--puzzle-review-qa") { PlayerStore.shared.recordPuzzleSolve(key: "p-1-01", record: PuzzleRecord(angle: 2.22, speed: 2.2, top: -0.3, signature: 5, day: 0, tries: 1), at: Date().addingTimeInterval(-86400)) }   // a solve yesterday: its day-1 review is due
        if QA.has("--open-puzzle-qa") { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.beginPuzzle(0) } }   // 0.50 QA: start puzzle #0 without the Lobby
        if QA.has("--wood-picker-qa") { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.openComputerMatch() } }   // photo of the wood picker
        if QA.has("--legal-qa") {   // 0.49c G2: opens Pháp lý for the UI test / photo
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                let nav = UINavigationController(rootViewController: LegalController()); nav.overrideUserInterfaceStyle = .dark
                self?.topPresenter.present(nav, animated: false)
            }
        }
        if QA.has("--drill-diagrams-qa") {   // 0.49c: the drill card of four drills as pictures (+ the diagram timing) in Documents/diagram-qa
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.writeDrillDiagramQA() }
        }
        if QA.has("--auto-shot-qa") {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
                guard let self = self else { t.invalidate(); return }
                guard self.lessonActive || self.testRun != nil || self.puzzleSession != nil, !self.shotActive, self.replayIndex == nil, self.presentedViewController == nil,
                      !self.engine.moving, self.cue?.sunk == false, self.strokeAllowed else { return }
                if self.lessonActive && self.lessonScores.count >= 5 { return }
                let d = Drill.all[self.drillIndex]
                // Same aim the drill suggests; the round needs a shot, not a pass.
                if self.balls.first(where: { $0.id == 0 }).map({ abs($0.x - (self.initial.first { $0.id == 0 }?.x ?? 0)) < 0.002 }) != true { return }
                if self.drillVariant == 0 { self.angle = d.angle }
                if QA.has("--puzzle-solve-qa"), let s = self.puzzleSession, !s.solved, let p = BLPuzzleAt(Int32(s.index))?.pointee, p.solutionCount > 0 {   // 0.50: play the best listed route
                    let r = p.solutions.0
                    self.angle = r.angle; self.spin.select(side: 0, top: r.top); self.setHold(true); guard self.locked else { return }
                    self.shoot(r.speed); self.qaShots += 1; self.spin.collapse(); self.setHold(false); return
                }
                if self.puzzleSession?.solved == true { return }
                if QA.has("--puzzle-miss-qa"), self.puzzleSession != nil { self.angle += 0.5 }   // a certain miss, for the retry / measurement test
                self.setHold(true); guard self.locked else { return }
                self.shoot(2.0); self.qaShots += 1; self.spin.collapse(); self.setHold(false)
            }
        }
        #endif
    }
    /// QA: the engine settings that differ from a fresh BLWorld (= Config::app, what the drill checker simulates), "key=app/fresh,…".
    func settingsDiffVsConfigApp() -> String {
        let fresh = BLWorld().settings
        return engine.settings.compactMap { k, v in
            let f = fresh[k]?.doubleValue; return f == v.doubleValue ? nil : "\(k)=\(v.doubleValue)/\(f.map { String($0) } ?? "nil")"
        }.sorted().joined(separator: ",")
    }
    /// QA (scene accessibility value): 0.47 state for XCTest.
    var qa047: String {
        let d = Drill.all[drillIndex]
        return String(format: ";shotSpeed=%.4f;barFrac=%.4f;barMax=%.4f;sdiff=\(QA.has("--settings-diff-qa") ? settingsDiffVsConfigApp() : "");dailyTries=\(PlayerStore.shared.dailyState(DailyPuzzle.today()).grades.count);dailyLocked=\(PlayerStore.shared.dailyState(DailyPuzzle.today()).locked ? 1 : 0);dailyShare=\(dailyShareShown.replacingOccurrences(of: ";", with: ",").replacingOccurrences(of: "\n", with: "|"));dailyShares=\(dailyShareTaps);puzzleFails=\(puzzleFailedInRow);puzzleMirrored=\(puzzleSession?.mirrored == true ? 1 : 0);puzzleGhost=\(puzzleGhostActive ? 1 : 0);puzzleHintLevel=\(puzzleSession?.hintLevel ?? 0);puzzle=\(puzzleSession.map { PuzzleRooms.key($0.index) } ?? "");puzzleStarsNow=\(puzzleSession.map { PlayerStore.shared.puzzleStars(PuzzleRooms.key($0.index)) } ?? -1);puzzleTries=\(puzzleSession?.tries ?? 0);puzzleRetryMs=\(String(format: "%.2f", puzzleRetryMs));puzzleRetries=\(puzzleRetries);hintJar=\(currentHintJar().count);petemoss=\(Wood.fontAvailable ? 1 : 0);glare=\(glareSummary);midShotLayout=%lld;barZoom=%.2f;bar=%lld", lastShotSpeed, powerBar?.firedFraction ?? 0, powerBarMaxSpeed, midShotLayoutTotal, Double(powerBar?.peakZoom ?? 1), powerBar?.isHidden == false ? 1 : 0) + ";drill=" + d.id + ";lesson=\(lessonActive ? 1 : 0);lessonShots=\(lessonScores.count);test=" + (testRun.map { "\($0.kind):\($0.shot)" } ?? "none") + String(format: ";layoutX=%.5f;layoutY=%.5f", initial.first { $0.id == 0 }?.x ?? 0, initial.first { $0.id == 0 }?.y ?? 0) + ";variant=\(drillVariant);spectrum=\(UserDefaults.standard.bool(forKey: Prefs.diagPowerSpectrum) ? 1 : 0);threeBallPref=\(UserDefaults.standard.bool(forKey: Prefs.threeBallBreak) ? 1 : 0);catalog=\(FeatureFlags.drillCatalog ? 1 : 0);chapters=" + Chapters.all.map { String($0.drills.count) }.joined(separator: ",")
    }
}

// MARK: - 0.47 round end (TC+Coach.scoreLesson): streak, Bài hôm nay, record, feedback summary, challenge
extension TrainingController {
    /// Right after PlayerStore.recordRound: what shows on the table (not in the alert).
    func roundFinished047(_ d: Drill, round: PlayerStore.RoundResult, stars: Int, average: Int) {
        if FeatureFlags.progress && round.newRecord { showNewRecord(d.title + " · " + L10n.tr("điểm trung bình") + " \(average)/100") }
        if FeatureFlags.dailyDrill && round.streakGrew {
            let days = PlayerStore.shared.streakShown()
            notifyStatus("Chuỗi ngày +1 · \(days) ngày liên tiếp")
        }
    }
    /// M5: how much to show after each shot of this drill (Challenge.h: BLFeedbackLevel — level 1–2 or a 4–5-star
    /// drill: full; level 3–5 on a 1–3-star drill: made/missed only, summary after 5 shots).
    func feedbackMode047(_ d: Drill) -> Int32 {
        guard FeatureFlags.fadingFeedback else { return Int32(BL_FEEDBACK_FULL) }
        return BLFeedbackLevel(PlayerStore.shared.data.level, Chapters.stars(d.id) > 0 ? Chapters.stars(d.id) : 3, 0)
    }
    func showFeedbackDetails() {
        let a = UIAlertController(title: "Chi tiết từng cú", message: feedbackDetails.joined(separator: "\n"), preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Đóng", style: .cancel)); topPresenter.present(a, animated: true)
    }
    /// Extra choices on the round result: next drill of today's three.
    func roundAlertExtras047(_ alert: UIAlertController, drill d: Drill, round: PlayerStore.RoundResult, index: Int) {
        if FeatureFlags.progress {   // M3: result = stars, time, made rate; difficulty of the drill
            let last = PlayerStore.shared.data.attempts.filter { $0.drill == d.id }.suffix(5)
            let seconds = Int(last.reduce(0) { $0 + $1.seconds }.rounded()), made = last.filter { $0.made }.count
            let level = Int(Chapters.stars(d.id))
            alert.message = (alert.message ?? "") + "\n" + L10n.tr("Vào") + " \(made)/\(last.count) · " + L10n.tr("thời gian") + String(format: " %lld:%02lld", seconds / 60, seconds % 60)
                + (level > 0 ? " · " + L10n.tr("độ khó") + " " + Drill.starText(level) : "")
        }
        if feedbackMode == Int32(BL_FEEDBACK_SUMMARY) && BLFeedbackSummaryDue(feedbackMode, Int32(feedbackDetails.count), 1) != 0 {
            let detail = feedbackDetails
            alert.message = (alert.message ?? "") + "\n" + L10n.tr("Tóm tắt 5 cú: chi tiết ẩn trong lúc đánh, bấm Xem chi tiết")
            alert.addAction(UIAlertAction(title: "Xem chi tiết", style: .default) { [weak self] _ in self?.feedbackDetails = detail; self?.showFeedbackDetails() })
        }
        if FeatureFlags.challenge {   // M6: side by side with the challenger, then challenge someone else
            let made = PlayerStore.shared.data.rounds.last?.made ?? 0, stars = PlayerStore.shared.data.rounds.last?.stars ?? 0
            if let c = challengePlaying, c.drill == index {
                alert.message = (alert.message ?? "") + "\n" + L10n.tr("Thách đấu") + " " + ChallengeCode.pretty(c.code) + ": " + L10n.tr("bạn") + " \(made)/5 · " + L10n.tr("người thách") + " \(c.score / 20)/5"
                    + (made * 20 > c.score ? " · " + L10n.tr("Bạn thắng!") : (made * 20 == c.score ? " · " + L10n.tr("Hoà") : ""))
                challengePlaying = nil
            }
            alert.addAction(UIAlertAction(title: "Thách bạn", style: .default) { [weak self] _ in self?.shareChallenge(drill: d, made: made, stars: stars) })
        }
        if FeatureFlags.dailyDrill {
            let picks = DailyDrills.today()
            if picks.contains(index) {
                let streak = PlayerStore.shared.streakShown()
                alert.message = (alert.message ?? "") + "\nBài hôm nay: \(picks.filter { DailyDrills.done($0) }.count)/\(picks.count) · \(streak) ngày liên tiếp"
                if let next = DailyDrills.nextUndone(), next != index {
                    alert.addAction(UIAlertAction(title: "Bài hôm nay tiếp theo", style: .default) { [weak self] _ in self?.beginDrill(next, guided: false) })
                }
            }
        }
    }
}

#if DEBUG
extension TrainingController {
    /// `--drill-diagrams-qa`: opens the drill card of stop-hold, cut-side-30, kick3-corner5 and pos-follow one after the other, writes
    /// each as a PNG and a summary.json with the time the table picture took (first call = render, second = cache).
    func writeDrillDiagramQA() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("diagram-qa")
        try? FileManager.default.removeItem(at: dir); try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let keys = ["stop-hold", "cut-side-30", "kick3-corner5", "pos-follow"]
        var timings: [String: Any] = [:]
        if QA.has("--diagram-solution-qa") { for k in keys { PlayerStore.shared.recordRound(drill: k, stars: 3, average: 70, made: 3) } }   // "played ≥ 1 round": the faint solution path shows
        func step(_ i: Int) {
            guard i < keys.count else {
                timings["pictureFirstMs"] = DrillTableImage.firstMs; timings["pictureLastMs"] = DrillTableImage.lastMs
                timings["picture"] = DrillTableImage.image() != nil
                if let d = try? JSONSerialization.data(withJSONObject: timings, options: [.prettyPrinted, .sortedKeys]) { try? d.write(to: dir.appendingPathComponent("summary.json")) }
                return
            }
            guard let index = Chapters.index(of: keys[i]) else { step(i + 1); return }
            let card = DrillLessonController(drill: Drill.all[index])
            let nav = UINavigationController(rootViewController: card); nav.modalPresentationStyle = .fullScreen
            topPresenter.present(nav, animated: false) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    let image = UIGraphicsImageRenderer(bounds: nav.view.bounds).image { _ in nav.view.drawHierarchy(in: nav.view.bounds, afterScreenUpdates: true) }
                    try? image.pngData()?.write(to: dir.appendingPathComponent(keys[i] + ".png"))
                    timings[keys[i] + "Ms"] = DrillTableImage.lastMs
                    nav.dismiss(animated: false) { step(i + 1) }
                }
            }
        }
        step(0)
    }
}
#endif
