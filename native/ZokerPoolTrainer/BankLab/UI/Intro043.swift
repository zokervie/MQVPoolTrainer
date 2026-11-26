import UIKit
import SceneKit
import AVFoundation

/// 0.43 — brand intro "THE GOLDEN BREAK" (owner brief 14/11). Built IN the app with SceneKit, not a video: the balls move
/// by closed-form physics (stun → stop shot, object ball slides then rolls, rolling resistance), the number faces the
/// viewer because the ball rolls about the camera axis, and the logo is the official image composited flat (no
/// re-drawn letters). Full 5.6 s on the first launch, a 1 s sting afterwards; tap to skip; silent when the app sound
/// is off. Sound is synthesised here (TEMPORARY until the owner's own recordings).
final class IntroOverlay: UIView, SCNSceneRendererDelegate {
    static let seenKey = "intro043Seen"
    /// Called once after the window is shown.
    static func present(in window: UIWindow) {
        let args = ProcessInfo.processInfo.arguments
        let qa = args.contains("--intro-qa") || args.contains("--old-intro-qa")
        if !qa && (args.contains("--visual-qa") || args.contains("--g1-default-qa") || args.contains("--keep-lobby-qa")) { return }
        guard qa || (UserDefaults.standard.object(forKey: "introEnabled043") as? Bool ?? true) else { return }
        let full = qa || !UserDefaults.standard.bool(forKey: seenKey)
        let overlay = IntroOverlay(frame: window.bounds, full: full && !args.contains("--intro-sting"))
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(overlay)
        UserDefaults.standard.set(true, forKey: seenKey)
        overlay.begin()
    }

    private let full: Bool
    private let scn = SCNView()
    private let scene = SCNScene()
    private let cueBall = SCNNode(), nine = SCNNode(), cue = SCNNode(), camera = SCNNode(), sweep = SCNNode(), ring = SCNNode()
    private var startTime: CFTimeInterval = 0
    private var finished = false
    private let logoView = UIImageView(), title = UILabel(), shade = UIView()
    // Closed-form shot (metres, seconds of SIMULATED time from the tip contact).
    private let R: Float = 0.028575
    private let cueStart: Float = -0.18, cueSpeed: Float = 0.48, cueDecel: Float = 0.35
    private var impactSim: Float = 0
    private var nineSamples: [(x: Float, angle: Float)] = []   // every 1/240 s after the impact
    private let strikeReal: Double = 1.5
    // 0.44 (owner item 12: "intro còn sơ xài — VFX, SFX chuyên nghiệp, lả lướt hơn")
    private let beam = SCNNode(), rim = SCNNode()
    private var sparksFired = false

