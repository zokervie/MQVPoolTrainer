import Foundation
import simd

public enum MotionState: String, Codable, Sendable {
    case sliding, rolling, spinning, stationary, pocketed
}

/// Trạng thái động học của một bi. Tâm bi ở z = R; vận tốc chỉ trong mặt phẳng bàn
/// (nhảy bi làm sau).
public struct Ball: Codable, Equatable, Sendable {
    public var id: Int                     // 0 = bi cái
    public var position: SIMD3<Double>
    public var velocity: SIMD3<Double>
    public var angularVelocity: SIMD3<Double>
    public var state: MotionState

    public init(id: Int, position: SIMD3<Double>,
                velocity: SIMD3<Double> = .zero,
                angularVelocity: SIMD3<Double> = .zero) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.angularVelocity = angularVelocity
        self.state = .stationary
    }
}

public extension Ball {
    /// Vận tốc điểm tiếp xúc với nỉ: u = v + ω × (−R·ẑ).
    /// u = 0 nghĩa là bi lăn không trượt. Nguồn: Alciatore TP 4.1.
    func contactVelocity(radius R: Double) -> SIMD3<Double> {
        let u = velocity + cross(angularVelocity, SIMD3(0, 0, -R))
        return SIMD3(u.x, u.y, 0)
    }

    /// Phân loại trạng thái theo vận tốc hiện tại.
    func classified(radius R: Double, epsilon: Double = 1e-9) -> MotionState {
        if state == .pocketed { return .pocketed }
        if simd_length(contactVelocity(radius: R)) > epsilon { return .sliding }
        if simd_length(velocity) > epsilon { return .rolling }
        if abs(angularVelocity.z) > epsilon { return .spinning }
        return .stationary
    }
}
