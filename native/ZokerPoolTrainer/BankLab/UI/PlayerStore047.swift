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
    @discardableResult func recordRound(drill: String, stars: Int, average: Double, at now: Date = Date()) -> RoundResult {
        let s = max(0, min(5, stars))
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

    // MARK: reads
    func stars(_ drill: String) -> Int { data.stars[drill] ?? 0 }
    func streakShown(at now: Date = Date()) -> Int32 { BLStreakShown(data.streak.c, day(now)) }

    /// Plain-text usage report for testers (D1/D7: opened on the day after / a week after install).
    func usageReport(at now: Date = Date(), extra: [String] = []) -> String {
        let m = data.metrics, today = day(now)
        let f = ISO8601DateFormatter(); f.timeZone = timeZone; f.formatOptions = [.withFullDate]
        var lines = ["ZokerPoolTrainer usage (local, never sent)",
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
