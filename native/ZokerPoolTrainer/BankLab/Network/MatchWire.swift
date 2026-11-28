import Foundation
import os

/// Bounded wire data. 0.44: the guest runs the SAME deterministic solver from `LANShotStart` (lockstep) and the host's
/// snapshots verify it; if they ever disagree the guest falls back to presenting the host snapshots.
struct LANBall: Codable, Equatable {
    var id: Int
    var x: Double
    var y: Double
    var vx: Double = 0
    var vy: Double = 0
    var wx: Double = 0
    var wy: Double = 0
    var spin: Double = 0
    var height: Double = 0
    var vertical: Double = 0
    var qx: Double = 0
    var qy: Double = 0
    var qz: Double = 0
    var qw: Double = 1
    var sunk: Bool = false
    var rails: Int = 0

    var isValid: Bool {
        let values = [x, y, vx, vy, wx, wy, spin, height, vertical, qx, qy, qz, qw]
        return (0...15).contains(id) && values.allSatisfy { $0.isFinite } &&
            abs(x) <= 10 && abs(y) <= 10 && abs(vx) <= 100 && abs(vy) <= 100 &&
            abs(wx) <= 100_000 && abs(wy) <= 100_000 && abs(spin) <= 100_000 &&
            height >= -0.01 && height <= 10 && abs(vertical) <= 100 &&
            [qx, qy, qz, qw].allSatisfy { abs($0) <= 2 } && (0...100_000).contains(rails)
    }
}

struct LANShot: Codable, Equatable {
    var angle: Double
    var speed: Double
    var side: Double
    var top: Double
    var elevation: Double
    var cueType: Int

    var isValid: Bool {
        [angle, speed, side, top, elevation].allSatisfy { $0.isFinite } &&
            abs(angle) <= 1_000_000 && speed > 0 && speed <= 8 &&
            hypot(side, top) <= 0.711 && (0...90).contains(elevation) && (0...2).contains(cueType)
    }
}

/// 0.41 (owner: "đối thủ đang đánh không thấy hình cơ"): the shooter's live cue pose, ~15 Hz, display only — it never
/// changes the table. pull 0…1 = how far the cue is drawn back.
struct LANAim: Codable, Equatable {
    var angle: Double
    var side: Double = 0
    var top: Double = 0
    var elevation: Double = 0
    var pull: Double = 0
    var cueType: Int = 0
    var visible: Bool = true
    var isValid: Bool {
        [angle, side, top, elevation, pull].allSatisfy { $0.isFinite } && abs(angle) <= 1_000_000 &&
            hypot(side, top) <= 0.711 && (0...90).contains(elevation) && (0...1).contains(pull) && (0...2).contains(cueType)
    }
}

struct LANPlacement: Codable, Equatable {
    var x: Double
    var y: Double
    var isValid: Bool { x.isFinite && y.isFinite && abs(x) <= 10 && abs(y) <= 10 }
}

struct LANCall: Codable, Equatable {
    var ball: Int
    var pocket: Int
    var safety: Bool = false
    var isValid: Bool {
        safety ? (0...15).contains(ball) && (-1...5).contains(pocket) :
            (1...15).contains(ball) && (0...5).contains(pocket)
    }
}

/// 0.53 A3.2: one sound per pocket drop. The guest has two audio sources for a shot (its own lockstep solver and the host's snapshot events);
/// whichever delivers a drop first claims (shot, ball, pocket) and the other stays silent, also across a mid-shot fallback.
struct PocketSoundLedger {
    private var shot = Int.min
    private var claimed = Set<String>()
    mutating func firstTime(shot id: Int, event: LANEvent) -> Bool {
        if id != shot { shot = id; claimed.removeAll() }
        guard event.kind == 2 else { return true }
        return claimed.insert("\(event.a)|\(event.b)").inserted
    }
}

struct LANEvent: Codable, Equatable {
    var index: Int
    var kind: Int
    var a: Int
    var b: Int
    var time: Double
    var x: Double
    var y: Double
    var impact: Double
    var isValid: Bool {
        (0...100_000).contains(index) && (0...2).contains(kind) && (0...15).contains(a) &&
            (-1...15).contains(b) && [time, x, y, impact].allSatisfy { $0.isFinite } &&
            (0...86_400).contains(time) && abs(x) <= 10 && abs(y) <= 10 && (0...100).contains(impact)
    }
}

struct LANCommand: Codable, Equatable {
    enum Action: String, Codable {
        case strike, placeCue, callShot, declarePushOut, acceptPushOut, returnPushOut, chooseOption, concede
    }
    var id: String = UUID().uuidString
    var matchID: String = ""
    var expectedRevision: UInt64 = 0
    var player: Int
    var action: Action
    var shot: LANShot? = nil
    var placement: LANPlacement? = nil
    var call: LANCall? = nil
    var option: String? = nil

