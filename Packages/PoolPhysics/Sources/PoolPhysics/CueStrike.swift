import Foundation
import simd

/// Thông số cú đánh. Điểm chạm tính theo tỉ lệ bán kính bi, −1…1.
public struct CueStrike: Codable, Equatable, Sendable {
    /// Hướng cơ trên mặt bàn (radian, 0 = trục +x).
    public var aimAngle: Double
    /// Tốc độ đầu cơ khi chạm bi (m/s).
    public var cueSpeed: Double
    /// Điểm chạm dọc: +1 = đỉnh bi (xoáy trên), −1 = đáy (xoáy dưới).
    public var tipVertical: Double
    /// Điểm chạm ngang: +1 = bên phải bi theo hướng ngắm.
    public var tipHorizontal: Double
    /// Độ dốc cơ (radian, 0 = nằm ngang; nâng đuôi cơ lên). Cơ dốc + đánh dưới → nhảy bi;
    /// cơ rất dốc + đánh lệch → massé. Điểm chạm đo trên mặt phẳng vuông góc với trục cơ.
    public var elevation: Double

    public init(aimAngle: Double, cueSpeed: Double, tipVertical: Double = 0, tipHorizontal: Double = 0,
                elevation: Double = 0) {
        self.aimAngle = aimAngle
        self.cueSpeed = cueSpeed
        self.tipVertical = tipVertical
        self.tipHorizontal = tipHorizontal
        self.elevation = elevation
    }

    private enum CodingKeys: String, CodingKey { case aimAngle, cueSpeed, tipVertical, tipHorizontal, elevation }

    /// Đọc được bản ghi cũ chưa có `elevation`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        aimAngle = try c.decode(Double.self, forKey: .aimAngle)
        cueSpeed = try c.decode(Double.self, forKey: .cueSpeed)
        tipVertical = try c.decodeIfPresent(Double.self, forKey: .tipVertical) ?? 0
        tipHorizontal = try c.decodeIfPresent(Double.self, forKey: .tipHorizontal) ?? 0
        elevation = try c.decodeIfPresent(Double.self, forKey: .elevation) ?? 0
    }

    /// Khoảng cách điểm chạm tới tâm, theo tỉ lệ bán kính.
    public var tipOffset: Double { (tipVertical * tipVertical + tipHorizontal * tipHorizontal).squareRoot() }
}

/// Thông số cơ. Giá trị mặc định là **giả định** (cơ phổ biến), cần đo hoặc lấy theo cơ của người chơi.
public struct CueSpec: Codable, Equatable, Sendable {
    /// Khối lượng cơ (kg). Giả định: 19 oz ≈ 0,54 kg.
    public var mass: Double = 0.54
    /// Khối lượng hiệu dụng đầu cơ (kg), quyết định squirt. Giả định: ~7 g (cơ ngọn tiêu chuẩn).
    /// Nguồn mô hình: Alciatore TP A.31.
    public var endMass: Double = 0.007
    /// Hệ số phục hồi đầu cơ–bi. Giả định ~0,75 [Alciatore dùng 0,7–0,8].
    public var tipRestitution: Double = 0.75
    /// Giới hạn trượt cơ, tỉ lệ bán kính. Nguồn: Alciatore (~0,5R).
    public var miscueLimit: Double = 0.5

    public init() {}
}

public struct StrikeOutcome: Equatable, Sendable {
    public var ball: Ball
    public var miscue: Bool
    /// Góc lệch squirt (radian, dấu: dương = lệch sang trái hướng ngắm).
    public var squirtAngle: Double
    /// Xung lực truyền cho bi (N·s).
    public var impulse: Double
}

