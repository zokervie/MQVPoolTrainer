import Foundation

/// 0.58 L1 — the take-back shelf of ONE drill: steps never cross drills or chapters. Every step is pushed with the scope
/// (drill id) it was made in; asking for a step under another scope finds nothing, and entering a new scope (or leaving
/// the screen) clears the shelf. Foundation only: Tests/UndoShelfTests.swift.
struct UndoShelf<Step> {
    private(set) var scope = ""
    var back: [Step] = [], forward: [Step] = []
    /// A new drill, chapter, variant or screen: nothing of the old one survives.
    mutating func clear(scope newScope: String = "") { scope = newScope; back = []; forward = [] }
    /// Records a step made in `scope`; a step from another scope first empties the shelf.
    mutating func push(_ step: Step, scope s: String) { if s != scope { clear(scope: s) }; back.append(step); forward.removeAll() }
    /// The previous step of `scope`, or nil (also nil when the shelf belongs to another scope).
    mutating func popBack(scope s: String) -> Step? { s == scope ? back.popLast() : nil }
    func canGoBack(scope s: String) -> Bool { s == scope && !back.isEmpty }
}
