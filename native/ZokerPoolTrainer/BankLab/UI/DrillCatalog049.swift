import UIKit

/// 0.49b "Xưởng bài" X1/X6 — the drill catalogue read from C (DrillCatalog.h, generated table) and the texts that go with it.
/// Geometry, goal, judging rule, chapter, ladder order and MEASURED difficulty come from `BLDrillTable`; the texts live here
/// (Vietnamese source, English in I18N_en/i18n.json) keyed by the drill `key`, which is also `Drill.id` and never changes.
/// Switch: FeatureFlags.drillCatalog (default on; off = the ≤ 0.48 Swift list, `Drill.legacyAll`).
enum DrillCatalog {
    static func spec(_ key: String) -> BLDrillSpec? {
        let i = BLDrillIndex(key)
        return i >= 0 ? BLDrillAt(i)?.pointee : nil
    }
    static var count: Int { Int(BLDrillCount()) }
    static func key(at i: Int) -> String { BLDrillAt(Int32(i)).map { String(cString: $0.pointee.key) } ?? "" }

    /// Title and one-line note of drills that are new in 0.49b (older drills keep the text they had: titles never change).
    static let newText: [String: (title: String, note: String)] = [
        "cut-15-r": ("Cắt phải 15° vào lỗ góc", "Cắt dày: bi cái dễ theo vào lỗ, đánh hơi dưới tâm."),
        "cut-side-30": ("Cắt 30° vào lỗ giữa", "Lỗ giữa hẹp hơn: ngắm vào giữa miệng lỗ."),
        "cut-60-r": ("Cắt mỏng 60° vào lỗ góc", "Chạm rất mỏng: bi ma gần như cạnh bi 1."),
        "cue-path-30": ("Quy tắc 30° · Bi lăn", "Đánh trên tâm, lực vừa: bi cái lệch khoảng 30° rồi dừng trong vòng."),
        "cue-path-90": ("Quy tắc 90° · Bi trượt", "Cùng thế bi. Đánh chắc tay hơn để bi cái còn trượt khi chạm: nó đi theo đường 90°."),
        "cue-path-2rail": ("Cắt 45° · Bi cái 2 băng", "Bi 1 vào lỗ, bi cái chạm 2 băng rồi dừng trong vòng."),
        "pos-stop": ("Đi bi · Dừng lấy góc", "Ăn bi 1, bi cái dừng trong vòng: từ đó bi 2 có góc dễ vào lỗ giữa trái."),
        "pos-follow": ("Đi bi · Theo lấy góc", "Ăn bi 1, theo tới vòng: bi 2 cắt vào lỗ góc trên phải."),
        "pos-draw": ("Đi bi · Lùi lấy góc", "Ăn bi 1, lùi về vòng: bi 2 gần thẳng vào lỗ góc dưới trái."),
        "bank-cross-side": ("Bank chéo vào lỗ giữa", "Bi 1 chạm băng phải rồi chéo sang lỗ giữa trái."),
        "safe-behind": ("An toàn · Giấu sau bi cản", "Chạm bi 1 trước, không bi nào vào lỗ; cuối cú, bi 2 chắn giữa bi cái và bi 1."),
        "safe-tuck": ("An toàn · Đẩy bi 1 ra sau", "Như trên, bi cản ở phía xa."),
    ]
    /// One-line formula shown under "Xem thêm" for new drills (the chapter's extra line is the fallback).
    static let newSystem: [String: String] = [
        "cue-path-30": "Bi lăn (trên tâm) đi lệch khoảng 30° so với đường cơ sau khi chạm; bi trượt đi theo đường 90° (Dr. Dave Alciatore).",
        "cue-path-90": "Bi cái còn trượt khi chạm thì rời bi 1 theo đường vuông góc 90° với đường bi 1 đi (Dr. Dave Alciatore).",
        "safe-behind": "An toàn: thắng bằng thế bi, không cần vào lỗ. Chạm bi 1 trước rồi để bi cản chắn đường thẳng giữa bi cái và bi 1.",
        "safe-tuck": "Như \"Giấu sau bi cản\" nhưng bi cản ở xa hơn: lực nhẹ hơn, góc chạm quan trọng hơn."]

