import Foundation

// 0.58d item 4: the provisional 15 Ball score (settled score + face value of the balls that dropped since it settled).
@main struct PointChipsTests {
    static func check(_ ok: Bool, _ what: String) { if !ok { print("FAIL \(what)"); exit(1) } }
    static func main() {
        check(PointChips.shown(settled: 34, sunkNow: [], sunkAtSettle: [], shooting: true) == 34, "no ball dropped: unchanged")
        check(PointChips.shown(settled: 34, sunkNow: [7], sunkAtSettle: [], shooting: true) == 41, "ball 7 drops: +7")
        check(PointChips.shown(settled: 34, sunkNow: [7, 3], sunkAtSettle: [3], shooting: true) == 41, "ball 3 was already counted: only 7 is new")
        check(PointChips.shown(settled: 34, sunkNow: [7], sunkAtSettle: [], shooting: false) == 34, "the other player's chip never moves")
        check(PointChips.shown(settled: 0, sunkNow: [0, 15], sunkAtSettle: [], shooting: true) == 15, "the cue ball (0) is not a point")
        check(PointChips.shown(settled: 58, sunkNow: [1, 2, 3], sunkAtSettle: [], shooting: true) == 64, "may pass 61 until the rules settle it")
        check(PointChips.floatSeconds <= 0.6, "the +N fades within 0.6 s")
        print("PASS point chips")
    }
}
