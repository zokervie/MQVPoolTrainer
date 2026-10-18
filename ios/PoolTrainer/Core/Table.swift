import Foundation

// Kích thước bàn và hình học băng / lỗ (đơn vị: mét). Bàn 9 ft chuẩn WPA.
// Hệ trục giống bản web và SceneKit (tay phải, y hướng lên): x theo chiều dài bàn (trái → phải),
// z theo chiều rộng, hướng XUỐNG dưới màn hình khi nhìn từ trên. Nút dz = 0 là băng dưới (z = +W/2).

let R = 0.028575            // bán kính bi (2,25 in)
let TL = 2.54               // chiều dài mặt chơi (100 in)
let TW = 1.27               // chiều rộng mặt chơi (50 in)
let DIAMOND = TL / 8        // khoảng cách giữa 2 nút (12,5 in)
let CUSHION_H = 0.0365      // chiều cao mũi băng so với mặt vải (~64% đường kính bi)
let CORNER_MOUTH = 0.118    // miệng lỗ góc (~4,65 in)
let SIDE_MOUTH = 0.132      // miệng lỗ giữa (~5,2 in)

private let HL = TL / 2, HW = TW / 2
private let cA = CORNER_MOUTH / 2.0.squareRoot()
private let sA = SIDE_MOUTH / 2

/// Điểm trên mặt bàn (x theo chiều dài, z theo chiều rộng).
struct P2: Equatable, Codable {
    var x: Double
    var z: Double
    init(_ x: Double, _ z: Double) { self.x = x; self.z = z }
    static func + (a: P2, b: P2) -> P2 { P2(a.x + b.x, a.z + b.z) }
    static func - (a: P2, b: P2) -> P2 { P2(a.x - b.x, a.z - b.z) }
    static func * (a: P2, k: Double) -> P2 { P2(a.x * k, a.z * k) }
    var length: Double { (x * x + z * z).squareRoot() }
    func dist(_ o: P2) -> Double { (self - o).length }
}

/// Đổi toạ độ nút (0..8 theo chiều dài, 0..4 theo chiều rộng) sang mét.
func fromDiamond(_ dx: Double, _ dz: Double) -> P2 { P2((dx / 8 - 0.5) * TL, (0.5 - dz / 4) * TW) }
func toDiamond(_ p: P2) -> (dx: Double, dz: Double) { ((p.x / TL + 0.5) * 8, (0.5 - p.z / TW) * 4) }

enum Rail: String { case top, bottom, left, right, jaw }

struct Cushion {
    let a: P2
    let b: P2
    let rail: Rail
    var isJaw: Bool { rail == .jaw }
}

private func jaw(_ n: P2, _ dx: Double, _ dz: Double, _ len: Double) -> Cushion {
    let m = (dx * dx + dz * dz).squareRoot()
    return Cushion(a: n, b: P2(n.x + dx / m * len, n.z + dz / m * len), rail: .jaw)
}

/// Danh sách đoạn băng (mũi băng + hàm lỗ). Tâm bi va chạm khi cách đoạn < R.
func buildCushions() -> [Cushion] {
    var segs: [Cushion] = []
    let J = 0.07
    let c38 = cos(38 * Double.pi / 180), s38 = sin(38 * Double.pi / 180)
    let c76 = cos(76 * Double.pi / 180), s76 = sin(76 * Double.pi / 180)
    for sz in [1.0, -1.0] {
        for sx in [1.0, -1.0] {
            segs.append(Cushion(a: P2(sx * sA, sz * HW), b: P2(sx * (HL - cA), sz * HW), rail: sz > 0 ? .bottom : .top))
            segs.append(jaw(P2(sx * (HL - cA), sz * HW), sx * c38, sz * s38, J))
            segs.append(jaw(P2(sx * sA, sz * HW), -sx * c76, sz * s76, J * 0.75))
        }
    }
    for sx in [1.0, -1.0] {
        segs.append(Cushion(a: P2(sx * HL, -(HW - cA)), b: P2(sx * HL, HW - cA), rail: sx > 0 ? .right : .left))
        for sz in [1.0, -1.0] { segs.append(jaw(P2(sx * HL, sz * (HW - cA)), sx * s38, sz * c38, J)) }
    }
    return segs
}

struct Pocket {
    let id: String
    let name: String
    let corner: Bool
    let p: P2          // tâm lỗ
    let capture: Double
    let r: Double      // bán kính hiển thị
    let mouth: P2
}

func buildPockets() -> [Pocket] {
    var out: [Pocket] = []
    let names = ["1,1": "Góc dưới phải", "-1,1": "Góc dưới trái", "1,-1": "Góc trên phải", "-1,-1": "Góc trên trái"]
    for sx in [1, -1] { for sz in [1, -1] {
        let d = 0.046
        let fx = Double(sx), fz = Double(sz)
        let mx = fx * (HL - cA / 2), mz = fz * (HW - cA / 2)
        out.append(Pocket(id: "c\(sx)\(sz)", name: names["\(sx),\(sz)"]!, corner: true,
                          p: P2(mx + fx * d * 0.5.squareRoot(), mz + fz * d * 0.5.squareRoot()),
                          capture: 0.05, r: 0.066, mouth: P2(mx, mz)))
    } }
    for sz in [1, -1] {
        let fz = Double(sz)
        out.append(Pocket(id: "s\(sz)", name: sz > 0 ? "Giữa dưới" : "Giữa trên", corner: false,
                          p: P2(0, fz * (HW + 0.036)), capture: 0.05, r: 0.064, mouth: P2(0, fz * HW)))
    }
    return out
}

let CUSHIONS = buildCushions()
let POCKETS = buildPockets()

func pocketById(_ id: String) -> Pocket? { POCKETS.first { $0.id == id } }

let HEAD_SPOT = fromDiamond(2, 2)
let FOOT_SPOT = fromDiamond(6, 2)
