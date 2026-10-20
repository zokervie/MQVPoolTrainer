import Foundation

/// Quy đổi kết quả cú vuốt → thông số cơ. Đường cong cố định, đơn điệu, dễ đoán.
public struct StrokeMapping: Codable, Equatable, Sendable {
    /// Dải tốc độ ngón (mm/s) ↔ dải tốc độ cơ (m/s).
    /// Giá trị khởi đầu (giả định), cần chỉnh khi đo trên thiết bị (KPI U4): tốc độ ngón thường gặp
    /// 100–1000 mm/s phủ dải lực luyện tập 0,4–5 m/s. Nới tới 1500 mm/s (gần tuyến tính, γ ≈ 1,02) để
    /// mỗi bước tốc độ ngón đổi lực ít hơn → lực mịn hơn ở mọi mức.
    public var fingerMin: Double = 80
    public var fingerMax: Double = 1500
    public var cueMin: Double = 0.3
    public var cueMax: Double = 6
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
