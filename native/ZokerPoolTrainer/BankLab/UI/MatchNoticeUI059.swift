import UIKit

/// 0.59 A1/A2/A4 (owner 28/11): the notice shown under the scoreboard (foul card, turn pill) and the call chip
/// ("① Chọn bi · ② Chọn lỗ", then "Bi 3 → lỗ 6 · Đổi"). The decision is MatchNotice (Foundation, tested); this file only draws.
/// Shown only once the balls have stopped, never on top of a dialog, tap to dismiss early. Switches: Tuỳ chỉnh.
enum MatchNoticeUI {
    static var last: MatchNoticeInput?
    static var lastKind = ""
    static var count = 0
    static var recheck = false
    static weak var card: UIView?
    static weak var chip: UIView?
    static var chipTap: (() -> Void)?
    static var lastChip = ""      // QA probe: the last chip text shown (the chip itself fades after 1.8 s)
    static var dimmed: [(view: UIView, alpha: CGFloat, touch: Bool)] = []
    static var focus = false
    static let seatColors = [UIColor(red: 0.18, green: 0.44, blue: 0.85, alpha: 0.94), UIColor(red: 0.72, green: 0.20, blue: 0.24, alpha: 0.94)]
}

extension TrainingController {
    /// Called from syncMatchControls(): compares the ruled state with the previous one and shows at most one notice.
    func matchNoticeTick() {
        guard matchPlay.active else { MatchNoticeUI.last = nil; return }
        let networked = matchPlay.session.role != .none
        let moving = shotActive || (matchPlay.session.role == .guest && matchPlay.session.latestSnapshot?.isMoving == true)
        if moving {
            // rule the notice once the balls stop (the guest's state can arrive while its picture still plays the shot)
            if !MatchNoticeUI.recheck {
                MatchNoticeUI.recheck = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in MatchNoticeUI.recheck = false; self?.matchNoticeTick() }
            }
            return
        }
        let player = matchInt("currentPlayer")
        let warned = (matchPlay.state["twoFoulWarning"] as? [Bool]).map { $0.indices.contains(player) && $0[player] } ?? false
        let now = MatchNoticeInput(shotCount: matchInt("shotCount"), reason: matchPlay.state["reason"] as? String ?? "",
                                   currentPlayer: player, ballInHand: matchBool("ballInHand"), warnedCurrent: warned,
                                   pendingChoice: !(matchPlay.state["pendingChoice"] as? String ?? "").isEmpty,
                                   winner: matchInt("winner", fallback: -1), localPlayer: matchPlay.session.localPlayer,
                                   networked: networked, vsComputer: matchPlay.computerLevel != nil, names: matchPlay.names)
        let previous = MatchNoticeUI.last
        MatchNoticeUI.last = now
        guard previous != now else { return }
        let notice = MatchNotice.decide(previous: previous, now: now, reasonText: { [weak self] in self?.matchReason($0) ?? $0 },
                                        foulCard: Prefs.flag(Prefs.matchFoulCard, true), turnPill: Prefs.flag(Prefs.matchTurnPill, true))
        guard let notice = notice else { return }
        showMatchNotice(notice)
    }

    func showMatchNotice(_ notice: MatchNotice) {
        MatchNoticeUI.card?.removeFromSuperview()
        let box = UIView(), stack = UIStackView()
        stack.axis = .vertical; stack.alignment = .center; stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false; box.addSubview(stack)
        func label(_ text: String, _ size: CGFloat, _ weight: UIFont.Weight, _ color: UIColor) {
            let l = UILabel(); l.text = text; l.font = .systemFont(ofSize: size, weight: weight); l.textColor = color
            l.numberOfLines = 2; l.textAlignment = .center; l.adjustsFontSizeToFitWidth = true; l.minimumScaleFactor = 0.8
            stack.addArrangedSubview(l)
        }
        var hold = 1.2
        switch notice {
        case let .foul(title, detail, warning, _):
            box.backgroundColor = UIColor(red: 0.30, green: 0.07, blue: 0.08, alpha: 0.93)
            box.layer.cornerRadius = 14; box.layer.borderWidth = 1; box.layer.borderColor = UIColor(red: 0.95, green: 0.42, blue: 0.40, alpha: 0.9).cgColor
            label(title, 17, .semibold, .white)
            label(detail, 14, .medium, UIColor(white: 1, alpha: 0.88))
            if let w = warning { label("⚠︎ " + w, 13, .semibold, UIColor(red: 0.98, green: 0.78, blue: 0.35, alpha: 1)) }
            hold = warning == nil ? 2.5 : 3.5
            MatchNoticeUI.lastKind = "foul"
        case let .turn(text, seat):
            box.backgroundColor = MatchNoticeUI.seatColors[min(1, max(0, seat))]
            box.layer.cornerRadius = 15
            label(text, 15, .semibold, .white)
            MatchNoticeUI.lastKind = "turn"
        }
        MatchNoticeUI.count += 1
        let vertical: CGFloat = MatchNoticeUI.lastKind == "turn" ? 6 : 10
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: box.topAnchor, constant: vertical),
                                     stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -vertical),
                                     stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 18),
                                     stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -18)])
        box.accessibilityIdentifier = "MatchNotice"; box.accessibilityValue = MatchNoticeUI.lastKind
        box.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissMatchNotice)))
        placeUnderScoreboard(box, maxWidth: MatchNoticeUI.lastKind == "turn" ? 260 : 440)
        MatchNoticeUI.card = box
        LANPairQA.notice(MatchNoticeUI.lastKind + ":" + stack.arrangedSubviews.compactMap { ($0 as? UILabel)?.text }.joined(separator: " | "))
        box.alpha = 0; box.transform = CGAffineTransform(translationX: 0, y: -8)
        UIView.animate(withDuration: 0.22) { box.alpha = 1; box.transform = .identity }
        UIView.animate(withDuration: 0.3, delay: hold, options: [.allowUserInteraction]) { box.alpha = 0 } completion: { _ in
            if MatchNoticeUI.card === box { box.removeFromSuperview() }
        }
    }
    @objc func dismissMatchNotice() {
        guard let box = MatchNoticeUI.card else { return }
        UIView.animate(withDuration: 0.15) { box.alpha = 0 } completion: { _ in box.removeFromSuperview() }
    }

    /// A4: the call chip, same place as the notice. `seconds` = nil keeps it until hideCallChip().
    func showCallChip(_ text: String, seconds: Double?, tap: (() -> Void)? = nil) {
        MatchNoticeUI.chip?.removeFromSuperview()
        let box = UIView(); box.backgroundColor = UIColor(white: 0.06, alpha: 0.88)
        box.layer.cornerRadius = 15; box.layer.borderWidth = 1; box.layer.borderColor = MenuSkin.gold.withAlphaComponent(0.85).cgColor
        let l = UILabel(); l.text = text; l.font = .systemFont(ofSize: 15, weight: .semibold); l.textColor = .white; l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false; box.addSubview(l)
        NSLayoutConstraint.activate([l.topAnchor.constraint(equalTo: box.topAnchor, constant: 6), l.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -6),
                                     l.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16), l.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16)])
        box.accessibilityIdentifier = "CallChip"; box.accessibilityValue = text
        MatchNoticeUI.lastChip = text
        MatchNoticeUI.chipTap = tap
        if tap != nil { box.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(callChipTapped))) }
        placeUnderScoreboard(box, maxWidth: 360)
        MatchNoticeUI.chip = box
        if let s = seconds {
            UIView.animate(withDuration: 0.3, delay: s, options: [.allowUserInteraction]) { box.alpha = 0 } completion: { _ in
                if MatchNoticeUI.chip === box { box.removeFromSuperview() }
            }
        }
    }
    /// A4 (owner, ảnh 28/11: buttons over the corner pockets on the top view): while calling, the HUD steps back (faded,
    /// not tappable) so every pocket and every ball can be tapped (the scoreboard too: it sits over the top side pocket); only the call chip stays.
    func setCallFocus(_ on: Bool) {
        if on {
            MatchNoticeUI.focus = true
            dimHUDForCall()
            // the quick rail and the camera key are rebuilt when the camera mode changes: dim the new ones too
            for t in [0.35, 0.9, 1.6] {
                DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in if MatchNoticeUI.focus { self?.dimHUDForCall() } }
            }
        } else {
            MatchNoticeUI.focus = false
            let list = MatchNoticeUI.dimmed; MatchNoticeUI.dimmed = []
            list.forEach { $0.view.isUserInteractionEnabled = $0.touch }
            UIView.animate(withDuration: 0.25) { list.forEach { $0.view.alpha = $0.alpha } }
        }
    }
    private func dimHUDForCall() {
        for v in view.subviews where v !== scn && v !== MatchNoticeUI.chip && v !== MatchNoticeUI.card
            && !v.isHidden && v.alpha > 0.13 && !MatchNoticeUI.dimmed.contains(where: { $0.view === v }) {
            MatchNoticeUI.dimmed.append((v, v.alpha, v.isUserInteractionEnabled))
            v.isUserInteractionEnabled = false
        }
        UIView.animate(withDuration: 0.25) { MatchNoticeUI.dimmed.forEach { $0.view.alpha = 0.12 } }
    }
    func hideCallChip() { MatchNoticeUI.chip?.removeFromSuperview(); MatchNoticeUI.chipTap = nil }
    @objc func callChipTapped() { let t = MatchNoticeUI.chipTap; hideCallChip(); t?() }

    private func placeUnderScoreboard(_ box: UIView, maxWidth: CGFloat) {
        box.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(box)
        let board = matchPlay.scoreboard
        let underBoard = board.superview === view && !board.isHidden
        let anchor = underBoard ? board.bottomAnchor : view.safeAreaLayoutGuide.topAnchor
        let gap: CGFloat = underBoard ? 8 : 52
        NSLayoutConstraint.activate([box.topAnchor.constraint(equalTo: anchor, constant: gap),
                                     box.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     box.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
                                     box.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8)])
    }
}
