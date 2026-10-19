import Foundation

/// Vùng khóa ẩn ở góc dưới trái (tọa độ màn hình chuẩn hóa 0…1, gốc trên-trái, như UIKit).
public struct LockZone: Sendable {
    /// Diện tích ~1/8 màn hình: rộng 0,25 × cao 0,5.
    public var width: Double = 0.25
    public var height: Double = 0.5
    /// Khoảng cách tới mép để tránh thao tác hệ thống.
    public var edgeInset: Double = 0.03
    /// Thời gian chạm tối đa để tính là chạm nhanh (s). 0,3 s cũ quá gắt với chạm tự nhiên của ngón cái.
    public var maxTapDuration: Double = 0.45
    /// Bán kính chạm tối đa (pt) — lớn hơn coi là lòng bàn tay tì vào màn hình.
    /// Ngón cái người thật trên iPhone báo `majorRadius` khoảng 30–50 pt (giá trị cũ 30 pt làm mọi lần
    /// chạm bằng ngón cái bị loại → không khóa được, không có rung). Lòng bàn tay thường > 80 pt.
    public var maxTouchRadius: Double = 70
    /// Ngón di chuyển quá xa trong lúc chạm thì không tính là chạm (chuẩn hóa).
    public var maxTapTravel: Double = 0.05
    /// Đảo bố cục cho người thuận tay trái (vùng khóa sang góc dưới phải).
    public var mirrored: Bool = false

    public init() {}

    public func contains(_ p: SIMD2<Double>) -> Bool {
        let xOK = mirrored
            ? (p.x >= 1 - edgeInset - width && p.x <= 1 - edgeInset)
            : (p.x >= edgeInset && p.x <= edgeInset + width)
        let yOK = p.y >= 1 - edgeInset - height && p.y <= 1 - edgeInset
        return xOK && yOK
    }

    /// Kiểm tra một lần chạm đã kết thúc có phải là "chạm khóa" hợp lệ.
    public func isLockTap(start: SIMD2<Double>, end: SIMD2<Double>,
                          duration: Double, maxRadius: Double) -> Bool {
        contains(start)
            && duration <= maxTapDuration
            && maxRadius <= maxTouchRadius
            && simd_distance_2(start, end) <= maxTapTravel
    }
}

@inline(__always)
func simd_distance_2(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
    let d = a - b
    return (d.x * d.x + d.y * d.y).squareRoot()
}
