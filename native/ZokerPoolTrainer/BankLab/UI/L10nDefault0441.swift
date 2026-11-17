import Foundation

/// 0.44.1 (owner): the first-launch language follows the device — the first of `Locale.preferredLanguages` the app
/// supports — and falls back to Vietnamese (the source language), never to English. A saved choice always wins.
/// Foundation only: Tests/L10nDefaultTests.swift (Tools/run_lan_checks.sh).
enum L10nDefault {
    static func code(preferred: [String], supported: [String]) -> String {
        for tag in preferred {
            let lower = tag.lowercased()
            let base = lower.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? lower
            if supported.contains(base) { return base }
            if base == "tl", supported.contains("fil") { return "fil" }   // Tagalog devices → Filipino
        }
        return "vi"
    }
}
