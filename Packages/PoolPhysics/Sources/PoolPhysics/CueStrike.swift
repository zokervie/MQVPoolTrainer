import Foundation
import simd

/// Thông số cú đánh. Điểm chạm tính theo tỉ lệ bán kính bi, −1…1.
public struct CueStrike: Codable, Equatable, Sendable {
    /// Hướng cơ trên mặt bàn (radian, 0 = trục +x).
    public var aimAngle: Double
    /// Tốc độ đầu cơ khi chạm bi (m/s).
    public var cueSpeed: Double
    /// Điểm chạm dọc: +1 = đỉnh bi (xoáy trên), −1 = đáy (xoáy dưới).
    public var tipVertical: Double
    /// Điểm chạm ngang: +1 = bên phải bi theo hướng ngắm.
    public var tipHorizontal: Double

    public init(aimAngle: Double, cueSpeed: Double, tipVertical: Double = 0, tipHorizontal: Double = 0) {
        self.aimAngle = aimAngle
        self.cueSpeed = cueSpeed
        self.tipVertical = tipVertical
        self.tipHorizontal = tipHorizontal
    }
}

/// GIAI ĐOẠN 1: mô hình cơ nằm ngang, bỏ qua squirt và swerve.
/// Tốc độ bi cái tạm tính bằng hệ số cố định nhân tốc độ cơ (xem `speedRatio`).
/// Xoáy theo Alciatore TP 4.2 (lực xung lệch tâm).
/// TODO (Giai đoạn 2): khối lượng cơ, khối lượng đầu cơ (squirt), góc dốc cơ (swerve),
/// giới hạn trượt cơ (miscue) ~0,5R.
public enum CueModel {
    /// Tỉ lệ tốc độ bi / tốc độ cơ khi đánh giữa tâm (thực nghiệm ~1,3–1,5).
    public static let speedRatio = 1.4

    public static func apply(_ strike: CueStrike, to ball: Ball, radius R: Double) -> Ball {
        var b = ball
        let dir = SIMD3(cos(strike.aimAngle), sin(strike.aimAngle), 0)
        let side = SIMD3(-dir.y, dir.x, 0) // vuông góc bên trái hướng ngắm
        let v = strike.cueSpeed * speedRatio
        b.velocity = v * dir
        // Lực đánh lệch tâm theo độ cao h = tipVertical·R tạo ω = 5·v·h / (2R²).
        // Nguồn: Alciatore TP 4.2.
        let h = strike.tipVertical * R
        let topspin = 5 * v * h / (2 * R * R)
        // Trục quay của xoáy trên là trục vuông góc hướng đi trong mặt bàn: (ẑ × dir) → hướng "side".
        let wxy = topspin * side
        // Xoáy ngang: lệch ngang tạo quay quanh trục đứng. Đánh bên phải → quay theo chiều kim đồng hồ (ωz < 0).
        let s = strike.tipHorizontal * R
        let wz = -5 * v * s / (2 * R * R)
        b.angularVelocity = SIMD3(wxy.x, wxy.y, wz)
        b.state = b.classified(radius: R)
        return b
    }
}
