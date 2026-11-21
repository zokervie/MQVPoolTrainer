import Foundation

/// 0.45 M5.2 — stable drill ids. Progress used to be keyed by the Vietnamese title (`lessonStars035`): renaming or
/// translating a title lost the stars. Every `Drill` now carries an `id` that NEVER changes (rename the title freely,
/// never the id; a new drill gets a new id). The table maps the titles that existed when ids were introduced, so the
/// one-time migration of `lessonStars035` (PlayerStore.migrateLegacyStars) finds them.
/// Foundation only: Tests/PlayerStoreTests.swift (Tools/run_lan_checks.sh).
enum DrillIDs {
    /// Title (Vietnamese source, as of 0.47) → stable id. Order = `Drill.all` order.
    static let byTitle: [(title: String, id: String)] = [
        ("Tự do", "tool-free"),
        ("Đo độ lăn", "tool-roll"),
        ("Đo độ nảy", "tool-bounce"),
        ("Kick 1 băng · Gương A", "kick1-mirror-a"),
        ("Stop · Giữ bi cái", "stop-hold"),
        ("Cu-lê · Theo vào vùng", "follow-zone"),
        ("Trô · Lùi vào vùng", "draw-zone"),
        ("Cắt phải 30° vào lỗ góc", "cut-30-r"),
        ("Cắt trái 45° vào lỗ góc", "cut-45-l"),
        ("Lực 1/3 · Dừng đúng vùng", "speed-1"),
        ("Lực 2/3 · Dừng đúng vùng", "speed-2"),
        ("Lực 3/3 · Dừng đúng vùng", "speed-3"),
        ("Kick 1 băng · Gương B", "kick1-mirror-b"),
        ("Kick 1 băng · Thoát bi cản", "kick1-blocker"),
        ("Kick 1 băng · Bi cản xa", "kick1-blocker-far"),
        ("Kick 2 băng · Gương kép", "kick2-double-mirror"),
        ("Kick 2 băng · Thoát bi cản", "kick2-blocker"),
        ("Kick 3 băng · Corner-5", "kick3-corner5"),
        ("Kick 3 băng · Bi cản giữa bàn", "kick3-blocker-mid"),
        ("Kick 3 băng · Bi cản cao", "kick3-blocker-high"),
        ("Bank 1 băng", "bank1"),
        ("Bank 2 băng", "bank2"),
        ("Kick 2 băng · Hệ Plus", "kick2-plus"),
        ("Bank 3 băng", "bank3"),
        ("Kick 4 băng", "kick4"),
        ("Trick · Combo dính", "trick-combo"),
        ("Trick · Jump qua bi cản", "trick-jump"),
        ("Trick · Massé vòng bi cản", "trick-masse"),
        ("Trick · Kick 3 băng thoát cụm", "trick-kick3-cluster"),
        ("Trick · Reverse bank zigzag", "trick-reverse-zigzag"),
        ("Cú đầu tiên", "first-shot"),
    ]
    /// 0.49b: drills that came with the catalogue (BLDrillTable), appended after `byTitle` — challenge codes number a drill
    /// by its position in `challengeIDs`, so this list is append-only too.
    static let catalogExtra: [String] = ["cut-side-30", "cut-15-r", "cut-60-r", "cue-path-30", "cue-path-90", "cue-path-2rail",
                                         "pos-stop", "pos-follow", "pos-draw", "bank-cross-side", "safe-behind", "safe-tuck"]
    static let challengeIDs: [String] = byTitle.map { $0.id } + catalogExtra
    /// 0.49b X1: chapter exams used to be saved as "chapter-<n>" (0.47 chapter numbers); the catalogue's chapters have stable
    /// keys (BLDrillChapterKey). Old best score moves to the new key(s) of the same material, once (PlayerStore.migrateLegacyExamKeys).
    /// "chapter-4" (Đường bi cái, never had drills) is dropped.
    static let legacyExamKeys: [(old: String, new: [String])] = [
        ("chapter-1", ["straight-speed", "stop-follow-draw"]), ("chapter-2", ["straight-speed"]), ("chapter-3", ["cut"]),
        ("chapter-4", []), ("chapter-5", ["kick", "bank"]), ("chapter-6", ["special"])]
    static let idForTitle: [String: String] = Dictionary(uniqueKeysWithValues: byTitle.map { ($0.title, $0.id) })
    /// Id for a drill title. A title missing from the table (a drill added later without an id) gets a derived id so
    /// nothing crashes; DEBUG builds assert so the table is kept complete.
    static func id(forTitle title: String) -> String {
        if let id = idForTitle[title] { return id }
        assertionFailure("DrillIDs: add a stable id for \"\(title)\"")
        return "title:" + title
    }
}
