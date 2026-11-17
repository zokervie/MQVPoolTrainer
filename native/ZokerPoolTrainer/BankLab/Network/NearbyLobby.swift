import Foundation

/// 0.44-mm Nearby Play (anh 16/11: giao diện phòng + nối lại; GIỮ MultipeerConnectivity, LANShotStart/lockstep và lớp truyền).
/// Pure, Foundation-only room logic so it can be tested without two devices (Tests/NearbyLobbyTests.swift via
/// Tools/run_lan_checks.sh). LocalMatchSession feeds it transport facts; the lobby screen renders it. It never sends
/// bytes and never touches match state — the host stays the only rules/solver authority.
struct NearbyRoomAd: Equatable {
    var code: String, host: String, game: String, version: Int, matchID: String
}

enum NearbyFailure: Equatable {
    case incompatibleVersion, rejected, roomFull, roomGone, reconnectTimedOut, permissionDenied
    var vietnamese: String {
        switch self {
        case .incompatibleVersion: return "Hai máy khác phiên bản ứng dụng · cập nhật cả hai máy"
        case .rejected: return "Chủ phòng đã từ chối"
        case .roomFull: return "Phòng đã đủ 2 người"
        case .roomGone: return "Phòng không còn · hãy tìm lại"
        case .reconnectTimedOut: return "Mất kết nối quá lâu · trận vẫn được giữ, chọn Nối lại hoặc Rời phòng"
        case .permissionDenied: return "Cần quyền Mạng cục bộ: Cài đặt → Zoker Pool → Mạng cục bộ"
        }
    }
    var english: String {
        switch self {
        case .incompatibleVersion: return "The two devices run different app versions · update both"
        case .rejected: return "The host declined"
        case .roomFull: return "The room already has two players"
        case .roomGone: return "The room is gone · search again"
        case .reconnectTimedOut: return "Connection lost for too long · the match is kept, Reconnect or Leave"
        case .permissionDenied: return "Local Network permission needed: Settings → Zoker Pool → Local Network"
        }
    }
}

enum NearbyPhase: Equatable {
    case idle, hosting, browsing, joining(String), connected, reconnecting(attempt: Int), failed(NearbyFailure), left
}

/// `.acceptKnown` = the guest the host already accepted in this room, coming back after a drop: take it, no question.
enum NearbyInvitationDecision: Equatable { case ask, acceptKnown, ignoreDuplicate, rejectBusy }

struct NearbyLobby {
    /// Retry delays after a drop (s): 1, 2, 4, 8, then every 8 s.
    static let backoff: [Double] = [1, 2, 4, 8]
    /// Give up (match kept, paused) after this long without the link — longer than the 25 s background grace,
    /// so a quick app switch on either phone never ends in a failure message.
    static let giveUpAfter = 45.0
    /// Quality bands on the ping/pong round trip (ms) and its jitter.
    static let goodRTT = 60.0, okRTT = 150.0, goodJitter = 15.0, okJitter = 40.0

    let protocolVersion: Int
    private(set) var phase: NearbyPhase = .idle
    private(set) var rooms: [NearbyRoomAd] = []
    private(set) var incompatibleRooms = 0
    private(set) var pendingInvitation: String?
    /// The guest the host said yes to in this room (0.44.1 review: a reconnecting guest was refused by its own host).
    private(set) var acceptedPeer: String?
    /// Guest side: invitations refused in a row (reset by a connection). Two = the host declined.
    private(set) var refusals = 0
    static let refusalsToStop = 2
    private(set) var mode = "nineBall"
    private(set) var rtt: [Double] = []
    private(set) var reconnects = 0, reconnectSuccesses = 0
    private var droppedAt: Double?
    private var nextRetryAt: Double?
    private var seenIncompatible = Set<String>()
    /// Peers the host said no to in this room: MultipeerConnectivity re-invites on its own, never ask twice.
    private var declined = Set<String>()

    init(protocolVersion: Int) { self.protocolVersion = protocolVersion }

    // MARK: Room creation / discovery
    mutating func host(mode: String) { self = NearbyLobby(protocolVersion: protocolVersion); self.mode = mode; phase = .hosting }
    mutating func browse() { self = NearbyLobby(protocolVersion: protocolVersion); phase = .browsing }
    /// A room advertised nearby. Returns false when it cannot be joined (other app version); such rooms are counted,
    /// not listed, so the player sees why a friend's room is missing.
    @discardableResult mutating func roomFound(_ ad: NearbyRoomAd) -> Bool {
        guard ad.version == protocolVersion else {
            if seenIncompatible.insert(ad.code).inserted { incompatibleRooms += 1 }
            return false
        }
        if let i = rooms.firstIndex(where: { $0.code == ad.code }) { rooms[i] = ad } else { rooms.append(ad) }
        rooms.sort { $0.host == $1.host ? $0.code < $1.code : $0.host < $1.host }
        return true
    }
    mutating func roomLost(code: String) {
        rooms.removeAll { $0.code == code }
        if case .joining(let joining) = phase, joining == code { phase = .failed(.roomGone) }
    }
    /// Typed 6-digit code (the existing "Vào phòng Wi‑Fi bằng mã"): no scan needed.
    mutating func joinDirect(code: String) { self = NearbyLobby(protocolVersion: protocolVersion); phase = .joining(code) }
    mutating func join(code: String) -> Bool {
        guard rooms.contains(where: { $0.code == code }) else { return false }
        phase = .joining(code); return true
    }

