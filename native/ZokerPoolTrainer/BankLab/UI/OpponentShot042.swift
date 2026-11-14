import UIKit

/// 0.42 (owner acceptance 0.41 item 5): after each opponent stroke (Wi-Fi/online opponent or the computer) the player
/// sees what was played — power on the 7-colour scale with the spectrum burst, the tip contact on an effect ball, the
/// cue chosen (Đánh / Jump / Massé / Break) and the elevation — for 3.5 s, in the middle-left (clear of the HUD).
extension TrainingController {
    private static var opponentCard: UIView?
    static var lastShotInfo: [String: Double] = [:]
    func recordStrikeInfo(_ shot: LANShot, player: Int) {
        Self.lastShotInfo = ["speed": shot.speed, "side": shot.side, "top": shot.top, "elevation": shot.elevation,
                             "cueType": Double(shot.cueType), "player": Double(player), "id": Double(matchInt("shotCount") + 1)]
    }
    /// 0.43 (owner 0.40 #5 + screenshot 14/11: the 0.42 card covered the table). No card: the opponent's stroke is shown ON
    /// the player's own controls — the effect ball already shows the contact (match strike selects it), the cue keys and
    /// elevation fan follow — plus a slim 7-colour power bar right under the effect ball with "m/s · cue · elevation".
    /// Display only, fades after 3.5 s. Switch: Tuỳ chỉnh (opponentShotCard042).
    func showOpponentShot(speed: Double, side: Double, top: Double, elevation: Double, cueType: Int, who: String) {
        guard UserDefaults.standard.object(forKey: "opponentShotCard042") as? Bool ?? true else { return }
        Self.opponentCard?.removeFromSuperview()
        spin.select(side: side, top: top); spin.alpha = 0.97
        if elevation > 0 { elevationPad.degrees = elevation }
        let anchor = spin.frame
        let w = max(150, anchor.width * 2.4), h: CGFloat = 30
        let strip = UIView(frame: CGRect(x: anchor.midX - w / 2, y: anchor.maxY + 6, width: w, height: h))
        if strip.frame.maxY > view.bounds.height - 2 { strip.frame.origin.y = anchor.minY - h - 6 }
        strip.frame.origin.x = max(8, min(view.bounds.width - w - 8, strip.frame.minX))
        strip.isUserInteractionEnabled = false; strip.accessibilityIdentifier = "OpponentShotCard"
        view.addSubview(strip); Self.opponentCard = strip
        let t = max(0, min(1, speed / 8.0))
        let bar = CAGradientLayer(); bar.frame = CGRect(x: 0, y: 2, width: w, height: 7); bar.cornerRadius = 3.5
        bar.startPoint = CGPoint(x: 0, y: 0.5); bar.endPoint = CGPoint(x: 1, y: 0.5)
        bar.colors = (0...6).map { PowerFX.color(Double($0) / 6).cgColor }; strip.layer.addSublayer(bar)
        let needle = UIView(frame: CGRect(x: w * CGFloat(t) - 1.5, y: 0, width: 3, height: 11)); needle.backgroundColor = .white
        needle.layer.cornerRadius = 1.5; needle.layer.shadowColor = UIColor.black.cgColor; needle.layer.shadowOpacity = 0.6; needle.layer.shadowRadius = 2
        strip.addSubview(needle)
        let cueName = cueType == 1 ? "Jump" : (cueType == 2 ? "Break" : (elevation > 35 ? "Massé" : L10n.tr("Đánh")))
        let info = UILabel(frame: CGRect(x: 0, y: 12, width: w, height: 17)); info.textAlignment = .center
        info.text = String(format: "%.1f m/s · %@ · %d°", speed, cueName, Int(elevation.rounded()))
        info.font = .monospacedDigitSystemFont(ofSize: 12, weight: .heavy); info.textColor = PowerFX.color(t)
        info.shadowColor = .black; info.shadowOffset = CGSize(width: 0, height: 1); info.adjustsFontSizeToFitWidth = true
        strip.addSubview(info)
        strip.alpha = 0
        UIView.animate(withDuration: 0.2) { strip.alpha = 1 }
        UIView.animate(withDuration: 0.35, delay: 3.5, options: [], animations: { strip.alpha = 0 }) { _ in strip.removeFromSuperview() }
    }
}