    var isValid: Bool {
        guard UUID(uuidString: id) != nil, (0...1).contains(player),
              matchID.isEmpty || UUID(uuidString: matchID) != nil else { return false }
        switch action {
        case .strike:
            return shot?.isValid == true && placement == nil && call == nil && option == nil
        case .placeCue:
            return placement?.isValid == true && shot == nil && call == nil && option == nil
        case .callShot:
            return call?.isValid == true && shot == nil && placement == nil && option == nil
        case .chooseOption:
            guard let option = option, !option.isEmpty, option.utf8.count <= 40,
                  option.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-" )).contains($0) }) else { return false }
            return shot == nil && placement == nil && call == nil
        case .declarePushOut, .acceptPushOut, .returnPushOut, .concede:
            return shot == nil && placement == nil && call == nil && option == nil
        }
    }
}

struct LANSnapshot: Codable, Equatable {
    var matchID: String = ""
    var revision: UInt64 = 0
    var shotID: Int = 0
    var elapsed: Double = 0
    var balls: [LANBall]
    var currentPlayer: Int
    var isMoving: Bool
    var isPaused: Bool = false
    var angle: Double = 0
    var events: [LANEvent] = []
    /// Host-generated BLMatch state, JSON object only; max 16 KiB. No hints or predicted paths.
    var rulesJSON: Data = Data("{}".utf8)

    var rulesDictionary: [String: Any]? {
        (try? JSONSerialization.jsonObject(with: rulesJSON)) as? [String: Any]
    }
    var isValid: Bool {
        guard matchID.isEmpty || UUID(uuidString: matchID) != nil,
              (0...1).contains(currentPlayer), (0...1_000_000_000).contains(shotID),
              elapsed.isFinite, (0...86_400).contains(elapsed), angle.isFinite, abs(angle) <= 1_000_000,
              !balls.isEmpty, balls.count <= 16, balls.allSatisfy({ $0.isValid }),
              Set(balls.map { $0.id }).count == balls.count, balls.contains(where: { $0.id == 0 }),
              events.count <= 128, events.allSatisfy({ $0.isValid }),
              Set(events.map { $0.index }).count == events.count,
              rulesJSON.count <= 16_384, rulesDictionary != nil else { return false }
        return true
    }
}

/// 0.44 lockstep (owner item 2: Wi‑Fi play "không mượt như lúc tập"): everything the guest needs to run the same
/// fixed-step solver for one shot — the normalised pre-strike balls, the exact strike the host's world received (angle
/// after squirt) and every physics setting. Both devices then simulate at 960 Hz locally; the host stays authoritative.
struct LANShotStart: Codable, Equatable {
    var shotID: Int
    var balls: [LANBall]
    var angle: Double
    var speed: Double
    var side: Double
    var top: Double
    var settings: [String: Double]
    var isValid: Bool {
        (0...1_000_000_000).contains(shotID) && !balls.isEmpty && balls.count <= 16 && balls.allSatisfy({ $0.isValid }) &&
            Set(balls.map { $0.id }).count == balls.count && [angle, speed, side, top].allSatisfy({ $0.isFinite }) &&
            abs(angle) <= 1_000_000 && speed > 0 && speed <= 8 && hypot(side, top) <= 0.711 &&
            settings.count <= 128 && settings.values.allSatisfy({ $0.isFinite }) && settings.keys.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 64 })
    }
}

/// One protocol version for rules/physics compatibility. A mismatched client is refused.
struct LANEnvelope: Codable {
    enum Kind: String, Codable { case hello, snapshot, command, accepted, rejected, events, ping, pong, leave, aim, shotStart }
    static let protocolVersion = 2   // 0.44: shotStart (lockstep)
    static let maximumBytes = 131_072
    var version: Int = LANEnvelope.protocolVersion
    var roomCode: String
    var matchID: String
    var sequence: UInt64
    var kind: Kind
    var role: String? = nil
    var game: String? = nil
    var snapshot: LANSnapshot? = nil
    var command: LANCommand? = nil
    var events: [LANEvent]? = nil
    var shotID: Int? = nil
    var message: String? = nil
    var aim: LANAim? = nil
    var shotStart: LANShotStart? = nil
    /// 0.58c: sent with MC `.unreliable` (moving snapshots, aim). Such packets are ordered on their own counter so a
    /// late one can never make the receiver drop a reliable packet that carries a lower sequence. nil = reliable.
    var unreliable: Bool? = nil
}

