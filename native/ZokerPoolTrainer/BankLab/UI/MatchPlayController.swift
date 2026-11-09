import UIKit
import GameKit
import simd

/// UI state is deliberately separate from the host's rules and fixed-step world.
/// A guest only draws snapshots; it never steps or strikes a local solver.
final class MatchPlayState {
    let session = LocalMatchSession()
    var rules: BLMatch?
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
        matchPlay.active && matchPlay.session.role != .none && !matchPlay.session.isConnected
    }
    var matchAllowsInput: Bool {
        guard matchPlay.active else { return true }
        if matchPlay.session.isApplyingCommand || matchPlay.applyingOfflineCommand { return true }
        guard matchInt("winner", fallback: -1) < 0 else { return false }
        if matchPlay.session.role == .none { return true }
        let moving = matchPlay.session.role == .guest ?
            matchPlay.session.latestSnapshot?.isMoving == true : (shotActive || BLShotCameraBusy(shotCameraState))
        return matchPlay.session.isConnected && !matchPlay.session.hasPendingCommand &&
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
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        button.titleLabel?.textAlignment = .left
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.contentHorizontalAlignment = .left
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(white: 0.025, alpha: 0.7)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 84),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 244),
            button.heightAnchor.constraint(equalToConstant: 44)
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
        matchPlay.session.leave()
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
    /// 0.29 broadcast-style scoreboard, top centre: NAME  frames  RACE N  frames  NAME, gold dot on the shooter.
    func updateScoreboard() {
        let board = matchPlay.scoreboard
        if !matchPlay.scoreboardBuilt {
            matchPlay.scoreboardBuilt = true
            board.translatesAutoresizingMaskIntoConstraints = false; board.isUserInteractionEnabled = false
            board.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 0.88); board.layer.cornerRadius = 10
            board.layer.borderWidth = 1; board.layer.borderColor = UIColor.rgb(0xEAC583).withAlphaComponent(0.55).cgColor
            board.accessibilityIdentifier = "MatchScoreboard"
            view.addSubview(board)
            NSLayoutConstraint.activate([board.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
                                         board.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
                                         board.heightAnchor.constraint(equalToConstant: 40)])
            let row = UIStackView(); row.axis = .horizontal; row.spacing = 10; row.alignment = .center
            row.translatesAutoresizingMaskIntoConstraints = false; board.addSubview(row); row.tag = 1
            NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo: board.leadingAnchor, constant: 12), row.trailingAnchor.constraint(equalTo: board.trailingAnchor, constant: -12),
                                         row.centerYAnchor.constraint(equalTo: board.centerYAnchor)])
            for tag in 10...14 { let label = UILabel(); label.tag = tag; row.addArrangedSubview(label) }
        }
        board.isHidden = !matchPlay.active
        guard matchPlay.active, let row = board.viewWithTag(1) else { return }
        let player = matchInt("currentPlayer"), gold = UIColor.rgb(0xEAC583)
        func set(_ tag: Int, _ text: String, _ size: CGFloat, _ color: UIColor, _ weight: UIFont.Weight) {
            guard let label = row.viewWithTag(tag) as? UILabel else { return }
            label.text = text; label.textColor = color; label.font = .monospacedDigitSystemFont(ofSize: size, weight: weight)
        }
        let shooting = matchPlay.matchWinner < 0 && matchInt("winner", fallback: -1) < 0
        set(10, (shooting && player == 0 ? "● " : "") + matchPlay.names[0], 14, player == 0 ? .white : UIColor(white: 0.7, alpha: 1), .semibold)
        set(11, "\(matchPlay.frames[0])", 22, .white, .bold)
        set(12, "RACE \(matchPlay.raceTo) · VÁN \(matchPlay.rackNo)", 11, gold, .bold)
        set(13, "\(matchPlay.frames[1])", 22, .white, .bold)
        set(14, matchPlay.names[1] + (shooting && player == 1 ? " ●" : ""), 14, player == 1 ? .white : UIColor(white: 0.7, alpha: 1), .semibold)
        view.bringSubviewToFront(board)
    }
    func leaveMatch() {
        guard !shotActive || matchSimulationPaused || matchPlay.session.role == .guest else { notifyStatus("Chờ bi dừng trước khi rời trận"); return }
        matchPlay.active = false
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
        updateScoreboard()
        table.spectatorPivot = !localTurn
        // 0.29: when the turn comes to this device, it is already in the ready-to-shoot aim view.
        if localTurn && !wasLocal && !shotActive && replayIndex == nil && table.cameraMode != 2 {
            aimCameraYaw = 0; shotCameraAnchor = nil; selectCamera(2)
        }
        matchPlay.banner.isHidden = locked || menuOpen
        matchPlay.banner.setTitle(matchStatusText(), for: .normal)
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
        notifyStatus("Call · chạm vào bi muốn gọi")
    }
    func endMatchCallPick() {
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
        notifyStatus("Đã gọi bi \(ball) · lỗ \(pocket + 1)")
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
        if let warnings = matchPlay.state["twoFoulWarning"] as? [Bool] {
            let player = matchInt("currentPlayer")
            let warningID = "\(player)-\(matchInt("shotCount"))"
            if warnings.indices.contains(player), warnings[player], matchPlay.warningAcknowledged != warningID {
                setHold(false)
                let alert = UIAlertController(title: "Cảnh báo hai lỗi liên tiếp", message: "Người \(player + 1) đã phạm hai lỗi liên tiếp. Một lỗi nữa ở cú này sẽ thua ván theo luật 9/10 Ball.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Đã hiểu", style: .default) { [weak self] _ in
                    self?.matchPlay.warningAcknowledged = warningID
                    self?.notifyStatus("Đã cảnh báo · giữ B và ra cơ khi sẵn sàng")
                })
                present(alert, animated: true); return true
            }
        }
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
        if matchPlay.session.role == .none {
            matchPlay.applyingOfflineCommand = true
            let accepted = applyMatchCommand(command)
            matchPlay.applyingOfflineCommand = false
            if !accepted { notifyStatus("Thao tác chưa hợp lệ theo luật đang chơi") }
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
            var state = engine.states.map { BallState($0) }
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
                  matchCuePositionValid(engine.states.map { BallState($0) }),
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
        let events = engine.events
        if events.count > matchPlay.publishedEvents {
            let fresh = events.enumerated().dropFirst(matchPlay.publishedEvents).compactMap { matchEvent($0.element, index: $0.offset) }
            for start in stride(from: 0, to: fresh.count, by: 128) {
                matchPlay.session.publishEvents(Array(fresh[start..<min(start + 128, fresh.count)]), shotID: matchPlay.shotID)
            }
            matchPlay.publishedEvents = events.count
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
        matchPlay.calledBall = 0; matchPlay.calledPocket = -1
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
            var state = engine.states.map { BallState($0) }
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
            publishMatchSnapshot(force: true); return
        }
        notifyStatus("\(matchPlay.names[winner]) thắng ván \(matchPlay.rackNo) · \(matchPlay.frames[0])–\(matchPlay.frames[1])")
        publishMatchSnapshot(force: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.startNextRack() }
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
            table.placementBlocked = !matchCuePositionValid(state)
            notifyStatus("Kéo bi cái · chạm Đặt bi lần nữa để xác nhận")
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
        var state = matchPlay.state
        state["calledBall"] = matchPlay.calledBall; state["calledPocket"] = matchPlay.calledPocket
        state["safety"] = matchPlay.safety; state["pushOut"] = matchPlay.pushOut
        state["raceTo"] = matchPlay.raceTo; state["frames"] = matchPlay.frames; state["names"] = matchPlay.names
        state["rackNo"] = matchPlay.rackNo; state["matchWinner"] = matchPlay.matchWinner
        guard let json = try? JSONSerialization.data(withJSONObject: state) else { return }
        let events = engine.events.enumerated().suffix(128).compactMap { matchEvent($0.element, index: $0.offset) }
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
        if let f = state["frames"] as? [NSNumber], f.count == 2 { matchPlay.frames = f.map { max(0, min(99, $0.intValue)) } }
        if let n = state["names"] as? [String], n.count == 2 { matchPlay.names = n.map { String($0.prefix(16)) } }
        matchPlay.rackNo = (state["rackNo"] as? NSNumber)?.intValue ?? matchPlay.rackNo
        matchPlay.matchWinner = (state["matchWinner"] as? NSNumber)?.intValue ?? -1
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
        if matchPlay.snapshots.count > 8 { matchPlay.snapshots.removeFirst(matchPlay.snapshots.count - 8) }
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
