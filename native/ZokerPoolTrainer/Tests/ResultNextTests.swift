import Foundation

/// 0.58c item 6: the primary button of exam / ring results.
@main enum ResultNextTests {
    static var checks = 0
    static func check(_ ok: Bool, _ message: String) {
        checks += 1
        if !ok { print("FAIL ResultNext: \(message)"); exit(1) }
    }
    static func main() {
        typealias R = ResultNext
        check(R.afterExam(passed: true, next: (2, true, true)) == .goNext(chapter: 2), "passed + next open → go next")
        check(R.afterExam(passed: false, next: (2, true, true)) == .retry, "not passed → retry is the main button")
        check(R.afterExam(passed: true, next: (2, false, true)) == .retryUntilUnlocked, "passed but next locked → the missing piece")
        check(R.afterExam(passed: true, next: nil) == .retry, "last chapter → nothing to go to")
        check(R.afterExam(passed: true, next: (4, true, false)) == .retry, "next chapter without drills yet → not offered")
        check(R.ladderAutoNextSeconds == 1.5, "auto-advance 1.5 s")
        check(R.afterRing(stars: 3, nextExists: true, nextOpen: true, chapterFinished: false) == .autoNext, "3 stars + next open → auto")
        check(R.afterRing(stars: 3, nextExists: false, nextOpen: false, chapterFinished: true) == .medalCard, "chapter done → medal card")
        check(R.afterRing(stars: 1, nextExists: true, nextOpen: false, chapterFinished: false) == .nextLocked, "short of stars → next locked, say what is needed")
        check(R.afterRing(stars: 1, nextExists: true, nextOpen: true, chapterFinished: false) == .stay, "open next but < 3 stars → player's choice")
        print("PASS ResultNext: \(checks) checks (exam main button, ring auto-next 1.5 s, locked next)")
    }
}
