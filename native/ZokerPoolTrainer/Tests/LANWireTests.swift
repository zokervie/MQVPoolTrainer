import Foundation

/// Foundation-only protocol checks. Actual MCSession discovery/reconnection needs two devices.
@main struct LANWireTests {
    struct Failure: Error, CustomStringConvertible { var description: String }

    static func main() throws {
        var checks = 0
        func check(_ condition: Bool, _ message: String) throws {
            guard condition else { throw Failure(description: message) }
            checks += 1
        }
        func mustThrow(_ message: String, _ body: () throws -> Void) throws {
            var rejected = false
            do { try body() } catch { rejected = true }
            try check(rejected, message)
        }

        let match = UUID().uuidString
        let cue = LANBall(id: 0, x: 0.1, y: -0.8, vx: 1.2, vy: -0.2,
                          wx: 3, wy: 4, spin: 12, height: 0.03, vertical: -0.4,
                          qx: 0, qy: 0.6, qz: 0, qw: 0.8, sunk: false, rails: 2)
        var state = LANSnapshot(matchID: match, revision: 7, shotID: 3, elapsed: 1.25,
                                balls: [cue, LANBall(id: 1, x: -0.2, y: 0.4)],
                                currentPlayer: 1, isMoving: false,
                                rulesJSON: Data("{\"game\":\"nineBall\",\"ballInHand\":false}".utf8))
        try check(state.isValid, "complete finite state must be valid")
        var envelope = LANEnvelope(roomCode: "123456", matchID: match, sequence: 1, kind: .snapshot)
        envelope.snapshot = state
        let bytes = try LANWireCodec.encode(envelope)
        let decoded = try LANWireCodec.decode(bytes)
        try check(decoded.snapshot == state, "wire roundtrip must preserve all velocity, spin, height and quaternion values")
        try check(decoded.snapshot?.rulesDictionary?["game"] as? String == "nineBall", "rules JSON roundtrip")

        var badState = state
        badState.balls.append(cue)
        try check(!badState.isValid, "duplicate ball IDs must be rejected")
        badState = state; badState.balls[0].x = .nan
        try check(!badState.isValid, "NaN position must be rejected")
        envelope.snapshot = badState
        try mustThrow("NaN cannot be serialized onto the wire") { _ = try LANWireCodec.encode(envelope) }
        badState = state; badState.balls[0].spin = .infinity
        try check(!badState.isValid, "infinite spin must be rejected")
        badState = state; badState.rulesJSON = Data("[]".utf8)
        try check(!badState.isValid, "rules must be a JSON object")
        badState = state; badState.rulesJSON = Data(repeating: 32, count: 16_385)
        try check(!badState.isValid, "oversized rule state must be rejected")
        badState = state; badState.balls[0].height = -1
        try check(!badState.isValid, "invalid ball height must be rejected")

        envelope.snapshot = state
        envelope.version = LANEnvelope.protocolVersion + 1
        let incompatible = try JSONEncoder().encode(envelope)
        try mustThrow("different protocol version must be refused") { _ = try LANWireCodec.decode(incompatible) }
        envelope.version = LANEnvelope.protocolVersion
        envelope.roomCode = "１２３４５６"
        try mustThrow("room codes are six ASCII digits") { _ = try LANWireCodec.encode(envelope) }
        envelope.roomCode = "123456"; envelope.matchID = "old-room"
        try mustThrow("invalid match identity must be refused") { _ = try LANWireCodec.encode(envelope) }
        envelope.matchID = match; envelope.sequence = 0
        try mustThrow("sequence zero must be refused") { _ = try LANWireCodec.encode(envelope) }
        envelope.sequence = 1; envelope.kind = .rejected; envelope.snapshot = nil
        envelope.message = String(repeating: "x", count: LANEnvelope.maximumBytes)
        try mustThrow("encoded packets must obey the 128 KiB cap") { _ = try LANWireCodec.encode(envelope) }
        try mustThrow("oversized incoming packets must be rejected before decoding") {
            _ = try LANWireCodec.decode(Data(repeating: 0, count: LANEnvelope.maximumBytes + 1))
        }
        try mustThrow("malformed JSON must be rejected") { _ = try LANWireCodec.decode(Data("{".utf8)) }

        let shot = LANShot(angle: .pi / 2, speed: 2.5, side: 0.3, top: 0,
                           elevation: 0, cueType: 0)
        let command = LANCommand(matchID: match, expectedRevision: 7, player: 1, action: .strike, shot: shot)
        try check(LANAuthorityGate.allows(command, snapshot: state, matchID: match, expectedPlayer: 1), "current seat and revision must be accepted")
        try check(!LANAuthorityGate.allows(command, snapshot: state, matchID: match, expectedPlayer: 0), "guest cannot impersonate the host seat")
        var wrong = command; wrong.expectedRevision = 6
        try check(!LANAuthorityGate.allows(wrong, snapshot: state, matchID: match, expectedPlayer: 1), "stale revision must not mutate the host world")
        wrong = command; wrong.matchID = UUID().uuidString
        try check(!LANAuthorityGate.allows(wrong, snapshot: state, matchID: match, expectedPlayer: 1), "commands from a previous match must be rejected")
        try check(!LANAuthorityGate.allows(command, snapshot: state, matchID: match, expectedPlayer: 1,
                                          alreadyProcessed: Set([command.id])), "duplicate command UUID must be rejected")
        try check(!LANAuthorityGate.allows(command, snapshot: state, matchID: match, expectedPlayer: 1,
                                          consumedRevision: 7), "two distinct commands cannot consume the same host revision")
        state.currentPlayer = 0
        try check(!LANAuthorityGate.allows(command, snapshot: state, matchID: match, expectedPlayer: 1), "wrong-turn shots must be rejected")
        state.currentPlayer = 1; state.isMoving = true
        try check(!LANAuthorityGate.allows(command, snapshot: state, matchID: match, expectedPlayer: 1), "another stroke during motion must be rejected")
        let concede = LANCommand(matchID: match, expectedRevision: 7, player: 1, action: .concede)
        try check(LANAuthorityGate.allows(concede, snapshot: state, matchID: match, expectedPlayer: 1), "a player may concede while the balls move")
        state.isPaused = true
        try check(!LANAuthorityGate.allows(concede, snapshot: state, matchID: match, expectedPlayer: 1), "a disconnected/paused match must not accept actions")
        state.isPaused = false; state.isMoving = false

        wrong = command; wrong.shot?.speed = 50
        try check(!wrong.isValid, "out-of-range force must be rejected")
        wrong = command; wrong.placement = LANPlacement(x: 0, y: 0)
        try check(!wrong.isValid, "one command cannot carry two different action payloads")
        wrong = command; wrong.shot?.cueType = 3
        try check(!wrong.isValid, "UI masse preset 3 must map to core cue type 0")
        let call = LANCommand(matchID: match, expectedRevision: 7, player: 1, action: .callShot,
                              call: LANCall(ball: 10, pocket: 5))
        try check(call.isValid, "called ball and pocket must survive typed transport")
        let option = LANCommand(matchID: match, expectedRevision: 7, player: 1, action: .chooseOption, option: "pass")
        try check(option.isValid, "pending-rule option must survive typed transport")

        try check(LANAuthorityGate.acceptsSnapshot(state, matchID: match, lastRevision: nil,
                                                  awaitingFullSync: true), "initial complete snapshot must be accepted")
        try check(LANAuthorityGate.acceptsSnapshot(state, matchID: match, lastRevision: 7,
                                                  awaitingFullSync: true), "reconnect must accept a full snapshot at the unchanged revision")
        try check(!LANAuthorityGate.acceptsSnapshot(state, matchID: match, lastRevision: 7,
                                                   awaitingFullSync: false), "ordinary duplicate snapshots must be ignored")
        try check(!LANAuthorityGate.acceptsSnapshot(state, matchID: match, lastRevision: 8,
                                                   awaitingFullSync: true), "reconnect must not roll state backwards")
        // Online room codes and relay seat tokens.
        let online = OnlineRoomCode.make()
        try check(OnlineRoomCode.isValid(online), "generated online code must validate")
        try check(!OnlineRoomCode.isValid("AB0CDEFG") && !OnlineRoomCode.isValid("ABCDEFG"), "ambiguous or short codes must be refused")
        try check(OnlineRoomCode.normalized(" ab2c-def9 ") == "AB2CDEF9", "codes are entered case-insensitively")
        let token = OnlineRoomCode.makeToken()
        try check(token.count == 32 && token.allSatisfy { "0123456789abcdef".contains($0) }, "relay token must be 32 lowercase hex")
        let onlineEnvelope = LANEnvelope(roomCode: online, matchID: match, sequence: 1, kind: .ping)
        try check((try LANWireCodec.decode(try LANWireCodec.encode(onlineEnvelope))).roomCode == online, "online code must pass the codec")

        // Playout clock: steady 10 Hz with jitter never stalls and stays behind the newest sample.
        var playout = PlayoutClock()
        var clock = 0.0, latest = 0.0, stalls = 0, now = 0.0, nextArrival = 0.0, hostTime = 0.0
        var jitterSeed: UInt64 = 7
        for _ in 0..<1200 { // 20 s at 60 Hz
            now += 1.0 / 60
            while nextArrival <= now {
                latest = hostTime
                playout.observe(arrival: nextArrival, elapsed: hostTime)
                hostTime += 0.1
                jitterSeed = jitterSeed &* 6364136223846793005 &+ 1442695040888963407
                nextArrival = hostTime + 0.05 + Double(jitterSeed >> 40) / Double(1 << 24) * 0.18
            }
            let next = playout.advance(clock: clock, dt: 1.0 / 60, latest: latest, moving: true)
            if now > 2, next - clock < 0.25 / 60 { stalls += 1 }
            try check(next <= latest + 1e-9, "playout must not pass the newest host sample")
            clock = next
        }
        try check(stalls < 30, "jittered stream must play without long stalls (stalls=\(stalls))")
        try check(playout.delay > PlayoutClock.minimumDelay && playout.delay <= PlayoutClock.maximumDelay, "delay adapts within bounds")
        try check(playout.advance(clock: 1, dt: 0.1, latest: 1.05, moving: false) == 1.05, "settled shot runs to its end")

        // Hermite curve: endpoints exact; straight constant-velocity roll stays linear.
        let a = LANBall(id: 3, x: 0, y: 0, vx: 1, vy: 0), b = LANBall(id: 3, x: 0.1, y: 0, vx: 1, vy: 0)
        try check(SnapshotCurve.eligible(a, b), "straight roll uses the curve")
        let mid = SnapshotCurve.position(a, b, interval: 0.1, fraction: 0.5)
        try check(abs(mid.x - 0.05) < 1e-12 && abs(mid.y) < 1e-12, "constant velocity matches linear")
        let end = SnapshotCurve.position(a, b, interval: 0.1, fraction: 1)
        try check(abs(end.x - 0.1) < 1e-12, "curve ends at the next sample")
        var railed = b; railed.rails = 1; railed.vx = -0.8
        try check(!SnapshotCurve.eligible(a, railed), "rail contact falls back to linear")
        var sunk = b; sunk.sunk = true
        try check(!SnapshotCurve.eligible(a, sunk), "pocketed ball falls back to linear")
        print("PASS LAN wire: \(checks) production codec/authority/roundtrip validation checks; two-device transport NOT_RUN")
    }
}
