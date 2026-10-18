import Foundation
import PoolPhysics

/// Ánh xạ dữ liệu vật lý → tham số âm thanh (UPGRADE.md 6.4).
/// Mọi đường cong đơn điệu theo xung lực (KPI A1). Tham số là giá trị khởi đầu, sẽ hiệu chỉnh
/// theo bản thu bàn thật ở R7.
public struct AcousticMapping: Codable, Equatable, Sendable {

    public struct KindCurve: Codable, Equatable, Sendable {
        /// Xung lực (N·s) ứng với cường độ 0 và 1 (thang log).
        public var impulseMin: Double
        public var impulseMax: Double
        /// Âm lượng ở cường độ 0 và 1 (dB).
        public var gainMinDB: Double
        public var gainMaxDB: Double
    }

    public var curves: [CollisionKind: KindCurve]
    /// Số lớp lực của mỗi loại mẫu.
    public var layers: Int = 5
    /// Tần số cắt bộ lọc thông thấp ở cường độ 0 và 1 (Hz): va chạm nhẹ tối hơn.
    public var cutoffMinHz: Double = 1_800
    public var cutoffMaxHz: Double = 18_000
    /// Tốc độ pháp tuyến (m/s) ứng với transient sắc nhất.
    public var transientFullSpeed: Double = 6

    public init() {
        curves = [
            .cueTip:      KindCurve(impulseMin: 0.03, impulseMax: 2.0, gainMinDB: -34, gainMaxDB: -3),
            .miscue:      KindCurve(impulseMin: 0.01, impulseMax: 0.5, gainMinDB: -30, gainMaxDB: -8),
            .ballBall:    KindCurve(impulseMin: 0.005, impulseMax: 1.5, gainMinDB: -42, gainMaxDB: -2),
            .ballCushion: KindCurve(impulseMin: 0.01, impulseMax: 1.5, gainMinDB: -44, gainMaxDB: -6),
            .ballJaw:     KindCurve(impulseMin: 0.01, impulseMax: 1.5, gainMinDB: -40, gainMaxDB: -4),
            .ballDrop:    KindCurve(impulseMin: 0.005, impulseMax: 1.0, gainMinDB: -36, gainMaxDB: -6)
        ]
    }

    /// Cường độ chuẩn hóa 0…1 theo log xung lực.
    public func intensity(_ kind: CollisionKind, impulse: Double) -> Double {
        guard let c = curves[kind], impulse > 0 else { return 0 }
        let x = log(impulse / c.impulseMin) / log(c.impulseMax / c.impulseMin)
        return min(1, max(0, x))
    }

    public func gainDB(_ kind: CollisionKind, impulse: Double) -> Double {
        guard let c = curves[kind] else { return -96 }
        let i = intensity(kind, impulse: impulse)
        return c.gainMinDB + (c.gainMaxDB - c.gainMinDB) * i
    }

    /// Lớp dưới, lớp trên và tỉ lệ trộn chéo (0 = toàn lớp dưới).
    public func layerBlend(_ kind: CollisionKind, impulse: Double) -> (lower: Int, upper: Int, mix: Double) {
        let x = intensity(kind, impulse: impulse) * Double(layers - 1)
        let lower = min(layers - 1, Int(x.rounded(.down)))
        let upper = min(layers - 1, lower + 1)
        return (lower, upper, upper == lower ? 0 : x - Double(lower))
    }

    public func cutoffHz(_ kind: CollisionKind, impulse: Double) -> Double {
        let i = intensity(kind, impulse: impulse)
        return cutoffMinHz * pow(cutoffMaxHz / cutoffMinHz, i)
    }

    /// Độ sắc transient 0…1 theo tốc độ pháp tuyến.
    public func transient(speed: Double) -> Double {
        min(1, max(0, speed / transientFullSpeed)).squareRoot()
    }
}

/// Vị trí người nghe (camera) trên mặt bàn, để định vị âm thanh.
public struct ListenerPose: Equatable, Sendable {
    public var position: SIMD2<Double>
    /// Hướng nhìn (radian, trong hệ tọa độ vật lý).
    public var yaw: Double
    public init(position: SIMD2<Double>, yaw: Double) { self.position = position; self.yaw = yaw }

    /// Pan −1 (trái) … +1 (phải) và suy giảm theo khoảng cách (dB, ≤ 0).
    public func spatial(_ p: SIMD3<Double>) -> (pan: Double, attenuationDB: Double) {
        let d = SIMD2(p.x, p.y) - position
        let dist = (d.x * d.x + d.y * d.y).squareRoot()
        guard dist > 1e-6 else { return (0, 0) }
        // Thành phần ngang so với hướng nhìn: phải là âm của "trái".
        let left = SIMD2(-sin(yaw), cos(yaw))
        let lateral = -(d.x * left.x + d.y * left.y) / dist
        let atten = max(-9, min(0, -6 * log2(max(1, dist))))
        return (max(-1, min(1, lateral)), atten)
    }
}
