import UIKit
import ObjectiveC

/// 0.42 (owner acceptance 0.41 item 12): seven languages; 0.44.1: device language by default, else Vietnamese — en, vi, fil, es, zh-Hans, ja, hi.
/// The source text of the app is Vietnamese. Rather than touching ~900 call sites, UIKit's text entry points
/// (UILabel, UIButton, UIAlertController/Action, UISegmentedControl, UINavigationItem) are swizzled once and pass
/// through `L10n.tr`: exact phrase first, then known phrases inside dynamic text ("Bi 5 · lỗ 3"), longest first.
/// Untranslated text falls back to English if present, otherwise stays Vietnamese.
/// Catalog: `L10n.table` below (core screens) + optional `I18N_<code>` data assets (Tools/i18n, full catalog).
/// Translations other than vi/en are machine-quality drafts: a native speaker must review before release.
enum L10n {
    static let languages: [(code: String, name: String)] = [("en", "English"), ("vi", "Tiếng Việt"), ("fil", "Filipino"),
                                                             ("es", "Español"), ("zh", "中文"), ("ja", "日本語"), ("hi", "हिन्दी")]
    static let key = "appLanguage042"
    /// QA launches (UI tests, probes) always run in the source language so their text assertions stay valid.
    /// `--l10n-real` lets a QA launch use the real device language (first-launch language UI test).
    static let qa = ProcessInfo.processInfo.arguments.contains { $0.hasSuffix("-qa") } && !ProcessInfo.processInfo.arguments.contains("--l10n-real")   // 0.47: mọi cờ *-qa (không chỉ --visual-qa) giữ tiếng nguồn
    /// 0.44.1 (owner): no saved choice → the device language if supported, else Vietnamese (was: English).
    static var code: String {
        qa ? "vi" : (UserDefaults.standard.string(forKey: key) ?? deviceDefault)
    }
    private static var cache: [String: String] = [:]
    /// Computed once per launch (review: it ran on every translated string). A language change restarts the app anyway.
    static let deviceDefault = L10nDefault.code(preferred: Locale.preferredLanguages, supported: languages.map { $0.code })
    private static var loaded: [String: [String: String]] = [:]
    private static func asset(_ code: String) -> [String: String] {
        if let t = loaded[code] { return t }
        var t: [String: String] = [:]
        if let data = NSDataAsset(name: "I18N_\(code)")?.data, let d = try? JSONSerialization.jsonObject(with: data) as? [String: String] { t = d }
        let column = ["en": 0, "fil": 1, "es": 2, "zh": 3, "ja": 4, "hi": 5][code]
        if let c = column { for (k, row) in table where row.indices.contains(c) && t[k] == nil { t[k] = row[c] } }
        loaded[code] = t; return t
    }
    private static var catalogs: [String: L10nCatalog] = [:]
    /// 0.59: QA only — Vietnamese text that reached a non-Vietnamese screen (probe field viLeaks, UI test asserts 0).
    private(set) static var leaks: [String] = []
    static func tr(_ s: String) -> String {
        let lang = code
        guard lang != "vi", !s.isEmpty else { return s }
        if let hit = cache[lang + "\u{1}" + s] { return hit }
        let cat: L10nCatalog
        if let c = catalogs[lang] { cat = c } else {
            var merged = asset("en"); if lang != "en" { for (k, v) in asset(lang) { merged[k] = v } }
            cat = L10nCatalog(merged); catalogs[lang] = cat
        }
        let out = L10nCore.translate(s, cat)
        if leakWatch, L10nCore.vietnameseCount(out) > 0, leaks.count < 200, !leaks.contains(s) {
            leaks.append(s); print("L10N-LEAK [\(lang)] \(s.replacingOccurrences(of: "\n", with: "⏎")) → \(out.replacingOccurrences(of: "\n", with: "⏎"))")
        }
        if cache.count > 4000 { cache.removeAll() }
        cache[lang + "\u{1}" + s] = out
        return out
    }
    /// Leak recording only in QA launches that use a real language (`--l10n-real`), never in release.
    static let leakWatch = ProcessInfo.processInfo.arguments.contains("--l10n-real")
    static func set(_ code: String) { UserDefaults.standard.set(code, forKey: key); cache.removeAll(); catalogs.removeAll() }

