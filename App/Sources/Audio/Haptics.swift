import UIKit

/// Phản hồi rung (docs/02-controls.md) — thay chữ trên màn hình bằng cảm giác ở tay:
/// - chạm bi effect: tích nhẹ; kéo điểm chạm chạm vòng giới hạn trượt cơ: tích rõ hơn
/// - khóa: hai nhịp cứng; mở khóa: một nhịp mềm
/// - kéo lùi đủ đà: một tích nhẹ báo "sẵn sàng đẩy"
/// - cơ chạm bi: một nhịp, mạnh theo lực
/// Bộ tạo rung được `prepare()` trước để không trễ ở lần chạm đầu (iOS tắt Taptic Engine khi rảnh).
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let selection = UISelectionFeedbackGenerator()

    /// Gọi khi ngón vừa chạm màn hình: đánh thức Taptic Engine cho rung ngay sau đó.
    static func prepare() {
        rigid.prepare(); heavy.prepare(); soft.prepare(); light.prepare(); selection.prepare()
    }

    static func lock() {
        rigid.impactOccurred(intensity: 1.0)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            rigid.impactOccurred(intensity: 0.8)
        }
    }

    static func unlock() { soft.impactOccurred(intensity: 0.7) }

    /// Chạm vào bi effect.
    static func effectTouch() { selection.selectionChanged() }

    /// Kéo lùi đủ quãng lấy đà: có thể đẩy.
    static func readied() { light.impactOccurred(intensity: 0.6) }

    /// Cường độ theo tốc độ cơ (m/s).
    static func cueContact(speed: Double) {
        let i = min(1, max(0.35, speed / 5))
        heavy.impactOccurred(intensity: CGFloat(i))
    }

    /// Kéo điểm chạm quá vòng giới hạn.
    static func edge() { rigid.impactOccurred(intensity: 0.6) }
}
