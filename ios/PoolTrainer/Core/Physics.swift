import Foundation

// Engine vật lý bi-a (bản Swift, khớp từng bước với src/physics.js của bản web):
// trượt/lăn trên vải, xoáy 3 trục, va chạm bi-bi có ma sát (throw, truyền xoáy),
// va chạm băng có điểm tiếp xúc cao hơn tâm bi (english đổi góc nảy), lệch hướng (squirt), massé, lỗ bắt bi.
// Tham số tham khảo: Dr. Dave Alciatore – "approximate values for pool equipment physical properties".

let G = 9.81

struct PhysParams {
    var muSlide = 0.2        // ma sát trượt bi-vải (0,15–0,4)
    var muRoll = 0.011       // cản lăn (0,005–0,015)
    var spinDecel = 10.0     // giảm tốc xoáy quanh trục đứng (rad/s²)
    var eBall = 0.95         // hồi phục bi-bi (0,92–0,98)
    var muBall = 0.06        // ma sát bi-bi (0,03–0,08) → "throw"
    var eCushion = 0.86      // hồi phục băng ở tốc độ thấp
    var muCushion = 0.2      // ma sát bi-băng
    var dt = 1.0 / 2000
}
var PHYS = PhysParams()

private let I = 0.4 * R * R                    // mômen quán tính / khối lượng (m = 1)
private let SIN_T = (CUSHION_H - R) / R
private let COS_T = (1 - SIN_T * SIN_T).squareRoot()

