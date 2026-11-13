import Foundation
import MultipeerConnectivity
import GameKit
import UIKit

/// Two devices, no account. Nearby: MultipeerConnectivity. Internet: a WebSocket
/// relay (Server/relay) that only forwards bytes between the two seats of a room.
/// All public APIs and callbacks use the main thread. Both transports give ordered
/// reliable delivery and transport encryption (MCSession .required / TLS).
/// Host is seat 0 and the only solver/rules authority; guest is seat 1.
final class LocalMatchSession: NSObject {
    enum Role { case none, host, guest }
    enum Transport { case nearby, internet, gameCenter }
    static let serviceType = "zt-pool18"

    var onStateChanged: ((String) -> Void)?
    var onSnapshot: ((LANSnapshot) -> Void)?
    /// Host only: validate the rules, apply the command, return whether accepted.
    /// Publish the new state in onAcceptedCommand or the next display tick.
    var onCommand: ((LANCommand) -> Bool)?
    var onAcceptedCommand: ((LANCommand) -> Void)?
    var onEvents: (([LANEvent], Int) -> Void)?
    var onError: ((String) -> Void)?
    /// 0.41: the remote shooter's live cue pose (display only).
    var onAim: ((LANAim) -> Void)?
    /// 0.42: shared music chunks (same Wi-Fi only, MusicPlayer042 format).
    var onMusic: ((Data) -> Void)?

    private(set) var role: Role = .none
    private(set) var transport: Transport = .nearby
    private(set) var roomCode = ""
    private(set) var game = ""
    private(set) var latestSnapshot: LANSnapshot?
    private(set) var isApplyingCommand = false
    private(set) var connectionDescription = "Chưa vào phòng"
    var hasPendingCommand: Bool { awaitingCommandID != nil }
    var localPlayer: Int { role == .guest ? 1 : 0 }
    /// 0.41: 20 Hz on Wi‑Fi / Game Center (smoother guest playback), 10 Hz through the internet relay.
    var snapshotInterval: Double { transport == .internet ? 0.1 : 0.05 }
    var isConnected: Bool {
        remoteReady && (role == .host || snapshotReady) && !backgrounded && !protocolBlocked && linkUp
    }
    /// Transport-level link to exactly one peer.
    private var linkUp: Bool {
        switch transport {
        case .internet: return relay?.isOpen == true && relayPeerPresent
        case .gameCenter: return gameCenterMatch != nil && gameCenterPeerPresent
        case .nearby: return session?.connectedPeers.count == 1
        }
    }
    private var peerName: String {
        transport == .gameCenter ? (gameCenterMatch?.players.first?.displayName ?? "bạn Game Center")
            : (transport == .internet ? "bạn chơi online" : (reservedPeer?.displayName ?? "bạn chơi"))
    }
    private var relay: RelayLink?
    // 0.27 Game Center: Apple relays the bytes; no room code, no own server, free.
    private var gameCenterMatch: GKMatch?
    private var gameCenterPeerPresent = false
    private var relayPeerPresent = false
    private var relayToken = ""
    private var relayFailures = 0
    private let peerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var heartbeat: Timer?
    private var matchID = ""
    private var reservedPeer: MCPeerID?
    private var pendingPeer: MCPeerID?
    private var remoteReady = false
    private var snapshotReady = false
    private var backgrounded = false
    private var protocolBlocked = false
    private var generation = UUID()
    private var revision: UInt64 = 0
    private var sendSequence: UInt64 = 0
    private var receivedSequence: UInt64 = 0
    private var processedCommands: [String] = []
    private var acceptedByGuest: [String] = []
    private var consumedRevision: UInt64?
    private var awaitingCommandID: String?
    private var awaitingRevision: UInt64?
    private var deliveredEventShot = -1
    private var deliveredEventIndex = -1
    private var lastReceived = ProcessInfo.processInfo.systemUptime
    private var lastPing = 0.0
    private var lastPublished = -Double.infinity
    private var retryAt = 0.0
    private var inviteStarted = 0.0
    private var lastError = ""
    private var lastErrorAt = -Double.infinity

