import Foundation

/// Mọi hằng số vật lý nằm ở đây để hiệu chỉnh và lưu theo "hồ sơ bàn".
/// Giá trị mặc định lấy từ tài liệu đã công bố; sẽ tinh chỉnh sau.
public struct PhysicsParameters: Codable, Equatable, Sendable {
    /// Gia tốc trọng trường (m/s²).
    public var gravity: Double = 9.81

    /// Ma sát trượt bi–nỉ. Nguồn: D. Alciatore, "Pool and Billiards Physics Resources" (~0,2).
    public var slidingFriction: Double = 0.2

    /// Hệ số cản lăn bi–nỉ. Nguồn: Alciatore (~0,005–0,015 tùy nỉ). Nỉ nhanh → nhỏ hơn.
    public var rollingResistance: Double = 0.01

    /// Hệ số giảm xoay quanh trục đứng (đơn vị như ma sát, dùng trong dω_z/dt = -5·μ·g/(2R)).
    /// Nguồn: Marlow, "The Physics of Pocket Billiards" (~0,044). Cần hiệu chỉnh.
    public var spinFriction: Double = 0.044

    /// Ma sát bi–bi (gây throw). Nguồn: Alciatore, TP A.14 (~0,06, phụ thuộc tốc độ).
    public var ballBallFriction: Double = 0.06

    /// Hệ số phục hồi bi–bi. Nguồn: Alciatore (~0,92–0,98).
    public var ballBallRestitution: Double = 0.94

    /// Hệ số phục hồi băng. Nguồn: Mathavan et al. 2010 (~0,75–0,85).
    public var cushionRestitution: Double = 0.8

    /// Ma sát bi–băng. Nguồn: Mathavan et al. 2010 (~0,2).
    public var cushionFriction: Double = 0.2

    public init() {}
}