    // MARK: swizzling (installed once at launch)
    private static var installed = false
    static func install() {
        guard !installed else { return }; installed = true
        swap(UILabel.self, #selector(setter: UILabel.text), #selector(UILabel.l10n_setText(_:)))
        swap(UIButton.self, #selector(UIButton.setTitle(_:for:)), #selector(UIButton.l10n_setTitle(_:for:)))
        // 0.59 (bản 200, owner screenshots): buttons built with UIButton.Configuration set `configuration.title`, which never
        // passed through setTitle(_:for:) — the right column (Đặt bi · Camera · ngắm · Bàn · Xong · Toàn cảnh) stayed Vietnamese.
        swap(UIButton.self, NSSelectorFromString("setConfiguration:"), #selector(UIButton.l10n_setConfiguration(_:)))
        swap(UIViewController.self, #selector(setter: UIViewController.title), #selector(UIViewController.l10n_setTitle(_:)))
        swap(UIAlertController.self, #selector(setter: UIAlertController.message), #selector(UIAlertController.l10n_setMessage(_:)))
        swap(UIAlertController.self, #selector(setter: UIAlertController.title), #selector(UIAlertController.l10n_alertSetTitle(_:)))
        swap(UISegmentedControl.self, #selector(UISegmentedControl.insertSegment(withTitle:at:animated:)), #selector(UISegmentedControl.l10n_insertSegment(withTitle:at:animated:)))
        swap(UISegmentedControl.self, #selector(UISegmentedControl.setTitle(_:forSegmentAt:)), #selector(UISegmentedControl.l10n_setTitle(_:forSegmentAt:)))
        if let original = class_getClassMethod(UIAlertAction.self, NSSelectorFromString("actionWithTitle:style:handler:")),
           let replacement = class_getClassMethod(UIAlertAction.self, #selector(UIAlertAction.l10n_action(withTitle:style:handler:))) {
            method_exchangeImplementations(original, replacement)
        }
    }
    private static func swap(_ cls: AnyClass, _ a: Selector, _ b: Selector) {
        // Safe pattern: when the class only inherits `a`, add it on this class first so the superclass is untouched.
        guard let m1 = class_getInstanceMethod(cls, a), let m2 = class_getInstanceMethod(cls, b) else { return }
        if class_addMethod(cls, a, method_getImplementation(m2), method_getTypeEncoding(m2)) {
            class_replaceMethod(cls, b, method_getImplementation(m1), method_getTypeEncoding(m1))
        } else { method_exchangeImplementations(m1, m2) }
    }
}
extension UILabel { @objc func l10n_setText(_ t: String?) { l10n_setText(t.map(L10n.tr)) } }
extension UIButton {
    @objc func l10n_setTitle(_ t: String?, for state: UIControl.State) { l10n_setTitle(t.map(L10n.tr), for: state) }
    /// `configuration` setter: the title (and subtitle) go through L10n.tr; Vietnamese (and every QA launch) returns them unchanged.
    @objc func l10n_setConfiguration(_ c: AnyObject?) {
        guard L10n.code != "vi", var config = c as? UIButton.Configuration else { l10n_setConfiguration(c); return }
        if let t = config.title { let tt = L10n.tr(t); if tt != t { config.title = tt } }
        if let t = config.subtitle { let tt = L10n.tr(t); if tt != t { config.subtitle = tt } }
        l10n_setConfiguration(config as AnyObject)
    }
}
extension UIViewController { @objc func l10n_setTitle(_ t: String?) { l10n_setTitle(t.map(L10n.tr)) } }
extension UIAlertController {
    @objc func l10n_setMessage(_ t: String?) { l10n_setMessage(t.map(L10n.tr)) }
    @objc func l10n_alertSetTitle(_ t: String?) { l10n_alertSetTitle(t.map(L10n.tr)) }
}
extension UISegmentedControl {
    @objc func l10n_insertSegment(withTitle t: String?, at i: Int, animated: Bool) { l10n_insertSegment(withTitle: t.map(L10n.tr), at: i, animated: animated) }
    @objc func l10n_setTitle(_ t: String?, forSegmentAt i: Int) { l10n_setTitle(t.map(L10n.tr), forSegmentAt: i) }
}
extension UIAlertAction {
    @objc class func l10n_action(withTitle t: String?, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Void)?) -> UIAlertAction {
        l10n_action(withTitle: t.map(L10n.tr), style: style, handler: handler)
    }
}