    // MARK: Invitations (host)
    /// The same peer inviting again while its question is open is a duplicate (MultipeerConnectivity retries).
    mutating func invitation(from peer: String) -> NearbyInvitationDecision {
        if let known = acceptedPeer, known == peer {
            switch phase {
            case .hosting, .connected, .reconnecting, .failed(.reconnectTimedOut): return .acceptKnown
            default: break
            }
        }
        switch phase {
        case .connected, .reconnecting: return .rejectBusy
        case .hosting:
            if declined.contains(peer) { return .rejectBusy }
            if pendingInvitation == peer { return .ignoreDuplicate }
            if pendingInvitation != nil { return .rejectBusy }
            pendingInvitation = peer; return .ask
        default: return .rejectBusy
        }
    }
    /// The host answered; on "no" the room stays open for someone else. `asked: false` = the question could not be
    /// shown (another screen on top): refuse this once without remembering the player as declined.
    mutating func decide(accept: Bool, asked: Bool = true) {
        if let peer = pendingInvitation {
            if accept { acceptedPeer = peer } else if asked { declined.insert(peer) }
        }
        pendingInvitation = nil
    }
    /// Guest side: the host said no.
    mutating func rejectedByHost() { phase = .failed(.rejected) }
    /// Guest side: an invitation ended without a connection. Returns true when the guest should stop inviting
    /// (two in a row = the host declined); the phase then reads "Chủ phòng đã từ chối".
    mutating func inviteRefused() -> Bool {
        refusals += 1
        guard refusals >= Self.refusalsToStop else { return false }
        rejectedByHost(); return true
    }

    // MARK: Link lifecycle
    mutating func linkUp(now: Double) {
        if case .reconnecting = phase { reconnectSuccesses += 1 }
        phase = .connected; pendingInvitation = nil; droppedAt = nil; nextRetryAt = nil; refusals = 0
    }
    /// Only a match that was connected can be "reconnecting"; a drop while still looking leaves the search running.
    mutating func linkDown(now: Double) {
        switch phase {
        case .connected:
            reconnects += 1; droppedAt = now; nextRetryAt = now + Self.backoff[0]; phase = .reconnecting(attempt: 1)
        case .joining: phase = .browsing
        default: break
        }
    }
    enum TickAction: Equatable { case none, retry, giveUp }
    /// Called about once a second. `.retry` = restart discovery now; `.giveUp` = stop retrying, keep the match paused.
    mutating func tick(now: Double) -> TickAction {
        guard case .reconnecting(let attempt) = phase, let dropped = droppedAt, let next = nextRetryAt else { return .none }
        if now - dropped >= Self.giveUpAfter { phase = .failed(.reconnectTimedOut); nextRetryAt = nil; return .giveUp }
        guard now >= next else { return .none }
        let delay = Self.backoff[min(attempt, Self.backoff.count - 1)]
        nextRetryAt = now + delay; phase = .reconnecting(attempt: attempt + 1)
        return .retry
    }
    /// Explicit "Nối lại" after a give-up: a fresh retry window.
    mutating func manualReconnect(now: Double) {
        guard case .failed(.reconnectTimedOut) = phase else { return }
        droppedAt = now; nextRetryAt = now; phase = .reconnecting(attempt: 1)
    }
    mutating func fail(_ reason: NearbyFailure) { phase = .failed(reason); pendingInvitation = nil }
    mutating func leave() { self = NearbyLobby(protocolVersion: protocolVersion); phase = .left }

    // MARK: Start (0.44.1: the local-only "Ready" switch is gone; the host's game travels in the advert and hello as before)
    var canStart: Bool { phase == .connected }

    // MARK: Connection quality from ping/pong
    mutating func roundTrip(_ seconds: Double) {
        guard seconds.isFinite, seconds >= 0, seconds < 10 else { return }
        rtt.append(seconds * 1000); if rtt.count > 20 { rtt.removeFirst(rtt.count - 20) }
    }
    var rttMs: Double? { rtt.isEmpty ? nil : rtt.sorted()[rtt.count / 2] }
    /// Mean absolute difference between consecutive samples (RFC 3550-style, unsmoothed).
    var jitterMs: Double? {
        guard rtt.count >= 2 else { return nil }
        return zip(rtt, rtt.dropFirst()).map { abs($1 - $0) }.reduce(0, +) / Double(rtt.count - 1)
    }
    /// 0 = unknown, 1 = poor, 2 = ok, 3 = good.
    var quality: Int {
        guard let r = rttMs else { return 0 }
        let j = jitterMs ?? 0
        if r <= Self.goodRTT && j <= Self.goodJitter { return 3 }
        if r <= Self.okRTT && j <= Self.okJitter { return 2 }
        return 1
    }
}
