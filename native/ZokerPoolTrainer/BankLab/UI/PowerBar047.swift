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
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
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
        fraction = 0; redraw()
        guard f >= Self.cancelBelow else { return }
        firedFraction = f
        fire?(f)
    }
    override func cancelTracking(with event: UIEvent?) { fraction = 0; redraw() }
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
    func syncPowerBar() {
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
        let w: CGFloat = pad ? 50 : 40, h = min(safe.height * 0.46, pad ? 380 : 230)
        let x = leftHanded ? CGFloat(rail.x + rail.w) + 14 : CGFloat(rail.x) - 14 - w
        bar.frame = CGRect(x: x, y: safe.minY + safe.height * 0.16, width: w, height: h)
        syncPowerBar()
    }
}
