import Foundation
import simd

/// Hình học va chạm suy ra từ `TableSpec` (mô hình MVP, đơn giản hóa — ghi rõ giới hạn):
/// - Băng: bốn đường thẳng tại mép mặt chơi (x = 0, x = L, y = 0, y = W); bi chạm khi tâm cách đường R.
///   Băng bị cắt ở các miệng lỗ.
/// - Lỗ góc: miệng 45°, độ rộng miệng `cornerPocketMouth` đo giữa hai mũi băng.
///   Mũi băng cách góc a = mouth/√2 dọc mỗi băng.
/// - Lỗ giữa: khe rộng `sidePocketMouth` ở giữa hai băng dài.
/// - Mũi băng ở miệng lỗ (jaw): điểm cố định; bi va vào điểm khi tâm cách điểm R.
/// - Bi rơi lỗ khi tâm vượt qua đường bắt giữ phía sau miệng lỗ.
/// Chưa mô hình: mặt vát của miệng lỗ, độ sâu thành lỗ, bi nảy ra khỏi lỗ.
public struct TableGeometry: Sendable {
    public let length: Double
    public let width: Double
    public let ballRadius: Double
    /// Khoảng cách từ góc đến mũi băng dọc mỗi băng (lỗ góc).
    public let cornerSetback: Double
    public let sideHalfMouth: Double
    public let cushions: [CushionSegment]
    public let jaws: [SIMD2<Double>]
    public let pockets: [Pocket]

    public struct CushionSegment: Sendable {
        /// 0: y = 0 (dưới), 1: y = W (trên), 2: x = 0 (trái), 3: x = L (phải).
        public let rail: Int
        public let from: Double   // khoảng dọc theo băng (theo x với băng ngang, theo y với băng dọc)
        public let to: Double
        /// Pháp tuyến hướng vào trong bàn.
        public var inwardNormal: SIMD2<Double> {
            switch rail {
            case 0: SIMD2(0, 1)
            case 1: SIMD2(0, -1)
            case 2: SIMD2(1, 0)
            default: SIMD2(-1, 0)
            }
        }
    }

    public struct Pocket: Sendable, Equatable {
        public let id: Int          // 0..5
        public let name: String     // "goc_duoi_trai", …
        /// Tâm lỗ (để hiển thị), mét.
        public let center: SIMD2<Double>
        /// Bắt giữ khi w·p + k ≤ 0 (w hướng vào trong bàn).
        public let captureNormal: SIMD2<Double>
        public let captureOffset: Double
    }

    public init(_ t: TableSpec) {
        let L = t.length, W = t.width, R = t.ballRadius
        length = L; width = W; ballRadius = R
        let a = t.cornerPocketMouth / 2.0.squareRoot()
        let h = t.sidePocketMouth / 2
        cornerSetback = a
        sideHalfMouth = h
        cushions = [
            CushionSegment(rail: 0, from: a, to: L / 2 - h),
            CushionSegment(rail: 0, from: L / 2 + h, to: L - a),
            CushionSegment(rail: 1, from: a, to: L / 2 - h),
            CushionSegment(rail: 1, from: L / 2 + h, to: L - a),
            CushionSegment(rail: 2, from: a, to: W - a),
            CushionSegment(rail: 3, from: a, to: W - a)
        ]
        jaws = [
            SIMD2(a, 0), SIMD2(0, a),                 // góc dưới trái
            SIMD2(L - a, 0), SIMD2(L, a),             // góc dưới phải
            SIMD2(a, W), SIMD2(0, W - a),             // góc trên trái
            SIMD2(L - a, W), SIMD2(L, W - a),         // góc trên phải
            SIMD2(L / 2 - h, 0), SIMD2(L / 2 + h, 0), // giữa dưới
            SIMD2(L / 2 - h, W), SIMD2(L / 2 + h, W)  // giữa trên
        ]
        // Đường bắt giữ lỗ góc: tâm bi vượt qua đường song song với miệng lỗ, lùi vào trong lỗ 0,5R.
        // Miệng lỗ góc dưới trái là đường x + y = a; chuẩn hóa theo √2.
        let s = 1 / 2.0.squareRoot()
        let cornerK = -(a - 0.5 * R) * s
        pockets = [
            Pocket(id: 0, name: "goc_duoi_trai", center: SIMD2(0, 0), captureNormal: SIMD2(s, s), captureOffset: cornerK),
            Pocket(id: 1, name: "goc_duoi_phai", center: SIMD2(L, 0), captureNormal: SIMD2(-s, s), captureOffset: cornerK + L * s),
            Pocket(id: 2, name: "goc_tren_trai", center: SIMD2(0, W), captureNormal: SIMD2(s, -s), captureOffset: cornerK + W * s),
            Pocket(id: 3, name: "goc_tren_phai", center: SIMD2(L, W), captureNormal: SIMD2(-s, -s), captureOffset: cornerK + (L + W) * s),
            // Lỗ giữa: bắt giữ khi tâm bi vượt qua đường băng (y = 0 hoặc y = W).
            Pocket(id: 4, name: "giua_duoi", center: SIMD2(L / 2, 0), captureNormal: SIMD2(0, 1), captureOffset: 0),
            Pocket(id: 5, name: "giua_tren", center: SIMD2(L / 2, W), captureNormal: SIMD2(0, -1), captureOffset: W)
        ]
    }

    /// Lỗ giữa chỉ bắt giữ khi bi nằm trong khe miệng lỗ.
    func sidePocketAccepts(_ id: Int, x: Double) -> Bool {
        id < 4 || abs(x - length / 2) <= sideHalfMouth
    }
}
