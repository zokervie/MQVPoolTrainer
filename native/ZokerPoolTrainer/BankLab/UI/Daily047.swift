import UIKit

/// 0.47 M2 — Bài hôm nay + chuỗi ngày. Three drills a day picked by BLDailyPickMixed (DailyLoop.h: day seed + level
/// from the last 7 days, different kinds interleaved, only drills the player can open). Streak rules: DailyLoop.h
/// (BLStreakComplete / BLStreakShown, weekly freeze), written by PlayerStore.recordRound. Swift only draws.
enum DailyDrills {
    /// Drill.all indices of today's three (easiest first).
    static func today(_ s: PlayerStore = .shared, at now: Date = Date()) -> [Int] {
        let pool: [Int] = FeatureFlags.chapters
            ? Chapters.all.flatMap { $0.drills }.compactMap { Chapters.index(of: $0) }
            : Drill.all.indices.filter { Drill.all[$0].level > 0 }
        guard !pool.isEmpty else { return [] }
        let openChapters = Chapters.openChapters(s)
        let stars = pool.map { i -> Int32 in
            let id = Drill.all[i].id
            // Brief: only from OPEN CHAPTERS (rung order is for the ladder; daily practice may mix the rungs).
            let open = !FeatureFlags.chapters || Chapters.locate(id).map { openChapters[$0.chapter - 1] } ?? true
            return open && Mastery.ringOpen(id) ? (Chapters.stars(id) > 0 ? Chapters.stars(id) : 3) : 0
        }
        let kinds = pool.map { Chapters.kind(Drill.all[$0].id).rawValue }
        var out = [Int32](repeating: 0, count: Int(BL_DAILY_COUNT))
        let n = BLDailyPickMixed(s.day(now), s.data.level, stars, kinds, Int32(pool.count), &out)
        return out.prefix(Int(n)).map { pool[Int($0)] }
    }
    static func done(_ index: Int, _ s: PlayerStore = .shared, at now: Date = Date()) -> Bool { s.roundsToday(Drill.all[index].id, at: now) > 0 }
    /// Next of today's drills not finished yet.
    static func nextUndone(_ s: PlayerStore = .shared, at now: Date = Date()) -> Int? { today(s, at: now).first { !done($0, s, at: now) } }
}

extension TrainingController {
    /// "Bài hôm nay" card for the Lobby (nil when the flag is off or nothing is open).
    func dailyCard() -> LobbyController.Daily? {
        guard FeatureFlags.dailyDrill else { return nil }
        let picks = DailyDrills.today()
        guard !picks.isEmpty else { return nil }
        let items = picks.map { (title: Drill.all[$0].title, done: DailyDrills.done($0)) }
        let left = items.filter { !$0.done }.count
        let streak = Int(PlayerStore.shared.streakShown())
        let subtitle = left == 0 ? "Xong cả 3 bài hôm nay · hẹn mai" : "\(left)/\(items.count) bài còn lại · 5–8 phút"
        return .init(title: "Bài hôm nay", subtitle: subtitle, streak: streak, items: items, run: { [weak self] in
            guard let self = self, !self.shotActive, self.replayIndex == nil, self.localTurn else { return }
            self.setMenu(false)
            self.beginDrill(DailyDrills.nextUndone() ?? picks[0], guided: false)
        })
    }
}
