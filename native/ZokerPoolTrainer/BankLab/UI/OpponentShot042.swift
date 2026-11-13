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
    /// The card for one stroke. `cueType`: 0 play, 1 jump, 2 break; a raised play cue (> 35°) is shown as Massé.
    func showOpponentShot(speed: Double, side: Double, top: Double, elevation: Double, cueType: Int, who: String) {
        guard UserDefaults.standard.object(forKey: "opponentShotCard042") as? Bool ?? true else { return }
        Self.opponentCard?.removeFromSuperview()
        let card = UIView(); card.isUserInteractionEnabled = false; card.accessibilityIdentifier = "OpponentShotCard"
        card.backgroundColor = UIColor(white: 0.03, alpha: 0.78); card.layer.cornerRadius = 14
        card.layer.borderWidth = 1; card.layer.borderColor = BroadcastCard.gold.withAlphaComponent(0.8).cgColor
        let w: CGFloat = 214, h: CGFloat = 112
        card.frame = CGRect(x: view.bounds.width * 0.30 - w / 2, y: view.bounds.height * 0.5 - h / 2 - 20, width: w, height: h)
        view.addSubview(card); Self.opponentCard = card
        let title = UILabel(frame: CGRect(x: 10, y: 6, width: w - 20, height: 16)); title.text = "Cú của \(who)"
        title.font = .systemFont(ofSize: 12, weight: .heavy); title.textColor = BroadcastCard.gold; card.addSubview(title)
        // effect ball with the tip contact
        let ball = SpinPad(frame: CGRect(x: 10, y: 28, width: 76, height: 76)); ball.isUserInteractionEnabled = false
        ball.select(side: side, top: top); card.addSubview(ball)
        // power on the spectrum scale
        let t = max(0, min(1, speed / 8.0))
        let bar = CAGradientLayer(); bar.frame = CGRect(x: 96, y: 34, width: w - 106, height: 10); bar.cornerRadius = 5
        bar.startPoint = CGPoint(x: 0, y: 0.5); bar.endPoint = CGPoint(x: 1, y: 0.5)
        bar.colors = (0...6).map { PowerFX.color(Double($0) / 6).cgColor }; card.layer.addSublayer(bar)
        let needle = UIView(frame: CGRect(x: 96 + (w - 106) * CGFloat(t) - 1.5, y: 30, width: 3, height: 18)); needle.backgroundColor = .white
        needle.layer.cornerRadius = 1.5; card.addSubview(needle)
        let power = UILabel(frame: CGRect(x: 96, y: 50, width: w - 106, height: 22)); power.text = String(format: "%.1f m/s", speed)
        power.font = .monospacedDigitSystemFont(ofSize: 18, weight: .heavy); power.textColor = PowerFX.color(t); card.addSubview(power)
        let cueName = cueType == 1 ? "Jump" : (cueType == 2 ? "Break" : (elevation > 35 ? "Massé" : "Đánh"))
        let spinText = abs(side) < 0.05 && abs(top) < 0.05 ? "tâm" :
            [top > 0.05 ? "trên \(Int(top * 100))%" : (top < -0.05 ? "dưới \(Int(-top * 100))%" : nil),
             side > 0.05 ? "phải \(Int(side * 100))%" : (side < -0.05 ? "trái \(Int(-side * 100))%" : nil)].compactMap { $0 }.joined(separator: " · ")
        let info = UILabel(frame: CGRect(x: 96, y: 72, width: w - 106, height: 34)); info.numberOfLines = 2
        info.text = "Cơ \(cueName) · \(Int(elevation.rounded()))°\nĐiểm chạm: \(spinText)"
        info.font = .systemFont(ofSize: 11, weight: .semibold); info.textColor = .white; info.adjustsFontSizeToFitWidth = true; card.addSubview(info)
        powerFX.fire(CGPoint(x: card.frame.midX, y: card.frame.minY - 4), speed: speed)
        card.alpha = 0; card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.2) { card.alpha = 1; card.transform = .identity }
        UIView.animate(withDuration: 0.35, delay: 3.5, options: [], animations: { card.alpha = 0 }) { _ in card.removeFromSuperview() }
    }
}
