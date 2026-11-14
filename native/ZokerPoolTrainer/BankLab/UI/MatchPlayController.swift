import UIKit
import GameKit
import simd

/// UI state is deliberately separate from the host's rules and fixed-step world.
/// A guest only draws snapshots; it never steps or strikes a local solver.
final class MatchPlayState {
    let session = LocalMatchSession()
    var rules: BLMatch?
    /// 0.40 Đấu với máy: level 0…5 of the computer (player 2); nil = two humans. Feature flag "vsComputer" (IAP-ready).
    var computerLevel: Int?
    var computerThinking = false, computerFailures = 0, computerTurnKey = "", computerShots = 0, computerStarted = 0.0
    var computerAim: ComputerAim?
    /// The human's cue/elevation/tip before the computer took the table; restored when the turn comes back (0.40c).
    var humanSetup: TrainingController.ShotSetup?
    /// 0.40b shot clock (Tuỳ chỉnh → Vật lý → Đồng hồ cú). Extensions are per player per rack.
    var clockLeft = 0.0, clockKey = "", extensionsLeft = [0, 0], extensionRack = -1, clockWarned = 0
    let clockBar = UIView(), clockLabel = UILabel(), extensionButton = UIButton(type: .system)
    var clockBuilt = false
    var clockSides: [NSLayoutConstraint] = [], clockSide = -1
    var lastSnapshotBuild = -Double.infinity
    // 0.41 live cue of the remote shooter (display only) and the away rules.
    var remoteAim: LANAim?, remoteShown: LANAim?, remoteAimAt = -Double.infinity
    var lastAimSent: LANAim?, lastAimSentAt = -Double.infinity
    var localCueVisual: (Int, Double)?
    var awaySince: Double?, awayTurnKey = "", awayTurnStart = 0.0, everConnected = false
    var state: [String:Any] = [:]
    var active = false
    var showNumbers = false
    var applyingOfflineCommand = false
    var shotID = 0
    var elapsed = 0.0
    var crossed = Set<Int>()
    var publishedEvents = 0
    var calledBall = 0, calledPocket = -1
    var safety = false, pushOut = false
    var warningAcknowledged: String?
    var forfeitWinner: Int?
    var guestBalls: [BallState] = []
    var snapshots: [LANSnapshot] = []
    var guestClock = 0.0
    var playout = PlayoutClock()
    var audioEvents: [LANEvent] = []
    var playedEvents = Set<Int>()
    var audioShotID = -1
    var lastGuestShot = -1
    var lastGuestTurn = -1
    var pendingAimSync = true
    var needsFullSync = true
    var placementDraft: [BallState]?
    var placementOrigin: [BallState]?
    var pendingChoiceKey = ""
    var banner = UIButton(type: .system)
    // 0.29 race-to-N scoreboard (host authority; published in the rules JSON as raceTo/frames/names/rackNo/matchWinner).
    var raceTo = 5, frames = [0, 0], names = ["Người 1", "Người 2"], rackNo = 1, breaker = 0, matchWinner = -1
    var rackCounted = false
    let scoreboard = UIView()
    var scoreboardBuilt = false
    var bannerConfigured = false
    var lastStatus = ""
}

extension TrainingController {
    var matchIsCompetitive: Bool { matchPlay.active }
    var matchAllowsEditing: Bool { !matchPlay.active }
    var matchDisplayedBalls: [BallState]? {
        if let draft = matchPlay.placementDraft { return draft }
        return matchPlay.active && matchPlay.session.role == .guest ? matchPlay.guestBalls : nil
    }
    var matchSimulationPaused: Bool {
        matchPlay.active && matchPlay.session.role != .none && !matchPlay.session.isConnected && !matchHostSolo
    }
    /// 0.41 (owner: "đến lượt ai nấy đánh, tránh chờ đợi"): the host holds the rules and the solver, so it keeps
    /// playing its own turns while the guest is away (screen off, other app). The guest resyncs in full on return.
    var matchHostSolo: Bool {
        matchPlay.active && matchPlay.session.role == .host && !matchPlay.session.isConnected &&
            matchPlay.everConnected && matchPlay.awaySince != nil
    }
    var matchAllowsInput: Bool {
        guard matchPlay.active else { return true }
        if matchPlay.session.isApplyingCommand || matchPlay.applyingOfflineCommand { return true }
        guard matchInt("winner", fallback: -1) < 0 else { return false }
        if matchPlay.computerLevel != nil && matchInt("currentPlayer") == 1 { return false }   // the computer's turn
        if matchPlay.session.role == .none { return true }
        let moving = matchPlay.session.role == .guest ?
            matchPlay.session.latestSnapshot?.isMoving == true : (shotActive || BLShotCameraBusy(shotCameraState))
        return (matchPlay.session.isConnected || matchHostSolo) && !matchPlay.session.hasPendingCommand &&
            !moving &&
            matchInt("currentPlayer") == matchPlay.session.localPlayer
    }
    var matchCanStroke: Bool {
        guard matchPlay.active else { return true }
        return matchAllowsInput && matchBool("canShoot") && !matchSimulationPaused &&
            matchPlay.placementDraft == nil && matchCuePositionValid(balls)
    }
    func matchInt(_ key: String, fallback: Int = 0) -> Int {
        let value = (matchPlay.state[key] as? NSNumber)?.intValue ?? fallback
        if key == "currentPlayer" { return min(1, max(0, value)) }
        if key == "winner" { return (-1...1).contains(value) ? value : -1 }
        return value
    }
    func matchBool(_ key: String) -> Bool { (matchPlay.state[key] as? NSNumber)?.boolValue ?? false }
    func matchPreferredAimTarget(in state: [BallState]) -> BallState? {
        let active = state.filter { $0.id > 0 && !$0.sunk }
        guard matchPlay.active, matchPlay.state["rule"] as? String == "eightBall",
              let groups = matchPlay.state["groups"] as? [Int], groups.count == 2 else {
            return active.min { $0.id < $1.id }
        }
        let group = groups[matchInt("currentPlayer")]
        if group < 0 { return active.filter { $0.id != 8 }.min { $0.id < $1.id } ?? active.first }
        let own = active.filter { group == 0 ? (1...7).contains($0.id) : (9...15).contains($0.id) }
        return own.min { $0.id < $1.id } ?? active.first { $0.id == 8 }
    }

