import Foundation

/// Đa thức bậc thấp (≤ 4) và tìm nghiệm thực trong một khoảng.
///
/// Không dùng công thức Ferrari/Cardano (kém ổn định số ở nghiệm kép, ví dụ va chạm sượt).
/// Cách làm: cô lập nghiệm bằng các điểm tới hạn (nghiệm của đạo hàm, tính đệ quy),
/// trong mỗi đoạn đơn điệu thì chia đôi. Kết quả xác định: không có ngẫu nhiên.
/// Hệ số theo thứ tự tăng dần: c[0] + c[1]·t + c[2]·t² + …
public enum Polynomial {

    public static func evaluate(_ c: [Double], _ t: Double) -> Double {
        var r = 0.0
        for k in stride(from: c.count - 1, through: 0, by: -1) { r = r * t + c[k] }
        return r
    }

    public static func derivative(_ c: [Double]) -> [Double] {
        guard c.count > 1 else { return [] }
        return (1..<c.count).map { Double($0) * c[$0] }
    }

    /// Bỏ các hệ số bậc cao gần bằng 0 so với hệ số lớn nhất.
    static func trimmed(_ c: [Double]) -> [Double] {
        let scale = c.map(abs).max() ?? 0
        guard scale > 0 else { return [] }
        var out = c
        while let last = out.last, abs(last) <= 1e-15 * scale { out.removeLast() }
        return out
    }

    /// Mọi nghiệm thực trong [lo, hi], tăng dần.
    public static func realRoots(_ coefficients: [Double], in lo: Double, _ hi: Double) -> [Double] {
        guard hi >= lo else { return [] }
        let c = trimmed(coefficients)
        let degree = c.count - 1
        if degree <= 0 { return [] }
        if degree == 1 {
            let r = -c[0] / c[1]
            return (r >= lo && r <= hi) ? [r] : []
        }
        let critical = realRoots(derivative(c), in: lo, hi)
        let points = [lo] + critical + [hi]
        var roots: [Double] = []
        for k in 0..<(points.count - 1) {
            let a = points[k], b = points[k + 1]
            let fa = evaluate(c, a), fb = evaluate(c, b)
            if fa == 0 {
                roots.append(a)
            } else if fa * fb < 0 {
                roots.append(bisect(c, a, b, fa))
            }
            if k == points.count - 2, fb == 0 { roots.append(b) }
        }
        // Gộp nghiệm trùng (nghiệm nằm đúng điểm tới hạn có thể xuất hiện hai lần).
        var unique: [Double] = []
        for r in roots.sorted() where unique.last.map({ abs($0 - r) > 1e-13 * (1 + abs(r)) }) ?? true {
            unique.append(r)
        }
        return unique
    }

    private static func bisect(_ c: [Double], _ a0: Double, _ b0: Double, _ fa0: Double) -> Double {
        var a = a0, b = b0, fa = fa0
        for _ in 0..<200 {
            let m = 0.5 * (a + b)
            if m <= a || m >= b { break }
            let fm = evaluate(c, m)
            if fm == 0 { return m }
            if (fa < 0) == (fm < 0) { a = m; fa = fm } else { b = m }
        }
        return 0.5 * (a + b)
    }
}
