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
    /// 0,0127 → dω_z/dt ≈ 10,9 rad/s², giữa khoảng công bố 5–15 rad/s² (Dr. Dave) và trùng pooltool
    /// (u_sp = 10·(2/5)/9·R). Giá trị cũ 0,044 (≈ 37,8 rad/s²) làm xoáy ngang tắt quá nhanh (docs/09).
    public var spinFriction: Double = 0.0127

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

    /// Hệ số phục hồi băng tại tốc độ lao vào băng 1 m/s. Dr. Dave: 0,6–0,9 (giả định 0,8, đo ở M3).
    public var cushionRestitution: Double = 0.8
    /// Độ giảm hệ số phục hồi băng theo tốc độ lao vào (mỗi m/s):
    /// e(v) = clamp(e₁ − k·(v − 1), 0,6, 0,95). Cao su băng đàn nhớt nên e giảm khi va mạnh
    /// (Dr. Dave: e băng "thay đổi theo tốc độ", khoảng 0,6–0,9). Độ dốc k là **giả định**, đo ở M3.
    /// Đặt 0 để có mô hình hằng số (đối chứng Han 2005 / pooltool).
    public var cushionRestitutionSpeedSlope: Double = 0.04

    /// Ma sát bi–băng. Nguồn: pooltool (0,2); Mathavan 2010 dùng 0,14 (biến thể so sánh).
    public var cushionFriction: Double = 0.2

    /// Hệ số phục hồi bi–mặt bàn (đá + nỉ) cho nhảy bi. Giả định ~0,5 (Alciatore, phân tích jump shot
    /// dùng khoảng 0,5); phụ thuộc nỉ và độ dày đá — cần đo ở R4.
    public var tableRestitution: Double = 0.5

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case gravity, slidingFriction, rollingResistance, spinFriction, ballBallFriction, ballBallFrictionMinRatio,
             ballBallFrictionDecay, ballBallRestitution, cushionRestitution, cushionRestitutionSpeedSlope, cushionFriction, tableRestitution
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
        cushionRestitutionSpeedSlope = try c.decodeIfPresent(Double.self, forKey: .cushionRestitutionSpeedSlope)
            ?? d.cushionRestitutionSpeedSlope
        cushionFriction = try c.decodeIfPresent(Double.self, forKey: .cushionFriction) ?? d.cushionFriction
        tableRestitution = try c.decodeIfPresent(Double.self, forKey: .tableRestitution) ?? d.tableRestitution
    }

    /// Hệ số phục hồi băng khi tâm bi lao vào băng với tốc độ pháp tuyến v (m/s).
    public func cushionRestitution(atApproachSpeed v: Double) -> Double {
        min(0.95, max(0.6, cushionRestitution - cushionRestitutionSpeedSlope * (v - 1)))
    }

    /// Ma sát bi–bi tại tốc độ trượt tương đối v (m/s).
    public func ballBallFriction(atSlipSpeed v: Double) -> Double {
        ballBallFriction * (ballBallFrictionMinRatio + (1 - ballBallFrictionMinRatio) * exp(-ballBallFrictionDecay * v))
    }
}
