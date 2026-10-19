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

    /// Hệ số phục hồi bi–mặt bàn (đá + nỉ) cho nhảy bi. Giả định ~0,5 (Alciatore, phân tích jump shot
    /// dùng khoảng 0,5); phụ thuộc nỉ và độ dày đá — cần đo ở R4.
    public var tableRestitution: Double = 0.5

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case gravity, slidingFriction, rollingResistance, spinFriction, ballBallFriction, ballBallFrictionMinRatio,
             ballBallFrictionDecay, ballBallRestitution, cushionRestitution, cushionFriction, tableRestitution
    }

    /// Đọc được hồ sơ cũ thiếu khóa mới (giá trị thiếu = mặc định).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PhysicsParameters()
        gravity = try c.decodeIfPresent(Double.self, forKey: .gravity) ?? d.gravity
        slidingFriction = try c.decodeIfPresent(Double.self, forKey: .slidingFriction) ?? d.slidingFriction
        rollingResistance = try c.decodeIfPresent(Double.self, forKey: .rollingResistance) ?? d.rollingResistance
        spinFriction = try c.decodeIfPresent(Double.self, forKey: .spinFriction) ?? d.spinFriction
        ballBallFriction = try c.decodeIfPresent(Double.self, forKey: .ballBallFriction) ?? d.ballBallFriction
        ballBallFrictionMinRatio = try c.decodeIfPresent(Double.self, forKey: .ballBallFrictionMinRatio) ?? d.ballBallFrictionMinRatio
        ballBallFrictionDecay = try c.decodeIfPresent(Double.self, forKey: .ballBallFrictionDecay) ?? d.ballBallFrictionDecay
        ballBallRestitution = try c.decodeIfPresent(Double.self, forKey: .ballBallRestitution) ?? d.ballBallRestitution
        cushionRestitution = try c.decodeIfPresent(Double.self, forKey: .cushionRestitution) ?? d.cushionRestitution
        cushionFriction = try c.decodeIfPresent(Double.self, forKey: .cushionFriction) ?? d.cushionFriction
        tableRestitution = try c.decodeIfPresent(Double.self, forKey: .tableRestitution) ?? d.tableRestitution
    }

    /// Ma sát bi–bi tại tốc độ trượt tương đối v (m/s).
    public func ballBallFriction(atSlipSpeed v: Double) -> Double {
        ballBallFriction * (ballBallFrictionMinRatio + (1 - ballBallFrictionMinRatio) * exp(-ballBallFrictionDecay * v))
    }
}
