import Foundation
import PoolPhysics

/// Tổng hợp mẫu tạm cho R2 (mono, Float, −1…1). Xác định hoàn toàn theo (loại, lớp, biến thể).
/// Đây là âm thanh **thay thế**, chỉ để kiến trúc chạy được; sẽ thay bằng bản thu bàn thật ở R7.
public enum PlaceholderSynth {

    /// Thời gian tiếp xúc bi–bi (s) ở lớp lực `level` (0…1).
    /// Giả định: ~250 µs ở 1 m/s (bậc độ lớn thường dẫn cho bi phenolic), tỉ lệ v^(−1/5) theo lý thuyết
    /// tiếp xúc Hertz; lớp 0…1 ứng với tốc độ pháp tuyến 0,03…9 m/s (thang log, khớp AcousticMapping).
    static func ballBallContactTime(level: Double) -> Double {
        let v = 0.03 * pow(300, level)
        return 250e-6 * pow(v, -0.2)
    }

    /// Biên độ phổ (chuẩn hóa, = 1 tại 0 Hz) của xung lực dạng nửa sin, độ dài `tau`.
    static func halfSinePulseGain(_ f: Double, tau: Double) -> Double {
        let x = 2 * f * tau
        if abs(1 - x) < 1e-6 { return .pi / 4 }
        return abs(cos(.pi * f * tau)) / abs(1 - x * x)
    }

    /// Một dải cộng hưởng: tần số tâm (Hz), độ sắc Q, biên độ (sau khi chuẩn hóa RMS của dải).
    struct Band { var f: Double; var q: Double; var a: Double }

    /// Thông số tổng hợp mỗi loại va chạm (âm thanh tạm, chỉnh theo bản thu bàn thật ở R7).
    /// Nguyên tắc: xung nhiễu rất ngắn (thời gian tiếp xúc) qua bộ lọc cộng hưởng Q thấp → tiếng "cách" khô,
    /// không có sóng sin kéo dài (bản đầu dùng sin tắt chậm 30–50 ms nên nghe như cụng ly).
    struct Voice {
        var tau: Double          // hằng số tắt của xung kích thích (s)
        var length: Double       // độ dài mẫu (s)
        var hertz: Bool          // phổ kích thích theo thời gian tiếp xúc Hertz (bi–bi)
        var pivot: Double        // tần số trục nghiêng phổ (Hz)
        var tilt: (Double, Double) // số mũ nghiêng phổ = tilt.0 + tilt.1·lực: nhẹ → tối, mạnh → sáng
        var knocks: [Double]
        var bands: (Double) -> [Band]
    }

    static func voice(_ kind: CollisionKind) -> Voice {
        switch kind {
        case .ballBall:
            return Voice(tau: 0.0012, length: 0.09, hertz: true, pivot: 2300, tilt: (-1.5, 2.5), knocks: [0]) { l in
                [Band(f: 1150, q: 3, a: 0.9 * (1 - l) + 0.25), Band(f: 2300, q: 2, a: 1),
                 Band(f: 4300, q: 2.5, a: 0.25 + 0.8 * l), Band(f: 6800, q: 2.5, a: 0.05 + 0.5 * l)]
            }
        case .ballCushion:
            return Voice(tau: 0.006, length: 0.25, hertz: false, pivot: 420, tilt: (-1, 2), knocks: [0]) { l in
                [Band(f: 160, q: 1.2, a: 1), Band(f: 420, q: 1.5, a: 0.5), Band(f: 1100, q: 2, a: 0.25 * (0.4 + l))]
            }
        case .cueTip:
            // Đầu da trên bi: "cốc" trầm ~0,9 kHz + tiếng gỗ thân cơ ~175 Hz.
            return Voice(tau: 0.0025, length: 0.12, hertz: false, pivot: 900, tilt: (-0.5, 1.3), knocks: [0]) { l in
                [Band(f: 880, q: 1.6, a: 1), Band(f: 1900, q: 2, a: 0.45 * (0.4 + l)),
                 Band(f: 3600, q: 2, a: 0.25 * l), Band(f: 175, q: 3, a: 0.12)]
            }
        case .ballJaw:
            return Voice(tau: 0.003, length: 0.15, hertz: false, pivot: 700, tilt: (-0.8, 1.6), knocks: [0]) { _ in
                [Band(f: 700, q: 3, a: 1), Band(f: 1600, q: 3, a: 0.5), Band(f: 260, q: 2, a: 0.4)]
            }
        case .ballDrop:
            return Voice(tau: 0.004, length: 0.6, hertz: false, pivot: 300, tilt: (-0.5, 1), knocks: [0, 0.11, 0.21, 0.32]) { _ in
                [Band(f: 130, q: 2, a: 1), Band(f: 320, q: 2, a: 0.6), Band(f: 900, q: 3, a: 0.2)]
            }
        case .miscue:
            return Voice(tau: 0.04, length: 0.2, hertz: false, pivot: 3000, tilt: (0, 0), knocks: [0]) { _ in
                [Band(f: 2800, q: 1, a: 0.5), Band(f: 5000, q: 1, a: 0.4)]
            }
        }
    }

