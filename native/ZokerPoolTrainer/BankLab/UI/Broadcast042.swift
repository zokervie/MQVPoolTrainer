import UIKit
import AVFoundation

/// 0.42 (owner acceptance 0.41, item 3): TV-style score card after every rack (3.5 s) and a winner card at the end of
/// the match with "Chơi tiếp" / "Về sảnh". VFX: scrim, two name plates sliding in, a gold light sweep, score pop,
/// spark burst (confetti for the match). SFX: a short sting synthesised on the device (no licensed audio needed).
final class BroadcastCard: UIView {
    struct Action { let title: String; let primary: Bool; let run: () -> Void }
    private let panel = UIView(), sweep = CAGradientLayer(), emitter = CAEmitterLayer()
    private var actions: [Action] = []
    static let gold = UIColor(red: 0.95, green: 0.76, blue: 0.32, alpha: 1)

    func present(in host: UIView, kicker: String, names: [String], scores: [Int], winner: Int, headline: String,
                 final: Bool, actions: [Action], hold: Double) {
        removeFromSuperview(); subviews.forEach { $0.removeFromSuperview() }; layer.sublayers?.removeAll()
        self.actions = actions
        frame = host.bounds; autoresizingMask = [.flexibleWidth, .flexibleHeight]; accessibilityIdentifier = "BroadcastCard"
        backgroundColor = UIColor(white: 0, alpha: 0); isUserInteractionEnabled = !actions.isEmpty
        host.addSubview(self)
        let w = min(bounds.width - 40, 560), h: CGFloat = final ? 210 : 150
        panel.frame = CGRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2 - (final ? 10 : 0), width: w, height: h)
        panel.subviews.forEach { $0.removeFromSuperview() }; panel.layer.sublayers?.removeAll()
        panel.layer.cornerRadius = 14; panel.layer.cornerCurve = .continuous; panel.clipsToBounds = true
        let bg = CAGradientLayer(); bg.frame = panel.bounds
        bg.colors = [UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 0.96).cgColor, UIColor(red: 0.08, green: 0.10, blue: 0.20, alpha: 0.96).cgColor]
        panel.layer.addSublayer(bg)
        panel.layer.borderWidth = 1.5; panel.layer.borderColor = Self.gold.cgColor
        addSubview(panel)
        // header strip
        let header = UILabel(frame: CGRect(x: 0, y: 0, width: w, height: 30)); header.textAlignment = .center
        header.text = kicker.uppercased(); header.font = .systemFont(ofSize: 13, weight: .heavy); header.textColor = .black
        header.backgroundColor = Self.gold; panel.addSubview(header)
        // name plates + scores
        let plateW = (w - 120) / 2, rowY: CGFloat = 46
        var popTargets: [UIView] = []
        for seat in 0...1 {
            let name = UILabel(frame: CGRect(x: seat == 0 ? 12 : w - 12 - plateW, y: rowY, width: plateW, height: 44))
            name.text = names[seat].uppercased(); name.font = .systemFont(ofSize: 18, weight: .black)
            name.adjustsFontSizeToFitWidth = true; name.minimumScaleFactor = 0.55
            name.textAlignment = seat == 0 ? .left : .right
            name.textColor = winner == seat ? Self.gold : UIColor(white: 0.92, alpha: winner < 0 || winner == seat ? 1 : 0.6)
            panel.addSubview(name)
            name.transform = CGAffineTransform(translationX: seat == 0 ? -w : w, y: 0)
            UIView.animate(withDuration: 0.45, delay: 0.08, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.4) { name.transform = .identity }
            let score = UILabel(frame: CGRect(x: w / 2 + (seat == 0 ? -56 : 6), y: rowY - 4, width: 50, height: 52))
            score.text = "\(scores[seat])"; score.textAlignment = .center
            score.font = .monospacedDigitSystemFont(ofSize: 40, weight: .black)
            score.textColor = winner == seat ? .black : .white
            score.backgroundColor = winner == seat ? Self.gold : UIColor(white: 1, alpha: 0.08)
            score.layer.cornerRadius = 8; score.clipsToBounds = true
            panel.addSubview(score); popTargets.append(score)
        }
        let dash = UILabel(frame: CGRect(x: w / 2 - 6, y: rowY + 6, width: 12, height: 36)); dash.text = "–"
        dash.textColor = Self.gold; dash.font = .systemFont(ofSize: 26, weight: .black); dash.textAlignment = .center; panel.addSubview(dash)
        let line = UILabel(frame: CGRect(x: 12, y: rowY + 58, width: w - 24, height: 30)); line.textAlignment = .center
        line.text = headline; line.font = .systemFont(ofSize: final ? 20 : 15, weight: .heavy)
        line.textColor = final ? Self.gold : UIColor(white: 0.95, alpha: 1); line.adjustsFontSizeToFitWidth = true; line.minimumScaleFactor = 0.6
        panel.addSubview(line)
        // buttons
        if !actions.isEmpty {
            let bw = (w - 36) / CGFloat(actions.count)
            for (k, a) in actions.enumerated() {
                let b = UIButton(type: .system); b.frame = CGRect(x: 12 + CGFloat(k) * (bw + 12), y: h - 56, width: bw - 12 + (actions.count == 1 ? 12 : 0), height: 42)
                b.setTitle(a.title, for: .normal); b.titleLabel?.font = .systemFont(ofSize: 16, weight: .heavy)
                b.setTitleColor(a.primary ? .black : .white, for: .normal)
                b.backgroundColor = a.primary ? Self.gold : UIColor(white: 1, alpha: 0.12)
                b.layer.cornerRadius = 10; b.tag = k; b.accessibilityIdentifier = "Broadcast\(k)"
                b.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside); panel.addSubview(b)
            }
        }
        // light sweep
        sweep.frame = CGRect(x: -w, y: 0, width: w * 0.6, height: h)
        sweep.colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 0.28).cgColor, UIColor(white: 1, alpha: 0).cgColor]
        sweep.startPoint = CGPoint(x: 0, y: 0.5); sweep.endPoint = CGPoint(x: 1, y: 0.5); panel.layer.addSublayer(sweep)
        let move = CABasicAnimation(keyPath: "position.x"); move.fromValue = -w * 0.3; move.toValue = w * 1.3
        move.duration = 0.9; move.beginTime = CACurrentMediaTime() + 0.35; move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        move.fillMode = .both; sweep.add(move, forKey: "sweep")
        // panel + scrim in
        panel.transform = CGAffineTransform(scaleX: 0.86, y: 0.86); panel.alpha = 0
        UIView.animate(withDuration: 0.28) { self.backgroundColor = UIColor(white: 0, alpha: 0.45); self.panel.alpha = 1; self.panel.transform = .identity }
        for (k, s) in popTargets.enumerated() {
            s.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
            UIView.animate(withDuration: 0.5, delay: 0.45 + Double(k) * 0.08, usingSpringWithDamping: 0.45, initialSpringVelocity: 0.9) { s.transform = .identity }
        }
        burst(final: final, around: panel.frame)
        BroadcastSting.shared.play(final: final)
        if hold > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) { [weak self] in self?.dismiss() }
        }
    }
    @objc private func tap(_ sender: UIButton) {
        guard actions.indices.contains(sender.tag) else { return }
        let run = actions[sender.tag].run; dismiss(); run()
    }
    func dismiss() {
        UIView.animate(withDuration: 0.25, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview(); self.alpha = 1 }
    }
    private func burst(final: Bool, around rect: CGRect) {
        emitter.removeFromSuperlayer()
        emitter.emitterPosition = CGPoint(x: rect.midX, y: final ? rect.minY - 10 : rect.midY)
        emitter.emitterShape = final ? .line : .circle; emitter.emitterSize = CGSize(width: final ? rect.width : 40, height: 1)
        emitter.renderMode = .additive
        let colors: [UIColor] = final ? [Self.gold, .white, UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 1), UIColor(red: 1, green: 0.35, blue: 0.3, alpha: 1)] : [Self.gold, .white]
        emitter.emitterCells = colors.map { color in
            let c = CAEmitterCell(); c.contents = Self.spark.cgImage; c.color = color.cgColor
            c.birthRate = final ? 60 : 90; c.lifetime = final ? 3.2 : 0.9; c.velocity = final ? 140 : 260; c.velocityRange = 90
            c.emissionLongitude = final ? .pi / 2 : 0; c.emissionRange = final ? .pi / 4 : .pi * 2
            c.yAcceleration = final ? 120 : 0; c.spin = 3; c.spinRange = 6; c.scale = final ? 0.55 : 0.35; c.scaleRange = 0.25; c.alphaSpeed = final ? -0.25 : -1.1
            return c
        }
        emitter.frame = bounds; layer.addSublayer(emitter)
        emitter.beginTime = CACurrentMediaTime()
        DispatchQueue.main.asyncAfter(deadline: .now() + (final ? 1.4 : 0.25)) { [weak self] in self?.emitter.birthRate = 0 }
        emitter.birthRate = 1
    }
    private static let spark: UIImage = {
        UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { ctx in
            UIColor.white.setFill(); ctx.cgContext.fill(CGRect(x: 3, y: 0, width: 6, height: 12))
        }
    }()
}