    override init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "lanPeerIdentity018"),
           let stored = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data) {
            peerID = stored
        } else {
            let value = MCPeerID(displayName: "Z-Trainer " + String(UUID().uuidString.suffix(4)))
            peerID = value
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true) {
                defaults.set(data, forKey: "lanPeerIdentity018")
            }
        }
        super.init()
        // 0.41 (owner: the other screen turning off froze the match). willResignActive also fires for Control Centre,
        // a notification banner or an incoming-call banner — the match was cut for each. Now only a real move to the
        // background counts, with a 25 s grace kept alive by a background task (quick app switch keeps the room).
        NotificationCenter.default.addObserver(self, selector: #selector(enterBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resume),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        heartbeat?.invalidate()
        relay?.close()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
    }

    @discardableResult func createRoom(game: String, internet: Bool = false) -> String {
        requireMain()
        leave()
        guard validGame(game) else { report("Thể loại trận không hợp lệ"); return "" }
        if internet && OnlineRelayConfig.url == nil {
            report("Chưa có địa chỉ máy chủ online. Vào Chơi theo luật → Máy chủ online."); return ""
        }
        role = .host
        transport = internet ? .internet : .nearby
        self.game = game
        roomCode = internet ? OnlineRoomCode.make() : String(Int.random(in: 100_000...999_999))
        relayToken = internet ? OnlineRelayConfig.token(for: roomCode, role: "host") : ""
        matchID = UUID().uuidString
        restartSession()
        startHeartbeat()
        describe(internet ? "Mã phòng online \(roomCode) · đang chờ bạn" : "Mã phòng \(roomCode) · đang chờ bạn")
        return roomCode
    }

    @discardableResult func joinRoom(code: String, internet: Bool = false) -> Bool {
        requireMain()
        let trimmed = internet ? OnlineRoomCode.normalized(code) : code.trimmingCharacters(in: .whitespacesAndNewlines)
        if internet {
            guard OnlineRoomCode.isValid(trimmed) else { report("Mã phòng online gồm 8 ký tự (chữ và số)"); return false }
            guard OnlineRelayConfig.url != nil else {
                report("Chưa có địa chỉ máy chủ online. Vào Chơi theo luật → Máy chủ online."); return false
            }
        } else {
            guard trimmed.utf8.count == 6, trimmed.utf8.allSatisfy({ (48...57).contains($0) }) else {
                report("Nhập mã phòng gồm 6 chữ số"); return false
            }
        }
        leave()
        role = .guest
        transport = internet ? .internet : .nearby
        roomCode = trimmed
        relayToken = internet ? OnlineRelayConfig.token(for: roomCode, role: "guest") : ""
        restartSession()
        startHeartbeat()
        describe(internet ? "Đang vào phòng online \(roomCode)" : "Đang tìm phòng \(roomCode) trên mạng gần đây")
        return true
    }

    /// 0.27: start a 1-vs-1 match found or invited through Game Center. Both devices call this with the same
    /// GKMatch; the seat is decided deterministically (lower gamePlayerID hosts), the host's `game` wins.
    func startGameCenter(match: GKMatch, game: String) {
        requireMain()
        leave()
        guard validGame(game) else { report("Thể loại trận không hợp lệ"); return }
        let me = GKLocalPlayer.local.gamePlayerID, other = match.players.first?.gamePlayerID ?? ""
        role = me < other ? .host : .guest
        transport = .gameCenter
        gameCenterMatch = match
        self.game = game
        roomCode = "GAMECENTER"
        matchID = role == .host ? UUID().uuidString : ""
        restartSession()
        startHeartbeat()
        describe(role == .host ? "Game Center · bạn là chủ bàn" : "Game Center · đang đồng bộ với chủ bàn")
    }

    func leave() {
        requireMain()
        if role != .none { send(kind: .leave) }
        generation = UUID()
        role = .none
        remoteReady = false; snapshotReady = false
        stopDiscovery()
        heartbeat?.invalidate(); heartbeat = nil
        session?.delegate = nil; session?.disconnect(); session = nil
        relay?.close(); relay = nil; relayPeerPresent = false; relayFailures = 0
        gameCenterMatch?.delegate = nil; gameCenterMatch?.disconnect(); gameCenterMatch = nil; gameCenterPeerPresent = false
        transport = .nearby; relayToken = ""
        roomCode = ""; game = ""; matchID = ""
        reservedPeer = nil; pendingPeer = nil
        latestSnapshot = nil; revision = 0; sendSequence = 0; receivedSequence = 0
        processedCommands.removeAll(); acceptedByGuest.removeAll()
        consumedRevision = nil; awaitingCommandID = nil; awaitingRevision = nil
        deliveredEventShot = -1; deliveredEventIndex = -1; isApplyingCommand = false
        backgrounded = false; protocolBlocked = false
        lastPublished = -Double.infinity
        endBackgroundGrace()
        describe("Chưa vào phòng")
    }

    /// Explicit retry after local-network permission/settings change. Same host match is retained.
    func reconnect() {
        requireMain()
        guard role != .none else { return }
        protocolBlocked = false
        backgrounded = false
        restartSession()
        describe("Đang nối lại phòng \(roomCode) · trận tạm dừng")
    }

    /// Publish actual host solver state. During motion, call each display tick; sends at most 10 Hz.
    /// Use force=true for start/end of shot, rule decisions and the first snapshot after connection.
    @discardableResult func publishSnapshot(_ value: LANSnapshot, force: Bool = false) -> Bool {
        requireMain()
        guard role == .host, value.isValid else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastPublished >= snapshotInterval - 0.002 else { return false }
        if !force, !value.isMoving, let previous = latestSnapshot, !previous.isMoving,
           previous.shotID == value.shotID, previous.balls == value.balls,
           previous.currentPlayer == value.currentPlayer, previous.isPaused == value.isPaused,
           previous.angle == value.angle, previous.rulesJSON == value.rulesJSON,
           previous.events == value.events { return false }
        lastPublished = now
        revision += 1
        var authoritative = value
        authoritative.matchID = matchID
        authoritative.revision = revision
        latestSnapshot = authoritative
        if isConnected { send(kind: .snapshot, snapshot: authoritative) }
        return true
    }

    /// Send audio impacts immediately rather than waiting for the next 10 Hz visual frame.
    func publishEvents(_ events: [LANEvent], shotID: Int) {
        requireMain()
        guard role == .host, isConnected, !events.isEmpty, events.count <= 128,
              events.allSatisfy({ $0.isValid }), (0...1_000_000_000).contains(shotID) else { return }
        send(kind: .events, events: events, shotID: shotID)
    }

    /// 0.41: the local shooter's cue pose for the other screen, at most ~15 Hz (display only, never authoritative).
    private var lastAimSent = -Double.infinity
    @discardableResult func publishAim(_ aim: LANAim) -> Bool {
        requireMain()
        let now = ProcessInfo.processInfo.systemUptime
        guard role != .none, isConnected, aim.isValid, now - lastAimSent >= 0.066 else { return false }
        lastAimSent = now
        return send(kind: .aim, aim: aim)
    }

    /// Host: true means applied by onCommand. Guest: true means queued; only snapshots confirm state.
    @discardableResult func submitCommand(_ command: LANCommand) -> Bool {
        requireMain()
        guard isConnected, command.isValid, command.player == localPlayer else { return false }
        if role == .host { return receiveHostCommand(command, player: 0) }
        guard awaitingCommandID == nil, let snapshot = latestSnapshot,
              LANAuthorityGate.allows(command, snapshot: snapshot, matchID: matchID,
                                     expectedPlayer: 1, alreadyProcessed: Set(acceptedByGuest)) else { return false }
        awaitingCommandID = command.id; awaitingRevision = command.expectedRevision
        let queued = send(kind: .command, command: command)
        if !queued { awaitingCommandID = nil; awaitingRevision = nil }
        return queued
    }

    private func requireMain() { precondition(Thread.isMainThread, "LocalMatchSession APIs require main thread") }
    private func validGame(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 64 &&
            value.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
    private func describe(_ value: String) {
        connectionDescription = value
        onStateChanged?(value)
    }
    private func report(_ value: String) {
        let now = ProcessInfo.processInfo.systemUptime
        guard value != lastError || now - lastErrorAt > 3 else { return }
        lastError = value; lastErrorAt = now
        onError?(value)
    }
    private func stopDiscovery() {
        advertiser?.delegate = nil; advertiser?.stopAdvertisingPeer(); advertiser = nil
        browser?.delegate = nil; browser?.stopBrowsingForPeers(); browser = nil
    }
    private func restartSession() {
        generation = UUID()
        remoteReady = false; snapshotReady = false
        pendingPeer = nil
        awaitingCommandID = nil; awaitingRevision = nil
        receivedSequence = 0
        stopDiscovery()
        session?.delegate = nil; session?.disconnect()
        if transport == .gameCenter {
            session = nil
            lastReceived = ProcessInfo.processInfo.systemUptime; retryAt = lastReceived
            gameCenterMatch?.delegate = self
            gameCenterPeerPresent = (gameCenterMatch?.players.count ?? 0) == 1
            if gameCenterPeerPresent { handleRelay(.peer(true)) }
            return
        }
        if transport == .internet {
            session = nil
            relay?.close(); relayPeerPresent = false
            lastReceived = ProcessInfo.processInfo.systemUptime
            retryAt = lastReceived
            guard !backgrounded, !protocolBlocked, let base = OnlineRelayConfig.url else { return }
            let link = RelayLink(base: base, code: roomCode, role: role == .host ? "host" : "guest", token: relayToken)
            let token = generation
            link.onEvent = { [weak self] event in
                guard let self = self, self.generation == token, self.relay === link else { return }
                self.handleRelay(event)
            }
            relay = link
            link.connect()
            return
        }
        let value = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        value.delegate = self
        session = value
        lastReceived = ProcessInfo.processInfo.systemUptime
        retryAt = lastReceived
        startDiscovery()
    }
    private func startDiscovery() {
        guard role != .none, !backgrounded, !protocolBlocked, transport == .nearby else { return }
        if role == .host {
            if advertiser == nil {
                advertiser = MCNearbyServiceAdvertiser(peer: peerID,
                    discoveryInfo: ["code": roomCode, "version": String(LANEnvelope.protocolVersion),
                                    "match": matchID, "game": game], serviceType: Self.serviceType)
                advertiser?.delegate = self
            }
            advertiser?.startAdvertisingPeer()
        } else {
            if browser == nil {
                browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
                browser?.delegate = self
            }
            browser?.startBrowsingForPeers()
        }
    }
    private func startHeartbeat() {
        heartbeat?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        heartbeat = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func tick() {
        guard role != .none, !backgrounded, !protocolBlocked else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if transport == .gameCenter {
            if linkUp && remoteReady {
                if now - lastReceived > 10 { describe("Mất tín hiệu Game Center · trận tạm dừng"); remoteReady = false; return }
                if now - lastPing >= 2 { lastPing = now; send(kind: .ping) }
            }
            return
        }
        if transport == .internet {
            if linkUp {
                if remoteReady && now - lastReceived > 10 {
                    describe("Mất tín hiệu · trận tạm dừng, đang nối lại")
                    restartSession()
                    return
                }
                if remoteReady && now - lastPing >= 2 { lastPing = now; send(kind: .ping) }
            } else if relay == nil && now - retryAt > min(30, 2 * pow(2, Double(min(relayFailures, 4)))) {
                restartSession() // backoff 2, 4, 8, 16, 30 s
            } else if let link = relay, !link.isOpen, now - retryAt > 15 {
                restartSession() // connection attempt stuck
            }
            return
        }
        if session?.connectedPeers.count == 1 {
            if now - lastReceived > 10 {
                describe("Mất tín hiệu · trận tạm dừng, đang nối lại")
                restartSession()
                return
            }
            if remoteReady && now - lastPing >= 2 { lastPing = now; send(kind: .ping) }
        } else if pendingPeer != nil && now - inviteStarted > 15 {
            describe("Chưa nối được · kiểm tra Wi-Fi và quyền Mạng cục bộ")
            restartSession()
        } else if now - retryAt > 5 {
            retryAt = now
            startDiscovery()
        }
    }

    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundDeadline: Timer?
    static let backgroundGrace = 25.0
    @objc private func enterBackground() {
        guard role != .none, !backgrounded else { return }
        endBackgroundGrace()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "zoker-match") { [weak self] in
            self?.suspend(); self?.endBackgroundGrace()
        }
        let timer = Timer(timeInterval: Self.backgroundGrace, repeats: false) { [weak self] _ in
            guard let self = self, UIApplication.shared.applicationState == .background else { self?.endBackgroundGrace(); return }
            self.suspend(); self.endBackgroundGrace()
        }
        backgroundDeadline = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func endBackgroundGrace() {
        backgroundDeadline?.invalidate(); backgroundDeadline = nil
        if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask); backgroundTask = .invalid }
    }
    @objc private func suspend() {
        guard role != .none else { return }
        backgrounded = true; remoteReady = false; snapshotReady = false
        stopDiscovery()
        session?.disconnect()
        relay?.close(); relay = nil; relayPeerPresent = false
        describe("Ứng dụng tạm nghỉ · trận tạm dừng")
    }
    @objc private func resume() {
        endBackgroundGrace()   // back within the grace: the room never dropped
        guard role != .none, backgrounded, !protocolBlocked else { return }
        backgrounded = false
        restartSession()
        describe("Đang nối lại phòng \(roomCode) · trận tạm dừng")
    }

    @discardableResult private func send(kind: LANEnvelope.Kind, snapshot: LANSnapshot? = nil,
                                         command: LANCommand? = nil, message: String? = nil,
                                         events: [LANEvent]? = nil, shotID: Int? = nil, aim: LANAim? = nil) -> Bool {
        guard linkUp else { return false }
        sendSequence += 1
        var packet = LANEnvelope(roomCode: roomCode, matchID: matchID, sequence: sendSequence, kind: kind)
        packet.snapshot = snapshot; packet.command = command; packet.message = message
        packet.events = events; packet.shotID = shotID; packet.aim = aim
        if kind == .hello { packet.role = role == .host ? "host" : "guest"; packet.game = game }
        do {
            let data = try LANWireCodec.encode(packet)
            if transport == .gameCenter {
                guard let match = gameCenterMatch else { return false }
                try match.sendData(toAllPlayers: data, with: .reliable)
            } else if transport == .internet {
                guard let relay = relay else { return false }
                relay.send(data)
            } else {
                guard let session = session else { return false }
                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            }
            return true
        } catch {
            report("Chưa gửi được trạng thái trận. Đang chờ kết nối ổn định.")
            return false
        }
    }

    private func protocolFailure(_ message: String) {
        protocolBlocked = true; remoteReady = false
        stopDiscovery(); session?.disconnect()
        relay?.close(); relay = nil; relayPeerPresent = false
        describe("Trận tạm dừng · cần kết nối lại")
        report(message)
    }

    private func receive(_ data: Data, from peer: MCPeerID?) {
        guard data.count <= LANEnvelope.maximumBytes,
              let packet = try? LANWireCodec.decode(data), packet.roomCode == roomCode,
              packet.sequence > receivedSequence else { return }
        guard transport != .nearby || reservedPeer == nil || reservedPeer == peer else { return }
        if packet.kind != .hello && packet.matchID != matchID { return }
        receivedSequence = packet.sequence
        lastReceived = ProcessInfo.processInfo.systemUptime
        switch packet.kind {
        case .hello:
            guard let peerGame = packet.game, validGame(peerGame), UUID(uuidString: packet.matchID) != nil else {
                protocolFailure("Thông tin phòng không hợp lệ"); return
            }
            if role == .host {
                guard packet.role == "guest", packet.matchID == matchID else { return }
            } else {
                guard packet.role == "host", matchID.isEmpty || packet.matchID == matchID else {
                    protocolFailure("Phòng đã đổi trận. Hãy nhập lại mã để tham gia."); return
                }
                matchID = packet.matchID; game = peerGame
            }
            let wasReady = remoteReady
            remoteReady = true
            if role == .host {
                describe("Đã nối \(peer?.displayName ?? peerName) · Chủ phòng")
                if let snapshot = latestSnapshot { send(kind: .snapshot, snapshot: snapshot) }
            } else {
                // Online guests learn the match ID from the host's hello, then answer it.
                if transport == .internet && !wasReady { send(kind: .hello) }
                describe("Đang đồng bộ với \(peer?.displayName ?? peerName)")
            }
        case .snapshot:
            guard role == .guest, remoteReady, let value = packet.snapshot,
                  LANAuthorityGate.acceptsSnapshot(value, matchID: matchID,
                    lastRevision: latestSnapshot?.revision, awaitingFullSync: !snapshotReady) else { return }
            let firstSync = !snapshotReady
            latestSnapshot = value; snapshotReady = true
            revision = value.revision
            if let pending = awaitingRevision, value.revision > pending {
                awaitingCommandID = nil; awaitingRevision = nil
            }
            if firstSync {
                deliveredEventShot = value.shotID
                deliveredEventIndex = value.events.map { $0.index }.max() ?? -1
            }
            onSnapshot?(value)
            if firstSync { describe("Đã nối \(peer?.displayName ?? peerName) · Khách") }
        case .command:
            guard role == .host, remoteReady, let command = packet.command else { return }
            _ = receiveHostCommand(command, player: 1)
        case .accepted:
            guard role == .guest, remoteReady, let command = packet.command, command.isValid,
                  command.matchID == matchID, !acceptedByGuest.contains(command.id) else { return }
            acceptedByGuest.append(command.id)
            if awaitingCommandID == command.id { awaitingCommandID = nil; awaitingRevision = nil }
            if acceptedByGuest.count > 256 { acceptedByGuest.removeFirst(acceptedByGuest.count - 256) }
            onAcceptedCommand?(command)
        case .rejected:
            awaitingCommandID = nil; awaitingRevision = nil
            if let value = packet.message { report(String(value.prefix(160))) }
        case .events:
            guard role == .guest, remoteReady, let events = packet.events, !events.isEmpty,
                  events.count <= 128, events.allSatisfy({ $0.isValid }), let shot = packet.shotID,
                  (0...1_000_000_000).contains(shot) else { return }
            guard shot >= deliveredEventShot else { return }
            if shot != deliveredEventShot { deliveredEventShot = shot; deliveredEventIndex = -1 }
            let fresh = events.filter { $0.index > deliveredEventIndex }.sorted { $0.index < $1.index }
            if let index = fresh.last?.index { deliveredEventIndex = index }
            if !fresh.isEmpty { onEvents?(fresh, shot) }
        case .aim:
            guard remoteReady, let aim = packet.aim, aim.isValid else { return }
            onAim?(aim)
        case .ping: send(kind: .pong)
        case .pong: break
        case .leave:
            remoteReady = false
            describe("Bạn đã rời phòng · trận tạm dừng")
            if transport == .nearby { session?.disconnect() }
        }
    }

    @discardableResult private func receiveHostCommand(_ command: LANCommand, player: Int) -> Bool {
        guard role == .host, isConnected, !isApplyingCommand, let snapshot = latestSnapshot,
              LANAuthorityGate.allows(command, snapshot: snapshot, matchID: matchID,
                                     expectedPlayer: player, alreadyProcessed: Set(processedCommands),
                                     consumedRevision: consumedRevision) else {
            if player == 1 { send(kind: .rejected, message: "Lượt hoặc trạng thái đã đổi. Hãy chờ đồng bộ.") }
            return false
        }
        isApplyingCommand = true
        let applied = onCommand?(command) == true
        isApplyingCommand = false
        guard applied else {
            if player == 1 { send(kind: .rejected, message: "Thao tác chưa hợp lệ theo luật của trận.") }
            return false
        }
        processedCommands.append(command.id)
        consumedRevision = command.expectedRevision
        if processedCommands.count > 256 { processedCommands.removeFirst(processedCommands.count - 256) }
        send(kind: .accepted, command: command)
        onAcceptedCommand?(command)
        return true
    }
}

