import Foundation

/// 0.59 (owner, video bản 202: "Mã 561634 · Đang đồng bộ lượt…", "KẾT THÚC VÁN 1", "ván 2 starts", "ván mới sau seconds lát",
/// "Tạo room"): the old fallback replaced every known phrase found anywhere inside a dynamic string, so a short key
/// ("giây" → "seconds", "phòng" → "room") was swapped into the middle of an untranslated sentence and produced a mix.
/// Foundation only (Tests/L10nSweepTests.swift runs it on every Vietnamese literal of the app, Tools/run_lan_checks.sh).
///
/// Order for one string:
///  1. whole string: exact key → same key ignoring a trailing "…" / "." / ":" / "!" → ALL-CAPS text by its key → template;
///  2. split on "\n", then " · ", then " — " and translate each part the same way (recursively);
///  3. legacy pass (known phrases inside the text, longest first) — kept only when it leaves fewer Vietnamese letters than 2.
/// Template keys: "{}" = any text (translated recursively, e.g. a player name "Người 1"), "#" = a number. The translation
/// uses the same markers in the same order: "{} thắng ván" → "{} wins the rack", "Kết thúc ván #" → "End of rack #".
final class L10nCatalog {
    let exact: [String: String]
    let upper: [String: String]
    let templates: [(regex: NSRegularExpression, out: String)]
    let phrases: [String]

    private let source: [String: String]
    /// ALL-CAPS screens ("KẾT THÚC VÁN 1 · RACE 5", "NGƯỜI 1"): the same catalog with upper-cased keys and translations.
    lazy var caps: L10nCatalog = {
        var d: [String: String] = [:]
        for (k, v) in source { let u = k.uppercased(); if d[u] == nil { d[u] = v.uppercased() } }
        return L10nCatalog(d)
    }()

    init(_ dict: [String: String]) {
        source = dict
        var ex: [String: String] = [:], up: [String: String] = [:], tpl: [(NSRegularExpression, String)] = []
        for (k, v) in dict {
            if k.contains("{}") || k.range(of: "(^|[^0-9])#($|[^0-9])", options: .regularExpression) != nil && k != "#" {
                var p = NSRegularExpression.escapedPattern(for: k)
                // "{}" never spans a "·" or a line break: "{} thắng ván {}" must not eat "· ván mới sau giây lát"
                p = p.replacingOccurrences(of: "\\{\\}", with: "([^\\n·]+?)").replacingOccurrences(of: "#", with: "([0-9]+(?:[.,][0-9]+)?)")
                if let r = try? NSRegularExpression(pattern: "^" + p + "$", options: [.dotMatchesLineSeparators, .caseInsensitive]) { tpl.append((r, v)) }
            }
            // every key is also an exact key ("# Z-Trainer — hiệu chỉnh bàn" is a heading, not a template)
            ex[k] = v
            let u = k.uppercased(); if u != k, up[u] == nil { up[u] = v }
        }
        exact = ex; upper = up
        // longer templates first, so "{} thắng ván #" wins over "{} thắng ván"
        templates = tpl.sorted { $0.0.pattern.count > $1.0.pattern.count }
        // only phrases of two words or more: a lone word ("giây", "phòng", "phải") swapped into an untranslated sentence
        // is exactly the mix the owner saw ("ván mới sau seconds lát", "Tạo room")
        phrases = ex.keys.filter { k in
            let t = k.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.count >= 4 && t.contains(" ") && !k.contains("{}") && !k.contains("#")
        }.sorted { $0.count > $1.count }
    }
}

enum L10nCore {
    static let vietnameseLetters = try! NSRegularExpression(pattern: "[ạảãàáâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]", options: [.caseInsensitive])
    /// "massé" is the English (French) term, not a leak.
    static func vietnameseCount(_ s: String) -> Int {
        let t = s.replacingOccurrences(of: "massé", with: "", options: .caseInsensitive)
        return vietnameseLetters.numberOfMatches(in: t, range: NSRange(t.startIndex..., in: t))
    }

