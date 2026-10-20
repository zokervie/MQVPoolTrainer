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
    /// Cơ dùng cho cú này (`CueSpec.library`). nil = cơ của `Simulation` (mặc định: cơ thường).
    /// Lưu cùng cú để phát lại đúng.
    public var cueId: String?

    public init(aimAngle: Double, cueSpeed: Double, tipVertical: Double = 0, tipHorizontal: Double = 0,
                elevation: Double = 0, cueId: String? = nil) {
        self.aimAngle = aimAngle
        self.cueSpeed = cueSpeed
        self.tipVertical = tipVertical
        self.tipHorizontal = tipHorizontal
        self.elevation = elevation
        self.cueId = cueId
    }

    private enum CodingKeys: String, CodingKey { case aimAngle, cueSpeed, tipVertical, tipHorizontal, elevation, cueId }

    /// Đọc được bản ghi cũ chưa có `elevation`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        aimAngle = try c.decode(Double.self, forKey: .aimAngle)
        cueSpeed = try c.decode(Double.self, forKey: .cueSpeed)
        tipVertical = try c.decodeIfPresent(Double.self, forKey: .tipVertical) ?? 0
        tipHorizontal = try c.decodeIfPresent(Double.self, forKey: .tipHorizontal) ?? 0
        elevation = try c.decodeIfPresent(Double.self, forKey: .elevation) ?? 0
        cueId = try c.decodeIfPresent(String.self, forKey: .cueId)
    }

    /// Khoảng cách điểm chạm tới tâm, theo tỉ lệ bán kính.
    public var tipOffset: Double { (tipVertical * tipVertical + tipHorizontal * tipHorizontal).squareRoot() }
}

/// Loại cơ. Tên hư cấu của dự án — không dùng tên/hình hãng thật (chưa có số đo và giấy phép).
public enum CueKind: String, Codable, CaseIterable, Sendable {
    /// Cơ đánh thường (cơ dài, đầu da).
    case playing
    /// Cơ nhảy (ngắn, nhẹ, đầu phenolic cứng).
    case jump
    /// Cơ massé (ngắn, nặng, cứng).
    case masse
}

/// Thông số cơ. Nguồn/giả định ghi ở từng trường; bộ cơ có sẵn ở `CueSpec.library`.
public struct CueSpec: Codable, Equatable, Sendable {
    public var id: String = "playing"
    public var kind: CueKind = .playing
    /// Khối lượng cơ (kg). Cơ thường 18–21 oz (Dr. Dave); mặc định 19 oz ≈ 0,54 kg.
    public var mass: Double = 0.54
    /// Khối lượng hiệu dụng đầu cơ (kg), quyết định squirt. Giả định: ~7 g (ngọn tiêu chuẩn).
    /// Nguồn mô hình: Alciatore TP A.31.
    public var endMass: Double = 0.007
    /// Hệ số phục hồi đầu cơ–bi. Dr. Dave: đầu da 0,71–0,75; phenolic 0,81–0,87 (docs/09).
    public var tipRestitution: Double = 0.75
    /// Giới hạn trượt cơ, tỉ lệ bán kính. Nguồn: Alciatore (~0,5R, đầu da có phấn).
    public var miscueLimit: Double = 0.5
    /// Đường kính đầu tẩy (m). WPA: tối đa 14 mm; thường 12,5–13,5 mm.
    public var tipDiameter: Double = 0.013
    /// Chiều dài cơ (m), chỉ để vẽ. Cơ thường 57–59″ (~1,47 m).
    public var length: Double = 1.47
    /// Tốc độ đầu cơ khi cùng một cú vuốt, so với cơ thường. Cơ nhẹ vung nhanh hơn với cùng sức tay:
    /// coi tay + cơ như một khối, cùng động năng → V ∝ 1/√(M_tay + M). **Giả định** M_tay hiệu dụng 1,0 kg
    /// (chưa đo); cùng một cơ thì luôn cùng một hệ số → vẫn "cùng đầu vào, cùng kết quả".
    public var strokeSpeedFactor: Double { ((CueSpec.armMass + 0.54) / (CueSpec.armMass + mass)).squareRoot() }
    public static let armMass = 1.0

    public init() {}

    public init(id: String, kind: CueKind, mass: Double, endMass: Double, tipRestitution: Double,
                miscueLimit: Double, tipDiameter: Double, length: Double) {
        self.id = id; self.kind = kind; self.mass = mass; self.endMass = endMass
        self.tipRestitution = tipRestitution; self.miscueLimit = miscueLimit
        self.tipDiameter = tipDiameter; self.length = length
    }