    func configureMatchPlay() {
        guard !matchPlay.bannerConfigured else { return }
        matchPlay.bannerConfigured = true
        let button = matchPlay.banner
        button.accessibilityIdentifier = "MatchStatus"
        // 0.42 (owner screenshot 13/11 18:12: the status box covered the spin ball): a thin one-line strip at the very
        // bottom centre, clear of the left (B / spin) and right (elevation / camera) clusters.
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.font = .systemFont(ofSize: 10.5, weight: .semibold)
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.adjustsFontSizeToFitWidth = true; button.titleLabel?.minimumScaleFactor = 0.8
        button.contentHorizontalAlignment = .center
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(white: 0.025, alpha: 0.62)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        let width = button.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.42); width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -3),
            width, button.widthAnchor.constraint(lessThanOrEqualToConstant: 460),
            button.heightAnchor.constraint(equalToConstant: 20)
        ])
        button.addAction(UIAction { [weak self] _ in self?.openMatchActions() }, for: .touchUpInside)
        button.isHidden = true
        let session = matchPlay.session
        session.onStateChanged = { [weak self, weak session] message in
            guard let self = self, let session = session else { return }
            self.matchPlay.lastStatus = message
            if session.role == .guest && !session.isConnected { self.matchPlay.needsFullSync = true }
            if self.matchPlay.active {
                self.syncMatchControls()
                if session.role == .host { self.publishMatchSnapshot(force: true) }
            }
        }
        session.onError = { [weak self] text in
            guard let self = self else { return }
            self.notifyStatus(text); self.updateControls(); self.syncMatchControls()
        }
        session.onCommand = { [weak self] command in self?.applyMatchCommand(command) ?? false }
        session.onAcceptedCommand = { [weak self, weak session] command in
            guard let self = self, let session = session else { return }
            if session.role == .host { self.publishMatchSnapshot(force: true) }
            else if command.action == .strike, let shot = command.shot,
                    UserDefaults.standard.object(forKey: "poolAudioEnabled") as? Bool ?? true {
                self.poolAudio.play(kind: 3, impact: shot.speed, pan: 0)
            }
            if command.action == .strike { self.setHold(false) }
            self.syncMatchControls()
        }
        session.onSnapshot = { [weak self] snapshot in self?.receiveMatchSnapshot(snapshot) }
        session.onMusic = { data in MusicPlayer042.shared.receiveShared(data) }
        MusicPlayer042.shared.setSharing({ [weak session] data in session?.sendMusic(data) })
        session.onAim = { [weak self] aim in
            guard let self = self else { return }
            self.matchPlay.remoteAim = aim; self.matchPlay.remoteAimAt = ProcessInfo.processInfo.systemUptime
            self.wakeRendering()
        }
        session.onEvents = { [weak self, weak session] events, shotID in
            guard let self = self, session?.role == .guest else { return }
            if shotID > self.matchPlay.audioShotID {
                self.matchPlay.audioShotID = shotID
                self.matchPlay.playedEvents.removeAll()
                self.matchPlay.audioEvents.removeAll()
            }
            guard shotID == self.matchPlay.audioShotID else { return }
            self.queueMatchAudio(events)
        }
    }

    func configureMatchMenuItems() -> [UIAction] {
        [UIAction(title: "Chơi theo luật / Chơi cùng bạn", image: UIImage(systemName: "person.2")) { [weak self] _ in
            self?.openMatchMenu()
        }]
    }
    /// 0.37: scope nil = everything; 0 = two players on one device, 1 = Wi‑Fi nearby, 2 = Online (Lobby → Thi đấu).
    func openMatchMenu(scope: Int? = nil) {
        guard !shotActive, replayIndex == nil, !locked else { return }
        if matchPlay.active { openMatchActions(); return }
        let titles = ["Hai người · một máy", "Wi‑Fi gần nhau", "Online"]
        let sheet = UIAlertController(title: scope.map { titles[$0] } ?? "Chơi theo luật", message: "8/9/10 Ball: luật WPA. 15 Ball: Rotation, chạm số nhỏ nhất trước, đạt 61 điểm. Wi-Fi: hai máy cùng mạng. Online: hai máy ở bất kỳ đâu (Wi-Fi/4G) qua máy chủ chuyển tiếp miễn phí; máy tạo phòng tính vật lý cho cả hai.", preferredStyle: .actionSheet)
        let all = scope == nil
        for (rule, title) in matchDisciplines {
            if all || scope == 0 { sheet.addAction(UIAlertAction(title: title + " · chuyền máy", style: .default) { [weak self] _ in self?.setupMatch { self?.startMatch(rule: rule, network: false) } }) }
            if all || scope == 1 { sheet.addAction(UIAlertAction(title: title + " · tạo phòng Wi-Fi", style: .default) { [weak self] _ in self?.setupMatch { self?.startMatch(rule: rule, network: true) } }) }
            if all || scope == 2 { sheet.addAction(UIAlertAction(title: title + " · tạo phòng Online", style: .default) { [weak self] _ in self?.setupMatch { self?.startMatch(rule: rule, network: true, online: true) } }) }
        }
        // 0.27: Game Center — friends, invitations, auto-match; no room code, no own server.
        if all || scope == 2 { sheet.addAction(UIAlertAction(title: "Online · Game Center (bạn bè / ghép trận)", style: .default) { [weak self] _ in self?.chooseGameCenterMatch() }) }
        if all || scope == 1 { sheet.addAction(UIAlertAction(title: "Vào phòng Wi-Fi bằng mã", style: .default) { [weak self] _ in self?.joinMatchRoom() }) }
        if all || scope == 2 { sheet.addAction(UIAlertAction(title: "Vào phòng Online bằng mã", style: .default) { [weak self] _ in self?.joinMatchRoom(online: true) })
            sheet.addAction(UIAlertAction(title: "Máy chủ online…", style: .default) { [weak self] _ in self?.configureOnlineRelay() }) }
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        presentSheet(sheet, source: menuButton)
    }
    /// Address of the free relay (Server/relay deployed on Cloudflare Workers).
    func configureOnlineRelay(then next: (() -> Void)? = nil) {
        let alert = UIAlertController(title: "Máy chủ online", message: "Dán địa chỉ máy chủ chuyển tiếp, ví dụ zoker-relay.ten-ban.workers.dev. Hai máy phải dùng cùng một địa chỉ.", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = OnlineRelayConfig.text; field.placeholder = "zoker-relay.ten-ban.workers.dev"
            field.keyboardType = .URL; field.autocapitalizationType = .none; field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { [weak self, weak alert] _ in
            guard let self = self else { return }
            if OnlineRelayConfig.set(alert?.textFields?.first?.text ?? "") {
                self.notifyStatus(OnlineRelayConfig.url == nil ? "Đã xoá máy chủ online" : "Đã lưu máy chủ online")
                if OnlineRelayConfig.url != nil { next?() }
            } else { self.notifyStatus("Địa chỉ máy chủ chưa đúng") }
        })
        present(alert, animated: true)
    }
    var matchDisciplines: [(String,String)] {
        [("nineBall","9 Ball"),("eightBall","8 Ball"),("tenBall","10 Ball"),("rotation15","15 Ball Rotation · 61 điểm")]
    }
    /// 0.29: names + race to N agreed before the match (remembered for next time).
    func setupMatch(_ start: @escaping () -> Void) {
        let defaults = UserDefaults.standard
        let alert = UIAlertController(title: "Thiết lập trận", message: "Tên người chơi và số ván thắng (race to). Ví dụ race 5: ai thắng 5 ván trước thắng trận.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Người chơi 1"; $0.text = defaults.string(forKey: "playerName0") ?? "Người 1" }
        alert.addTextField { $0.placeholder = "Người chơi 2"; $0.text = defaults.string(forKey: "playerName1") ?? "Người 2" }
        alert.addTextField { $0.placeholder = "Race to (1–25)"; $0.keyboardType = .numberPad
            $0.text = String(defaults.object(forKey: "raceTo029") as? Int ?? 5) }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Bắt đầu", style: .default) { [weak self, weak alert] _ in
            guard let self = self, let fields = alert?.textFields, fields.count == 3 else { return }
            let clean: (String?, String) -> String = { text, fallback in
                let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? fallback : String(t.prefix(16)) }
            let n0 = clean(fields[0].text, "Người 1"), n1 = clean(fields[1].text, "Người 2")
            let race = Int(BLRaceClamp(Int32(Int(fields[2].text ?? "") ?? 5)))
            defaults.set(n0, forKey: "playerName0"); defaults.set(n1, forKey: "playerName1"); defaults.set(race, forKey: "raceTo029")
            self.matchPlay.names = [n0, n1]; self.matchPlay.raceTo = race
            start()
        })
        present(alert, animated: true)
    }
    func chooseGameCenterMatch() {
        let sheet = UIAlertController(title: "Game Center", message: "Mời bạn trong danh sách bạn bè hoặc ghép ngẫu nhiên với người cùng chọn thể loại.", preferredStyle: .actionSheet)
        for (rule, title) in matchDisciplines {
            sheet.addAction(UIAlertAction(title: title, style: .default) { _ in GameCenterHub.shared.findMatch(rule: rule) })
        }
        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel)); presentSheet(sheet, source: menuButton)
    }
    /// Both devices land here with the same GKMatch; the session decides the seat (lower player ID hosts).
    func startGameCenterMatch(_ match: GKMatch, rule: String) {
        guard !shotActive, replayIndex == nil else { return }
        let me = GKLocalPlayer.local.gamePlayerID, other = match.players.first?.gamePlayerID ?? ""
        if me < other { startMatch(rule: rule, network: true, gameCenter: match); return }
        prepareGuestMatch()
        matchPlay.session.startGameCenter(match: match, game: rule)
        setMenu(false); syncMatchControls(); updateControls()
        notifyStatus("Game Center · đang đồng bộ với \(match.players.first?.displayName ?? "bạn")")
    }
    func startMatch(rule: String, network: Bool, online: Bool = false, gameCenter: GKMatch? = nil) {
        guard !shotActive, replayIndex == nil else { return }
        if online && OnlineRelayConfig.url == nil {
            configureOnlineRelay { [weak self] in self?.startMatch(rule: rule, network: true, online: true) }
            return
        }
        matchPlay.session.leave(); MusicPlayer042.shared.setSharing(nil)
        clearShot()
        matchPlay.active = true
        matchPlay.rules = BLMatch(rule: rule)
        matchPlay.rules?.reset(breaker: 0)
        matchPlay.forfeitWinner = nil
        matchPlay.shotID = 0; matchPlay.elapsed = 0
        matchPlay.playout.reset()
        matchPlay.warningAcknowledged = nil
        matchPlay.showNumbers = false
        matchPlay.state = matchPlay.rules?.state ?? [:]
        resetMatchCall()
        // Competitive dimensions match the virtual WPA table/rack model. All
        // players use one authoritative host solver and its default calibration.
        engine.settings = BLWorld().settings
        side = 0; top = 0; spin.reset(); shotKind = 0
        table.selectCue(0); table.cueElevation = 0
        if gameCenter != nil {   // Game Center: names come from the accounts
            matchPlay.names = [GKLocalPlayer.local.displayName, gameCenter?.players.first?.displayName ?? "Đối thủ"]
            matchPlay.raceTo = UserDefaults.standard.object(forKey: "raceTo029") as? Int ?? 5
        }
        matchPlay.frames = [0, 0]; matchPlay.rackNo = 1; matchPlay.breaker = 0; matchPlay.matchWinner = -1; matchPlay.rackCounted = false
        let rack = matchPlay.rules?.rack(seed: UInt64.random(in: 1...UInt64.max)) ?? []
        engine.loadLayout(rack)
        initial = balls; before = initial
        startRackIntro()
        angle = Double.pi / 2
        guideOn = false; coaching = false; locked = false; isPlacingBalls = false
        table.resetPocketPresentation()
        table.setCompetitivePresentation(numbers: false)
        if network {
            if let match = gameCenter { matchPlay.session.startGameCenter(match: match, game: rule) }
            else { _ = matchPlay.session.createRoom(game: rule, internet: online) }
            publishMatchSnapshot(force: true)
        }
        setMenu(false); refresh(); syncMatchControls(); updateControls()
        let code = matchPlay.session.roomCode
        if gameCenter != nil {
            notifyStatus("Game Center · bạn là chủ bàn, phá trước")
        } else if online && !code.isEmpty {
            UIPasteboard.general.string = code
            notifyStatus("Mã phòng online \(code) (đã sao chép) · gửi cho bạn, bạn chọn Vào phòng Online bằng mã")
        } else {
            notifyStatus(network ? "Mã phòng \(code) · máy bạn chọn Vào phòng bằng mã" : "Lượt người 1 · phá từ phía sau vạch đầu bàn")
        }
    }
    func joinMatchRoom(online: Bool = false) {
        if online && OnlineRelayConfig.url == nil {
            configureOnlineRelay { [weak self] in self?.joinMatchRoom(online: true) }
            return
        }
        let alert = online ?
            UIAlertController(title: "Vào phòng Online", message: "Nhập mã 8 ký tự bạn gửi. Hai máy có thể ở mạng khác nhau (Wi-Fi hoặc 4G).", preferredStyle: .alert) :
            UIAlertController(title: "Vào phòng Wi-Fi", message: "Hai máy dùng cùng Wi-Fi, mở ứng dụng và cho phép Mạng cục bộ. Nhập mã 6 chữ số trên máy tạo phòng.", preferredStyle: .alert)
        alert.addTextField { field in
            if online {
                field.placeholder = "Mã 8 ký tự"; field.autocapitalizationType = .allCharacters; field.autocorrectionType = .no
                if let pasted = UIPasteboard.general.hasStrings ? UIPasteboard.general.string : nil,
                   OnlineRoomCode.isValid(OnlineRoomCode.normalized(pasted)) { field.text = OnlineRoomCode.normalized(pasted) }
            } else { field.placeholder = "Mã 6 chữ số"; field.keyboardType = .numberPad }
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Kết nối", style: .default) { [weak self, weak alert] _ in
            guard let self = self, let typed = alert?.textFields?.first?.text else { return }
            let code = online ? OnlineRoomCode.normalized(typed) : typed
            if online {
                guard OnlineRoomCode.isValid(code) else { self.notifyStatus("Mã phòng online gồm 8 ký tự"); return }
            } else {
                guard code.count == 6, code.allSatisfy({ $0.isNumber && $0.isASCII }) else { self.notifyStatus("Mã phòng cần 6 chữ số"); return }
            }
            self.prepareGuestMatch()
            _ = self.matchPlay.session.joinRoom(code: code, internet: online)
            self.setMenu(false); self.syncMatchControls(); self.updateControls()
        })
        present(alert, animated: true)
    }
    func prepareGuestMatch() {
        clearShot()
        matchPlay.rules = nil; matchPlay.state = [:]
        matchPlay.active = true; matchPlay.showNumbers = false
        matchPlay.guestBalls = []; matchPlay.snapshots = []; matchPlay.playout.reset()
        matchPlay.lastGuestShot = -1; matchPlay.lastGuestTurn = -1; matchPlay.pendingAimSync = true; matchPlay.needsFullSync = true
        matchPlay.audioShotID = -1; matchPlay.audioEvents = []; matchPlay.playedEvents = []
        matchPlay.placementDraft = nil
        coaching = false; guideOn = false; locked = false
        table.cameraMode = 0; table.zoom = 1; table.focusBounds = nil
        table.setCompetitivePresentation(numbers: false)
    }
    /// 0.39 (owner: scoreboard too plain — names and scores must stand apart, framed, professional type). Broadcast
    /// layout: [● NAME][ 3 ]  RACE 5 · VÁN 2  [ 1 ][NAME ●]. Each player has a colour plate (blue / red), scores sit in
    /// gold boxes with heavy rounded digits, the shooter's plate gets a bright frame and a dot; the frame is dark glass.
    /// 0.40b (owner 12/11): slimmer TV bar (30 pt), a lit "turn lamp" on the shooter's plate (also pass-and-play on one
    /// phone), and 10 styles in Tuỳ chỉnh → Hình ảnh → Bảng điểm (feature flag "scoreboardStyles" → Z-Style pack later).
    struct ScoreboardStyle {
        let name: String
        let plates: (UIColor, UIColor), score: UIColor, scoreText: UIColor, text: UIColor
        let centre: UIColor, centreText: UIColor, frame: UIColor, radius: CGFloat, slant: Bool, lamp: UIColor
    }
    static let scoreboardStyles: [ScoreboardStyle] = {
        let c = UIColor.rgb
        return [
            ScoreboardStyle(name: "TV đêm", plates: (c(0x1F5FAF), c(0xB0343A)), score: c(0xEAC583), scoreText: c(0x101010), text: .white, centre: c(0x0A0D14), centreText: c(0xEAC583), frame: c(0xEAC583), radius: 8, slant: false, lamp: c(0x5BFF7A)),
            ScoreboardStyle(name: "VS xanh–đỏ", plates: (c(0x1E3A9E), c(0x1E3A9E)), score: c(0x2B2F38), scoreText: .white, text: .white, centre: c(0xC62828), centreText: .white, frame: c(0xC9CED6), radius: 4, slant: true, lamp: c(0x5BFF7A)),
            ScoreboardStyle(name: "Bạc cổ điển", plates: (c(0xEDEFF2), c(0xEDEFF2)), score: c(0x1E3A9E), scoreText: .white, text: c(0x16213E), centre: c(0x2B2F38), centreText: .white, frame: c(0xB0343A), radius: 3, slant: true, lamp: c(0x18C24A)),
            ScoreboardStyle(name: "Tối giản", plates: (UIColor(white: 0, alpha: 0.55), UIColor(white: 0, alpha: 0.55)), score: UIColor(white: 1, alpha: 0.12), scoreText: .white, text: .white, centre: .clear, centreText: UIColor(white: 1, alpha: 0.7), frame: .clear, radius: 10, slant: false, lamp: c(0x5BFF7A)),
            ScoreboardStyle(name: "Neon", plates: (c(0x05060A), c(0x05060A)), score: c(0x05060A), scoreText: c(0x29F0FF), text: c(0x29F0FF), centre: c(0x05060A), centreText: c(0xFF3DCB), frame: c(0xFF3DCB), radius: 8, slant: false, lamp: c(0x29F0FF)),
            ScoreboardStyle(name: "Gỗ CLB", plates: (c(0x5A3A22), c(0x5A3A22)), score: c(0xF1E3C6), scoreText: c(0x3A2414), text: c(0xF1E3C6), centre: c(0x2E1D10), centreText: c(0xF1E3C6), frame: c(0xC79A5B), radius: 6, slant: false, lamp: c(0xFFD15C)),
            ScoreboardStyle(name: "Nỉ xanh", plates: (c(0x0F5E3C), c(0x0F5E3C)), score: c(0xEAC583), scoreText: c(0x0B2A1B), text: .white, centre: c(0x08321F), centreText: c(0xEAC583), frame: c(0xEAC583), radius: 8, slant: false, lamp: c(0xFFE36E)),
            ScoreboardStyle(name: "Carbon", plates: (c(0x24262B), c(0x24262B)), score: c(0xFF7A1A), scoreText: c(0x111111), text: .white, centre: c(0x141518), centreText: c(0xFF7A1A), frame: c(0x3A3D44), radius: 5, slant: true, lamp: c(0xFF7A1A)),
            ScoreboardStyle(name: "Hoàng gia", plates: (c(0x3B1F6B), c(0x3B1F6B)), score: c(0xE9C46A), scoreText: c(0x2A1450), text: .white, centre: c(0x24113F), centreText: c(0xE9C46A), frame: c(0xE9C46A), radius: 8, slant: false, lamp: c(0x7CFFB2)),
            ScoreboardStyle(name: "Trắng sáng", plates: (c(0xFFFFFF), c(0xFFFFFF)), score: c(0x16213E), scoreText: .white, text: c(0x16213E), centre: c(0xE6E9EF), centreText: c(0x16213E), frame: c(0xC9CED6), radius: 10, slant: false, lamp: c(0x18C24A)),
        ]
    }()
    static var scoreboardStyleIndex: Int {
        min(scoreboardStyles.count - 1, max(0, UserDefaults.standard.integer(forKey: "scoreboardStyle040")))
    }
    func updateScoreboard() {
        let board = matchPlay.scoreboard
        let styleIndex = Self.scoreboardStyleIndex, style = Self.scoreboardStyles[styleIndex]
        func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            return UIFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size)
        }
        if !matchPlay.scoreboardBuilt || board.tag != 100 + styleIndex {
            matchPlay.scoreboardBuilt = true
            board.subviews.forEach { $0.removeFromSuperview() }
            board.tag = 100 + styleIndex
            if board.superview == nil {
                board.translatesAutoresizingMaskIntoConstraints = false; board.isUserInteractionEnabled = false
                board.accessibilityIdentifier = "MatchScoreboard"
                view.addSubview(board)
                NSLayoutConstraint.activate([board.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
                                             board.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
                                             board.heightAnchor.constraint(equalToConstant: 30),
                                             board.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.62),
                                             board.widthAnchor.constraint(lessThanOrEqualToConstant: 400)])
                let preferred = board.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.5)
                preferred.priority = .defaultHigh; preferred.isActive = true
            }
            board.backgroundColor = .clear
            board.layer.shadowColor = UIColor.black.cgColor; board.layer.shadowOpacity = 0.45; board.layer.shadowRadius = 6; board.layer.shadowOffset = .zero
            let row = UIStackView(); row.axis = .horizontal; row.spacing = 0; row.alignment = .fill
            row.translatesAutoresizingMaskIntoConstraints = false; board.addSubview(row); row.tag = 1
            NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: board.leadingAnchor), row.trailingAnchor.constraint(equalTo: board.trailingAnchor),
                                         row.topAnchor.constraint(equalTo: board.topAnchor), row.bottomAnchor.constraint(equalTo: board.bottomAnchor)])
            row.layer.cornerRadius = style.radius; row.layer.cornerCurve = .continuous; row.clipsToBounds = true
            row.layer.borderWidth = style.frame == .clear ? 0 : 1; row.layer.borderColor = style.frame.cgColor
            if style.slant { row.transform = CGAffineTransform(a: 1, b: 0, c: -0.18, d: 1, tx: 0, ty: 0) }   // TV-style parallelogram
            // 0.40c (owner: a long and a short name made the bar lopsided): both name plates are the SAME width, the
            // score and centre boxes are fixed, and the bar has a fixed width — names shrink (then abbreviate) to fit.
            var namePlates: [UIView] = []
            for tag in 10...14 {
                let plate = UIView(); plate.tag = tag + 10
                let label = UILabel(); label.tag = tag; label.textAlignment = .center; label.adjustsFontSizeToFitWidth = true; label.minimumScaleFactor = 0.62
                label.lineBreakMode = .byTruncatingTail; label.numberOfLines = 1
                label.translatesAutoresizingMaskIntoConstraints = false; plate.addSubview(label)
                if style.slant { label.transform = CGAffineTransform(a: 1, b: 0, c: 0.18, d: 1, tx: 0, ty: 0) }
                let lampSide: CGFloat = tag == 10 ? 1 : (tag == 14 ? -1 : 0)
                if lampSide != 0 {
                    // The turn lamp: dark when waiting, lit and breathing for the player to shoot.
                    let lamp = UIView(); lamp.tag = tag + 40; lamp.layer.cornerRadius = 4.5
                    lamp.translatesAutoresizingMaskIntoConstraints = false; plate.addSubview(lamp)
                    // Shot clock seconds sit in the shooter's own plate, next to the name (owner 12/11: not mid-screen).
                    let clock = UILabel(); clock.tag = tag + 60; clock.textAlignment = .center
                    clock.font = .monospacedDigitSystemFont(ofSize: 13, weight: .heavy); clock.isHidden = true
                    clock.translatesAutoresizingMaskIntoConstraints = false; plate.addSubview(clock)
                    if style.slant { clock.transform = label.transform }
                    NSLayoutConstraint.activate([lamp.widthAnchor.constraint(equalToConstant: 9), lamp.heightAnchor.constraint(equalToConstant: 9),
                                                 lamp.centerYAnchor.constraint(equalTo: plate.centerYAnchor),
                                                 lampSide > 0 ? lamp.leadingAnchor.constraint(equalTo: plate.leadingAnchor, constant: 8)
                                                              : lamp.trailingAnchor.constraint(equalTo: plate.trailingAnchor, constant: -8),
                                                 clock.widthAnchor.constraint(equalToConstant: 24), clock.centerYAnchor.constraint(equalTo: plate.centerYAnchor),
                                                 lampSide > 0 ? clock.trailingAnchor.constraint(equalTo: plate.trailingAnchor, constant: -5)
                                                              : clock.leadingAnchor.constraint(equalTo: plate.leadingAnchor, constant: 5)])
                    NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: plate.leadingAnchor, constant: lampSide > 0 ? 22 : 31),
                                                 label.trailingAnchor.constraint(equalTo: plate.trailingAnchor, constant: lampSide > 0 ? -31 : -22)])
                    namePlates.append(plate)
                } else {
                    NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: plate.leadingAnchor, constant: 4),
                                                 label.trailingAnchor.constraint(equalTo: plate.trailingAnchor, constant: -4),
                                                 plate.widthAnchor.constraint(equalToConstant: tag == 12 ? 58 : 34)])
                }
                label.centerYAnchor.constraint(equalTo: plate.centerYAnchor).isActive = true
                row.addArrangedSubview(plate)
            }
            if namePlates.count == 2 { namePlates[0].widthAnchor.constraint(equalTo: namePlates[1].widthAnchor).isActive = true }
        }
        board.isHidden = !matchPlay.active
        guard matchPlay.active, let row = board.viewWithTag(1) else { return }
        let player = matchInt("currentPlayer")
        let shooting = matchPlay.matchWinner < 0 && matchInt("winner", fallback: -1) < 0
        func set(_ tag: Int, _ text: String, _ font: UIFont, _ color: UIColor, plate: UIColor) {
            guard let label = row.viewWithTag(tag) as? UILabel, let box = row.viewWithTag(tag + 10) else { return }
            if label.text != text { label.text = text }
            label.textColor = color; label.font = font; box.backgroundColor = plate
        }
        for seat in 0...1 {
            let active = shooting && player == seat
            let name = Self.scoreboardName(matchPlay.names[seat])
            let plate = seat == 0 ? style.plates.0 : style.plates.1
            set(seat == 0 ? 10 : 14, name, rounded(12, .heavy), style.text.withAlphaComponent(active ? 1 : 0.55),
                plate: plate.withAlphaComponent(plate.cgColor.alpha * (active ? 1 : 0.7)))
            set(seat == 0 ? 11 : 13, "\(matchPlay.frames[seat])", .monospacedDigitSystemFont(ofSize: 17, weight: .black), style.scoreText, plate: style.score)
            if let lamp = row.viewWithTag((seat == 0 ? 10 : 14) + 40) {
                lamp.backgroundColor = active ? style.lamp : UIColor(white: 0.25, alpha: 0.8)
                lamp.layer.shadowColor = style.lamp.cgColor; lamp.layer.shadowRadius = 5; lamp.layer.shadowOffset = .zero
                lamp.layer.shadowOpacity = active ? 0.95 : 0
                lamp.accessibilityLabel = active ? "Đến lượt \(matchPlay.names[seat])" : nil
                if active, lamp.layer.animation(forKey: "breath") == nil {
                    let breath = CABasicAnimation(keyPath: "opacity"); breath.fromValue = 1; breath.toValue = 0.45
                    breath.duration = 0.8; breath.autoreverses = true; breath.repeatCount = .infinity
                    lamp.layer.add(breath, forKey: "breath")
                } else if !active { lamp.layer.removeAnimation(forKey: "breath") }
            }
        }
        set(12, "R\(matchPlay.raceTo) · V\(matchPlay.rackNo)", rounded(10, .bold), style.centreText, plate: style.centre)
        view.bringSubviewToFront(board)
        updateGroupStrips()
    }
    /// Display name for a plate: upper case; long names keep the given name whole and shorten the rest to initials
    /// ("Nguyễn Văn Anh" → "N.V. ANH"); the computer's level is abbreviated ("Máy · Quarter Pro" → "MÁY · QP").
    static func scoreboardName(_ raw: String) -> String {
        let short = ["Beginner": "BEG", "Amateur": "AMA", "Quarter Pro": "QP", "Semi Pro": "SP", "Pro": "PRO", "AI": "AI"]
        let parts = raw.components(separatedBy: " · ")
        if parts.count == 2, let level = short[parts[1]] { return (parts[0] + " · " + level).uppercased() }
        let words = raw.split(separator: " ").map(String.init)
        guard raw.count > 12, words.count > 1 else { return raw.uppercased() }
        return (words.dropLast().compactMap { $0.first.map { String($0) + "." } }.joined() + " " + words.last!).uppercased()
    }
    func leaveMatch() {
        guard !shotActive || matchSimulationPaused || matchPlay.session.role == .guest else { notifyStatus("Chờ bi dừng trước khi rời trận"); return }
        matchPlay.active = false
        matchPlay.computerLevel = nil; matchPlay.computerThinking = false; matchPlay.computerAim = nil; matchPlay.humanSetup = nil
        UIApplication.shared.isIdleTimerDisabled = false; matchPlay.awaySince = nil; matchPlay.everConnected = false
        matchPlay.remoteAim = nil; matchRestoreLocalCue()
        matchPlay.session.leave()
        matchPlay.rules = nil; matchPlay.state = [:]
        matchPlay.placementDraft = nil; matchPlay.placementOrigin = nil
        matchPlay.guestBalls = []; matchPlay.snapshots = []
        matchPlay.banner.isHidden = true
        coachButton.accessibilityLabel = "Coach · Huấn luyện viên"
        localTurn = true; shotActive = false; isPlacingBalls = false
        clearShot(); applyCoachVisibility(); loadDrill(0)
    }

    func syncMatchControls() {
        guard matchPlay.active else { matchPlay.banner.isHidden = true; matchPlay.scoreboard.isHidden = true; table.spectatorPivot = false; return }
        let wasLocal = localTurn
        localTurn = matchAllowsInput
        // 0.39 (owner: Wi-Fi/online — after the friend joined, every key on both sides stayed grey and the break could
        // not be played). The turn flips to this device from network callbacks (peer joined, snapshot, command), which
        // only ran this function; the cue icons, spin, elevation and quick rail are enabled in updateControls(), so they
        // kept the state from while the room was waiting. Any change of turn now refreshes every control once.
        if localTurn != wasLocal { DispatchQueue.main.async { [weak self] in self?.updateControls() } }
        updateScoreboard()
        table.spectatorPivot = !localTurn
        // 0.29: when the turn comes to this device, it is already in the ready-to-shoot aim view.
        if localTurn && !wasLocal && !shotActive && replayIndex == nil && table.cameraMode != 2 {
            aimCameraYaw = 0; shotCameraAnchor = nil; selectCamera(2)
        }
        // 0.42 item 6 (owner: watching the opponent's turn followed every aim twitch — dizzy). Tuỳ chỉnh → Camera lượt
        // đối thủ: 0 broadcast (fixed high side view of the whole table, default), 1 top, 2 follow the opponent's cue.
        if !localTurn && wasLocal && replayIndex == nil {
            switch UserDefaults.standard.object(forKey: "spectatorCam042") as? Int ?? 0 {
            case 1: beginCameraTransition(0.6); selectCamera(1)
            case 2: break
            default:
                beginCameraTransition(0.6); selectCamera(0)
                table.focusBounds = nil; table.orbitPitch = 0.62; table.zoom = 1.0
                table.orbit = -0.20   // yaw 0 in placeCamera: from the long side, the whole table across a landscape screen
            }
        }
        matchPlay.banner.isHidden = locked || menuOpen
        matchPlay.banner.setTitle(matchStatusText().replacingOccurrences(of: "\n", with: "  ·  "), for: .normal)
        presentPendingChoiceIfNeeded()
        coachButton.setTitle(matchPlay.showNumbers ? "123 ✓" : "123", for: .normal)
        coachButton.accessibilityLabel = "Bật tắt nút số băng · không có đường hướng dẫn"
        coachButton.accessibilityValue = matchPlay.showNumbers ? "Bật" : "Tắt"
        coachCard.isHidden = true
        table.setCompetitivePresentation(numbers: matchPlay.showNumbers && !locked)
        for button in [quickAdd,undoButton,retryButton,resetButton,drillButton,layoutButton,settingsButton,replayButton,quickReplay] {
            button?.isEnabled = false
        }
        quickPlace?.isEnabled = matchAllowsInput && !shotActive && matchBool("ballInHand") && (matchPlay.state["pendingChoice"] as? String ?? "").isEmpty
        lockButton.isEnabled = strokeAllowed
        stroke.isEnabled = locked && strokeAllowed
        stroke.isUserInteractionEnabled = stroke.isEnabled
        testShotButton.isEnabled = matchCanStroke && !presentationBusy && !isPlacingBalls
        guideOn = false
        wakeRendering()
        if matchPlay.session.role != .guest { publishMatchSnapshot() }
    }
    func matchToggleNumbers() {
        matchPlay.showNumbers.toggle()
        syncMatchControls()
    }
    func matchStatusText() -> String {
        let name = matchPlay.state["rule"] as? String == "rotation15" ? "15 Rotation" :
            (matchDisciplines.first { $0.0 == (matchPlay.state["rule"] as? String) }?.1 ?? "Trận Wi-Fi")
        let room = matchPlay.session.role == .none ? "Chuyền máy" : "Mã \(matchPlay.session.roomCode)"
        if let since = matchPlay.awaySince, matchPlay.everConnected, matchPlay.matchWinner < 0 {
            let away = Int(ProcessInfo.processInfo.systemUptime - since)
            let left = max(0, Int(Self.awayForfeitSeconds) - away)
            if matchPlay.session.role == .host {
                return "\(room) · Đối thủ tạm vắng \(away) s\nBạn vẫn đánh lượt của mình · đối thủ quá \(Int(Self.awayTurnSeconds)) s/lượt bị lỗi · xử thắng sau \(left) s"
            }
            return "\(room) · Chủ phòng tạm vắng \(away) s\nChờ nối lại · bạn được xử thắng sau \(left) s"
        }
        if matchSimulationPaused { return "\(room) · TẠM DỪNG\n\(matchPlay.lastStatus)" }
        let winner = matchInt("winner", fallback: -1)
        if matchPlay.matchWinner >= 0 { return "\(name) · \(room)\n\(matchPlay.names[matchPlay.matchWinner]) thắng trận \(matchPlay.frames.max() ?? 0)–\(matchPlay.frames.min() ?? 0) · chạm để chơi trận mới" }
        if winner >= 0 { return "\(name) · \(room)\n\(matchPlay.names[winner]) thắng ván · ván mới sau giây lát" }
        let player = matchInt("currentPlayer")
        let seat = matchPlay.session.role == .none ? "Lượt \(matchPlay.names[min(1, max(0, player))])" : (player == matchPlay.session.localPlayer ? "Lượt của bạn" : "Đang xem đối thủ")
        var detail = matchReason(matchPlay.state["reason"] as? String ?? "")
        if let warnings = matchPlay.state["twoFoulWarning"] as? [Bool], warnings.indices.contains(player), warnings[player] {
            detail = "2 lỗi liên tiếp · lỗi nữa thua ván"
        } else if !(matchPlay.state["pendingChoice"] as? String ?? "").isEmpty { detail = "Chạm để chọn quyền nhận / trả bàn" }
        else if matchBool("ballInHand") { detail = matchBool("headStringOnly") ? "Đặt bi cái sau vạch đầu bàn" : "Bi cái trong tay · chạm Đặt bi" }
        else if matchPlay.pushOut { detail = "Đã khai Push-out" }
        else if matchPlay.safety { detail = "Đã gọi đánh an toàn" }
        else if matchPlay.calledBall > 0 { detail = "Gọi bi \(matchPlay.calledBall) · lỗ \(matchPlay.calledPocket + 1)" }
        else if matchBool("requiresCall") { detail = "Tự động: bi đi thẳng vào lỗ được tính · băng/combo: bấm Call" }
        if let scores = matchPlay.state["scores"] as? [Int], scores.count == 2, matchPlay.state["rule"] as? String == "rotation15" { detail += " · \(scores[0])–\(scores[1])/61" }
        if let groups = matchPlay.state["groups"] as? [Int], groups.count == 2, matchPlay.state["rule"] as? String == "eightBall", groups[player] >= 0 { detail += groups[player] == 0 ? " · bi trơn" : " · bi sọc" }
        return "\(name) · \(room) · \(seat)\n\(detail)"
    }

    func openMatchActions() {
        guard matchPlay.active, !locked else { return }
        let sheet = UIAlertController(title: matchStatusText(), message: "Camera quan sát thuộc từng máy. Trận đối kháng luôn tắt mọi đường hướng dẫn; chỉ có nút số băng tùy chọn.", preferredStyle: .actionSheet)
        if matchPlay.matchWinner >= 0, matchPlay.session.role != .guest {
            sheet.addAction(UIAlertAction(title: "Trận mới · cùng người chơi, race \(matchPlay.raceTo)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.matchPlay.frames = [0, 0]; self.matchPlay.rackNo = 0; self.matchPlay.matchWinner = -1; self.matchPlay.breaker = 1
                self.startNextRack()
            })
        }
        if matchAllowsInput, !shotActive, matchInt("winner", fallback: -1) < 0 {
            let options = matchPlay.state["choiceOptions"] as? [String] ?? []
            for option in options {
                sheet.addAction(UIAlertAction(title: matchChoiceTitle(option), style: .default) { [weak self] _ in self?.submitMatchAction(.chooseOption, option: option) })
            }
            if options.isEmpty {
                if matchBool("requiresCall") {
                    sheet.addAction(UIAlertAction(title: "Gọi bi và lỗ", style: .default) { [weak self] _ in self?.chooseMatchCall() })
                    if matchPlay.state["rule"] as? String == "eightBall" {
                        sheet.addAction(UIAlertAction(title: "Gọi đánh an toàn", style: .default) { [weak self] _ in
                            self?.submitMatchAction(.callShot, call: LANCall(ball: 0, pocket: -1, safety: true))
                        })
                    }
                }
                if matchBool("pushOutAvailable") {
                    sheet.addAction(UIAlertAction(title: "Khai Push-out cho cú kế tiếp", style: .default) { [weak self] _ in self?.submitMatchAction(.declarePushOut) })
                }
                if matchBool("ballInHand") {
                    sheet.addAction(UIAlertAction(title: "Đặt bi cái", style: .default) { [weak self] _ in _ = self?.handleMatchPlacementToggle() })
                }
                sheet.addAction(UIAlertAction(title: "Nhận thua ván", style: .destructive) { [weak self] _ in self?.submitMatchAction(.concede) })
            }
        }
        sheet.addAction(UIAlertAction(title: matchPlay.showNumbers ? "Ẩn nút số băng" : "Hiện nút số băng", style: .default) { [weak self] _ in self?.matchToggleNumbers() })
        if matchPlay.session.role != .none {
            sheet.addAction(UIAlertAction(title: "Nối lại phòng \(matchPlay.session.roomCode)", style: .default) { [weak self] _ in self?.matchPlay.session.reconnect() })
        }
        sheet.addAction(UIAlertAction(title: "Rời trận / về luyện tập", style: .destructive) { [weak self] _ in self?.leaveMatch() })
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        presentSheet(sheet, source: matchPlay.banner)
    }
    /// 0.26 Call: full-screen top view; tap the ball, then the pocket. Cancel by tapping Call again.
    func beginMatchCallPick() {
        guard matchAllowsInput, !shotActive, matchBool("requiresCall") else { return }
        if matchCallPicking != 0 { endMatchCallPick(); notifyStatus("Đã hủy gọi lỗ"); return }
        matchCallPose = captureCamera(); selectCamera(1); matchCallPicking = 1; matchCallBall = 0
        showCallPockets(1)
        notifyStatus("Gọi lỗ · chạm vào bi muốn gọi, rồi chạm lỗ đang nhấp nháy")
    }
    func endMatchCallPick() {
        if matchCallPicking != 0 && matchPlay.calledBall == 0 { showCallPockets(0) }
        matchCallPicking = 0; matchCallBall = 0
        if let pose = matchCallPose { applyCamera(pose) }; matchCallPose = nil; syncQuickRail()
    }
    /// Returns true when the tap was used by the Call picker.
    func handleMatchCallTap(_ p: SIMD2<Double>) -> Bool {
        guard matchCallPicking != 0 else { return false }
        if matchCallPicking == 1 {
            let candidates = balls.filter { $0.id > 0 && !$0.sunk }
            guard let ball = candidates.min(by: { hypot($0.x - p.x, $0.y - p.y) < hypot($1.x - p.x, $1.y - p.y) }),
                  hypot(ball.x - p.x, ball.y - p.y) < 0.12 else { notifyStatus("Chạm gần một bi hơn"); return true }
            matchCallBall = ball.id; matchCallPicking = 2; notifyStatus("Bi \(ball.id) · chạm vào lỗ"); return true
        }
        // Pocket order = solver order (Physics.cpp World::pocket), independent of camera rotation.
        let g = engine.settings, x = (g["tableWidth"]?.doubleValue ?? 1.27) / 2, y = (g["tableLength"]?.doubleValue ?? 2.54) / 2
        let holes = [(-x, -y), (x, -y), (-x, 0.0), (x, 0.0), (-x, y), (x, y)]
        let pocket = holes.indices.min(by: { hypot(holes[$0].0 - p.x, holes[$0].1 - p.y) < hypot(holes[$1].0 - p.x, holes[$1].1 - p.y) }) ?? 0
        guard hypot(holes[pocket].0 - p.x, holes[pocket].1 - p.y) < 0.35 else { notifyStatus("Chạm gần một lỗ hơn"); return true }
        let ball = matchCallBall; endMatchCallPick()
        submitMatchAction(.callShot, call: LANCall(ball: ball, pocket: pocket))
        showCallPockets(2, chosen: pocket)
        notifyStatus("✓ Đã gọi bi \(ball) · lỗ \(pocket + 1)")
        return true
    }
    /// 0.28: ~3.4 s racking intro at the start of every rack; tap the table to skip. Input waits for it.
    func startRackIntro() {
        // Automated QA launches (UI tests, probes) skip the intro so timing-based checks stay deterministic.
        guard !ProcessInfo.processInfo.arguments.contains(where: { $0 == "--visual-qa" || $0.hasPrefix("--ux") || $0.hasSuffix("-qa") }) else { return }
        renderUntil = ProcessInfo.processInfo.systemUptime + 4
        table.playRackIntro(balls) { [weak self] in self?.wakeRendering(); self?.updateControls() }
        for (delay, impact) in [(1.0, 0.35), (1.35, 0.5), (1.7, 0.3)] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.table.rackIntroPlaying, UserDefaults.standard.object(forKey: "poolAudioEnabled") as? Bool ?? true else { return }
                self.poolAudio.play(kind: 1, impact: impact, pan: 0)
            }
        }
    }
    func chooseMatchCall() {
        guard matchAllowsInput, !shotActive else { return }
        let sheet = UIAlertController(title: "Gọi bi", message: "Chọn bi dự định vào lỗ. Phải chạm bi hợp lệ trước theo luật đang chơi.", preferredStyle: .actionSheet)
        for ball in balls.filter({ $0.id > 0 && !$0.sunk }).sorted(by: { $0.id < $1.id }) {
            sheet.addAction(UIAlertAction(title: "Bi \(ball.id)", style: .default) { [weak self] _ in self?.chooseMatchPocket(ball: ball.id) })
        }
        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        presentSheet(sheet, source: matchPlay.banner)
    }
    func chooseMatchPocket(ball: Int) {
        let sheet = UIAlertController(title: "Bi \(ball) vào lỗ nào?", message: "Vị trí nhìn từ đầu bàn phá: bên trái / phải của người phá.", preferredStyle: .actionSheet)
        // Solver order follows the actual six mouth coordinates, not screen
        // position, so rotating the camera cannot change a call's identity.
        let titles = ["1 · góc trái đầu bàn", "2 · góc phải đầu bàn", "3 · giữa trái", "4 · giữa phải", "5 · góc trái cuối bàn", "6 · góc phải cuối bàn"]
        for (pocket, title) in titles.enumerated() {
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.submitMatchAction(.callShot, call: LANCall(ball: ball, pocket: pocket))
            })
        }
        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        presentSheet(sheet, source: matchPlay.banner)
    }
    /// true means networking/rules handled or rejected this request. Only an
    /// accepted host command recurses into the normal stroke implementation.
    func routeMatchShot(_ speed: Double) -> Bool {
        guard matchPlay.active else { return false }
        if matchPlay.session.isApplyingCommand || matchPlay.applyingOfflineCommand { return false }
        guard locked, speed.isFinite, speed > 0, speed <= 8,
              matchCanStroke, !presentationBusy else { return true }
        // 0.42 (owner 13/11 18:19: the two-foul warning popped up while stroking and swallowed the stroke). The warning
        // is now shown once when the turn starts (presentPendingChoiceIfNeeded) and never blocks or cancels a stroke.
        // 0.26: no forced call. Uncalled shots are adjudicated by the straight-in rule (MatchRules::autoCall).
        if matchPlay.session.role == .none { return false }
        let shot = LANShot(angle: angle, speed: speed, side: side, top: top,
                           elevation: max(table.cueElevation, table.clearanceElevation),
                           cueType: engine.settings["cueType"]?.intValue ?? 0)
        submitMatchAction(.strike, shot: shot)
        return true
    }
    func submitMatchAction(_ action: LANCommand.Action, shot: LANShot? = nil,
                           placement: LANPlacement? = nil, call: LANCall? = nil, option: String? = nil) {
        guard matchPlay.active else { return }
        var command = LANCommand(player: matchPlay.session.role == .none ? matchInt("currentPlayer") : matchPlay.session.localPlayer,
                                 action: action, shot: shot, placement: placement, call: call, option: option)
        if matchPlay.session.role == .none || matchHostSolo {
            matchPlay.applyingOfflineCommand = true
            let accepted = applyMatchCommand(command)
            matchPlay.applyingOfflineCommand = false
            if !accepted { notifyStatus("Thao tác chưa hợp lệ theo luật đang chơi") }
            if matchHostSolo { publishMatchSnapshot(force: true) }   // stored; sent when the guest is back
        } else {
            guard let snapshot = matchPlay.session.latestSnapshot else { notifyStatus("Chờ đồng bộ trạng thái trận"); return }
            command.matchID = snapshot.matchID; command.expectedRevision = snapshot.revision
            if !matchPlay.session.submitCommand(command) { notifyStatus("Chờ đúng lượt hoặc chờ kết nối lại") }
        }
        updateControls(); syncMatchControls()
    }
    func applyMatchCommand(_ command: LANCommand) -> Bool {
        guard matchPlay.active, let rules = matchPlay.rules, command.isValid,
              matchInt("winner", fallback: -1) < 0 else { return false }
        if command.action == .concede {
            matchPlay.forfeitWinner = 1 - command.player
            engine.loadLayout(engine.states)
            frameStateCache = nil
            shotActive = false; locked = false
            BLShotCameraReset(&shotCameraState)
            updateMatchState()
            return true
        }
        guard command.player == matchInt("currentPlayer"), !shotActive,
              !BLShotCameraBusy(shotCameraState) else { return false }
        let choices = matchPlay.state["choiceOptions"] as? [String] ?? []
        switch command.action {
        case .chooseOption, .acceptPushOut, .returnPushOut:
            let option = command.option ?? (command.action == .acceptPushOut ? "accept" : "pass")
            guard choices.contains(option) else { return false }
            let result = rules.resolve(choice: option)
            guard (result["accepted"] as? NSNumber)?.boolValue == true else { return false }
            applyMatchResult(result)
        case .callShot:
            guard choices.isEmpty, let call = command.call, matchBool("requiresCall"),
                  !call.safety || (matchPlay.state["rule"] as? String) == "eightBall",
                  call.safety || balls.contains(where: { $0.id == call.ball && !$0.sunk }) else { return false }
            matchPlay.calledBall = call.ball; matchPlay.calledPocket = call.pocket
            matchPlay.safety = call.safety; matchPlay.pushOut = false
            rules.setCall(ball: call.ball, pocket: call.pocket, safety: call.safety, pushOut: false)
        case .declarePushOut:
            guard choices.isEmpty, matchBool("pushOutAvailable") else { return false }
            matchPlay.pushOut = true; matchPlay.calledBall = 0; matchPlay.calledPocket = -1; matchPlay.safety = false
            rules.setCall(ball: 0, pocket: -1, safety: false, pushOut: true)
        case .placeCue:
            guard choices.isEmpty, matchBool("ballInHand"), let placement = command.placement else { return false }
            var state = engine.ballStates
            guard let index = state.firstIndex(where: { $0.id == 0 }) else { return false }
            state[index].x = placement.x; state[index].y = placement.y; state[index].sunk = false
            state[index].height = 0; state[index].vertical = 0
            guard matchCuePositionValid(state) else { return false }
            engine.loadLayout(state.map { $0.dictionary })
            frameStateCache = nil
            matchPlay.placementDraft = nil; matchPlay.placementOrigin = nil
            isPlacingBalls = false; table.placementBlocked = false
            refresh()
        case .strike:
            guard choices.isEmpty, let shot = command.shot, shot.isValid,
                  matchCuePositionValid(engine.ballStates),
                  true else { return false }
            angle = shot.angle; side = shot.side; top = shot.top
            var config = engine.settings
            config["cueType"] = NSNumber(value: shot.cueType)
            config["cueElevationDegrees"] = NSNumber(value: shot.elevation)
            config["experimental3D"] = NSNumber(value: shot.elevation > 35 || shot.cueType == 1)
            shotKind = shot.cueType == 0 && shot.elevation > 35 ? 3 : shot.cueType
            shotKindPhysics(shotKind, &config)   // 0.21: same tip/squirt/massé policy as practice on both devices
            engine.settings = config
            table.selectCue(shot.cueType); table.cueElevation = shot.elevation
            spin.select(side: shot.side, top: shot.top)
            guard cueClearance(side: shot.side, top: shot.top) <= shot.elevation + 0.01 else { return false }
            localTurn = true; locked = true; menuOpen = false
            isPlacingBalls = false; matchPlay.placementDraft = nil
            recordStrikeInfo(shot, player: command.player)
            let byOpponent = (matchPlay.session.role == .host && command.player != matchPlay.session.localPlayer) ||
                (matchPlay.session.role == .none && matchPlay.computerLevel != nil && command.player == 1)
            if byOpponent {
                showOpponentShot(speed: shot.speed, side: shot.side, top: shot.top, elevation: shot.elevation, cueType: shot.cueType,
                                 who: matchPlay.names[min(1, max(0, command.player))])
            }
            if matchPlay.session.role == .host, command.player != matchPlay.session.localPlayer,
               let origin = engine.ballStates.first(where: { $0.id == 0 }) {
                // 0.42 item 10: the guest's cue is seen meeting the ball and following through on the host too.
                beginCueStrikeAnim(origin: origin, angle: shot.angle, side: shot.side, top: shot.top, elevation: shot.elevation,
                                   cueType: shot.cueType, fromPull: 0, lead: 0)
            }
            shoot(shot.speed)
            guard shotActive else { syncMatchControls(); return false }
            // A remote player has no physical B release on this host. Unlock
            // observation immediately; shotActive still prevents another hit.
            setHold(false)
        case .concede: break
        }
        updateMatchState(); syncMatchControls()
        return true
    }
    func didStartMatchShot() {
        guard matchPlay.active else { return }
        matchPlay.shotID += 1
        matchPlay.elapsed = 0
        matchPlay.crossed.removeAll(); matchPlay.publishedEvents = 0
        matchPlay.warningAcknowledged = nil
        syncMatchControls()
        publishMatchSnapshot(force: true)
    }
    func didAdvanceMatchShot() {
        guard matchPlay.active, matchPlay.session.role != .guest else { return }
        matchPlay.elapsed = engine.elapsed
        for ball in balls where ball.id > 0 && !ball.sunk && ball.y < -0.635 { matchPlay.crossed.insert(ball.id) }
        // 0.43 (anh: "đấu không mượt như lúc tập"): was `engine.events` — the WHOLE shot's event list bridged into
        // dictionaries every frame (hundreds after a break). Now only the new ones.
        let newEvents = engine.events(since: UInt(matchPlay.publishedEvents))
        if !newEvents.isEmpty {
            let base = matchPlay.publishedEvents
            let fresh = newEvents.enumerated().compactMap { matchEvent($0.element, index: base + $0.offset) }
            for start in stride(from: 0, to: fresh.count, by: 128) {
                matchPlay.session.publishEvents(Array(fresh[start..<min(start + 128, fresh.count)]), shotID: matchPlay.shotID)
            }
            matchPlay.publishedEvents = base + newEvents.count
        }
        publishMatchSnapshot()
    }
    func finishMatchShot() -> Bool {
        guard matchPlay.active, let rules = matchPlay.rules, matchPlay.session.role != .guest else { return false }
        frameStateCache = nil
        let result = rules.complete(before: before.map { $0.dictionary },
                                    after: engine.states, events: lastShotEvents,
                                    headCrossed: matchPlay.crossed.sorted().map { NSNumber(value: $0) })
        if (result["accepted"] as? NSNumber)?.boolValue == true { applyMatchResult(result) }
        else {
            // Never continue an unadjudicated match or silently label it legal.
            matchPlay.state["canShoot"] = false
            matchPlay.state["reason"] = "invalid_evidence"
            notifyStatus("Không thể xác minh cú đánh · rời trận để khởi tạo lại")
        }
        resetMatchCall()
        table.setCompetitivePresentation(numbers: matchPlay.showNumbers)
        refresh(); updateControls(); syncMatchControls(); publishMatchSnapshot(force: true)
        return true
    }
    func resetMatchCall() {
        matchPlay.calledBall = 0; matchPlay.calledPocket = -1; showCallPockets(0)
        matchPlay.safety = false; matchPlay.pushOut = false
        matchPlay.rules?.setCall(ball: 0, pocket: -1, safety: false, pushOut: false)
    }
    func updateMatchState() {
        guard let rules = matchPlay.rules else { return }
        matchPlay.state = rules.state
        if let winner = matchPlay.forfeitWinner {
            matchPlay.state["winner"] = winner
            matchPlay.state["canShoot"] = false
            matchPlay.state["reason"] = "conceded"
        }
    }
    func applyMatchResult(_ result: [String:Any]) {
        updateMatchState()
        if (result["rerack"] as? NSNumber)?.boolValue == true, let rules = matchPlay.rules {
            engine.loadLayout(rules.rack(seed: UInt64.random(in: 1...UInt64.max)))
            startRackIntro()
            table.resetPocketPresentation()
        } else {
            var state = engine.ballStates
            let spots = (result["spotBalls"] as? [NSNumber] ?? []).map { $0.intValue }
            for id in Set(spots).sorted() { spotMatchBall(id, in: &state) }
            if matchBool("ballInHand"), let index = state.firstIndex(where: { $0.id == 0 }), state[index].sunk {
                state[index].sunk = false
                state[index].height = 0; state[index].vertical = 0
                placeMatchCueInFreeArea(&state)
            }
            if !spots.isEmpty || matchBool("ballInHand") { engine.loadLayout(state.map { $0.dictionary }) }
        }
        frameStateCache = nil
        resetMatchCall()
        statusLabel.text = matchReason(matchPlay.state["reason"] as? String ?? "")
        recordRackIfFinished()
    }
    /// 0.29: count the rack; next rack starts by itself after 1.2 s (alternate break) unless the race is won.
    func recordRackIfFinished() {
        let winner = matchInt("winner", fallback: -1)
        guard winner >= 0, !matchPlay.rackCounted, matchPlay.matchWinner < 0, matchPlay.session.role != .guest else { return }
        matchPlay.rackCounted = true
        var a = Int32(matchPlay.frames[0]), b = Int32(matchPlay.frames[1])
        let decided = Int(BLRaceRecordRack(&a, &b, Int32(matchPlay.raceTo), Int32(winner)))
        matchPlay.frames = [Int(a), Int(b)]
        updateScoreboard()
        if decided >= 0 {
            matchPlay.matchWinner = decided
            notifyStatus("\(matchPlay.names[decided]) thắng trận \(matchPlay.frames[decided])–\(matchPlay.frames[1 - decided])")
            publishMatchSnapshot(force: true); showRackBroadcast(winner: decided, isFinal: true); return
        }
        notifyStatus("\(matchPlay.names[winner]) thắng ván \(matchPlay.rackNo) · \(matchPlay.frames[0])–\(matchPlay.frames[1])")
        publishMatchSnapshot(force: true)
        showRackBroadcast(winner: winner, isFinal: false)   // 0.42 item 3: TV score card, 3.5 s, then the next rack
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) { [weak self] in self?.startNextRack() }
    }
    func startNextRack() {
        guard matchPlay.active, matchPlay.matchWinner < 0, let rules = matchPlay.rules, !shotActive else { return }
        matchPlay.breaker = Int(BLRaceNextBreaker(Int32(matchPlay.breaker)))
        matchPlay.rackNo += 1; matchPlay.rackCounted = false
        rules.reset(breaker: matchPlay.breaker)
        engine.loadLayout(rules.rack(seed: UInt64.random(in: 1...UInt64.max)))
        table.resetPocketPresentation(); clearShot()
        updateMatchState(); initial = balls; before = initial
        startRackIntro()
        refresh(); updateControls(); syncMatchControls(); publishMatchSnapshot(force: true)
    }

    func matchCuePositionValid(_ state: [BallState]) -> Bool {
        guard let cue = state.first(where: { $0.id == 0 }), !cue.sunk,
              cue.x.isFinite, cue.y.isFinite else { return false }
        guard matchBool("ballInHand") else { return true }
        guard
              abs(cue.x) <= 0.635 - 0.028575,
              abs(cue.y) <= 1.27 - 0.028575 else { return false }
        if matchBool("ballInHand"), matchBool("headStringOnly"), cue.y >= -0.635 { return false }
        return !state.contains { $0.id > 0 && !$0.sunk && hypot($0.x - cue.x, $0.y - cue.y) < 0.0571501 }
    }
    func placeMatchCueInFreeArea(_ state: inout [BallState]) {
        guard let cueIndex = state.firstIndex(where: { $0.id == 0 }) else { return }
        let ys: [Double] = matchBool("headStringOnly") ? [-0.90,-0.72,-1.10] : [0,-0.90,0.90,-0.45,0.45]
        for y in ys {
            for x in [0.0,-0.14,0.14,-0.28,0.28,-0.42,0.42,-0.56,0.56] {
                state[cueIndex].x = x; state[cueIndex].y = y
                if matchCuePositionValid(state) { return }
            }
        }
    }
    func spotMatchBall(_ id: Int, in state: inout [BallState]) {
        guard let index = state.firstIndex(where: { $0.id == id }) else { return }
        let spacing = 0.057151
        // Foot spot, then towards the foot cushion; if blocked, back towards
        // the head cushion, all along the longitudinal spotting line.
        let forward: [Double] = (0...10).map { index in 0.635 + Double(index) * spacing }
        let backward: [Double] = (1...32).map { index in 0.635 - Double(index) * spacing }
        let candidates: [Double] = forward + backward
        for y in candidates where abs(y) <= 1.27 - 0.028575 {
            if state.contains(where: { $0.id != id && !$0.sunk && hypot($0.x, $0.y - y) < spacing }) { continue }
            state[index].x = 0; state[index].y = y; state[index].sunk = false
            state[index].height = 0; state[index].vertical = 0
            return
        }
        // This is impossible for a normal <=16-ball table; hold the match if
        // malformed state prevents a legal spot rather than overlap balls.
        matchPlay.state["canShoot"] = false
        matchPlay.state["reason"] = "spot_blocked"
    }
    func handleMatchPlacementToggle() -> Bool {
        guard matchPlay.active else { return false }
        guard matchAllowsInput, !presentationBusy, matchBool("ballInHand"),
              (matchPlay.state["pendingChoice"] as? String ?? "").isEmpty else {
            notifyStatus("Chỉ được đặt bi cái khi có quyền bi trong tay"); return true
        }
        if let draft = matchPlay.placementDraft, let cue = draft.first(where: { $0.id == 0 }) {
            guard matchCuePositionValid(draft) else { notifyStatus("Vị trí vướng bi / ngoài vùng đặt hợp lệ"); return true }
            submitMatchAction(.placeCue, placement: LANPlacement(x: cue.x, y: cue.y))
            if let pose = placementPose { applyCamera(pose) }; placementPose = nil
            if matchPlay.session.role == .guest {
                // Only the authoritative snapshot confirms this placement.
                notifyStatus("Đang xác nhận vị trí với máy chủ")
            }
        } else {
            matchPlay.placementOrigin = balls
            var state = balls
            if let index = state.firstIndex(where: { $0.id == 0 }) {
                state[index].x = 0; state[index].y = matchBool("headStringOnly") ? -0.9 : 0
                state[index].sunk = false; state[index].height = 0; state[index].vertical = 0
            }
            matchPlay.placementDraft = state
            isPlacingBalls = true
            // 0.42 item 9: top-down view while placing (restored on confirm / cancel).
            if placementPose == nil { placementPose = captureCamera(); selectCamera(1) }
            table.placementBlocked = !matchCuePositionValid(state)
            notifyStatus("Chạm chỗ muốn đặt hoặc kéo ở bất kỳ đâu · chạm Đặt bi lần nữa để xác nhận")
            refresh()
        }
        updateControls(); syncMatchControls(); return true
    }
    func handleMatchMoveBall(_ id: Int, to point: SIMD2<Double>) -> Bool {
        guard matchPlay.active else { return false }
        guard id == 0, matchAllowsInput, var draft = matchPlay.placementDraft,
              let index = draft.firstIndex(where: { $0.id == 0 }) else { return true }
        draft[index].x = min(0.635 - 0.028575, max(-0.635 + 0.028575, point.x))
        let maxY = matchBool("headStringOnly") ? -0.635001 : 1.27 - 0.028575
        draft[index].y = min(maxY, max(-1.27 + 0.028575, point.y))
        matchPlay.placementDraft = draft
        table.placementBlocked = !matchCuePositionValid(draft)
        refresh(); wakeRendering(); return true
    }
    func handleMatchPlacementCancel() -> Bool {
        guard matchPlay.active else { return false }
        matchPlay.placementDraft = nil; matchPlay.placementOrigin = nil
        isPlacingBalls = false; table.placementBlocked = false
        if let pose = placementPose { applyCamera(pose) }; placementPose = nil
        refresh(); updateControls(); syncMatchControls(); return true
    }

    func matchEvent(_ dictionary: [String:NSNumber], index: Int) -> LANEvent? {
        let event = LANEvent(index: index, kind: dictionary["kind"]?.intValue ?? -1,
                             a: dictionary["a"]?.intValue ?? -1, b: dictionary["b"]?.intValue ?? -1,
                             time: dictionary["time"]?.doubleValue ?? 0,
                             x: dictionary["x"]?.doubleValue ?? 0, y: dictionary["y"]?.doubleValue ?? 0,
                             impact: dictionary["impact"]?.doubleValue ?? 0)
        return event.isValid ? event : nil
    }
    func matchWireBall(_ ball: BallState) -> LANBall {
        LANBall(id: ball.id, x: ball.x, y: ball.y, vx: ball.vx ?? 0, vy: ball.vy ?? 0,
                wx: ball.wx, wy: ball.wy, spin: ball.spin,
                height: max(0, ball.height ?? 0), vertical: ball.vertical ?? 0,
                qx: ball.qx ?? 0, qy: ball.qy ?? 0, qz: ball.qz ?? 0, qw: ball.qw ?? 1,
                sunk: ball.sunk, rails: ball.rails)
    }
    func matchRenderBall(_ ball: LANBall) -> BallState {
        var result = BallState(id: ball.id, x: ball.x, y: ball.y)
        result.vx = ball.vx; result.vy = ball.vy; result.wx = ball.wx; result.wy = ball.wy
        result.spin = ball.spin; result.height = ball.height; result.vertical = ball.vertical
        result.qx = ball.qx; result.qy = ball.qy; result.qz = ball.qz; result.qw = ball.qw
        result.sunk = ball.sunk; result.rails = ball.rails
        return result
    }
    func publishMatchSnapshot(force: Bool = false) {
        guard matchPlay.active, matchPlay.session.role == .host else { return }
        // 0.41 (owner: match play less smooth than practice). The host built the rules JSON, 128 events and every ball
        // on EVERY display frame, then the session dropped all but 10–20 per second. Build only when it can be sent.
        let now = ProcessInfo.processInfo.systemUptime
        if !force && now - matchPlay.lastSnapshotBuild < matchPlay.session.snapshotInterval { return }
        matchPlay.lastSnapshotBuild = now
        var state = matchPlay.state
        state["calledBall"] = matchPlay.calledBall; state["calledPocket"] = matchPlay.calledPocket
        state["safety"] = matchPlay.safety; state["pushOut"] = matchPlay.pushOut
        state["raceTo"] = matchPlay.raceTo; state["frames"] = matchPlay.frames; state["names"] = matchPlay.names; state["lastShot"] = Self.lastShotInfo
        state["rackNo"] = matchPlay.rackNo; state["matchWinner"] = matchPlay.matchWinner
        guard let json = try? JSONSerialization.data(withJSONObject: state) else { return }
        // 0.43: bridge only the last 128 (was the whole list, then suffix). publishedEvents tracks the world's count.
        let tailStart = max(0, matchPlay.publishedEvents - 128)
        let tail = engine.events(since: UInt(tailStart))
        let events = tail.suffix(128).enumerated().compactMap { matchEvent($0.element, index: tailStart + max(0, tail.count - 128) + $0.offset) }
        // Read the world rather than the placement preview or presentation
        // cache: a guest's unconfirmed placement is never authoritative.
        let snapshot = LANSnapshot(shotID: matchPlay.shotID, elapsed: matchPlay.elapsed,
                                   balls: engine.states.map { matchWireBall(BallState($0)) },
                                   currentPlayer: matchInt("currentPlayer"),
                                   isMoving: shotActive || BLShotCameraBusy(shotCameraState),
                                   isPaused: !matchPlay.session.isConnected,
                                   angle: angle, events: events, rulesJSON: json)
        _ = matchPlay.session.publishSnapshot(snapshot, force: force)
    }
    func receiveMatchSnapshot(_ snapshot: LANSnapshot) {
        guard matchPlay.active, matchPlay.session.role == .guest,
              snapshot.isValid, let state = snapshot.rulesDictionary else { return }
        let isFirst = matchPlay.snapshots.isEmpty
        let newShot = snapshot.shotID != matchPlay.lastGuestShot
        let newTurn = snapshot.currentPlayer != matchPlay.lastGuestTurn
        if newShot || (resyncCameraNeeded(snapshot) && shotCameraAnchor == nil) {
            // Capture the pre-shot position before replacing the displayed
            // balls. A guest must keep its Aim3D origin while the cue moves.
            shotCameraAnchor = matchPlay.guestBalls.first(where: { $0.id == 0 }) ??
                snapshot.balls.first(where: { $0.id == 0 }).map { matchRenderBall($0) }
            liveCameraAngle = angle
            // 0.42 item 10: the host's stroke — close the back-swing onto the ball, then follow through.
            if newShot, snapshot.isMoving, snapshot.currentPlayer != matchPlay.session.localPlayer, let shown = matchPlay.remoteShown ?? matchPlay.remoteAim, shown.visible,
               let origin = matchPlay.guestBalls.first(where: { $0.id == 0 }) {
                beginCueStrikeAnim(origin: origin, angle: shown.angle, side: shown.side, top: shown.top, elevation: shown.elevation,
                                   cueType: shown.cueType, fromPull: shown.pull, lead: 0.1)
            }
            if newShot, snapshot.isMoving, snapshot.currentPlayer != matchPlay.session.localPlayer,
               let info = state["lastShot"] as? [String: NSNumber], let speed = info["speed"]?.doubleValue {
                showOpponentShot(speed: speed, side: info["side"]?.doubleValue ?? 0, top: info["top"]?.doubleValue ?? 0,
                                 elevation: info["elevation"]?.doubleValue ?? 0, cueType: info["cueType"]?.intValue ?? 0,
                                 who: matchPlay.names[min(1, max(0, snapshot.currentPlayer))])
            }
        }
        let gap = snapshot.elapsed - (matchPlay.snapshots.last?.elapsed ?? snapshot.elapsed)
        let resync = isFirst || matchPlay.needsFullSync || (!newShot && gap > 0.5)
        matchPlay.needsFullSync = false
        if newShot { matchPlay.playout.beginShot() }
        if snapshot.isMoving { matchPlay.playout.observe(arrival: ProcessInfo.processInfo.systemUptime, elapsed: snapshot.elapsed) }
        if newShot || newTurn || isFirst { matchPlay.pendingAimSync = true }
        matchPlay.state = state
        matchPlay.calledBall = (state["calledBall"] as? NSNumber)?.intValue ?? 0
        matchPlay.calledPocket = (state["calledPocket"] as? NSNumber)?.intValue ?? -1
        matchPlay.safety = (state["safety"] as? NSNumber)?.boolValue ?? false
        matchPlay.pushOut = (state["pushOut"] as? NSNumber)?.boolValue ?? false
        if let race = (state["raceTo"] as? NSNumber)?.intValue { matchPlay.raceTo = Int(BLRaceClamp(Int32(race))) }
        let framesBefore = matchPlay.frames, winnerBefore = matchPlay.matchWinner
        if let f = state["frames"] as? [NSNumber], f.count == 2 { matchPlay.frames = f.map { max(0, min(99, $0.intValue)) } }
        if let n = state["names"] as? [String], n.count == 2 { matchPlay.names = n.map { String($0.prefix(16)) } }
        matchPlay.rackNo = (state["rackNo"] as? NSNumber)?.intValue ?? matchPlay.rackNo
        matchPlay.matchWinner = (state["matchWinner"] as? NSNumber)?.intValue ?? -1
        // 0.42 item 3: the guest shows the same broadcast card when the host counts a rack.
        if !isFirst, matchPlay.frames != framesBefore, matchPlay.frames.reduce(0, +) > framesBefore.reduce(0, +) {
            let won = matchPlay.frames[0] > framesBefore[0] ? 0 : 1
            showRackBroadcast(winner: matchPlay.matchWinner >= 0 ? matchPlay.matchWinner : won, isFinal: matchPlay.matchWinner >= 0 && winnerBefore < 0)
        }
        if newShot {
            matchPlay.snapshots = []
            matchPlay.guestClock = max(0, snapshot.elapsed - matchPlay.playout.delay)
            if matchPlay.audioShotID != snapshot.shotID {
                matchPlay.audioShotID = snapshot.shotID
                matchPlay.playedEvents = []; matchPlay.audioEvents = []
            }
            if isFirst { table.resetPocketPresentation() }
        }
        if resync {
            // Rejoining mid-shot must not burst already completed sounds.
            matchPlay.snapshots.removeAll()
            matchPlay.guestClock = snapshot.isMoving ? max(0, snapshot.elapsed - matchPlay.playout.delay) : snapshot.elapsed
            matchPlay.playedEvents.formUnion(snapshot.events.map { $0.index })
            matchPlay.audioEvents.removeAll()
            matchPlay.pendingAimSync = true
        } else { queueMatchAudio(snapshot.events) }
        if let previous = matchPlay.snapshots.last,
           snapshot.elapsed < previous.elapsed || (!snapshot.isMoving && !previous.isMoving) {
            matchPlay.snapshots.removeAll()
        }
        matchPlay.snapshots.append(snapshot)
        // 10 Hz samples: 8 cover the largest internet playout delay (0.45 s).
        if matchPlay.snapshots.count > 16 { matchPlay.snapshots.removeFirst(matchPlay.snapshots.count - 16) }   // 0.41: 20 Hz Wi‑Fi needs twice the samples
        matchPlay.guestBalls = snapshot.balls.map { matchRenderBall($0) }
        if !snapshot.isMoving {
            matchPlay.placementDraft = nil; matchPlay.placementOrigin = nil
            isPlacingBalls = false; table.placementBlocked = false
            if matchPlay.pendingAimSync {
                aimCameraYaw += angle - snapshot.angle
                angle = snapshot.angle; guideDirty = true
                matchPlay.pendingAimSync = false
            }
        }
        matchPlay.lastGuestShot = snapshot.shotID; matchPlay.lastGuestTurn = snapshot.currentPlayer
        matchPlay.shotID = snapshot.shotID
        syncMatchControls(); updateControls(); wakeRendering()
    }
    func resyncCameraNeeded(_ snapshot: LANSnapshot) -> Bool {
        snapshot.isMoving && (matchPlay.needsFullSync || matchPlay.snapshots.isEmpty)
    }
    func queueMatchAudio(_ events: [LANEvent]) {
        let queued = Set(matchPlay.audioEvents.map { $0.index })
        matchPlay.audioEvents.append(contentsOf: events.filter {
            !matchPlay.playedEvents.contains($0.index) && !queued.contains($0.index)
        })
        matchPlay.audioEvents.sort { $0.time == $1.time ? $0.index < $1.index : $0.time < $1.time }
        if matchPlay.audioEvents.count > 512 { matchPlay.audioEvents.removeFirst(matchPlay.audioEvents.count - 512) }
    }
    /// Guest rendering uses a short snapshot buffer. The interpolation clock is
    /// shared with audio; no network callback plays an impact before its frame.
    func matchGuestTick(_ dt: Double) -> Bool {
        guard matchPlay.active else { return false }
        matchPlay.banner.isHidden = locked || menuOpen
        if matchPlay.session.role != .guest { return false }
        guard let latest = matchPlay.snapshots.last else { return true }
        if !latest.isPaused && matchPlay.session.isConnected {
            matchPlay.guestClock = matchPlay.playout.advance(clock: matchPlay.guestClock, dt: dt,
                                                             latest: latest.elapsed, moving: latest.isMoving)
        }
        let later = matchPlay.snapshots.first { $0.elapsed >= matchPlay.guestClock } ?? latest
        let earlier = matchPlay.snapshots.last { $0.elapsed <= matchPlay.guestClock } ?? matchPlay.snapshots.first ?? latest
        let interval = later.elapsed - earlier.elapsed
        let fraction = interval > 0 ? max(0, min(1, (matchPlay.guestClock - earlier.elapsed) / interval)) : 1
        var from = earlier.balls.map { matchRenderBall($0) }, to = later.balls.map { matchRenderBall($0) }
        if interval > 0 {
            // Follow the rolling curve from host velocities between 10 Hz samples.
            let laterByID = Dictionary(uniqueKeysWithValues: later.balls.map { ($0.id, $0) })
            for (index, a) in earlier.balls.enumerated() {
                guard let b = laterByID[a.id], SnapshotCurve.eligible(a, b),
                      let target = to.firstIndex(where: { $0.id == a.id }) else { continue }
                let point = SnapshotCurve.position(a, b, interval: interval, fraction: fraction)
                from[index].x = point.x; from[index].y = point.y
                to[target].x = point.x; to[target].y = point.y
            }
        }
        if let draft = matchPlay.placementDraft { table.update(draft, dt: dt) }
        else {
            table.replay(from, to: to, fraction: fraction)
            let targets = Dictionary(uniqueKeysWithValues: to.map { ($0.id, $0) })
            matchPlay.guestBalls = from.map { a in
                guard let b = targets[a.id], !a.sunk else { return a }
                if b.sunk && fraction >= 1 { return b }
                var ball = a
                ball.x += (b.x - a.x) * fraction; ball.y += (b.y - a.y) * fraction
                ball.height = (a.height ?? 0) + ((b.height ?? 0) - (a.height ?? 0)) * fraction
                return ball
            }
        }
        while let event = matchPlay.audioEvents.first, event.time <= matchPlay.guestClock {
            matchPlay.audioEvents.removeFirst(); matchPlay.playedEvents.insert(event.index)
            if !latest.isPaused, UserDefaults.standard.object(forKey: "poolAudioEnabled") as? Bool ?? true {
                poolAudio.play(kind: event.kind, impact: event.impact,
                               pan: audioPan(event.x, event.y), eventAge: max(0, matchPlay.guestClock - event.time))
            }
        }
        if latest.isMoving, !latest.isPaused, matchPlay.session.isConnected { wakeRendering() }
        return true
    }
    func matchChoiceTitle(_ choice: String) -> String {
        ["accept":"Nhận bàn / tiếp tục", "pass":"Trả lượt cho người vừa đánh",
         "ballInHand":"Nhận bi cái trong tay", "spotAndPlay":"Đặt lại bi 8 và tiếp tục",
         "rerackSelf":"Xếp lại · tôi phá", "rerackOpponent":"Xếp lại · đối thủ phá"][choice] ?? choice
    }
    func matchReason(_ reason: String) -> String {
        ["break":"Bắt đầu · phá hợp lệ", "legal_pot":"Vào bi hợp lệ · tiếp tục", "called_pot":"Đúng bi / lỗ đã gọi · tiếp tục",
         "points_scored":"Đã cộng điểm", "turn_passed":"Hết lượt", "scratch":"Lỗi bi cái vào lỗ",
         "ball_off_table":"Lỗi bi ra khỏi bàn", "wrong_ball_first":"Lỗi chạm sai bi đầu tiên",
         "no_rail_after_contact":"Lỗi không chạm băng / vào bi sau tiếp xúc", "bad_cue_ball_placement":"Lỗi vị trí bi cái",
         "illegal_break_four_rails":"Phá chưa đủ bốn bi chạm băng", "three_ball_break_not_met":"Phá 9 Ball chưa đạt điều kiện ba bi",
         "eight_on_legal_break":"Bi 8 vào khi phá · chọn xử lý", "eight_on_foul_break":"Bi 8 vào khi phá lỗi",
         "push_out_choice":"Push-out · người kế chọn nhận / trả", "uncalled_ball_choice":"Vào bi không gọi · chọn nhận / trả",
         "nine_ball_win":"Vào bi 9 hợp lệ", "ten_ball_win":"Vào bi 10 cuối cùng hợp lệ", "eight_ball_win":"Vào bi 8 hợp lệ",
         "rotation_61_win":"Đã đạt 61 điểm", "rotation_tiebreak_win":"Thắng 61–60 · điểm phân thắng bại", "early_eight":"Thua do vào bi 8 sớm", "eight_on_foul":"Thua do bi 8 trong cú lỗi",
         "eight_wrong_pocket":"Thua do bi 8 sai lỗ", "three_consecutive_fouls":"Thua do ba lỗi liên tiếp sau cảnh báo",
         "conceded":"Đối thủ nhận thua", "invalid_evidence":"Cú đánh không đủ dữ liệu để xác minh",
         "spot_blocked":"Không có chỗ hợp lệ để đặt lại bi"][reason] ?? "Tiếp tục theo quyền hiện tại"
    }
}