    init(frame: CGRect, full: Bool) {
        self.full = full
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1)
        accessibilityIdentifier = "IntroOverlay"
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(skip)))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Setup
    private func begin() {
        if full { buildScene(); solveShot() }
        buildLogo()
        IntroSound.shared.play(full: full)
        startTime = CACurrentMediaTime()
        if full {
            scn.frame = bounds; scn.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            scn.scene = scene; scn.backgroundColor = backgroundColor; scn.antialiasingMode = .multisampling4X
            scn.pointOfView = camera; scn.delegate = self; scn.isPlaying = true; scn.preferredFramesPerSecond = 60
            scn.isUserInteractionEnabled = false
            insertSubview(scn, at: 0)
            schedule(3.05) { [weak self] in self?.goldConverge() }
            schedule(4.45) { [weak self] in self?.showLogo(duration: 0.45) }
            schedule(5.55) { [weak self] in self?.finish() }
        } else {
            schedule(0.0) { [weak self] in self?.showLogo(duration: 0.22) }
            schedule(1.0) { [weak self] in self?.finish() }
        }
    }
    private func schedule(_ t: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
            guard let self = self, !self.finished else { return }; work()
        }
    }

    private func buildScene() {
        // Night-blue felt, low key light; a spot sweeps the cloth in the first second.
        let felt = SCNMaterial(); felt.lightingModel = .physicallyBased
        felt.diffuse.contents = UIColor(red: 0.035, green: 0.075, blue: 0.16, alpha: 1); felt.roughness.contents = 0.95
        let bed = SCNNode(geometry: SCNPlane(width: 4, height: 4)); bed.geometry?.materials = [felt]
        bed.eulerAngles.x = -.pi / 2; scene.rootNode.addChildNode(bed)
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 60
        ambient.light?.color = UIColor(red: 0.55, green: 0.62, blue: 0.85, alpha: 1); scene.rootNode.addChildNode(ambient)
        sweep.light = SCNLight(); sweep.light?.type = .spot; sweep.light?.intensity = 0; sweep.light?.temperature = 4300
        sweep.light?.spotInnerAngle = 18; sweep.light?.spotOuterAngle = 42; sweep.light?.castsShadow = true
        sweep.light?.shadowRadius = 6; sweep.light?.shadowColor = UIColor(white: 0, alpha: 0.55)
        sweep.position = SCNVector3(-0.6, 1.1, 0.15); scene.rootNode.addChildNode(sweep)
        let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional; key.light?.intensity = 420
        key.light?.temperature = 5200; key.eulerAngles = SCNVector3(-1.1, 0.35, 0); scene.rootNode.addChildNode(key)
        // Balls
        cueBall.geometry = SCNSphere(radius: CGFloat(R)); (cueBall.geometry as? SCNSphere)?.segmentCount = 64
        cueBall.geometry?.materials = [ballMaterial(UIImage(), base: UIColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1))]
        cueBall.position = SCNVector3(cueStart, R, 0); scene.rootNode.addChildNode(cueBall)
        nine.geometry = SCNSphere(radius: CGFloat(R)); (nine.geometry as? SCNSphere)?.segmentCount = 64
        nine.geometry?.materials = [ballMaterial(Self.nineStripe(), base: .white)]
        nine.position = SCNVector3(0, R, 0); scene.rootNode.addChildNode(nine)
        // Number discs on the stripe, both sides (real stripe balls), facing ±z = the camera axis.
        for sign: Float in [1, -1] {
            let disc = SCNNode(geometry: SCNPlane(width: CGFloat(R) * 0.98, height: CGFloat(R) * 0.98))
            let m = SCNMaterial(); m.diffuse.contents = Self.numberDisc(); m.lightingModel = .physicallyBased
            m.roughness.contents = 0.18; m.transparencyMode = .aOne; disc.geometry?.materials = [m]
            disc.position = SCNVector3(0, 0, sign * R * 0.985); if sign < 0 { disc.eulerAngles.y = .pi }
            nine.addChildNode(disc)
        }
        // Cue: tapered shaft, white ferrule, blue tip, along +x.
        let shaftMat = SCNMaterial(); shaftMat.lightingModel = .physicallyBased
        shaftMat.diffuse.contents = UIColor(red: 0.86, green: 0.74, blue: 0.52, alpha: 1); shaftMat.roughness.contents = 0.35
        let shaft = SCNNode(geometry: SCNCone(topRadius: 0.0062, bottomRadius: 0.0145, height: 1.30)); shaft.geometry?.materials = [shaftMat]
        shaft.eulerAngles.z = .pi / 2; shaft.position = SCNVector3(-0.65 - 0.026, 0, 0)
        let ferrule = SCNNode(geometry: SCNCylinder(radius: 0.0062, height: 0.022)); ferrule.eulerAngles.z = .pi / 2
        ferrule.position = SCNVector3(-0.015, 0, 0); ferrule.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.95, alpha: 1)
        let tip = SCNNode(geometry: SCNCylinder(radius: 0.0062, height: 0.008)); tip.eulerAngles.z = .pi / 2
        tip.position = SCNVector3(-0.004, 0, 0); tip.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.18, green: 0.36, blue: 0.62, alpha: 1)
        for n in [shaft, ferrule, tip] { cue.addChildNode(n) }
        cue.eulerAngles.z = 0.06   // butt slightly raised, tip on the ball's centre line
        scene.rootNode.addChildNode(cue)
        // Gold ring that spreads on the cloth at the impact.
        let ringPlane = SCNPlane(width: 1, height: 1); let rm = SCNMaterial(); rm.diffuse.contents = Self.ringImage()
        rm.lightingModel = .constant; rm.blendMode = .add; rm.writesToDepthBuffer = false; ringPlane.materials = [rm]
        ring.geometry = ringPlane; ring.eulerAngles.x = -.pi / 2; ring.position = SCNVector3(-R, 0.0008, 0); ring.opacity = 0
        ring.scale = SCNVector3(0.02, 0.02, 0.02); scene.rootNode.addChildNode(ring)
        // Low camera on the +z side, the number axis.
        camera.camera = SCNCamera(); camera.camera?.fieldOfView = 34; camera.camera?.zNear = 0.01
        camera.camera?.wantsHDR = true; camera.camera?.bloomIntensity = 0.6; camera.camera?.bloomThreshold = 0.85
        camera.camera?.wantsDepthOfField = true; camera.camera?.focusDistance = 0.42; camera.camera?.fStop = 2.8
        camera.position = SCNVector3(-0.08, 0.075, 0.42); camera.look(at: SCNVector3(-0.05, R, 0))
        scene.rootNode.addChildNode(camera)
        // 0.44 cinematic lens: motion blur on the strike, soft vignette, warmer bloom, a hint of chromatic fringe.
        camera.camera?.motionBlurIntensity = 0.45; camera.camera?.vignettingIntensity = 0.9; camera.camera?.vignettingPower = 1.2
        camera.camera?.bloomIntensity = 0.9; camera.camera?.bloomThreshold = 0.78; camera.camera?.bloomBlurRadius = 10
        camera.camera?.colorFringeStrength = 0.6; camera.camera?.colorFringeIntensity = 0.25
        camera.camera?.contrast = 0.12; camera.camera?.saturation = 1.06
        // 0.44.1 investigation (-oldIntroNoPost YES): the same intro with every post effect off.
        if UserDefaults.standard.bool(forKey: "oldIntroNoPost") {
            camera.camera?.wantsHDR = false; camera.camera?.bloomIntensity = 0; camera.camera?.wantsDepthOfField = false
            camera.camera?.motionBlurIntensity = 0; camera.camera?.colorFringeStrength = 0; camera.camera?.vignettingIntensity = 0
        }
        // Reflections: a studio gradient (warm key, navy fill) so the lacquered balls carry real highlights.
        scene.lightingEnvironment.contents = Self.studioEnvironment(); scene.lightingEnvironment.intensity = 0.9
        // Gold rim from behind the 9-ball — the brand colour lives on the ball's edge.
        rim.light = SCNLight(); rim.light?.type = .spot; rim.light?.color = UIColor(red: 1, green: 0.78, blue: 0.36, alpha: 1)
        rim.light?.intensity = 900; rim.light?.spotInnerAngle = 10; rim.light?.spotOuterAngle = 34
        rim.position = SCNVector3(0.25, 0.18, -0.55); rim.look(at: SCNVector3(0, R, 0)); scene.rootNode.addChildNode(rim)
        // Visible light beam of the sweeping spot (additive cone, fades at its ends) with drifting dust.
        let cone = SCNCone(topRadius: 0.01, bottomRadius: 0.36, height: 1.1); cone.radialSegmentCount = 48
        let bm = SCNMaterial(); bm.lightingModel = .constant; bm.blendMode = .add; bm.writesToDepthBuffer = false; bm.isDoubleSided = true
        bm.diffuse.contents = Self.beamGradient(); bm.transparency = 0.22; cone.materials = [bm]
        beam.geometry = cone; beam.opacity = 0; scene.rootNode.addChildNode(beam)
        let dust = SCNParticleSystem(); dust.birthRate = 26; dust.particleLifeSpan = 3.2; dust.particleSize = 0.0016
        dust.particleColor = UIColor(red: 1, green: 0.92, blue: 0.75, alpha: 0.55); dust.blendMode = .additive
        dust.emitterShape = SCNBox(width: 0.7, height: 0.6, length: 0.4, chamferRadius: 0); dust.particleVelocity = 0.01
        dust.particleVelocityVariation = 0.01; dust.isAffectedByGravity = false; dust.particleColorVariation = SCNVector4(0, 0, 0, 0.4)
        let dustNode = SCNNode(); dustNode.position = SCNVector3(-0.05, 0.3, 0); dustNode.addParticleSystem(dust); scene.rootNode.addChildNode(dustNode)
    }
    /// Gold sparks and a soft flash at the moment of impact (fired once, from the render loop).
    private func impactSparks(at point: SCNVector3) {
        let sparks = SCNParticleSystem(); sparks.birthRate = 2200; sparks.emissionDuration = 0.06; sparks.loops = false
        sparks.particleLifeSpan = 0.55; sparks.particleLifeSpanVariation = 0.25; sparks.particleSize = 0.0022; sparks.particleSizeVariation = 0.0012
        sparks.particleColor = UIColor(red: 1, green: 0.80, blue: 0.34, alpha: 1); sparks.blendMode = .additive
        sparks.particleVelocity = 0.55; sparks.particleVelocityVariation = 0.35; sparks.spreadingAngle = 70
        sparks.emittingDirection = SCNVector3(0, 1, 0.6); sparks.acceleration = SCNVector3(0, -1.2, 0); sparks.dampingFactor = 1.5
        sparks.stretchFactor = 0.012
        let fade = CAKeyframeAnimation(); fade.values = [1, 1, 0]; fade.keyTimes = [0, 0.6, 1]
        sparks.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        let node = SCNNode(); node.position = point; node.addParticleSystem(sparks); scene.rootNode.addChildNode(node)
        let flash = SCNNode(); flash.light = SCNLight(); flash.light?.type = .omni; flash.light?.color = UIColor(red: 1, green: 0.82, blue: 0.45, alpha: 1)
        flash.light?.intensity = 1600; flash.light?.attenuationEndDistance = 0.5; flash.position = SCNVector3(point.x, point.y + 0.04, point.z + 0.05)
        scene.rootNode.addChildNode(flash)
        flash.runAction(.customAction(duration: 0.45) { node, t in node.light?.intensity = 1600 * (1 - t / 0.45) })
    }
    private static func studioEnvironment() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 512, height: 256)).image { ctx in
            let colors = [UIColor(red: 0.95, green: 0.82, blue: 0.55, alpha: 1).cgColor, UIColor(red: 0.10, green: 0.14, blue: 0.28, alpha: 1).cgColor,
                          UIColor(red: 0.01, green: 0.02, blue: 0.05, alpha: 1).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 1]) {
                ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
            }
            UIColor(white: 1, alpha: 0.9).setFill(); ctx.cgContext.fillEllipse(in: CGRect(x: 180, y: 20, width: 90, height: 34))   // softbox
        }
    }
    private static func beamGradient() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 256)).image { ctx in
            for y in 0..<256 { let v = Double(y) / 255; let a = sin(v * .pi) * 0.9
                UIColor(red: 1, green: 0.88, blue: 0.62, alpha: CGFloat(a)).setFill(); ctx.fill(CGRect(x: 0, y: y, width: 4, height: 1)) }
        }
    }
    private func ballMaterial(_ image: UIImage, base: UIColor) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .physicallyBased
        m.diffuse.contents = image.size.width > 0 ? image : base
        m.roughness.contents = 0.12; m.metalness.contents = 0.0; m.clearCoat.contents = 1.0; m.clearCoatRoughness.contents = 0.04
        return m
    }
    /// Equirectangular 9-ball: white caps, yellow stripe on the equator of the y axis.
    private static func nineStripe() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 512)).image { ctx in
            UIColor(red: 0.97, green: 0.96, blue: 0.92, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 512))
            UIColor(red: 0.98, green: 0.76, blue: 0.05, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 512 * 0.30, width: 1024, height: 512 * 0.40))
        }
    }
    private static func numberDisc() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { ctx in
            let r = CGRect(x: 0, y: 0, width: 256, height: 256)
            UIColor.clear.setFill(); ctx.fill(r)
            UIColor(red: 0.97, green: 0.96, blue: 0.92, alpha: 1).setFill(); ctx.cgContext.fillEllipse(in: r.insetBy(dx: 52, dy: 52))
            let style = NSMutableParagraphStyle(); style.alignment = .center
            let font = UIFont(name: "AvenirNext-Bold", size: 108) ?? UIFont.systemFont(ofSize: 108, weight: .bold)
            ("9" as NSString).draw(in: CGRect(x: 0, y: 128 - font.lineHeight / 2, width: 256, height: font.lineHeight),
                                   withAttributes: [.font: font, .foregroundColor: UIColor.black, .paragraphStyle: style])
        }
    }
    private static func ringImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256)).image { ctx in
            let colors = [UIColor(red: 1, green: 0.78, blue: 0.3, alpha: 0).cgColor, UIColor(red: 1, green: 0.78, blue: 0.3, alpha: 0.9).cgColor,
                          UIColor(red: 1, green: 0.78, blue: 0.3, alpha: 0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.78, 0.9, 1.0]) {
                ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 128, y: 128), startRadius: 0, endCenter: CGPoint(x: 128, y: 128), endRadius: 128, options: [])
            }
        }
    }

    /// Stun stop shot, then the 9-ball: sliding (μs 0.20) until it rolls (5/7 of its speed), then rolling resistance
    /// (0.12 m/s², Mathavan 2009) to rest. Same coefficients as the game; e 0.94 between the balls.
    private func solveShot() {
        let dist = -2 * R - cueStart   // centre x where the balls touch is -2R
        // x = v t - a t²/2 = dist
        let disc = cueSpeed * cueSpeed - 2 * cueDecel * dist
        impactSim = (cueSpeed - sqrt(max(0, disc))) / cueDecel
        let vAt = cueSpeed - cueDecel * impactSim
        var v = 0.94 * vAt, w: Float = 0, x: Float = 0, angle: Float = 0
        let mu: Float = 0.20 * 9.81, roll: Float = 0.12, dt: Float = 1.0 / 240
        nineSamples = [(0, 0)]
        for _ in 0..<(240 * 5) {
            if v - w * R > 1e-4 {           // sliding: friction slows v and spins the ball up
                v -= mu * dt; w += 2.5 * mu / R * dt
                if w * R >= v { w = v / R }   // natural roll reached (5/7 of the start speed)
            } else { v = max(0, v - roll * dt); w = v / R }
            x += v * dt; angle -= w * dt
            nineSamples.append((x, angle))
            if v <= 0 { break }
        }
        // number upright when the ball stops: pre-rotate by the final roll angle
        if let last = nineSamples.last { nine.eulerAngles.z = -last.angle }
    }
    /// Real seconds since the strike → simulated seconds (0.25× slow motion around the impact).
    private func simTime(_ real: Double) -> Float {
        let r = Float(real - strikeReal), a: Float = max(0, impactSim - 0.06), b: Float = 0.42
        if r <= a { return r }
        if r <= a + b { return a + (r - a) * 0.25 }
        return a + b * 0.25 + (r - a - b)
    }

    // MARK: - Per frame (SceneKit render thread)
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard full else { return }
        let t = CACurrentMediaTime() - startTime
        // 0–1.1 s: the spot sweeps across and settles on the balls
        let sweepT = Float(min(1, t / 1.1))
        sweep.position = SCNVector3(-0.6 + 0.62 * smooth(sweepT), 1.1, 0.15)
        sweep.look(at: SCNVector3(-0.25 + 0.27 * smooth(sweepT), 0, 0))
        sweep.light?.intensity = CGFloat(1600 * smooth(min(1, Float(t) / 0.6)))
        // the beam hangs from the spot to its target; strongest in the first second, then a faint haze
        let target = SCNVector3(-0.25 + 0.27 * smooth(sweepT), 0, 0)
        beam.position = SCNVector3((sweep.position.x + target.x) / 2, (sweep.position.y + target.y) / 2, (sweep.position.z + target.z) / 2)
        beam.look(at: sweep.position, up: SCNVector3(1, 0, 0), localFront: SCNVector3(0, 1, 0))
        beam.opacity = CGFloat(0.9 * smooth(min(1, Float(t) / 0.5)) * (t < 1.4 ? 1 : max(0.25, 1 - Float(t - 1.4) / 1.2)))
        // cue: approach (1.0–1.25), pause, stroke (1.40–1.50), follow-through
        let gapTip: Float
        if t < 1.0 { gapTip = 0.16 } else if t < 1.25 { gapTip = 0.16 - 0.14 * smooth(Float((t - 1.0) / 0.25)) }
        else if t < 1.40 { gapTip = 0.02 } else if t < strikeReal { gapTip = 0.02 * (1 - Float((t - 1.40) / 0.10)) }
        else { gapTip = -min(0.05, Float(t - strikeReal) * 0.5) }
        let s = simTime(t)
        let cueX: Float = t < strikeReal ? cueStart : (s < impactSim ? cueStart + cueSpeed * s - 0.5 * cueDecel * s * s : -2 * R)
        cue.position = SCNVector3(cueStart - R - gapTip, R + 0.004, 0)   // the cue node's origin is the tip
        cue.opacity = CGFloat(t < 2.4 ? 1 : max(0, 1 - (t - 2.4) / 0.5))
        cueBall.position = SCNVector3(cueX, R, 0)
        if t >= strikeReal && s >= impactSim {
            let k = Int((s - impactSim) * 240)
            let sample = nineSamples[min(max(0, k), nineSamples.count - 1)]
            nine.position = SCNVector3(sample.x, R, 0)
            nine.eulerAngles.z = -(nineSamples.last?.angle ?? 0) + sample.angle
            if !sparksFired {
                sparksFired = true
                let hit = SCNVector3(-R, R, 0)
                DispatchQueue.main.async { [weak self] in self?.impactSparks(at: hit) }
            }
            // gold ring
            let age = s - impactSim
            ring.opacity = CGFloat(max(0, 0.9 - age * 1.6)); let sc = 0.02 + age * 0.9; ring.scale = SCNVector3(sc, sc, sc)
        }
        // camera drifts with the 9-ball, keeps it centred, slight push-in
        let follow = max(-0.05, min(nine.position.x, 0.42))
        // 0.44: after the impact the camera glides on a slow arc (≈ 20°) around the 9-ball instead of a straight drift
        let arc = Float(t > strikeReal ? smooth(Float((t - strikeReal) / 2.6)) : 0) * 0.35
        let radius: Float = 0.40 - 0.05 * Float(min(1, t / 5))
        camera.position = SCNVector3(follow - 0.03 + sin(arc) * radius, 0.07 - 0.012 * Float(min(1, t / 5)) + arc * 0.02, cos(arc) * radius)
        camera.look(at: SCNVector3(follow, R, 0))
        let dx = camera.position.x - follow, dy = camera.position.y - R, dz = camera.position.z
        camera.camera?.focusDistance = CGFloat(sqrt(dx * dx + dy * dy + dz * dz))
    }
    private func smooth(_ x: Float) -> Float { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }

    // MARK: - Gold streaks → Z, then the logo
    private func goldConverge() {
        let p = scn.projectPoint(nine.presentation.position)
        let from = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        let side = min(bounds.width, bounds.height) * 0.42
        let logoFrame = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2 - side * 0.12, width: side, height: side)
        // Z stroke points (unit square, same proportions as the logo's Z)
        let z: [CGPoint] = [CGPoint(x: 0.10, y: 0.12), CGPoint(x: 0.92, y: 0.12), CGPoint(x: 0.08, y: 0.86), CGPoint(x: 0.70, y: 0.86)]
        // 0.44: 220 motes on curved paths (each its own arc), sizes 1.5–6 pt, staggered, then a sparkle burst on the Z.
        for i in 0..<220 {
            let seg = i % 3, u = CGFloat((i * 37) % 220) / 220
            let a = z[seg], b = z[seg + 1]
            let target = CGPoint(x: logoFrame.minX + (a.x + (b.x - a.x) * u) * side, y: logoFrame.minY + (a.y + (b.y - a.y) * u) * side)
            let dot = CALayer(); let r = CGFloat(2 + (i % 4))
            dot.bounds = CGRect(x: 0, y: 0, width: r, height: r); dot.cornerRadius = r / 2
            dot.backgroundColor = UIColor(red: 1, green: 0.80, blue: 0.32, alpha: 1).cgColor
            dot.shadowColor = dot.backgroundColor; dot.shadowOpacity = 1; dot.shadowRadius = 4; dot.shadowOffset = .zero
            let start = CGPoint(x: from.x - CGFloat(i % 9) * 6 - 10, y: from.y + CGFloat((i * 13) % 21) - 10)
            dot.position = target; layer.addSublayer(dot)
            let path = UIBezierPath(); path.move(to: start)
            let bend = CGFloat((i * 53) % 160) - 80
            path.addCurve(to: target, controlPoint1: CGPoint(x: start.x + (target.x - start.x) * 0.3, y: start.y - 120 + bend),
                          controlPoint2: CGPoint(x: target.x - bend * 0.6, y: target.y + bend * 0.5))
            let move = CAKeyframeAnimation(keyPath: "position"); move.path = path.cgPath
            move.duration = 0.95 + Double(i % 11) * 0.035; move.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.0, 0.2, 1.0)
            move.beginTime = CACurrentMediaTime() + Double(i % 13) * 0.012; move.fillMode = .backwards
            dot.add(move, forKey: "in")
            let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 1; fade.toValue = 0; fade.beginTime = CACurrentMediaTime() + 1.35
            fade.duration = 0.3; fade.fillMode = .forwards; fade.isRemovedOnCompletion = false; dot.add(fade, forKey: "out")
        }
    }
    /// Sparkle burst along the Z as the logo lands.
    private func zSparkle(in frame: CGRect) {
        let emitter = CAEmitterLayer(); emitter.emitterPosition = CGPoint(x: frame.midX, y: frame.midY)
        emitter.emitterShape = .rectangle; emitter.emitterSize = CGSize(width: frame.width * 0.8, height: frame.height * 0.7); emitter.renderMode = .additive
        let cell = CAEmitterCell(); cell.contents = Self.sparkImage().cgImage; cell.birthRate = 140; cell.lifetime = 0.9; cell.lifetimeRange = 0.4
        cell.scale = 0.12; cell.scaleRange = 0.08; cell.scaleSpeed = -0.1; cell.alphaSpeed = -1.1; cell.velocity = 18; cell.velocityRange = 14
        cell.emissionRange = .pi * 2; cell.color = UIColor(red: 1, green: 0.85, blue: 0.45, alpha: 1).cgColor
        emitter.emitterCells = [cell]; layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { emitter.removeFromSuperlayer() }
    }
    private static func sparkImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0, endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
            }
            UIColor.white.setFill(); ctx.fill(CGRect(x: 31, y: 4, width: 2, height: 56)); ctx.fill(CGRect(x: 4, y: 31, width: 56, height: 2))
        }
    }
    private func buildLogo() {
        shade.frame = bounds; shade.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shade.backgroundColor = UIColor(red: 0.02, green: 0.03, blue: 0.07, alpha: 1); shade.alpha = 0; addSubview(shade)
        // 0.44: navy radial backdrop with a warm centre instead of a flat panel
        let glow = CAGradientLayer(); glow.type = .radial; glow.frame = bounds
        glow.colors = [UIColor(red: 0.16, green: 0.12, blue: 0.06, alpha: 1).cgColor, UIColor(red: 0.02, green: 0.03, blue: 0.07, alpha: 1).cgColor]
        glow.startPoint = CGPoint(x: 0.5, y: 0.45); glow.endPoint = CGPoint(x: 1.1, y: 1.1); shade.layer.addSublayer(glow)
        logoView.image = UIImage(named: "ZokerLogo043"); logoView.contentMode = .scaleAspectFit; logoView.alpha = 0
        logoView.layer.cornerRadius = 18; logoView.clipsToBounds = true; addSubview(logoView)
        title.text = "ZOKERVIE"; title.textAlignment = .center; title.alpha = 0
        title.font = UIFont(name: "AvenirNext-HeavyItalic", size: 34) ?? UIFont.systemFont(ofSize: 34, weight: .black)
        title.textColor = UIColor(red: 0.95, green: 0.78, blue: 0.36, alpha: 1)
        title.attributedText = NSAttributedString(string: "ZOKERVIE", attributes: [.kern: 6, .font: title.font as Any, .foregroundColor: title.textColor as Any])
        addSubview(title)
        let side = min(bounds.width, bounds.height) * 0.42
        logoView.frame = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2 - side * 0.12, width: side, height: side)
        title.frame = CGRect(x: 0, y: logoView.frame.maxY + 10, width: bounds.width, height: 44)
    }
    private func showLogo(duration: Double) {
        logoView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut]) {
            self.shade.alpha = self.full ? 0.92 : 1; self.logoView.alpha = 1; self.logoView.transform = .identity; self.title.alpha = 1
        }
        // light glides across the Z
        let gloss = CAGradientLayer(); gloss.frame = logoView.bounds
        gloss.colors = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 0.55).cgColor, UIColor(white: 1, alpha: 0).cgColor]
        gloss.locations = [0.35, 0.5, 0.65]; gloss.startPoint = CGPoint(x: 0, y: 0.2); gloss.endPoint = CGPoint(x: 1, y: 0.8)
        logoView.layer.addSublayer(gloss)
        if full { DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.7) { [weak self] in guard let self = self else { return }; self.zSparkle(in: self.logoView.frame) } }
        let move = CABasicAnimation(keyPath: "locations"); move.fromValue = [-0.3, -0.15, 0.0]; move.toValue = [1.0, 1.15, 1.3]
        move.duration = full ? 0.9 : 0.6; move.beginTime = CACurrentMediaTime() + duration * 0.6; move.fillMode = .backwards
        gloss.add(move, forKey: "sweep"); gloss.locations = [1.0, 1.15, 1.3]
    }
    @objc private func skip() { IntroSound.shared.stop(); finish() }
    private func finish() {
        guard !finished else { return }; finished = true
        UIView.animate(withDuration: 0.35, animations: { self.alpha = 0 }) { _ in
            self.scn.isPlaying = false; self.scn.delegate = nil; self.removeFromSuperview()
        }
    }
}