// MARK: - Internet relay
extension LocalMatchSession {
    fileprivate func handleRelay(_ event: RelayLink.Event) {
        switch event {
        case .peer(let present):
            relayFailures = 0
            relayPeerPresent = present
            if present {
                // Sent whenever the other seat (re)connects: restart the handshake,
                // because a relaunched peer numbers its packets from 1 again.
                receivedSequence = 0; remoteReady = false; snapshotReady = false
                lastReceived = ProcessInfo.processInfo.systemUptime
                describe("Đang đồng bộ với \(peerName)")
                // Host speaks first; a reconnecting guest that already knows the match also may.
                if role == .host || !matchID.isEmpty { send(kind: .hello) }
            } else {
                remoteReady = false; snapshotReady = false
                awaitingCommandID = nil; awaitingRevision = nil
                describe(role == .host ? "Mã phòng online \(roomCode) · đang chờ bạn" : "Bạn chơi mất kết nối · trận tạm dừng")
            }
        case .data(let data):
            receive(data, from: nil)
        case .closed(let code):
            relayPeerPresent = false; remoteReady = false; snapshotReady = false
            awaitingCommandID = nil; awaitingRevision = nil
            relay = nil
            relayFailures += 1
            retryAt = ProcessInfo.processInfo.systemUptime
            switch code {
            case 4404: protocolBlocked = true; describe("Không tìm thấy phòng \(roomCode)"); report("Mã phòng online không đúng hoặc chủ phòng chưa mở phòng.")
            case 4409: protocolBlocked = true; describe("Phòng \(roomCode) đã đủ 2 người"); report("Phòng online đã có người khác vào.")
            case 4426: protocolBlocked = true; describe("Cần cập nhật ứng dụng"); report("Máy chủ online dùng phiên bản giao thức khác.")
            case 4410: protocolBlocked = true; describe("Phòng đang mở trên máy khác")
            default: describe("Mất mạng · trận tạm dừng, đang nối lại")
            }
        }
    }
}

