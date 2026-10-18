import Foundation
import simd

/// Chuyển động tự do của một bi trên nỉ, giải dạng đóng (không tích phân số).
/// Dùng cho mô phỏng theo sự kiện: tính thời điểm chuyển trạng thái kế tiếp và
/// trạng thái tại thời điểm bất kỳ trước đó.
///
/// Nguồn công thức: D. Alciatore, "Technical Proofs" TP 4.1–4.2;
/// L. Leckie & M. Greenspan, "An Event-Based Pool Physics Simulator" (2006).
public enum FreeMotion {

    private static let zHat = SIMD3<Double>(0, 0, 1)

    /// Thời điểm (s) bi đổi trạng thái chuyển động, tính từ hiện tại.
    /// - sliding → rolling: t = 2|u| / (7·μs·g)
    /// - rolling → spinning/stationary: t = |v| / (μr·g)
    /// - spinning → stationary: t = 2R|ωz| / (5·μsp·g)
    public static func timeToTransition(_ b: Ball, _ p: PhysicsParameters, radius R: Double) -> Double? {
        let g = p.gravity
        switch b.classified(radius: R) {
        case .sliding:
            return 2 * simd_length(b.contactVelocity(radius: R)) / (7 * p.slidingFriction * g)
        case .rolling:
            return simd_length(b.velocity) / (p.rollingResistance * g)
        case .spinning:
            return 2 * R * abs(b.angularVelocity.z) / (5 * p.spinFriction * g)
        case .stationary, .pocketed:
            return nil
        }
    }

    /// Trạng thái bi sau thời gian t, với điều kiện t không vượt quá `timeToTransition`.
    public static func evolve(_ b: Ball, by t: Double, _ p: PhysicsParameters, radius R: Double) -> Ball {
        let g = p.gravity
        var out = b
        let state = b.classified(radius: R)

        // Xoay quanh trục đứng giảm tuyến tính, độc lập với chuyển động ngang.
        let wz = b.angularVelocity.z
        let dwz = 5 * p.spinFriction * g / (2 * R) * t
        let newWz = abs(wz) <= dwz ? 0 : wz - (wz > 0 ? dwz : -dwz)

        switch state {
        case .sliding:
            // Lực ma sát ngược hướng u, hướng u không đổi trong pha trượt.
            let u = b.contactVelocity(radius: R)
            let uHat = simd_normalize(u)
            let mu = p.slidingFriction
            out.position = b.position + b.velocity * t - 0.5 * mu * g * t * t * uHat
            out.velocity = b.velocity - mu * g * t * uHat
            let dw = (5 * mu * g / (2 * R)) * t * cross(zHat, uHat)
            out.angularVelocity = SIMD3(b.angularVelocity.x + dw.x,
                                        b.angularVelocity.y + dw.y,
                                        newWz)

        case .rolling:
            let vHat = simd_normalize(b.velocity)
            let a = p.rollingResistance * g
            out.position = b.position + b.velocity * t - 0.5 * a * t * t * vHat
            out.velocity = b.velocity - a * t * vHat
            // Giữ điều kiện lăn: ω_xy = (ẑ × v) / R.
            let wxy = cross(zHat, out.velocity) / R
            out.angularVelocity = SIMD3(wxy.x, wxy.y, newWz)

        case .spinning:
            out.angularVelocity = SIMD3(0, 0, newWz)

        case .stationary, .pocketed:
            break
        }

        out.state = out.classified(radius: R)
        return out
    }

    /// Đưa bi tới đúng thời điểm chuyển trạng thái và làm sạch sai số làm tròn.
    public static func advanceToTransition(_ b: Ball, _ p: PhysicsParameters, radius R: Double) -> (Ball, Double)? {
        guard let t = timeToTransition(b, p, radius: R) else { return nil }
        var next = evolve(b, by: t, p, radius: R)
        switch b.classified(radius: R) {
        case .sliding:
            // Ép đúng điều kiện lăn để tránh sai số trôi.
            let wxy = cross(zHat, next.velocity) / R
            next.angularVelocity = SIMD3(wxy.x, wxy.y, next.angularVelocity.z)
        case .rolling:
            next.velocity = .zero
            next.angularVelocity = SIMD3(0, 0, next.angularVelocity.z)
        case .spinning:
            next.angularVelocity = .zero
        default: break
        }
        next.state = next.classified(radius: R)
        return (next, t)
    }

    /// Chạy một bi đơn lẻ tới khi dừng, trả về các trạng thái tại từng sự kiện.
    public static func runToRest(_ b: Ball, _ p: PhysicsParameters, radius R: Double) -> [(time: Double, ball: Ball)] {
        var events: [(time: Double, ball: Ball)] = [(time: 0, ball: b)]
        var current = b
        var clock = 0.0
        while let step = advanceToTransition(current, p, radius: R) {
            clock += step.1
            current = step.0
            events.append((time: clock, ball: current))
            if events.count > 16 { break } // an toàn, mỗi bi chỉ có tối đa 3 chuyển trạng thái
        }
        return events
    }
}
