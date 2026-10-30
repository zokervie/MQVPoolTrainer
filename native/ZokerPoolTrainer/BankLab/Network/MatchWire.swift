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
        guard packet.roomCode.utf8.count == 6, packet.roomCode.utf8.allSatisfy({ (48...57).contains($0) }),
              UUID(uuidString: packet.matchID) != nil, packet.sequence > 0 else {
            throw LANWireError.malformedEnvelope
        }
    }
}
