import Foundation

/// Mọi hằng số vật lý nằm ở đây để hiệu chỉnh và lưu theo "hồ sơ bàn".
/// Giá trị mặc định lấy từ tài liệu; nguồn gốc từng giá trị ghi trong `TableDefinition.zoker9ft`.
public struct PhysicsParameters: Codable, Equatable, Sendable {
    /// Gia tốc trọng trường (m/s²).
    public var gravity: Double = 9.81

    /// Ma sát trượt bi–nỉ. Nguồn: D. Alciatore, "Pool and Billiards Physics Resources" (~0,2).
    public var slidingFriction: Double = 0.2

    /// Hệ số cản lăn bi–nỉ. Nguồn: Alciatore (~0,005–0,015 tùy nỉ). Nỉ nhanh → nhỏ hơn.
    public var rollingResistance: Double = 0.01

    /// Hệ số giảm xoay quanh trục đứng (dω_z/dt = −5·μ·g/(2R)).
    /// Nguồn: Marlow, "The Physics of Pocket Billiards" (~0,044). Cần hiệu chỉnh.
    public var spinFriction: Double = 0.044

    /// Ma sát bi–bi khi tốc độ trượt tương đối → 0 (gây throw).
    /// Mô hình phụ thuộc tốc độ: μ(v) = μ₀·(r + (1 − r)·e^(−c·v)).
    /// Nguồn: Alciatore TP A.14, khớp dữ liệu Marlow: μ(v) = a + b·e^(−c·v),
    /// a ≈ 0,00995, b ≈ 0,108, c ≈ 1,088 s/m → μ₀ = a + b ≈ 0,118, r = a/(a+b) ≈ 0,084.
    /// Đặt μ₀ = 0 để có va chạm không ma sát (dùng cho test quy tắc 90°/30°).
    public var ballBallFriction: Double = 0.118
    /// r trong công thức trên (tỉ lệ ma sát còn lại ở tốc độ cao).
    public var ballBallFrictionMinRatio: Double = 0.084
    /// c trong công thức trên (s/m).
    public var ballBallFrictionDecay: Double = 1.088

    /// Hệ số phục hồi bi–bi. Nguồn: Alciatore (~0,92–0,98).
    public var ballBallRestitution: Double = 0.94

    /// Hệ số phục hồi băng. Nguồn: Mathavan et al. 2010 (~0,75–0,85).
    public var cushionRestitution: Double = 0.8

    /// Ma sát bi–băng. Nguồn: Mathavan et al. 2010 (~0,2).
    public var cushionFriction: Double = 0.2

    public init() {}

    /// Ma sát bi–bi tại tốc độ trượt tương đối v (m/s).
    public func ballBallFriction(atSlipSpeed v: Double) -> Double {
        ballBallFriction * (ballBallFrictionMinRatio + (1 - ballBallFrictionMinRatio) * exp(-ballBallFrictionDecay * v))
    }
}
