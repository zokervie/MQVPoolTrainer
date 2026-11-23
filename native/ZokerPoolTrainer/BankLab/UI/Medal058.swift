import UIKit

/// 0.58 T3 — the chapter medal, drawn in code (Core Graphics): six materials of rising brilliance (MedalTier), a ribbon for "Tay sạch".
/// The diamond medal carries a moving light sweep; Reduce Motion shows it still. No image assets, no third-party artwork.
enum MedalArt {
    private static func palette(_ t: MedalTier) -> (rim: [UIColor], face: [UIColor], ink: UIColor) {
        func c(_ hex: UInt32) -> UIColor { UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1) }
        switch t {
        case .wood: return ([c(0x8a5a2b), c(0x5a3716)], [c(0xb98750), c(0x7d5226)], c(0x3a220c))
        case .bronze: return ([c(0xd89a5a), c(0x7a4a22)], [c(0xcd7f32), c(0x8a531c)], c(0x4a2a0c))
        case .silver: return ([c(0xf2f4f7), c(0x8b929a)], [c(0xdfe3e8), c(0xa5acb5)], c(0x4a5058))
        case .gold: return ([c(0xffe28a), c(0xb8860b)], [c(0xffd24d), c(0xd9a521)], c(0x6b4b00))
        case .platinum: return ([c(0xf5fbff), c(0x93a9b8)], [c(0xe8f3fa), c(0xb7cad6)], c(0x3b5566))
        case .diamond: return ([c(0xe9fbff), c(0x4cc9f0)], [c(0xbff4ff), c(0x7ad7f0)], c(0x0d4a63))
        }
    }
    /// A square image of the medal. `ribbon` adds the red-blue ribbon of the "Tay sạch" seal; `sweep` (0…1) places the diamond's light band.
    static func image(tier: MedalTier, size: CGFloat = 220, ribbon: Bool = false, sweep: CGFloat = 0.5) -> UIImage {
        let p = palette(tier)
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let g = ctx.cgContext, s = size, center = CGPoint(x: s / 2, y: s * 0.44), r = s * 0.36
            if ribbon {
                for (i, col) in [UIColor(red: 0.78, green: 0.1, blue: 0.14, alpha: 1), UIColor(red: 0.1, green: 0.25, blue: 0.7, alpha: 1)].enumerated() {
                    col.setFill(); let x = center.x + (i == 0 ? -r * 0.55 : r * 0.05)
                    let path = UIBezierPath(); path.move(to: CGPoint(x: x, y: center.y + r * 0.6)); path.addLine(to: CGPoint(x: x + r * 0.5, y: center.y + r * 0.6))
                    path.addLine(to: CGPoint(x: x + r * 0.5, y: s * 0.97)); path.addLine(to: CGPoint(x: x + r * 0.25, y: s * 0.9)); path.addLine(to: CGPoint(x: x, y: s * 0.97)); path.close(); path.fill()
                }
            }
            g.saveGState(); g.setShadow(offset: CGSize(width: 0, height: s * 0.02), blur: s * 0.04, color: UIColor.black.withAlphaComponent(0.45).cgColor)
            let rim = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: p.rim.map { $0.cgColor } as CFArray, locations: [0, 1]) {
                g.addEllipse(in: rim); g.clip(); g.drawLinearGradient(grad, start: CGPoint(x: rim.minX, y: rim.minY), end: CGPoint(x: rim.maxX, y: rim.maxY), options: [])
            }
            g.restoreGState()
            let face = rim.insetBy(dx: r * 0.14, dy: r * 0.14)
            g.saveGState(); g.addEllipse(in: face); g.clip()
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: p.face.map { $0.cgColor } as CFArray, locations: [0, 1]) {
                g.drawRadialGradient(grad, startCenter: CGPoint(x: face.midX - r * 0.25, y: face.midY - r * 0.3), startRadius: 0, endCenter: CGPoint(x: face.midX, y: face.midY), endRadius: r * 0.95, options: [.drawsAfterEndLocation])
            }
            // emblem: a five-point star (more points of light on the higher materials)
            p.ink.withAlphaComponent(0.85).setFill()
            let star = UIBezierPath(); let spikes = 5, outer = r * 0.52, inner = r * 0.22
            for i in 0..<(spikes * 2) { let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(spikes), rad = i % 2 == 0 ? outer : inner
                let pt = CGPoint(x: face.midX + cos(a) * rad, y: face.midY + sin(a) * rad); i == 0 ? star.move(to: pt) : star.addLine(to: pt) }
            star.close(); star.fill()
            if tier == .diamond {   // the light sweep
                let x = face.minX + (face.width + r) * sweep - r * 0.5
                g.setBlendMode(.plusLighter)
                UIColor.white.withAlphaComponent(0.55).setFill()
                let band = UIBezierPath(); band.move(to: CGPoint(x: x, y: face.minY)); band.addLine(to: CGPoint(x: x + r * 0.3, y: face.minY)); band.addLine(to: CGPoint(x: x - r * 0.1, y: face.maxY)); band.addLine(to: CGPoint(x: x - r * 0.4, y: face.maxY)); band.close(); band.fill()
            }
            g.restoreGState()
        }
    }
}

/// The medal on screen; the diamond animates its light unless Reduce Motion is on.
final class MedalView: UIImageView {
    private var link: CADisplayLink?
    private var t: CGFloat = 0.5
    let tier: MedalTier, ribbon: Bool
    init(tier: MedalTier, ribbon: Bool, size: CGFloat = 200) {
        self.tier = tier; self.ribbon = ribbon
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        contentMode = .scaleAspectFit; isAccessibilityElement = true; accessibilityLabel = L10n.tr("Huy chương") + " " + L10n.tr(tier.title)
        accessibilityIdentifier = "Medal-\(tier.rawValue)"
        image = MedalArt.image(tier: tier, size: size * 2, ribbon: ribbon)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        link?.invalidate(); link = nil
        guard window != nil, tier.animated, !UIAccessibility.isReduceMotionEnabled else { return }
        link = CADisplayLink(target: self, selector: #selector(tick)); link?.preferredFramesPerSecond = 30; link?.add(to: .main, forMode: .common)
    }
    @objc private func tick() { t += 0.012; if t > 1.3 { t = -0.3 }; image = MedalArt.image(tier: tier, size: bounds.width * 2, ribbon: ribbon, sweep: t) }
    deinit { link?.invalidate() }
}