/// Procedural broadcast sting: noise whoosh + a bright major chord (rack) or a rising fanfare (match).
final class BroadcastSting {
    static let shared = BroadcastSting()
    private let engine = AVAudioEngine(), player = AVAudioPlayerNode()
    private var ready = false
    private lazy var rack: AVAudioPCMBuffer? = make(final: false)
    private lazy var match: AVAudioPCMBuffer? = make(final: true)
    private func setup() {
        guard !ready else { return }
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
        ready = (try? engine.start()) != nil
    }
    func play(final: Bool) {
        guard UserDefaults.standard.object(forKey: "broadcastSound042") as? Bool ?? true else { return }
        setup(); guard ready, let buffer = final ? match : rack else { return }
        player.stop(); player.volume = 0.55; player.scheduleBuffer(buffer, at: nil); player.play()
    }
    private func make(final: Bool) -> AVAudioPCMBuffer? {
        let sr = 44100.0, seconds = final ? 2.4 : 1.3
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1),
              let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sr * seconds)) else { return nil }
        b.frameLength = b.frameCapacity
        let out = b.floatChannelData![0]; var seed: UInt32 = 3; var lp = 0.0
        let notes: [(Double, Double)] = final ? [(0.25, 392), (0.25, 493.9), (0.25, 587.3), (0.55, 784), (0.55, 987.8), (0.55, 1174.7)]
                                              : [(0.18, 523.3), (0.18, 659.3), (0.18, 784)]
        for i in 0..<Int(b.frameLength) {
            let t = Double(i) / sr
            seed = seed &* 1664525 &+ 1013904223; let n = Double(seed >> 8) / Double(1 << 24) * 2 - 1
            lp += (n - lp) * (0.02 + 0.25 * min(1, t / 0.3))                       // rising filtered whoosh
            let whoosh = lp * 0.35 * sin(min(1, t / 0.35) * .pi)
            var chord = 0.0
            for (start, f) in notes where t >= start {
                let u = t - start, env = min(1, u / 0.012) * exp(-u * (final ? 1.2 : 2.6))
                chord += env * (sin(2 * .pi * f * u) + 0.35 * sin(4 * .pi * f * u) + 0.12 * sin(6 * .pi * f * u))
            }
            out[i] = Float(max(-1, min(1, whoosh + chord * 0.16)))
        }
        return b
    }
}