/// Where the free relay lives. Set once in the app (Máy chủ online) or bake in
/// `defaultURL` after deploying Server/relay to Cloudflare Workers.
enum OnlineRelayConfig {
    static let defaultURL = ""
    private static let key = "onlineRelayURL019"
    static var url: URL? {
        let text = (UserDefaults.standard.string(forKey: key) ?? defaultURL).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return normalize(text)
    }
    static var text: String { UserDefaults.standard.string(forKey: key) ?? defaultURL }
    @discardableResult static func set(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { UserDefaults.standard.removeObject(forKey: key); return true }
        guard normalize(trimmed) != nil else { return false }
        UserDefaults.standard.set(trimmed, forKey: key); return true
    }
    /// Accepts "zoker-relay.name.workers.dev", https:// or wss:// forms; returns wss/ws.
    static func normalize(_ text: String) -> URL? {
        var value = text
        if !value.contains("://") { value = "wss://" + value }
        guard var parts = URLComponents(string: value), let host = parts.host, !host.isEmpty else { return nil }
        switch parts.scheme?.lowercased() {
        case "https", "wss": parts.scheme = "wss"
        case "http", "ws": parts.scheme = "ws" // local relay testing only
        default: return nil
        }
        parts.path = ""; parts.query = nil; parts.fragment = nil
        return parts.url
    }
    /// One seat secret per room and role, kept so a relaunch can retake the seat.
    static func token(for code: String, role: String) -> String {
        let key = "onlineSeat019." + role + "." + code
        if let stored = UserDefaults.standard.string(forKey: key), stored.count == 32 { return stored }
        let value = OnlineRoomCode.makeToken()
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}

/// One WebSocket to the relay. Binary frames carry LANWireCodec envelopes;
/// text frames are relay notices ({"relay":"peer","present":true}).
final class RelayLink: NSObject, URLSessionWebSocketDelegate {
    enum Event { case peer(Bool), data(Data), closed(Int) }
    var onEvent: ((Event) -> Void)?
    private(set) var isOpen = false
    private var task: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let request: URLRequest
    private var finished = false