// MARK: - 0.40 Đấu với máy (computer opponent, Core/Opponent.hpp via BLOpponent)
extension TrainingController {
    static let computerLevelTitles = ["Beginner", "Amateur", "Quarter Pro", "Semi Pro", "Pro", "AI"]
    static let computerLevelNotes = ["mới chơi, đánh theo cảm tính", "chơi vui, chỉ lo vào bi", "CLB: đi vị trí, thủ, kick, bi băng",
                                     "phong trào: thêm combo, lực và effect đa dạng", "chuyên nghiệp: tính 2 bi, xoáy ngang, nhảy bi", "gần như không trượt, cả massé"]
    /// Lobby → Thi đấu → Đấu với máy: level, then rule, then race.
    func openComputerMatch() {
        guard !shotActive, replayIndex == nil, !locked else { return }
        if matchPlay.active { openMatchActions(); return }
        let sheet = UIAlertController(title: "Đấu với máy", message: "Máy tính bằng chính vật lý của bàn và tự thử cú theo tay của cấp đó. Cấp càng cao càng ít sai tay, điều bi xa hơn, dùng lực/effect, thủ, kick, nhảy, massé.", preferredStyle: .actionSheet)
        for (level, title) in Self.computerLevelTitles.enumerated() {
            sheet.addAction(UIAlertAction(title: "\(title) · \(Self.computerLevelNotes[level])", style: .default) { [weak self] _ in self?.chooseComputerRule(level) })
        }
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel)); presentSheet(sheet, source: menuButton)
    }
    func chooseComputerRule(_ level: Int) {
        let sheet = UIAlertController(title: "Luật", message: "Đối thủ: \(Self.computerLevelTitles[level])", preferredStyle: .actionSheet)
        for (rule, title) in matchDisciplines {
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in self?.chooseComputerRace(level, rule: rule) })
        }
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel)); presentSheet(sheet, source: menuButton)
    }
    func chooseComputerRace(_ level: Int, rule: String) {
        let sheet = UIAlertController(title: "Chạm mấy ván?", message: nil, preferredStyle: .actionSheet)
        for race in [1, 3, 5, 7, 9] {
            sheet.addAction(UIAlertAction(title: "Race \(race)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                UserDefaults.standard.set(level, forKey: "computerLevel040")
                self.startMatch(rule: rule, network: false)
                self.matchPlay.computerLevel = level
                self.matchPlay.computerFailures = 0; self.matchPlay.computerTurnKey = ""
                self.matchPlay.names = [UserDefaults.standard.string(forKey: "playerName0") ?? "Bạn", "Máy · " + Self.computerLevelTitles[level]]
                self.matchPlay.raceTo = race
                self.updateScoreboard(); self.syncMatchControls(); self.updateControls()
                self.notifyStatus("Đấu với máy · \(Self.computerLevelTitles[level]) · race \(race) · bạn phá trước")
            })
        }
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel)); presentSheet(sheet, source: menuButton)
    }
    /// Called every tick: when it is the computer's turn and the table is still, plan on a background queue and play
    /// the turn through the same command path as a human (choice → ball in hand → call → stroke).
    func driveComputerTurn() {
        // 0.40c: the computer aims on screen (turns the cue, practice strokes) before striking — not a mechanical
        // instant stroke (owner 12/11: "các cú đánh quá đều đặn").
        if let aim = matchPlay.computerAim {
            guard matchPlay.active, aim.key == matchPlay.computerTurnKey, matchInt("currentPlayer") == 1, !shotActive else {
                matchPlay.computerAim = nil; matchPlay.computerThinking = false; pull = 0; return
            }
            animateComputerAim(aim); return
        }
        // Give the human back their own cue, lift and tip point (the computer may have jumped or played a massé).
        if let saved = matchPlay.humanSetup, matchPlay.computerLevel != nil, matchInt("currentPlayer") == 0, !shotActive,
           !presentationBusy, localTurn, !locked {
            matchPlay.humanSetup = nil
            applySetup(ShotSetup(angle: angle, side: saved.side, top: saved.top, kind: saved.kind, elevation: saved.elevation))
        }
        if matchPlay.computerThinking, ProcessInfo.processInfo.systemUptime - matchPlay.computerStarted > 10 {
            matchPlay.computerThinking = false; matchPlay.computerFailures += 1   // never leave the turn hanging
        }
        guard matchPlay.active, let level = matchPlay.computerLevel, let rules = matchPlay.rules,
              !matchPlay.computerThinking, matchInt("winner", fallback: -1) < 0, matchPlay.matchWinner < 0,
              matchInt("currentPlayer") == 1, !shotActive, !presentationBusy, !table.rackIntroPlaying,
              matchPlay.placementDraft == nil, presentedViewController == nil else { return }
        let key = "\(matchPlay.rackNo)-\(matchInt("shotCount"))-\(matchPlay.state["pendingChoice"] as? String ?? "")-\(matchPlay.computerFailures)"
        if key == matchPlay.computerTurnKey { return }
        matchPlay.computerTurnKey = key
        matchPlay.computerThinking = true; matchPlay.computerStarted = ProcessInfo.processInfo.systemUptime
        notifyStatus("Máy đang tính cú…")
        let seed = UInt64.random(in: 1...UInt64.max)
        let job = BLOpponent(world: engine, match: rules, level: level, seed: seed)
        let started = ProcessInfo.processInfo.systemUptime
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let plan = job.plan()
            let spent = ProcessInfo.processInfo.systemUptime - started
            DispatchQueue.main.async { [weak self] in self?.playComputerTurn(plan, key: key, spent: spent) }
        }
    }
    private func applyComputer(_ action: LANCommand.Action, shot: LANShot? = nil, placement: LANPlacement? = nil,
                               call: LANCall? = nil, option: String? = nil) -> Bool {
        let command = LANCommand(player: 1, action: action, shot: shot, placement: placement, call: call, option: option)
        matchPlay.applyingOfflineCommand = true
        let accepted = applyMatchCommand(command)
        matchPlay.applyingOfflineCommand = false
        return accepted
    }
    /// Plan delivered: answer a referee choice at once; otherwise place the cue ball, show the cue, and start aiming.
    func playComputerTurn(_ plan: [String: Any], key: String, spent: Double) {
        guard matchPlay.active, matchPlay.computerLevel != nil, key == matchPlay.computerTurnKey,
              matchInt("currentPlayer") == 1, !shotActive else { matchPlay.computerThinking = false; return }
        func number(_ k: String) -> Double { (plan[k] as? NSNumber)?.doubleValue ?? 0 }
        if let option = plan["option"] as? String, !option.isEmpty, !(matchPlay.state["pendingChoice"] as? String ?? "").isEmpty {
            if !applyComputer(.chooseOption, option: option) { matchPlay.computerFailures += 1 }
            else { notifyStatus("Máy chọn: \(option)") }
            matchPlay.computerThinking = false; updateControls(); syncMatchControls(); return
        }
        guard (plan["valid"] as? NSNumber)?.boolValue == true else {
            matchPlay.computerFailures += 1; matchPlay.computerThinking = false
            if matchPlay.computerFailures >= 3 { computerFallbackStroke(around: angle) }
            return
        }
        if (plan["placed"] as? NSNumber)?.boolValue == true, matchBool("ballInHand") {
            _ = applyComputer(.placeCue, placement: LANPlacement(x: number("x"), y: number("y")))
            refresh()
        }
        if matchPlay.humanSetup == nil { matchPlay.humanSetup = currentSetup() }
        // Show the chosen cue, its lift and the tip point while the computer lines up (what a viewer reads as "thinking").
        let cueType = Int(number("cueType")), elevation = number("elevation")
        table.selectCue(cueType); table.cueElevation = elevation
        table.masseLook = cueType == 0 && elevation >= BL_MASSE_ELEVATION
        side = number("side"); top = number("top")
        notifyStatus(Self.computerIntentText(Int(number("intent")), target: Int(number("target")), chance: number("chance")))
        // Tempo: the plan's think time (hard choices take longer) less the time already spent computing, then
        // two practice strokes. QA runs keep the same sequence, faster.
        let qa = ProcessInfo.processInfo.arguments.contains("--computer-qa") ? 0.35 : 1.0
        let think = max(0.5, number("think") - spent) * qa
        var to = number("angle"); let from = angle
        while to - from > Double.pi { to -= 2 * Double.pi }
        while from - to > Double.pi { to += 2 * Double.pi }
        matchPlay.computerAim = ComputerAim(from: from, to: to, start: ProcessInfo.processInfo.systemUptime,
                                            turn: min(2.2, max(0.5, think)), strokes: (cueType == 1 || elevation >= BL_MASSE_ELEVATION ? 1.0 : 1.3) * qa,
                                            plan: plan, key: key)
        matchPlay.computerStarted = ProcessInfo.processInfo.systemUptime   // the watchdog counts from here
        wakeRendering()
    }
    static func computerIntentText(_ intent: Int, target: Int, chance: Double) -> String {
        let ball = target > 0 ? " bi \(target)" : ""
        switch intent {
        case 1: return "Máy: đánh băng" + ball
        case 2: return "Máy: đánh combo" + ball
        case 3: return "Máy: nhảy bi vào lỗ" + ball
        case 4: return "Máy: massé vào lỗ" + ball
        case 5: return "Máy: chơi thủ"
        case 6: return "Máy: kick băng thoát bi"
        case 7: return "Máy: nhảy bi thoát" + ball
        case 8: return "Máy: massé thoát" + ball
        case 9: return "Máy: chạm bi an toàn"
        case 10: return "Máy phá bi"
        default: return chance >= 0.85 ? "Máy: vào bi" + ball + " · đi vị trí" : "Máy: thử vào" + ball
        }
    }
    /// One frame of the computer's pre-shot routine: turn the cue onto the line (eased), then practice strokes, strike.
    func animateComputerAim(_ aim: ComputerAim) {
        let t = ProcessInfo.processInfo.systemUptime - aim.start
        if t < aim.turn {
            let u = t / aim.turn, e = u * u * (3 - 2 * u)
            angle = aim.from + (aim.to - aim.from) * e; pull = 0.06 * e
        } else if t < aim.turn + aim.strokes {
            angle = aim.to
            let u = (t - aim.turn) / aim.strokes   // two short feathers, the last one drawn back further
            pull = u < 0.66 ? 0.06 + 0.22 * (1 - cos(u / 0.33 * Double.pi)) / 2 : 0.06 + 0.45 * sin((u - 0.66) / 0.34 * Double.pi / 2)
        } else {
            matchPlay.computerAim = nil; pull = 0; angle = aim.to
            strikeComputerPlan(aim.plan, key: aim.key)
            return
        }
        guideDirty = true; wakeRendering()
    }
    func strikeComputerPlan(_ plan: [String: Any], key: String) {
        defer { matchPlay.computerThinking = false; updateControls(); syncMatchControls() }
        guard matchPlay.active, matchPlay.computerLevel != nil, key == matchPlay.computerTurnKey,
              matchInt("currentPlayer") == 1, !shotActive else { return }
        func number(_ k: String) -> Double { (plan[k] as? NSNumber)?.doubleValue ?? 0 }
        let target = Int(number("target")), pocket = Int(number("pocket"))
        if matchBool("requiresCall") {
            let safety = (plan["safety"] as? NSNumber)?.boolValue == true
            if safety, (matchPlay.state["rule"] as? String) == "eightBall" {
                _ = applyComputer(.callShot, call: LANCall(ball: 0, pocket: -1, safety: true))
            } else if target > 0, (0...5).contains(pocket) {
                _ = applyComputer(.callShot, call: LANCall(ball: target, pocket: pocket))
            }
        }
        angle = number("angle")
        let cueType = Int(number("cueType"))
        // The planner measured the lift on its line; re-check with the app's own clearance (stale obstacle lists,
        // aim vs stroke line) so the strike guard never rejects it (0.40b: rejected strokes looped = "máy chờ").
        updateCueClearance()
        let lift = min(85, max(number("elevation"), cueClearance(side: number("side"), top: number("top")) > 0.01 ? cueClearance(side: number("side"), top: number("top")) + 0.5 : 0))
        let shot = LANShot(angle: angle, speed: number("speed"), side: number("side"), top: number("top"), elevation: lift, cueType: cueType)
        if applyComputer(.strike, shot: shot) {
            matchPlay.computerFailures = 0; matchPlay.computerShots += 1
        } else {
            matchPlay.computerFailures += 1
            if matchPlay.computerFailures >= 3 { computerFallbackStroke(around: angle) }
        }
    }
    /// Last resort after repeated rejections: the nearest direction the cue can reach with a normal stroke; if none,
    /// a no-contact foul (same referee path as the shot clock) — the turn always moves on.
    func computerFallbackStroke(around start: Double) {
        updateCueClearance()
        for step in 0..<72 {
            let a = start + Double(step % 2 == 0 ? 1 : -1) * Double((step + 1) / 2) * 5 * Double.pi / 180
            angle = a
            let need = cueClearance(side: 0, top: 0)
            guard need <= 30 else { continue }
            let lift = need > 0.01 ? need + 0.5 : 0
            if applyComputer(.strike, shot: LANShot(angle: a, speed: 2, side: 0, top: 0, elevation: lift, cueType: 0)) {
                matchPlay.computerFailures = 0; matchPlay.computerShots += 1; return
            }
        }
        computerNoStrokeFoul()
    }
}