struct V3: Equatable {
    var x: Double, y: Double, z: Double
    init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    static let zero = V3(0, 0, 0)
    static func + (a: V3, b: V3) -> V3 { V3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func - (a: V3, b: V3) -> V3 { V3(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func * (a: V3, k: Double) -> V3 { V3(a.x * k, a.y * k, a.z * k) }
    static prefix func - (a: V3) -> V3 { V3(-a.x, -a.y, -a.z) }
    var length: Double { (x * x + y * y + z * z).squareRoot() }
}
@inline(__always) func cross(_ a: V3, _ b: V3) -> V3 { V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) }
@inline(__always) func dot(_ a: V3, _ b: V3) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

/// Quaternion hiển thị (x, y, z, w) – xoay theo trục thế giới.
struct Quat: Equatable { var x = 0.0, y = 0.0, z = 0.0, w = 1.0 }

final class Ball {
    let id: Int              // 0 = bi cái, 1..15
    var x: Double, z: Double
    var vx = 0.0, vz = 0.0
    var w = V3.zero          // vận tốc góc (rad/s)
    var pocketed = false
    var pocket: String? = nil
    var dropFrom: P2? = nil
    var q = Quat()

    init(_ id: Int, _ x: Double, _ z: Double) { self.id = id; self.x = x; self.z = z }
    convenience init(_ id: Int, _ p: P2) { self.init(id, p.x, p.z) }

    var pos: P2 { get { P2(x, z) } set { x = newValue.x; z = newValue.z } }
    var speed: Double { (vx * vx + vz * vz).squareRoot() }
    var moving: Bool { !pocketed && (vx * vx + vz * vz > 1e-8 || abs(w.x) + abs(w.y) + abs(w.z) > 1e-3) }

    func clone() -> Ball {
        let b = Ball(id, x, z)
        b.vx = vx; b.vz = vz; b.w = w; b.pocketed = pocketed; b.pocket = pocket; b.dropFrom = dropFrom; b.q = q
        return b
    }
}

enum SimEvent {
    case strike(t: Double, ball: Int)
    case hit(t: Double, a: Int, b: Int, speed: Double)
    case cushion(t: Double, ball: Int, rail: Rail, speed: Double)
    case pocket(t: Double, ball: Int, pocket: String)

    var t: Double {
        switch self {
        case .strike(let t, _), .hit(let t, _, _, _), .cushion(let t, _, _, _), .pocket(let t, _, _): return t
        }
    }
}

final class Simulation {
    var balls: [Ball]
    var time = 0.0
    var events: [SimEvent] = []
    var trackRotation = true
    /// Lấy mẫu đường đi (dùng cho sơ đồ / cú mẫu): id → các điểm.
    var traceIds: Set<Int>? = nil
    var tracePts: [Int: [P2]] = [:]
    private var traceCounter = 0

    init(_ balls: [Ball] = []) { self.balls = balls }

    func clone() -> Simulation {
        let s = Simulation(balls.map { $0.clone() })
        s.trackRotation = false
        return s
    }

    var moving: Bool { balls.contains { $0.moving } }
    func ball(_ id: Int) -> Ball? { balls.first { $0.id == id } }

    /// Cú đánh. dir: góc (rad) hướng cơ trên mặt bàn; speed: tốc độ bi cái (m/s);
    /// a: điểm đánh ngang (theo R, + = phải); b: điểm đánh dọc (+ = trên/theo, − = dưới/kéo);
    /// elev: góc nâng cơ (rad); squirt: hệ số lệch hướng do english.
    func strike(_ ballId: Int, dir: Double, speed: Double, a a0: Double = 0, b b0: Double = 0, elev: Double = 0, squirt: Double = 0.02) {
        guard let cb = ball(ballId) else { return }
        var a = a0, b = b0
        let off = (a * a + b * b).squareRoot()
        if off > 0.6 { a *= 0.6 / off; b *= 0.6 / off }
        let ce = cos(elev), se = sin(elev)
        let d = V3(cos(dir) * ce, -se, sin(dir) * ce)
        let side = V3(-sin(dir), 0, cos(dir))
        let up = cross(side, d)
        let k = max(0, 1 - a * a - b * b).squareRoot()
        let r = V3(R * (-d.x * k + side.x * a + up.x * b),
                   R * (-d.y * k + side.y * a + up.y * b),
                   R * (-d.z * k + side.z * a + up.z * b))
        let J = d * speed
        let tq = cross(r, J)
        let sq = -squirt * a
        cb.vx = J.x * cos(sq) - J.z * sin(sq)
        cb.vz = J.x * sin(sq) + J.z * cos(sq)
        cb.w = tq * (1 / I)
        events.append(.strike(t: time, ball: ballId))
    }

    func step(_ dt: Double = PHYS.dt) {
        let muSlide = PHYS.muSlide, muRoll = PHYS.muRoll, spinDecel = PHYS.spinDecel
        for bl in balls where !bl.pocketed {
            var w = bl.w
            let ux = bl.vx + R * w.z, uz = bl.vz - R * w.x
            let um = hypot(ux, uz)
            if um > 1e-4 {
                let lim = 3.5 * muSlide * G * dt
                if um <= lim {
                    bl.vx -= (2.0 / 7) * ux; bl.vz -= (2.0 / 7) * uz
                    w.x = bl.vz / R; w.z = -bl.vx / R
                } else {
                    let fx = -muSlide * G * ux / um, fz = -muSlide * G * uz / um
                    bl.vx += fx * dt; bl.vz += fz * dt
                    w.x += (-fz * 2.5 / R) * dt; w.z += (fx * 2.5 / R) * dt
                }
            } else {
                let s = hypot(bl.vx, bl.vz)
                if s > 0 {
                    let ns = s - muRoll * G * dt
                    if ns <= 0 { bl.vx = 0; bl.vz = 0 } else { bl.vx *= ns / s; bl.vz *= ns / s }
                }
                w.x = bl.vz / R; w.z = -bl.vx / R
            }
            if w.y != 0 {
                let dw = spinDecel * dt
                w.y = abs(w.y) <= dw ? 0 : w.y - (w.y > 0 ? dw : -dw)
            }
            bl.w = w
            bl.x += bl.vx * dt; bl.z += bl.vz * dt
            if trackRotation { integrateQuat(&bl.q, w, dt) }
        }
        collideBalls()
        collideCushions()
        checkPockets()
        time += dt
        if let ids = traceIds {
            traceCounter += 1
            if traceCounter % 10 == 0 {
                for id in ids { if let b = ball(id), !b.pocketed { tracePts[id, default: []].append(b.pos) } }
            }
        }
    }

    private func collideBalls() {
        let n = balls.count, D = 2 * R, D2 = D * D
        for i in 0..<n {
            let A = balls[i]
            if A.pocketed { continue }
            for j in (i + 1)..<max(n, i + 1) {
                let B = balls[j]
                if B.pocketed { continue }
                let dx = B.x - A.x, dz = B.z - A.z
                let d2 = dx * dx + dz * dz
                if d2 >= D2 || d2 == 0 { continue }
                let d = d2.squareRoot()
                let nx = dx / d, nz = dz / d
                let pen = (D - d) / 2
                A.x -= nx * pen; A.z -= nz * pen; B.x += nx * pen; B.z += nz * pen
                let approach = (A.vx - B.vx) * nx + (A.vz - B.vz) * nz
                if approach <= 0 { continue }
                resolveBallBall(A, B, nx, nz)
            }
        }
    }

    private func resolveBallBall(_ A: Ball, _ B: Ball, _ nx: Double, _ nz: Double) {
        let n = V3(nx, 0, nz)
        let rA = V3(R * nx, 0, R * nz), rB = V3(-R * nx, 0, -R * nz)
        let cA = cross(A.w, rA), cB = cross(B.w, rB)
        let vrel = V3(A.vx + cA.x - B.vx - cB.x, cA.y - cB.y, A.vz + cA.z - B.vz - cB.z)
        let vn = (A.vx - B.vx) * nx + (A.vz - B.vz) * nz
        let Jn = (1 + PHYS.eBall) * vn / 2
        A.vx -= Jn * nx; A.vz -= Jn * nz; B.vx += Jn * nx; B.vz += Jn * nz
        let vrn = dot(vrel, n)
        let vt = V3(vrel.x - vrn * nx, vrel.y, vrel.z - vrn * nz)
        let vtm = vt.length
        if vtm > 1e-6 {
            let Jt = min(PHYS.muBall * Jn, vtm / 7)
            let t = V3(-vt.x / vtm * Jt, -vt.y / vtm * Jt, -vt.z / vtm * Jt)
            A.vx += t.x; A.vz += t.z; B.vx -= t.x; B.vz -= t.z
            let tA = cross(rA, t), tB = cross(rB, -t)
            A.w = A.w + tA * (1 / I)
            B.w = B.w + tB * (1 / I)
        }
        events.append(.hit(t: time, a: A.id, b: B.id, speed: vn))
    }

    private func collideCushions() {
        for bl in balls where !bl.pocketed {
            if abs(bl.x) < TL / 2 - R * 1.5 && abs(bl.z) < TW / 2 - R * 1.5 { continue }
            for s in CUSHIONS {
                let ax = s.a.x, az = s.a.z, bx = s.b.x, bz = s.b.z
                let ex = bx - ax, ez = bz - az
                var t = ((bl.x - ax) * ex + (bl.z - az) * ez) / (ex * ex + ez * ez)
                t = t < 0 ? 0 : (t > 1 ? 1 : t)
                let qx = ax + ex * t, qz = az + ez * t
                let dx = bl.x - qx, dz = bl.z - qz
                let d2 = dx * dx + dz * dz
                if d2 >= R * R || d2 == 0 { continue }
                let d = d2.squareRoot()
                let nx = dx / d, nz = dz / d
                bl.x = qx + nx * R; bl.z = qz + nz * R
                let vn = bl.vx * nx + bl.vz * nz
                if vn >= 0 { continue }
                resolveCushion(bl, nx, nz, s)
            }
        }
    }

    private func resolveCushion(_ bl: Ball, _ nx: Double, _ nz: Double, _ seg: Cushion) {
        let vn = bl.vx * nx + bl.vz * nz
        let e = max(0.55, min(PHYS.eCushion, PHYS.eCushion - 0.035 * (-vn - 1)))
        let Jn = -(1 + e) * vn
        let r = V3(-R * COS_T * nx, R * SIN_T, -R * COS_T * nz)
        let N = V3(nx, 0, nz)
        bl.vx += Jn * nx; bl.vz += Jn * nz
        let tn = cross(r, V3(Jn * nx, 0, Jn * nz))
        bl.w = bl.w + tn * (1 / I)
        let c = cross(bl.w, r)
        let vc = V3(bl.vx + c.x, c.y, bl.vz + c.z)
        let vcn = dot(vc, N)
        let vt = V3(vc.x - vcn * nx, vc.y, vc.z - vcn * nz)
        let vtm = vt.length
        if vtm > 1e-6 {
            let tdir = vt * (1 / vtm)
            let rt = cross(r, tdir)
            let K = 1 + dot(rt, rt) / I
            let Jt = min(PHYS.muCushion * Jn, vtm / K)
            let imp = -tdir * Jt
            bl.vx += imp.x; bl.vz += imp.z
            let tt = cross(r, imp)
            bl.w = bl.w + tt * (1 / I)
        }
        events.append(.cushion(t: time, ball: bl.id, rail: seg.rail, speed: -vn))
    }

    private func checkPockets() {
        for bl in balls where !bl.pocketed {
            if abs(bl.x) < TL / 2 - 0.09 && abs(bl.z) < TW / 2 - 0.09 { continue }
            for p in POCKETS {
                let dx = bl.x - p.p.x, dz = bl.z - p.p.z
                if dx * dx + dz * dz < p.capture * p.capture { pocketBall(bl, p); break }
            }
            if !bl.pocketed && (abs(bl.x) > TL / 2 + 0.06 || abs(bl.z) > TW / 2 + 0.06) {
                var best = POCKETS[0], bd = Double.infinity
                for p in POCKETS { let dd = pow(bl.x - p.p.x, 2) + pow(bl.z - p.p.z, 2); if dd < bd { bd = dd; best = p } }
                pocketBall(bl, best)
            }
        }
    }

    private func pocketBall(_ bl: Ball, _ p: Pocket) {
        bl.pocketed = true; bl.pocket = p.id
        bl.dropFrom = bl.pos
        bl.vx = 0; bl.vz = 0; bl.w = .zero
        events.append(.pocket(t: time, ball: bl.id, pocket: p.id))
    }

    /// Chạy tới khi dừng (dùng cho kiểm thử / dự đoán).
    @discardableResult
    func runUntilRest(_ maxTime: Double = 20, dt: Double = PHYS.dt) -> Simulation {
        let steps = Int((maxTime / dt).rounded(.up))
        for i in 0..<steps {
            step(dt)
            if i % 20 == 0 && !moving { break }
        }
        return self
    }
}

func integrateQuat(_ q: inout Quat, _ w: V3, _ dt: Double) {
    let wm = w.length
    if wm < 1e-9 { return }
    let ang = wm * dt, s = sin(ang / 2) / wm
    let dx = w.x * s, dy = w.y * s, dz = w.z * s, dw = cos(ang / 2)
    let x = q.x, y = q.y, z = q.z, ww = q.w
    var n = Quat(x: dw * x + dx * ww + dy * z - dz * y,
                 y: dw * y - dx * z + dy * ww + dz * x,
                 z: dw * z + dx * y - dy * x + dz * ww,
                 w: dw * ww - dx * x - dy * y - dz * z)
    let m = (n.x * n.x + n.y * n.y + n.z * n.z + n.w * n.w).squareRoot()
    n.x /= m; n.y /= m; n.z /= m; n.w /= m
    q = n
}

/// Tốc độ cần để bi lăn được quãng đường d: v = √(2·μr·g·d).
func speedForDistance(_ d: Double) -> Double { (2 * PHYS.muRoll * G * d).squareRoot() }

// MARK: - Truy vấn sự kiện
extension Array where Element == SimEvent {
    var pottedIds: [Int] { compactMap { if case .pocket(_, let b, _) = $0 { return b }; return nil } }
    /// Va chạm đầu tiên của bi cái.
    var firstCueHit: (t: Double, other: Int)? {
        for e in self { if case .hit(let t, let a, let b, _) = e, a == 0 || b == 0 { return (t, a == 0 ? b : a) } }
        return nil
    }
    func cushions(of ball: Int) -> [(t: Double, rail: Rail)] {
        compactMap { if case .cushion(let t, let b, let r, _) = $0, b == ball { return (t, r) }; return nil }
    }
}
