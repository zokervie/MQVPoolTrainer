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
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()

    /// Gọi khi ngón vừa chạm màn hình: đánh thức Taptic Engine cho rung ngay sau đó.
    static func prepare() {
        rigid.prepare(); heavy.prepare(); soft.prepare(); light.prepare(); medium.prepare(); selection.prepare()
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

    /// Nấc kéo lùi: mỗi 8 mm kéo lùi một tích, càng lùi sâu càng rõ — mốc cảm giác để lặp lại cú vuốt.
    static func pullTick(_ n: Int) {
        light.impactOccurred(intensity: CGFloat(min(1, 0.3 + 0.12 * Double(n))))
    }

    /// Cơ chạm bi: ba "chất" rung theo dải lực (nhẹ → mềm, vừa → chắc, mạnh → nặng), cường độ tăng liên tục
    /// theo căn bậc hai tốc độ cơ — phân biệt được nhiều mức lực bằng tay, không cần chữ.
    static func cueContact(speed: Double) {
        let i = CGFloat(min(1, 0.3 + 0.7 * (speed / 6).squareRoot()))
        switch speed {
        case ..<1.2: soft.impactOccurred(intensity: i)
        case ..<3: medium.impactOccurred(intensity: i)
        default: heavy.impactOccurred(intensity: i)
        }
    }

    /// Kéo điểm chạm quá vòng giới hạn.
    static func edge() { rigid.impactOccurred(intensity: 0.6) }
}
