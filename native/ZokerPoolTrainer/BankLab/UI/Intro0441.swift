import UIKit
import SceneKit
import AVFoundation

/// 0.44.1 M5 — new intro, filmed ON THE PLAY TABLE (same SCNView, same render path as play: wherever the game draws,
/// the intro draws). The 0.43 intro was its own overlay SCNView added to the window, with HDR + bloom + depth of field
/// + motion blur + colour fringe, and `viewDidAppear` presented the full-screen Lobby on top of it (Docs/NGHIEM-THU-0.44.1).
///
/// First launch, 6.0 s: lights up + low slide along the rail (0–0.6) · cue draw-back + wind (0.6–1.6) · REAL 9-ball
/// break at 1.6 s (Physics.cpp replaying BankLab/UI/IntroBreak.h, Tests/IntroBreakTests.cpp) with flash, felt shock
/// ring, chalk puff, 0.25 s camera shake, 0.5 s of 0.25× slow motion, streaks behind balls over 3 m/s · follow the ball
/// that drops (pocket jaw + drop + gold sparks) · crane up, gold particles converge into the Z logo and "ZOKER POOL"
/// with a light sweep (2D Core Animation over the 3D) · fade, then the Lobby. Later launches: the 2D logo only, ≤ 1.2 s.
/// Tap anywhere: gone within 0.2 s, sound stops, `finish` runs exactly once. Reduce Motion, Low Power, or no 3D frame
/// within 0.5 s ⇒ the 2D logo only. The screen is never black: the logo layer is drawn from the first frame.
/// No bloom / motion blur / depth of field (play camera settings).

// MARK: - ShotFX (reusable in 0.47 M4: each effect switches on/off on its own)
struct ShotFXOptions {
    var flash = true, shockRing = true, chalk = true, streaks = true, pocketSparks = true, shake = true
    static var reduced: ShotFXOptions { var o = ShotFXOptions(); o.flash = false; o.shake = false; return o }
}
final class ShotFX {
    var options: ShotFXOptions
    private weak var scene: SCNScene?
    private weak var hostView: UIView?
    private var streakNodes: [Int: SCNNode] = [:], lastPositions: [Int: SIMD3<Float>] = [:]
    private var shakeUntil: CFTimeInterval = 0, shakeStart: CFTimeInterval = 0, shakeAmplitude: Float = 0
    private static let additive: (UIColor) -> SCNMaterial = { colour in
        let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = colour; m.blendMode = .add
        m.writesToDepthBuffer = false; m.isDoubleSided = true; return m
    }
    init(scene: SCNScene, hostView: UIView, options: ShotFXOptions = ShotFXOptions()) { self.scene = scene; self.hostView = hostView; self.options = options }

