import UIKit

/// Phản hồi rung (docs/02-controls.md): khóa và mở khóa khác nhau, cơ chạm bi theo lực.
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let light = UIImpactFeedbackGenerator(style: .light)

    static func lock() { rigid.impactOccurred(intensity: 1.0) }

    static func unlock() {
        soft.impactOccurred(intensity: 0.6)
    }

    /// Cường độ theo tốc độ cơ (m/s).
    static func cueContact(speed: Double) {
        let i = min(1, max(0.2, speed / 6))
        rigid.impactOccurred(intensity: CGFloat(i))
    }

    /// Kéo điểm chạm quá vòng giới hạn.
    static func edge() { light.impactOccurred(intensity: 0.5) }
}
