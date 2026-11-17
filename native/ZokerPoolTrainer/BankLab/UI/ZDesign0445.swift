import UIKit

/// 0.45 M3 — ZDesign: one place for the app's look. Tokens (colour, type, radius, spacing, motion) and the shared
/// components that replace every black box: ZPill (frosted glass), ZButton (one line, shrinks to 70 %, never breaks
/// inside a word), ZToast (status line on a pill), ZSheet (sheet presentation defaults). 0.46 redraws screens with it.
enum ZDesign {
    enum Color {
        static let background = UIColor(red: 0.020, green: 0.031, blue: 0.059, alpha: 1)
        static let textPrimary = UIColor.white
        static let textSecondary = UIColor(white: 0.78, alpha: 1)
        static let gold = UIColor(red: 0xEA / 255.0, green: 0xC5 / 255.0, blue: 0x83 / 255.0, alpha: 1)   // = LobbyController.gold
        static let goldRim = gold.withAlphaComponent(0.75)
        static let danger = UIColor.systemRed, success = UIColor.systemGreen
    }
    enum Radius { static let pill: CGFloat = 18, card: CGFloat = 14, button: CGFloat = 10 }
    enum Space { static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24 }
    enum Motion { static let quick = 0.15, standard = 0.25, slow = 0.45 }
    /// Dynamic Type, never below 13 pt on iPhone.
    static func font(_ style: UIFont.TextStyle, weight: UIFont.Weight = .regular, minimum: CGFloat = 13) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style).pointSize
        return UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: max(minimum, base), weight: weight))
    }
}

/// Frosted glass with a fine gold rim (was GlassPill in 0.44.1; GlassPill stays as an alias for its call sites).
enum ZPill {
    static func apply(to view: UIView, cornerRadius: CGFloat = ZDesign.Radius.pill) { GlassPill.apply(to: view, cornerRadius: cornerRadius) }
    static func styleCaption(_ label: UILabel, size: CGFloat) { GlassPill.styleCaption(label, size: size) }
}

/// One-line button that shrinks its title to fit (≥ 70 %), never wraps or clips inside a word.
enum ZButton {
    static func make(_ title: String, symbol: String? = nil, filled: Bool = false, size: CGFloat = 13, action: @escaping () -> Void) -> UIButton {
        var c = filled ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        c.title = title; c.titleLineBreakMode = .byClipping
        if let symbol = symbol { c.image = UIImage(systemName: symbol); c.imagePlacement = .top; c.imagePadding = 3 }
        c.baseForegroundColor = filled ? .black : ZDesign.Color.textPrimary
        c.baseBackgroundColor = ZDesign.Color.gold
        c.background.cornerRadius = ZDesign.Radius.button
        if !filled { c.background.backgroundColor = UIColor(white: 0.03, alpha: 0.42) }
        c.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        let b = UIButton(configuration: c, primaryAction: UIAction { _ in action() })
        b.configurationUpdateHandler = { button in fit(button, size: size) }
        return b
    }
    /// The shrink rule (also used by the 0.44.1 Coach toggles).
    static func fit(_ button: UIButton, size: CGFloat) {
        guard var c = button.configuration, let title = c.title, button.bounds.width > 0 else { return }
        let full = (title as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: .semibold)]).width
        let scaled = size * max(0.7, min(1, (button.bounds.width - 12) / max(1, full)))
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in var a = a; a.font = .systemFont(ofSize: scaled, weight: .semibold); return a }
        button.configuration = c
    }
}

/// Status line on a pill (replaces the black toast).
enum ZToast {
    static func style(_ label: UILabel) {
        label.backgroundColor = .clear; label.textColor = ZDesign.Color.textPrimary
        label.font = ZDesign.font(.footnote, weight: .semibold)
        if let host = label.superview, host !== label.window, host.accessibilityIdentifier == "ZToastPill" { ZPill.apply(to: host, cornerRadius: ZDesign.Radius.card) }
    }
}

/// Sheet presentation defaults (grabber, medium + large detents, dark).
enum ZSheet {
    static func configure(_ vc: UIViewController) {
        vc.overrideUserInterfaceStyle = .dark
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController { sheet.detents = [.medium(), .large()]; sheet.prefersGrabberVisible = true }
    }
}