    /// Two-frame white flash over the view.
    func flash() {
        guard options.flash, let host = hostView else { return }
        let v = UIView(frame: host.bounds); v.backgroundColor = UIColor(white: 1, alpha: 0.55); v.isUserInteractionEnabled = false
        host.addSubview(v)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 / 60) { UIView.animate(withDuration: 0.08, animations: { v.alpha = 0 }) { _ in v.removeFromSuperview() } }
    }
    /// Gold ring spreading on the felt.
    func shockRing(at p: SIMD3<Float>) {
        guard options.shockRing, let scene = scene else { return }
        let plane = SCNPlane(width: 1, height: 1)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { c in
            UIColor(red: 1, green: 0.82, blue: 0.45, alpha: 0.9).setStroke()
            let path = UIBezierPath(ovalIn: CGRect(x: 10, y: 10, width: 108, height: 108)); path.lineWidth = 6; path.stroke()
        }
        let m = Self.additive(.white); m.diffuse.contents = image; plane.materials = [m]
        let n = SCNNode(geometry: plane); n.eulerAngles.x = -.pi / 2; n.simdPosition = SIMD3(p.x, 0.001, p.z); n.scale = SCNVector3(0.02, 0.02, 0.02)
        scene.rootNode.addChildNode(n)
        n.runAction(.sequence([.group([.scale(to: 0.55, duration: 0.45), .fadeOut(duration: 0.45)]), .removeFromParentNode()]))
    }
    /// Chalk dust at the cue tip.
    func chalk(at p: SIMD3<Float>) {
        guard options.chalk, let scene = scene else { return }
        let s = SCNParticleSystem(); s.birthRate = 200; s.emissionDuration = 0.06; s.loops = false   // 0.57: ≤ 12 motes
        s.particleLifeSpan = 0.5; s.particleSize = 0.0035; s.particleColor = UIColor(red: 0.55, green: 0.72, blue: 0.95, alpha: 0.7)
        s.particleVelocity = 0.25; s.particleVelocityVariation = 0.2; s.spreadingAngle = 70; s.blendMode = .alpha
        s.emitterShape = SCNSphere(radius: 0.004); s.isAffectedByGravity = true; s.acceleration = SCNVector3(0, -0.6, 0)
        let n = SCNNode(); n.simdPosition = p; scene.rootNode.addChildNode(n); n.addParticleSystem(s)
        n.runAction(.sequence([.wait(duration: 1.0), .removeFromParentNode()]))
    }
    /// Short light streaks behind balls faster than 3 m/s (call every frame with the ball positions).
    func streaks(_ balls: [(id: Int, p: SIMD3<Float>)], dt: Double) {
        guard options.streaks, let scene = scene, dt > 0 else { return }
        for b in balls {
            let last = lastPositions[b.id] ?? b.p; lastPositions[b.id] = b.p
            let v = (b.p - last) / Float(dt), speed = simd_length(v)
            let node = streakNodes[b.id] ?? {
                let plane = SCNPlane(width: 0.02, height: 1); plane.materials = [Self.additive(UIColor(red: 1, green: 0.93, blue: 0.75, alpha: 1))]
                let n = SCNNode(geometry: plane); n.opacity = 0; scene.rootNode.addChildNode(n); streakNodes[b.id] = n; return n
            }()
            guard speed > 3 else { node.opacity = max(0, node.opacity - 0.15); continue }
            let dir = v / speed, len = min(0.28, speed * 0.035)
            node.simdPosition = SIMD3(b.p.x - dir.x * len / 2, 0.006, b.p.z - dir.z * len / 2)
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, -atan2(dir.x, dir.z) + .pi)
            node.scale = SCNVector3(1, len, 1); node.opacity = CGFloat(min(0.55, (speed - 3) * 0.12 + 0.2))
        }
    }
    /// Gold sparks out of a pocket.
    /// 0.57 I1: a few chalk-dust motes hanging in the table light (≤ IntroTiming.dustCount alive at once).
    func dust(over p: SIMD3<Float>) {
        guard let scene = scene else { return }
        let s = SCNParticleSystem(); s.birthRate = 30; s.loops = true; s.particleLifeSpan = 1.6; s.particleLifeSpanVariation = 0.5
        s.particleSize = 0.0045; s.particleColor = UIColor(white: 0.95, alpha: 0.35); s.blendMode = .alpha
        s.emitterShape = SCNBox(width: 0.5, height: 0.25, length: 0.5, chamferRadius: 0); s.particleVelocity = 0.02; s.particleVelocityVariation = 0.02
        s.acceleration = SCNVector3(0, 0.01, 0); s.isAffectedByGravity = false; s.warmupDuration = 0.4
        let n = SCNNode(); n.simdPosition = p; scene.rootNode.addChildNode(n); n.addParticleSystem(s)
        n.runAction(.sequence([.wait(duration: 3.3), .removeFromParentNode()]))
    }
    func pocketSparks(at p: SIMD3<Float>) {
        guard options.pocketSparks, let scene = scene else { return }
        let s = SCNParticleSystem(); s.birthRate = 80; s.emissionDuration = 0.12; s.loops = false   // 0.57: ≤ 10 sparks
        s.particleLifeSpan = 0.7; s.particleLifeSpanVariation = 0.3; s.particleSize = 0.006
        s.particleColor = UIColor(red: 1, green: 0.8, blue: 0.35, alpha: 1); s.blendMode = .additive
        s.particleVelocity = 0.9; s.particleVelocityVariation = 0.5; s.spreadingAngle = 35
        s.emittingDirection = SCNVector3(0, 1, 0); s.acceleration = SCNVector3(0, -2.5, 0)
        let n = SCNNode(); n.simdPosition = p; scene.rootNode.addChildNode(n); n.addParticleSystem(s)
        n.runAction(.sequence([.wait(duration: 1.4), .removeFromParentNode()]))
    }
    /// Camera shake that dies out over `duration` (call `shakeOffset` every frame).
    func shake(amplitude: Float = 0.012, duration: Double = 0.25) {
        guard options.shake else { return }
        shakeStart = CACurrentMediaTime(); shakeUntil = shakeStart + duration; shakeAmplitude = amplitude
    }
    func shakeOffset() -> SIMD3<Float> {
        let now = CACurrentMediaTime(); guard now < shakeUntil else { return .zero }
        let k = Float((shakeUntil - now) / max(0.001, shakeUntil - shakeStart)), t = Float(now - shakeStart)
        return SIMD3(sin(t * 91) * shakeAmplitude * k, sin(t * 73 + 1) * shakeAmplitude * k * 0.6, 0)
    }
    func removeAll() { for n in streakNodes.values { n.removeFromParentNode() }; streakNodes.removeAll(); lastPositions.removeAll() }
}

