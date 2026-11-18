import UIKit
import SceneKit

/// 0.44.1 M4 — new tutorial (owner 17/11: "hướng dẫn rườm rà… đồ hoạ trực quan… đừng dùng khung đen").
/// Replaces the 0.44 15-step overlay (62 % dim, black 340 pt boxes, forced spin/elevation steps before the first shot).
/// Now: no full-screen view, no dim, no black box, no "Next" button, nothing blocks a touch. Captions are the shared
/// GlassPill (white 17 pt bold, ≤ 36 pt tall, ≤ 6 words); a faded hand replays the gesture until the player does it;
/// the key to press only gets a blinking gold ring. First time: two beats on "Cú đầu tiên", then contextual hints
/// (each once, at most one per shot, gone after 6 s). Beats and hints are data records so 0.45 can swap the stroke
/// beat for the power bar without rewriting this file.

/// One teaching beat: the gesture the hand replays, the caption, what to ring, and when it is done.
struct TutorialBeat {
    enum Gesture { case dragAcross, holdBAndStroke, pullPowerBar }
    let id: String
    let caption: String          // Vietnamese source; L10n translates on display (en + 5 drafts in L10n.table)
    let gesture: Gesture
    let showsAimDot: Bool
    let ring: (TrainingController) -> UIView?
    let done: (TrainingController) -> Bool
}
/// A contextual hint: shown once, at most one per shot, hidden after 6 s.
struct TutorialHint {
    let id: String
    let caption: String
    let target: (TrainingController) -> UIView?
}

enum TutorialScript {
    /// Initial aim offset for beat 1 (brief: 12–18°): the player must actually turn the aim onto the dot.
    static let aimOffset = 15.0 * Double.pi / 180
    /// Beat 1 is done within 1° of the line into the pocket.
    static let aimTolerance = 1.0 * Double.pi / 180
    static let hintSeconds = 6.0

    static func firstShot(straight: Double, powerBar: Bool = false) -> [TutorialBeat] {
        [
            TutorialBeat(id: "aim", caption: "Kéo để ngắm vào chấm vàng", gesture: .dragAcross, showsAimDot: true,
                         ring: { _ in nil },
                         done: { tc in abs(remainder(tc.angle - straight, 2 * .pi)) < aimTolerance }),
            powerBar ? TutorialBeat(id: "stroke", caption: "Kéo thanh lực xuống rồi thả", gesture: .pullPowerBar, showsAimDot: true,
                                    ring: { tc in tc.powerBar },
                                    done: { tc in tc.shotActive })   // 0.47 M1: beat 2 with the power bar on
                     : TutorialBeat(id: "stroke", caption: "Giữ B, vuốt lùi rồi đẩy tới", gesture: .holdBAndStroke, showsAimDot: true,
                                    ring: { tc in tc.lockButton },
                                    done: { tc in tc.shotActive }),
        ]
    }
    static let hints: [TutorialHint] = [
        TutorialHint(id: "replay", caption: "Xem lại cú này", target: { $0.quickReplay }),
        TutorialHint(id: "retry", caption: "Đánh lại từ đây", target: { $0.retryButton }),
        TutorialHint(id: "spin", caption: "Kéo để chọn điểm chạm", target: { $0.spin }),
        TutorialHint(id: "elevation", caption: "Kéo để nâng đuôi cơ", target: { $0.elevationPad }),
    ]
    static let seenKey = Prefs.tutorialSeen          // kept: "đã xem" only after the first shot is played
    static let enabledKey = Prefs.tutorialEnabled    // auto-start on first launch
    static let hintsKey = Prefs.tutorialHints       // Tuỳ chỉnh: contextual hints on/off
    static func hintSeenKey(_ id: String) -> String { Prefs.tutorialHintSeen(id) }
}

