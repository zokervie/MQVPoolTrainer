import Foundation

/// 0.45 M5.3: launch flow intro → Lobby → (tutorial) → table: order, skips, no step twice, late signals ignored.
@main struct AppFlowTests {
    struct Failure: Error, CustomStringConvertible { var description: String }
    static func main() throws {
        var checks = 0
        func check(_ ok: Bool, _ what: String) throws { guard ok else { throw Failure(description: what) }; checks += 1 }
        final class Rig {
            let flow = AppFlow(); var calls: [String] = []
            init(intro: Bool, lobby: Bool, tutorial: Bool) {
                flow.startIntro = { [unowned self] in calls.append("intro"); return intro }
                flow.startLobby = { [unowned self] in calls.append("lobby"); return lobby }
                flow.startTutorial = { [unowned self] in calls.append("tutorial"); return tutorial }
                flow.arrivedAtTable = { [unowned self] in calls.append("table") }
            }
        }
        // Fresh install: every step runs, in order, each only after the previous one reported done.
        let fresh = Rig(intro: true, lobby: true, tutorial: true)
        fresh.flow.begin()
        try check(fresh.flow.step == .intro && fresh.calls == ["intro"], "starts with the intro only")
        fresh.flow.done(.lobby); fresh.flow.done(.tutorial)
        try check(fresh.flow.step == .intro && fresh.calls == ["intro"], "out-of-order signals ignored")
        fresh.flow.done(.intro)
        try check(fresh.flow.step == .lobby && fresh.calls == ["intro", "lobby"], "Lobby after the intro")
        fresh.flow.done(.intro)
        try check(fresh.calls == ["intro", "lobby"], "duplicate intro finish does not reopen the Lobby")
        fresh.flow.done(.lobby)
        try check(fresh.flow.step == .tutorial && fresh.calls.last == "tutorial", "tutorial after the Lobby")
        fresh.flow.done(.tutorial)
        try check(fresh.flow.step == .table && fresh.calls == ["intro", "lobby", "tutorial", "table"], "table last")
        fresh.flow.done(.tutorial); fresh.flow.done(.table); fresh.flow.begin()
        try check(fresh.calls == ["intro", "lobby", "tutorial", "table"], "nothing runs twice after the table")
        try check(fresh.flow.logText == "intro>lobby>tutorial>table", "log \(fresh.flow.logText)")
        // Returning player: tutorial already seen → skipped, table right after the Lobby.
        let back = Rig(intro: true, lobby: true, tutorial: false)
        back.flow.begin(); back.flow.done(.intro); back.flow.done(.lobby)
        try check(back.flow.step == .table && back.calls == ["intro", "lobby", "tutorial", "table"], "tutorial asked once, skipped")
        // QA launch: no intro, no Lobby, no tutorial → straight to the table synchronously.
        let qa = Rig(intro: false, lobby: false, tutorial: false)
        qa.flow.begin()
        try check(qa.flow.step == .table && qa.calls == ["intro", "lobby", "tutorial", "table"], "all skipped → table at once")
        // --tutorial-qa: no intro / Lobby, tutorial forced.
        let tut = Rig(intro: false, lobby: false, tutorial: true)
        tut.flow.begin()
        try check(tut.flow.step == .tutorial, "forced tutorial waits for its done")
        tut.flow.done(.tutorial)
        try check(tut.flow.step == .table && tut.calls.filter { $0 == "table" }.count == 1, "table once")
        // Intro off, Lobby on.
        let noIntro = Rig(intro: false, lobby: true, tutorial: false)
        noIntro.flow.begin()
        try check(noIntro.flow.step == .lobby, "intro off → Lobby first")
        noIntro.flow.done(.intro)
        try check(noIntro.flow.step == .lobby && noIntro.calls.filter { $0 == "lobby" }.count == 1, "stale intro done after a skipped intro ignored")
        // A starter that re-enters (done called synchronously from inside its own start) must not double-run.
        let sync = AppFlow(); var syncCalls: [String] = []
        sync.startIntro = { syncCalls.append("intro"); return false }
        sync.startLobby = { syncCalls.append("lobby"); return true }
        sync.startTutorial = { syncCalls.append("tutorial"); return false }
        sync.arrivedAtTable = { syncCalls.append("table") }
        sync.begin(); sync.begin()
        try check(syncCalls == ["intro", "lobby"], "begin twice = once")
        // A starter that signals done synchronously and then reports "not started" must not skip twice.
        let reentrant = AppFlow(); var reCalls: [String] = []
        reentrant.startIntro = { [unowned reentrant] in reCalls.append("intro"); reentrant.done(.intro); return false }
        reentrant.startLobby = { reCalls.append("lobby"); return true }
        reentrant.begin()
        try check(reCalls == ["intro", "lobby"] && reentrant.step == .lobby, "re-entrant done: Lobby once (\(reCalls))")
        print("PASS AppFlow: \(checks) checks (order intro → Lobby → tutorial → table, skips, no step twice)")
    }
}