/// The computer's pre-shot routine (0.40c): turn the cue onto the line, practice strokes, then the planned stroke.
struct ComputerAim { var from: Double, to: Double, start: Double, turn: Double, strokes: Double, plan: [String: Any], key: String }

// MARK: - 0.40b Đồng hồ cú + Gia hạn (EXTENSION), theo thông lệ giải quốc tế
/// Presets (seconds per shot, extensions per player per rack, seconds per extension). Professional events use a
/// 30-second clock with one 30-second extension per player per rack (World Nineball Tour shot-clock rules; WPA events
/// similar) — the "Quốc tế" preset. Time running out = standard foul, opponent ball in hand anywhere (MatchRulesTests).
/// ASSUMED (not in the rule text we checked): the break shot is not timed; the clock pauses while a referee choice
/// (push-out, re-break, …) is pending and while the balls move.
struct ShotClockPreset { let name: String, seconds: Double, extensions: Int, extensionSeconds: Double }
extension TrainingController {
    static let shotClockPresets = [
        ShotClockPreset(name: "Tắt", seconds: 0, extensions: 0, extensionSeconds: 0),
        ShotClockPreset(name: "Quốc tế · 30 s + 1 gia hạn", seconds: 30, extensions: 1, extensionSeconds: 30),
        ShotClockPreset(name: "Luyện thi đấu · 45 s + 2", seconds: 45, extensions: 2, extensionSeconds: 30),
        ShotClockPreset(name: "Nhanh · 20 s + 1", seconds: 20, extensions: 1, extensionSeconds: 15),
    ]
    static var shotClock: ShotClockPreset {
        shotClockPresets[min(shotClockPresets.count - 1, max(0, UserDefaults.standard.integer(forKey: "shotClock040")))]
    }
    /// Called every tick on the host / offline device (the guest only mirrors the result through the referee).
    func tickShotClock(_ dt: Double) {
        let preset = Self.shotClock
        let running = matchPlay.active && preset.seconds > 0 && matchPlay.session.role != .guest &&
            matchInt("winner", fallback: -1) < 0 && matchPlay.matchWinner < 0 && !matchBool("breakShot") &&
            (matchPlay.state["pendingChoice"] as? String ?? "").isEmpty && !shotActive && !presentationBusy && !table.rackIntroPlaying &&
            presentedViewController == nil && (matchCanStroke || matchPlay.computerLevel != nil)   // 0.42: never tick under a dialog or while B is disabled
        buildShotClock()
        let showing = matchPlay.active && preset.seconds > 0
        if matchPlay.clockBar.isHidden == showing { matchPlay.clockBar.isHidden = !showing }
        guard showing else {
            for tag in [70, 74] { (matchPlay.scoreboard.viewWithTag(tag) as? UILabel)?.isHidden = true }
            return
        }
        if matchPlay.extensionRack != matchPlay.rackNo {
            matchPlay.extensionRack = matchPlay.rackNo; matchPlay.extensionsLeft = [preset.extensions, preset.extensions]
        }
        let key = "\(matchPlay.rackNo)-\(matchInt("shotCount"))-\(matchInt("currentPlayer"))"
        if key != matchPlay.clockKey { matchPlay.clockKey = key; matchPlay.clockLeft = preset.seconds; matchPlay.clockWarned = 0 }
        if running { matchPlay.clockLeft = max(0, matchPlay.clockLeft - min(dt, 0.1)) }
        let left = matchPlay.clockLeft
        // Owner TXT A: light haptic at 10 s and 5 s.
        if running, left <= 10, matchPlay.clockWarned < 1 { matchPlay.clockWarned = 1; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        if running, left <= 5, matchPlay.clockWarned < 2 { matchPlay.clockWarned = 2; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        let text = running || left < preset.seconds ? String(format: "%02.0f", ceil(left)) : "\(Int(preset.seconds))"
        let player = matchInt("currentPlayer")
        // 0.40c (owner): the seconds sit on the shooter's name plate (no box, no centre-screen bar).
        let style = Self.scoreboardStyles[Self.scoreboardStyleIndex]
        let colour: UIColor = left <= 5 ? .rgb(0xFF4D4D) : (left <= 10 ? .rgb(0xFFC94D) : style.text)
        for seat in 0...1 {
            guard let clock = matchPlay.scoreboard.viewWithTag((seat == 0 ? 10 : 14) + 60) as? UILabel else { continue }
            let mine = seat == player
            if clock.isHidden == mine { clock.isHidden = !mine }
            if mine { if clock.text != text { clock.text = text }; if clock.textColor != colour { clock.textColor = colour } }
            clock.accessibilityLabel = mine ? "Đồng hồ cú \(text) giây" : nil
        }
        if matchPlay.clockLabel.text != text { matchPlay.clockLabel.text = text }
        layoutShotClockExtension(player: player)
        let canExtend = running && matchPlay.extensionsLeft[player] > 0 && matchAllowsInput
        if matchPlay.extensionButton.isHidden == canExtend { matchPlay.extensionButton.isHidden = !canExtend }
        if running && left <= 0 { shotClockExpired() }
    }
    private func buildShotClock() {
        guard !matchPlay.clockBuilt, matchPlay.scoreboard.superview != nil else { return }   // anchored under the scoreboard
        matchPlay.clockBuilt = true
        // 0.40c: the seconds live on the shooter's plate (updateScoreboard); this transparent pill under that plate only
        // carries the "Gia hạn" button and moves to the shooter's side.
        let bar = matchPlay.clockBar, ext = matchPlay.extensionButton
        bar.translatesAutoresizingMaskIntoConstraints = false; bar.isHidden = true
        bar.backgroundColor = .clear; bar.accessibilityIdentifier = "ShotClock"
        matchPlay.clockLabel.isHidden = true   // kept for QA probes; the visible seconds are on the plate
        var config = UIButton.Configuration.plain()
        config.title = "Gia hạn +"; config.baseForegroundColor = .rgb(0xEAC583)
        config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { var a = $0; a.font = .systemFont(ofSize: 12, weight: .bold); return a }
        ext.configuration = config
        ext.layer.cornerRadius = 11; ext.layer.borderWidth = 1; ext.layer.borderColor = UIColor.rgb(0xEAC583).withAlphaComponent(0.6).cgColor
        ext.layer.shadowColor = UIColor.black.cgColor; ext.layer.shadowOpacity = 0.5; ext.layer.shadowRadius = 3; ext.layer.shadowOffset = .zero
        ext.accessibilityIdentifier = "ShotClockExtension"; ext.translatesAutoresizingMaskIntoConstraints = false
        ext.addAction(UIAction { [weak self] _ in self?.callExtension() }, for: .touchUpInside)
        bar.addSubview(ext); view.addSubview(bar)
        NSLayoutConstraint.activate([
            ext.leadingAnchor.constraint(equalTo: bar.leadingAnchor), ext.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            ext.topAnchor.constraint(equalTo: bar.topAnchor), ext.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: 24),
            bar.topAnchor.constraint(equalTo: matchPlay.scoreboard.bottomAnchor, constant: 4)])
        matchPlay.clockSides = [bar.leadingAnchor.constraint(equalTo: matchPlay.scoreboard.leadingAnchor, constant: 6),
                                bar.trailingAnchor.constraint(equalTo: matchPlay.scoreboard.trailingAnchor, constant: -6)]
    }
    /// Keep the extension button under the shooter's plate.
    private func layoutShotClockExtension(player: Int) {
        guard matchPlay.clockSides.count == 2, matchPlay.clockSide != player else { return }
        matchPlay.clockSide = player
        matchPlay.clockSides[0].isActive = player == 0; matchPlay.clockSides[1].isActive = player != 0
    }
    func callExtension() {
        let preset = Self.shotClock, player = matchInt("currentPlayer")
        guard matchPlay.active, matchPlay.extensionsLeft[player] > 0, matchAllowsInput else { return }
        matchPlay.extensionsLeft[player] -= 1
        matchPlay.clockLeft += preset.extensionSeconds; matchPlay.clockWarned = 0
        notifyStatus("\(matchPlay.names[player]) gọi GIA HẠN +\(Int(preset.extensionSeconds)) s")
    }
    /// The computer could not deliver any stroke (never seen in tests): referee it as a no-contact foul and move on.
    func computerNoStrokeFoul() {
        guard let rules = matchPlay.rules else { return }
        let state = engine.states
        let result = rules.complete(before: state, after: state, events: [], headCrossed: [])
        guard (result["accepted"] as? NSNumber)?.boolValue == true else { return }
        applyMatchResult(result); matchPlay.computerFailures = 0
        notifyStatus("Máy không ra được cơ · phạm lỗi · bạn có bi trong tay")
        refresh(); updateControls(); syncMatchControls(); publishMatchSnapshot(force: true)
    }
    private func shotClockExpired() {
        guard let rules = matchPlay.rules else { return }
        let player = matchInt("currentPlayer")
        // Same referee path as a stroke with no contact → standard foul (see MatchRulesTests "shot clock").
        let state = engine.states
        let result = rules.complete(before: state, after: state, events: [], headCrossed: [])
        guard (result["accepted"] as? NSNumber)?.boolValue == true else { return }
        applyMatchResult(result)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        notifyStatus("Hết giờ · \(matchPlay.names[player]) phạm lỗi · đối thủ có bi trong tay")
        matchPlay.clockKey = ""
        refresh(); updateControls(); syncMatchControls(); publishMatchSnapshot(force: true)
    }
}

// MARK: - 0.41 Cơ của đối thủ hiện trên màn hình · luật vắng mặt khi chơi mạng
extension TrainingController {
    /// A player away (screen off, other app, lost link) gets a foul after this long on their own turn, and loses the
    /// match after this long away in total. Values set by the owner 13/11/2026.
    static let awayTurnSeconds = 30.0, awayForfeitSeconds = 90.0   // owner 13/11 07:21: 30 s per turn, 1 min 30 s away = match lost