/// The same gate used by the live host and protocol regression harness.
enum LANAuthorityGate {
    static func allows(_ command: LANCommand, snapshot: LANSnapshot, matchID: String,
                       expectedPlayer: Int, alreadyProcessed: Set<String> = [],
                       consumedRevision: UInt64? = nil, epochRevision: UInt64? = nil) -> Bool {
        denyReason(command, snapshot: snapshot, matchID: matchID, expectedPlayer: expectedPlayer,
                   alreadyProcessed: alreadyProcessed, consumedRevision: consumedRevision, epochRevision: epochRevision) == nil
    }
    /// 0.58c: nil = allowed; otherwise a short reason for the log and for the "never swallow a shot" message.
    static func denyReason(_ command: LANCommand, snapshot: LANSnapshot, matchID: String,
                           expectedPlayer: Int, alreadyProcessed: Set<String> = [],
                           consumedRevision: UInt64? = nil, epochRevision: UInt64? = nil) -> String? {
        // 0.44 (owner: "đã hiện lực mà không ra cơ" in Wi-Fi play). Exact revision equality rejected a stroke whenever the
        // host re-published something cosmetic (aim angle, pause flag, audio events) between the guest's last snapshot
        // and the command. The host now passes the revision at which the current game state (balls, turn, rules, motion)
        // began: any revision inside that epoch describes the same table, so the command is still valid.
        let revisionOK: Bool
        if let epoch = epochRevision, epoch <= snapshot.revision {
            revisionOK = command.expectedRevision >= epoch && command.expectedRevision <= snapshot.revision
        } else {
            revisionOK = command.expectedRevision == snapshot.revision
        }
        if !command.isValid { return "command-invalid" }
        if !snapshot.isValid { return "snapshot-invalid" }
        if !(0...1).contains(expectedPlayer) { return "player-range" }
        if UUID(uuidString: matchID) == nil || snapshot.matchID != matchID || command.matchID != matchID { return "match-id" }
        if command.player != expectedPlayer { return "wrong-player" }
        if !revisionOK {
            let epochText = epochRevision.map { String($0) } ?? "-"
            return "revision(cmd \(command.expectedRevision) snap \(snapshot.revision) epoch \(epochText))"
        }
        if snapshot.isPaused { return "snapshot-paused" }
        if let consumed = consumedRevision, command.expectedRevision <= consumed { return "revision-consumed(\(consumed))" }
        if alreadyProcessed.contains(command.id) { return "duplicate-command" }
        if command.action != .concede {
            if snapshot.isMoving { return "table-moving" }
            if snapshot.currentPlayer != expectedPlayer { return "not-your-turn(current \(snapshot.currentPlayer))" }
        }
        return nil
    }
    static func acceptsSnapshot(_ value: LANSnapshot, matchID: String, lastRevision: UInt64?,
                                awaitingFullSync: Bool) -> Bool {
        guard value.isValid, value.matchID == matchID else { return false }
        guard let previous = lastRevision else { return true }
        return value.revision > previous || (awaitingFullSync && value.revision == previous)
    }
}

/// 0.58c: timestamped network log (os_log + a ring buffer the QA harness and the "Mất kết nối" overlay can read).
/// One line per event: MCSession state, remoteReady/isConnected, why input is blocked, why the gate refused, send time.
enum LANLog {
    private static let logger = Logger(subsystem: "vn.zoker.pool", category: "lan")
    private static let lock = NSLock()
    private static var ring: [String] = []
    static var echo = ProcessInfo.processInfo.arguments.contains("--lan-log")
    static func log(_ tag: String, _ message: @autoclosure () -> String) {
        let line = String(format: "%.3f [%@] ", ProcessInfo.processInfo.systemUptime, tag) + message()
        lock.lock(); ring.append(line); if ring.count > 4000 { ring.removeFirst(ring.count - 4000) }; lock.unlock()   // 0.59 ZB-037: 4000 lines = a whole match
        logger.notice("\(line, privacy: .public)")
        if echo { print("LANLOG " + line) }
    }
    static var lines: [String] { lock.lock(); defer { lock.unlock() }; return ring }
}

/// 0.58c: tracks the newest queued snapshot so a background sender can drop stale ones when the queue backs up.
final class LANStaleGate {
    private let lock = NSLock()
    private var newest: UInt64 = 0
    func noteQueued(_ sequence: UInt64) { lock.lock(); newest = max(newest, sequence); lock.unlock() }
    func isStale(_ sequence: UInt64) -> Bool { lock.lock(); defer { lock.unlock() }; return sequence < newest }
}

enum LANWireError: Error { case tooLarge, incompatibleVersion, malformedEnvelope }