// MARK: - Sound: plays IntroMix0441 (Tools/gen_intro_audio.py), one player per layer
final class IntroMixPlayer {
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    func play(full: Bool) {
        guard UserDefaults.standard.object(forKey: "poolAudioEnabled") as? Bool ?? true,
              let sheet = NSDataAsset(name: "IntroMix0441").flatMap({ try? JSONSerialization.jsonObject(with: $0.data) as? [String: Any] }),
              let part = sheet[full ? "full" : "sting"] as? [String: Any], let layers = part["layers"] as? [[String: Any]] else { return }
        let master = (part["master"] as? Double) ?? 1
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        var buffers: [String: AVAudioPCMBuffer] = [:]
        func buffer(_ name: String) -> AVAudioPCMBuffer? {
            if let b = buffers[name] { return b }
            guard let data = NSDataAsset(name: name)?.data else { return nil }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".wav")
            try? data.write(to: url)
            guard let file = try? AVAudioFile(forReading: url), let b = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: b)) != nil else { return nil }
            buffers[name] = b; return b
        }
        var scheduled: [(AVAudioPlayerNode, AVAudioPCMBuffer, Double)] = []
        for layer in layers {
            guard let name = layer["sound"] as? String, let b = buffer(name) else { continue }
            let p = AVAudioPlayerNode(), pitch = AVAudioUnitVarispeed()
            pitch.rate = Float((layer["rate"] as? Double) ?? 1)
            engine.attach(p); engine.attach(pitch)
            engine.connect(p, to: pitch, format: b.format); engine.connect(pitch, to: engine.mainMixerNode, format: b.format)
            p.volume = Float(((layer["gain"] as? Double) ?? 1) * master)
            players.append(p); scheduled.append((p, b, (layer["at"] as? Double) ?? 0))
            if name == "IntroRiser0441" || name == "IntroJingle0441" || name.hasPrefix("IntroBGM") { bed.append((p, p.volume)) }
        }
        // 0.57 I5: a place for the lounge bed — an "IntroBGM" data asset (the owner's Suno file) plays under the film when it exists, silence otherwise
        if full, let b = buffer("IntroBGM") {
            let p = AVAudioPlayerNode(); engine.attach(p); engine.connect(p, to: engine.mainMixerNode, format: b.format)
            p.volume = Float(0.5 * master); players.append(p); scheduled.append((p, b, 0)); bed.append((p, p.volume))
        }
        guard !scheduled.isEmpty, (try? engine.start()) != nil else { return }
        // Each player's own timeline starts at play(); the buffer is placed `at` seconds into it. (0.44.1: play(at: hostTime)
        // threw an Objective-C exception on the iOS 26.3 Simulator and aborted the app.)
        for (p, b, at) in scheduled {
            let rate = b.format.sampleRate
            p.scheduleBuffer(b, at: AVAudioTime(sampleTime: AVAudioFramePosition(at * rate), atRate: rate), options: [], completionHandler: nil)
        }
        for (p, _, _) in scheduled where p.engine != nil { p.play() }
    }
    private var bed: [(AVAudioPlayerNode, Float)] = []   // layers that duck: the riser, the logo chime and a background bed ("IntroBGM", when it exists)
    func setDuck(_ gain: Float) { for (p, base) in bed { p.volume = base * gain } }
    func stop() { players.forEach { $0.stop() }; engine.stop() }
}

// MARK: - Director
final class IntroDirector0441 {
    static let fullSeconds = IntroTiming.fullSeconds, stingSeconds = 1.2   // 0.57 I1: 3.2 s (was 6.0 s)
    /// 0.57 I7 probe values of the last intro: wall seconds from start to finish, ms from a skip to the end, and its mode ("full" = 3D, "logo").
    static var lastWall = 0.0, lastFilm = 0.0, lastSkipMs = -1.0, lastMode = ""   // film = wall minus main-thread stalls the timeline froze for
    private var skipAt: CFTimeInterval = 0, startedAt: CFTimeInterval = 0
    private weak var tc: TrainingController?
    private let full: Bool
    private var done: (() -> Void)?
    private var finished = false
    private let overlay = UIView(), logo = UIImageView(), title = UILabel(), shade = UIView()
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0, lastFrame: CFTimeInterval = 0
    private(set) var maxFrameMs = 0.0, frames = 0
    private var world: BLWorld?
    private var fx: ShotFX?
    private let camera = SCNNode()
    private var simTime = 0.0, struck = false, dropped = false, logoShown = false, fadeStarted = false
    private let audio = IntroMixPlayer()
    private let haptics = IntroHaptics()   // 0.57 I2
    private var eventsSeen = 0, stopHapticDone = false, baseFov: CGFloat = 45
    private var balls: [BallState] = []
    private(set) var mode = "none"   // "full" | "logo" (QA) | "video" (0.59 rendered film)
    private var player: AVPlayer?, playerLayer: AVPlayerLayer?, filmEnd: NSObjectProtocol?, filmURL: URL?
    private var hiddenByIntro: [UIView] = []
    var onFinish: ((IntroDirector0441) -> Void)?
    var probeStills: [[String: Any]] = []

    init(owner: TrainingController, full: Bool) { tc = owner; self.full = full }
    var tcRef: TrainingController? { tc }
    var overlayView: UIView { overlay }

