import UIKit

/// Texture vẽ bằng Core Graphics: bi, vải, gỗ, chữ số nút.
enum Textures {
    private static var ballCache: [Int: UIImage] = [:]
    private static var textCache: [String: UIImage] = [:]
    /// Texture theo pixel thật (không nhân ×3 theo màn hình) để tiết kiệm bộ nhớ.
    static let fmt1x: UIGraphicsImageRendererFormat = { let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = false; return f }()

    /// Bản đồ equirectangular 2:1 cho SCNSphere.
    static func ball(_ id: Int) -> UIImage {
        if let t = ballCache[id] { return t }
        let W: CGFloat = 1024, H: CGFloat = 512
        let ivory = UIColor(hex: BallColors.ivory)
        let img = UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: Textures.fmt1x).image { ctx in
            let g = ctx.cgContext
            if id == 0 {
                ivory.setFill(); g.fill(CGRect(x: 0, y: 0, width: W, height: H))
                // chấm đỏ để nhìn thấy xoáy
                UIColor(hex: 0xc1121f).setFill()
                for (u, v) in [(0.0, 0.5), (0.25, 0.5), (0.5, 0.5), (0.75, 0.5), (0.125, 0.18), (0.625, 0.82), (1.0, 0.5)] {
                    let w: CGFloat = v == 0.5 ? 26 : 26 / CGFloat(sin(Double.pi * v))
                    g.fillEllipse(in: CGRect(x: CGFloat(u) * W - w / 2, y: CGFloat(v) * H - 13, width: w, height: 26))
                }
                g.fill(CGRect(x: 0, y: 0, width: W, height: 10)); g.fill(CGRect(x: 0, y: H - 10, width: W, height: 10))
            } else {
                let col = UIColor(hex: BallColors.hex(id))
                if id > 8 {
                    ivory.setFill(); g.fill(CGRect(x: 0, y: 0, width: W, height: H))
                    col.setFill(); g.fill(CGRect(x: 0, y: H * 0.27, width: W, height: H * 0.46))
                } else { col.setFill(); g.fill(CGRect(x: 0, y: 0, width: W, height: H)) }
                for u in [0.25, 0.75] {
                    let x = CGFloat(u) * W, y = H / 2
                    ivory.setFill(); g.fillEllipse(in: CGRect(x: x - 68, y: y - 68, width: 136, height: 136))
                    let s = "\(id)" as NSString
                    let at: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: id > 9 ? 78 : 92, weight: .bold), .foregroundColor: UIColor(hex: 0x121212)]
                    let sz = s.size(withAttributes: at)
                    s.draw(at: CGPoint(x: x - sz.width / 2, y: y - sz.height / 2), withAttributes: at)
                    if id == 6 || id == 9 { UIColor(hex: 0x121212).setFill(); g.fill(CGRect(x: x - 22, y: y + 46, width: 44, height: 6)) }
                }
            }
        }
        ballCache[id] = img
        return img
    }

    /// Vải: nhiễu nhỏ nhuộm theo màu nỉ.
    static func cloth(_ hex: UInt32) -> UIImage {
        let S = 256
        let r = Double((hex >> 16) & 0xff), gr = Double((hex >> 8) & 0xff), b = Double(hex & 0xff)
        var px = [UInt8](repeating: 255, count: S * S * 4)
        for i in 0..<(S * S) {
            let n = (225 + Double.random(in: 0..<30) - Double((i % S) % 2) * 6) / 255
            px[i * 4] = UInt8(min(255, r * n)); px[i * 4 + 1] = UInt8(min(255, gr * n)); px[i * 4 + 2] = UInt8(min(255, b * n))
        }
        return image(px, S, S)
    }

    /// Vân gỗ đơn giản (sọc lượn + nhiễu).
    static func wood(_ hex: UInt32, w: Int = 512, h: Int = 512) -> UIImage {
        let r = Double((hex >> 16) & 0xff), gr = Double((hex >> 8) & 0xff), b = Double(hex & 0xff)
        var px = [UInt8](repeating: 255, count: w * h * 4)
        let ph = (0..<6).map { _ in Double.random(in: 0..<6.28) }
        for y in 0..<h { for x in 0..<w {
            let fx = Double(x) / Double(w), fy = Double(y) / Double(h)
            let warp = sin(fx * 9 + ph[0]) * 0.02 + sin(fx * 23 + ph[1]) * 0.008
            let ring = sin((fy + warp) * 160 + sin(fx * 3 + ph[2]) * 2)
            let k = 0.82 + 0.12 * ring + 0.06 * sin((fy + warp) * 37 + ph[3]) + Double.random(in: -0.03...0.03)
            let i = (y * w + x) * 4
            px[i] = UInt8(max(0, min(255, r * k))); px[i + 1] = UInt8(max(0, min(255, gr * k))); px[i + 2] = UInt8(max(0, min(255, b * k)))
        } }
        return image(px, w, h)
    }

    static func text(_ s: String, _ hex: UInt32) -> UIImage {
        let key = "\(s)#\(hex)"
        if let t = textCache[key] { return t }
        let S: CGFloat = 128
        let img = UIGraphicsImageRenderer(size: CGSize(width: S, height: S), format: Textures.fmt1x).image { _ in
            let at: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: s.count > 2 ? 60 : 80, weight: .heavy), .foregroundColor: UIColor(hex: hex),
                                                     .strokeColor: UIColor(white: 0, alpha: 0.55), .strokeWidth: -2.5]
            let ns = s as NSString, sz = ns.size(withAttributes: at)
            ns.draw(at: CGPoint(x: (S - sz.width) / 2, y: (S - sz.height) / 2), withAttributes: at)
        }
        textCache[key] = img
        return img
    }

    private static func image(_ px: [UInt8], _ w: Int, _ h: Int) -> UIImage {
        var data = px
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        return UIImage(cgImage: ctx.makeImage()!)
    }
}
