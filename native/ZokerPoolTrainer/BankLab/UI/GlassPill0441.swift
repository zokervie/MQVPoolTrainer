import UIKit

/// 0.44.1 (owner: "đừng dùng khung đen"): the one caption look for the new tutorial (M4) and the Coach card — a thin
/// frosted-glass pill with a fine gold rim, white bold text. No dark slab, no full-screen dim.
enum GlassPill {
    static let gold = UIColor(red: 0xEA / 255.0, green: 0xC5 / 255.0, blue: 0x83 / 255.0, alpha: 1)
    /// Puts the frosted background behind `view`'s content (index 0) and styles its rim. Idempotent.
    static func apply(to view: UIView, cornerRadius: CGFloat) {
        view.backgroundColor = .clear
        view.layer.cornerRadius = cornerRadius; view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1; view.layer.borderColor = gold.withAlphaComponent(0.75).cgColor
        view.clipsToBounds = true
        guard !view.subviews.contains(where: { $0.accessibilityIdentifier == "GlassPillBlur" }) else { return }
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.accessibilityIdentifier = "GlassPillBlur"; blur.isUserInteractionEnabled = false
        blur.frame = view.bounds; blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(blur, at: 0)
    }
    /// Caption text on the glass: white, bold, a soft shadow so it reads over a bright table too.
    static func styleCaption(_ label: UILabel, size: CGFloat) {
        label.textColor = .white; label.font = .systemFont(ofSize: size, weight: .bold)
        label.layer.shadowColor = UIColor.black.cgColor; label.layer.shadowOpacity = 0.55
        label.layer.shadowRadius = 2; label.layer.shadowOffset = CGSize(width: 0, height: 1)
    }
}
