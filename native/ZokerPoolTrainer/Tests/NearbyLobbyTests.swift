import Foundation

/// 0.44-mm Nearby Play room logic (Foundation only). Real discovery/invitations need two devices.
@main struct NearbyLobbyTests {
    struct Failure: Error, CustomStringConvertible { var description: String }
    static func main() throws {
        var checks = 0
        func check(_ ok: Bool, _ what: String) throws { guard ok else { throw Failure(description: what) }; checks += 1 }
        let v = 2
        func ad(_ code: String, _ host: String = "A", version: Int = 2) -> NearbyRoomAd {
            NearbyRoomAd(code: code, host: host, game: "nineBall", version: version, matchID: UUID().uuidString)
        }

        // Discovery state machine
        var guest = NearbyLobby(protocolVersion: v); guest.browse()
        try check(guest.phase == .browsing, "browse starts searching")
        try check(guest.roomFound(ad("111111", "Bình")) && guest.roomFound(ad("222222", "An")), "compatible rooms listed")
        try check(guest.rooms.map { $0.host } == ["An", "Bình"], "rooms sorted by host name")
        guest.roomFound(ad("111111", "Bình")); try check(guest.rooms.count == 2, "re-advertised room is not duplicated")
        try check(!guest.roomFound(ad("333333", version: 1)) && guest.incompatibleRooms == 1, "other app version counted, not listed")
        guest.roomFound(ad("333333", version: 1)); try check(guest.incompatibleRooms == 1, "same incompatible room counted once")
        try check(!guest.join(code: "999999"), "cannot join a room that was never seen")
        try check(guest.join(code: "111111") && guest.phase == .joining("111111"), "join a listed room")
        guest.roomLost(code: "111111"); try check(guest.phase == .failed(.roomGone), "room vanishing while joining fails clearly")

        // Connection lifecycle + reconnect
        guest.browse(); guest.roomFound(ad("222222")); _ = guest.join(code: "222222")
        guest.linkDown(now: 0); try check(guest.phase == .browsing, "a failed join returns to searching, not reconnecting")
        _ = guest.join(code: "222222"); guest.linkUp(now: 1); try check(guest.phase == .connected, "connected")
        guest.linkDown(now: 10); try check(guest.phase == .reconnecting(attempt: 1) && guest.reconnects == 1, "a drop starts reconnecting")
        try check(guest.tick(now: 10.5) == .none, "no retry before the first backoff")
        try check(guest.tick(now: 11) == .retry && guest.phase == .reconnecting(attempt: 2), "retry after 1 s")
        try check(guest.tick(now: 12.9) == .none && guest.tick(now: 13) == .retry, "then after 2 s")
        try check(guest.tick(now: 16.9) == .none && guest.tick(now: 17) == .retry, "then after 4 s")
        try check(guest.tick(now: 25) == .retry && guest.tick(now: 33) == .retry, "then every 8 s")
        guest.linkUp(now: 34); try check(guest.phase == .connected && guest.reconnectSuccesses == 1, "reconnect success counted")
        guest.linkDown(now: 100)
        var t = 100.0, gaveUp = false
        while t < 200 { t += 1; if guest.tick(now: t) == .giveUp { gaveUp = true; break } }
        try check(gaveUp && t == 100 + NearbyLobby.giveUpAfter, "gives up after 45 s, not before")
        try check(guest.phase == .failed(.reconnectTimedOut), "give-up keeps a clear failure (match kept, paused)")
        try check(guest.tick(now: 500) == .none, "no retries after giving up")
        guest.manualReconnect(now: 600); try check(guest.phase == .reconnecting(attempt: 1) && guest.tick(now: 600) == .retry, "manual Reconnect opens a fresh window")
        try check(NearbyLobby.giveUpAfter > 25, "give-up is longer than the 25 s background grace")

        // Invitations (host)
        var host = NearbyLobby(protocolVersion: v); host.host(mode: "eightBall")
        try check(host.mode == "eightBall" && host.phase == .hosting, "host keeps the chosen game")
        try check(host.invitation(from: "P1") == .ask, "first invitation asks the host")
        try check(host.invitation(from: "P1") == .ignoreDuplicate, "duplicate invitation from the same peer is ignored")
        try check(host.invitation(from: "P2") == .rejectBusy, "a second player is refused while the host decides")
        host.decide(accept: false); try check(host.phase == .hosting && host.pendingInvitation == nil, "rejecting keeps the room open")
        try check(host.invitation(from: "P1") == .rejectBusy, "a declined player is refused without asking again (MC retries)")
        try check(host.invitation(from: "P2") == .ask, "the next player can ask after a rejection")
        host.decide(accept: true); host.linkUp(now: 0)
        try check(host.invitation(from: "P3") == .rejectBusy, "a full room refuses others")
        host.linkDown(now: 1); try check(host.invitation(from: "P3") == .rejectBusy, "a stranger cannot take the seat during reconnect")

        // Join by typed code (no scan): straight to joining
        var typed = NearbyLobby(protocolVersion: v); typed.joinDirect(code: "555555")
        try check(typed.phase == .joining("555555"), "typed code joins without a scan")
        typed.linkUp(now: 0); try check(typed.phase == .connected, "typed join connects")

        // Ready / start
        var lobby = NearbyLobby(protocolVersion: v); lobby.host(mode: "nineBall")
        lobby.setReady(true); try check(!lobby.localReady && !lobby.canStart, "cannot be ready before a player connects")
        _ = lobby.invitation(from: "P"); lobby.decide(accept: true); lobby.linkUp(now: 0)
        lobby.setReady(true); try check(lobby.canStart, "ready once connected")
        lobby.linkDown(now: 1); try check(!lobby.canStart, "a drop blocks Start")
        lobby.leave(); try check(lobby.phase == .left && lobby.rooms.isEmpty && !lobby.localReady, "leave clears the room")

        // Guest rejected / failures
        var g2 = NearbyLobby(protocolVersion: v); g2.browse(); g2.roomFound(ad("444444")); _ = g2.join(code: "444444")
        g2.rejectedByHost(); try check(g2.phase == .failed(.rejected), "rejection is reported")
        for f in [NearbyFailure.incompatibleVersion, .rejected, .roomFull, .roomGone, .reconnectTimedOut, .permissionDenied] {
            try check(!f.vietnamese.isEmpty && !f.english.isEmpty, "every failure has a Vietnamese and English message")
        }

        // Quality
        var q = NearbyLobby(protocolVersion: v)
        try check(q.quality == 0 && q.rttMs == nil, "unknown quality without samples")
        for ms in [20.0, 22, 25, 21, 24] { q.roundTrip(ms / 1000) }
        try check(q.quality == 3 && abs((q.rttMs ?? 0) - 22) < 1e-9, "good LAN: ~22 ms median")
        var q2 = NearbyLobby(protocolVersion: v); for ms in [90.0, 100, 120, 95] { q2.roundTrip(ms / 1000) }
        try check(q2.quality == 2, "ok band")
        var q3 = NearbyLobby(protocolVersion: v); for ms in [30.0, 200, 40, 250] { q3.roundTrip(ms / 1000) }
        try check(q3.quality == 1, "high jitter is poor even with a low minimum")
        q3.roundTrip(.nan); q3.roundTrip(-1); q3.roundTrip(30); try check(q3.rtt.count == 4, "invalid and stale samples ignored")
        for _ in 0..<40 { q.roundTrip(0.02) }; try check(q.rtt.count == 20, "keeps the last 20 samples")

        print("PASS Nearby lobby: \(checks) room/connection/reconnect/invitation/quality checks; two-device discovery NOT_RUN")
    }
}
