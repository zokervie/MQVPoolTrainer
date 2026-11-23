import Foundation

// 0.58 P2: "Thách bạn" — ring challenge code, share line, comparison. Foundation + the C core (PuzzleDaily.h, DrillCatalog.h).
@main enum RingChallengeTests {
    static var checks = 0
    static func check(_ ok: Bool, _ msg: String) { checks += 1; if !ok { print("FAIL: \(msg)"); exit(1) } }
    static func main() {
        let key = String(cString: BLDrillAt(BLDrillIndex("first-shot") >= 0 ? BLDrillIndex("first-shot") : 0).pointee.key)
        guard let code = RingChallenge.encode(ringKey: key, stars: 3, made: 4) else { check(false, "encode a real ring"); return }
        check(code.count == 15, "15 characters")
        let got = RingChallenge.decode(code)
        check(got?.ringKey == key && got?.stars == 3 && got?.made == 4, "decode returns the ring key, stars and shots made")
        check(RingChallenge.decode(String(code.prefix(5)) + "-" + String(code.dropFirst(5).prefix(5)) + "-" + String(code.suffix(5)))?.made == 4, "XXXXX-XXXXX-XXXXX is read")
        check(RingChallenge.decode("12345-12345-12345") == nil && RingChallenge.decode("") == nil, "wrong code → nil (error shown)")
        check(RingChallenge.encode(ringKey: "no-such-ring", stars: 3, made: 4) == nil, "unknown ring → no code")
        // a valid code naming a ring this build does not have is an error, not a crash
        var buf = [CChar](repeating: 0, count: 16)
        check(BLRingChallengeEncode(4000, 1, 1, &buf) != 0 && RingChallenge.decode(String(cString: buf)) == nil, "a ring number the app does not know → error")
        let line = RingChallenge.shareLine(ringName: "Vòng 2", made: 4, code: code)
        check(line == "Zoker Pool · Thách bạn ải Vòng 2 · mình 4/5 — vượt được không? \(RingChallenge.pretty(code))", "share line wording: \(line)")
        check(RingChallenge.verdict(mine: 5, theirs: 4) == .win && RingChallenge.verdict(mine: 4, theirs: 4) == .draw && RingChallenge.verdict(mine: 2, theirs: 4) == .lose, "comparison")
        print("PASS RingChallenge: \(checks) checks")
    }
}