enum LANWireCodec {
    static func encode(_ packet: LANEnvelope) throws -> Data {
        try validateHeader(packet)
        let data = try JSONEncoder().encode(packet)
        guard data.count <= LANEnvelope.maximumBytes else { throw LANWireError.tooLarge }
        return data
    }
    static func decode(_ data: Data) throws -> LANEnvelope {
        guard data.count <= LANEnvelope.maximumBytes else { throw LANWireError.tooLarge }
        let packet = try JSONDecoder().decode(LANEnvelope.self, from: data)
        try validateHeader(packet)
        return packet
    }
    private static func validateHeader(_ packet: LANEnvelope) throws {
        guard packet.version == LANEnvelope.protocolVersion else { throw LANWireError.incompatibleVersion }
        let nearbyCode = packet.roomCode.utf8.count == 6 && packet.roomCode.utf8.allSatisfy({ (48...57).contains($0) })
        guard nearbyCode || OnlineRoomCode.isValid(packet.roomCode),
              UUID(uuidString: packet.matchID) != nil, packet.sequence > 0 else {
            throw LANWireError.malformedEnvelope
        }
    }
}

/// Internet rooms: 8 symbols without 0/O/1/I (same alphabet as Server/relay).
enum OnlineRoomCode {
    static let alphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
    static func make() -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<8).map { _ in alphabet[Int(generator.next(upperBound: UInt64(alphabet.count)))] })
    }
    static func normalized(_ text: String) -> String {
        text.uppercased().filter { !$0.isWhitespace && $0 != "-" }
    }
    static func isValid(_ code: String) -> Bool {
        code.count == 8 && code.allSatisfy { alphabet.contains($0) }
    }
    /// 32 lowercase hex characters: the relay seat secret for one device and room.
    static func makeToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<16).map { _ in String(format: "%02x", Int(generator.next(upperBound: UInt64(256)))) }.joined()
    }
}

/// Guest playout clock for snapshots that arrive with network jitter.
/// It trails the newest host time by an adaptive delay and steers at 0.92-1.08x,
/// so a late packet slows motion slightly instead of freezing it.
struct PlayoutClock {
    static let minimumDelay = 0.12, maximumDelay = 0.45
    private(set) var delay = PlayoutClock.minimumDelay
    private(set) var jitter = 0.0
    private var baseline: Double?

    /// New connection or match: forget everything.
    mutating func reset() { jitter = 0; baseline = nil; delay = Self.minimumDelay }
    /// Host shot time restarts at 0 each shot; keep the learned jitter so the
    /// first frames of the next shot already have a fitting buffer.
    mutating func beginShot() { baseline = nil }

    /// arrival: local uptime when a moving snapshot arrived; elapsed: host shot time.
    mutating func observe(arrival: Double, elapsed: Double) {
        guard arrival.isFinite, elapsed.isFinite else { return }
        let offset = arrival - elapsed
        // Earliest-seen offset approximates the fastest path; it is slowly
        // forgotten so a lasting route change is not treated as jitter forever.
        let base = min(offset, (baseline ?? offset) + 0.002)
        baseline = base
        jitter += (offset - base - jitter) / 8
        delay = min(Self.maximumDelay, max(Self.minimumDelay, 0.06 + 3.0 * jitter))
    }

    func advance(clock: Double, dt: Double, latest: Double, moving: Bool) -> Double {
        guard dt > 0 else { return min(clock, latest) }
        guard moving else { return min(latest, clock + dt) }
        let error = (latest - delay) - clock
        if error > 0.6 { return latest - delay }
        let rate = min(1.08, max(0.92, 1 + 0.5 * error))
        return min(latest, clock + dt * rate)
    }
}

/// Cubic Hermite between two host samples using their velocities. Used only
/// when the ball rolls straight on through the interval (no rail, pocket or
/// sharp turn); otherwise callers keep linear interpolation.
enum SnapshotCurve {
    static func eligible(_ a: LANBall, _ b: LANBall) -> Bool {
        guard a.id == b.id, !a.sunk, !b.sunk, a.rails == b.rails, a.height < 0.002, b.height < 0.002 else { return false }
        let va = hypot(a.vx, a.vy), vb = hypot(b.vx, b.vy)
        guard va > 0.02, vb > 0.02 else { return false }
        return (a.vx * b.vx + a.vy * b.vy) / (va * vb) > 0.8
    }
    static func position(_ a: LANBall, _ b: LANBall, interval h: Double, fraction t: Double) -> (x: Double, y: Double) {
        let t = max(0, min(1, t)), t2 = t * t, t3 = t2 * t
        let h00 = 2 * t3 - 3 * t2 + 1, h10 = t3 - 2 * t2 + t, h01 = -2 * t3 + 3 * t2, h11 = t3 - t2
        return (h00 * a.x + h10 * h * a.vx + h01 * b.x + h11 * h * b.vx,
                h00 * a.y + h10 * h * a.vy + h01 * b.y + h11 * h * b.vy)
    }
}
