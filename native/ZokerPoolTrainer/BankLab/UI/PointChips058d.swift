import UIKit

/// 0.58d item 4 — 15 Ball Rotation (first to 61): two point chips right under the top scoreboard, one under each player's name,
/// "34 /61", in the player's colour. The number follows the balls as they drop (the rules engine settles it when the shot ends and the
/// authoritative score replaces the provisional one); a score pops the number and floats a faint "+N" that is gone within 0.6 s.
/// Text only after the first build: no constraint changes while the balls roll. Guests read the same state/balls from the host snapshot.
extension TrainingController {
    private static var pointChips: [UILabel] = []
    private static var pointSettled: [Int] = [0, 0]
    private static var pointSunkAtSettle: Set<Int> = []
    private static var pointShown: [Int] = [-1, -1]
    private static var pointShotCount = -1

    func updatePointChips() {
        let board = matchPlay.scoreboard
        let rotation = matchPlay.active && !board.isHidden && matchPlay.state["rule"] as? String == "rotation15"
        if Self.pointChips.count != 2 || Self.pointChips[0].superview == nil {
            Self.pointChips.forEach { $0.removeFromSuperview() }
            Self.pointChips = (0...1).map { seat in
                let l = UILabel(); l.textAlignment = .center; l.isUserInteractionEnabled = false
                l.translatesAutoresizingMaskIntoConstraints = false; l.accessibilityIdentifier = "PointChip\(seat)"
                l.layer.cornerRadius = 9; l.layer.cornerCurve = .continuous; l.clipsToBounds = false
                l.layer.shadowColor = UIColor.black.cgColor; l.layer.shadowOpacity = 0.35; l.layer.shadowRadius = 4; l.layer.shadowOffset = .zero
                view.addSubview(l)
                NSLayoutConstraint.activate([l.topAnchor.constraint(equalTo: board.bottomAnchor, constant: 4), l.heightAnchor.constraint(equalToConstant: 30),
                                             l.widthAnchor.constraint(equalToConstant: 84),
                                             seat == 0 ? l.leadingAnchor.constraint(equalTo: board.leadingAnchor, constant: 4)
                                                       : l.trailingAnchor.constraint(equalTo: board.trailingAnchor, constant: -4)])
                return l
            }
            Self.pointShown = [-1, -1]
        }
        for chip in Self.pointChips { chip.isHidden = !rotation }
        guard rotation else { Self.pointShown = [-1, -1]; return }
        let scores = (matchPlay.state["scores"] as? [NSNumber])?.map { $0.intValue } ?? (matchPlay.state["scores"] as? [Int]) ?? [0, 0]
        guard scores.count == 2 else { return }
        let sunkNow = Set(balls.filter { $0.sunk && $0.id > 0 }.map { $0.id })
        let shotCount = matchInt("shotCount")
        // the rules settled a shot (even one that scored nothing, e.g. a foul) or a new rack began: the score is authoritative again
        if scores != Self.pointSettled || shotCount != Self.pointShotCount || sunkNow.count < Self.pointSunkAtSettle.count {
            Self.pointSettled = scores; Self.pointSunkAtSettle = sunkNow; Self.pointShotCount = shotCount
        }
        let player = matchInt("currentPlayer")
        let shooting = matchPlay.matchWinner < 0 && matchInt("winner", fallback: -1) < 0
        let style = Self.scoreboardStyles[Self.scoreboardStyleIndex]
        for seat in 0...1 {
            let chip = Self.pointChips[seat]
            let value = PointChips.shown(settled: Self.pointSettled[seat], sunkNow: sunkNow, sunkAtSettle: Self.pointSunkAtSettle, shooting: shooting && player == seat)
            let colour = seat == 0 ? style.plates.0 : style.plates.1
            chip.backgroundColor = colour.withAlphaComponent(max(0.78, colour.cgColor.alpha))
            let big = UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .black), small = UIFont.systemFont(ofSize: 11, weight: .bold)
            if Self.pointShown[seat] != value {
                let before = Self.pointShown[seat]
                Self.pointShown[seat] = value
                let text = NSMutableAttributedString(string: "\(value)", attributes: [.font: big, .foregroundColor: style.text])
                text.append(NSAttributedString(string: " /61", attributes: [.font: small, .foregroundColor: style.text.withAlphaComponent(0.7)]))
                chip.attributedText = text
                chip.accessibilityValue = "\(value)"
                chip.accessibilityLabel = "\(matchPlay.names[seat]): \(value)/61"
                if before >= 0, value > before, !UIAccessibility.isReduceMotionEnabled { popAndFloat(chip, gained: value - before) }
            }
        }
        view.bringSubviewToFront(Self.pointChips[0]); view.bringSubviewToFront(Self.pointChips[1])
    }
    private func popAndFloat(_ chip: UILabel, gained: Int) {
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1, 1.22, 1]; pop.keyTimes = [0, 0.4, 1]; pop.duration = 0.3
        chip.layer.add(pop, forKey: "pop")
        let plus = UILabel(); plus.text = "+\(gained)"; plus.font = .monospacedDigitSystemFont(ofSize: 15, weight: .heavy)
        plus.textColor = .white; plus.alpha = 0.9; plus.sizeToFit(); plus.isUserInteractionEnabled = false
        plus.center = CGPoint(x: chip.center.x, y: chip.frame.maxY + 6)
        view.addSubview(plus)
        UIView.animate(withDuration: PointChips.floatSeconds, delay: 0, options: [.curveEaseOut]) {
            plus.alpha = 0; plus.center.y += 14
        } completion: { _ in plus.removeFromSuperview() }
    }
}