/// Synthesised intro sound (TEMPORARY — replace with the owner's recordings): room tone, chalk, cue tip, the ball
/// click with a short low thump, rolling that turns into a warm metallic shimmer, and the "tách — ting" brand mark.
/// Stereo but mono-safe (the same events in both channels, only the shimmer is detuned ±1.5 Hz). Peak ≤ 0.8.
final class IntroSound {
    static let shared = IntroSound()
    private let engine = AVAudioEngine(), player = AVAudioPlayerNode()
    private var ready = false
    func play(full: Bool) {
        guard UserDefaults.standard.object(forKey: "poolAudioEnabled") as? Bool ?? true else { return }
        if !ready {
            engine.attach(player)
            let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
            engine.connect(player, to: engine.mainMixerNode, format: format)
            ready = (try? engine.start()) != nil
        }
        guard ready, let buffer = Self.make(full: full) else { return }
        player.stop(); player.volume = 0.9; player.scheduleBuffer(buffer, at: nil); player.play()
    }
    func stop() { if ready { player.stop() } }
    static func make(full: Bool) -> AVAudioPCMBuffer? {
        let sr = 48000.0, seconds = full ? 5.9 : 1.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2),
              let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sr * seconds)) else { return nil }
        b.frameLength = b.frameCapacity
        let l = b.floatChannelData![0], r = b.floatChannelData![1]
        let events = IntroScore.events(full: full)
        var seed: UInt32 = 11, lp1 = 0.0, lp2 = 0.0
        for i in 0..<Int(b.frameLength) {
            let t = Double(i) / sr
            seed = seed &* 1664525 &+ 1013904223; let n = Double(seed >> 8) / Double(1 << 24) * 2 - 1
            lp1 += (n - lp1) * 0.02; lp2 += (n - lp2) * 0.25
            let (a, c) = IntroScore.sample(t: t, noiseLow: lp1, noiseMid: lp2, noise: n, events: events)
            let g = full ? 1.0 : 0.9   // sting: the click and the tách overlap — keep the peak under 0.8 (no clipping)
            l[i] = Float(max(-0.8, min(0.8, a * g))); r[i] = Float(max(-0.8, min(0.8, c * g)))
        }
        return b
    }
}

