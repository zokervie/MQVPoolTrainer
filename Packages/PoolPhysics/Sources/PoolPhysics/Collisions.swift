import Foundation
import simd

/// Kết quả vật lý của một va chạm, dùng cho bản ghi (`CollisionRecord`), âm thanh và haptic.
public struct ImpactInfo: Equatable, Sendable {
    /// Tốc độ tương đối theo pháp tuyến ngay trước va chạm (m/s, ≥ 0).
    public var relativeNormalSpeed: Double
    /// Độ lớn xung lực pháp tuyến (N·s).
    public var normalImpulse: Double
    /// Tốc độ trượt tiếp tuyến tại điểm tiếp xúc ngay trước va chạm (m/s).
    public var tangentialSlip: Double
}

/// Va chạm bi–bi có ma sát bề mặt (tạo throw do cắt và do xoáy).
///
/// Mô hình xung lực (Alciatore TP A.14; Marlow):
/// - Pháp tuyến: J_n = (1 + e)·m·v_rel,n / 2 (hai bi cùng khối lượng).
/// - Tiếp tuyến: J_t = min(μ(v)·J_n, m·|u_t|/7), ngược hướng trượt u_t tại điểm tiếp xúc.
///   Hệ số 7 = 2 × 3,5 (mỗi quả cầu đặc: Δu = J/m + R²J/I = 3,5·J/m).
/// - Thành phần thẳng đứng của vận tốc sau va chạm bị bỏ (bi không nhảy; nhảy bi chưa mô hình).
/// Với μ₀ = 0 (`ballBallFriction = 0`) mô hình trở về va chạm không ma sát.
public enum BallBallCollision {
    public static func resolve(_ a: Ball, _ b: Ball, _ p: PhysicsParameters,
                               mass m: Double = 0.17, radius R: Double = 0.028575) -> (Ball, Ball) {
        resolveWithInfo(a, b, p, mass: m, radius: R).0
    }

    public static func resolveWithInfo(_ a: Ball, _ b: Ball, _ p: PhysicsParameters,
                                       mass m: Double, radius R: Double) -> ((Ball, Ball), ImpactInfo?) {
        var n = b.position - a.position
        n.z = 0
        let nHat = simd_normalize(n)
        let vRel = simd_dot(a.velocity - b.velocity, nHat)
        guard vRel > 0 else { return ((a, b), nil) }

        let jn = (1 + p.ballBallRestitution) * m * vRel / 2

        // Vận tốc điểm tiếp xúc trên mỗi bi.
        let ra = R * nHat, rb = -R * nHat
        let ua = a.velocity + cross(a.angularVelocity, ra)
        let ub = b.velocity + cross(b.angularVelocity, rb)
        let u = ua - ub
        let ut = u - simd_dot(u, nHat) * nHat
        let slip = simd_length(ut)

        var jt = SIMD3<Double>.zero
        if slip > 1e-12 {
            let mu = p.ballBallFriction(atSlipSpeed: slip)
            let magnitude = min(mu * jn, m * slip / 7)
            jt = -magnitude * (ut / slip)
        }

        // Xung lực lên bi a: −J_n·n̂ + J_t ; lên bi b: ngược lại.
        let impulseA = -jn * nHat + jt
        let inertia = 0.4 * m * R * R
        var a2 = a, b2 = b
        a2.velocity = a.velocity + impulseA / m
        b2.velocity = b.velocity - impulseA / m
        a2.angularVelocity = a.angularVelocity + cross(ra, impulseA) / inertia
        b2.angularVelocity = b.angularVelocity + cross(rb, -impulseA) / inertia
        a2.velocity.z = 0
        b2.velocity.z = 0
        a2.state = a2.classified(radius: R)
        b2.state = b2.classified(radius: R)
        return ((a2, b2), ImpactInfo(relativeNormalSpeed: vRel, normalImpulse: jn, tangentialSlip: slip))
    }
}

/// Va chạm bi với băng hoặc mũi băng ở miệng lỗ.
///
/// Mô hình MVP (đơn giản hóa từ Mathavan et al. 2010 / Han 2005, **chưa đối chứng**):
/// - Điểm tiếp xúc ở độ cao mũi băng h (> R), nên pháp tuyến tiếp xúc nghiêng xuống một góc θ,
///   sin θ = (h − R)/R. Nhờ vậy xoáy trên/dưới và xoáy ngang đều ảnh hưởng tới đường bật.
/// - Xung lực pháp tuyến theo hệ số phục hồi e; ma sát Coulomb giới hạn bởi lượng cần để hết trượt
///   (Δu_t = 3,5·J_t/m cho quả cầu đặc).
/// - Thành phần thẳng đứng của vận tốc sau va chạm bị bỏ (nỉ hấp thụ).
public enum CushionCollision {
    /// - Parameter inward: pháp tuyến ngang hướng từ băng vào trong bàn (đã chuẩn hóa).
    public static func resolve(_ ball: Ball, inward: SIMD2<Double>, cushionHeight h: Double,
                               _ p: PhysicsParameters, mass m: Double, radius R: Double) -> (Ball, ImpactInfo?) {
        let nh = SIMD3(inward.x, inward.y, 0)
        guard simd_dot(ball.velocity, nh) < 0 else { return (ball, nil) }

        let sinT = max(-0.9, min(0.9, (h - R) / R))
        let cosT = (1 - sinT * sinT).squareRoot()
        // Vector từ tâm bi tới điểm tiếp xúc, và pháp tuyến tiếp xúc (từ băng vào tâm bi).
        let rc = -R * cosT * nh + R * sinT * SIMD3(0, 0, 1)
        let normal = -rc / R

        let uc = ball.velocity + cross(ball.angularVelocity, rc)
        let vn = simd_dot(uc, normal)          // < 0 khi bi đang lao vào băng
        guard vn < 0 else { return (ball, nil) }
        let jn = -(1 + p.cushionRestitution) * m * vn

        let ut = uc - vn * normal
        let slip = simd_length(ut)
        var impulse = jn * normal
        if slip > 1e-12 {
            let magnitude = min(p.cushionFriction * jn, m * slip / 3.5)
            impulse -= magnitude * (ut / slip)
        }

        var out = ball
        out.velocity = ball.velocity + impulse / m
        out.velocity.z = 0
        out.angularVelocity = ball.angularVelocity + cross(rc, impulse) / (0.4 * m * R * R)
        out.state = out.classified(radius: R)
        return (out, ImpactInfo(relativeNormalSpeed: -simd_dot(ball.velocity, nh), normalImpulse: jn, tangentialSlip: slip))
    }
}
