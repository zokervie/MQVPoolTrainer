import Foundation

// 0.58 T1–T4: auto-advance policy, achievement record + history, medal tiers, match tally.
@main enum AchievementsTests {
    static var checks = 0
    static func check(_ ok: Bool, _ msg: String) { checks += 1; if !ok { print("FAIL: \(msg)"); exit(1) } }
    static func attempt(_ stars: Int, _ percent: Int = 10, undo: Int = 0, run: Int = 2) -> AchievementAttempt {
        AchievementAttempt(stars: stars, percent: percent, undoUsed: undo, usedPowerBar: false, longestRun: run, seconds: 40, date: 1_700_000_000)
    }
    static func main() {
        // T1
        check(AutoAdvance.decide(stars: 3, nextRingOpen: true, chapterFinished: false) == .autoNext(after: 1.5), "3 stars and an open next ring: auto-start after 1.5 s")
        check(AutoAdvance.decide(stars: 2, nextRingOpen: true, chapterFinished: false) == .hold, "fewer than 3 stars: stay on the card")
        check(AutoAdvance.decide(stars: 3, nextRingOpen: false, chapterFinished: false) == .hold, "no open next ring: stay")
        check(AutoAdvance.decide(stars: 3, nextRingOpen: false, chapterFinished: true) == .chapterEnd && AutoAdvance.decide(stars: 3, nextRingOpen: true, chapterFinished: true) == .chapterEnd, "end of the chapter: the medal card")
        // T3
        let expected: [MedalTier] = [.wood, .wood, .bronze, .bronze, .silver, .silver, .gold, .gold, .platinum, .diamond]
        check((0...9).map { MedalTier.forTitle($0) } == expected, "title 0–1 wood · 2–3 bronze · 4–5 silver · 6–7 gold · 8 platinum · 9 diamond")
        check(MedalTier.forTitle(-4) == .wood && MedalTier.forTitle(77) == .diamond, "out of range is clamped")
        check(MedalTier.allCases.filter { $0.animated } == [.diamond], "only the diamond is animated")
        // T2
        var book = AchievementBook()
        check(book.record("ring-a", attempt(2)), "the first attempt is the best")
        check(!book.record("ring-a", attempt(1)) && book.best("ring-a")?.stars == 2, "a worse attempt does not replace the best")
        check(book.record("ring-a", attempt(3, 5)) && book.best("ring-a")?.stars == 3, "more stars replace it")
        check(book.record("ring-a", attempt(3, 9)) && !book.record("ring-a", attempt(3, 9, undo: 4)), "same stars: higher percent wins; same percent with more take-backs does not")
        for i in 0..<30 { book.record("ring-b", attempt(1, i)) }
        check(book.entries["ring-b"]?.history.count == 20 && book.entries["ring-b"]?.history.first?.percent == 10, "history keeps the latest 20")
        let data = try! JSONEncoder().encode(book)
        check(try! JSONDecoder().decode(AchievementBook.self, from: data) == book, "round-trips through JSON")
        check(book.best("missing") == nil, "unknown key has no record")
        // T4
        var tally = MatchTally()
        tally.record(.machine(level: 2), won: true); tally.record(.machine(level: 2), won: false); tally.record(.machine(level: 5), won: true)
        tally.record(.people, won: true); tally.record(.online, won: false)
        check(tally.machine[2] == MatchTally.Record(won: 1, lost: 1) && tally.people.won == 1 && tally.online.lost == 1, "kept apart: machine (by level) · people · online")
        check(tally.summary.played == 5 && tally.summary.won == 3 && tally.summary.lost == 2 && tally.summary.percent == 60, "one total line")
        check(MatchTally().summary.percent == 0, "no matches: 0 %")
        print("PASS Achievements: \(checks) checks")
    }
}
