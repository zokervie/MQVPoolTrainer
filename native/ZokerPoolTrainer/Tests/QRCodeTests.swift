import Foundation
import CoreImage
import CoreGraphics

// 0.58: the home-made QR encoder is a real QR — an independent decoder (CIDetector, Mac only) reads back the payload, for several lengths.
@main enum QRCodeTests {
    static var checks = 0
    static func check(_ ok: Bool, _ msg: String) { checks += 1; if !ok { print("FAIL: \(msg)"); exit(1) } }
    static func image(_ qr: QRCode, scale: Int = 8, quiet: Int = 4) -> CGImage {
        let n = (qr.size + 2 * quiet) * scale
        let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray: 1, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: n, height: n)); ctx.setFillColor(gray: 0, alpha: 1)
        for r in 0..<qr.size { for c in 0..<qr.size where qr.modules[r][c] { ctx.fill(CGRect(x: (c + quiet) * scale, y: n - (r + quiet + 1) * scale, width: scale, height: scale)) } }
        return ctx.makeImage()!
    }
    static func main() {
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(options: [.useSoftwareRenderer: true]), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        let samples = ["zokerpool://daily", "A", "zokerpool://daily?day=41", String(repeating: "Zoker ", count: 10) + "Pool", "https://example.org/the-bi/0123456789"]
        for s in samples {
            guard let qr = QRCode(s) else { check(false, "encodes \(s.count) bytes"); continue }
            let found = detector.features(in: CIImage(cgImage: image(qr))).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            check(found.first == s, "CIDetector reads back \"\(s.prefix(24))\" (\(s.utf8.count) bytes, version \((qr.size - 17) / 4)): \(found)")
        }
        check(QRCode(String(repeating: "x", count: 200)) == nil, "too long for versions 1–5 → nil")
        print("PASS QRCode: \(checks) checks (read back by CIDetector)")
    }
}
