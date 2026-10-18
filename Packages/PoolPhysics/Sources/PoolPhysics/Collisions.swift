import Foundation
import simd

/// Va chạm bi–bi lý tưởng (GIAI ĐOẠN 1: chưa có ma sát bi–bi, nên chưa có throw).
/// Hai bi cùng khối lượng: trao đổi thành phần vận tốc theo đường nối tâm, nhân hệ số phục hồi.
/// Vận tốc góc giữ nguyên (không có ma sát tiếp tuyến).
/// Nguồn: Alciatore TP 3.1 (90° rule).
///
/// TODO (Giai đoạn 2): thay bằng mô hình có ma sát bi–bi phụ thuộc tốc độ
/// (Alciatore TP A.14) để tạo throw do cắt và do xoáy ngang.
public enum BallBallCollision {
    public static func resolve(_ a: Ball, _ b: Ball, _ p: PhysicsParameters) -> (Ball, Ball) {
        var a2 = a, b2 = b
        var n = b.position - a.position
        n.z = 0
        let nHat = simd_normalize(n)
        let vRel = simd_dot(a.velocity - b.velocity, nHat)
        guard vRel > 0 else { return (a, b) } // đang tách ra
        let e = p.ballBallRestitution
        let j = (1 + e) / 2 * vRel
        a2.velocity = a.velocity - j * nHat
        b2.velocity = b.velocity + j * nHat
        return (a2, b2)
    }
}
