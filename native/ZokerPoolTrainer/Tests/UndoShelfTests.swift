import Foundation

// 0.58 L1: a take-back never carries a step (here: a "jump" shot) from one drill / chapter into another.
@main enum UndoShelfTests {
    static var checks = 0
    static func check(_ ok: Bool, _ msg: String) { checks += 1; if !ok { print("FAIL: \(msg)"); exit(1) } }
    static func main() {
        var s = UndoShelf<String>()
        s.push("ch1-jump", scope: "c1-d3"); s.push("ch1-shot2", scope: "c1-d3")
        check(s.canGoBack(scope: "c1-d3") && s.back.count == 2, "two steps recorded in drill c1-d3")
        check(!s.canGoBack(scope: "c2-d1") && s.popBack(scope: "c2-d1") == nil, "another chapter finds no step of chapter 1 (the 'jump' never comes back)")
        check(s.back.count == 2, "asking from another scope does not eat chapter 1's steps")
        s.push("ch2-shot", scope: "c2-d1")
        check(s.back == ["ch2-shot"] && s.scope == "c2-d1", "the first shot of chapter 2 starts a fresh shelf")
        check(s.popBack(scope: "c2-d1") == "ch2-shot" && s.popBack(scope: "c2-d1") == nil, "only chapter 2's own step comes back")
        s.push("a", scope: "x"); s.forward = ["f"]; s.clear()
        check(s.back.isEmpty && s.forward.isEmpty && !s.canGoBack(scope: "x"), "leaving the screen clears both directions")
        s.push("b", scope: "x"); s.clear(scope: "x")
        check(s.back.isEmpty, "re-entering the same drill (replay the ring) also starts empty")
        print("PASS UndoShelf: \(checks) checks")
    }
}