extension TrainingController {
    private static var broadcastCard = BroadcastCard()
    /// Host and guest both call this when the frames change. `final` = the race is decided.
    func showRackBroadcast(winner: Int, final: Bool) {
        guard matchPlay.active, matchPlay.names.count == 2, matchPlay.frames.count == 2 else { return }
        let names = matchPlay.names, scores = matchPlay.frames
        let rack = max(1, matchPlay.rackNo)
        if final {
            var actions: [BroadcastCard.Action] = []
            if matchPlay.session.role != .guest {
                actions.append(.init(title: "Chơi tiếp", primary: true) { [weak self] in
                    guard let self = self else { return }
                    self.matchPlay.frames = [0, 0]; self.matchPlay.rackNo = 0; self.matchPlay.matchWinner = -1; self.matchPlay.breaker = 1
                    self.startNextRack()
                })
            }
            actions.append(.init(title: "Về sảnh", primary: matchPlay.session.role == .guest) { [weak self] in
                guard let self = self else { return }
                self.leaveMatch(); self.openLobby()
            })
            Self.broadcastCard.present(in: view, kicker: "Kết thúc trận · Race \(matchPlay.raceTo)", names: names, scores: scores, winner: winner,
                                       headline: "🏆 \(names[winner]) thắng trận \(scores[winner])–\(scores[1 - winner])", final: true,
                                       actions: actions, hold: 0)
        } else {
            Self.broadcastCard.present(in: view, kicker: "Kết thúc ván \(rack) · Race \(matchPlay.raceTo)", names: names, scores: scores, winner: winner,
                                       headline: "\(names[winner]) thắng ván \(rack) · ván \(rack + 1) bắt đầu", final: false, actions: [], hold: 3.4)
        }
    }

