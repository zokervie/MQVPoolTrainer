import UIKit

/// 0.44-mm Nearby Play (anh 16/11): one sheet for Tạo phòng / Tìm phòng · lời mời · sẵn sàng · chất lượng · nối lại · rời phòng.
/// Transport and protocol are unchanged (MultipeerConnectivity, LANShotStart lockstep, host authority); this screen only
/// drives LocalMatchSession's existing room calls and renders its NearbyLobby state. Online play stays in its own menu.
final class NearbyLobbyController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    weak var owner: TrainingController?
    /// 0 = Tạo phòng, 1 = Tìm phòng (a guest already in a room always opens on 1).
    var initialTab = 0
    private var session: LocalMatchSession? { owner?.matchPlay.session }
    private let tabs = UISegmentedControl(items: ["Tạo phòng", "Tìm phòng"])
    private let games = UISegmentedControl()
    private var gameRules: [String] = []
    private let createButton = UIButton(type: .system), joinCodeButton = UIButton(type: .system)
    private let codeLabel = UILabel(), statusLabel = UILabel(), qualityLabel = UILabel(), failureLabel = UILabel(), emptyLabel = UILabel()
    private let startButton = UIButton(type: .system), reconnectButton = UIButton(type: .system), leaveButton = UIButton(type: .system)
    private let rooms = UITableView(frame: .zero, style: .insetGrouped)
    private var timer: Timer?
    private static let gold = UIColor(red: 0xEA / 255.0, green: 0xC5 / 255.0, blue: 0x83 / 255.0, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(white: 0.05, alpha: 1)
        view.accessibilityIdentifier = "NearbyLobby"
        let title = UILabel(); title.text = "Chơi gần · Nearby"; title.font = .systemFont(ofSize: 22, weight: .bold); title.textColor = Self.gold
        let note = UILabel(); note.numberOfLines = 0; note.font = .systemFont(ofSize: 12); note.textColor = UIColor(white: 0.7, alpha: 1)
        note.text = "Hai iPhone/iPad ở gần nhau, cùng Wi‑Fi hoặc không cần Internet (Apple tự chọn Wi‑Fi / Wi‑Fi trực tiếp / Bluetooth). Không cần IP, cổng hay máy chủ."
        tabs.selectedSegmentIndex = 0; tabs.addAction(UIAction { [weak self] _ in self?.tabChanged() }, for: .valueChanged)
        let disciplines = owner?.matchDisciplines ?? [("nineBall", "9 Ball")]
        gameRules = disciplines.map { $0.0 }
        for (i, item) in disciplines.enumerated() { games.insertSegment(withTitle: item.1, at: i, animated: false) }
        games.selectedSegmentIndex = 0
        style(createButton, "Tạo phòng", filled: true) { [weak self] in self?.createRoom() }
        style(joinCodeButton, "Nhập mã 6 số", filled: false) { [weak self] in self?.owner?.joinMatchRoom() }
        style(startButton, "Bắt đầu", filled: true) { [weak self] in self?.dismiss(animated: true) }
        style(reconnectButton, "Nối lại", filled: false) { [weak self] in self?.session?.reconnect(); self?.render() }
        style(leaveButton, "Rời phòng", filled: false) { [weak self] in self?.leave() }
        codeLabel.font = .monospacedDigitSystemFont(ofSize: 34, weight: .heavy); codeLabel.textColor = .white; codeLabel.textAlignment = .center
        codeLabel.accessibilityIdentifier = "NearbyCode"
        for l in [statusLabel, failureLabel, emptyLabel] { l.numberOfLines = 0; l.font = .systemFont(ofSize: 14); l.textColor = .white }
        failureLabel.textColor = UIColor(red: 1, green: 0.55, blue: 0.45, alpha: 1); failureLabel.accessibilityIdentifier = "NearbyFailure"
        emptyLabel.textColor = UIColor(white: 0.65, alpha: 1)
        qualityLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold); qualityLabel.accessibilityIdentifier = "NearbyQuality"
        rooms.dataSource = self; rooms.delegate = self; rooms.backgroundColor = .clear; rooms.accessibilityIdentifier = "NearbyRooms"
        rooms.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        let ready = UIStackView(arrangedSubviews: [UIView(), qualityLabel]); ready.spacing = 10; ready.alignment = .center
        let actions = UIStackView(arrangedSubviews: [reconnectButton, leaveButton, startButton]); actions.spacing = 10; actions.distribution = .fillEqually
        let stack = UIStackView(arrangedSubviews: [title, note, tabs, games, createButton, joinCodeButton, rooms, emptyLabel, codeLabel, statusLabel, failureLabel, ready, actions])
        stack.axis = .vertical; stack.spacing = 12; stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false; scroll.addSubview(stack)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)])
        session?.onLobbyChanged = { [weak self] in self?.render() }
        tabs.selectedSegmentIndex = session?.role == LocalMatchSession.Role.guest ? 1 : (session?.role == LocalMatchSession.Role.host ? 0 : initialTab)
        tabChanged()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.render() }
        RunLoop.main.add(t, forMode: .common); timer = t
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard presentingViewController == nil else { return }
        timer?.invalidate(); timer = nil
        session?.onLobbyChanged = nil
        if session?.role == LocalMatchSession.Role.none { session?.stopScan() }
        // 0.44.1: the host's Accept/Decline question is owned by TrainingController and survives this sheet;
        // LocalMatchSession.leave() clears it.
    }
    private func style(_ b: UIButton, _ title: String, filled: Bool, _ action: @escaping () -> Void) {
        var c = filled ? UIButton.Configuration.filled() : UIButton.Configuration.bordered()
        c.title = title; c.cornerStyle = .capsule
        c.baseBackgroundColor = filled ? Self.gold : UIColor(white: 0.2, alpha: 1); c.baseForegroundColor = filled ? .black : .white
        b.configuration = c; b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        b.accessibilityIdentifier = "Nearby-" + title
    }
    private func tabChanged() {
        if tabs.selectedSegmentIndex == 1, session?.role == LocalMatchSession.Role.none { session?.startScan() }
        if tabs.selectedSegmentIndex == 0, session?.role == LocalMatchSession.Role.none { session?.stopScan() }
        render()
    }
    private func createRoom() {
        guard let owner = owner, session?.role == LocalMatchSession.Role.none else { return }
        let rule = gameRules.indices.contains(games.selectedSegmentIndex) ? gameRules[games.selectedSegmentIndex] : "nineBall"
        session?.stopScan()
        owner.startMatch(rule: rule, network: true)
        owner.installNearbyInvitationPrompt()
        render()
    }
    private func join(_ code: String) {
        guard let owner = owner, session?.role == LocalMatchSession.Role.none else { return }
        owner.prepareGuestMatch()
        _ = session?.joinRoom(code: code, fromScan: true)
        owner.syncMatchControls(); owner.updateControls()
        render()
    }
    private func leave() {
        owner?.leaveNearbyMatch()
        if tabs.selectedSegmentIndex == 1 { session?.startScan() }
        render()
    }
    func render() {
        guard let session = session, isViewLoaded else { return }
        let lobby = session.lobby, hosting = tabs.selectedSegmentIndex == 0, inRoom = session.role != .none
        tabs.isEnabled = !inRoom
        games.isHidden = !hosting || inRoom; createButton.isHidden = !hosting || inRoom
        joinCodeButton.isHidden = hosting || inRoom; rooms.isHidden = hosting || inRoom
        emptyLabel.isHidden = hosting || inRoom
        emptyLabel.text = lobby.rooms.isEmpty ? "Đang tìm phòng gần đây… Máy kia chọn Tạo phòng." + (lobby.incompatibleRooms > 0 ? "\n\(lobby.incompatibleRooms) phòng dùng phiên bản khác — cập nhật cả hai máy." : "")
            : (lobby.incompatibleRooms > 0 ? "\(lobby.incompatibleRooms) phòng khác phiên bản bị ẩn." : "")
        codeLabel.isHidden = !(inRoom && session.role == .host); codeLabel.text = session.roomCode
        statusLabel.isHidden = !inRoom; statusLabel.text = session.connectionDescription
        if case .failed(let reason) = lobby.phase { failureLabel.isHidden = false; failureLabel.text = reason.vietnamese + "\n" + reason.english }
        else { failureLabel.isHidden = true }
        let connected = session.isConnected
        qualityLabel.superview?.isHidden = !inRoom
        let q = lobby.quality
        let bars = ["○○○", "●○○", "●●○", "●●●"][q]
        let rtt = lobby.rttMs.map { String(format: "%.0f ms", $0) } ?? "—", jitter = lobby.jitterMs.map { String(format: " ±%.0f", $0) } ?? ""
        qualityLabel.text = connected ? "\(bars) \(rtt)\(jitter)" : (inRoom ? "○○○ chưa nối" : "")
        qualityLabel.textColor = [UIColor(white: 0.6, alpha: 1), .systemRed, .systemYellow, .systemGreen][q]
        var reconnecting = false
        switch lobby.phase { case .reconnecting, .failed(.reconnectTimedOut): reconnecting = true; default: break }
        reconnectButton.isHidden = !(inRoom && reconnecting)   // waiting for a first guest is not a reconnect
        leaveButton.isHidden = !inRoom
        startButton.isHidden = !inRoom
        startButton.isEnabled = lobby.canStart   // 0.44.1: lights up once connected (no local-only Ready switch)
        startButton.configuration?.title = session.role == .host ? "Bắt đầu" : "Vào bàn"
        if !rooms.isHidden { rooms.reloadData() }
        // QA only: join the first room found, to exercise the host's Accept/Decline question on two Simulators.
        if ProcessInfo.processInfo.arguments.contains("--nearby-autojoin-qa"), !inRoom, !hosting, let first = lobby.rooms.first { join(first.code) }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { session?.lobby.rooms.count ?? 0 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "room") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "room")
        guard let room = session?.lobby.rooms[indexPath.row] else { return cell }
        let title = owner?.matchDisciplines.first { $0.0 == room.game }?.1 ?? room.game
        cell.textLabel?.text = room.host; cell.detailTextLabel?.text = "\(title) · phòng \(room.code)"
        cell.accessoryType = .disclosureIndicator; cell.accessibilityIdentifier = "NearbyRoom-" + room.code
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let room = session?.lobby.rooms[indexPath.row] else { return }
        join(room.code)
    }
}

