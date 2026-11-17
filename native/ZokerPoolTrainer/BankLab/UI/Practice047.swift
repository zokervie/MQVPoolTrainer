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
            let next = r.drills[r.shot % r.drills.count], kind = r.kind
            // Same pause as the 5-shot round: the player sees where the balls stopped, then the next layout.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                guard let self = self, self.testRun?.kind == kind, !self.shotActive, self.replayIndex == nil else { return }
                self.loadDrill(next)
                self.statusLabel.text = r.title + " · cú \(r.shot + 1)/10"
            }
            return
        }
        endTestRun(cancelled: false)
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
        if QA.has("--auto-shot-qa") {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
                guard let self = self else { t.invalidate(); return }
                guard self.lessonActive || self.testRun != nil, !self.shotActive, self.replayIndex == nil, self.presentedViewController == nil,
                      !self.engine.moving, self.cue?.sunk == false, self.strokeAllowed else { return }
                if self.lessonActive && self.lessonScores.count >= 5 { return }
                let d = Drill.all[self.drillIndex]
                // Same aim the drill suggests; the round needs a shot, not a pass.
                if self.balls.first(where: { $0.id == 0 }).map({ abs($0.x - (d.balls.first { $0.id == 0 }?.x ?? 0)) < 0.002 }) != true { return }
                self.angle = d.angle
                self.setHold(true); guard self.locked else { return }
                self.shoot(2.0); self.qaShots += 1; self.spin.collapse(); self.setHold(false)
            }
        }
        #endif
    }
    /// QA (scene accessibility value): 0.47 state for XCTest.
    var qa047: String {
        let d = Drill.all[drillIndex]
        return String(format: ";shotSpeed=%.4f;barFrac=%.4f;barMax=%.4f;bar=%lld", lastShotSpeed, powerBar?.firedFraction ?? 0, powerBarMaxSpeed, powerBar?.isHidden == false ? 1 : 0) + ";drill=" + d.id + ";lesson=\(lessonActive ? 1 : 0);lessonShots=\(lessonScores.count);test=" + (testRun.map { "\($0.kind):\($0.shot)" } ?? "none")
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
        return BLFeedbackLevel(PlayerStore.shared.data.level, Chapters.difficulty[d.id] ?? 3, 0)
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
            let level = Int(Chapters.difficulty[d.id] ?? 0)
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
