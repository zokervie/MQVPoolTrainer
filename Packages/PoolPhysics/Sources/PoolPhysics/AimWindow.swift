import Foundation
import simd

/// Khoảng hướng ngắm đạt một mục tiêu cụ thể (docs/05-feedback.md).
/// Không giả định có một đường đánh đúng duy nhất: tìm *khoảng* góc ngắm (giữ nguyên lực và
/// điểm chạm người chơi đã dùng) mà mục tiêu đạt được.
public struct AimWindow: Equatable, Sendable {
    public var lower: Double   // radian
    public var upper: Double

    public var width: Double { upper - lower }
    public var center: Double { 0.5 * (lower + upper) }

    /// Khoảng cách góc (radian, có dấu) từ góc đã dùng tới khoảng; 0 nếu nằm trong.
    /// Dương: cần xoay ngắm ngược chiều kim đồng hồ (sang trái); âm: sang phải.
    public func error(for angle: Double) -> Double {
        if angle < lower { return lower - angle }
        if angle > upper { return upper - angle }
        return 0
    }

    /// Tìm khoảng gần góc đã dùng nhất.
    /// - Parameters:
    ///   - halfRange: phạm vi quét hai bên góc đã dùng (radian).
    ///   - step: bước quét thô; biên được tinh chỉnh bằng chia đôi.
    public static func search(simulation: Simulation, balls: [Ball], strike: CueStrike,
                              halfRange: Double = 0.14, step: Double = 0.002,
                              succeeds: (ShotResult) -> Bool) -> AimWindow? {
        func ok(_ angle: Double) -> Bool {
            var s = strike; s.aimAngle = angle
            return succeeds(simulation.run(balls: balls, strike: s))
        }
        let n = Int((2 * halfRange / step).rounded())
        let angles = (0...n).map { strike.aimAngle - halfRange + Double($0) * step }
        let results = angles.map(ok)

        // Các đoạn liên tiếp thành công.
        var runs: [(Int, Int)] = []
        var start: Int? = nil
        for k in results.indices {
            if results[k] { if start == nil { start = k } }
            else if let s = start { runs.append((s, k - 1)); start = nil }
        }
        if let s = start { runs.append((s, results.count - 1)) }
        guard !runs.isEmpty else { return nil }

        let used = strike.aimAngle
        let best = runs.min { a, b in
            distance(used, angles[a.0], angles[a.1]) < distance(used, angles[b.0], angles[b.1])
        }!

        func refine(_ good: Double, _ bad: Double) -> Double {
            var g = good, b = bad
            for _ in 0..<12 {
                let mid = 0.5 * (g + b)
                if ok(mid) { g = mid } else { b = mid }
            }
            return g
        }
        let lo = best.0 > 0 ? refine(angles[best.0], angles[best.0 - 1]) : angles[best.0]
        let hi = best.1 < angles.count - 1 ? refine(angles[best.1], angles[best.1 + 1]) : angles[best.1]
        return AimWindow(lower: lo, upper: hi)
    }

    private static func distance(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        x < lo ? lo - x : x > hi ? x - hi : 0
    }
}

// MARK: - Xếp bi và số ngẫu nhiên xác định

/// Bộ sinh số ngẫu nhiên xác định (SplitMix64) cho test và bài tập có lệch vị trí.
/// Không dùng `SystemRandomNumberGenerator` để kết quả lặp lại được theo seed.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// Số thực đều trong [0, 1).
    public mutating func unit() -> Double { Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0) }
}

public enum Rack {
    /// Tam giác bi chạm nhau, đỉnh tại `apex`, mở rộng theo hướng +x.
    /// `gap`: khe hở nhỏ giữa các bi (mét) để tránh chồng lấn do làm tròn.
    public static func triangle(apex: SIMD2<Double>, rows: Int = 5, radius R: Double,
                                gap: Double = 1e-6, firstId: Int = 1) -> [Ball] {
        var out: [Ball] = []
        var id = firstId
        let d = 2 * R + gap
        let rowStep = d * 3.0.squareRoot() / 2
        for row in 0..<rows {
            for k in 0...row {
                let x = apex.x + Double(row) * rowStep
                let y = apex.y + (Double(k) - Double(row) / 2) * d
                out.append(Ball(id: id, position: SIMD3(x, y, R)))
                id += 1
            }
        }
        return out
    }
}
