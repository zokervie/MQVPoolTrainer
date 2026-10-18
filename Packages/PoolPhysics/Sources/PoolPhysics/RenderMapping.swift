import Foundation

/// Chuyển đổi tọa độ duy nhất giữa vật lý và hiển thị (PROGRESS R0.5).
///
/// - Vật lý: gốc ở một góc mặt chơi, x theo chiều dài, y theo chiều rộng, z hướng lên; mét, Double.
/// - RealityKit: gốc ở tâm mặt chơi, y hướng lên, hệ tay phải; mét, Float.
///
/// Phép đổi: (x, y, z)_vật lý → (x − L/2, z, −(y − W/2))_hiển thị.
/// Đây là phép quay −90° quanh trục x cộng phép tịnh tiến, nên giữ nguyên chiều tay phải.
public struct RenderMapping: Sendable {
    public let length: Double
    public let width: Double

    public init(table: TableSpec) {
        self.length = table.length
        self.width = table.width
    }

    public func toRender(_ p: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3(Float(p.x - length / 2), Float(p.z), Float(-(p.y - width / 2)))
    }

    public func toPhysics(_ r: SIMD3<Float>) -> SIMD3<Double> {
        SIMD3(Double(r.x) + length / 2, -Double(r.z) + width / 2, Double(r.y))
    }

    /// Hướng (vận tốc, trục quay): chỉ quay, không tịnh tiến.
    public func directionToRender(_ v: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3(Float(v.x), Float(v.z), Float(-v.y))
    }

    public func directionToPhysics(_ v: SIMD3<Float>) -> SIMD3<Double> {
        SIMD3(Double(v.x), -Double(v.z), Double(v.y))
    }
}