    static func translate(_ s: String, _ c: L10nCatalog) -> String {
        if s == s.uppercased(), s != s.lowercased(), vietnameseCount(s) > 0, c.exact[s] == nil { return translateExact(s, c.caps) }
        return translateExact(s, c)
    }

    private static func translateExact(_ s: String, _ c: L10nCatalog) -> String {
        if let w = whole(s, c, depth: 0) { return w }
        guard vietnameseCount(s) > 0 else { return s }
        let parts = segmented(s, c, depth: 0)
        if vietnameseCount(parts) == 0 { return parts }
        let legacy = phrasePass(s, c)
        return vietnameseCount(legacy) < vietnameseCount(parts) ? legacy : parts
    }

    /// Steps 1–2 only (no legacy pass); nil when nothing applies to the whole text.
    private static func whole(_ s: String, _ c: L10nCatalog, depth: Int) -> String? {
        if let t = c.exact[s] { return t }
        // keep the outer spaces of a part (" · " splitting leaves none, "\n" may)
        let core = s.trimmingCharacters(in: .whitespaces)
        if core.isEmpty { return nil }
        if core != s, let t = whole(core, c, depth: depth) {
            let lead = s.prefix { $0 == " " }, trail = String(s.reversed().prefix { $0 == " " })
            return String(lead) + t + trail
        }
        for p in ["…", "...", ".", ":", "!", "?"] where core.hasSuffix(p) && core.count > p.count {
            let base = String(core.dropLast(p.count))
            if let t = c.exact[base] ?? c.exact[base + "…"] { return t + p }
        }
        if core == core.uppercased(), core != core.lowercased(), let t = c.upper[core] { return t.uppercased() }
        guard depth < 4, vietnameseCount(core) > 0 else { return nil }
        let ns = core as NSString, range = NSRange(location: 0, length: ns.length)
        for (r, out) in c.templates {
            guard let m = r.firstMatch(in: core, range: range) else { continue }
            var result = "", rest = Substring(out), slot = 1
            while let i = rest.firstIndex(where: { $0 == "#" || $0 == "{" }) {
                result += rest[..<i]
                if rest[i] == "#" {
                    if slot < m.numberOfRanges { result += ns.substring(with: m.range(at: slot)) }; slot += 1
                    rest = rest[rest.index(after: i)...]
                } else if rest[i...].hasPrefix("{}") {
                    if slot < m.numberOfRanges {
                        let arg = ns.substring(with: m.range(at: slot))
                        result += whole(arg, c, depth: depth + 1) ?? (vietnameseCount(arg) > 0 ? segmented(arg, c, depth: depth + 1) : arg)
                    }
                    slot += 1
                    rest = rest[rest.index(i, offsetBy: 2)...]
                } else { result += "{"; rest = rest[rest.index(after: i)...] }
            }
            result += rest
            // an ALL-CAPS text ("KẾT THÚC VÁN 1") keeps its capitals in the translation
            return core == core.uppercased() && core != core.lowercased() ? result.uppercased() : result
        }
        return nil
    }

    private static func segmented(_ s: String, _ c: L10nCatalog, depth: Int) -> String {
        for sep in ["\n", " · ", " — "] where s.contains(sep) {
            return s.components(separatedBy: sep).map { part in
                whole(part, c, depth: depth + 1) ?? (vietnameseCount(part) > 0 && depth < 6 ? segmented(part, c, depth: depth + 1) : part)
            }.joined(separator: sep)
        }
        return whole(s, c, depth: depth + 1) ?? phrasePass(s, c)
    }

    /// Legacy: known phrases inside the text, longest first (before 0.59 this was the only fallback).
    static func phrasePass(_ s: String, _ c: L10nCatalog) -> String {
        var r = s
        for k in c.phrases where r.contains(k) { r = r.replacingOccurrences(of: k, with: c.exact[k] ?? k) }
        return r
    }
}
