import UIKit

/// 0.54 "Làm chủ chương" — the Swift side only keeps names, grouping and drawing. EVERY rule (stars of a round, % of a chapter, title band, ring unlocking,
/// warm-up, take-back budget, "Tay sạch") comes from Mastery.h through the bridging header; none is rewritten here.
enum Mastery {
    /// Title names by BLTitleIndex 0…9 (vi); the English names are in the i18n catalogue under the same Vietnamese key.
    static let titles = ["Tay Mơ Có Chí", "Khách Quen Bàn Số 3", "Triển Vọng", "Bậc Thầy Đánh Phủi", "Trùm Quán Quen",
                         "Hung Thần Phố Bida", "Cáo Già Sa Mạc", "Chuyên Gia", "Bảo Vật Quốc Gia", "Thiên Tài"]
    static let nickname = "Bàn Tay Nhung"
    static let intro = "Chúng tôi tin rằng sau khi vượt qua chương này với điểm số càng cao và càng ít dùng quyền trợ giúp, bạn sẽ hoàn thiện khả năng kiểm soát lực và xứng đáng với danh hiệu mà game trao tặng."
    static let ladderTitles = ["force-near": "Lực gần", "force-far": "Lực xa", "force-1rail-short": "1 băng ngắn", "force-1rail-long": "1 băng dài",
                               "force-2rail": "2 băng", "force-2rail-long": "2 băng dài", "force-3rail": "3 băng", "force-follow": "Theo bi", "force-draw": "Lùi bi"]

    struct Ladder { let name: String; let rings: [String] }   // rings = ids of tier 1, 2, 3
    static func tier(_ id: String) -> Int { DrillCatalog.spec(id).map { Int($0.tier) } ?? 0 }
    static func ladders(_ c: Chapter) -> [Ladder] {
        var order: [String] = [], rings: [String: [String]] = [:]
        for id in c.drills where tier(id) > 0 {
            let name = String(id.dropLast(2)); if rings[name] == nil { order.append(name) }
            rings[name, default: []].append(id)
        }
        return order.map { Ladder(name: $0, rings: rings[$0] ?? []) }
    }
    static func hasLadders(_ c: Chapter) -> Bool { c.drills.contains { tier($0) > 0 } }
    static func ladderName(of id: String) -> String { String(id.dropLast(2)) }

    /// Is this ring playable? (BLTierOpen on the stars of the ring before it.)
    static func ringOpen(_ id: String, _ s: PlayerStore = .shared) -> Bool {
        // 0.58c: BLLadderPrevious works on the CATALOGUE table's index. This used the index in Drill.all (the old lessons come first
        // there), so the "ring before" was the wrong row and a ring that had earned its 3 stars never opened the next one.
        let t = tier(id); guard t > 0, let index = (0..<DrillCatalog.count).first(where: { DrillCatalog.key(at: $0) == id }) else { return true }
        let previous = BLLadderPrevious(Int32(index))
        return BLTierOpen(Int32(t), previous >= 0 ? Int32(s.ladderStars(DrillCatalog.key(at: Int(previous)))) : 0) != 0
    }
    static func percent(_ c: Chapter, _ s: PlayerStore = .shared) -> Int {
        let stars = c.drills.filter { tier($0) > 0 }.map { Int32(s.ladderStars($0)) }
        return Int(BLChapterPercent(stars, Int32(stars.count)))
    }
    static func warmDone(_ made: Int) -> Bool { BLWarmupDone(Int32(made)) != 0 }
    static func titleIndex(_ percent: Int) -> Int { Int(BLTitleIndex(Int32(percent))) }
    /// "còn N % nữa lên <bậc sau>"; nil at the top title.
    static func nextTitle(_ percent: Int) -> (name: String, remaining: Int)? {
        let i = titleIndex(percent); guard i + 1 < titles.count else { return nil }
        return (titles[i + 1], max(0, Int(BLTitleLowerPercent(Int32(i + 1))) - percent))
    }
    /// -1 = unlimited
    static func undoLeft(_ c: Chapter, _ s: PlayerStore = .shared) -> Int { Int(BLChapterUndoLeft(Int32(c.number), Int32(s.undoUsed(c.key)))) }
    static func undoAllowed(_ c: Chapter, _ s: PlayerStore = .shared) -> Bool { BLChapterUndoAllowed(Int32(c.number), Int32(s.undoUsed(c.key))) != 0 }
    /// 0.56 K2: no "Tay sạch" after a take-back or after the rescue power bar (BLChapterCleanSealNoHelp).
    static func cleanSeal(_ c: Chapter, _ s: PlayerStore = .shared) -> Bool { BLChapterCleanSealNoHelp(Int32(percent(c, s)), Int32(s.undoUsed(c.key)), Int32(s.rescueUsed(c.key))) != 0 }
    /// Offer the rescue power bar? (BLPowerBarRescue: never in chapter 1; ≤ 10 take-backs left; and the rung is hard or was missed 3 scored rounds in a row)
    static func rescue(_ c: Chapter, makePercent: Int, failedRounds: Int, _ s: PlayerStore = .shared) -> Bool {
        BLPowerBarRescue(Int32(c.number), Int32(s.undoUsed(c.key)), Int32(makePercent), Int32(failedRounds)) != 0
    }

    /// "Khoe": 1080×1350, wood frame and Petemoss like the menu. Name · title · nickname · % · "Tay sạch" seal · logo. No aim lines, no solutions.
    static func cardImage(player: String, title: String, nickname: String, percent: Int, seal: Bool, tier: MedalTier? = nil) -> UIImage {
        let size = CGSize(width: 1080, height: 1350)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            MenuSkin.frameWood.setFill(); c.fill(CGRect(origin: .zero, size: size))
            let colors = [Wood.cardTop.cgColor, Wood.cardBottom.cgColor] as CFArray
            let inner = CGRect(x: 60, y: 60, width: size.width - 120, height: size.height - 120)
            c.saveGState(); UIBezierPath(roundedRect: inner, cornerRadius: 44).addClip()
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) { c.drawLinearGradient(g, start: inner.origin, end: CGPoint(x: inner.minX, y: inner.maxY), options: []) }
            c.restoreGState()
            func draw(_ text: String, _ font: UIFont, _ color: UIColor, y: CGFloat) {
                let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let w = (text as NSString).size(withAttributes: a).width
                (text as NSString).draw(at: CGPoint(x: (size.width - min(w, size.width - 160)) / 2 , y: y), withAttributes: a)
            }
            draw("ZOKER POOL", Wood.titleFont(120), Wood.ink, y: 130)
            draw(player, .systemFont(ofSize: 64, weight: .semibold), Wood.inkSoft, y: 330)
            draw(title, Wood.titleFont(130), Wood.ink, y: 470)
            draw("“" + nickname + "”", Wood.titleFont(84), Wood.inkSoft, y: 660)
            draw("\(percent) %", .systemFont(ofSize: 220, weight: .heavy), Wood.ink, y: 800)
            if seal { draw("✓ " + L10n.tr("Tay sạch"), .systemFont(ofSize: 74, weight: .bold), UIColor(red: 0.1, green: 0.4, blue: 0.2, alpha: 1), y: 1100) }
            if let tier = tier { MedalArt.image(tier: tier, size: 230, ribbon: seal).draw(in: CGRect(x: 64, y: 1010, width: 230, height: 230)) }   // 0.58 T3: the share card shows the chapter medal
            draw("zokerpool", .systemFont(ofSize: 44, weight: .medium), Wood.inkSoft, y: 1230)
        }
    }
}
