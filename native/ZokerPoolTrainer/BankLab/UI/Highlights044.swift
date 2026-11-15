import UIKit

/// 0.44 (owner item 11: "highlight tự chọn những cú đẹp nhất trong trận, biên tập như DOP, sau trận hiện lựa chọn
/// xem / lưu tinh tế, không lấn màn hình").
///
/// Scoring (what a broadcast editor keeps): each potted object ball 3 · a pot after the ball itself touched a cushion
/// (bank / kick) +4 · combination (the potted ball was not the first ball hit) +3 · long pot (object ball travel > 1.2 m)
/// +2 · jump or massé stroke +5 · a stroke that won the rack +6 · break that pots +2 · cue-ball travel with 3+ rails for
/// position +1. A scratch scores 0. The best five are kept (one stored replay each, ~1–3 MB) and, after the match, a
/// small chip offers "Xem" (reel, Action Mix camera = automatic cuts, slow motion only at contact/pot) or "Lưu video"
/// (the same reel as one MP4 via the #17 exporter).
struct MatchHighlight {
    var score: Double
    var label: String
    var state: TrainingController.ReplayReturnState
}

extension TrainingController {
    static var highlights: [MatchHighlight] = []
    static var highlightQueue: [MatchHighlight] = []
    private static var highlightChip: UIView?

    func resetHighlights() { Self.highlights = []; Self.highlightQueue = []; Self.highlightChip?.removeFromSuperview() }

    /// Called by finishMatchShot (host / same device / vs computer) before the referee result is applied.
    func scoreHighlight(wonRack: Bool, shooter: Int, isBreak: Bool) {
        guard !frames.isEmpty, let shot = lastShot else { return }
        let events = lastShotEvents
        let pots = events.filter { ($0["kind"]?.intValue ?? -1) == 2 }
        if pots.contains(where: { ($0["a"]?.intValue ?? -1) == 0 }) { return }   // scratch
        let potted = pots.compactMap { $0["a"]?.intValue }.filter { $0 > 0 }
        let firstHit = events.first { ($0["kind"]?.intValue ?? -1) == 1 && (($0["a"]?.intValue ?? -1) == 0 || ($0["b"]?.intValue ?? -1) == 0) }
        let firstObject = firstHit.map { ($0["a"]?.intValue ?? 0) == 0 ? ($0["b"]?.intValue ?? -1) : ($0["a"]?.intValue ?? -1) } ?? -1
        var score = 0.0, tags: [String] = []
        for id in potted {
            score += 3
            let rails = events.filter { ($0["kind"]?.intValue ?? -1) == 0 && ($0["a"]?.intValue ?? -1) == id }
            let potTime = pots.first { ($0["a"]?.intValue ?? -1) == id }?["time"]?.doubleValue ?? .infinity
            if rails.contains(where: { ($0["time"]?.doubleValue ?? .infinity) < potTime }) { score += 4; tags.append("băng") }
            if id != firstObject && firstObject > 0 { score += 3; tags.append("bi chạm bi") }
            if let a = frames.first?.first(where: { $0.id == id }), let b = frames.last?.first(where: { $0.id == id }), hypot(a.x - b.x, a.y - b.y) > 1.2 {
                score += 2; tags.append("bi xa")
            }
        }
        let kind = shot.shotKind ?? shot.cueType
        if kind == 1 || kind == 3, !potted.isEmpty { score += 5; tags.append(kind == 1 ? "jump" : "massé") }
        if isBreak, !potted.isEmpty { score += 2; tags.append("phá") }
        if wonRack { score += 6; tags.append("kết thúc ván") }
        let cueRails = events.filter { ($0["kind"]?.intValue ?? -1) == 0 && ($0["a"]?.intValue ?? -1) == 0 }.count
        if cueRails >= 3, !potted.isEmpty { score += 1; tags.append("về thế \(cueRails) băng") }
        guard score >= 3 else { return }
        let who = matchPlay.names[min(1, max(0, shooter))]
        let label = "\(who) · " + (tags.isEmpty ? "vào \(potted.count) bi" : Array(Set(tags)).sorted().joined(separator: ", "))
        let state = ReplayReturnState(frames: frames, times: frameTimes, events: lastShotEvents, shot: lastShot, paths: paths,
                                      coach: false, preparation: lastPreparation)
        Self.highlights.append(MatchHighlight(score: score, label: label, state: state))
        Self.highlights.sort { $0.score > $1.score }
        if Self.highlights.count > 5 { Self.highlights.removeLast(Self.highlights.count - 5) }
    }