/// Drives the beats and hints with a handful of small, touch-transparent views.
final class FirstShotCoach {
    private weak var tc: TrainingController?
    private var beats: [TutorialBeat] = []
    private var index = -1
    private(set) var state = "none" {
        didSet { if state != oldValue { log.append(state); if log.count > 24 { log.removeFirst(log.count - 24) } } }
    }
    /// Every state the coach went through, in order (QA + review CI 158: a fast CI could pass beat 2 between two polls).
    private(set) var log: [String] = []
    private let caption = UIView(), captionLabel = UILabel()
    private let hand = UIImageView(), bHand = UIImageView(), aimDot = UIView(), ring = UIView()
    private var timer: Timer?
    private var hideWork: DispatchWorkItem?
    private var objectBall = SIMD2<Double>(0, 0)
    private var beatShownAt = Date()
    var firstShotRunning: Bool { index >= 0 && index < beats.count }

    init(owner: TrainingController) {
        tc = owner
        GlassPill.apply(to: caption, cornerRadius: 18)
        GlassPill.styleCaption(captionLabel, size: 17)
        captionLabel.textAlignment = .center; captionLabel.numberOfLines = 1
        captionLabel.adjustsFontSizeToFitWidth = true; captionLabel.minimumScaleFactor = 0.75
        captionLabel.accessibilityIdentifier = "TutorialCaption"
        caption.addSubview(captionLabel); caption.accessibilityIdentifier = "TutorialPill"
        for v in [hand, bHand] {
            v.image = UIImage(systemName: "hand.point.up.left.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .regular))
            v.tintColor = UIColor.white.withAlphaComponent(0.6); v.contentMode = .scaleAspectFit
            v.layer.shadowColor = UIColor.black.cgColor; v.layer.shadowOpacity = 0.4; v.layer.shadowRadius = 3
        }
        hand.accessibilityIdentifier = "TutorialHand"
        aimDot.backgroundColor = GlassPill.gold; aimDot.layer.cornerRadius = 7
        aimDot.layer.borderColor = UIColor.white.cgColor; aimDot.layer.borderWidth = 2
        aimDot.accessibilityIdentifier = "TutorialAimDot"
        ring.layer.borderColor = GlassPill.gold.cgColor; ring.layer.borderWidth = 3; ring.accessibilityIdentifier = "TutorialRing"
        for v in [caption, hand, bHand, aimDot, ring] { v.isUserInteractionEnabled = false; v.isHidden = true }
    }
    private func attach() {
        guard let view = tc?.view else { return }
        for v in [ring, aimDot, hand, bHand, caption] where v.superview !== view { view.addSubview(v) }
        for v in [ring, aimDot, hand, bHand, caption] { view.bringSubviewToFront(v) }
    }

    // MARK: first shot
    func startFirstShot() {
        guard let tc = tc else { return }
        tc.loadDrill(Drill.startup)
        let drill = Drill.all[Drill.startup], straight = drill.angle
        objectBall = SIMD2(drill.balls.first { $0.id == 1 }?.x ?? 0, drill.balls.first { $0.id == 1 }?.y ?? 0)
        tc.angle = straight + TutorialScript.aimOffset; tc.aimCameraYaw = 0
        tc.refresh(); tc.wakeRendering()
        beats = TutorialScript.firstShot(straight: straight, powerBar: tc.usesPowerBar)
        attach(); show(beat: 0)
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common); timer = t
    }
    private func show(beat i: Int) {
        index = i
        guard i < beats.count, let tc = tc else { endBeats(); return }
        let beat = beats[i]; state = beat.id; beatShownAt = Date()
        say(beat.caption)
        aimDot.isHidden = !beat.showsAimDot
        animateHand(beat.gesture)
        if let target = beat.ring(tc) { ringAround(target) } else { stopRing() }
    }
    private func tick() {
        guard let tc = tc else { return }
        if firstShotRunning, beats[index].showsAimDot { placeAimDot(tc) }
        if !ring.isHidden, let t = ringTarget, t.window != nil {
            ring.frame = t.convert(t.bounds, to: tc.view).insetBy(dx: -6, dy: -6); ring.layer.cornerRadius = min(ring.bounds.width, ring.bounds.height) / 2
        }
        // QA only (--tutorial-stroke-qa): XCUITest cannot hold B with one finger and stroke with another, so the UI
        // test lets the app fire the stroke 1.5 s after beat 2 is on screen. The real gesture needs a device.
        if firstShotRunning, beats[index].id == "stroke", QA.has("--tutorial-stroke-qa"),
           !tc.qaTutorialStrokeFired, Date().timeIntervalSince(beatShownAt) > 1.5, !tc.shotActive, !tc.presentationBusy {
            tc.qaTutorialStrokeFired = true; tc.locked = true; tc.shoot(2.0)
        }
        // 0.44.1 review: a stroke during ANY beat (players often shoot before aiming) ends the beats like beat 2 does.
        if firstShotRunning, tc.shotActive { state = "shot"; index = beats.count; hideAll(keepCaption: false); return }
        if firstShotRunning, beats[index].done(tc) {
            if beats[index].id == "stroke" { state = "shot"; index = beats.count; hideAll(keepCaption: false); return }
            show(beat: index + 1)
        }
    }
    private func endBeats() { index = beats.count; hideAll(keepCaption: false) }
    /// Ghost-ball aim point on the object ball (2R back from its centre along the line into the corner pocket).
    private func placeAimDot(_ tc: TrainingController) {
        let r = 0.028575, pocket = SIMD2(BLFirstShotPocketX(), BLFirstShotPocketY())
        let u = simd_normalize(pocket - objectBall), ghost = objectBall - u * 2 * r
        let p = tc.scn.projectPoint(SCNVector3(Float(ghost.x), Float(r), Float(ghost.y)))
        guard p.z > 0, p.z < 1 else { aimDot.isHidden = true; return }
        aimDot.isHidden = false
        aimDot.frame = CGRect(x: CGFloat(p.x) - 7, y: CGFloat(p.y) - 7, width: 14, height: 14)
    }