/// Va chạm cơ–bi theo xung lực, có độ dốc cơ.
///
/// - Tốc độ bi: v = (1 + e)·V / (1 + m/M + (5/2)·(d/R)²), d = khoảng cách điểm chạm tới tâm.
///   Nguồn: Alciatore TP A.30 (va chạm lệch tâm). Xung lực J = m·v dọc trục cơ (3D).
/// - Xoáy: ω = (r × J)/I, r là vector từ tâm tới điểm chạm. Đánh cao 2/5 R (cơ ngang) cho lăn ngay.
/// - Squirt (thành phần ngang): tan α = (5/2)·s·√(1 − s²) / (1 + m/mₑ + (5/2)·(1 − s²)), s = độ lệch ngang/R.
///   Nguồn: Alciatore TP A.31. Bi cái lệch về phía ngược với phía đánh.
/// - Cơ dốc: thành phần J hướng xuống ép bi vào mặt bàn → `SlateImpact` (nảy lên = nhảy bi). Đường cong
///   massé/swerve sinh ra ở pha trượt sau đó (ma sát nỉ với xoáy nghiêng), đúng quy tắc "bi cong về phía
///   đánh lệch". Giả thiết: cơ–bi rồi bi–bàn nối tiếp tức thời; cú ép xuống lúc chạm cơ **không có ma sát**
///   (nếu tính ma sát Coulomb toàn phần ở đây, bi bẻ góc gắt ngay lập tức thay vì đi cong — trái mô tả của
///   Alciatore về massé). Các lần nảy sau đó có ma sát. Cần đối chiếu video ở R4.
/// - Trượt cơ: d > giới hạn → bi đi chậm, không xoáy, gắn cờ miscue.
public enum CueModel {

    public static func strike(_ strike: CueStrike, cue: CueSpec = CueSpec(),
                              ball: Ball, mass m: Double, radius R: Double,
                              parameters: PhysicsParameters = PhysicsParameters()) -> StrikeOutcome {
        let flat = SIMD3(cos(strike.aimAngle), sin(strike.aimAngle), 0)
        let left = SIMD3(-flat.y, flat.x, 0)
        let el = max(0, min(strike.elevation, 1.5))
        // Trục cơ hướng vào bi (đi xuống khi nâng đuôi cơ).
        let axis = cos(el) * flat - sin(el) * SIMD3(0, 0, 1)
        // "Lên" trên mặt bi theo người cầm cơ: vuông góc trục cơ, trong mặt phẳng đứng chứa trục cơ.
        let up = simd_normalize(SIMD3(0, 0, 1) - simd_dot(SIMD3(0, 0, 1), axis) * axis)
        var b = ball
        let d = strike.tipOffset

        if d > cue.miscueLimit {
            // Trượt cơ: phần lớn năng lượng không truyền vào bi.
            let v = 0.2 * strike.cueSpeed
            b.velocity = v * flat
            b.angularVelocity = .zero
            b.state = b.classified(radius: R)
            return StrikeOutcome(ball: b, miscue: true, squirtAngle: 0, impulse: m * v)
        }

        let v = (1 + cue.tipRestitution) * strike.cueSpeed / (1 + m / cue.mass + 2.5 * d * d)
        let impulse = m * v

        // Điểm chạm trên mặt bi (vector từ tâm), phía sau bi theo trục cơ.
        let offset = strike.tipVertical * R * up - strike.tipHorizontal * R * left
        let back = (max(0, R * R - simd_length_squared(offset))).squareRoot()
        let r = offset - back * axis
        let J = impulse * axis
        b.angularVelocity = cross(r, J) / (0.4 * m * R * R)

        // Squirt: lệch ngược phía đánh ngang (áp cho thành phần ngang của vận tốc).
        let s = strike.tipHorizontal
        let c = 1 - s * s
        let alpha = atan((2.5 * s * c.squareRoot()) / (1 + m / cue.endMass + 2.5 * c))
        let theta = strike.aimAngle + alpha
        let vh = v * cos(el), vz = -v * sin(el)
        b.velocity = SIMD3(vh * cos(theta), vh * sin(theta), vz)
        if vz < 0 {
            // Bi đang nằm trên bàn: mặt bàn đỡ lực ép xuống.
            b.position.z = R
            b = SlateImpact.resolve(b, parameters, mass: m, radius: R, friction: false)
        } else {
            b.velocity.z = 0
        }
        b.state = b.classified(radius: R)
        return StrikeOutcome(ball: b, miscue: false, squirtAngle: alpha, impulse: impulse)
    }

    /// Giữ API cũ cho test hiện có: trả về bi sau cú đánh với thông số cơ mặc định.
    public static func apply(_ strike: CueStrike, to ball: Ball, radius R: Double, mass m: Double = 0.17) -> Ball {
        Self.strike(strike, ball: ball, mass: m, radius: R).ball
    }
}