    init(base: URL, code: String, role: String, token: String) {
        var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) ?? URLComponents()
        parts.path = "/v1/rooms/" + code
        parts.queryItems = [URLQueryItem(name: "role", value: role), URLQueryItem(name: "token", value: token),
                            URLQueryItem(name: "v", value: String(LANEnvelope.protocolVersion))]
        var request = URLRequest(url: parts.url ?? base)
        request.timeoutInterval = 15
        self.request = request
        super.init()
    }

    func connect() {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        urlSession = session
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = LANEnvelope.maximumBytes + 1024
        self.task = task
        task.resume()
        receiveNext()
    }

    func send(_ data: Data) {
        guard isOpen, let task = task else { return }
        task.send(.data(data)) { [weak self] error in
            guard error != nil else { return }
            DispatchQueue.main.async { self?.finish(1006) }
        }
    }

    func close() {
        guard !finished else { return }
        finished = true; isOpen = false
        task?.cancel(with: .normalClosure, reason: nil)
        urlSession?.invalidateAndCancel()
        onEvent = nil
    }

    private func receiveNext() {
        task?.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, !self.finished else { return }
                switch result {
                case .failure:
                    self.finish(self.task?.closeCode.rawValue ?? 1006)
                case .success(.data(let data)):
                    self.isOpen = true
                    if data.count <= LANEnvelope.maximumBytes { self.onEvent?(.data(data)) }
                    self.receiveNext()
                case .success(.string(let text)):
                    let json = text.utf8.count <= 256 ? (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] : nil
                    if json?["relay"] as? String == "error", let code = json?["code"] as? Int {
                        // Custom WebSocket close codes (44xx) are not exposed by URLSession.
                        self.finish(code); return
                    }
                    self.isOpen = true
                    if json?["relay"] as? String == "peer", let present = json?["present"] as? Bool {
                        self.onEvent?(.peer(present))
                    }
                    self.receiveNext()
                @unknown default:
                    self.receiveNext()
                }
            }
        }
    }

    private func finish(_ code: Int) {
        guard !finished else { return }
        finished = true; isOpen = false
        let handler = onEvent; onEvent = nil
        task?.cancel(with: .goingAway, reason: nil)
        urlSession?.invalidateAndCancel()
        handler?(.closed(code))
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        guard !finished else { return }
        isOpen = true
    }
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        finish(closeCode.rawValue)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish((task as? URLSessionWebSocketTask)?.closeCode.rawValue ?? 1006)
    }
}

