import Foundation

/// 0.44.1: first-launch language from the device (no more English by default).
@main struct L10nDefaultTests {
    struct Failure: Error, CustomStringConvertible { var description: String }
    static func main() throws {
        var checks = 0
        func check(_ ok: Bool, _ what: String) throws { guard ok else { throw Failure(description: what) }; checks += 1 }
        let supported = ["en", "vi", "fil", "es", "zh", "ja", "hi"]
        func code(_ p: [String]) -> String { L10nDefault.code(preferred: p, supported: supported) }
        try check(code(["vi-VN"]) == "vi", "Vietnamese device → vi")
        try check(code(["vi"]) == "vi", "bare vi → vi")
        try check(code(["en-US"]) == "en", "English device → en")
        try check(code(["fr-FR"]) == "vi", "unsupported language → vi, not en")
        try check(code([]) == "vi", "no preference → vi")
        try check(code(["fr-FR", "ja-JP"]) == "ja", "first SUPPORTED preference wins")
        try check(code(["zh-Hans-CN"]) == "zh", "script subtag → zh")
        try check(code(["es-419"]) == "es", "region number → es")
        try check(code(["fil-PH"]) == "fil" && code(["tl-PH"]) == "fil", "Filipino / Tagalog → fil")
        try check(code(["de_DE", "vi_VN"]) == "vi", "underscore tags")
        try check(code(["en-VN", "vi-VN"]) == "en", "order of the device list is respected")
        try check(code(["zh-Hans-CN"]) == "zh", "Simplified Chinese → zh (the app's Simplified catalog)")
        try check(code(["zh-Hant-TW"]) == "vi" && code(["zh-Hant-TW", "en-US"]) == "en", "Traditional Chinese is not Simplified: next preference, else vi")
        try check(code(["ja-JP"]) == "ja" && code(["vi-VN"]) == "vi", "ja-JP → ja, vi-VN → vi")
        print("PASS L10n default: \(checks) first-launch language checks (device-first, Vietnamese fallback)")
    }
}