    /// Called by TrainingController.finishShot.
    func shotFinished(potted: Bool, scratch: Bool, shots: Int) {
        guard let tc = tc else { return }
        if state == "shot" {
            UserDefaults.standard.set(true, forKey: Prefs.tutorialSeen)   // "đã xem" only after the first shot
            tc.appFlow.done(.tutorial)   // 0.45 M5.3: launch flow reaches the table (ignored if not in the tutorial step)
            if potted && !scratch {
                state = "potted"; say("Vào rồi!"); UINotificationFeedbackGenerator().notificationOccurred(.success)
                hideLater(2.2) { [weak self] in self?.hint(missed: false, shots: shots) }
            } else {
                state = "retry"; say("Thử lại nhé"); UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self, weak tc] in
                    guard let self = self, let tc = tc else { return }
                    self.restoreFirstShot(tc, attempts: 60)
                }
            }
            return
        }
        hint(missed: !potted, shots: shots)
    }
    /// "Thử lại nhé": the balls go back by themselves and beat 2 runs again (aim kept).
    private func restoreFirstShot(_ tc: TrainingController, attempts: Int) {
        guard tc.drillIndex == Drill.startup, !tc.matchPlay.active else { hideAll(keepCaption: false); return }
        if tc.shotActive || tc.presentationBusy || !tc.localTurn {
            // Wait for the replay/shot camera however long it takes; give up cleanly after ~30 s.
            guard attempts > 0 else { hideAll(keepCaption: false); index = beats.count; state = "none"; return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.restoreFirstShot(tc, attempts: attempts - 1) }; return
        }
        let aim = tc.angle
        tc.loadDrill(Drill.startup); tc.angle = aim; tc.refresh(); tc.wakeRendering()
        show(beat: 1)
    }

    // MARK: contextual hints
    private func hint(missed: Bool, shots: Int) {
        // Review CI 158: no contextual hint may appear before the two-beat first shot is finished.
        guard !firstShotRunning, UserDefaults.standard.bool(forKey: TutorialScript.seenKey) || state == "potted" || state == "none" else { return }
        guard let tc = tc, UserDefaults.standard.object(forKey: TutorialScript.hintsKey) as? Bool ?? true else { hideAll(keepCaption: false); return }
        func unseen(_ id: String) -> Bool { !UserDefaults.standard.bool(forKey: TutorialScript.hintSeenKey(id)) }
        let c = tc.cue
        let nearRail = c.map { abs($0.x) > 0.635 - 0.06 || abs($0.y) > 1.27 - 0.06 } ?? false
        let title = Drill.all.indices.contains(tc.drillIndex) ? Drill.all[tc.drillIndex].title : ""
        let elevated = tc.shotKind != 0 || title.contains("Jump") || title.contains("Massé")
        var pick: String?
        if unseen("replay") { pick = "replay" }
        else if missed && unseen("retry") { pick = "retry" }
        else if shots >= 3 && unseen("spin") { pick = "spin" }
        else if (nearRail || elevated) && unseen("elevation") { pick = "elevation" }
        guard let id = pick else { hideAll(keepCaption: false); return }
        showHint(id)
    }
    /// Shows one hint now (also from Menu → Hướng dẫn chơi); marks it seen.
    func showHint(_ id: String) {
        guard let tc = tc, let h = TutorialScript.hints.first(where: { $0.id == id }) else { return }
        UserDefaults.standard.set(true, forKey: TutorialScript.hintSeenKey(id))
        attach(); state = "hint-" + id
        hand.layer.removeAllAnimations(); hand.isHidden = true; bHand.isHidden = true; aimDot.isHidden = true
        say(h.caption)
        if let t = h.target(tc), t.window != nil, !t.isHidden { ringAround(t) } else { stopRing() }
        hideLater(TutorialScript.hintSeconds, then: nil)
    }

    // MARK: drawing
    private var ringTarget: UIView?
    private func say(_ text: String) {
        guard let view = tc?.view else { return }
        hideWork?.cancel()
        captionLabel.text = text   // L10n swizzle translates
        let shown = captionLabel.text ?? text
        let width = min(view.bounds.width - 40, captionLabel.intrinsicContentSize.width + 36)
        // Low on the screen, between B / the effect ball and the elevation dial: never over the balls in the aim view.
        let y = view.bounds.height - view.safeAreaInsets.bottom - 36 - 14
        caption.frame = CGRect(x: (view.bounds.width - width) / 2, y: y, width: width, height: 36)
        captionLabel.frame = caption.bounds.insetBy(dx: 16, dy: 0)
        caption.isHidden = false; caption.alpha = 0
        UIView.animate(withDuration: 0.2) { self.caption.alpha = 1 }
        UIAccessibility.post(notification: .announcement, argument: shown)   // VoiceOver reads the caption
    }
    private func hideLater(_ seconds: Double, then: (() -> Void)?) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if let then = then { then() } else { self.hideAll(keepCaption: false) }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
    private func hideAll(keepCaption: Bool) {
        hand.layer.removeAllAnimations(); bHand.layer.removeAllAnimations(); hand.isHidden = true; bHand.isHidden = true
        aimDot.isHidden = true; stopRing()
        if !keepCaption { UIView.animate(withDuration: 0.2, animations: { self.caption.alpha = 0 }) { _ in if self.caption.alpha == 0 { self.caption.isHidden = true } } }
        if state.hasPrefix("hint") || state == "potted" { state = "none" }
        if !firstShotRunning && state == "none" { timer?.invalidate(); timer = nil }
    }
    private func ringAround(_ v: UIView) {
        guard let view = tc?.view else { return }
        ringTarget = v
        ring.frame = v.convert(v.bounds, to: view).insetBy(dx: -6, dy: -6)
        ring.layer.cornerRadius = min(ring.bounds.width, ring.bounds.height) / 2
        ring.isHidden = false
        let blink = CABasicAnimation(keyPath: "opacity"); blink.fromValue = 1; blink.toValue = 0.15
        blink.duration = 0.55; blink.autoreverses = true; blink.repeatCount = .infinity
        ring.layer.add(blink, forKey: "blink")
    }
    private func stopRing() { ring.layer.removeAllAnimations(); ring.isHidden = true; ringTarget = nil }
    /// The faded hand replays the gesture in a loop until the beat is done.
    private func animateHand(_ gesture: TutorialBeat.Gesture) {
        guard let view = tc?.view else { return }
        hand.layer.removeAllAnimations(); bHand.layer.removeAllAnimations()
        let b = view.bounds
        hand.frame = CGRect(x: 0, y: 0, width: 48, height: 48); hand.isHidden = false
        switch gesture {
        case .dragAcross:
            bHand.isHidden = true
            let move = CAKeyframeAnimation(keyPath: "position")
            move.values = [CGPoint(x: b.width * 0.40, y: b.height * 0.60), CGPoint(x: b.width * 0.40, y: b.height * 0.60),
                           CGPoint(x: b.width * 0.60, y: b.height * 0.60), CGPoint(x: b.width * 0.60, y: b.height * 0.60)].map { NSValue(cgPoint: $0) }
            move.keyTimes = [0, 0.15, 0.75, 1]; move.duration = 1.8; move.repeatCount = .infinity
            hand.layer.add(move, forKey: "move"); hand.layer.add(fade(1.8), forKey: "fade")
        case .holdBAndStroke:
            if let lock = tc?.lockButton, lock.window != nil {
                let c = lock.convert(CGPoint(x: lock.bounds.midX, y: lock.bounds.midY), to: view)
                bHand.frame = CGRect(x: 0, y: 0, width: 48, height: 48); bHand.center = CGPoint(x: c.x + 10, y: c.y + 18); bHand.isHidden = false
                let press = CABasicAnimation(keyPath: "transform.scale"); press.fromValue = 1; press.toValue = 0.86
                press.duration = 0.45; press.autoreverses = true; press.repeatCount = .infinity
                bHand.layer.add(press, forKey: "press")
            }
            let x = b.width * 0.58
            let move = CAKeyframeAnimation(keyPath: "position")
            move.values = [CGPoint(x: x, y: b.height * 0.55), CGPoint(x: x, y: b.height * 0.72), CGPoint(x: x, y: b.height * 0.40),
                           CGPoint(x: x, y: b.height * 0.40)].map { NSValue(cgPoint: $0) }
            move.keyTimes = [0, 0.45, 0.7, 1]; move.duration = 1.9; move.repeatCount = .infinity
            hand.layer.add(move, forKey: "move"); hand.layer.add(fade(1.9), forKey: "fade")
        case .pullPowerBar:   // 0.47 M1: the hand pulls the bar down and lets go
            bHand.isHidden = true
            guard let bar = tc?.powerBar, bar.window != nil else { break }
            let top = bar.convert(CGPoint(x: bar.bounds.midX, y: 26), to: view), bottom = bar.convert(CGPoint(x: bar.bounds.midX, y: bar.bounds.height * 0.75), to: view)
            let move = CAKeyframeAnimation(keyPath: "position")
            move.values = [top, top, bottom, bottom].map { NSValue(cgPoint: CGPoint(x: $0.x + 12, y: $0.y + 18)) }
            move.keyTimes = [0, 0.15, 0.7, 1]; move.duration = 1.9; move.repeatCount = .infinity
            hand.layer.add(move, forKey: "move"); hand.layer.add(fade(1.9), forKey: "fade")
        }
    }
    private func fade(_ d: Double) -> CAKeyframeAnimation {
        let f = CAKeyframeAnimation(keyPath: "opacity"); f.values = [0, 1, 1, 0]; f.keyTimes = [0, 0.12, 0.8, 1]
        f.duration = d; f.repeatCount = .infinity; return f
    }
    func stop() { timer?.invalidate(); timer = nil; index = beats.count; hideWork?.cancel(); state = "none"; hideAll(keepCaption: false); tc?.appFlow.done(.tutorial) }
}

