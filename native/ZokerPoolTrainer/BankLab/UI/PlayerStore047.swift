import Foundation

/// 0.45 M5.1 — the player's progress, in ONE file: Application Support/Player/player.json (`schemaVersion`).
/// Single writer: only PlayerStore's methods mutate `data`; screens read (`data`, `stars`, `streakShown`…).
/// Atomic write; before each write the last good file is kept as `player.json.bak`. A file that does not decode is
/// set aside as `player.json.corrupt` and the `.bak` is restored, so a crash mid-write or a bad file never wipes the
/// player's history. Streak / level / record rules come from DailyLoop.h (shared with Tests/DailyLoopTests.cpp).
/// Foundation + DailyLoop.h only: Tests/PlayerStoreTests.swift (Tools/run_lan_checks.sh).

/// One shot on a drill.
struct DrillAttempt: Codable, Equatable {
    var drill: String      // stable id (DrillIDs), never the title
    var at: Date
    var day: Int64         // local calendar day (BLDayIndex) when it was played
    var made: Bool
    var stars: Int         // stars of the 5-shot round this shot closed (0 if it did not close one)
    var seconds: Double    // time spent on this attempt (since the drill was opened / the previous attempt), ≤ 600
}

/// Local usage numbers (never sent anywhere; Tuỳ chỉnh → Máy → "Sao chép số liệu sử dụng" lets a tester paste them).
struct UsageMetrics: Codable, Equatable {
    var installedAt: Date
    var installDay: Int64
    var openDays: [Int64] = []     // distinct local days the app was opened (sorted)
    var sessions = 0
    var shots = 0
    var drillsCompleted = 0        // finished 5-shot rounds
    init(installedAt: Date, installDay: Int64) { self.installedAt = installedAt; self.installDay = installDay }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        installedAt = try c.decode(Date.self, forKey: .installedAt); installDay = try c.decode(Int64.self, forKey: .installDay)
        openDays = try c.decodeIfPresent([Int64].self, forKey: .openDays) ?? []
        sessions = try c.decodeIfPresent(Int.self, forKey: .sessions) ?? 0
        shots = try c.decodeIfPresent(Int.self, forKey: .shots) ?? 0
        drillsCompleted = try c.decodeIfPresent(Int.self, forKey: .drillsCompleted) ?? 0
    }
}

struct StreakRecord: Codable, Equatable {
    var count: Int32, best: Int32, lastDay: Int64, freezes: Int32, freezeWeek: Int64, freezesUsed: Int32
    init(_ s: BLStreak) { count = s.count; best = s.best; lastDay = s.lastDay; freezes = s.freezes; freezeWeek = s.freezeWeek; freezesUsed = s.freezesUsed }
    var c: BLStreak { BLStreak(count: count, best: best, lastDay: lastDay, freezes: freezes, freezeWeek: freezeWeek, freezesUsed: freezesUsed) }
}

/// 0.47: one finished 5-shot round (Bài hôm nay "đã xong", màn Tiến bộ).
struct RoundLog: Codable, Equatable {
    var drill: String
    var day: Int64
    var stars: Int
    var made: Int
    var average: Double
}
/// 0.47 M0/M5: a 10-shot test without help (chapter exam or the weekly "Bài kiểm không trợ giúp").
struct TestLog: Codable, Equatable {
    var kind: String       // "chapter-<n>" or "weekly"
    var day: Int64
    var made: Int
    var shots: Int
}

/// 0.49b X7: one set of 10 shots on a real table, typed in by the player ("Ra bàn thật").
struct RealTableLog: Codable, Equatable { var day: Int64; var made: Int }

