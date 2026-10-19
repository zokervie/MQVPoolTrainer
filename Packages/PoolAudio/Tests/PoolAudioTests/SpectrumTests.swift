import XCTest
import PoolPhysics
@testable import PoolAudio

/// Kiểm tra định lượng âm sắc (không thay được nghe thử): độ sáng (trọng tâm phổ) và độ dài
/// phải tăng theo lực; mỗi loại va chạm có dải tần riêng.
final class SpectrumTests: XCTestCase {

    /// Trọng tâm phổ (Hz) bằng DFT trực tiếp trên 4096 mẫu đầu (đủ cho tiếng va chạm ngắn).
    func spectralCentroid(_ x: [Float], sr: Double = 44_100) -> Double {
        let n = min(4096, x.count)
        var num = 0.0, den = 0.0
        for k in stride(from: 1, to: n / 2, by: 4) {
            var re = 0.0, im = 0.0
            for i in 0..<n {
                let w = 0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(n - 1))
                let a = 2 * .pi * Double(k * i) / Double(n)
                re += Double(x[i]) * w * cos(a); im -= Double(x[i]) * w * sin(a)
            }
            let mag = (re * re + im * im).squareRoot()
            num += Double(k) * sr / Double(n) * mag; den += mag
        }
        return den > 0 ? num / den : 0
    }

    /// Thời gian tới khi đường bao giảm 40 dB so với đỉnh (ms).
    func decayMs(_ x: [Float], sr: Double = 44_100) -> Double {
        let peak = x.map { abs($0) }.max() ?? 0
        let floor = peak * 0.01
        var last = 0
        for (i, v) in x.enumerated() where abs(v) > floor { last = i }
        return Double(last) / sr * 1000
    }

    /// Xung lực → giọng đã lên lịch → âm thanh sau bộ trộn (gồm lọc thông thấp và transient).
    func rendered(_ kind: CollisionKind, impulse: Double, speed: Double) -> [Float] {
        let e = AudioEvent(kind: kind, time: 0, position: SIMD3(1, 0.6, 0), relativeNormalSpeed: speed,
                           impulse: impulse, tangentialSlip: 0, materials: AudioEventBuilder.material(for: kind),
                           sourceIds: [0, 1], shotId: 1, index: 0)
        let voices = AudioScheduler().schedule([e], listener: ListenerPose(position: SIMD2(1, 0.6), yaw: 0), spatial: false)
        let out = OfflineRenderer().render(voices) { PlaceholderSynth.render($0) }
        return stride(from: 0, to: out.interleaved.count, by: 2).map { out.interleaved[$0] }
    }

    func testBrightnessRisesWithImpact() {
        var rows: [String] = []
        for kind in [CollisionKind.ballBall, .ballCushion, .cueTip] {
            let soft = rendered(kind, impulse: 0.02, speed: 0.2)
            let hard = rendered(kind, impulse: 1.0, speed: 5)
            let cs = spectralCentroid(soft), ch = spectralCentroid(hard)
            let ls = 20 * log10(Double(soft.map { abs($0) }.max() ?? 1e-9))
            let lh = 20 * log10(Double(hard.map { abs($0) }.max() ?? 1e-9))
            rows.append(String(format: "%@: soft centroid %.0f Hz, peak %.1f dBFS, decay %.0f ms | hard %.0f Hz, %.1f dBFS, %.0f ms",
                               kind.rawValue, cs, ls, decayMs(soft), ch, lh, decayMs(hard)))
            XCTAssertGreaterThan(ch, cs * 1.2, "\(kind): va chạm mạnh phải sáng hơn rõ rệt")
            XCTAssertGreaterThan(lh, ls + 15, "\(kind): va chạm mạnh phải to hơn")
        }
        print("REPORT: audio spectra:\n" + rows.map { "REPORT:   " + $0 }.joined(separator: "\n"))
    }

    /// Tiếng bi–bi phải khô, tắt nhanh như tiếng "cách" thật — không ngân như cụng ly
    /// (bản tổng hợp đầu tắt sau ~170 ms vì dùng sóng sin tắt chậm).
    func testBallClackIsShortNotRinging() {
        for impulse in [0.02, 0.3, 1.0] {
            let d = decayMs(rendered(.ballBall, impulse: impulse, speed: impulse / 0.17))
            XCTAssertLessThan(d, 40, "bi–bi xung \(impulse): tắt sau \(d) ms")
        }
    }

    /// Dải tần đặc trưng: bi–bi "tách" cao, băng "bịch" thấp.
    func testKindsHaveDistinctRegisters() {
        let bb = spectralCentroid(rendered(.ballBall, impulse: 0.3, speed: 2))
        let cu = spectralCentroid(rendered(.ballCushion, impulse: 0.3, speed: 2))
        XCTAssertGreaterThan(bb, 2 * cu, "bi–bi \(bb) Hz, băng \(cu) Hz")
    }
}
