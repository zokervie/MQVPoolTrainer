import UIKit

/// 0.42: while choosing the tip contact or the cue elevation, a large copy is shown away from the finger.
/// 0.44 (owner item 16: "chỉ hiện MỘT hình nhô lên khỏi vùng ngón tay, không cần double"): the copy now pops up straight
/// ABOVE the control the finger is on (clamped inside the safe area) and the control itself fades to near-invisible
/// while it is up — one image, never two. Display only (no touches); the real control keeps receiving the drag.
extension TrainingController {
    private static var loupes: (spin: SpinPad, elevation: ElevationPad)?
    private static var elevationHide: DispatchWorkItem?
    private var loupeViews: (spin: SpinPad, elevation: ElevationPad) {
        if let l = Self.loupes, l.spin.superview != nil { return l }
        let s = SpinPad(frame: .zero), e = ElevationPad(frame: .zero)
        for v in [s as UIView, e] {
            v.isUserInteractionEnabled = false; v.isHidden = true; v.alpha = 0; v.translatesAutoresizingMaskIntoConstraints = false
            v.layer.shadowColor = UIColor.black.cgColor; v.layer.shadowOpacity = 0.5; v.layer.shadowRadius = 10; v.layer.shadowOffset = .zero
            view.addSubview(v)
        }
        s.accessibilityIdentifier = "SpinLoupe"; e.accessibilityIdentifier = "ElevationLoupe"
        let side: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 240 : 170
        let safe = view.safeAreaLayoutGuide
        func above(_ v: UIView, _ control: UIView) -> [NSLayoutConstraint] {
            let cx = v.centerXAnchor.constraint(equalTo: control.centerXAnchor); cx.priority = .defaultHigh
            let bottom = v.bottomAnchor.constraint(equalTo: control.topAnchor, constant: -12); bottom.priority = .defaultHigh
            return [v.widthAnchor.constraint(equalToConstant: side), v.heightAnchor.constraint(equalToConstant: side), cx, bottom,
                    v.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor, constant: 6),
                    v.trailingAnchor.constraint(lessThanOrEqualTo: safe.trailingAnchor, constant: -6),
                    v.topAnchor.constraint(greaterThanOrEqualTo: safe.topAnchor, constant: 6)]
        }
        NSLayoutConstraint.activate(above(s, spin) + above(e, elevationPad))
        Self.loupes = (s, e); return (s, e)
    }
    private func fade(_ v: UIView, _ on: Bool) {
        if on { view.bringSubviewToFront(v); v.isHidden = false }
        UIView.animate(withDuration: on ? 0.12 : 0.22, animations: { v.alpha = on ? 1 : 0 }) { _ in if !on && v.alpha == 0 { v.isHidden = true } }
    }
    /// Called from the spin pad's `changed` and `expandedChanged`.
    func updateSpinLoupe(expanded: Bool? = nil) {
        guard UserDefaults.standard.object(forKey: "loupes042") as? Bool ?? true else { return }
        let loupe = loupeViews.spin
        loupe.maximumOffset = spin.maximumOffset; loupe.maxTop = spin.maxTop; loupe.reachable = spin.reachable; loupe.reachableSnapshot = spin.reachableSnapshot   // 0.44-mm: same per-draw snapshot as the effect ball
        loupe.select(side: spin.side, top: spin.top)
        if let expanded = expanded { fade(loupe, expanded) }
    }
    /// 0.44: the real control under the finger while its lifted copy is up (alpha 0.02 still receives touches).
    var loupesActive: Bool {
        (UserDefaults.standard.object(forKey: "loupes042") as? Bool ?? true) && !ProcessInfo.processInfo.arguments.contains("--spin-detail")
    }
    /// Called from the elevation pad's `changed`: shown while it moves, hidden 0.8 s after the last change.
    func updateElevationLoupe() {
        guard UserDefaults.standard.object(forKey: "loupes042") as? Bool ?? true else { return }
        let loupe = loupeViews.elevation
        loupe.leftHanded = elevationPad.leftHanded; loupe.minimum = elevationPad.minimum; loupe.degrees = elevationPad.degrees
        fade(loupe, true); elevationPad.alpha = 0.02
        Self.elevationHide?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }; self.fade(self.loupeViews.elevation, false)
            UIView.animate(withDuration: 0.18) { self.elevationPad.alpha = 1 }
        }
        Self.elevationHide = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
}
