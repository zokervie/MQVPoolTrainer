import UIKit
import PoolInput

/// Vị trí bi chỉnh effect (dùng chung cho vùng chạm và phần vẽ SwiftUI).
enum EffectBallLayout {
    static let compactRadius: CGFloat = 30
    static let expandedRadius: CGFloat = 110

    static func center(size: CGSize, insets: UIEdgeInsets, mirrored: Bool) -> CGPoint {
        let margin: CGFloat = 76
        let x = mirrored ? insets.left + margin : size.width - insets.right - margin
        return CGPoint(x: x, y: size.height * 0.5)
    }

    /// Thanh độ dốc cơ: dải dọc sát bên trong bi effect (phía giữa màn hình).
    static let elevationHeight: CGFloat = 150
    static func elevationRect(size: CGSize, insets: UIEdgeInsets, mirrored: Bool) -> CGRect {
        let c = center(size: size, insets: insets, mirrored: mirrored)
        let x = mirrored ? c.x + compactRadius + 18 : c.x - compactRadius - 18 - 26
        return CGRect(x: x, y: c.y - elevationHeight / 2, width: 26, height: elevationHeight)
    }
}

/// Lớp nhận cảm ứng phủ trên cảnh 3D (docs/02-controls.md):
/// - Chưa khóa: vuốt bất kỳ đâu xoay hướng ngắm (hai ngón = chế độ tinh); chạm bi effect để chọn điểm chạm.
/// - Vùng khóa ẩn góc dưới trái (hoặc phải nếu thuận tay trái): chạm nhanh rồi nhấc.
/// - Đã khóa: vuốt bất kỳ đâu ngoài vùng khóa để ra cơ; điểm đặt ngón là vạch chạm bi.
@MainActor
final class TouchSurface: UIView {
    weak var model: GameModel?

