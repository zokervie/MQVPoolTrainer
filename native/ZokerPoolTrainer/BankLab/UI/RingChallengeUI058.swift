import UIKit

/// 0.58 P2 "Thách bạn" on the ring result card: share a 15-character code (no server, nothing typed by the user); a friend enters it in
/// Sảnh → Nhập mã thách đấu, plays exactly that ring, and the result card compares the two. Counted on this device only (0.55 R5 counters).
extension TrainingController {
    func shareRingChallenge(_ d: Drill, stars: Int, made: Int) {
        guard let code = RingChallenge.encode(ringKey: d.id, stars: stars, made: made) else { return }
        let text = String(format: L10n.tr("Zokervie · Thách bạn ải %@ · mình %d/5 — vượt được không? %@"), d.title, made, RingChallenge.pretty(code))
        UIPasteboard.general.string = code
        PlayerStore.shared.noteCodeSent()
        let share = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        topPresenter.present(share, animated: true)
    }
    /// Entered code that is a ring challenge: returns true when handled (valid → the ring opens; a ring this build lacks → error).
    func playRingChallenge(_ text: String) -> Bool {
        var ring: Int32 = 0, stars: Int32 = 0, made: Int32 = 0
        guard BLRingChallengeDecode(text, &ring, &stars, &made) != 0 else { return false }
        guard let info = RingChallenge.decode(text), let index = Chapters.index(of: info.ringKey) else {
            let bad = UIAlertController(title: L10n.tr("Mã không đúng"), message: L10n.tr("Ải trong mã này chưa có trong bản app của bạn."), preferredStyle: .alert)
            bad.view.accessibilityIdentifier = "ChallengeBadCode"; bad.addAction(UIAlertAction(title: L10n.tr("Đóng"), style: .cancel)); topPresenter.present(bad, animated: true); return true
        }
        PlayerStore.shared.noteCodeReceived()
        ringChallengePlaying = info
        beginDrill(index, guided: false)
        notifyStatus(String(format: L10n.tr("Thách bạn: đánh bằng %d/5"), info.made))
        return true
    }
    /// Line appended to the ring result when the round was a challenge; counts a solved challenge when the player matched or beat it.
    func ringChallengeResultLine(drill d: Drill, made: Int) -> String? {
        guard let c = ringChallengePlaying, c.ringKey == d.id else { return nil }
        ringChallengePlaying = nil
        let v = RingChallenge.verdict(mine: made, theirs: c.made)
        if v != .lose { PlayerStore.shared.noteCodeSolved() }
        return String(format: L10n.tr("Thách bạn: bạn %d/5 · người thách %d/5"), made, c.made) + " · " + (v == .win ? L10n.tr("Bạn thắng!") : (v == .draw ? L10n.tr("Hoà") : L10n.tr("Chưa vượt")))
    }
}
