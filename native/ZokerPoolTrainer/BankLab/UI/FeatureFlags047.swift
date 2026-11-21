import Foundation

/// 0.47 — every new feature of "Quay lại mỗi ngày" sits behind a flag so it can later be sold / unlocked per pack
/// (In-App Purchase) without touching the feature's code. Default ON for the test build. A flag is read where the
/// feature is entered (Lobby card, menu row, HUD control); switching one off hides the entry, never deletes data.
/// QA: `--ff-off-<name>` forces one off for a launch (Debug only, through `QA`). Foundation only: Tests/PrefsTests.swift.
enum FeatureFlags {
    enum Flag: String, CaseIterable {
        case chapters          // M0 Kho bài theo chương (thẻ mẹo, thang bài, thi chương)
        case powerBar          // M1 Thanh lực
        case dailyDrill        // M2 Bài hôm nay + chuỗi ngày
        case progress          // M3 Sao độ khó, màn Tiến bộ, Kỷ lục mới
        case playFX            // M4 Hiệu ứng khi chơi
        case fadingFeedback    // M5 Phản hồi giảm dần + bài kiểm tuần
        case challenge         // M6 Thách bạn bằng mã
        case drillCatalog      // 0.49b X1 Xưởng bài: kho bài đọc từ bảng C (tắt = danh sách Swift cũ)
    }
    static func isOn(_ f: Flag, _ d: UserDefaults = .standard) -> Bool {
        if QA.has("--ff-off-" + f.rawValue) { return false }
        return Prefs.flag(Prefs.featureFlag(f.rawValue), true, d)
    }
    static var chapters: Bool { isOn(.chapters) }
    static var powerBar: Bool { isOn(.powerBar) }
    static var dailyDrill: Bool { isOn(.dailyDrill) }
    static var progress: Bool { isOn(.progress) }
    static var playFX: Bool { isOn(.playFX) }
    static var fadingFeedback: Bool { isOn(.fadingFeedback) }
    static var challenge: Bool { isOn(.challenge) }
    static var drillCatalog: Bool { isOn(.drillCatalog) }

    /// M1: the power bar is the stroke input? Saved choice (Tuỳ chỉnh) wins; otherwise new players (< 50 shots) get
    /// the bar and players who already stroke with B keep the swipe (brief, "Mặc định khi không ai trả lời").
    static func usesPowerBar(shots: Int, _ d: UserDefaults = .standard) -> Bool {
        guard isOn(.powerBar, d) else { return false }
        if let saved = d.object(forKey: Prefs.powerBarMode) as? Int { return saved == 1 }
        return shots < 50
    }
}