    func run(done: @escaping () -> Void) {
        guard let tc = tc else { done(); return }
        self.done = done
        let reduce = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled || QA.has("--intro-reduce-qa")   // QA: stands in for the system switch
        mode = full && !reduce ? "full" : "logo"
        // 0.59 (đợt 1): the rendered film "Cú đánh hai băng" (intro C, 1080p60, own sound) when it is in the bundle — 6 s the first time,
        // its last 1.5 s afterwards, a tap skips. Reduce Motion / Low Power keep the 2D logo. QA launches keep the 3D director unless --intro-video-qa.
        if !reduce, IntroFilm059.wanted, let url = IntroFilm059.url() { mode = "video"; filmURL = url }
        hiddenByIntro = tc.view.subviews.filter { $0 !== tc.scn && !$0.isHidden }
        hiddenByIntro.forEach { $0.isHidden = true }   // play UI hidden during the intro (only what was visible)
        overlay.frame = tc.view.bounds; overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.accessibilityIdentifier = "IntroOverlay"; overlay.isAccessibilityElement = true
        overlay.accessibilityLabel = "Bỏ qua"; overlay.accessibilityTraits = .button   // VoiceOver: "Bỏ qua"
        overlay.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(skip)))
        tc.view.addSubview(overlay)
        shade.frame = overlay.bounds; shade.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shade.backgroundColor = UIColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1); shade.isUserInteractionEnabled = false
        overlay.addSubview(shade)
        buildLogo()
        start = CACurrentMediaTime(); lastFrame = start; startedAt = start
        if mode == "video", let url = filmURL { startFilm(url); return }
        if mode == "full" { setUp3D(tc) } else { showLogo(at: 0, duration: 0.25) }
        audio.play(full: mode == "full")
        let l = CADisplayLink(target: self, selector: #selector(step)); l.add(to: .main, forMode: .common); link = l
    }

    private func setUp3D(_ tc: TrainingController) {
        let w = BLWorld(); w.settings = tc.engine.settings
        balls = (0..<Int(BL_INTRO_BALL_COUNT)).map { i in BallState(id: Int(BLIntroBall(Int32(i), 0)), x: BLIntroBall(Int32(i), 1), y: BLIntroBall(Int32(i), 2)) }
        w.loadLayout(balls.map { $0.dictionary }); world = w
        tc.introRunning = true
        tc.table.resetPocketPresentation()
        tc.table.update(balls, dt: 0)
        camera.camera = (tc.table.camera.camera?.copy() as? SCNCamera) ?? SCNCamera()
        baseFov = camera.camera?.fieldOfView ?? 45
        camera.camera?.wantsDepthOfField = false; camera.camera?.motionBlurIntensity = 0; camera.camera?.bloomIntensity = 0
        tc.table.scene.rootNode.addChildNode(camera); tc.scn.pointOfView = camera
        tc.scn.rendersContinuously = true
        tc.scn.isUserInteractionEnabled = false   // touches during the fade never reach aim/camera gestures
        fx = ShotFX(scene: tc.table.scene, hostView: overlay)
        fx?.dust(over: SIMD3(Float(BL_INTRO_CUE_X), 0.12, Float(BL_INTRO_CUE_Y)))   // 0.57 I1: ≤ 40 chalk-dust motes drifting in the light
        // The 3D must show a frame within 0.5 s, otherwise the 2D logo plays alone (never a black screen).
        let frames0 = tc.table.pacer.renderedFrames
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak tc] in
            guard let self = self, let tc = tc, !self.finished, self.mode == "full" else { return }
            if tc.table.pacer.renderedFrames <= frames0 { self.mode = "logo"; self.teardown3D(); self.layoutLogo(); self.start = CACurrentMediaTime() - 0; self.showLogo(at: 0, duration: 0.25) }
        }
    }

    // timeline helpers
    private static func ease(_ x: Double) -> Float { let t = Float(max(0, min(1, x))); return t * t * (3 - 2 * t) }
    private func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> { a + (b - a) * t }
    private func ball(_ id: Int) -> SIMD3<Float> {
        let b = balls.first { $0.id == id } ?? BallState(id: id, x: 0, y: 0)
        return SIMD3(Float(b.x), 0.028575, Float(b.y))
    }
    /// Simulated seconds after the strike for a wall time (1× for 0.125 s, 0.5 s at 0.25×, then 1×).
    static func simTime(wall t: Double) -> Double { IntroTiming.simTime(wall: t) }

    @objc private func step(_ l: CADisplayLink) {
        guard let tc = tc, !finished else { return }
        let now = CACurrentMediaTime()
        let dtWall = now - lastFrame; lastFrame = now
        // A main-thread stall (cold shader compile, first frame on a new install) must not eat the film: the timeline
        // freezes while no frame is shown, so every beat is actually seen. Stalls still count in maxFrameMs.
        if dtWall > 0.1 { start += dtWall - 1.0 / 60 }
        var t = now - start
        if let q = QA.arguments.first(where: { $0.hasPrefix("--intro-skip-at-qa=") }), Double(q.dropFirst("--intro-skip-at-qa=".count)).map({ t >= $0 }) == true, skipAt == 0 { skip() }   // QA: a tap at that moment
        // 0.53 stability: --intro-hold-qa freezes the film at 1 s until the tap, so a slow cold-start UI test always sees the intro FIRST and alone
        if QA.has("--intro-hold-qa"), t > 1.0 { start = now - 1.0; t = 1.0 }
        if frames > 2 { maxFrameMs = max(maxFrameMs, dtWall * 1000) }; frames += 1
        if mode == "logo" {
            if t >= Self.stingSeconds { finish() }
            return
        }
        // shade = room lights coming up
        shade.alpha = CGFloat(max(0, 0.5 - t / 1.2))   // lights come up from half: never a black frame
        if let w = world {
            let target = Self.simTime(wall: t)
            if t >= IntroTiming.strike && !struck {
                struck = true
                w.strike(angle: Double(BL_INTRO_ANGLE), speed: Double(BL_INTRO_SPEED), side: 0, top: Double(BL_INTRO_TOP))
                let cue = ball(0)
                fx?.flash(); fx?.shockRing(at: cue); fx?.chalk(at: cue + SIMD3(-Float(cos(BL_INTRO_ANGLE)) * 0.03, 0, -Float(sin(BL_INTRO_ANGLE)) * 0.03)); fx?.shake()
                haptics.tipMeetsBall()   // 0.57 I2 (CoreHaptics, replaces the generic heavy tap)
            }
            if struck, target > simTime { w.advance(target - simTime); simTime = target }
            // 0.57 I2: small taps on the REAL ball–ball impacts of this break (solver events), never hard-coded times
            if struck { let ev = w.events(since: UInt(eventsSeen)); eventsSeen += ev.count
                for e in ev where (e["kind"]?.intValue ?? -1) == 1 { haptics.ballImpact(time: e["time"]?.doubleValue ?? 0, impact: e["impact"]?.doubleValue ?? 0) } }
            balls = w.ballStates
            tc.table.update(balls, dt: dtWall); tc.table.animatePockets(dtWall)
            fx?.streaks(balls.filter { !$0.sunk }.map { (id: $0.id, p: SIMD3(Float($0.x), 0.028575, Float($0.y))) }, dt: dtWall)
            if !dropped, simTime >= Double(BL_INTRO_FIRST_DROP_TIME) {
                dropped = true; haptics.pocketDrop()
                fx?.pocketSparks(at: SIMD3(Float(BLFirstShotPocketX()), 0.02, Float(BLFirstShotPocketY())))
            }
            // cue: draw back 0.45–0.79, stop 80 ms, stroke to the ball at 0.95 (IntroTiming), gone just after
            let cueBall = balls.first { $0.id == 0 }
            if t >= IntroTiming.holdEnd && !stopHapticDone { stopHapticDone = true; haptics.cueStops() }
            if t < IntroTiming.strike + 0.1 {
                tc.table.showCue(cueBall, angle: Double(BL_INTRO_ANGLE), visible: t >= 0.2, pull: IntroTiming.pull(t))
            } else { tc.table.showCue(cueBall, angle: Double(BL_INTRO_ANGLE), visible: false, pull: 0) }
        }
        placeCamera(t)
        audio.setDuck(Float(IntroTiming.duckGain(t)))   // 0.57 I3: music / bed −6 dB while the break hits
        camera.camera?.fieldOfView = baseFov + CGFloat(IntroTiming.fovDelta(t))   // 0.57 I1: −3° punch-in at the strike
        if t >= IntroTiming.logoStart && !logoShown { logoShown = true; showLogo(at: 0, duration: 0.45) }
        if t >= IntroTiming.logoEnd && !fadeStarted {
            fadeStarted = true
            UIView.animate(withDuration: Self.fullSeconds - IntroTiming.logoEnd) { self.overlay.alpha = 0 }
        }
        if t >= Self.fullSeconds { finish() }
    }

    private func placeCamera(_ t: Double) {
        let rack = ball(1), cue0 = SIMD3<Float>(Float(BL_INTRO_CUE_X), 0.028575, Float(BL_INTRO_CUE_Y))
        let d = SIMD3<Float>(Float(cos(BL_INTRO_ANGLE)), 0, Float(sin(BL_INTRO_ANGLE)))
        let side = SIMD3<Float>(-d.z, 0, d.x)
        let eye0 = cue0 - d * 0.55 + SIMD3(0, 0.07, 0) - side * 0.04, eye1 = cue0 - d * 0.55 + SIMD3(0, 0.09, 0) + side * 0.04   // the 8 cm slide
        var eye: SIMD3<Float>, look: SIMD3<Float>
        if t < IntroTiming.slideStart {   // low, close to the cloth, behind the cue ball
            eye = eye0; look = rack
        } else if t < IntroTiming.strike {   // slide 8 cm sideways while the cue draws back and strikes
            let k = Self.ease((t - IntroTiming.slideStart) / (IntroTiming.strike - IntroTiming.slideStart))
            eye = mix(eye0, eye1, k); look = rack
        } else if t < IntroTiming.dropWall(firstDrop: Double(BL_INTRO_FIRST_DROP_TIME)) {   // TV-style crane after the ball that drops
            let target = ball(Int(BL_INTRO_FIRST_DROP_BALL))
            let pocket = SIMD3<Float>(Float(BLFirstShotPocketX()), 0.03, Float(BLFirstShotPocketY()))
            let k = Self.ease((t - IntroTiming.strike) / 0.6)
            let followEye = target + simd_normalize(target - pocket + SIMD3(0.0001, 0, 0)) * 0.55 + SIMD3(0, 0.22, 0)
            eye = mix(eye1, followEye, k); look = mix(rack, target, k)
        } else {   // after the drop: crane up to the aiming view while the title appears
            let k = Self.ease((t - IntroTiming.dropWall(firstDrop: Double(BL_INTRO_FIRST_DROP_TIME))) / (IntroTiming.logoEnd - IntroTiming.dropWall(firstDrop: Double(BL_INTRO_FIRST_DROP_TIME))))
            let target = ball(Int(BL_INTRO_FIRST_DROP_BALL))
            let pocket = SIMD3<Float>(Float(BLFirstShotPocketX()), 0.03, Float(BLFirstShotPocketY()))
            let from = target + simd_normalize(target - pocket + SIMD3(0.0001, 0, 0)) * 0.55 + SIMD3(0, 0.22, 0)
            eye = mix(from, SIMD3(0, 3.0, 0.01), k); look = mix(target, SIMD3(0, 0, 0), k)
        }
        camera.simdPosition = eye + (fx?.shakeOffset() ?? .zero)
        camera.simdLook(at: look, up: SIMD3(0, 1, 0), localFront: SIMD3(0, 0, -1))
    }

    // 2D logo layer: gold particles converge into the Z logo + "ZOKER POOL", then a light sweep.
    private let tagline = UILabel()
    private func buildLogo() {
        logo.image = UIImage(named: "ZokerLogo043"); logo.contentMode = .scaleAspectFit; logo.alpha = 0
        logo.clipsToBounds = true
        title.text = "ZOKERVIE"; title.alpha = 0
        title.textColor = UIColor(red: 0.95, green: 0.78, blue: 0.38, alpha: 1)
        tagline.text = L10n.tr("Luyện mắt · tư duy · đường bi"); tagline.alpha = 0; tagline.textColor = UIColor(white: 0.9, alpha: 1)
        for v in [logo, title, tagline] { v.isUserInteractionEnabled = false; overlay.addSubview(v) }
        layoutLogo()
    }
    /// 0.57 I1: the first-launch title sits in the TOP-LEFT corner (never over the table); the short logo-only mode (2nd launch, reduced motion) stays centred.
    private func layoutLogo() {
        if mode == "full" {
            let side = min(overlay.bounds.width, overlay.bounds.height) * 0.16, left = overlay.safeAreaInsets.left + 22, top = overlay.safeAreaInsets.top + 18
            logo.frame = CGRect(x: left, y: top, width: side, height: side); logo.layer.cornerRadius = side * 0.16
            title.textAlignment = .left; title.font = UIFont(name: "AvenirNext-HeavyItalic", size: side * 0.34) ?? .systemFont(ofSize: side * 0.34, weight: .black)
            title.attributedText = NSAttributedString(string: "ZOKERVIE", attributes: [.kern: side * 0.04])
            title.frame = CGRect(x: logo.frame.maxX + 12, y: top + side * 0.1, width: overlay.bounds.width * 0.5, height: side * 0.45)
            tagline.textAlignment = .left; tagline.font = .systemFont(ofSize: max(11, side * 0.19), weight: .semibold)
            tagline.frame = CGRect(x: logo.frame.maxX + 12, y: title.frame.maxY, width: overlay.bounds.width * 0.5, height: side * 0.3)
        } else {
            let side = min(overlay.bounds.width, overlay.bounds.height) * 0.42
            logo.frame = CGRect(x: (overlay.bounds.width - side) / 2, y: overlay.bounds.height * 0.46 - side * 0.62, width: side, height: side); logo.layer.cornerRadius = side * 0.12
            title.textAlignment = .center; title.font = UIFont(name: "AvenirNext-HeavyItalic", size: side * 0.2) ?? .systemFont(ofSize: side * 0.2, weight: .black)
            title.attributedText = NSAttributedString(string: "ZOKERVIE", attributes: [.kern: side * 0.035])
            title.frame = CGRect(x: 0, y: logo.frame.maxY + side * 0.06, width: overlay.bounds.width, height: side * 0.26)
            tagline.frame = .zero
        }
    }
    private func showLogo(at delay: Double, duration: Double) {
        // gold particles that converge on the logo (short mode only: the first-launch film keeps ≤ 60 particles)
        if mode == "full" { UIView.animate(withDuration: duration) { self.logo.alpha = 1; self.title.alpha = 1; self.tagline.alpha = 1 }; return }
        let emitter = CAEmitterLayer(); emitter.emitterPosition = CGPoint(x: logo.frame.midX, y: logo.frame.midY)
        emitter.emitterShape = .circle; emitter.emitterMode = .outline; emitter.emitterSize = CGSize(width: logo.frame.width * 2.2, height: logo.frame.width * 2.2)
        let cell = CAEmitterCell()
        cell.contents = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in UIColor(red: 1, green: 0.84, blue: 0.45, alpha: 1).setFill(); UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 8, height: 8)).fill() }.cgImage
        cell.birthRate = 260; cell.lifetime = 0.55; cell.velocity = -logo.frame.width * 1.9; cell.scale = 0.5; cell.alphaSpeed = -0.6
        emitter.emitterCells = [cell]; overlay.layer.insertSublayer(emitter, below: logo.layer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { emitter.removeFromSuperlayer() }
        UIView.animate(withDuration: duration, delay: delay + (mode == "full" ? 0.3 : 0), options: [.curveEaseOut]) {
            self.logo.alpha = 1; self.title.alpha = 1
        }
        // light sweep across the logo
        let sweep = CAGradientLayer(); sweep.frame = logo.bounds.insetBy(dx: -logo.bounds.width, dy: 0)
        sweep.colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 0.55).cgColor, UIColor(white: 1, alpha: 0).cgColor]
        sweep.startPoint = CGPoint(x: 0, y: 0.3); sweep.endPoint = CGPoint(x: 1, y: 0.7); sweep.locations = [0.42, 0.5, 0.58]
        logo.layer.addSublayer(sweep)
        let move = CABasicAnimation(keyPath: "position.x"); move.fromValue = -logo.bounds.width; move.toValue = logo.bounds.width * 2
        move.beginTime = CACurrentMediaTime() + (mode == "full" ? 0.9 : 0.3); move.duration = 0.6; move.fillMode = .backwards
        sweep.add(move, forKey: "sweep"); sweep.position.x = logo.bounds.width * 2
    }

    // MARK: - 0.59 rendered film
    private func startFilm(_ url: URL) {
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = !(UserDefaults.standard.object(forKey: "poolAudioEnabled") as? Bool ?? true)
        p.actionAtItemEnd = .pause
        let layer = AVPlayerLayer(player: p); layer.frame = overlay.bounds; layer.videoGravity = .resizeAspectFill
        overlay.layer.insertSublayer(layer, above: shade.layer)
        logo.isHidden = true; title.isHidden = true
        player = p; playerLayer = layer
        filmEnd = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in self?.finish() }
        let begin = full ? CMTime.zero : CMTime(seconds: max(0, IntroFilm059.seconds - IntroFilm059.stingSeconds), preferredTimescale: 600)
        p.seek(to: begin, toleranceBefore: .zero, toleranceAfter: .zero) { [weak p] _ in p?.play() }
        // Never stuck: whatever happens to the film, the intro ends.
        DispatchQueue.main.asyncAfter(deadline: .now() + (full ? IntroFilm059.seconds : IntroFilm059.stingSeconds) + 2.0) { [weak self] in self?.finish() }
        // Never a black screen: no playable film within 0.8 s → the 2D logo plays instead.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self, weak item] in
            guard let self = self, !self.finished, self.mode == "video", item?.status != .readyToPlay else { return }
            self.stopFilm(); self.mode = "logo"; self.logo.isHidden = false; self.title.isHidden = false
            self.layoutLogo(); self.start = CACurrentMediaTime(); self.showLogo(at: 0, duration: 0.25)
            let l = CADisplayLink(target: self, selector: #selector(self.step)); l.add(to: .main, forMode: .common); self.link = l
        }
    }
    private func stopFilm() {
        player?.pause(); playerLayer?.removeFromSuperlayer()
        if let o = filmEnd { NotificationCenter.default.removeObserver(o) }
        filmEnd = nil; player = nil; playerLayer = nil
    }

    @objc func skip() {
        guard !finished else { return }
        if skipAt == 0 { skipAt = CACurrentMediaTime() }
        audio.stop(); haptics.stop()   // 0.57 I2: skipping stops the vibration at once
        UIView.animate(withDuration: 0.15, animations: { self.overlay.alpha = 0 }) { _ in self.finish() }
    }
    private func teardown3D() {
        guard let tc = tc else { return }
        fx?.removeAll(); camera.removeFromParentNode()
        tc.scn.pointOfView = tc.table.camera; tc.scn.rendersContinuously = false; tc.scn.isUserInteractionEnabled = true
        tc.table.showCue(nil, angle: 0, visible: false, pull: 0)
        world = nil; tc.introRunning = false
    }
    /// Exactly once, whatever ends the intro (timeline, tap, fallback).
    private(set) var finishCalls = 0
    func finish() {
        guard !finished, let tc = tc else { return }
        finishCalls += 1
        finished = true
        Self.lastWall = CACurrentMediaTime() - startedAt; Self.lastFilm = CACurrentMediaTime() - start; Self.lastMode = mode; if skipAt > 0 { Self.lastSkipMs = (CACurrentMediaTime() - skipAt) * 1000 }
        tc.introFinishCount += 1
        tc.publishIntroProbe()
        link?.invalidate(); link = nil
        stopFilm()   // 0.59
        audio.stop(); haptics.stop(); teardown3D()
        overlay.removeFromSuperview()
        hiddenByIntro.forEach { $0.isHidden = false }; hiddenByIntro = []
        tc.layoutHUDAfterIntro()
        onFinish?(self)
        let d = done; done = nil; d?()
    }
}

