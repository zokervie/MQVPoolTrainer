import Foundation

/// 0.58 P2 "Thách bạn" — the 15-character ring challenge (BLRingChallengeEncode/Decode in PuzzleDaily.h: ring number in the stable
/// catalogue, stars, shots made), its share line and the comparison. No server, no text typed by the user. Tests/RingChallengeTests.swift.
enum RingChallenge {
    enum Verdict: Equatable { case win, draw, lose }
    struct Info: Equatable { let ringKey: String; let stars: Int; let made: Int }
    static func encode(ringKey: String, stars: Int, made: Int) -> String? {
        let n = BLDrillIndex(ringKey)
        guard n >= 0 else { return nil }
        var buf = [CChar](repeating: 0, count: 16)
        guard BLRingChallengeEncode(n, Int32(stars), Int32(made), &buf) != 0 else { return nil }
        return String(cString: buf)
    }
    /// nil for a wrong code, or a code naming a ring this build does not have.
    static func decode(_ text: String) -> Info? {
        var ring: Int32 = 0, stars: Int32 = 0, made: Int32 = 0
        guard BLRingChallengeDecode(text, &ring, &stars, &made) != 0, let spec = BLDrillAt(ring) else { return nil }
        return Info(ringKey: String(cString: spec.pointee.key), stars: Int(stars), made: Int(made))
    }
    static func pretty(_ code: String) -> String {
        guard code.count == 15 else { return code }
        return String(code.prefix(5)) + "-" + String(code.dropFirst(5).prefix(5)) + "-" + String(code.suffix(5))
    }
    /// "Zoker Pool · Thách bạn ải <tên> · mình <N>/5 — vượt được không? <mã>" (the words are passed through L10n by the caller).
    static func shareLine(ringName: String, made: Int, code: String) -> String {
        "Zokervie · Thách bạn ải \(ringName) · mình \(made)/5 — vượt được không? \(pretty(code))"
    }
    static func verdict(mine: Int, theirs: Int) -> Verdict { mine > theirs ? .win : (mine == theirs ? .draw : .lose) }
}