/// The score, shared by the app and the stem export (Tools/intro_audio.py mirrors it).
enum IntroScore {
    struct Event { let kind: Int; let at: Double }   // 0 room, 1 chalk, 2 tip, 3 ball click + thump, 4 roll→shimmer, 5 tách, 6 ting
    static func events(full: Bool) -> [Event] {
        full ? [Event(kind: 0, at: 0), Event(kind: 1, at: 0.55), Event(kind: 2, at: 1.5), Event(kind: 3, at: 1.94),
                Event(kind: 4, at: 2.0), Event(kind: 7, at: 3.05), Event(kind: 8, at: 4.5), Event(kind: 5, at: 4.6), Event(kind: 6, at: 4.72)]
             : [Event(kind: 3, at: 0.04), Event(kind: 5, at: 0.10), Event(kind: 6, at: 0.20)]
    }
    static func sample(t: Double, noiseLow: Double, noiseMid: Double, noise: Double, events: [Event]) -> (Double, Double) {
        var mono = 0.0, l = 0.0, r = 0.0
        for e in events where t >= e.at {
            let u = t - e.at
            switch e.kind {
            case 0: mono += noiseLow * 0.10 * min(1, u / 0.4) * max(0, 1 - max(0, t - 1.15) / 0.25)
            case 1: if u < 0.03 { mono += noiseMid * 0.22 * exp(-u * 160) }
            case 2: if u < 0.08 { mono += (noise * 0.35 * exp(-u * 700) + sin(2 * .pi * 1150 * u) * 0.30 * exp(-u * 90)) }
            case 3: if u < 0.35 {
                mono += noise * 0.45 * exp(-u * 900) + sin(2 * .pi * 3300 * u) * 0.35 * exp(-u * 70) + sin(2 * .pi * 720 * u) * 0.22 * exp(-u * 40)
                mono += sin(2 * .pi * 58 * u) * 0.40 * exp(-u * 14) * min(1, u / 0.004)
            }
            case 4:
                let fade = max(0, 1 - u / 2.2)
                mono += noiseLow * 0.16 * fade
                let s = min(1, max(0, (u - 1.0) / 0.8)) * max(0, 1 - max(0, u - 2.4) / 0.4)
                for (k, f) in [880.0, 1318.5, 1760.0].enumerated() {
                    let amp = 0.05 / Double(k + 1) * s
                    l += sin(2 * .pi * (f - 1.5) * u) * amp; r += sin(2 * .pi * (f + 1.5) * u) * amp
                }
            case 5: if u < 0.05 { mono += noise * 0.4 * exp(-u * 600) + sin(2 * .pi * 2600 * u) * 0.25 * exp(-u * 120) }
            case 6: if u < 1.2 {
                let env = min(1, u / 0.006) * exp(-u * 3.4)
                mono += env * (sin(2 * .pi * 1568 * u) * 0.30 + sin(2 * .pi * 2352 * u) * 0.12 + sin(2 * .pi * 4330 * u) * 0.05)
            }
            case 7: if u < 1.4 {   // 0.44: airy swell that travels left → right with the gold motes
                let env = sin(min(1, u / 1.4) * .pi) * 0.16, pan = u / 1.4
                l += noiseMid * env * (1 - pan * 0.7); r += noiseMid * env * (0.3 + pan * 0.7)
            }
            case 8: if u < 1.0 {   // 0.44: six tiny chimes as the sparkles land on the Z (alternating sides)
                for (k, f) in [2637.0, 3136.0, 3520.0, 3951.1, 4186.0, 4698.6].enumerated() {
                    let v = u - Double(k) * 0.065
                    guard v > 0 else { continue }
                    let tone = sin(2 * .pi * f * v) * 0.045 * exp(-v * 7) * min(1, v / 0.003)
                    if k % 2 == 0 { l += tone; r += tone * 0.45 } else { r += tone; l += tone * 0.45 }
                }
            }
            default: break
            }
        }
        return (mono + l, mono + r)
    }
}