    private var effectTouch: UITouch?
    private var elevationTouch: UITouch?
    private var elevationStep = 0
    private var strokeStartY: CGFloat = 0
    private var edgeHapticFired = false
    private var readiedFired = false
    private var lockTouch: (touch: UITouch, start: CGPoint, time: TimeInterval)?
    private var strokeTouch: UITouch?
    private var analyzer = StrokeAnalyzer()
    private var strokeSamples: [TouchSample] = []
    private var aimTouches: [UITouch: CGPoint] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) không dùng") }

    private var mirrored: Bool { model?.settings.leftHanded ?? false }
    private var lockZone: LockZone { var z = LockZone(); z.mirrored = mirrored; return z }

    private func normalized(_ p: CGPoint) -> SIMD2<Double> {
        SIMD2(Double(p.x / max(bounds.width, 1)), Double(p.y / max(bounds.height, 1)))
    }

    private func millimeters(_ p: CGPoint) -> SIMD2<Double> {
        let k = model?.settings.mmPerPoint ?? 0.156
        return SIMD2(Double(p.x) * k, Double(p.y) * k)
    }

    private var effectCenter: CGPoint {
        EffectBallLayout.center(size: bounds.size, insets: safeAreaInsets, mirrored: mirrored)
    }

    // MARK: Bắt đầu chạm

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let model else { return }
        Haptics.prepare()
        for t in touches {
            let p = t.location(in: self)
            if lockZone.contains(normalized(p)), lockTouch == nil {
                lockTouch = (t, p, t.timestamp)
                continue
            }
            switch model.state {
            case .aiming:
                let c = effectCenter
                let er = EffectBallLayout.elevationRect(size: bounds.size, insets: safeAreaInsets, mirrored: mirrored)
                if elevationTouch == nil, er.insetBy(dx: -14, dy: -10).contains(p) {
                    elevationTouch = t
                    elevationStep = Int((model.elevation * 180 / .pi / 5).rounded())
                    Haptics.effectTouch()
                    updateElevation(t, model)
                } else if effectTouch == nil, hypot(p.x - c.x, p.y - c.y) <= EffectBallLayout.compactRadius * 1.6 {
                    effectTouch = t
                    edgeHapticFired = false
                    model.effectExpanded = true
                    Haptics.effectTouch()
                    if t.tapCount >= 2 { model.resetTip() }
                } else {
                    aimTouches[t] = p
                }
            case .locked:
                if strokeTouch == nil {
                    strokeTouch = t
                    strokeStartY = p.y
                    readiedFired = false
                    analyzer = StrokeAnalyzer()
                    let s = TouchSample(time: t.timestamp, position: millimeters(p))
                    strokeSamples = [s]
                    analyzer.begin(s)
                }
            case .shotRunning, .reviewing:
                break
            }
        }
    }

    // MARK: Di chuyển

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let model else { return }
        for t in touches {
            if t === effectTouch {
                updateTip(t, model)
            } else if t === elevationTouch {
                updateElevation(t, model)
            } else if t === strokeTouch {
                // Cơ chạy theo ngón: kéo xuống 1 mm → cơ lùi 5 mm (cú kéo 3 cm ≈ lấy đà 15 cm).
                let pullMm = Double(t.location(in: self).y - strokeStartY) * (model.settings.mmPerPoint)
                model.cueDraw = max(-0.01, pullMm * 0.005)
                let samples = event?.coalescedTouches(for: t) ?? [t]
                for c in samples {
                    let s = TouchSample(time: c.timestamp, position: millimeters(c.location(in: self)))
                    strokeSamples.append(s)
                    let outcome = analyzer.add(s)
                    if analyzer.isReadied && !readiedFired { readiedFired = true; Haptics.readied() }
                    if case .struck(let r) = outcome {
                        let rec = TouchRecording(deviceModel: UIDevice.current.model,
                                                 mmPerPoint: model.settings.mmPerPoint,
                                                 config: StrokeConfig(), samples: strokeSamples)
                        strokeTouch = nil
                        model.strokeCompleted(r, recording: rec)
                        break
                    }
                }
            } else if let last = aimTouches[t] {
                let p = t.location(in: self)
                let fine = aimTouches.count >= 2
                // Kéo sang phải → xoay hướng ngắm sang phải (góc giảm).
                let gain = fine ? 0.0004 : 0.0025
                model.rotateAim(by: -Double(p.x - last.x) * gain / (fine ? Double(aimTouches.count) : 1))
                aimTouches[t] = p
            }
        }
    }

    private func updateElevation(_ t: UITouch, _ model: GameModel) {
        let r = EffectBallLayout.elevationRect(size: bounds.size, insets: safeAreaInsets, mirrored: mirrored)
        let f = Double((r.maxY - t.location(in: self).y) / r.height)
        let e = max(0, min(1, f)) * GameModel.maxElevation
        model.setElevation(e)
        // Tích nhẹ mỗi 5°, như nấc khi nâng đuôi cơ.
        let step = Int((e * 180 / .pi / 5).rounded())
        if step != elevationStep { elevationStep = step; Haptics.effectTouch() }
    }

    private func updateTip(_ t: UITouch, _ model: GameModel) {
        let p = t.location(in: self)
        let c = effectCenter
        let r = EffectBallLayout.expandedRadius
        let v = SIMD2(Double((p.x - c.x) / r), Double(-(p.y - c.y) / r))
        let clamped = model.setTip(v)
        if clamped && !edgeHapticFired { Haptics.edge(); edgeHapticFired = true }
        if !clamped { edgeHapticFired = false }
    }

    // MARK: Kết thúc chạm

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches, cancelled: true)
    }

    private func finish(_ touches: Set<UITouch>, cancelled: Bool) {
        guard let model else { return }
        for t in touches {
            if t === effectTouch {
                effectTouch = nil
                model.effectExpanded = false
            } else if t === elevationTouch {
                elevationTouch = nil
            } else if let l = lockTouch, l.touch === t {
                lockTouch = nil
                let end = t.location(in: self)
                if !cancelled, lockZone.isLockTap(start: normalized(l.start), end: normalized(end),
                                                  duration: t.timestamp - l.time, maxRadius: Double(t.majorRadius)) {
                    model.lockTapped()
                }
            } else if t === strokeTouch {
                strokeTouch = nil
                model.cueDraw = 0
                if case .cancelled = analyzer.end() { model.strokeCancelled() }
            } else {
                aimTouches[t] = nil
            }
        }
    }
}
