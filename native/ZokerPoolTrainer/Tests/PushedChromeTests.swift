import Foundation

// 0.58 L3: the "Đóng" button of pushed screens is readable on the dark bar (WCAG ≥ 4.5) and named in both languages.
@main enum PushedChromeTests {
    static var checks = 0
    static func check(_ ok: Bool, _ msg: String) { checks += 1; if !ok { print("FAIL: \(msg)"); exit(1) } }
    static func main() {
        check(PushedChrome.contrast >= 4.5, "close button contrast \(PushedChrome.contrast) ≥ 4.5 on the dark bar")
        check(PushedChrome.closeTitleKey == "Đóng", "the button is named Đóng (translated by L10n)")
        print("PASS PushedChrome: \(checks) checks (contrast \(String(format: "%.1f", PushedChrome.contrast)):1)")
    }
}
