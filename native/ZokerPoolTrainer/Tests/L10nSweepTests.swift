import Foundation

/// 0.59 (owner, video bản 202): every Vietnamese literal of the app (Tools/i18n/sweep_literals.py) goes through the real
/// translation core in English; any Vietnamese letter left in the result is a leak. Also checks the core on the exact
/// strings of the owner's video. Built by Tools/run_lan_checks.sh with L10nCore059.swift + L10nTable059.swift.
/// Arguments: <i18n_en.json> <literals.json> <allow.txt>
enum L10n {}

@main struct L10nSweepMain {
    static func main() {
        var failures = 0
            func check(_ ok: Bool, _ what: String) { if !ok { failures += 1; print("FAIL \(what)") } }

        let args = CommandLine.arguments
        let en = (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[1])))) as? [String: String] ?? [:]
        var dict = en
        for (k, row) in L10n.table where dict[k] == nil && !row.isEmpty { dict[k] = row[0] }
        let cat = L10nCatalog(dict)
            func tr(_ s: String) -> String { L10nCore.translate(s, cat) }

        // The owner's video (bản 202) — exact screen strings
        check(tr("Mã 561634 · Đang đồng bộ lượt… · Đã nối Zokervie 5E4F · Khách") == "Code 561634 · Syncing the turn… · Connected to Zokervie 5E4F · Guest", "LAN status: \(tr("Mã 561634 · Đang đồng bộ lượt… · Đã nối Zokervie 5E4F · Khách"))")
        check(tr("KẾT THÚC VÁN 1 · RACE 5") == "END OF RACK 1 · RACE 5", "card kicker caps: \(tr("KẾT THÚC VÁN 1 · RACE 5"))")
        check(tr("Kết thúc ván 1 · Race 5") == "End of rack 1 · Race 5", "card kicker: \(tr("Kết thúc ván 1 · Race 5"))")
        check(tr("NGƯỜI 1") == "PLAYER 1", "caps name: \(tr("NGƯỜI 1"))")
        check(tr("Người 2 thắng ván · ván mới sau giây lát") == "Player 2 wins the rack · next rack in a moment", "rack end: \(tr("Người 2 thắng ván · ván mới sau giây lát"))")
        check(tr("Tạo phòng") == "Create room", "create room: \(tr("Tạo phòng"))")
        check(tr("Tìm phòng") == "Find room", "find room: \(tr("Tìm phòng"))")
        check(L10nCore.vietnameseCount(tr("9 Ball · Mã 561634 · Lượt bạn")) == 0, "status line: \(tr("9 Ball · Mã 561634 · Lượt bạn"))")
        // the core itself
        check(tr("Đặt bi") == "Place ball", "exact")
        check(tr("Đặt bi…") == "Place ball…", "trailing ellipsis")
        check(tr("Hello · 3") == "Hello · 3", "non-Vietnamese text untouched")

        // Sweep
        let allow = Set(((try? String(contentsOfFile: args[3], encoding: .utf8)) ?? "").split(separator: "\n").map { String($0) }.filter { !$0.hasPrefix("#") && !$0.isEmpty })
        let items = (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[2])))) as? [[String: Any]] ?? []
        var leaks: [(String, String, String)] = []
        for it in items {
            let s = it["text"] as? String ?? "", file = "\(it["file"] ?? ""):\(it["line"] ?? "")"
            let out = tr(s)
            if L10nCore.vietnameseCount(out) > 0, !allow.contains(s.replacingOccurrences(of: "\n", with: "\\n")) { leaks.append((file, s, out)) }
        }
        for (f, s, o) in leaks.prefix(400) { print("LEAK \(f): \(s.replacingOccurrences(of: "\n", with: "⏎")) → \(o.replacingOccurrences(of: "\n", with: "⏎"))") }
        print("REPORT l10n sweep: \(items.count) Vietnamese literals, \(leaks.count) still Vietnamese in English, catalog \(dict.count)")
        check(items.count > 300, "literal extraction found too little (\(items.count))")
        check(leaks.isEmpty, "\(leaks.count) literals leak Vietnamese into the English app")
        print(failures == 0 ? "PASS L10nSweepTests" : "FAIL L10nSweepTests (\(failures))")
        exit(failures == 0 ? 0 : 1)

    }
}