    /// Lọc thông dải RBJ (đỉnh 0 dB), hai tầng nối tiếp để dốc hơn.
    static func bandpass(_ x: [Double], f: Double, q: Double, sr: Double) -> [Double] {
        let w0 = 2 * Double.pi * f / sr, alpha = sin(w0) / (2 * q), c = cos(w0)
        let a0 = 1 + alpha, b0 = alpha / a0, b2 = -alpha / a0, a1 = -2 * c / a0, a2 = (1 - alpha) / a0
        var y = x
        for _ in 0..<2 {
            var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
            for i in y.indices {
                let xi = y[i]
                let v = b0 * xi + b2 * x2 - a1 * y1 - a2 * y2
                x2 = x1; x1 = xi; y2 = y1; y1 = v
                y[i] = v
            }
        }
        return y
    }

    public static func render(_ id: SampleID, sampleRate sr: Double = 44_100) -> [Float] {
        var rng = SplitMix64(seed: UInt64(id.layer * 97 + id.variant * 7919) &+ UInt64(CollisionKind.allCases.firstIndex(of: id.kind)!) &* 131)
        let level = Double(id.layer) / 4           // 0…1 theo lớp lực
        let detune = 1 + 0.02 * (Double(id.variant) - 1.5)
        let v = voice(id.kind)
        let n = Int(v.length * sr)
        // Va chạm mạnh: kích thích ngắn hơn (tiếp xúc ngắn) → nhiều cao tần.
        let tau = v.tau * (1.25 - 0.5 * level)
        var exc = [Double](repeating: 0, count: n)
        for (k, start) in v.knocks.enumerated() {
            let gain = pow(0.55, Double(k)), s0 = Int(start * sr)
            for i in s0..<n {
                let t = Double(i - s0) / sr
                if t > 12 * tau { break }
                exc[i] += gain * (rng.unit() * 2 - 1) * exp(-t / tau) * min(1, t / 0.0001)
            }
        }
        let contact = ballBallContactTime(level: level)
        var out = [Double](repeating: 0, count: n)
        for band in v.bands(level) {
            var g = v.hertz ? halfSinePulseGain(band.f, tau: contact) : 1
            g *= pow(band.f / v.pivot, v.tilt.0 + v.tilt.1 * level)
            let y = bandpass(exc, f: band.f * detune, q: band.q, sr: sr)
            let rms = (y.reduce(0) { $0 + $1 * $1 } / Double(max(1, n))).squareRoot()
            guard rms > 1e-12 else { continue }
            let k = band.a * g / rms
            for i in 0..<n { out[i] += k * y[i] }
        }
        // Chuẩn hóa đỉnh về 0,9.
        let peak = out.map { abs($0) }.max() ?? 1
        return out.map { Float(peak > 0 ? $0 * 0.9 / peak : 0) }
    }
}
