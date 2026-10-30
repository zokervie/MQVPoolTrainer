import Foundation
import MultipeerConnectivity
import UIKit

/// Two nearby devices, no account/server. All public APIs and callbacks use the main thread.
/// MCSession supplies ordered reliable delivery and required transport encryption.
/// Host is seat 0 and the only solver/rules authority; guest is seat 1.
final class LocalMatchSession: NSObject {
    enum Role { case none, host, guest }
    static let serviceType = "zt-pool18"

    var onStateChanged: ((String) -> Void)?
    var onSnapshot: ((LANSnapshot) -> Void)?
    /// Host only: validate the rules, apply the command, return whether accepted.
    /// Publish the new state in onAcceptedCommand or the next display tick.
    var onCommand: ((LANCommand) -> Bool)?
    var onAcceptedCommand: ((LANCommand) -> Void)?
    var onEvents: (([LANEvent], Int) -> Void)?
    var onError: ((String) -> Void)?

    private(set) var role: Role = .none
    private(set) var roomCode = ""
    private(set) var game = ""
    private(set) var latestSnapshot: LANSnapshot?
    private(set) var isApplyingCommand = false
    private(set) var connectionDescription = "Chưa vào phòng"
    var hasPendingCommand: Bool { awaitingCommandID != nil }
    var localPlayer: Int { role == .guest ? 1 : 0 }
    var isConnected: Bool {
        remoteReady && (role == .host || snapshotReady) && !backgrounded && !protocolBlocked && session?.connectedPeers.count == 1
    }

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
        NotificationCenter.default.addObserver(self, selector: #selector(suspend),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resume),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        heartbeat?.invalidate()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
    }

    @discardableResult func createRoom(game: String) -> String {
        requireMain()
        leave()
        guard validGame(game) else { report("Thể loại trận không hợp lệ"); return "" }
        role = .host
        self.game = game
        roomCode = String(Int.random(in: 100_000...999_999))
        matchID = UUID().uuidString
        restartSession()
        startHeartbeat()
        describe("Mã phòng \(roomCode) · đang chờ bạn")
        return roomCode
    }

    @discardableResult func joinRoom(code: String) -> Bool {
        requireMain()
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.utf8.count == 6, trimmed.utf8.allSatisfy({ (48...57).contains($0) }) else {
            report("Nhập mã phòng gồm 6 chữ số"); return false
        }
        leave()
        role = .guest
        roomCode = trimmed
        restartSession()
        startHeartbeat()
        describe("Đang tìm phòng \(roomCode) trên mạng gần đây")
        return true
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
        roomCode = ""; game = ""; matchID = ""
        reservedPeer = nil; pendingPeer = nil
        latestSnapshot = nil; revision = 0; sendSequence = 0; receivedSequence = 0
        processedCommands.removeAll(); acceptedByGuest.removeAll()
        consumedRevision = nil; awaitingCommandID = nil; awaitingRevision = nil
        deliveredEventShot = -1; deliveredEventIndex = -1; isApplyingCommand = false
        backgrounded = false; protocolBlocked = false
        lastPublished = -Double.infinity
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
        guard force || now - lastPublished >= 0.1 else { return false }
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
        let value = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        value.delegate = self
        session = value
        lastReceived = ProcessInfo.processInfo.systemUptime
        retryAt = lastReceived
        startDiscovery()
    }
    private func startDiscovery() {
        guard role != .none, !backgrounded, !protocolBlocked else { return }
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

    @objc private func suspend() {
        guard role != .none else { return }
        backgrounded = true; remoteReady = false; snapshotReady = false
        stopDiscovery()
        session?.disconnect()
        describe("Ứng dụng tạm nghỉ · trận tạm dừng")
    }
    @objc private func resume() {
        guard role != .none, backgrounded, !protocolBlocked else { return }
        backgrounded = false
        restartSession()
        describe("Đang nối lại phòng \(roomCode) · trận tạm dừng")
    }

    @discardableResult private func send(kind: LANEnvelope.Kind, snapshot: LANSnapshot? = nil,
                                         command: LANCommand? = nil, message: String? = nil,
                                         events: [LANEvent]? = nil, shotID: Int? = nil) -> Bool {
        guard let session = session, session.connectedPeers.count == 1 else { return false }
        sendSequence += 1
        var packet = LANEnvelope(roomCode: roomCode, matchID: matchID, sequence: sendSequence, kind: kind)
        packet.snapshot = snapshot; packet.command = command; packet.message = message
        packet.events = events; packet.shotID = shotID
        if kind == .hello { packet.role = role == .host ? "host" : "guest"; packet.game = game }
        do {
            let data = try LANWireCodec.encode(packet)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            return true
        } catch {
            report("Chưa gửi được trạng thái trận. Đang chờ kết nối ổn định.")
            return false
        }
    }

    private func protocolFailure(_ message: String) {
        protocolBlocked = true; remoteReady = false
        stopDiscovery(); session?.disconnect()
        describe("Trận tạm dừng · cần kết nối lại")
        report(message)
    }

    private func receive(_ data: Data, from peer: MCPeerID) {
        guard data.count <= LANEnvelope.maximumBytes,
              let packet = try? LANWireCodec.decode(data), packet.roomCode == roomCode,
              packet.sequence > receivedSequence else { return }
        guard reservedPeer == nil || reservedPeer == peer else { return }
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
            remoteReady = true
            if role == .host {
                describe("Đã nối \(peer.displayName) · Chủ phòng")
                if let snapshot = latestSnapshot { send(kind: .snapshot, snapshot: snapshot) }
            } else {
                describe("Đang đồng bộ với \(peer.displayName)")
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
            if firstSync { describe("Đã nối \(peer.displayName) · Khách") }
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
        case .ping: send(kind: .pong)
        case .pong: break
        case .leave:
            remoteReady = false
            describe("Bạn đã rời phòng · trận tạm dừng")
            session?.disconnect()
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
