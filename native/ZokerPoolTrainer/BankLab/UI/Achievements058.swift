import Foundation

/// 0.58 T1–T4 — pure, testable pieces of the achievements work (Foundation only: Tests/AchievementsTests.swift).
/// T1 auto-advance policy · T2 per-ring/per-chapter record with history · T3 medal tiers · T4 match tally split by opponent kind.

/// T1 — what the result card of a scored ring does next.
enum AutoAdvance {
    enum Decision: Equatable { case autoNext(after: Double), chapterEnd, hold }
    static let delay = 3.0
    /// 3 stars or more opens the next ring and starts it after 3 s unless the player taps; the last ring of a chapter shows the medal card instead.
    static func decide(stars: Int, nextRingOpen: Bool, chapterFinished: Bool) -> Decision {
        guard stars >= 3 else { return .hold }
        if chapterFinished { return .chapterEnd }
        return nextRingOpen ? .autoNext(after: delay) : .hold
    }
}

/// T3 — one medal per chapter = the chapter's title (BLTitleIndex 0…9), six materials of rising brilliance.
enum MedalTier: Int, CaseIterable {
    case wood, bronze, silver, gold, platinum, diamond
    static func forTitle(_ index: Int) -> MedalTier {
        switch max(0, min(9, index)) { case 0, 1: return .wood; case 2, 3: return .bronze; case 4, 5: return .silver; case 6, 7: return .gold; case 8: return .platinum; default: return .diamond }
    }
    /// vi names (translated through L10n by the UI).
    var title: String { ["Gỗ", "Đồng", "Bạc", "Vàng", "Bạch kim", "Kim cương"][rawValue] }
    /// Only the diamond is animated (light sweep); Reduce Motion turns it off.
    var animated: Bool { self == .diamond }
}

/// T2 — what is kept of one finished round of a ring (or one chapter exam).
struct AchievementAttempt: Codable, Equatable {
    var stars: Int, percent: Int, undoUsed: Int, usedPowerBar: Bool, longestRun: Int
    var seconds: Double      // recorded only: never decides a title
    var date: Double         // seconds since 1970
    /// "better" = more stars, then a higher chapter percent, then fewer take-backs.
    func beats(_ o: AchievementAttempt) -> Bool {
        if stars != o.stars { return stars > o.stars }
        if percent != o.percent { return percent > o.percent }
        return undoUsed < o.undoUsed
    }
}
struct AchievementEntry: Codable, Equatable { var best: AchievementAttempt?; var history: [AchievementAttempt] = [] }
struct AchievementBook: Codable, Equatable {
    static let historyLimit = 20
    var entries: [String: AchievementEntry] = [:]
    /// Returns true when this attempt is the new best of `key`. The history keeps the latest 20.
    @discardableResult mutating func record(_ key: String, _ a: AchievementAttempt) -> Bool {
        var e = entries[key] ?? AchievementEntry()
        let isBest = e.best.map { a.beats($0) } ?? true
        if isBest { e.best = a }
        e.history.append(a); if e.history.count > Self.historyLimit { e.history.removeFirst(e.history.count - Self.historyLimit) }
        entries[key] = e
        return isBest
    }
    func best(_ key: String) -> AchievementAttempt? { entries[key]?.best }
}

/// T4 — match numbers kept apart: against the machine (per level), against a person on one device / Wi-Fi, online. One summary line on top.
struct MatchTally: Codable, Equatable {
    struct Record: Codable, Equatable { var won = 0, lost = 0; var played: Int { won + lost } }
    var machine: [Int: Record] = [:]      // level 0…5
    var people = Record()                 // same device or Wi-Fi
    var online = Record()
    enum Kind: Equatable { case machine(level: Int), people, online }
    mutating func record(_ kind: Kind, won: Bool) {
        func bump(_ r: inout Record) { if won { r.won += 1 } else { r.lost += 1 } }
        switch kind { case .machine(let l): bump(&machine[l, default: Record()]); case .people: bump(&people); case .online: bump(&online) }
    }
    var total: Record { var t = people; t.won += online.won; t.lost += online.lost
        for r in machine.values { t.won += r.won; t.lost += r.lost }; return t }
    /// "12 ván · thắng 7 · thua 5 (58 %)" — wording in vi; the UI formats it through L10n.
    var summary: (played: Int, won: Int, lost: Int, percent: Int) { let t = total; return (t.played, t.won, t.lost, t.played == 0 ? 0 : (t.won * 100 + t.played / 2) / t.played) }
}