    // MARK: 0.42 item 8 — remaining group balls under each name (8-ball, after the groups are set)
    private static var groupStrips: [UIStackView] = []
    func updateGroupStrips() {
        let board = matchPlay.scoreboard
        if Self.groupStrips.count != 2 || Self.groupStrips[0].superview == nil {
            Self.groupStrips.forEach { $0.removeFromSuperview() }
            Self.groupStrips = (0...1).map { seat in
                let s = UIStackView(); s.axis = .horizontal; s.spacing = 2; s.alignment = .center; s.isUserInteractionEnabled = false
                s.translatesAutoresizingMaskIntoConstraints = false; s.accessibilityIdentifier = "GroupStrip\(seat)"
                view.addSubview(s)
                NSLayoutConstraint.activate([s.topAnchor.constraint(equalTo: board.bottomAnchor, constant: 3), s.heightAnchor.constraint(equalToConstant: 11),
                                             seat == 0 ? s.leadingAnchor.constraint(equalTo: board.leadingAnchor, constant: 10)
                                                       : s.trailingAnchor.constraint(equalTo: board.trailingAnchor, constant: -10)])
                return s
            }
        }
        let groups = (matchPlay.state["groups"] as? [NSNumber])?.map { $0.intValue } ?? []
        let show = matchPlay.active && !board.isHidden && matchPlay.state["rule"] as? String == "eightBall" && groups.count == 2 && groups[0] >= 0
        for seat in 0...1 {
            let strip = Self.groupStrips[seat]
            strip.isHidden = !show
            guard show else { continue }
            let range = groups[seat] == 0 ? Array(1...7) : Array(9...15)
            let onTable = Set(balls.filter { !$0.sunk }.map { $0.id })
            var ids = range.filter { onTable.contains($0) }
            if ids.isEmpty, onTable.contains(8) { ids = [8] }
            let key = ids.map(String.init).joined(separator: ",")
            if strip.accessibilityValue == key { continue }
            strip.accessibilityValue = key
            strip.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for id in ids { strip.addArrangedSubview(Self.ballChip(id)) }
        }
    }
    static func ballChip(_ id: Int) -> UIView {
        let d: CGFloat = 10, chip = UIView(); chip.translatesAutoresizingMaskIntoConstraints = false
        chip.widthAnchor.constraint(equalToConstant: d).isActive = true; chip.heightAnchor.constraint(equalToConstant: d).isActive = true
        chip.layer.cornerRadius = d / 2; chip.clipsToBounds = true
        chip.layer.borderWidth = 0.5; chip.layer.borderColor = UIColor(white: 0, alpha: 0.5).cgColor
        let base = TableScene.colors[id <= 8 ? id : id - 8]
        if id <= 8 { chip.backgroundColor = base } else {
            chip.backgroundColor = UIColor(white: 0.96, alpha: 1)
            let band = UIView(frame: CGRect(x: 0, y: d * 0.25, width: d, height: d * 0.5)); band.backgroundColor = base; chip.addSubview(band)
        }
        chip.accessibilityLabel = "bi \(id)"
        return chip
    }
}
