import Foundation

/// 0.58c item 6: what the primary button of a drill / exam result is. Pure (Foundation only), tested in Tests/ResultNextTests.swift.
/// Owner: after passing a chapter exam the box offered only Close / Retake; the next lesson needed lobby → list → open again.
enum ResultNext {
    enum Primary: Equatable {
        case goNext(chapter: Int)     // passed and the next chapter is open: go straight in
        case retry                    // not passed, or nothing further to open: do it again
        case retryUntilUnlocked       // passed but the next chapter still locked: the missing piece is this exam again
    }
    /// Chapter exam result.
    static func afterExam(passed: Bool, next: (number: Int, open: Bool, hasDrill: Bool)?) -> Primary {
        guard passed else { return .retry }
        guard let next = next else { return .retry }               // last chapter: nothing to go to
        guard next.hasDrill else { return .retry }
        return next.open ? .goNext(chapter: next.number) : .retryUntilUnlocked
    }

    /// Ring ladder result: 1.5 s after the card is shown the next ring starts by itself unless the player taps "Ở lại".
    static let ladderAutoNextSeconds = 1.5

    enum Ladder: Equatable { case autoNext, stay, medalCard, nextLocked }
    /// stars ≥ 3 and the next ring open → auto; last ring of the chapter → medal card; next ring exists but locked → say what is needed.
    static func afterRing(stars: Int, nextExists: Bool, nextOpen: Bool, chapterFinished: Bool) -> Ladder {
        if stars >= 3 && chapterFinished { return .medalCard }
        if stars >= 3 && nextExists && nextOpen { return .autoNext }
        if nextExists && !nextOpen { return .nextLocked }
        return .stay
    }
}