    /// Local shooter → the other screen: angle, tip point, lift, pull and cue, ~15 Hz while aiming.
    func matchPublishAim() {
        guard matchPlay.active, matchPlay.session.role != .none, localTurn, !shotActive, !presentationBusy else { return }
        var aim = LANAim(angle: angle, side: side, top: top,
                         elevation: min(90, max(0, max(table.cueElevation, table.clearanceElevation))),
                         pull: max(0, min(1, pull)), cueType: max(0, min(2, engine.settings["cueType"]?.intValue ?? 0)),
                         visible: !isPlacingBalls)
        let tip = hypot(aim.side, aim.top)
        if tip > 0.7 { aim.side *= 0.7 / tip; aim.top *= 0.7 / tip }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = matchPlay.lastAimSent, last == aim, now - matchPlay.lastAimSentAt < 0.5 { return }
        if matchPlay.session.publishAim(aim) { matchPlay.lastAimSent = aim; matchPlay.lastAimSentAt = now }
    }
    /// The remote shooter's cue, eased toward the latest pose, while it is their turn and the balls are still.
    func matchRemoteCue(_ dt: Double) -> LANAim? {
        let session = matchPlay.session
        guard matchPlay.active, session.role != .none, !localTurn, !presentationBusy, !shotActive,
              matchInt("currentPlayer") != session.localPlayer, let target = matchPlay.remoteAim, target.visible,
              ProcessInfo.processInfo.systemUptime - matchPlay.remoteAimAt < 3,
              session.role != .guest || session.latestSnapshot?.isMoving != true else { return nil }
        var shown = matchPlay.remoteShown ?? target
        let k = min(1, max(0, dt) * 14)
        var turn = target.angle - shown.angle
        while turn > Double.pi { turn -= 2 * Double.pi }
        while turn < -Double.pi { turn += 2 * Double.pi }
        shown.angle += turn * k; shown.side += (target.side - shown.side) * k; shown.top += (target.top - shown.top) * k
        shown.elevation += (target.elevation - shown.elevation) * k
        shown.pull += (target.pull - shown.pull) * min(1, max(0, dt) * 22)
        shown.cueType = target.cueType
        matchPlay.remoteShown = shown
        if matchPlay.localCueVisual == nil { matchPlay.localCueVisual = (engine.settings["cueType"]?.intValue ?? 0, table.cueElevation) }
        table.selectCue(shown.cueType); table.cueElevation = shown.elevation
        return shown
    }
    /// The turn is back: the local cue model and lift return to what this player had chosen.
    func matchRestoreLocalCue() {
        matchPlay.remoteShown = nil
        guard let local = matchPlay.localCueVisual else { return }
        matchPlay.localCueVisual = nil
        table.selectCue(local.0); table.cueElevation = local.1
    }
    /// Every 0.5 s while a network match runs: track absence, foul an absent player's turn, award the match.
    func matchNetworkWatch() {
        let session = matchPlay.session
        guard matchPlay.active, session.role != .none else { matchPlay.awaySince = nil; return }
        UIApplication.shared.isIdleTimerDisabled = true   // the screen never auto-locks mid-match (owner: "màn hình tắt")
        if session.isConnected {
            if matchPlay.awaySince != nil { notifyStatus("Đối thủ đã quay lại · tiếp tục trận"); syncMatchControls() }
            matchPlay.everConnected = true; matchPlay.awaySince = nil; matchPlay.awayTurnKey = ""
            return
        }
        guard matchPlay.everConnected, matchPlay.matchWinner < 0, matchInt("winner", fallback: -1) < 0 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if matchPlay.awaySince == nil {
            matchPlay.awaySince = now
            notifyStatus(session.role == .host ? "Đối thủ tạm vắng · bạn vẫn đánh lượt của mình" : "Chủ phòng tạm vắng · đang chờ nối lại")
            syncMatchControls()
        }
        let away = now - (matchPlay.awaySince ?? now)
        matchPlay.banner.setTitle(matchStatusText().replacingOccurrences(of: "\n", with: "  ·  "), for: .normal)
        if away >= Self.awayForfeitSeconds {
            let me = session.localPlayer
            matchPlay.matchWinner = me; matchPlay.forfeitWinner = me
            updateMatchState(); updateScoreboard()
            notifyStatus("\(matchPlay.names[me]) thắng · đối thủ rời trận quá \(Int(Self.awayForfeitSeconds)) giây")
            if session.role == .host { publishMatchSnapshot(force: true) }
            syncMatchControls(); updateControls()
            return
        }
        // Host only: the absent guest's turn runs a clock; at the limit it is a foul (ball in hand to the host).
        guard session.role == .host, matchInt("currentPlayer") == 1, !shotActive, !presentationBusy,
              (matchPlay.state["pendingChoice"] as? String ?? "").isEmpty, let rules = matchPlay.rules else { return }
        let key = "\(matchPlay.rackNo)-\(matchInt("shotCount"))"
        if matchPlay.awayTurnKey != key { matchPlay.awayTurnKey = key; matchPlay.awayTurnStart = now }
        guard now - matchPlay.awayTurnStart >= Self.awayTurnSeconds else { return }
        let state = engine.states
        let result = rules.complete(before: state, after: state, events: [], headCrossed: [])
        guard (result["accepted"] as? NSNumber)?.boolValue == true else { return }
        applyMatchResult(result)
        notifyStatus("Đối thủ vắng quá \(Int(Self.awayTurnSeconds)) s · phạm lỗi · bạn có bi trong tay")
        refresh(); updateControls(); syncMatchControls(); publishMatchSnapshot(force: true)
    }
}

extension TrainingController {
    /// 0.42: pocket markers for the call (0 off · 1 blinking picker · 2 chosen with a check mark).
    func showCallPockets(_ mode: Int, chosen: Int = -1) {
        let g = engine.settings
        table.showPocketMarkers(mode: mode, chosen: chosen, width: g["tableWidth"]?.doubleValue ?? 1.27, length: g["tableLength"]?.doubleValue ?? 2.54)
        wakeRendering()
    }
}

extension TrainingController {
    /// 0.42 (owner 13/11 18:15: "đối thủ vẫn chưa ra cơ được, phím B bị ẩn"). After a weak 9-ball break, a push-out,
    /// an 8-ball break foul or an uncalled 10-ball pot, the rules wait for the incoming player's CHOICE (accept / pass /
    /// ball in hand / re-rack) and B stays disabled until it is made — but the choice was only reachable by tapping the
    /// status strip, which nobody knew. The choice now opens by itself, once per decision, on the device that decides.
    func presentPendingChoiceIfNeeded() {
        if let warnings = matchPlay.state["twoFoulWarning"] as? [Bool], matchPlay.active, matchAllowsInput, !shotActive {
            let player = matchInt("currentPlayer"), warningID = "\(player)-\(matchInt("shotCount"))"
            if warnings.indices.contains(player), warnings[player], matchPlay.warningAcknowledged != warningID {
                matchPlay.warningAcknowledged = warningID
                notifyStatus("⚠︎ \(matchPlay.names[player]): đã 2 lỗi liên tiếp · lỗi nữa thua ván (9/10 Ball)")
            }
        }
        let kind = matchPlay.state["pendingChoice"] as? String ?? ""
        let options = matchPlay.state["choiceOptions"] as? [String] ?? []
        guard matchPlay.active, !kind.isEmpty, !options.isEmpty, matchAllowsInput, !shotActive, !L10n.qa,
              matchPlay.computerLevel == nil || matchInt("currentPlayer") == 0,
              presentedViewController == nil else { if kind.isEmpty { matchPlay.pendingChoiceKey = "" }; return }
        let key = "\(kind)-\(matchInt("shotCount"))-\(matchInt("currentPlayer"))-\(matchPlay.rackNo)"
        guard matchPlay.pendingChoiceKey != key else { return }
        matchPlay.pendingChoiceKey = key
        let who = matchPlay.names[min(1, max(0, matchInt("currentPlayer")))]
        let alert = UIAlertController(title: "\(who) chọn", message: matchReason(matchPlay.state["reason"] as? String ?? ""), preferredStyle: .alert)
        for option in options {
            alert.addAction(UIAlertAction(title: matchChoiceTitle(option), style: .default) { [weak self] _ in
                self?.submitMatchAction(.chooseOption, option: option)
            })
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.presentedViewController == nil else { self?.matchPlay.pendingChoiceKey = ""; return }
            self.present(alert, animated: true)
        }
    }
}
