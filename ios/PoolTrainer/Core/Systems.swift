import Foundation

// Hình học các hệ thống nút số (diamond systems) và công cụ ngắm.
// "Khung nút": dx 0..8 (trái → phải), dz 0..4 (băng dưới → băng trên) đo trên ĐƯỜNG NÚT (mặt gỗ, lùi sau mũi băng).

let DIAMOND_OFF = 0.094
private var DXs: Double { (TL + 2 * DIAMOND_OFF) / 8 }
private var DZs: Double { (TW + 2 * DIAMOND_OFF) / 4 }

func railPoint(_ dx: Double, _ dz: Double) -> P2 { P2(-TL / 2 - DIAMOND_OFF + dx * DXs, TW / 2 + DIAMOND_OFF - dz * DZs) }
func toRailFrame(_ p: P2) -> (dx: Double, dz: Double) { ((p.x + TL / 2 + DIAMOND_OFF) / DXs, (TW / 2 + DIAMOND_OFF - p.z) / DZs) }

// MARK: - Bi ma

/// Điểm nhắm cho bi mục tiêu vào lỗ: hơi lùi vào trong miệng lỗ.
func pocketAimPoint(_ p: Pocket) -> P2 {
    let k = p.corner ? 0.012 : 0.004
    let d = p.p - p.mouth, m = d.length == 0 ? 1 : d.length
    return p.mouth + d * (k / m)
}

/// Vị trí bi ma: G = O − 2R·û (û: hướng từ bi mục tiêu tới điểm nhắm).
func ghostBall(_ ob: P2, _ target: P2) -> P2 {
    let d = target - ob, m = d.length
    return ob - d * (2 * R / m)
}

/// Góc cắt (độ) giữa đường bi cái→bi ma và đường bi mục tiêu→lỗ.
func cutAngle(_ cb: P2, _ ob: P2, _ target: P2) -> Double {
    let g = ghostBall(ob, target)
    let a1 = atan2(g.z - cb.z, g.x - cb.x), a2 = atan2(target.z - ob.z, target.x - ob.x)
    var d = abs(a1 - a2) * 180 / .pi
    if d > 180 { d = 360 - d }
    return d
}

func overlapFromCut(_ deg: Double) -> Double { 1 - sin(deg * .pi / 180) }
func cutFromOverlap(_ f: Double) -> Double { asin(1 - f) * 180 / .pi }

/// Đặt bi cái để tạo góc cắt cho trước. side = ±1 chọn phía; dist = khoảng cách bi cái→bi ma.
func placeForCut(_ ob: P2, _ target: P2, _ deg: Double, _ dist: Double, _ side: Double = 1) -> P2 {
    let g = ghostBall(ob, target)
    let base = atan2(target.z - ob.z, target.x - ob.x)
    let a = base + side * deg * .pi / 180
    return P2(g.x - cos(a) * dist, g.z - sin(a) * dist)
}

// MARK: - Gương 1 băng (đường tâm bi cách mũi băng 1R)

func centerLine(_ rail: Rail) -> Double {
    switch rail {
    case .top: return -TW / 2 + R
    case .bottom: return TW / 2 - R
    case .left: return -TL / 2 + R
    case .right, .jaw: return TL / 2 - R
    }
}

func mirrorPoint(_ p: P2, _ rail: Rail) -> P2 {
    if rail == .top || rail == .bottom { return P2(p.x, 2 * centerLine(rail) - p.z) }
    return P2(2 * centerLine(rail) - p.x, p.z)
}

/// Điểm chạm băng của đường gương: x_c = (x₁·d₂ + x₂·d₁)/(d₁+d₂).
func mirrorContact(_ a: P2, _ b: P2, _ rail: Rail) -> P2 {
    let horiz = rail == .top || rail == .bottom
    let c = centerLine(rail)
    let d1 = horiz ? abs(a.z - c) : abs(a.x - c)
    let d2 = horiz ? abs(b.z - c) : abs(b.x - c)
    if horiz { return P2((a.x * d2 + b.x * d1) / (d1 + d2), c) }
    return P2(c, (a.z * d2 + b.z * d1) / (d1 + d2))
}

// MARK: - Phản chiếu qua góc (2 băng kề nhau)

