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

    public static func render(_ id: SampleID, sampleRate sr: Double = 44_100) -> [Float] {
        var rng = SplitMix64(seed: UInt64(id.layer * 97 + id.variant * 7919) &+ UInt64(CollisionKind.allCases.firstIndex(of: id.kind)!) &* 131)
        let level = Double(id.layer) / 4           // 0…1 theo lớp lực
        let detune = 1 + 0.025 * (Double(id.variant) - 1.5)
        let partials: [(f: Double, a: Double, decay: Double)]
        var noiseAmp = 0.0, noiseDecay = 0.004, length = 0.25
        var knocks: [Double] = [0]

        switch id.kind {
        case .ballBall:
            // Phổ kích thích theo thời gian tiếp xúc Hertz: va chạm mạnh → tiếp xúc ngắn → nhiều cao tần.
            let tau = ballBallContactTime(level: level)
            let raw: [(f: Double, a: Double, decay: Double)] = [(3_150, 1.0, 0.030), (5_050, 0.6 * (0.4 + level), 0.020), (7_900, 0.35 * level, 0.012), (1_200, 0.25, 0.05)]
            partials = raw.map { (f: $0.f, a: $0.a * halfSinePulseGain($0.f, tau: tau), decay: $0.decay) }
            noiseAmp = (0.25 + 0.5 * level) * halfSinePulseGain(4_000, tau: tau); noiseDecay = 0.0015; length = 0.18
        case .ballCushion:
            partials = [(170, 1.0, 0.05), (430, 0.6, 0.035), (1_100, 0.25 * (0.5 + level), 0.015)]
            noiseAmp = 0.15 + 0.25 * level; noiseDecay = 0.004; length = 0.22
        case .cueTip:
            partials = [(1_250, 1.0, 0.025), (2_600, 0.5 * (0.5 + level), 0.015), (420, 0.4, 0.04)]
            noiseAmp = 0.2 + 0.3 * level; noiseDecay = 0.002; length = 0.18
        case .ballJaw:
            partials = [(900, 1.0, 0.04), (2_100, 0.55, 0.02), (260, 0.5, 0.06)]
            noiseAmp = 0.2 + 0.3 * level; noiseDecay = 0.003; length = 0.25
        case .ballDrop:
            partials = [(140, 1.0, 0.06), (360, 0.5, 0.04)]
            noiseAmp = 0.15; noiseDecay = 0.006; length = 0.6
            knocks = [0, 0.11, 0.21, 0.32]
        case .miscue:
            partials = [(2_800, 0.3, 0.05)]
            noiseAmp = 0.9; noiseDecay = 0.06; length = 0.2
        }

        let n = Int(length * sr)
        var out = [Float](repeating: 0, count: n)
        for (k, start) in knocks.enumerated() {
            let gainK = pow(0.55, Double(k))
            let s0 = Int(start * sr)
            for i in s0..<n {
                let t = Double(i - s0) / sr
                var x = 0.0
                for p in partials { x += p.a * exp(-t / p.decay) * sin(2 * .pi * p.f * detune * t) }
                x += noiseAmp * exp(-t / noiseDecay) * (rng.unit() * 2 - 1)
                out[i] += Float(gainK * x)
            }
        }
        // Chuẩn hóa đỉnh về 0,9.
        let peak = out.map { abs($0) }.max() ?? 1
        if peak > 0 { for i in out.indices { out[i] *= 0.9 / peak } }
        return out
    }
}
