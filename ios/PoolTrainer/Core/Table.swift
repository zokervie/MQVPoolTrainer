import Foundation

// Kích thước bàn và hình học băng / lỗ (đơn vị: mét). Toàn bộ lấy từ hồ sơ bàn đang chọn (TableSpec, xem TableSpecs.swift).
// Hệ trục giống bản web và SceneKit (tay phải, y hướng lên): x theo chiều dài bàn (trái → phải),
// z theo chiều rộng, hướng XUỐNG dưới màn hình khi nhìn từ trên. Nút dz = 0 là băng dưới (z = +W/2).

let R = 0.028575                       // bán kính bi (2,25 in – WPA)

/// Hồ sơ bàn đang dùng. Đổi bằng `applyTable(_:)`.
private(set) var TABLE = TableSpec.standard
private(set) var TL = TABLE.length     // chiều dài mặt chơi (mũi băng → mũi băng)
private(set) var TW = TABLE.width      // chiều rộng mặt chơi
private(set) var CUSHION_H = TABLE.cushionHeight
private(set) var CORNER_MOUTH = TABLE.cornerMouth
private(set) var SIDE_MOUTH = TABLE.sideMouth
var DIAMOND: Double { TL / 8 }

private var HL: Double { TL / 2 }
private var HW: Double { TW / 2 }
private var cA: Double { CORNER_MOUTH / 2.0.squareRoot() }   // khoảng lùi mũi băng tính từ góc
private var sA: Double { SIDE_MOUTH / 2 }

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
/// Góc hàm = 180° − góc cắt miệng lỗ (WPA: lỗ góc 142°, lỗ giữa 104°).
func buildCushions() -> [Cushion] {
    var segs: [Cushion] = []
    let J = 0.07
    let ac = (180 - TABLE.cornerAngle) * Double.pi / 180, asd = (180 - TABLE.sideAngle) * Double.pi / 180
    let cc = cos(ac), sc = sin(ac), cs = cos(asd), ss = sin(asd)
    for sz in [1.0, -1.0] {
        for sx in [1.0, -1.0] {
            segs.append(Cushion(a: P2(sx * sA, sz * HW), b: P2(sx * (HL - cA), sz * HW), rail: sz > 0 ? .bottom : .top))
            segs.append(jaw(P2(sx * (HL - cA), sz * HW), sx * cc, sz * sc, J))
            segs.append(jaw(P2(sx * sA, sz * HW), -sx * cs, sz * ss, J * 0.75))
        }
    }
    for sx in [1.0, -1.0] {
        segs.append(Cushion(a: P2(sx * HL, -(HW - cA)), b: P2(sx * HL, HW - cA), rail: sx > 0 ? .right : .left))
        for sz in [1.0, -1.0] { segs.append(jaw(P2(sx * HL, sz * (HW - cA)), sx * sc, sz * cc, J)) }
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

/// Tâm lỗ lùi sau miệng lỗ theo độ sâu kệ lỗ (shelf): kệ sâu → bi phải vào sâu hơn mới rơi (dễ "lắc lỗ").
func buildPockets() -> [Pocket] {
    var out: [Pocket] = []
    let names = ["1,1": "Góc dưới phải", "-1,1": "Góc dưới trái", "1,-1": "Góc trên phải", "-1,-1": "Góc trên trái"]
    let d = 0.046 + (TABLE.cornerShelf - 0.0254)   // kệ 1″ → 0,046 m (khớp bản web)
    let rc = 0.066 * CORNER_MOUTH / 0.118, rs = 0.064 * SIDE_MOUTH / 0.132
    for sx in [1, -1] { for sz in [1, -1] {
        let fx = Double(sx), fz = Double(sz)
        let mx = fx * (HL - cA / 2), mz = fz * (HW - cA / 2)
        out.append(Pocket(id: "c\(sx)\(sz)", name: names["\(sx),\(sz)"]!, corner: true,
                          p: P2(mx + fx * d * 0.5.squareRoot(), mz + fz * d * 0.5.squareRoot()),
                          capture: 0.05, r: rc, mouth: P2(mx, mz)))
    } }
    let ds = 0.036 + (TABLE.sideShelf - 0.009525)  // kệ 0,375″ → 0,036 m
    for sz in [1, -1] {
        let fz = Double(sz)
        out.append(Pocket(id: "s\(sz)", name: sz > 0 ? "Giữa dưới" : "Giữa trên", corner: false,
                          p: P2(0, fz * (HW + ds)), capture: 0.05, r: rs, mouth: P2(0, fz * HW)))
    }
    return out
}

private(set) var CUSHIONS = buildCushions()
private(set) var POCKETS = buildPockets()

func pocketById(_ id: String) -> Pocket? { POCKETS.first { $0.id == id } }

var HEAD_SPOT: P2 { fromDiamond(2, 2) }
var FOOT_SPOT: P2 { fromDiamond(6, 2) }

/// Đổi hồ sơ bàn: kích thước, lỗ, băng, nỉ (cập nhật cả tham số vật lý).
func applyTable(_ s: TableSpec) {
    _ = DRILLS.count            // thư viện bài tập luôn dựng trên bàn chuẩn trước khi đổi bàn
    TABLE = s
    TL = s.length; TW = s.width
    CUSHION_H = s.cushionHeight
    CORNER_MOUTH = s.cornerMouth; SIDE_MOUTH = s.sideMouth
    CUSHIONS = buildCushions()
    POCKETS = buildPockets()
    PHYS.muSlide = s.muSlide; PHYS.muRoll = s.muRoll; PHYS.spinDecel = s.spinDecel
    PHYS.eCushion = s.eCushion; PHYS.muCushion = s.muCushion
}

/// Định dạng số kiểu Việt Nam (dấu phẩy thập phân).
func vn(_ v: Double, _ digits: Int = 1) -> String {
    String(format: "%.\(digits)f", v).replacingOccurrences(of: ".", with: ",")
}