struct PlayerData: Codable, Equatable {
    static let currentSchema = 1
    var schemaVersion = PlayerData.currentSchema
    var attempts: [DrillAttempt] = []
    var stars: [String: Int] = [:]          // drill id → best stars (0…5)
    var bestAverage: [String: Double] = [:] // drill id → best 5-shot average score (personal record)
    var streak = StreakRecord(BLStreakNew())
    var level: Int32 = 1
    var metrics: UsageMetrics
    var legacyStarsMigrated = false
    // 0.47 (all optional in the file: older files decode with empty values)
    var rounds: [RoundLog] = []
    var tests: [TestLog] = []
    var examBest: [String: Int] = [:]   // "chapter-<n>" → best made out of 10 (a full exam only)
    var tipsSeen: [Int] = []            // chapters whose tip card was shown once
    // 0.49b
    var examKeysMigrated = false        // "chapter-<n>" exam keys moved to BLDrillChapterKey names (X1)
    var realTable: [String: [RealTableLog]] = [:]   // drill id → tries on a real table (X7), oldest first

    init(now: Date, day: Int64) { metrics = UsageMetrics(installedAt: now, installDay: day) }
    // Missing fields (older / newer files) fall back to defaults instead of failing the whole file.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        attempts = try c.decodeIfPresent([DrillAttempt].self, forKey: .attempts) ?? []
        stars = try c.decodeIfPresent([String: Int].self, forKey: .stars) ?? [:]
        bestAverage = try c.decodeIfPresent([String: Double].self, forKey: .bestAverage) ?? [:]
        streak = try c.decodeIfPresent(StreakRecord.self, forKey: .streak) ?? StreakRecord(BLStreakNew())
        level = try c.decodeIfPresent(Int32.self, forKey: .level) ?? 1
        metrics = try c.decode(UsageMetrics.self, forKey: .metrics)
        legacyStarsMigrated = try c.decodeIfPresent(Bool.self, forKey: .legacyStarsMigrated) ?? false
        rounds = try c.decodeIfPresent([RoundLog].self, forKey: .rounds) ?? []
        tests = try c.decodeIfPresent([TestLog].self, forKey: .tests) ?? []
        examBest = try c.decodeIfPresent([String: Int].self, forKey: .examBest) ?? [:]
        tipsSeen = try c.decodeIfPresent([Int].self, forKey: .tipsSeen) ?? []
        examKeysMigrated = try c.decodeIfPresent(Bool.self, forKey: .examKeysMigrated) ?? false
        realTable = try c.decodeIfPresent([String: [RealTableLog]].self, forKey: .realTable) ?? [:]
    }
}

