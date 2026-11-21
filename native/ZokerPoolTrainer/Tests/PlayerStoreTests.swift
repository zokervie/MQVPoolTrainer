import Foundation

/// 0.45 M5: PlayerStore (player.json) — write/read, corrupt file → .bak restored, legacy title stars → stable ids,
/// streak/level/record through DailyLoop.h, usage numbers. Built with swiftc -import-objc-header BankLab/UI/DailyLoop.h.
@main struct PlayerStoreTests {
    struct Failure: Error, CustomStringConvertible { var description: String }
    static func main() throws {
        var checks = 0
        func check(_ ok: Bool, _ what: String) throws { guard ok else { throw Failure(description: what) }; checks += 1 }
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("PlayerStoreTests-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let utc = TimeZone(secondsFromGMT: 0)!, hanoi = TimeZone(secondsFromGMT: 7 * 3600)!
        let t0 = Date(timeIntervalSince1970: 1_763_000_000)   // a fixed instant
        func dayStart(_ n: Int) -> Date { t0.addingTimeInterval(Double(n) * 86400) }

        // 1 · write / read round trip
        let dirA = root.appendingPathComponent("a")
        let a = PlayerStore(directory: dirA, now: t0, timeZone: utc)
        try check(a.loadSource == "new" && a.data.schemaVersion == PlayerData.currentSchema, "fresh store")
        a.noteSession(at: t0)
        a.noteDrillOpened("cut-30-r", at: t0)
        a.recordShot(drill: "cut-30-r", made: true, at: t0.addingTimeInterval(12))
        a.recordShot(drill: "cut-30-r", made: false, at: t0.addingTimeInterval(20))
        a.recordShot(drill: nil, made: false, at: t0.addingTimeInterval(25))   // free table: counted, not an attempt
        let r = a.recordRound(drill: "cut-30-r", stars: 3, average: 70, at: t0.addingTimeInterval(30))
        try check(r.newBestStars && !r.newRecord && r.streakGrew, "first round: best stars, no 'record' on the first try, streak +1")
        try check(fm.fileExists(atPath: a.fileURL.path), "player.json written")
        try check(fm.fileExists(atPath: a.backupURL.path), ".bak kept from the previous write")
        let a2 = PlayerStore(directory: dirA, now: t0, timeZone: utc)
        try check(a2.loadSource == "file" && a2.data == a.data, "read back identical")
        try check(a2.data.attempts.count == 2 && a2.data.attempts[0].seconds == 12 && a2.data.attempts[1].seconds == 8, "attempt time since open / previous attempt")
        try check(a2.data.attempts[1].stars == 3 && a2.data.attempts[0].stars == 0, "round stars on the shot that closed it")
        try check(a2.data.metrics.shots == 3 && a2.data.metrics.sessions == 1 && a2.data.metrics.drillsCompleted == 1, "usage counters")
        try check(a2.stars("cut-30-r") == 3 && a2.streakShown(at: t0) == 1, "stars and streak readable")
        let text = String(data: try Data(contentsOf: a.fileURL), encoding: .utf8) ?? ""
        try check(text.contains("\"schemaVersion\":1"), "schemaVersion in the file")

        // 2 · corrupt main file → .bak restored, corrupt copy kept
        let before = a2.data
        a2.noteSession(at: t0.addingTimeInterval(60))          // .bak now = `before`
        try Data("{ not json".utf8).write(to: a2.fileURL)
        let a3 = PlayerStore(directory: dirA, now: t0, timeZone: utc)
        try check(a3.loadSource == "restored-from-bak", "unreadable file → restored from .bak (got \(a3.loadSource))")
        try check(a3.data == before, "restored data = last good copy")
        try check(fm.fileExists(atPath: a3.corruptURL.path), "corrupt file set aside, not lost")
        let a4 = PlayerStore(directory: dirA, now: t0, timeZone: utc)
        try check(a4.loadSource == "file" && a4.data == before, "restored copy written back as the main file")
        // both unreadable → fresh, never a crash
        try Data("x".utf8).write(to: a4.fileURL); try Data("y".utf8).write(to: a4.backupURL)
        let a5 = PlayerStore(directory: dirA, now: t0, timeZone: utc)
        try check(a5.loadSource == "reset-unreadable" && a5.data.attempts.isEmpty, "both unreadable → fresh store")
        // main missing (crash between remove and write) → .bak
        let dirB = root.appendingPathComponent("b")
        let b = PlayerStore(directory: dirB, now: t0, timeZone: utc)
        b.recordShot(drill: "bank1", made: true, at: t0); b.recordShot(drill: "bank1", made: true, at: t0)
        try fm.removeItem(at: b.fileURL)
        let b2 = PlayerStore(directory: dirB, now: t0, timeZone: utc)
        try check(b2.loadSource == "restored-from-bak" && b2.data.attempts.count == 1, "missing main file → .bak")
        // a file with only the required fields (older schema) still loads
        let dirC = root.appendingPathComponent("c"); try fm.createDirectory(at: dirC, withIntermediateDirectories: true)
        try Data("{\"metrics\":{\"installedAt\":1763000000,\"installDay\":20405}}".utf8).write(to: dirC.appendingPathComponent("player.json"))
        let c = PlayerStore(directory: dirC, now: t0, timeZone: utc)
        try check(c.loadSource == "file" && c.data.level == 1 && c.data.metrics.installDay == 20405, "missing fields fall back to defaults")

        // 3 · legacy stars by title → stable ids, once, nothing lost
        let legacy = ["Kick 1 băng · Gương A": 4, "Cắt phải 30° vào lỗ góc": 5, "Lực 2/3 · Dừng đúng vùng": 2,
                      "Trick · Reverse bank zigzag": 1, "Bài cũ không còn": 3]
        let dirD = root.appendingPathComponent("d")
        let d = PlayerStore(directory: dirD, now: t0, timeZone: utc)
        d.recordRound(drill: "speed-2", stars: 4, average: 80, at: t0)   // already better than the legacy 2
        try check(d.migrateLegacyStars(legacy) == legacy.count, "every legacy entry migrated")
        try check(d.stars("kick1-mirror-a") == 4 && d.stars("cut-30-r") == 5 && d.stars("trick-reverse-zigzag") == 1, "stars moved to ids")
        try check(d.stars("speed-2") == 4, "best of old and new kept")
        try check(d.stars("title:Bài cũ không còn") == 3, "unknown title kept, not dropped")
        try check(legacy.values.reduce(0, +) - 2 + 4 == d.data.stars.values.reduce(0, +), "total stars preserved")
        try check(d.migrateLegacyStars(["Bank 1 băng": 5]) == 0 && d.stars("bank1") == 0, "migration runs once")
        try check(PlayerStore(directory: dirD, now: t0, timeZone: utc).data.legacyStarsMigrated, "migration flag persisted")
        // the id table: unique ids, unique titles, every id non-empty and title-free
        let ids = DrillIDs.byTitle.map { $0.id }, titles = DrillIDs.byTitle.map { $0.title }
        try check(Set(ids).count == ids.count && Set(titles).count == titles.count, "drill ids and titles unique")
        try check(ids.allSatisfy { !$0.isEmpty && $0.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil }, "ids are ascii slugs")
        try check(DrillIDs.byTitle.count == 31 && DrillIDs.idForTitle["Cú đầu tiên"] == "first-shot", "31 drills of 0.47 mapped")

        // 4 · streak by LOCAL day, level from the last 7 days, personal record
        let dirE = root.appendingPathComponent("e")
        let e = PlayerStore(directory: dirE, now: t0, timeZone: hanoi)
        for n in 0..<3 { _ = e.recordRound(drill: "bank1", stars: 2, average: 50 + Double(n), at: dayStart(n)) }
        try check(e.data.streak.count == 3 && e.streakShown(at: dayStart(2)) == 3, "three days in a row")
        try check(!e.recordRound(drill: "bank1", stars: 2, average: 10, at: dayStart(2).addingTimeInterval(60)).streakGrew, "same day: no +1")
        try check(e.recordRound(drill: "bank1", stars: 2, average: 60, at: dayStart(3)).newRecord, "better average → record")
        try check(!e.recordRound(drill: "bank1", stars: 2, average: 60.2, at: dayStart(3)).newRecord, "within epsilon → no record")
        try check(e.streakShown(at: dayStart(9)) == 0, "long gap → streak shown 0")
        for i in 0..<10 { e.recordShot(drill: "bank1", made: i < 8, at: dayStart(4).addingTimeInterval(Double(i))) }
        try check(e.recordRound(drill: "bank1", stars: 4, average: 80, at: dayStart(4)).level == 2, "≥10 attempts, ≥70% → level up")

        // 5 · usage report and open days
        let dirF = root.appendingPathComponent("f")
        let f = PlayerStore(directory: dirF, now: t0, timeZone: utc)
        f.noteSession(at: t0); f.noteSession(at: t0.addingTimeInterval(60)); f.noteSession(at: dayStart(1)); f.noteSession(at: dayStart(7))
        try check(f.data.metrics.openDays.count == 3 && f.data.metrics.sessions == 4, "distinct open days, every session")
        let report = f.usageReport(at: dayStart(7), extra: ["version: test"])
        try check(report.contains("D1 opened: yes") && report.contains("D7 opened: yes") && report.contains("sessions: 4") && report.hasSuffix("version: test"), "usage report")
        // 6 · 0.47: round log (Bài hôm nay ticks), tests (chapter exam best / weekly), tips seen, survives a reload
        let dirG = root.appendingPathComponent("g")
        let g = PlayerStore(directory: dirG, now: t0, timeZone: hanoi)
        g.recordRound(drill: "stop-hold", stars: 3, average: 70, made: 3, at: dayStart(0))
        try check(g.roundsToday("stop-hold", at: dayStart(0).addingTimeInterval(3600)) == 1 && g.roundsToday("stop-hold", at: dayStart(1)) == 0, "rounds today by local day")
        try check(g.recordTest(kind: "chapter-1", made: 6, shots: 10, at: dayStart(0)), "first full exam sets the best")
        try check(!g.recordTest(kind: "chapter-1", made: 9, shots: 8, at: dayStart(0)), "interrupted exam never becomes the best")
        try check(g.recordTest(kind: "chapter-1", made: 8, shots: 10, at: dayStart(1)) && g.data.examBest["chapter-1"] == 8, "better exam improves the best")
        try check(!g.weeklyTestDone(at: dayStart(1)), "no weekly test yet")
        g.recordTest(kind: "weekly", made: 7, shots: 10, at: dayStart(1))
        try check(g.weeklyTestDone(at: dayStart(1)) && g.data.examBest["weekly"] == nil, "weekly test logged, not an exam best")
        g.markTipSeen(3); g.markTipSeen(1); g.markTipSeen(3)
        try check(g.data.tipsSeen == [1, 3], "tips seen once, sorted")
        let daily = g.daily(days: 2, at: dayStart(1))
        try check(daily.count == 2 && daily[0].rounds == 1 && daily[1].rounds == 0, "daily series oldest first")
        let g2 = PlayerStore(directory: dirG, now: t0, timeZone: hanoi)
        try check(g2.data.rounds.count == 1 && g2.data.tests.count == 4 && g2.data.tipsSeen == [1, 3], "0.47 fields survive a reload")
        // 7 · 0.49b: exam keys move to the catalogue's chapter keys once; real-table log
        let dirH = root.appendingPathComponent("h")
        let h = PlayerStore(directory: dirH, now: t0, timeZone: hanoi)
        h.recordTest(kind: "chapter-1", made: 8, shots: 10, at: dayStart(0)); h.recordTest(kind: "chapter-2", made: 9, shots: 10, at: dayStart(0))
        h.recordTest(kind: "chapter-3", made: 7, shots: 10, at: dayStart(0)); h.recordTest(kind: "chapter-4", made: 10, shots: 10, at: dayStart(0))
        h.recordTest(kind: "chapter-5", made: 7, shots: 10, at: dayStart(0)); h.recordTest(kind: "chapter-6", made: 8, shots: 10, at: dayStart(0))
        h.migrateLegacyExamKeys()
        try check(h.data.examBest["straight-speed"] == 9 && h.data.examBest["stop-follow-draw"] == 8, "chapter-1 → both, chapter-2 → straight-speed (best of both)")
        try check(h.data.examBest["cut"] == 7 && h.data.examBest["kick"] == 7 && h.data.examBest["bank"] == 7 && h.data.examBest["special"] == 8, "chapters 3, 5, 6 moved")
        try check(h.data.examBest.keys.allSatisfy { !$0.hasPrefix("chapter-") } && h.data.examBest.count == 6, "old keys gone, chapter-4 dropped")
        h.recordTest(kind: "cut", made: 9, shots: 10, at: dayStart(1)); h.migrateLegacyExamKeys()
        try check(h.data.examBest["cut"] == 9, "migration runs once")
        h.recordRealTable(drill: "stop-hold", made: 6, at: dayStart(0)); h.recordRealTable(drill: "stop-hold", made: 14, at: dayStart(1))
        try check(h.realTable("stop-hold").map { $0.made } == [6, 10] && h.realTable("bank1").isEmpty, "real-table log keeps order and clamps to 0…10")
        for i in 0..<60 { h.recordRealTable(drill: "x", made: i % 11, at: dayStart(2)) }
        try check(h.realTable("x").count == PlayerStore.maxRealTable, "real-table log is bounded")
        let h2 = PlayerStore(directory: dirH, now: t0, timeZone: hanoi)
        try check(h2.data.examKeysMigrated && h2.realTable("stop-hold").count == 2, "0.49b fields survive a reload")
        try check(DrillBadge.longestRun([true, true, false, true, true, true, false]) == 3 && DrillBadge.longestRun([]) == 0 && DrillBadge.longestRun([false]) == 0, "longest run of made shots")
        try check(h.awardBadge(.streak3, drill: "stop-hold") && !h.awardBadge(.streak3, drill: "stop-hold") && h.awardBadge(.small, drill: "stop-hold"), "a badge is new once")
        try check(h.badges("stop-hold") == [.streak3, .small] && h.badges("bank1").isEmpty, "badges per drill")
        let h3 = PlayerStore(directory: dirH, now: t0, timeZone: hanoi)
        try check(h3.badges("stop-hold") == [.streak3, .small], "badges survive a reload")
        // 8 · 0.50: puzzle stars never go down, tries add up, hint jar state round-trips
        try check(h.recordPuzzle(key: "p-1-01", stars: 2, tries: 3) && !h.recordPuzzle(key: "p-1-01", stars: 1, tries: 2) && h.puzzleStars("p-1-01") == 2, "puzzle best stars only rise")
        try check(h.data.puzzleTries["p-1-01"] == 5 && h.puzzleStars("p-9-99") == 0, "puzzle tries add up")
        h.saveHintJar(count: 2, refillFrom: 1_000.5, emptied: true)
        let h4 = PlayerStore(directory: dirH, now: t0, timeZone: hanoi)
        try check(h4.data.hintJarCount == 2 && h4.data.hintJarRefillFrom == 1_000.5 && h4.data.hintsEmptied == 1 && h4.puzzleStars("p-1-01") == 2, "0.50 fields survive a reload")
        // 9 · 0.50 T5/T6: Sổ lời giải, watched time, reviews after 1 / 3 / 7 days
        h.recordPuzzleSolve(key: "p-2-01", record: PuzzleRecord(angle: 1.5, speed: 2.0, top: -0.3, signature: 15, day: 0, tries: 2), at: dayStart(10))
        try check(h.data.puzzleBook["p-2-01"]?.tries == 2 && h.data.puzzleSolvedDay["p-2-01"] == h.day(dayStart(10)), "the solving stroke and day are kept")
        try check(h.puzzleReviewsDue(at: dayStart(10)).isEmpty && h.puzzleReviewsDue(at: dayStart(11)).first?.step == 1, "review 1 comes the next day")
        h.markPuzzleReviewDone(key: "p-2-01", step: 1)
        try check(h.puzzleReviewsDue(at: dayStart(12)).isEmpty && h.puzzleReviewsDue(at: dayStart(13)).first?.step == 3, "then day 3")
        h.markPuzzleReviewDone(key: "p-2-01", step: 3); h.markPuzzleReviewDone(key: "p-2-01", step: 7)
        try check(h.puzzleReviewsDue(at: dayStart(30)).isEmpty, "all three reviews played: nothing due")
        h.markPuzzleWatched(key: "p-2-01", at: 123.5); h.notePracticeTrip(); h.notePracticeTrip(returnedAndSolved: true)
        let h5 = PlayerStore(directory: dirH, now: t0, timeZone: hanoi)
        try check(h5.data.puzzleWatched["p-2-01"] == 123.5 && h5.data.practiceTrips == 1 && h5.data.practiceReturnSolved == 1 && h5.data.puzzleBook.count == 1, "0.50 book / watch / trips survive a reload")
        // 10 · 0.51 N1: the daily puzzle locks after a solve or 6 tries and stays per day
        for g in [0, 1, 0] { h.recordDailyTry(day: 20800, grade: g) }
        try check(!h.dailyState(20800).locked && h.dailyState(20800).grades == [0, 1, 0], "tries so far, still open")
        h.recordDailyTry(day: 20800, grade: 2)
        try check(h.dailyState(20800).solved && h.dailyState(20800).locked && h.dailyState(20800).grades.count == 4, "a solve locks the day")
        h.recordDailyTry(day: 20800, grade: 0)
        try check(h.dailyState(20800).grades.count == 4, "a locked day takes no more tries")
        for _ in 0..<7 { h.recordDailyTry(day: 20801, grade: 0) }
        try check(h.dailyState(20801).grades.count == 6 && h.dailyState(20801).locked && !h.dailyState(20801).solved && !h.dailyState(20802).locked, "6 tries lock, the next day is open")
        let h6 = PlayerStore(directory: dirH, now: t0, timeZone: hanoi)
        try check(h6.dailyState(20801).grades.count == 6 && h6.dailyState(20800).solved, "daily state survives a reload")
        // 11 · 0.51: solving the daily puzzle counts for the streak; local measures
        let h7 = PlayerStore(directory: root.appendingPathComponent("h7"), now: t0, timeZone: hanoi)
        let streakBefore = h7.data.streak.best
        h7.recordDailyTry(day: h7.day(dayStart(0)), grade: 0); h7.recordDailyTry(day: h7.day(dayStart(0)), grade: 2)
        h7.recordDailyTry(day: h7.day(dayStart(1)), grade: 2)
        let st = h7.dailyStats()
        try check(st.played == 2 && st.solved == 2 && st.averageTries == 1.5, "daily local measures: played, solved, average tries")
        try check(h7.data.streak.best >= max(streakBefore, 2), "two solved days in a row make a streak of 2")
        h7.noteDailyShare(); h7.noteDailyShare()
        try check(PlayerStore(directory: root.appendingPathComponent("h7"), now: t0, timeZone: hanoi).data.dailyShares == 2, "Khoe taps are kept")
        // 13 · 0.51 N2: only the first 5 predictions of a day change the Eye
        let h8 = PlayerStore(directory: root.appendingPathComponent("h8"), now: t0, timeZone: hanoi)
        try check(h8.data.eye == 1000, "the Eye starts at 1000")
        var counted = 0; for _ in 0..<8 { if h8.notePrediction(day: 21000) { counted += 1 } }
        try check(counted == 5, "5 scored predictions a day, the rest is practice (got \(counted))")
        try check(h8.notePrediction(day: 21001), "a new day counts again")
        h8.setEye(1042.5); h8.setEye(50)
        try check(PlayerStore(directory: root.appendingPathComponent("h8"), now: t0, timeZone: hanoi).data.eye == 100, "the Eye is kept and never drops under 100")
        // 12 · 0.50 T7: the 45-minute reminder with a fake clock
        var rest = RestNudge()
        try check(!rest.action(at: 0) && !rest.action(at: 600) && !rest.action(at: 1800), "no reminder in the first 45 minutes")
        var rest2 = RestNudge(); var t = 0.0, fired = 0
        while t <= 50 * 60 { if rest2.action(at: t) { fired += 1 }; t += 120 }   // an action every 2 minutes
        try check(fired == 1, "exactly one reminder per stretch, at 45 minutes (got \(fired))")
        var rest3 = RestNudge(); _ = rest3.action(at: 0); _ = rest3.action(at: 40 * 60)
        try check(!rest3.action(at: 40 * 60 + 400) && !rest3.action(at: 40 * 60 + 400 + 2400), "a break of 5+ minutes starts a new stretch")
        let old = PlayerData(now: t0, day: 0), oldJSON = try JSONEncoder().encode(old)
        var dict = try JSONSerialization.jsonObject(with: oldJSON) as! [String: Any]; dict.removeValue(forKey: "realTable"); dict.removeValue(forKey: "examKeysMigrated")
        let decoded = try JSONDecoder().decode(PlayerData.self, from: JSONSerialization.data(withJSONObject: dict))
        try check(decoded.realTable.isEmpty && !decoded.examKeysMigrated, "files from ≤ 0.49 decode with the new fields empty")
        print("PASS PlayerStore: \(checks) checks (round trip, .bak recovery, legacy stars → ids, streak/level/record, usage, 0.47 rounds/tests/tips)")
    }
}