extension LocalMatchSession {
    /// 0.42: music to the guest — nearby (same Wi-Fi) only; never over the internet relay or Game Center.
    func sendMusic(_ data: Data) {
        guard transport == .nearby, role == .host, let session = session, !session.connectedPeers.isEmpty,
              data.count <= LANEnvelope.maximumBytes else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    }
}

extension LocalMatchSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, session === self.session, self.role != .none else { return }
            switch state {
            case .connected:
                guard self.reservedPeer == nil || self.reservedPeer == peerID else { session.disconnect(); return }
                self.reservedPeer = peerID; self.pendingPeer = nil
                self.receivedSequence = 0; self.remoteReady = false; self.snapshotReady = false
                self.lastReceived = ProcessInfo.processInfo.systemUptime
                self.advertiser?.stopAdvertisingPeer(); self.browser?.stopBrowsingForPeers()
                self.describe("Đang đồng bộ với \(peerID.displayName)")
                self.send(kind: .hello)
            case .connecting:
                self.describe("Đang nối \(peerID.displayName)")
            case .notConnected:
                self.pendingPeer = nil; self.remoteReady = false; self.snapshotReady = false
                self.awaitingCommandID = nil; self.awaitingRevision = nil
                if !self.backgrounded && !self.protocolBlocked {
                    self.describe("Mất kết nối · trận tạm dừng, đang nối lại")
                    let token = self.generation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        guard let self = self, self.generation == token, !self.isConnected else { return }
                        self.startDiscovery()
                    }
                }
            @unknown default:
                self.remoteReady = false
                self.describe("Kết nối đang chuyển trạng thái · trận tạm dừng")
            }
        }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard data.count <= LANEnvelope.maximumBytes else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, session === self.session else { return }
            if data.prefix(4) == MusicPlayer042.magic { if self.role == .guest { self.onMusic?(data) }; return }
            self.receive(data, from: peerID)
        }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        stream.close() // Protocol only accepts bounded messages, never streams/resources.
    }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        progress.cancel()
    }
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension LocalMatchSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, advertiser === self.advertiser, self.role == .host,
                  !self.backgrounded, !self.protocolBlocked, let session = self.session,
                  session.connectedPeers.isEmpty, self.pendingPeer == nil,
                  self.reservedPeer == nil || self.reservedPeer == peerID,
                  let context = context, context.count <= 2048,
                  let info = (try? JSONSerialization.jsonObject(with: context)) as? [String: String],
                  info["code"] == self.roomCode, info["match"] == self.matchID,
                  info["version"] == String(LANEnvelope.protocolVersion) else {
                invitationHandler(false, nil); return
            }
            self.pendingPeer = peerID
            self.inviteStarted = ProcessInfo.processInfo.systemUptime
            invitationHandler(true, session)
        }
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, advertiser === self.advertiser else { return }
            self.describe("Chưa mở được phòng trên mạng cục bộ")
            self.report("Cho phép Mạng cục bộ trong Cài đặt và kết nối Wi-Fi, rồi chọn Nối lại.")
        }
    }
}

