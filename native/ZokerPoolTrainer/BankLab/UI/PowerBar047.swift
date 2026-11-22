import UIKit

/// 0.47 M1 — Thanh lực cho người mới. A vertical bar on the right: drag DOWN to load power, release to strike.
/// Bar travel → speed through BLPowerBarSpeed (DailyLoop.h, Tests/DailyLoopTests.cpp: monotonic, 0 → 0,5 m/s,
/// 100 % → the Tuỳ chỉnh ceiling 8 m/s × "Lực đánh tối đa"). The swipe with B keeps working; Tuỳ chỉnh → Lực đánh
/// chooses the default input (FeatureFlags.usesPowerBar). A release below 3 % travel is a cancel, not a tap-shot.
final class PowerBarControl: UIControl {
    /// Fraction 0…1 while loading (and the last one fired, for QA).
    private(set) var fraction = 0.0
    private(set) var firedFraction = 0.0
    var maxSpeed = BL_POWER_MAX_SPEED
    var fire: ((Double) -> Void)?
    private var startY: CGFloat = 0
    private let track = UIView(), fill = CAGradientLayer(), label = UILabel(), arrow = UIImageView(image: UIImage(systemName: "chevron.compact.down"))
    static let cancelBelow = 0.10   // review 0.47: 3 % was ~4 pt on iPhone — a resting finger fired a shot

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true; accessibilityIdentifier = "PowerBar"
        accessibilityLabel = "Thanh lực"; accessibilityHint = "Kéo xuống để nạp lực, thả để đánh"
        accessibilityTraits = [.adjustable]
        track.isUserInteractionEnabled = false; track.backgroundColor = UIColor(white: 0.05, alpha: 0.55)
        track.layer.cornerRadius = 12; track.layer.borderWidth = 1; track.layer.borderColor = UIColor(white: 1, alpha: 0.35).cgColor; track.clipsToBounds = true
        addSubview(track)
        fill.colors = [UIColor(red: 0.30, green: 0.85, blue: 0.45, alpha: 0.95).cgColor, UIColor(red: 1, green: 0.82, blue: 0.3, alpha: 0.95).cgColor,
                       UIColor(red: 1, green: 0.32, blue: 0.22, alpha: 0.95).cgColor]
        fill.startPoint = CGPoint(x: 0.5, y: 0); fill.endPoint = CGPoint(x: 0.5, y: 1)
        track.layer.addSublayer(fill)
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .bold); label.textColor = .white; label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true; label.minimumScaleFactor = 0.7; label.isUserInteractionEnabled = false
        addSubview(label)
        arrow.tintColor = UIColor(white: 1, alpha: 0.75); arrow.contentMode = .scaleAspectFit; arrow.isUserInteractionEnabled = false
        addSubview(arrow)
        redraw()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let labelH: CGFloat = 18
        track.frame = CGRect(x: 0, y: labelH + 2, width: bounds.width, height: max(10, bounds.height - labelH - 2))
        label.frame = CGRect(x: -8, y: 0, width: bounds.width + 16, height: labelH)
        redraw()
    }
    /// Travel the finger must cover for 100 % (90 % of the track, so a full charge never needs the very edge).
    private var travel: CGFloat { max(40, track.bounds.height * 0.9) }
    private func redraw() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let h = track.bounds.height * CGFloat(fraction)
        fill.frame = CGRect(x: 0, y: 0, width: track.bounds.width, height: h)
        CATransaction.commit()
        arrow.frame = CGRect(x: track.frame.minX + 6, y: track.frame.minY + max(4, h - 18), width: track.bounds.width - 12, height: 16)
        arrow.isHidden = fraction > 0.97
        label.text = fraction > 0 ? String(format: "%lld%%", Int((fraction * 100).rounded())) : "0%"
        accessibilityValue = String(format: "%lld%%", Int((fraction * 100).rounded()))
    }
    /// 0.49c G3: the bar is small (≈ 28 × 180 pt); holding it magnifies ×2.5 around the finger (like the effect ball) so the load can
    /// be set finely. Local touch coordinates are unaffected by the transform, so 1 screen pt moves the load 2.5× less.
    static let holdZoom: CGFloat = 2.5
    /// Largest magnification reached since launch (QA probe: a UI test cannot read the scene while the finger is down).
    private(set) var peakZoom: CGFloat = 1
    private func zoom(_ on: Bool, around p: CGPoint) {
        if on { peakZoom = Self.holdZoom }
        let d = CGPoint(x: p.x - bounds.midX, y: p.y - bounds.midY)
        let target = on ? CGAffineTransform(translationX: d.x, y: d.y).scaledBy(x: Self.holdZoom, y: Self.holdZoom).translatedBy(x: -d.x, y: -d.y) : .identity
        // Zoom in at once: an animated transform makes the touch's local coordinates drift during the first frames of the drag.
        if on { transform = target } else { UIView.animate(withDuration: 0.12) { self.transform = target } }
    }
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        zoom(true, around: touch.location(in: self))
        startY = touch.location(in: self).y; fraction = 0; redraw()
        UISelectionFeedbackGenerator().selectionChanged()
        return true
    }
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let f = Double((touch.location(in: self).y - startY) / travel)
        let clamped = max(0, min(1, f))
        if (clamped >= 1) != (fraction >= 1) && clamped >= 1 { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
        fraction = clamped; redraw()
        return true
    }
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        let f = fraction
        zoom(false, around: .zero)
        fraction = 0; redraw()
        guard f >= Self.cancelBelow else { return }
        firedFraction = f
        fire?(f)
    }
    override func cancelTracking(with event: UIEvent?) { zoom(false, around: .zero); fraction = 0; redraw() }
    // VoiceOver: swipe up/down sets the load, double-tap strikes.
    override func accessibilityIncrement() { fraction = min(1, fraction + 0.1); redraw() }
    override func accessibilityDecrement() { fraction = max(0, fraction - 0.1); redraw() }
    override func accessibilityActivate() -> Bool {
        guard fraction >= Self.cancelBelow else { return false }
        firedFraction = fraction; let f = fraction; fraction = 0; redraw(); fire?(f); return true
    }
}

