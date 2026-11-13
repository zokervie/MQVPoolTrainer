import UIKit

/// 0.42 (owner 13/11 18:12): while choosing the tip contact or the cue elevation, a large copy is shown away from the
/// finger — the effect ball in the middle of the LEFT half, the elevation fan in the middle of the RIGHT half.
/// Display only (no touches); it mirrors the real control.
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
        NSLayoutConstraint.activate([
            s.widthAnchor.constraint(equalToConstant: side), s.heightAnchor.constraint(equalToConstant: side),
            NSLayoutConstraint(item: s, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 0.55, constant: 0),
            s.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10),
            e.widthAnchor.constraint(equalToConstant: side), e.heightAnchor.constraint(equalToConstant: side),
            NSLayoutConstraint(item: e, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.45, constant: 0),
            e.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10)])
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
        loupe.maximumOffset = spin.maximumOffset; loupe.maxTop = spin.maxTop; loupe.reachable = spin.reachable
        loupe.select(side: spin.side, top: spin.top)
        if let expanded = expanded { fade(loupe, expanded) }
    }
    /// Called from the elevation pad's `changed`: shown while it moves, hidden 0.8 s after the last change.
    func updateElevationLoupe() {
        guard UserDefaults.standard.object(forKey: "loupes042") as? Bool ?? true else { return }
        let loupe = loupeViews.elevation
        loupe.leftHanded = elevationPad.leftHanded; loupe.minimum = elevationPad.minimum; loupe.degrees = elevationPad.degrees
        fade(loupe, true)
        Self.elevationHide?.cancel()
        let work = DispatchWorkItem { [weak self] in guard let self = self else { return }; self.fade(self.loupeViews.elevation, false) }
        Self.elevationHide = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }
}