extension TrainingController {
    static let tutorialSeenKey = TutorialScript.seenKey
    /// First time the player reaches the table after the Lobby closes (practice, "Cú đầu tiên"). QA: --tutorial-qa
    /// forces it; --keep-lobby-qa runs the real path (Lobby → Tập tự do → tutorial); other QA launches never show it.
    /// 0.45 M5.3: called by AppFlow (tutorial step) right after the Lobby closed — no timer. Returns true if the beats
    /// started (the flow then waits for `appFlow.done(.tutorial)` from the first shot).
    @discardableResult func maybeStartTutorial() -> Bool {
        let forced = QA.has("--tutorial-qa"), realPath = QA.has("--keep-lobby-qa")
        if !forced && !realPath && (QA.has("--visual-qa") || QA.arguments.contains { $0.hasPrefix("--ux0") || $0.hasPrefix("--g1-") }) { return false }
        if QA.has("--fresh-tutorial") && !freshTutorialDone {
            freshTutorialDone = true
            UserDefaults.standard.removeObject(forKey: Prefs.tutorialSeen)
            for h in TutorialScript.hints { UserDefaults.standard.removeObject(forKey: Prefs.tutorialHintSeen(h.id)) }
        }
        guard forced || (Prefs.flag(Prefs.tutorialEnabled, true) && !UserDefaults.standard.bool(forKey: Prefs.tutorialSeen)) else { return false }
        guard view.window != nil, presentedViewController == nil, !matchPlay.active, replayIndex == nil,
              firstShotCoach?.firstShotRunning != true, firstShotCoach?.state != "shot", (drillIndex == Drill.startup && !lessonActive) || forced else { return false }   // 0.47: bài chọn từ Sảnh (Bài hôm nay…) trùng bài khởi động thì không bị hướng dẫn chen vào
        return startTutorial()
    }
    /// Starts the two first-shot beats now (Menu → Hướng dẫn chơi → "Cú đầu tiên").
    @discardableResult func startTutorial() -> Bool {
        guard view.window != nil, !matchPlay.active, replayIndex == nil else { return false }
        let coach = firstShotCoach ?? FirstShotCoach(owner: self); firstShotCoach = coach
        coach.startFirstShot()
        return true
    }
    /// finishShot hook: result caption for the first shot, then at most one contextual hint.
    func tutorialShotFinished(events: [[String: NSNumber]]) {
        guard !matchPlay.active, replayIndex == nil else { return }
        let potted = events.contains { $0["kind"]?.intValue == 2 && ($0["a"]?.intValue ?? 0) > 0 }
        let scratch = events.contains { $0["kind"]?.intValue == 2 && $0["a"]?.intValue == 0 }
        tutorialShots += 1
        let coach = firstShotCoach ?? FirstShotCoach(owner: self); firstShotCoach = coach
        coach.shotFinished(potted: potted, scratch: scratch, shots: tutorialShots)
    }
    /// Menu → "Hướng dẫn chơi": the first shot again, or any hint on its own.
    func showTutorialList() {
        let sheet = UIAlertController(title: "Hướng dẫn chơi", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Cú đầu tiên · ngắm và ra cơ", style: .default) { [weak self] _ in self?.startTutorial() })
        for h in TutorialScript.hints {
            sheet.addAction(UIAlertAction(title: "Gợi ý · " + h.caption, style: .default) { [weak self] _ in
                guard let self = self else { return }
                let coach = self.firstShotCoach ?? FirstShotCoach(owner: self); self.firstShotCoach = coach; coach.showHint(h.id)
            })
        }
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        presentSheet(sheet, source: menuButton)
    }
}
