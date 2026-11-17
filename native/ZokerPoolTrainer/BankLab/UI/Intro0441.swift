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
        let s = SCNParticleSystem(); s.birthRate = 900; s.emissionDuration = 0.06; s.loops = false
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
    func pocketSparks(at p: SIMD3<Float>) {
        guard options.pocketSparks, let scene = scene else { return }
        let s = SCNParticleSystem(); s.birthRate = 700; s.emissionDuration = 0.12; s.loops = false
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
    func stop() { players.forEach { $0.stop() }; engine.stop() }
}

// MARK: - Director
final class IntroDirector0441 {
    static let fullSeconds = 6.0, stingSeconds = 1.2
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
    private var balls: [BallState] = []
    private(set) var mode = "none"   // "full" | "logo" (QA)
    private var hiddenByIntro: [UIView] = []
    var onFinish: ((IntroDirector0441) -> Void)?
    var probeStills: [[String: Any]] = []

    init(owner: TrainingController, full: Bool) { tc = owner; self.full = full }
    var tcRef: TrainingController? { tc }
    var overlayView: UIView { overlay }

    func run(done: @escaping () -> Void) {
        guard let tc = tc else { done(); return }
        self.done = done
        let reduce = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        mode = full && !reduce ? "full" : "logo"
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
        start = CACurrentMediaTime(); lastFrame = start
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
        camera.camera?.wantsDepthOfField = false; camera.camera?.motionBlurIntensity = 0; camera.camera?.bloomIntensity = 0
        tc.table.scene.rootNode.addChildNode(camera); tc.scn.pointOfView = camera
        tc.scn.rendersContinuously = true
        tc.scn.isUserInteractionEnabled = false   // touches during the fade never reach aim/camera gestures
        fx = ShotFX(scene: tc.table.scene, hostView: overlay)
        // The 3D must show a frame within 0.5 s, otherwise the 2D logo plays alone (never a black screen).
        let frames0 = tc.table.pacer.renderedFrames
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak tc] in
            guard let self = self, let tc = tc, !self.finished, self.mode == "full" else { return }
            if tc.table.pacer.renderedFrames <= frames0 { self.mode = "logo"; self.teardown3D(); self.start = CACurrentMediaTime() - 0; self.showLogo(at: 0, duration: 0.25) }
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
    static func simTime(wall t: Double) -> Double {
        let s = t - 1.6; if s <= 0 { return 0 }
        if s < 0.125 { return s }
        if s < 0.625 { return 0.125 + (s - 0.125) * 0.25 }
        return 0.25 + (s - 0.625)
    }