    /// Cơ thường: 19 oz, đầu da 13 mm. Mọi số theo khoảng công bố (Dr. Dave, WPA), endMass giả định.
    public static let playing = CueSpec()
    /// Cơ nhảy: ~9 oz (0,25 kg), dài ~40″, đầu phenolic (e 0,84 giữa 0,81–0,87). Nhẹ để đầu cơ "tránh đường"
    /// cho bi nảy lên (Dr. Dave, jump shot FAQ). endMass 12 g và giới hạn trượt 0,45R (phenolic ít bám phấn
    /// hơn) là **giả định**.
    public static let jump = CueSpec(id: "jump", kind: .jump, mass: 0.25, endMass: 0.012, tipRestitution: 0.84,
                                     miscueLimit: 0.45, tipDiameter: 0.0135, length: 1.02)
    /// Cơ massé: ~21 oz (0,6 kg), ngắn ~50″, ngọn cứng đầu da cứng (e 0,78). Số liệu **giả định** theo mô tả
    /// chung về cơ massé (nặng, cứng); chưa đo.
    public static let masse = CueSpec(id: "masse", kind: .masse, mass: 0.6, endMass: 0.012, tipRestitution: 0.78,
                                      miscueLimit: 0.5, tipDiameter: 0.013, length: 1.27)

    public static let library: [CueSpec] = [.playing, .jump, .masse]
    public static func named(_ id: String?) -> CueSpec? { library.first { $0.id == id } }
}

public struct StrikeOutcome: Equatable, Sendable {
    public var ball: Ball
    public var miscue: Bool
    /// Góc lệch squirt (radian, dấu: dương = lệch sang trái hướng ngắm).
    public var squirtAngle: Double
    /// Xung lực truyền cho bi (N·s), cộng cả các lần chạm lại.
    public var impulse: Double
    /// Số lần đầu cơ chạm lại bi sau lần đầu (cơ dốc: bi kẹt giữa đầu cơ và mặt bàn). Trong luật là lỗi
    /// nếu > 0 ở cú nhảy; ở massé là bình thường.
    public var doubleHits: Int = 0
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
            return StrikeOutcome(ball: b, miscue: true, squirtAngle: 0, impulse: m * v, doubleHits: 0)
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
        var doubleHits = 0
        var total = impulse
        if vz < 0 {
            // Bi đang nằm trên bàn: mặt bàn đỡ lực ép xuống.
            b.position.z = R
            b = SlateImpact.resolve(b, parameters, mass: m, radius: R, friction: false)
            // Chạm hai lần: sau va chạm 1D với khối lượng hiệu dụng của bi mₑ = m/(1 + 2,5d²), đầu cơ còn đi
            // tiếp với Vc' = V·(M − e·mₑ)/(M + mₑ). Nếu bi nảy khỏi mặt bàn mà thành phần vận tốc dọc trục cơ
            // nhỏ hơn Vc', đầu cơ đuổi kịp và đẩy bi lần nữa (ép xuống bàn). Đây là lý do cơ nhẹ nhảy tốt hơn
            // (Dr. Dave, jump shot FAQ: cơ nhẹ "tránh đường" cho bi). Giả thiết: mọi lần chạm tức thời, cùng
            // điểm chạm và cùng e; tối đa 4 lần.
            let me = m / (1 + 2.5 * d * d)
            var vc = strike.cueSpeed * (cue.mass - cue.tipRestitution * me) / (cue.mass + me)
            while doubleHits < 4 {
                let away = simd_dot(b.velocity, axis)
                let closing = vc - away
                guard closing > 1e-6 else { break }
                let j = (1 + cue.tipRestitution) * closing / (1 / cue.mass + 1 / me)
                b.velocity += j / m * axis
                b.angularVelocity += cross(r, j * axis) / (0.4 * m * R * R)
                vc -= j / cue.mass
                total += j
                doubleHits += 1
                if b.velocity.z < 0 { b = SlateImpact.resolve(b, parameters, mass: m, radius: R, friction: false) }
            }
        } else {
            b.velocity.z = 0
        }
        b.state = b.classified(radius: R)
        return StrikeOutcome(ball: b, miscue: false, squirtAngle: alpha, impulse: total, doubleHits: doubleHits)
    }

    /// Giữ API cũ cho test hiện có: trả về bi sau cú đánh với thông số cơ mặc định.
    public static func apply(_ strike: CueStrike, to ball: Ball, radius R: Double, mass m: Double = 0.17) -> Ball {
        Self.strike(strike, ball: ball, mass: m, radius: R).ball
    }
}
