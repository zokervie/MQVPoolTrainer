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

/// Ngưỡng kỹ thuật chống Zeno (giả định, nhỏ hơn nhiều so với độ chính xác đo được):
/// - Lại gần nhanh hơn `minApproachSpeed`: va chạm thường (có nảy).
/// - Lại gần chậm hơn (tiếp xúc tựa nhau): chỉ xử lý khi lấn quá `penetration`; khi đó tách ra
///   `separationGap` và triệt thành phần vận tốc lấn vào (không nảy, bảo toàn động lượng).
/// Nhờ vậy độ chồng lấn bị chặn bởi `penetration` và số sự kiện tiếp xúc có giới hạn.
public enum CollisionThresholds {
    public static let minApproachSpeed = 1e-4   // m/s
    public static let penetration = 1e-7        // m
    public static let separationGap = 1e-5      // m
    /// Vận tốc nảy lên tối thiểu để coi là bi rời bàn (m/s). Nhỏ hơn: nỉ hấp thụ, bi nằm lại trên bàn
    /// (độ cao nảy < v²/2g ≈ 0,1 mm). Chặn chuỗi nảy vô hạn (Zeno) khi bi rơi xuống bàn.
    public static let minLiftSpeed = 0.045      // m/s
}

/// Va chạm bi với mặt đá (nỉ) khi bi bị ép xuống (cơ dốc) hoặc rơi xuống sau khi nhảy.
/// - Pháp tuyến: v_z' = −e_t·v_z (e_t = `tableRestitution`); nảy nhỏ hơn `minLiftSpeed` thì bỏ.
/// - Ma sát Coulomb tại điểm tiếp xúc đáy bi, giới hạn bởi lượng cần để hết trượt (Δu = 3,5·J/m):
///   đây là cơ chế tạo đường cong massé khi cơ dốc ép bi xuống bàn.
public enum SlateImpact {
    /// - Parameter friction: false cho cú ép xuống ngay lúc cơ chạm bi (xem `CueModel`).
    public static func resolve(_ b: Ball, _ p: PhysicsParameters, mass m: Double, radius R: Double,
                               friction: Bool = true) -> Ball {
        var out = b
        guard b.velocity.z < 0 else { return b }
        let vzIn = -b.velocity.z
        let jn = m * (1 + p.tableRestitution) * vzIn                 // xung pháp tuyến (lên)
        let u = b.contactVelocity(radius: R)                          // trượt tại đáy bi (ngang)
        let slip = simd_length(u)
        if friction, slip > 1e-12 {
            let jt = min(p.slidingFriction * jn, m * slip / 3.5)
            let impulse = -jt * (u / slip)
            out.velocity += impulse / m
            // r = −R·ẑ (đáy bi): Δω = r × J / I.
            out.angularVelocity += cross(SIMD3(0, 0, -R), impulse) / (0.4 * m * R * R)
        }
        let vzOut = p.tableRestitution * vzIn
        out.velocity.z = vzOut >= minLift ? vzOut : 0
        out.position.z = max(out.position.z, R)
        if out.velocity.z == 0 { out.position.z = R }
        out.state = out.classified(radius: R)
        return out
    }
    private static let minLift = CollisionThresholds.minLiftSpeed
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
        // Hai bi cùng nằm trên bàn: mô hình phẳng đã kiểm chứng (R1.7, pooltool) — n.z = 0, bỏ v_z.
        // Có bi đang bay (nhảy bi, thử nghiệm D4): pháp tuyến 3D, mặt bàn đỡ bi bị ép xuống.
        let grounded = a.position.z <= R + 1e-7 && b.position.z <= R + 1e-7
        var n = b.position - a.position
        if grounded { n.z = 0 }
        let nHat = simd_normalize(n)
        let vRel = simd_dot(a.velocity - b.velocity, nHat)
        guard vRel > 0 else { return ((a, b), nil) }
        if vRel < CollisionThresholds.minApproachSpeed {
            // Tiếp xúc tựa: cân bằng vận tốc pháp tuyến (không nảy), không tạo bản ghi va chạm.
            var a2 = a, b2 = b
            a2.velocity -= 0.5 * vRel * nHat
            b2.velocity += 0.5 * vRel * nHat
            a2.state = a2.classified(radius: R); b2.state = b2.classified(radius: R)
            return ((a2, b2), nil)
        }
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
        if grounded {
            a2.velocity.z = 0
            b2.velocity.z = 0
            a2.state = a2.classified(radius: R)
            b2.state = b2.classified(radius: R)
            return ((a2, b2), ImpactInfo(relativeNormalSpeed: vRel, normalImpulse: jn, tangentialSlip: slip))
        }
        // Bi đang nằm trên bàn mà bị ép xuống: mặt bàn đỡ (nảy/hấp thụ). Bi đang bay giữ v_z.
        if a2.position.z <= R + 1e-7, a2.velocity.z < 0 { a2 = SlateImpact.resolve(a2, p, mass: m, radius: R) }
        if b2.position.z <= R + 1e-7, b2.velocity.z < 0 { b2 = SlateImpact.resolve(b2, p, mass: m, radius: R) }
        if a2.position.z <= R + 1e-7, a2.velocity.z < CollisionThresholds.minLiftSpeed { a2.velocity.z = 0 }
        if b2.position.z <= R + 1e-7, b2.velocity.z < CollisionThresholds.minLiftSpeed { b2.velocity.z = 0 }
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
/// - Xung lực pháp tuyến theo hệ số phục hồi e(v) (giảm theo tốc độ lao vào băng); ma sát Coulomb giới hạn bởi lượng cần để hết trượt
///   (Δu_t = 3,5·J_t/m cho quả cầu đặc).
/// - Thành phần thẳng đứng của vận tốc sau va chạm bị bỏ (nỉ hấp thụ).
public enum CushionCollision {
    /// - Parameter inward: pháp tuyến ngang hướng từ băng vào trong bàn (đã chuẩn hóa).
    public static func resolve(_ ball: Ball, inward: SIMD2<Double>, cushionHeight h: Double,
                               _ p: PhysicsParameters, mass m: Double, radius R: Double) -> (Ball, ImpactInfo?) {
        let nh = SIMD3(inward.x, inward.y, 0)
        let approach = -simd_dot(ball.velocity, nh)
        guard approach > 0 else { return (ball, nil) }
        if approach < CollisionThresholds.minApproachSpeed {
            // Tiếp xúc tựa vào băng: bỏ thành phần lao vào, không nảy, không bản ghi.
            var out = ball
            out.velocity += approach * nh
            out.state = out.classified(radius: R)
            return (out, nil)
        }

        let sinT = max(-0.9, min(0.9, (h - R) / R))
        let cosT = (1 - sinT * sinT).squareRoot()
        // Vector từ tâm bi tới điểm tiếp xúc, và pháp tuyến tiếp xúc (từ băng vào tâm bi).
        let rc = -R * cosT * nh + R * sinT * SIMD3(0, 0, 1)
        let normal = -rc / R

        let uc = ball.velocity + cross(ball.angularVelocity, rc)
        let vn = simd_dot(uc, normal)          // < 0 khi bi đang lao vào băng
        guard vn < 0 else { return (ball, nil) }
        let jn = -(1 + p.cushionRestitution(atApproachSpeed: approach)) * m * vn

        let ut = uc - vn * normal
        let slip = simd_length(ut)
        var impulse = jn * normal
        if slip > 1e-12 {
            let magnitude = min(p.cushionFriction * jn, m * slip / 3.5)
            impulse -= magnitude * (ut / slip)
        }

        var out = ball
        out.velocity = ball.velocity + impulse / m
        // Bi trên bàn: bỏ thành phần đứng (nỉ hấp thụ). Bi đang bay: giữ v_z trước va chạm (như Han 2005).
        out.velocity.z = ball.position.z > R + 1e-7 ? ball.velocity.z : 0
        out.angularVelocity = ball.angularVelocity + cross(rc, impulse) / (0.4 * m * R * R)
        out.state = out.classified(radius: R)
        return (out, ImpactInfo(relativeNormalSpeed: -simd_dot(ball.velocity, nh), normalImpulse: jn, tangentialSlip: slip))
    }
}