    @objc private func step(_ l: CADisplayLink) {
        guard let tc = tc, !finished else { return }
        let now = CACurrentMediaTime()
        let dtWall = now - lastFrame; lastFrame = now
        // A main-thread stall (cold shader compile, first frame on a new install) must not eat the film: the timeline
        // freezes while no frame is shown, so every beat is actually seen. Stalls still count in maxFrameMs.
        if dtWall > 0.1 { start += dtWall - 1.0 / 60 }
        let t = now - start
        if frames > 2 { maxFrameMs = max(maxFrameMs, dtWall * 1000) }; frames += 1
        if mode == "logo" {
            if t >= Self.stingSeconds { finish() }
            return
        }
        // shade = room lights coming up
        shade.alpha = CGFloat(max(0, 0.5 - t / 1.2))   // lights come up from half: never a black frame
        if let w = world {
            let target = Self.simTime(wall: t)
            if t >= 1.6 && !struck {
                struck = true
                w.strike(angle: Double(BL_INTRO_ANGLE), speed: Double(BL_INTRO_SPEED), side: 0, top: Double(BL_INTRO_TOP))
                let cue = ball(0)
                fx?.flash(); fx?.shockRing(at: cue); fx?.chalk(at: cue + SIMD3(-Float(cos(BL_INTRO_ANGLE)) * 0.03, 0, -Float(sin(BL_INTRO_ANGLE)) * 0.03)); fx?.shake()
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            if struck, target > simTime { w.advance(target - simTime); simTime = target }
            balls = w.ballStates
            tc.table.update(balls, dt: dtWall); tc.table.animatePockets(dtWall)
            fx?.streaks(balls.filter { !$0.sunk }.map { (id: $0.id, p: SIMD3(Float($0.x), 0.028575, Float($0.y))) }, dt: dtWall)
            if !dropped, simTime >= Double(BL_INTRO_FIRST_DROP_TIME) {
                dropped = true
                fx?.pocketSparks(at: SIMD3(Float(BLFirstShotPocketX()), 0.02, Float(BLFirstShotPocketY())))
            }
            // cue: draw back 0.6–1.45, stroke through to 1.6, gone after
            let cueBall = balls.first { $0.id == 0 }
            if t < 1.75 {
                let pull = t < 0.6 ? 0 : (t < 1.45 ? (t - 0.6) / 0.85 : max(0, 1 - (t - 1.45) / 0.15))
                tc.table.showCue(cueBall, angle: Double(BL_INTRO_ANGLE), visible: t >= 0.3, pull: pull)
            } else { tc.table.showCue(cueBall, angle: Double(BL_INTRO_ANGLE), visible: false, pull: 0) }
        }
        placeCamera(t)
        if t >= 3.6 && !logoShown { logoShown = true; showLogo(at: 0, duration: 0.6) }
        if t >= 5.2 && !fadeStarted {
            fadeStarted = true
            UIView.animate(withDuration: 0.8) { self.overlay.alpha = 0 }
        }
        if t >= Self.fullSeconds { finish() }
    }

    private func placeCamera(_ t: Double) {
        let rack = ball(1), cue0 = SIMD3<Float>(Float(BL_INTRO_CUE_X), 0.028575, Float(BL_INTRO_CUE_Y))
        let d = SIMD3<Float>(Float(cos(BL_INTRO_ANGLE)), 0, Float(sin(BL_INTRO_ANGLE)))
        var eye: SIMD3<Float>, look: SIMD3<Float>
        if t < 0.6 {   // low slide along the rail toward the rack
            let k = Self.ease(t / 0.6)
            eye = mix(SIMD3(-0.72, 0.10, -1.30), SIMD3(-0.62, 0.11, -0.25), k); look = mix(SIMD3(0, 0.03, 0), rack, k)
        } else if t < 1.75 {   // behind the cue ball, the cue drawing back
            let k = Self.ease((t - 0.6) / 0.4)
            eye = mix(SIMD3(-0.62, 0.11, -0.25), cue0 - d * 0.62 + SIMD3(0, 0.15, 0), k); look = mix(rack, rack, k)
        } else if t < 3.6 {   // follow the ball that drops
            let target = ball(Int(BL_INTRO_FIRST_DROP_BALL))
            let pocket = SIMD3<Float>(Float(BLFirstShotPocketX()), 0.03, Float(BLFirstShotPocketY()))
            let k = Self.ease((t - 1.75) / 0.6)
            let followEye = target + simd_normalize(target - pocket + SIMD3(0.0001, 0, 0)) * 0.55 + SIMD3(0, 0.22, 0)
            eye = mix(cue0 - d * 0.62 + SIMD3(0, 0.15, 0), followEye, k); look = mix(rack, target, k)
        } else {   // crane up to the top view
            let k = Self.ease((t - 3.6) / 1.4)
            let target = ball(Int(BL_INTRO_FIRST_DROP_BALL))
            let pocket = SIMD3<Float>(Float(BLFirstShotPocketX()), 0.03, Float(BLFirstShotPocketY()))
            let from = target + simd_normalize(target - pocket + SIMD3(0.0001, 0, 0)) * 0.55 + SIMD3(0, 0.22, 0)
            eye = mix(from, SIMD3(0, 3.0, 0.01), k); look = mix(target, SIMD3(0, 0, 0), k)
        }
        camera.simdPosition = eye + (fx?.shakeOffset() ?? .zero)
        camera.simdLook(at: look, up: SIMD3(0, 1, 0), localFront: SIMD3(0, 0, -1))
    }

    // 2D logo layer: gold particles converge into the Z logo + "ZOKER POOL", then a light sweep.
    private func buildLogo() {
        logo.image = UIImage(named: "ZokerLogo043"); logo.contentMode = .scaleAspectFit; logo.alpha = 0
        let side = min(overlay.bounds.width, overlay.bounds.height) * 0.42
        logo.frame = CGRect(x: (overlay.bounds.width - side) / 2, y: overlay.bounds.height * 0.46 - side * 0.62, width: side, height: side)
        logo.layer.cornerRadius = side * 0.12; logo.clipsToBounds = true
        title.text = "ZOKER POOL"; title.textAlignment = .center; title.alpha = 0
        title.font = UIFont(name: "AvenirNext-HeavyItalic", size: side * 0.2) ?? .systemFont(ofSize: side * 0.2, weight: .black)
        title.textColor = UIColor(red: 0.95, green: 0.78, blue: 0.38, alpha: 1)
        title.attributedText = NSAttributedString(string: "ZOKER POOL", attributes: [.kern: side * 0.035])
        title.frame = CGRect(x: 0, y: logo.frame.maxY + side * 0.06, width: overlay.bounds.width, height: side * 0.26)
        for v in [logo, title] { v.isUserInteractionEnabled = false; overlay.addSubview(v) }
    }
    private func showLogo(at delay: Double, duration: Double) {
        // gold particles that converge on the logo
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

    @objc func skip() {
        guard !finished else { return }
        audio.stop()
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
        tc.introFinishCount += 1
        link?.invalidate(); link = nil
        audio.stop(); teardown3D()
        overlay.removeFromSuperview()
        hiddenByIntro.forEach { $0.isHidden = false }; hiddenByIntro = []
        tc.layoutHUDAfterIntro()
        onFinish?(self)
        let d = done; done = nil; d?()
    }
}

extension TrainingController {
    static let introSeenKey = "intro043Seen"     // kept from 0.43 so a player who saw it does not see the long one again
    /// nil = no intro on this launch. First launch: the 6 s film; later: the ≤ 1.2 s logo. Setting `introEnabled043`
    /// (Tuỳ chỉnh) is respected. QA launches skip it except --intro-qa (probe) and --intro-lobby-qa (UI test).
    func makeIntro() -> IntroDirector0441? {
        let args = ProcessInfo.processInfo.arguments
        let forced = args.contains("--intro-qa") || args.contains("--intro-lobby-qa")
        if !forced && args.contains(where: { $0.hasPrefix("--") && $0.hasSuffix("qa") }) { return nil }
        if args.contains("--fresh-intro") { UserDefaults.standard.removeObject(forKey: Self.introSeenKey) }
        guard forced || (UserDefaults.standard.object(forKey: "introEnabled043") as? Bool ?? true) else { return nil }
        let full = !args.contains("--intro-sting") && (args.contains("--intro-qa") || !UserDefaults.standard.bool(forKey: Self.introSeenKey))
        UserDefaults.standard.set(true, forKey: Self.introSeenKey)
        let director = IntroDirector0441(owner: self, full: full)
        if args.contains("--intro-qa") { director.startProbe() }
        return director
    }
}

extension IntroDirector0441 {
    /// --intro-qa: stills of the real screen (3D frame + the 2D layer) at 0.5 · 1 · 2 · 3 · 4.5 s, each needing mean luma
    /// ≥ 0.08 and ≥ 15 % of pixels brighter than 0.10, plus the longest frame of the intro. Documents/intro-qa/.
    func startProbe() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("intro-qa")
        try? FileManager.default.removeItem(at: dir); try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for t in [0.5, 1.0, 2.0, 3.0, 4.5] {
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