    struct ChapterText { let key: String; let title: String; let tip: String; let more: String; let source: String }
    /// Chapter texts by BLDrillChapterKey: title · one-line tip · extra line · source.
    static let chapterText: [String: ChapterText] = Dictionary(uniqueKeysWithValues: [
        ChapterText(key: "straight-speed", title: "Cú thẳng và lực", tip: "Lực là quãng lăn", more: "Gấp đôi quãng: lực chỉ cần ×1,4",
                    source: "Thang Lực 1–30 của app; bài stop / theo / lùi của Kinister và Dr. Dave Alciatore"),
        ChapterText(key: "stop-follow-draw", title: "Dừng – theo – lùi", tip: "Trên tâm theo, dưới tâm lùi", more: "Bi cái càng xa, xoáy dưới càng hao",
                    source: "Bài stop / theo / lùi của Kinister và Dr. Dave Alciatore"),
        ChapterText(key: "cut", title: "Ngắm cắt", tip: "Nửa bi = 30°", more: "Đánh chậm: cắt mỏng hơn một chút",
                    source: "Ngắm theo phần bi (hình học); độ ném đo trên vật lý của app"),
        ChapterText(key: "cue-path", title: "Đường bi cái", tip: "Bi trượt đi 90°, bi lăn lệch 30°", more: "Đánh chắc tay hơn, bi cái gần 90° hơn",
                    source: "Quy tắc 90° và 30° (Dr. Dave Alciatore)"),
        ChapterText(key: "position", title: "Đi bi", tip: "Ăn bi này, nghĩ bi sau", more: "Chừa một góc cắt nhẹ, đừng thẳng tuyệt đối",
                    source: "Đi bi theo thế (nguyên tắc chung); quãng dừng đo trên vật lý của app"),
        ChapterText(key: "kick", title: "Kick băng", tip: "Gương và số nút", more: "Corner-5: số bi cái − số đích = số ngắm",
                    source: "Gương 1 băng; Corner-5 (Walter Harris / Robert Byrne)"),
        ChapterText(key: "bank", title: "Bank", tip: "Góc vào bằng góc ra", more: "Bank mạnh về ngắn hơn, bank nhẹ về dài hơn",
                    source: "Hệ gương cho bank (Dr. Dave Alciatore, kick/bank FAQ)"),
        ChapterText(key: "safety", title: "An toàn", tip: "Chạm nhẹ, giấu bi", more: "Chạm bi 1 trước, không bi nào vào lỗ",
                    source: "Nguyên tắc an toàn trong pool (chung)"),
        ChapterText(key: "special", title: "Kỹ thuật đặc biệt", tip: "Dựng cơ: bi bay hoặc cong", more: "",
                    source: "Jump / massé (Dr. Dave Alciatore, TP 7.x)"),
    ].map { ($0.key, $0) })

    /// "Bank" does not block the chapters after it until the cushion physics is re-checked (0.49b D2, default).
    static let nonBlocking: Set<String> = ["bank"]

    static func chapters() -> [Chapter] {
        (1...Int(BL_DRILL_CHAPTERS)).map { n in
            let key = String(cString: BLDrillChapterKey(Int32(n)))
            var idx = [Int32](repeating: 0, count: 64)
            let c = Int(BLDrillChapterDrills(Int32(n), &idx, 64))
            let t = chapterText[key] ?? ChapterText(key: key, title: key, tip: "", more: "", source: "")
            return Chapter(number: n, title: t.title, tip: t.tip, tipMore: t.more, source: t.source,
                           drills: (0..<c).map { Self.key(at: Int(idx[$0])) }, key: key, blocking: !nonBlocking.contains(key))
        }
    }

    /// The `Drill` of a catalogue spec; `old` is the ≤ 0.48 drill with the same id (its title, note, formula and video stay).
    static func make(_ s: BLDrillSpec, old: Drill?, title overrideTitle: String? = nil) -> Drill {
        let key = String(cString: s.key)
        let balls = withUnsafePointer(to: s.balls) { p in
            p.withMemoryRebound(to: BLDrillBall.self, capacity: Int(BL_DRILL_MAX_BALLS)) { b in
                (0..<Int(s.ballCount)).map { BallState(id: Int(b[$0].id), x: b[$0].x, y: b[$0].y) }
            }
        }
        let kind = Int(s.kind)
        let goal: PracticeGoal? = kind == Int(BL_DRILL_GOAL) ? PracticeGoal(x: s.goalX, y: s.goalY, radius: s.goalR, potRequired: s.potRequired != 0, potOnly: s.potOnly != 0) : nil
        let level: Int = {
            if let o = old { return o.level }
            switch kind {
            case Int(BL_DRILL_KICK): return s.rails <= 1 ? 2 : (s.rails <= 3 ? 3 : 4)
            case Int(BL_DRILL_BANK): return 4
            case Int(BL_DRILL_SAFETY): return 3
            default: return s.chapter >= 9 ? 5 : 1
            }
        }()
        let text = newText[key]
        var d = Drill(title: overrideTitle ?? old?.title ?? text?.title ?? key, note: old?.note ?? text?.note ?? "", rails: kind == Int(BL_DRILL_GOAL) || kind == Int(BL_DRILL_SAFETY) ? 0 : Int(s.rails),
                      kick: kind == Int(BL_DRILL_KICK), balls: balls, angle: s.angle, goal: goal, level: level,
                      system: old?.system ?? newSystem[key] ?? "")
        d.id = key; d.video = old?.video; d.tipTop = s.tipTop; d.spec = s; d.safety = kind == Int(BL_DRILL_SAFETY)
        return d
    }
    /// 3 tools (kept as they were: QA flags and the free table use their indices) + the legacy drills in their old order
    /// (so every saved index still means the same drill) + the drills that are new, in catalogue order.
    static func all(legacy: [Drill]) -> [Drill] {
        var out: [Drill] = [], used = Set<String>()
        for l in legacy {
            if l.id.hasPrefix("tool-") { out.append(l); continue }
            guard let s = spec(l.id) else { out.append(l); continue }   // not in the catalogue: keep it as it was
            out.append(make(s, old: l)); used.insert(l.id)
        }
        for i in 0..<count {
            let k = key(at: i)
            if !used.contains(k), let s = spec(k) { out.append(make(s, old: nil)) }
        }
        // 0.50: the puzzles' drills (own table BLPuzzleTable, keys "p-<room>-<nn>") sit after the catalogue so loadDrill/finishShot work on them unchanged.
        for i in 0..<Int(BLPuzzleCount()) {
            guard let p = BLPuzzleAt(Int32(i))?.pointee else { continue }
            var d = make(p.spec, old: nil, title: "Thế bí " + String(cString: p.spec.key)); d.level = 0
            out.append(d)
        }
        return out
    }
}