    /// After the match: a slim chip at the bottom centre, auto-hides after 15 s. Never covers the table centre.
    func offerHighlights() {
        Self.highlightChip?.removeFromSuperview()
        guard !Self.highlights.isEmpty else { return }
        let chip = UIStackView(); chip.axis = .horizontal; chip.spacing = 6; chip.alignment = .center
        chip.backgroundColor = UIColor(white: 0.03, alpha: 0.78); chip.layer.cornerRadius = 18
        chip.layer.borderColor = UIColor.rgb(0xEAC583).withAlphaComponent(0.55).cgColor; chip.layer.borderWidth = 1
        chip.isLayoutMarginsRelativeArrangement = true; chip.layoutMargins = UIEdgeInsets(top: 4, left: 14, bottom: 4, right: 6)
        chip.translatesAutoresizingMaskIntoConstraints = false; chip.accessibilityIdentifier = "HighlightChip"
        let title = UILabel(); title.text = "✦ Highlight · \(Self.highlights.count) cú"; title.textColor = .rgb(0xEAC583)
        title.font = .systemFont(ofSize: 13, weight: .bold)
        func button(_ text: String, _ action: @escaping () -> Void) -> UIButton {
            var c = UIButton.Configuration.filled(); c.title = text; c.baseBackgroundColor = UIColor.rgb(0xEAC583).withAlphaComponent(0.22)
            c.baseForegroundColor = .white; c.cornerStyle = .capsule; c.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12)
            c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in var a = a; a.font = .systemFont(ofSize: 13, weight: .semibold); return a }
            let b = UIButton(configuration: c); b.addAction(UIAction { _ in action() }, for: .touchUpInside); return b
        }
        let watch = button("Xem") { [weak self] in self?.playHighlightReel(export: false) }
        let save = button("Lưu video") { [weak self] in self?.playHighlightReel(export: true) }
        let close = button("✕") { [weak chip] in chip?.removeFromSuperview() }
        for v in [title, watch, save, close] as [UIView] { chip.addArrangedSubview(v) }
        view.addSubview(chip); Self.highlightChip = chip
        NSLayoutConstraint.activate([chip.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     chip.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
                                     chip.heightAnchor.constraint(equalToConstant: 40)])
        chip.alpha = 0; UIView.animate(withDuration: 0.3) { chip.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak chip] in
            UIView.animate(withDuration: 0.4, animations: { chip?.alpha = 0 }) { _ in chip?.removeFromSuperview() }
        }
    }

    /// The reel: best shots in match order, Action Mix camera. Export = the same reel into one MP4.
    func playHighlightReel(export: Bool) {
        Self.highlightChip?.removeFromSuperview()
        guard !shotActive, replayIndex == nil, videoExport == nil else { return }
        Self.highlightQueue = Self.highlights
        guard loadNextHighlight() else { return }
        replayCamera = 8
        if export { startVideoExport(includeInfo: false) } else { notifyStatus(Self.highlightQueue.isEmpty ? "Highlight" : "Highlight · còn \(Self.highlightQueue.count) cú"); replay() }
    }
    /// Loads the next reel shot into the replay buffers (the live shot is restored by stopReplay via archiveReturn).
    @discardableResult func loadNextHighlight() -> Bool {
        guard !Self.highlightQueue.isEmpty else { return false }
        let next = Self.highlightQueue.removeFirst()
        if archiveReturn == nil {
            archiveReturn = ReplayReturnState(frames: frames, times: frameTimes, events: lastShotEvents, shot: lastShot, paths: paths,
                                              coach: coaching, preparation: lastPreparation)
        }
        frames = next.state.frames; frameTimes = next.state.times; lastShotEvents = next.state.events
        lastShot = next.state.shot; paths = next.state.paths; lastPreparation = next.state.preparation
        notifyStatus("Highlight · " + next.label)
        if let export = videoExport, let shot = lastShot {
            let cue = shot.cueType == 1 ? "Jump" : (shot.cueType == 2 ? "Break" : (shot.elevation > 35 ? "Massé" : L10n.tr("Đánh")))
            export.info = (shot.speed, shot.side, shot.top, shot.elevation, cue)
        }
        return true
    }
}
