import UIKit
import CoreGraphics

/// Texture bi (equirectangular) vẽ bằng CoreGraphics: màu chuẩn, sọc cho bi 9–15, số rõ,
/// bi cái có chấm đỏ để nhìn thấy xoáy và tốc độ quay (docs/03-camera-graphics.md).
@MainActor
enum BallTextures {
    static let colors: [Int: UIColor] = [
        1: UIColor(red: 0.98, green: 0.80, blue: 0.10, alpha: 1),
        2: UIColor(red: 0.10, green: 0.25, blue: 0.75, alpha: 1),
        3: UIColor(red: 0.85, green: 0.12, blue: 0.10, alpha: 1),
        4: UIColor(red: 0.40, green: 0.15, blue: 0.55, alpha: 1),
        5: UIColor(red: 0.98, green: 0.45, blue: 0.08, alpha: 1),
        6: UIColor(red: 0.05, green: 0.50, blue: 0.25, alpha: 1),
        7: UIColor(red: 0.50, green: 0.10, blue: 0.10, alpha: 1),
        8: UIColor(white: 0.05, alpha: 1)
    ]

    static func image(for number: Int, size: Int = 512) -> CGImage? {
        let w = size, h = size / 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h),
                                               format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        let img = renderer.image { ctx in
            let c = ctx.cgContext
            let ivory = UIColor(red: 0.97, green: 0.96, blue: 0.92, alpha: 1)
            if number == 0 {
                c.setFillColor(ivory.cgColor)
                c.fill(CGRect(x: 0, y: 0, width: w, height: h))
                // Chấm đỏ phân bố đều để thấy xoáy theo mọi trục.
                c.setFillColor(UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1).cgColor)
                let dots: [(Double, Double)] = [(0, 0.5), (0.25, 0.5), (0.5, 0.5), (0.75, 0.5),
                                                (0.125, 0.2), (0.625, 0.2), (0.375, 0.8), (0.875, 0.8)]
                for (u, v) in dots {
                    let r = Double(h) * 0.05
                    c.fillEllipse(in: CGRect(x: u * Double(w) - r, y: v * Double(h) - r, width: 2 * r, height: 2 * r))
                }
                return
            }
            let base = colors[number > 8 ? number - 8 : number] ?? .gray
            if number > 8 {
                c.setFillColor(ivory.cgColor)
                c.fill(CGRect(x: 0, y: 0, width: w, height: h))
                c.setFillColor(base.cgColor)
                c.fill(CGRect(x: 0, y: Double(h) * 0.28, width: Double(w), height: Double(h) * 0.44))
            } else {
                c.setFillColor(base.cgColor)
                c.fill(CGRect(x: 0, y: 0, width: w, height: h))
            }
            // Hai vòng số ở hai phía.
            for u in [0.25, 0.75] {
                let r = Double(h) * 0.16
                let center = CGPoint(x: u * Double(w), y: Double(h) / 2)
                c.setFillColor(ivory.cgColor)
                c.fillEllipse(in: CGRect(x: center.x - r * 0.75, y: center.y - r, width: 1.5 * r, height: 2 * r))
                let text = "\(number)" as NSString
                let font = UIFont.systemFont(ofSize: r * 1.1, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                let s = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: center.x - s.width / 2, y: center.y - s.height / 2), withAttributes: attrs)
            }
        }
        return img.cgImage
    }
}
