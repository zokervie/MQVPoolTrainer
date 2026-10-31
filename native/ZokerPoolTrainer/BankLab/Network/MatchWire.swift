import Foundation

/// Bounded wire data. The guest presents host snapshots; it never advances a second solver.
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

/// One protocol version for rules/physics compatibility. A mismatched client is refused.
struct LANEnvelope: Codable {
    enum Kind: String, Codable { case hello, snapshot, command, accepted, rejected, events, ping, pong, leave }
    static let protocolVersion = 1
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
}

/// The same gate used by the live host and protocol regression harness.
enum LANAuthorityGate {
    static func allows(_ command: LANCommand, snapshot: LANSnapshot, matchID: String,
                       expectedPlayer: Int, alreadyProcessed: Set<String> = [],
                       consumedRevision: UInt64? = nil) -> Bool {
        guard command.isValid, snapshot.isValid, (0...1).contains(expectedPlayer),
              UUID(uuidString: matchID) != nil, snapshot.matchID == matchID,
              command.matchID == matchID, command.player == expectedPlayer,
              command.expectedRevision == snapshot.revision, !snapshot.isPaused,
              command.expectedRevision != consumedRevision,
              !alreadyProcessed.contains(command.id) else { return false }
        return command.action == .concede || (!snapshot.isMoving && snapshot.currentPlayer == expectedPlayer)
    }
    static func acceptsSnapshot(_ value: LANSnapshot, matchID: String, lastRevision: UInt64?,
                                awaitingFullSync: Bool) -> Bool {
        guard value.isValid, value.matchID == matchID else { return false }
        guard let previous = lastRevision else { return true }
        return value.revision > previous || (awaitingFullSync && value.revision == previous)
    }
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