extension TrainingController {
    /// 0.58c (CI 172: testIntroPlaysBeforeLobbyAndTapSkips "finish ran exactly once" and testFirstLaunchIntroEndsWithin3Point5Seconds
    /// waiting 80 s for introMode). `finish()` runs once (guarded, and the intro is started once), but the full probe string is only
    /// rewritten by the next shot-loop tick, and while the intro owned the table the tick only refreshed flow/flowLog. On a slow runner
    /// the Lobby is up before that tick, so the test read the pre-intro `introDone=0` / no `introMode` for ever. The intro now writes its
    /// own keys into the probe at the moment it finishes (QA launches only), whatever the tick does next.
    func publishIntroProbe() {
        guard QA.has("--intro-lobby-qa") || QA.has("--visual-qa") || QA.has("--keep-lobby-qa") else { return }
        let keys = ["introDone", "introMode", "introFilm", "introWall", "introSkipMs"]
        let kept = (scn.accessibilityValue ?? "").components(separatedBy: ";").filter { part in !keys.contains { part.hasPrefix($0 + "=") } }
        let fresh = ["introDone=\(introFinishCount)", "introMode=\(IntroDirector0441.lastMode)",
                     "introFilm=\(String(format: "%.2f", IntroDirector0441.lastFilm))",
                     "introWall=\(String(format: "%.2f", IntroDirector0441.lastWall))",
                     "introSkipMs=\(Int(IntroDirector0441.lastSkipMs))"]
        scn.accessibilityValue = (kept + fresh).joined(separator: ";") + ";"
    }
    static let introSeenKey = Prefs.introSeen     // kept from 0.43 so a player who saw it does not see the long one again
    /// nil = no intro on this launch. First launch: the 6 s film; later: the ≤ 1.2 s logo. Setting `introEnabled043`
    /// (Tuỳ chỉnh) is respected. QA launches skip it except --intro-qa (probe) and --intro-lobby-qa (UI test).
    func makeIntro() -> IntroDirector0441? {
        // 0.45 M5.6: QA arguments via `QA` (compiled out of Release builds).
        let forced = QA.has("--intro-qa") || QA.has("--intro-lobby-qa") || QA.has("--intro-video-qa")
        if !forced && QA.anyQA { return nil }
        if QA.has("--fresh-intro") { UserDefaults.standard.removeObject(forKey: Prefs.introSeen) }
        guard forced || Prefs.flag(Prefs.introEnabled, true) else { return nil }
        let full = !QA.has("--intro-sting") && (QA.has("--intro-qa") || !UserDefaults.standard.bool(forKey: Prefs.introSeen))
        UserDefaults.standard.set(true, forKey: Prefs.introSeen)
        let director = IntroDirector0441(owner: self, full: full)
        if QA.has("--intro-qa") { director.startProbe() }
        return director
    }
}