/// Góc C của hình chữ nhật tâm bi; ảnh T' = 2C − T. corner: "tr" | "tl" | "br" | "bl".
func cornerReflect(_ p: P2, _ corner: String) -> (img: P2, c: P2) {
    let cx = corner.contains("r") ? centerLine(.right) : centerLine(.left)
    let cz = corner.contains("t") ? centerLine(.top) : centerLine(.bottom)
    return (P2(2 * cx - p.x, 2 * cz - p.z), P2(cx, cz))
}

// MARK: - Corner-5 (băng trên → băng phải → băng dưới). T = D − F.

func corner5OriginNumber(_ cb: P2, _ F: Double) -> (D: Double, at: P2)? {
    let pf = railPoint(8 - F, 4)
    let dir = cb - pf
    let left = railPoint(0, 0).x, bottom = railPoint(0, 0).z
    if dir.x < 0 {
        let t = (left - pf.x) / dir.x
        let z = pf.z + dir.z * t
        let fr = toRailFrame(P2(left, z))
        if fr.dz >= 0 { return (5 + fr.dz, P2(left, z)) }
    }
    if dir.z > 0 {
        let t = (bottom - pf.z) / dir.z
        let x = pf.x + dir.x * t
        let fr = toRailFrame(P2(x, bottom))
        return (5 - fr.dx / 2, P2(x, bottom))
    }
    return nil
}

struct Corner5Solution { let F: Double, D: Double, T: Double; let aim: P2, origin: P2, arrival: P2 }

func corner5Solve(_ cb: P2, _ T: Double) -> Corner5Solution? {
    func f(_ F: Double) -> Double { if let o = corner5OriginNumber(cb, F) { return o.D - F - T }; return .nan }
    func finish(_ F: Double) -> Corner5Solution? {
        guard let o = corner5OriginNumber(cb, F) else { return nil }
        return Corner5Solution(F: F, D: o.D, T: T, aim: railPoint(8 - F, 4), origin: o.at, arrival: railPoint(8 - T, 0))
    }
    var lo = 0.3, hi = 7.7
    var flo = f(lo)
    let fhi = f(hi)
    if !(flo * fhi < 0) {
        var best: Double? = nil, bv = Double.infinity
        var F = 0.3
        while F <= 7.7 { let v = abs(f(F)); if v < bv { bv = v; best = F }; F += 0.05 }
        return best.flatMap(finish)
    }
    for _ in 0..<50 {
        let mid = (lo + hi) / 2, fm = f(mid)
        if fm * flo <= 0 { hi = mid } else { lo = mid; flo = fm }
    }
    return finish((lo + hi) / 2)
}

// MARK: - Nhãn số trên băng

enum LabelSide { case top, bottom, left, right, bottom2 }
struct RailLabel { let p: P2; let text: String; let color: UInt32; let side: LabelSide }
enum LabelKind { case std, corner5 }

func systemLabels(_ kind: LabelKind) -> [RailLabel] {
    func fmt(_ n: Double) -> String {
        abs(n - n.rounded()) < 1e-6 ? String(Int(n.rounded())) : String(format: "%.1f", n).replacingOccurrences(of: ".", with: ",")
    }
    var out: [RailLabel] = []
    switch kind {
    case .corner5:
        for i in 0...4 { out.append(RailLabel(p: railPoint(0, Double(i)), text: fmt(5 + Double(i)), color: 0xffd166, side: .left)) }
        for i in 1...7 { out.append(RailLabel(p: railPoint(Double(i), 0), text: fmt(5 - Double(i) / 2), color: 0xffd166, side: .bottom)) }
        for i in 1...7 { out.append(RailLabel(p: railPoint(8 - Double(i), 4), text: fmt(Double(i)), color: 0x7bdff2, side: .top)) }
        for i in 1...7 { out.append(RailLabel(p: railPoint(8 - Double(i), 0), text: fmt(Double(i)), color: 0xff8fab, side: .bottom2)) }
    case .std:
        for i in 0...8 {
            out.append(RailLabel(p: railPoint(Double(i), 0), text: "\(i)", color: 0xe9ecef, side: .bottom))
            out.append(RailLabel(p: railPoint(Double(i), 4), text: "\(i)", color: 0xe9ecef, side: .top))
        }
        for j in 1...3 {
            out.append(RailLabel(p: railPoint(0, Double(j)), text: "\(j)", color: 0xe9ecef, side: .left))
            out.append(RailLabel(p: railPoint(8, Double(j)), text: "\(j)", color: 0xe9ecef, side: .right))
        }
    }
    return out
}