extension TrainingController {
    var powerBarMaxSpeed: Double { BL_POWER_MAX_SPEED * Tuning.maxPower }
    /// QA launches keep the swipe (existing gesture tests) unless `--power-bar-qa` asks for the bar.
    var usesPowerBar: Bool {
        if let chosen = powerBarUserOn { return chosen && FeatureFlags.powerBar }   // 0.49c G3: the on-screen switch wins this session
        if QA.anyFlag { return QA.has("--power-bar-qa") && FeatureFlags.powerBar }
        return FeatureFlags.usesPowerBar(shots: PlayerStore.shared.data.metrics.shots)
    }
    func installPowerBar() {
        guard powerBar == nil else { return }
        let bar = PowerBarControl(frame: .zero)
        bar.fire = { [weak self] f in self?.firePowerBar(f) }
        view.addSubview(bar); powerBar = bar
        syncPowerBar()
    }
    /// The stroke from the bar: exactly like the B swipe (lock → shoot → release), speed from the core mapping.
    func firePowerBar(_ fraction: Double) {
        guard !shotActive, replayIndex == nil, !isPlacingBalls, strokeAllowed else { return }
        let speed = BLPowerBarSpeed(fraction, powerBarMaxSpeed)
        setHold(true); guard locked else { return }
        if let bar = powerBar { powerFX.fire(bar.convert(CGPoint(x: bar.bounds.midX, y: bar.bounds.maxY), to: powerFX), speed: speed) }
        shoot(speed); spin.collapse(); setHold(false)
    }
    /// 0.49c G3: small switch in the left cluster (next to "Đặt bi"): bar on = stroke with the bar, off = the swipe (B) only.
    func buildPowerBarSwitch() {
        let b = UIButton(type: .system); var c = UIButton.Configuration.filled()
        c.image = UIImage(systemName: "slider.vertical.3"); c.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        c.cornerStyle = .capsule; c.contentInsets = .zero
        b.configuration = c; b.accessibilityIdentifier = "PowerBarSwitch"
        b.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let on = !self.usesPowerBar
            self.powerBarUserOn = on
            UserDefaults.standard.set(on ? 1 : 0, forKey: Prefs.powerBarMode)
            self.syncPowerBar(); self.view.setNeedsLayout()
        }, for: .touchUpInside)
        view.addSubview(b); powerBarSwitch = b
    }
    func syncPowerBarSwitch() {
        guard let b = powerBarSwitch else { return }
        let on = usesPowerBar
        b.isHidden = menuOpen || spinExpanded || replayIndex != nil || !FeatureFlags.powerBar
        powerCaption?.isHidden = b.isHidden
        b.configuration?.baseBackgroundColor = on ? ZDesign.Color.gold : UIColor(white: 0.03, alpha: 0.55)
        b.configuration?.baseForegroundColor = on ? .black : .white
        b.accessibilityLabel = on ? "Tắt thanh lực" : "Bật thanh lực"; b.accessibilityValue = on ? "1" : "0"
    }
    func syncPowerBar() {
        syncPowerBarSwitch()
        guard let bar = powerBar else { return }
        bar.maxSpeed = powerBarMaxSpeed
        let show = usesPowerBar && !menuOpen && !spinExpanded && !introRunning
        bar.isHidden = !show
        bar.isEnabled = show && strokeAllowed && !shotActive && replayIndex == nil && !isPlacingBalls
        bar.alpha = bar.isEnabled ? 1 : 0.4
        if show { view.bringSubviewToFront(bar) }
    }
    /// Right of the play area, just inside the shortcut column (mirrored for the left hand). Called from layoutRightHUD.
    func placePowerBar(rail: BLRect, safe: CGRect) {
        guard let bar = powerBar else { return }
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let w: CGFloat = pad ? 28 : 26, h = min(safe.height * 0.40, pad ? 180 : 140)   // 0.49c G3: small; hold = ×2.5
        let x = leftHanded ? CGFloat(rail.x + rail.w) + 14 : CGFloat(rail.x) - 14 - w
        bar.frame = CGRect(x: x, y: safe.minY + safe.height * 0.16, width: w, height: h)
        placeSideButtons(bar: bar.frame)
        syncPowerBar()
    }
    /// 0.53 B1: "Đặt bi" and the bar switch sit beside the power bar (toward the table), each with a small caption; never moved while balls roll
    /// (this runs from the HUD layout only, which the shot defers).
    func placeSideButtons(bar: CGRect) {
        guard let place = placeBallButton, let sw = powerBarSwitch else { return }
        func caption(_ existing: UILabel?, _ text: String) -> UILabel {
            if let l = existing { return l }
            let l = UILabel(); l.text = L10n.tr(text); l.font = .systemFont(ofSize: 11, weight: .semibold); l.textColor = UIColor(white: 1, alpha: 0.85)
            l.textAlignment = .center; l.adjustsFontSizeToFitWidth = true; l.minimumScaleFactor = 0.7; l.isUserInteractionEnabled = false
            l.layer.shadowColor = UIColor.black.cgColor; l.layer.shadowRadius = 2; l.layer.shadowOpacity = 0.8; l.layer.shadowOffset = .zero
            view.addSubview(l); return l
        }
        placeCaption = caption(placeCaption, "Đặt bi"); powerCaption = caption(powerCaption, "Thanh lực")
        let colW: CGFloat = 64, x = leftHanded ? bar.maxX + 10 : bar.minX - 10 - colW
        let top = bar.minY
        place.bounds = CGRect(x: 0, y: 0, width: 64, height: 64); place.center = CGPoint(x: x + colW / 2, y: top + 32)
        placeCaption?.frame = CGRect(x: x - 6, y: top + 66, width: colW + 12, height: 14)
        sw.bounds = CGRect(x: 0, y: 0, width: 44, height: 44); sw.center = CGPoint(x: x + colW / 2, y: top + 66 + 14 + 6 + 22)
        powerCaption?.frame = CGRect(x: x - 6, y: top + 66 + 14 + 6 + 44 + 2, width: colW + 12, height: 14)
        syncPlaceBallButton(); syncPowerBarSwitch()
    }
}