extension LocalMatchSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, browser === self.browser, self.role == .guest,
                  !self.backgrounded, !self.protocolBlocked, !self.isConnected, self.pendingPeer == nil,
                  let session = self.session, let info = info, info["code"] == self.roomCode,
                  info["version"] == String(LANEnvelope.protocolVersion),
                  let roomMatch = info["match"], UUID(uuidString: roomMatch) != nil,
                  self.reservedPeer == nil || self.reservedPeer == peerID else { return }
            guard self.matchID.isEmpty || self.matchID == roomMatch else {
                self.protocolFailure("Phòng đã được tạo lại. Hãy rời phòng và nhập mã mới."); return
            }
            self.matchID = roomMatch
            if let game = info["game"], self.validGame(game) { self.game = game }
            self.pendingPeer = peerID; self.inviteStarted = ProcessInfo.processInfo.systemUptime
            let context = try? JSONSerialization.data(withJSONObject: ["code": self.roomCode,
                "match": roomMatch, "version": String(LANEnvelope.protocolVersion)])
            browser.invitePeer(peerID, to: session, withContext: context, timeout: 12)
            self.describe("Đang nối phòng \(self.roomCode)")
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, browser === self.browser, self.pendingPeer == peerID, !self.isConnected else { return }
            self.pendingPeer = nil
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, browser === self.browser else { return }
            self.describe("Chưa tìm được phòng trên mạng cục bộ")
            self.report("Kiểm tra quyền Mạng cục bộ và Wi-Fi, rồi chọn Nối lại.")
        }
    }
}

