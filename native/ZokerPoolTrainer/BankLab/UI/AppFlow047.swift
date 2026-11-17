import Foundation

/// 0.45 M5.3 — launch flow as a state machine: intro → Lobby → (tutorial if not done yet) → table.
/// Each step reports "done" with a call (`done(.intro)` from the intro's finish, `done(.lobby)` when the Lobby has
/// closed and the chosen action ran, `done(.tutorial)` after the first-shot beats), never with a timer. A step whose
/// starter returns false is skipped (QA launch, intro switched off, tutorial already seen…). Stale or repeated
/// `done` calls are ignored, so no step can run twice. Foundation only: Tests/AppFlowTests.swift.
final class AppFlow {
    enum Step: Int, CaseIterable { case launching, intro, lobby, tutorial, table
        var name: String { ["launching", "intro", "lobby", "tutorial", "table"][rawValue] }
    }
    private(set) var step: Step = .launching
    /// Every step entered, in order (QA: exposed as `flowLog=` on the scene).
    private(set) var log: [Step] = []
    /// Starters: return true if the step really began (it must later call `done`), false to skip it.
    var startIntro: () -> Bool = { false }
    var startLobby: () -> Bool = { false }
    var startTutorial: () -> Bool = { false }
    /// Runs once when the table is reached (Game Center sign-in…).
    var arrivedAtTable: () -> Void = {}

    func begin() { guard step == .launching, log.isEmpty else { return }; advance(after: .launching) }
    /// The current step finished. Ignored if `s` is not the current step (late or duplicate signal).
    func done(_ s: Step) { guard s == step, s != .table, s != .launching else { return }; advance(after: s) }

    private func advance(after s: Step) {
        var next = s.rawValue + 1
        while let candidate = Step(rawValue: next) {
            step = candidate; log.append(candidate)
            let began: Bool
            switch candidate {
            case .launching: began = false
            case .intro: began = startIntro()
            case .lobby: began = startLobby()
            case .tutorial: began = startTutorial()
            case .table: arrivedAtTable(); return
            }
            if began || step != candidate { return }   // began, or its starter already signalled done
            next += 1
        }
    }
    var logText: String { log.map { $0.name }.joined(separator: ">") }
}

/// QA launch arguments (`--*-qa`, `--fresh-*`). CI screenshots and XCTest run the Debug build (Verify-on-Mac.command);
/// the IPA is Release (Build-Unsigned-IPA.command), where every QA argument reads as absent (0.45 M5.6).
enum QA {
    #if DEBUG
    static let arguments = ProcessInfo.processInfo.arguments
    #else
    static let arguments: [String] = []
    #endif
    static func has(_ flag: String) -> Bool { arguments.contains(flag) }
    /// Any `--…qa` flag or --visual-qa (probe / UI-test launch).
    static var anyQA: Bool { arguments.contains { $0.hasPrefix("--") && $0.hasSuffix("qa") } }
    static var anyFlag: Bool { arguments.contains { $0.hasPrefix("--") } }
}