final class PlayerStore {
    /// The app's store (Application Support). Tests make their own with a temporary directory.
    static let shared: PlayerStore = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Player")
        #if DEBUG
        // QA (UI test "fresh install"): start from an empty progress file. Debug builds only.
        if ProcessInfo.processInfo.arguments.contains("--fresh-player-qa") { try? FileManager.default.removeItem(at: dir) }
        #endif
        return PlayerStore(directory: dir)
    }()
    static let maxAttempts = 2000
    static let maxAttemptSeconds = 600.0
    static let maxRounds = 1000, maxTests = 300

    let fileURL: URL
    var backupURL: URL { fileURL.appendingPathExtension("bak") }
    var corruptURL: URL { fileURL.appendingPathExtension("corrupt") }
    private(set) var data: PlayerData
    /// How the last load went: "new", "file", "restored-from-bak", "reset-unreadable".
    private(set) var loadSource = "new"
    private(set) var lastWriteError: String?
    var timeZone: TimeZone = .current
    private var clock: (drill: String, at: Date)?

    init(directory: URL, now: Date = Date(), timeZone: TimeZone = .current) {
        self.timeZone = timeZone
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("player.json")
        data = PlayerData(now: now, day: Self.day(now, timeZone))
        load(now: now)
    }

    static func day(_ date: Date, _ tz: TimeZone) -> Int64 {
        BLDayIndex(Int64(floor(date.timeIntervalSince1970)), Int32(tz.secondsFromGMT(for: date)))
    }
    func day(_ date: Date) -> Int64 { Self.day(date, timeZone) }

    // MARK: file
    private func decode(_ url: URL) -> PlayerData? {
        guard let bytes = try? Data(contentsOf: url) else { return nil }
        let d = JSONDecoder(); d.dateDecodingStrategy = .secondsSince1970
        return try? d.decode(PlayerData.self, from: bytes)
    }
    private func load(now: Date) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            if let bak = decode(backupURL) { data = bak; loadSource = "restored-from-bak"; save() }   // main lost mid-write
            return
        }
        if let main = decode(fileURL) { data = main; loadSource = "file"; return }
        // Unreadable: set it aside (never silently overwritten), then fall back to the last good copy.
        try? fm.removeItem(at: corruptURL); try? fm.copyItem(at: fileURL, to: corruptURL)
        if let bak = decode(backupURL) { data = bak; loadSource = "restored-from-bak" }
        else { loadSource = "reset-unreadable" }
        writeFile(keepBackup: false)   // the corrupt file must not become the next .bak
    }
    private func save() { writeFile(keepBackup: true) }
    private func writeFile(keepBackup: Bool) {
        let e = JSONEncoder(); e.dateEncodingStrategy = .secondsSince1970; e.outputFormatting = [.sortedKeys]
        do {
            let bytes = try e.encode(data)
            let fm = FileManager.default
            if keepBackup, fm.fileExists(atPath: fileURL.path) {
                try? fm.removeItem(at: backupURL); try? fm.copyItem(at: fileURL, to: backupURL)
            }
            try bytes.write(to: fileURL, options: .atomic)
            lastWriteError = nil
        } catch { lastWriteError = "\(error)" }
    }

    // MARK: writes (the only place progress changes)
    /// Once per install: stars saved by title (`lessonStars035`, ≤ 0.46) move to the stable ids, keeping the best of
    /// both. Titles not in the table keep their stars under "title:<title>" (nothing is dropped).
    @discardableResult func migrateLegacyStars(_ legacy: [String: Int]) -> Int {
        guard !data.legacyStarsMigrated else { return 0 }
        var moved = 0
        for (title, stars) in legacy {
            let id = DrillIDs.idForTitle[title] ?? "title:" + title
            let s = max(0, min(5, stars))
            if s > (data.stars[id] ?? 0) { data.stars[id] = s }
            moved += 1
        }
        data.legacyStarsMigrated = true
        save()
        return moved
    }
    /// App launch or return after ≥ 30 min in the background.
    func noteSession(at now: Date = Date()) {
        data.metrics.sessions += 1
        let today = day(now)
        if data.metrics.openDays.last != today && !data.metrics.openDays.contains(today) {
            data.metrics.openDays.append(today); data.metrics.openDays.sort()
        }
        save()
    }
    /// A drill was opened: its attempt clock starts now.
    func noteDrillOpened(_ drill: String, at now: Date = Date()) { clock = (drill, now) }
    /// Any shot that finished (practice or match): usage counter. `attempt` = the shot counted on a drill.
    func recordShot(drill: String?, made: Bool, at now: Date = Date()) {
        data.metrics.shots += 1
        if let drill = drill {
            var seconds = 0.0
            if let c = clock, c.drill == drill { seconds = min(Self.maxAttemptSeconds, max(0, now.timeIntervalSince(c.at))) }
            clock = (drill, now)
            data.attempts.append(DrillAttempt(drill: drill, at: now, day: day(now), made: made, stars: 0, seconds: seconds))
            if data.attempts.count > Self.maxAttempts { data.attempts.removeFirst(data.attempts.count - Self.maxAttempts) }
        }
        save()
    }
    struct RoundResult: Equatable { var newBestStars: Bool; var newRecord: Bool; var streakGrew: Bool; var level: Int32 }
    /// A 5-shot round finished: best stars, personal record (average), streak day, level from the last 7 days.
    @discardableResult func recordRound(drill: String, stars: Int, average: Double, made: Int = -1, at now: Date = Date()) -> RoundResult {
        let s = max(0, min(5, stars))
        data.rounds.append(RoundLog(drill: drill, day: day(now), stars: s, made: made < 0 ? min(4, s) : max(0, min(5, made)), average: average))
        if data.rounds.count > Self.maxRounds { data.rounds.removeFirst(data.rounds.count - Self.maxRounds) }
        let newBest = s > (data.stars[drill] ?? 0)
        if newBest { data.stars[drill] = s }
        let previous = data.bestAverage[drill]
        let record = BLIsNewRecord(previous == nil ? 0 : 1, previous ?? 0, average, 1, 0.5) != 0
        if previous == nil || average > previous! { data.bestAverage[drill] = average }
        if let i = data.attempts.lastIndex(where: { $0.drill == drill }) { data.attempts[i].stars = s }
        let today = day(now)
        var st = data.streak.c
        let grew = BLStreakComplete(&st, today) != 0
        data.streak = StreakRecord(st)
        let recent = data.attempts.filter { $0.day > today - 7 && $0.day <= today }
        data.level = BLNextLevel(data.level, Int32(recent.count), Int32(recent.filter { $0.made }.count))
        data.metrics.drillsCompleted += 1
        save()
        return RoundResult(newBestStars: newBest, newRecord: record, streakGrew: grew, level: data.level)
    }

    /// 0.47 M0/M5: a 10-shot test finished. Chapter exams keep the best made of a FULL exam (10 shots); the weekly test
    /// is a log (the "real progress" line on the Tiến bộ screen). Returns true if the chapter best improved.
    @discardableResult func recordTest(kind: String, made: Int, shots: Int, at now: Date = Date()) -> Bool {
        let m = max(0, min(shots, made))
        data.tests.append(TestLog(kind: kind, day: day(now), made: m, shots: shots))
        if data.tests.count > Self.maxTests { data.tests.removeFirst(data.tests.count - Self.maxTests) }
        var improved = false
        if kind != "weekly", shots == 10, m > (data.examBest[kind] ?? -1) { data.examBest[kind] = m; improved = true }
        save()
        return improved
    }
    /// 0.49b X1: once per install, exam bests saved under "chapter-<n>" move to the catalogue's chapter keys (max of the sources).
    func migrateLegacyExamKeys() {
        guard !data.examKeysMigrated else { return }
        for (old, new) in DrillIDs.legacyExamKeys {
            guard let best = data.examBest.removeValue(forKey: old) else { continue }
            for key in new { data.examBest[key] = max(data.examBest[key] ?? 0, best) }
        }
        data.examKeysMigrated = true; save()
    }
    static let maxRealTable = 50
    /// 0.49b X7: tries on a real table for one drill (made out of 10), the last `maxRealTable` kept.
    func recordRealTable(drill: String, made: Int, at now: Date = Date()) {
        var list = data.realTable[drill] ?? []
        list.append(RealTableLog(day: day(now), made: max(0, min(10, made))))
        if list.count > Self.maxRealTable { list.removeFirst(list.count - Self.maxRealTable) }
        data.realTable[drill] = list; save()
    }
    func realTable(_ drill: String) -> [RealTableLog] { data.realTable[drill] ?? [] }
    /// 0.47 M0: the chapter's tip card has been shown (it then lives in "Sổ mẹo").
    func markTipSeen(_ chapter: Int) {
        guard !data.tipsSeen.contains(chapter) else { return }
        data.tipsSeen.append(chapter); data.tipsSeen.sort(); save()
    }
    #if DEBUG
    /// QA (`--progress-demo-qa`): replace the progress with 30 days of made-up practice so the Tiến bộ screen can be
    /// photographed. Debug builds only; never called otherwise.
    func loadDemo(days: Int = 30, drills: [String], now: Date = Date()) {
        let today = day(now)
        var rng = SystemRandomNumberGenerator()
        var demo = PlayerData(now: now.addingTimeInterval(-Double(days) * 86400), day: today - Int64(days))
        var st = BLStreakNew()
        for back in stride(from: days - 1, through: 0, by: -1) {
            let d = today - Int64(back)
            if back % 9 == 5 { continue }   // a few missed days (freeze / reset visible on the chart)
            let skill = 0.35 + 0.45 * Double(days - back) / Double(days)
            for k in 0..<3 {
                let id = drills[(Int(d) + k) % max(1, drills.count)]
                var made = 0
                for s in 0..<5 {
                    let ok = Double.random(in: 0..<1, using: &rng) < skill; if ok { made += 1 }
                    demo.attempts.append(DrillAttempt(drill: id, at: now.addingTimeInterval(-Double(back) * 86400 + Double(k * 300 + s * 40)), day: d, made: ok, stars: 0, seconds: 40))
                }
                let stars = min(4, made)
                demo.rounds.append(RoundLog(drill: id, day: d, stars: stars, made: made, average: Double(made) * 18 + 8))
                demo.stars[id] = max(demo.stars[id] ?? 0, stars)
                demo.bestAverage[id] = max(demo.bestAverage[id] ?? 0, Double(made) * 18 + 8)
            }
            _ = BLStreakComplete(&st, d)
            if back % 7 == 0 { demo.tests.append(TestLog(kind: "weekly", day: d, made: Int((skill * 10).rounded()), shots: 10)) }
        }
        demo.streak = StreakRecord(st); demo.level = 3; demo.legacyStarsMigrated = true
        demo.metrics.sessions = 41; demo.metrics.shots = demo.attempts.count; demo.metrics.drillsCompleted = demo.rounds.count
        data = demo; save()
    }
    #endif

    // MARK: reads
    /// Rounds finished today (local day) on a drill — "Bài hôm nay" ticks.
    func roundsToday(_ drill: String, at now: Date = Date()) -> Int { let t = day(now); return data.rounds.filter { $0.drill == drill && $0.day == t }.count }
    /// Weekly test already taken this week?
    func weeklyTestDone(at now: Date = Date()) -> Bool { let w = BLWeekIndex(day(now)); return data.tests.contains { $0.kind == "weekly" && BLWeekIndex($0.day) == w } }
    /// Per local day over the last `days` days (oldest first): attempts and made.
    func daily(days: Int, at now: Date = Date()) -> [(day: Int64, attempts: Int, made: Int, rounds: Int)] {
        let today = day(now)
        return (0..<days).reversed().map { back in
            let d = today - Int64(back)
            let a = data.attempts.filter { $0.day == d }
            return (d, a.count, a.filter { $0.made }.count, data.rounds.filter { $0.day == d }.count)
        }
    }
    func stars(_ drill: String) -> Int { data.stars[drill] ?? 0 }
    func streakShown(at now: Date = Date()) -> Int32 { BLStreakShown(data.streak.c, day(now)) }

    /// Plain-text usage report for testers (D1/D7: opened on the day after / a week after install).
    func usageReport(at now: Date = Date(), extra: [String] = []) -> String {
        let m = data.metrics, today = day(now)
        let f = ISO8601DateFormatter(); f.timeZone = timeZone; f.formatOptions = [.withFullDate]
        var lines = ["Zoker Pool usage (local, never sent)",
                     "installed: " + f.string(from: m.installedAt) + " (day \(m.installDay))",
                     "days since install: \(today - m.installDay)",
                     "days opened: \(m.openDays.count)",
                     "D1 opened: " + (m.openDays.contains(m.installDay + 1) ? "yes" : "no"),
                     "D7 opened: " + (m.openDays.contains(m.installDay + 7) ? "yes" : "no"),
                     "sessions: \(m.sessions)",
                     "shots: \(m.shots)",
                     "drill rounds completed: \(m.drillsCompleted)",
                     "drill attempts kept: \(data.attempts.count)",
                     "streak: \(streakShown(at: now)) (best \(data.streak.best))",
                     "level: \(data.level)",
                     "open days: " + m.openDays.map { String($0 - m.installDay) }.joined(separator: ",")]
        lines += extra
        return lines.joined(separator: "\n")
    }
}