extension TrainingController {
    /// Menu → Chơi theo luật → Wi‑Fi gần nhau → "Chơi gần (Nearby)…".
    func openNearbyLobby(tab: Int = 0) {
        guard !shotActive, replayIndex == nil else { return }
        let lobby = NearbyLobbyController(); lobby.owner = self; lobby.initialTab = tab
        lobby.modalPresentationStyle = .pageSheet
        if let sheet = lobby.sheetPresentationController { sheet.detents = [.medium(), .large()]; sheet.prefersGrabberVisible = true }
        present(lobby, animated: true)
    }
    /// Leave the nearby room the same way the in-match menu does (the session tells the other phone).
    func leaveNearbyMatch() {
        matchPlay.session.askInvitation = nil
        if matchPlay.active { leaveMatch() } else { matchPlay.session.leave() }
    }

    /// 0.44.1: the visible top of the presentation stack (a sheet, the menu…) — present questions and code entry here,
    /// never from a controller that is already presenting something (UIKit then drops the new one silently).
    var topPresenter: UIViewController {
        var top: UIViewController = self
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }
    /// Host: ask Accept/Decline for a nearby guest, from whatever screen is on top, sheet open or not.
    func installNearbyInvitationPrompt() {
        matchPlay.session.askInvitation = { [weak self] name, reply in
            guard let self = self else { reply(false, false); return }
            self.presentNearbyInvitation(name, reply)
        }
    }
    private func presentNearbyInvitation(_ name: String, _ reply: @escaping (Bool, Bool) -> Void) {
        let top = topPresenter
        guard !(top is UIAlertController), top.viewIfLoaded?.window != nil, !top.isBeingPresented else {
            reply(false, false); return   // cannot ask now: refuse this once, the guest may ask again
        }
        let alert = UIAlertController(title: "\(name) muốn vào phòng", message: "\(name) wants to join · Nhận để bắt đầu trận với máy này.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Từ chối · Decline", style: .cancel) { _ in reply(false, true) })
        alert.addAction(UIAlertAction(title: "Nhận · Accept", style: .default) { _ in reply(true, true) })
        alert.view.accessibilityIdentifier = "NearbyInvitation"
        top.present(alert, animated: true)
        // 0.44.1 review: the session gives up after 15 s; never leave a dead question on screen (it would also make
        // the next guest's question impossible to show).
        DispatchQueue.main.asyncAfter(deadline: .now() + 14) { [weak alert] in
            guard let alert = alert, alert.presentingViewController != nil else { return }
            alert.dismiss(animated: true) { reply(false, false) }
        }
    }
}