// MARK: - Game Center transport (0.27)
extension LocalMatchSession: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.gameCenterMatch === match else { return }
            self.receive(data, from: nil)
        }
    }
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.gameCenterMatch === match else { return }
            self.gameCenterPeerPresent = state == .connected
            self.handleRelay(.peer(state == .connected))
        }
    }
    func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.gameCenterMatch === match else { return }
            self.gameCenterPeerPresent = false; self.remoteReady = false
            self.describe("Game Center mất kết nối · trận tạm dừng")
            self.report(error?.localizedDescription ?? "Game Center mất kết nối")
        }
    }
}

// MARK: - Game Center account, friends and matchmaking (0.27)
/// Accounts are Apple Game Center accounts: sign-in, friends, invitations and the match relay are Apple's,
/// free, with no password storage or own server. Needs the Game Center capability on the App ID and the app
/// record in App Store Connect (owner action); without it sign-in reports unavailable and Wi-Fi / relay
/// online play keep working unchanged.
final class GameCenterHub: NSObject, GKMatchmakerViewControllerDelegate, GKLocalPlayerListener, GKGameCenterControllerDelegate {
    static let shared = GameCenterHub()
    /// Disciplines in playerGroup order: auto-match only pairs players who asked for the same game.
    static let rules = ["eightBall", "nineBall", "tenBall", "rotation15"]
    weak var presenter: UIViewController?
    var onMatch: ((GKMatch, String) -> Void)?
    var onStatus: ((String) -> Void)?
    private var pendingRule = "nineBall"
    private(set) var unavailableReason: String?

    var isSignedIn: Bool { GKLocalPlayer.local.isAuthenticated }
    var displayName: String { GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.displayName : "Chưa đăng nhập" }

    func authenticate(then next: (() -> Void)? = nil) {
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            guard let self = self else { return }
            if let controller = controller { self.presenter?.present(controller, animated: true); return }
            if GKLocalPlayer.local.isAuthenticated {
                self.unavailableReason = nil
                GKLocalPlayer.local.unregisterAllListeners(); GKLocalPlayer.local.register(self)
                self.onStatus?("Game Center: \(GKLocalPlayer.local.displayName)"); next?()
            } else {
                self.unavailableReason = error?.localizedDescription ?? "Game Center chưa sẵn sàng trên máy này"
                self.onStatus?("Game Center: " + (self.unavailableReason ?? ""))
            }
        }
    }
    func findMatch(rule: String) {
        guard isSignedIn else { authenticate { [weak self] in self?.findMatch(rule: rule) }; return }
        pendingRule = rule
        let request = GKMatchRequest(); request.minPlayers = 2; request.maxPlayers = 2
        request.playerGroup = Self.rules.firstIndex(of: rule) ?? 1
        request.inviteMessage = "Mời bạn một ván bida trên Z-Trainer"
        guard let controller = GKMatchmakerViewController(matchRequest: request) else { onStatus?("Không mở được ghép trận Game Center"); return }
        controller.matchmakerDelegate = self
        presenter?.present(controller, animated: true)
    }
    func showFriends() { showDashboard(.localPlayerFriendsList) }
    func showProfile() { showDashboard(.localPlayerProfile) }
    private func showDashboard(_ state: GKGameCenterViewControllerState) {
        guard isSignedIn else { authenticate { [weak self] in self?.showDashboard(state) }; return }
        let controller = GKGameCenterViewController(state: state); controller.gameCenterDelegate = self
        presenter?.present(controller, animated: true)
    }
    // Invitation accepted from a notification or the friends list: the invite carries the game.
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        pendingRule = Self.rules.indices.contains(invite.playerGroup) ? Self.rules[invite.playerGroup] : "nineBall"
        guard let controller = GKMatchmakerViewController(invite: invite) else { return }
        controller.matchmakerDelegate = self
        presenter?.present(controller, animated: true)
    }
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        let rule = pendingRule
        viewController.dismiss(animated: true) { [weak self] in self?.onMatch?(match, rule) }
    }
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) { viewController.dismiss(animated: true) }
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        viewController.dismiss(animated: true); onStatus?("Game Center: " + error.localizedDescription)
    }
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) { gameCenterViewController.dismiss(animated: true) }
}
