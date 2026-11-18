import UIKit

/// 0.47 M6 — Thách bạn bằng mã (no server). After a round: an 8-character code (Challenge.h: Crockford base32,
/// CRC-9, every single-character typo rejected — Tests/DailyLoopTests.cpp) = drill number + seed + score, shared
/// through the iOS share sheet with a result card picture. A friend types the code (Sảnh → Nhập mã thách đấu) →
/// plays that drill → both scores side by side. `zoker://` links: not yet (needs the URL scheme in Info.plist).
struct ChallengeInfo: Equatable {
    let drill: Int       // Drill.all index
    let seed: Int
    let score: Int       // % made of the challenger
    let code: String
}

enum ChallengeCode {
    /// 0.48 M3: the last code shared this session (shown on the teaser's end card).
    static var lastIssued: String?
    /// Stable drill number = position in DrillIDs.byTitle (append-only table: a number never changes meaning).
    static func number(of id: String) -> Int? { DrillIDs.byTitle.firstIndex { $0.id == id } }
    static func encode(drillID: String, seed: Int, score: Int) -> String? {
        guard let n = number(of: drillID) else { return nil }
        var buf = [CChar](repeating: 0, count: 9)
        guard BLChallengeEncode(Int32(n), Int32(seed), Int32(score), &buf) != 0 else { return nil }
        return String(cString: buf)
    }
    /// "ABCD-EFGH" for reading out loud.
    static func pretty(_ code: String) -> String { code.count == 8 ? String(code.prefix(4)) + "-" + String(code.suffix(4)) : code }
    static func decode(_ text: String) -> ChallengeInfo? {
        var d: Int32 = 0, s: Int32 = 0, p: Int32 = 0
        guard BLChallengeDecode(text, &d, &s, &p) != 0, Int(d) < DrillIDs.byTitle.count,
              let index = Drill.all.firstIndex(where: { $0.id == DrillIDs.byTitle[Int(d)].id }) else { return nil }
        return ChallengeInfo(drill: index, seed: Int(s), score: Int(p), code: text.uppercased())
    }
}

extension TrainingController {
    /// Round result → "Thách bạn": share the code + a picture of the result card.
    func shareChallenge(drill d: Drill, made: Int, stars: Int) {
        let seed = Int(PlayerStore.shared.day(Date()) & 0xFFF)   // layout variation: not used yet (same layout), kept in the code
        guard let code = ChallengeCode.encode(drillID: d.id, seed: seed, score: made * 20) else { return }
        let text = L10n.tr("Thách bạn trong ZokerPoolTrainer") + ": " + d.title + " · " + L10n.tr("mình vào") + " \(made)/5. "
            + L10n.tr("Mã") + ": " + ChallengeCode.pretty(code) + " (" + L10n.tr("Sảnh → Nhập mã thách đấu") + ")"
        let card = challengeCardImage(title: d.title, made: made, stars: stars, code: ChallengeCode.pretty(code))
        let share = UIActivityViewController(activityItems: [text, card], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        UIPasteboard.general.string = code
        ChallengeCode.lastIssued = code
        topPresenter.present(share, animated: true)
    }
    func challengeCardImage(title: String, made: Int, stars: Int, code: String) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 600, height: 320)).image { _ in
            UIColor.rgb(0x101418).setFill(); UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 600, height: 320), cornerRadius: 28).fill()
            ZDesign.Color.gold.setStroke(); let border = UIBezierPath(roundedRect: CGRect(x: 6, y: 6, width: 588, height: 308), cornerRadius: 24); border.lineWidth = 3; border.stroke()
            func draw(_ s: String, _ y: CGFloat, _ size: CGFloat, _ color: UIColor, _ weight: UIFont.Weight = .bold) {
                let p = NSMutableParagraphStyle(); p.alignment = .center
                (s as NSString).draw(in: CGRect(x: 20, y: y, width: 560, height: size * 1.4), withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p])
            }
            draw("ZOKER POOL · " + L10n.tr("Thách bạn"), 24, 22, ZDesign.Color.gold, .heavy)
            draw(title, 70, 26, .white)
            draw(Drill.starText(stars) + "   \(made)/5", 120, 34, .white, .heavy)
            draw(code, 190, 48, ZDesign.Color.gold, .black)
            draw(L10n.tr("Sảnh → Nhập mã thách đấu"), 262, 18, UIColor(white: 0.75, alpha: 1), .medium)
        }
    }
    /// Sảnh → "Nhập mã thách đấu": a wrong code is refused (CRC), a good one opens the same drill.
    func enterChallengeCode() {
        let a = UIAlertController(title: "Nhập mã thách đấu", message: "8 ký tự, ví dụ ABCD-EFGH", preferredStyle: .alert)
        // No automatic paste: reading the pasteboard would trigger the iOS "Allow paste" prompt; the player pastes by hand.
        a.addTextField { f in f.autocapitalizationType = .allCharacters; f.autocorrectionType = .no; f.accessibilityIdentifier = "ChallengeCodeField"; f.placeholder = "ABCD-EFGH" }
        a.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        a.addAction(UIAlertAction(title: "Chơi bài này", style: .default) { [weak self, weak a] _ in
            guard let self = self else { return }
            let text = a?.textFields?.first?.text ?? ""
            guard let c = ChallengeCode.decode(text) else {
                let bad = UIAlertController(title: "Mã không đúng", message: "Kiểm tra lại 8 ký tự (chữ O và số 0, chữ I và số 1 được hiểu như nhau).", preferredStyle: .alert)
                bad.view.accessibilityIdentifier = "ChallengeBadCode"
                bad.addAction(UIAlertAction(title: "Đóng", style: .cancel)); self.topPresenter.present(bad, animated: true); return
            }
            self.beginDrill(c.drill, guided: false)
            self.lessonActive = true; self.lessonScores = []; self.lessonPasses = 0
            self.challengePlaying = c
            self.notifyStatus(L10n.tr("Thách đấu") + ": " + Drill.all[c.drill].title + " · " + L10n.tr("người thách vào") + " \(c.score / 20)/5")
        })
        topPresenter.present(a, animated: true)
    }
}