extension IntroDirector0441 {
    /// --intro-qa: stills of the real screen (3D frame + the 2D layer) at 0.4 · 0.9 · 1.5 · 2.4 · 3.0 s (0.57 timeline), each needing mean luma
    /// ≥ 0.08 and ≥ 15 % of pixels brighter than 0.10, plus the longest frame of the intro. Documents/intro-qa/.
    func startProbe() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("intro-qa")
        try? FileManager.default.removeItem(at: dir); try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for t in [0.4, 0.9, 1.5, 2.4, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                guard let self = self, let image = self.probeImage() else { return }
                try? image.pngData()?.write(to: dir.appendingPathComponent(String(format: "intro-%.1fs.png", t)))
                let s = Self.brightness(image)
                self.probeStills.append(["t": t, "mean": s.mean, "lit": s.lit, "mode": self.mode, "pass": s.mean >= 0.08 && s.lit >= 0.15])
            }
        }
        onFinish = { director in
            let stills = director.probeStills
            let pass = stills.count == 5 && stills.allSatisfy { ($0["pass"] as? Bool) == true }
            let summary: [String: Any] = ["result": pass ? "PASS" : "FAIL", "stills": stills, "mode": director.mode,
                                          "maxFrameMs": director.maxFrameMs, "frames": director.frames, "finishCalls": director.finishCalls]
            if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: dir.appendingPathComponent("summary.json"))
            }
        }
    }
    /// What the player sees: the SceneKit frame with the 2D intro layer drawn on top.
    func probeImage() -> UIImage? {
        guard let tc = tcRef else { return nil }
        let base = tc.scn.snapshot(), size = tc.view.bounds.size
        return UIGraphicsImageRenderer(size: size).image { c in
            base.draw(in: CGRect(origin: .zero, size: size))
            overlayView.layer.render(in: c.cgContext)
        }
    }
    static func brightness(_ image: UIImage) -> (mean: Double, lit: Double) {
        guard let cg = image.cgImage else { return (0, 0) }
        let w = 160, h = max(1, 160 * cg.height / max(cg.width, 1))
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return (0, 0) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        var sum = 0.0, lit = 0
        for i in 0..<(w * h) { let y = (0.2126 * Double(px[i * 4]) + 0.7152 * Double(px[i * 4 + 1]) + 0.0722 * Double(px[i * 4 + 2])) / 255; sum += y; if y > 0.10 { lit += 1 } }
        return (sum / Double(w * h), Double(lit) / Double(w * h))
    }
}

/// 0.59 (đợt 1): intro C "Cú đánh hai băng" — Blender film 1920×1080 60 fps, 6.0 s, AAC stereo (Assets IntroFilmC059, 2.7 MB).
/// The data set is copied once into Caches so AVPlayer gets a file URL.
enum IntroFilm059 {
    static let seconds = 6.0, stingSeconds = 1.5
    static var wanted: Bool { !QA.anyQA || QA.has("--intro-video-qa") }
    static func url() -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dest = caches.appendingPathComponent("intro-c-059.mp4")
        if let size = try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 100_000 { return dest }
        guard let data = NSDataAsset(name: "IntroFilmC059")?.data, data.count > 100_000 else { return nil }
        do { try data.write(to: dest, options: .atomic); return dest } catch { return nil }
    }
}
