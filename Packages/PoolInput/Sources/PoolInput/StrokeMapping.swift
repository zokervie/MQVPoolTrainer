import Foundation

/// Quy đổi kết quả cú vuốt → thông số cơ. Đường cong cố định, đơn điệu, dễ đoán.
public struct StrokeMapping: Codable, Equatable, Sendable {
    /// Dải tốc độ ngón (mm/s) ↔ dải tốc độ cơ (m/s).
    public var fingerMin: Double = 50
    public var fingerMax: Double = 1500
    public var cueMin: Double = 0.5
    public var cueMax: Double = 10
    /// Độ lệch hướng cơ (radian) ứng với lateralRatio = 1.
    public var lateralToAngle: Double = 0.05
    /// Xoáy ngang ngoài ý muốn (tỉ lệ bán kính bi) ứng với lateralRatio = 1.
    public var lateralToEnglish: Double = 0.3

    public init() {}

    /// Đường cong lũy thừa đi qua (fingerMin, cueMin) và (fingerMax, cueMax).
    public func cueSpeed(fingerSpeed f: Double) -> Double {
        guard f > 0 else { return 0 }
        let fc = min(max(f, fingerMin), fingerMax)
        let gamma = log(cueMax / cueMin) / log(fingerMax / fingerMin)
        let cue = cueMin * pow(fc / fingerMin, gamma)
        // Ngắt cơ đã nằm trong fingerSpeed (tốc độ tại vạch), không phạt thêm.
        return cue
    }

    public func aimError(_ r: StrokeResult) -> Double { r.lateralRatio * lateralToAngle }
    public func unintendedEnglish(_ r: StrokeResult) -> Double { r.lateralRatio * lateralToEnglish }
}
