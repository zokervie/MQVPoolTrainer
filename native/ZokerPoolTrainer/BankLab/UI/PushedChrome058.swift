import Foundation

/// 0.58 L3 — every screen pushed inside a navigation stack (Sổ lời giải, Đo cục bộ, Sổ mẹo…) carries a clear "Đóng" button
/// in readable colours; the chevron alone was lost on the dark bars. Colours live here (Foundation) so the contrast is tested.
enum PushedChrome {
    /// sRGB 0…1. The bar is the app's dark ink; the button text is the warm gold used by the Lobby.
    static let barBackground: (r: Double, g: Double, b: Double) = (0.07, 0.07, 0.08)
    static let buttonText: (r: Double, g: Double, b: Double) = (0.92, 0.77, 0.51)
    static let closeTitleKey = "Đóng"
    private static func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    private static func luminance(_ c: (r: Double, g: Double, b: Double)) -> Double { 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b) }
    /// WCAG contrast ratio of the button text on the bar (≥ 4.5 is readable).
    static var contrast: Double {
        let a = luminance(buttonText), b = luminance(barBackground)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
