import Foundation
import simd

// MARK: - Bản ghi va chạm (R1.6b) và quỹ đạo

public enum CollisionKind: String, Codable, Sendable, CaseIterable {
    case cueTip, ballBall, ballCushion, ballJaw, ballDrop, miscue
}

/// Một va chạm trong cú đánh. Đầu vào cho âm thanh, haptic và phân tích.
public struct CollisionRecord: Codable, Equatable, Sendable {
    public var kind: CollisionKind
    public var time: Double
    /// Vị trí va chạm (vật lý, mét).
    public var position: SIMD3<Double>
    /// Bi liên quan (một hoặc hai).
    public var ballIds: [Int]
    public var relativeNormalSpeed: Double
    public var impulse: Double
    public var tangentialSlip: Double
    /// Với ballDrop: id lỗ (TableGeometry.Pocket.id).
    public var pocketId: Int?
}

public struct Snapshot: Equatable, Sendable {
    public var time: Double
    public var balls: [Ball]
}

/// Quỹ đạo của cả cú đánh: trạng thái tại mọi sự kiện. Giữa hai sự kiện, mỗi bi chuyển động
/// theo nghiệm dạng đóng của `FreeMotion`, nên có thể nội suy chính xác tại thời điểm bất kỳ.
public struct Trajectory: Sendable {
    public let snapshots: [Snapshot]
    public let parameters: PhysicsParameters
    public let radius: Double

    public var duration: Double { snapshots.last?.time ?? 0 }

    public func state(at t: Double) -> [Ball] {
        guard let first = snapshots.first else { return [] }
        if t <= first.time { return first.balls }
        // Tìm nhị phân snapshot cuối cùng có time ≤ t.
        var lo = 0, hi = snapshots.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if snapshots[mid].time <= t { lo = mid } else { hi = mid - 1 }
        }
        let s = snapshots[lo]
        let dt = t - s.time
        return s.balls.map { b in
            guard dt > 0, b.state != .pocketed, b.state != .stationary else { return b }
            let limit = FreeMotion.timeToTransition(b, parameters, radius: radius) ?? dt
            return FreeMotion.evolve(b, by: min(dt, limit), parameters, radius: radius)
        }
    }
}

public enum SimulationStatus: Equatable, Sendable {
    case completed
    /// Chạm giới hạn số sự kiện: cú đánh không đáng tin, phải ghi seed để tái hiện.
    case eventLimitReached
}

public struct ShotResult: Sendable {
    public let trajectory: Trajectory
    public let collisions: [CollisionRecord]
    public let status: SimulationStatus
    public let miscue: Bool
    public var finalBalls: [Ball] { trajectory.snapshots.last?.balls ?? [] }

    /// Bi đã vào lỗ: id bi → id lỗ, theo thứ tự thời gian.
    public var pocketed: [(ballId: Int, pocketId: Int)] {
        collisions.filter { $0.kind == .ballDrop }.compactMap { r in r.pocketId.map { (r.ballIds[0], $0) } }
    }

    /// Bi đầu tiên mà bi cái chạm vào.
    public var firstObjectBallHit: Int? {
        collisions.first { $0.kind == .ballBall && $0.ballIds.contains(0) }
            .flatMap { $0.ballIds.first { $0 != 0 } }
    }
}

public struct SimulationOptions: Sendable {
    public var maxEvents: Int = 20_000
    /// Cửa sổ thời gian coi là "đồng thời" (s).
    public var simultaneityWindow: Double = 1e-9
    /// Đảo thứ tự xử lý các sự kiện đồng thời — chỉ dùng để đo độ nhạy thứ tự (KPI M7).
    public var reverseTieOrder: Bool = false
    public init() {}
}

// MARK: - Bộ giải theo sự kiện

/// Mô phỏng một cú đánh theo sự kiện (Leckie & Greenspan 2006):
/// tìm sự kiện sớm nhất (chuyển trạng thái, va chạm bi–bi, bi–băng, bi–mũi băng, bi rơi lỗ),
/// đưa mọi bi tới đúng thời điểm đó bằng nghiệm dạng đóng, xử lý sự kiện, lặp lại.
public struct Simulation: Sendable {
    public let table: TableSpec
    public let parameters: PhysicsParameters
    public let cue: CueSpec
    public let geometry: TableGeometry
    public var options: SimulationOptions

    public init(table: TableSpec, parameters: PhysicsParameters, cue: CueSpec = CueSpec(),
                options: SimulationOptions = SimulationOptions()) {
        self.table = table
        self.parameters = parameters
        self.cue = cue
        self.geometry = TableGeometry(table)
        self.options = options
    }

    public init(definition: TableDefinition, cue: CueSpec = CueSpec()) {
        self.init(table: definition.geometry, parameters: definition.physics, cue: cue)
    }

    private var R: Double { table.ballRadius }
    private var m: Double { table.ballMass }

    /// Đánh bi cái (id 0) rồi mô phỏng tới khi mọi bi dừng.
    public func run(balls initial: [Ball], strike: CueStrike) -> ShotResult {
        var balls = initial.map { b -> Ball in var c = b; c.position.z = R; c.state = c.classified(radius: R); return c }
        var records: [CollisionRecord] = []
        var miscue = false
        if let i = balls.firstIndex(where: { $0.id == 0 && $0.state != .pocketed }) {
            let out = CueModel.strike(strike, cue: cue, ball: balls[i], mass: m, radius: R)
            balls[i] = out.ball
            miscue = out.miscue
            records.append(CollisionRecord(kind: out.miscue ? .miscue : .cueTip, time: 0,
                                           position: balls[i].position, ballIds: [0],
                                           relativeNormalSpeed: strike.cueSpeed, impulse: out.impulse,
                                           tangentialSlip: 0, pocketId: nil))
        }
        let (traj, more, status) = simulate(balls)
        return ShotResult(trajectory: traj, collisions: records + more, status: status, miscue: miscue)
    }

    /// Mô phỏng từ trạng thái cho trước (không có cú đánh).
    ///
    /// Tối ưu chuẩn của mô phỏng theo sự kiện: mọi dự đoán lưu theo **thời gian tuyệt đối**; sau mỗi
    /// sự kiện chỉ tính lại dự đoán của các bi vừa thay đổi (va chạm hoặc đổi pha) và các cặp có chứa chúng.
    /// Chuyển động giữa các sự kiện là nghiệm dạng đóng nên dự đoán của bi không đổi vẫn đúng.
    public func simulate(_ initial: [Ball]) -> (Trajectory, [CollisionRecord], SimulationStatus) {
        var balls = initial
        let n = balls.count
        var clock = 0.0
        var snapshots = [Snapshot(time: 0, balls: balls)]
        var records: [CollisionRecord] = []
        var status = SimulationStatus.completed

        var transition = [Double](repeating: .infinity, count: n)   // thời điểm tuyệt đối
        var walls = [[Candidate]](repeating: [], count: n)
        var pairs = [Candidate?](repeating: nil, count: n * n)       // chỉ dùng i < j
        var dirty = Set(balls.indices)

        for _ in 0..<options.maxEvents {
            if !balls.contains(where: isMoving) { break }

            // 1. Tính lại dự đoán cho bi thay đổi.
            for i in dirty.sorted() {
                if isMoving(balls[i]) {
                    let dt = FreeMotion.timeToTransition(balls[i], parameters, radius: R) ?? .infinity
                    transition[i] = clock + dt
                    walls[i] = wallEvents(balls[i], index: i, horizon: dt).map { var c = $0; c.time += clock; return c }
                } else {
                    transition[i] = .infinity
                    walls[i] = []
                }
            }
            for i in 0..<n {
                for j in (i + 1)..<max(i + 1, n) where dirty.contains(i) || dirty.contains(j) {
                    pairs[i * n + j] = nil
                    guard balls[i].state != .pocketed, balls[j].state != .pocketed,
                          isMoving(balls[i]) || isMoving(balls[j]) else { continue }
                    let horizon = min(transition[i], transition[j]) - clock
                    if let t = pairTime(balls[i], balls[j], horizon: horizon) {
                        pairs[i * n + j] = Candidate(time: clock + t, kind: .ballBall, i: i, j: j)
                    }
                }
            }

            // 2. Sự kiện sớm nhất.
            var earliest = transition.min() ?? .infinity
            for w in walls { for c in w { earliest = min(earliest, c.time) } }
            for c in pairs { if let c { earliest = min(earliest, c.time) } }
            guard earliest.isFinite else { break }
            let T = max(clock, earliest)

            // 3. Đưa mọi bi tới thời điểm sự kiện.
            dirty = []
            for i in 0..<n where isMoving(balls[i]) {
                if transition[i] - T <= options.simultaneityWindow,
                   let snapped = FreeMotion.advanceToTransition(balls[i], parameters, radius: R) {
                    balls[i] = snapped.0
                    dirty.insert(i)
                } else if T > clock {
                    balls[i] = FreeMotion.evolve(balls[i], by: T - clock, parameters, radius: R)
                }
            }
            clock = T

            // 4. Xử lý các va chạm đồng thời theo thứ tự xác định.
            var due: [Candidate] = []
            for w in walls { for c in w where c.time - T <= options.simultaneityWindow { due.append(c) } }
            for c in pairs { if let c, c.time - T <= options.simultaneityWindow { due.append(c) } }
            due.sort { a, b in
                let ka = (a.kind.order, a.i, a.j, a.extra), kb = (b.kind.order, b.i, b.j, b.extra)
                return options.reverseTieOrder ? ka > kb : ka < kb
            }
            var restingPairs = Set<Int>()
            for e in due {
                dirty.insert(e.i)
                if e.j >= 0 { dirty.insert(e.j) }
                if let r = resolve(e, &balls, time: clock) {
                    records.append(r)
                } else if e.kind == .ballBall {
                    restingPairs.insert(e.i * n + e.j)
                }
            }
            // 5. Tách vị trí đồng thời cho mọi cặp (R1.7 / M3, M6). Trước đây mỗi cặp tựa nhau tự đẩy
            //    nhau ra một khe: trong tam giác xếp sát, cú đẩy ép bi giữa lấn vào bi bên cạnh → sự kiện
            //    mới cùng thời điểm → đẩy ngược lại (vòng lặp, chồng lấn tới ~12 µm, chạm giới hạn sự kiện).
            //    Giờ: chiếu vị trí kiểu Gauss–Seidel tới khi không cặp nào chồng lấn; cặp vừa tiếp xúc tựa
            //    giữ thêm khe `separationGap` (chống Zeno). Chỉ đổi vị trí (≤ vài µm), không đổi vận tốc.
            separateOverlaps(&balls, resting: restingPairs, dirty: &dirty)
            snapshots.append(Snapshot(time: clock, balls: balls))
            if snapshots.count >= options.maxEvents { status = .eventLimitReached; break }
        }
        return (Trajectory(snapshots: snapshots, parameters: parameters, radius: R), records, status)
    }

    // MARK: Ứng viên sự kiện

    enum CandidateKind: Int { case ballBall = 0, cushion = 1, jaw = 2, drop = 3, bounds = 4
        var order: Int { rawValue }
    }
    struct Candidate {
        var time: Double
        var kind: CandidateKind
        var i: Int
        var j: Int = -1
        /// cushion: chỉ số đoạn băng; jaw: chỉ số mũi băng; drop: id lỗ.
        var extra: Int = -1
    }

    private func isMoving(_ b: Ball) -> Bool {
        b.state != .pocketed && b.state != .stationary
    }

    /// Hệ số đa thức của vị trí ngang trong pha hiện tại: p(t) = c0 + c1·t + c2·t².
    private func motion(_ b: Ball) -> (SIMD2<Double>, SIMD2<Double>, SIMD2<Double>) {
        let a = FreeMotion.acceleration(b, parameters, radius: R)
        return (SIMD2(b.position.x, b.position.y), SIMD2(b.velocity.x, b.velocity.y), 0.5 * SIMD2(a.x, a.y))
    }

    /// Thời điểm sớm nhất trong (0, horizon] mà khoảng cách giữa hai điểm chuyển động
    /// giảm xuống bằng D (đang lại gần). Δp(t) = C + B·t + A·t².
    private func approachTime(C: SIMD2<Double>, B: SIMD2<Double>, A: SIMD2<Double>,
                              distance D: Double, horizon: Double) -> Double? {
        let coeffs = [simd_dot(C, C) - D * D,
                      2 * simd_dot(B, C),
                      simd_dot(B, B) + 2 * simd_dot(A, C),
                      2 * simd_dot(A, B),
                      simd_dot(A, A)]
        let f0 = coeffs[0], df0 = coeffs[1]
        let dcoeffs = Polynomial.derivative(coeffs)
        let h = horizon.isFinite ? horizon : 60
        // Tốc độ lại gần theo pháp tuyến tại khoảng cách D: −f'/(2D).
        let minRate = -2 * D * CollisionThresholds.minApproachSpeed
        let penetrationLevel = -2 * D * CollisionThresholds.penetration   // f khi lấn đúng `penetration`

        if f0 <= 1e-12 * D * D {
            // Đang chạm hoặc chồng lấn.
            if df0 <= minRate { return 0 }                         // lại gần đủ nhanh: va chạm ngay
            if f0 <= penetrationLevel { return 0 }                   // đã lấn quá ngưỡng: tách ngay
            guard h > 0 else { return nil }
            // Tiếp xúc chậm: chờ tới khi lấn quá ngưỡng.
            var c = coeffs; c[0] -= penetrationLevel
            for r in Polynomial.realRoots(c, in: 0, h) where r > 0 {
                if Polynomial.evaluate(dcoeffs, r) < 0 { return r }
            }
            return nil
        }
        guard h > 0 else { return nil }
        for r in Polynomial.realRoots(coeffs, in: 0, h) where r > 0 {
            if Polynomial.evaluate(dcoeffs, r) < 0 { return r }
        }
        return nil
    }

    private func pairTime(_ a: Ball, _ b: Ball, horizon: Double) -> Double? {
        let (pa, va, aa) = motion(a)
        let (pb, vb, ab) = motion(b)
        return approachTime(C: pb - pa, B: vb - va, A: ab - aa, distance: 2 * R, horizon: horizon)
    }

    /// Băng, mũi băng, lỗ, và biên an toàn cho một bi.
    private func wallEvents(_ b: Ball, index i: Int, horizon: Double) -> [Candidate] {
        let (p0, v0, a2) = motion(b)
        let h = horizon.isFinite ? horizon : 60
        var out: [Candidate] = []

        // Băng: thành phần pháp tuyến n·p(t) = R (tính từ đường băng), đang tiến vào băng.
        for (k, seg) in geometry.cushions.enumerated() {
            let horizontal = seg.rail <= 1
            let base: Double = seg.rail == 1 ? geometry.width : seg.rail == 3 ? geometry.length : 0
            let sign: Double = (seg.rail == 1 || seg.rail == 3) ? -1 : 1
            // Khoảng cách tâm bi tới đường băng trừ R: c0 + c1·t + c2·t².
            let c0 = sign * ((horizontal ? p0.y : p0.x) - base) - R
            let c1 = sign * (horizontal ? v0.y : v0.x)
            let c2 = sign * (horizontal ? a2.y : a2.x)
            func inSegment(_ t: Double) -> Bool {
                let p = p0 + v0 * t + a2 * t * t
                let along = horizontal ? p.x : p.y
                return along >= seg.from && along <= seg.to
            }
            if c0 <= 1e-12 {
                // Đang chạm băng.
                let pen = CollisionThresholds.penetration
                if c1 <= -CollisionThresholds.minApproachSpeed || c0 <= -pen {
                    if inSegment(0) { out.append(Candidate(time: 0, kind: .cushion, i: i, extra: k)) }
                } else if let r = Polynomial.realRoots([c0 + pen, c1, c2], in: 0, h)
                            .first(where: { $0 > 0 && c1 + 2 * c2 * $0 < 0 }), inSegment(r) {
                    out.append(Candidate(time: r, kind: .cushion, i: i, extra: k))
                }
                continue
            }
            if let r = Polynomial.realRoots([c0, c1, c2], in: 0, h).first(where: { $0 > 0 && c1 + 2 * c2 * $0 < 0 }),
               inSegment(r) {
                out.append(Candidate(time: r, kind: .cushion, i: i, extra: k))
            }
        }
        // Mũi băng (điểm cố định).
        for (k, q) in geometry.jaws.enumerated() {
            if let t = approachTime(C: p0 - q, B: v0, A: a2, distance: R, horizon: h) {
                out.append(Candidate(time: t, kind: .jaw, i: i, extra: k))
            }
        }
        // Lỗ: w·p(t) + k = 0, đang đi vào lỗ.
        for pocket in geometry.pockets {
            let w = pocket.captureNormal
            let c = [simd_dot(w, p0) + pocket.captureOffset, simd_dot(w, v0), simd_dot(w, a2)]
            if c[0] <= 0, geometry.sidePocketAccepts(pocket.id, x: p0.x) {
                out.append(Candidate(time: 0, kind: .drop, i: i, extra: pocket.id)); continue
            }
            for r in Polynomial.realRoots(c, in: 0, h) where r > 0 {
                if c[1] + 2 * c[2] * r >= 0 { continue }
                let p = p0 + v0 * r + a2 * r * r
                if geometry.sidePocketAccepts(pocket.id, x: p.x) {
                    out.append(Candidate(time: r, kind: .drop, i: i, extra: pocket.id))
                }
                break
            }
        }
        // Biên an toàn: bi thoát khỏi bàn vì lý do ngoài mô hình → coi như rơi lỗ gần nhất.
        let margin = 2 * R
        let bounds: [(SIMD2<Double>, Double)] = [
            (SIMD2(1, 0), margin), (SIMD2(-1, 0), geometry.length + margin),
            (SIMD2(0, 1), margin), (SIMD2(0, -1), geometry.width + margin)
        ]
        for (w, k) in bounds {
            let c = [simd_dot(w, p0) + k, simd_dot(w, v0), simd_dot(w, a2)]
            if let r = Polynomial.realRoots(c, in: 0, h).first(where: { $0 > 0 && c[1] + 2 * c[2] * $0 < 0 }) {
                out.append(Candidate(time: r, kind: .bounds, i: i))
            }
        }
        return out
    }

    // MARK: Tách chồng lấn

    /// Chiếu vị trí để mọi cặp bi cách nhau ≥ 2R (cặp tiếp xúc tựa: ≥ 2R + `separationGap`).
    /// Gauss–Seidel theo thứ tự chỉ số cố định → xác định từng bit. Bi bị dời được đánh dấu để tính lại dự đoán.
    private func separateOverlaps(_ balls: inout [Ball], resting: Set<Int>, dirty: inout Set<Int>) {
        let n = balls.count
        let gap = CollisionThresholds.separationGap
        for _ in 0..<64 {
            var moved = false
            for i in 0..<n where balls[i].state != .pocketed {
                for j in (i + 1)..<max(i + 1, n) where balls[j].state != .pocketed {
                    var d = balls[j].position - balls[i].position
                    d.z = 0
                    let dist = simd_length(d)
                    let target = resting.contains(i * n + j) ? 2 * R + gap : 2 * R
                    guard dist < target - 1e-12, dist > 0 else { continue }
                    let push = (target - dist) / 2 * (d / dist)
                    balls[i].position -= push
                    balls[j].position += push
                    dirty.insert(i); dirty.insert(j)
                    moved = true
                }
            }
            if !moved { break }
        }
    }

    // MARK: Xử lý sự kiện

    private func resolve(_ e: Candidate, _ balls: inout [Ball], time: Double) -> CollisionRecord? {
        guard balls[e.i].state != .pocketed else { return nil }
        switch e.kind {
        case .ballBall:
            guard balls[e.j].state != .pocketed else { return nil }
            var a = balls[e.i], b = balls[e.j]
            var d = b.position - a.position; d.z = 0
            // Sau một va chạm khác trong cùng thời điểm, cặp này có thể không còn chạm/lại gần.
            guard simd_length(d) <= 2 * R * (1 + 1e-7) else { return nil }
            let ((a2, b2), info) = BallBallCollision.resolveWithInfo(a, b, parameters, mass: m, radius: R)
            a = a2; b = b2
            // Vị trí được tách sau cả lượt va chạm đồng thời (`separateOverlaps`), không tách từng cặp ở đây.
            balls[e.i] = a; balls[e.j] = b
            guard let info else { return nil }
            return CollisionRecord(kind: .ballBall, time: time, position: 0.5 * (a.position + b.position),
                                   ballIds: [a.id, b.id], relativeNormalSpeed: info.relativeNormalSpeed,
                                   impulse: info.normalImpulse, tangentialSlip: info.tangentialSlip, pocketId: nil)

        case .cushion:
            let seg = geometry.cushions[e.extra]
            var (out, info) = CushionCollision.resolve(balls[e.i], inward: seg.inwardNormal,
                                                       cushionHeight: table.cushionHeight,
                                                       parameters, mass: m, radius: R)
            // Đưa tâm bi về đúng khoảng R (cộng khe nhỏ nếu là tiếp xúc tựa).
            let minDist = R + (info == nil ? CollisionThresholds.separationGap : 0)
            switch seg.rail {
            case 0: out.position.y = max(out.position.y, minDist)
            case 1: out.position.y = min(out.position.y, geometry.width - minDist)
            case 2: out.position.x = max(out.position.x, minDist)
            default: out.position.x = min(out.position.x, geometry.length - minDist)
            }
            balls[e.i] = out
            guard let info else { return nil }
            let n = seg.inwardNormal
            let contact = out.position - R * SIMD3(n.x, n.y, 0)
            return CollisionRecord(kind: .ballCushion, time: time, position: contact, ballIds: [out.id],
                                   relativeNormalSpeed: info.relativeNormalSpeed, impulse: info.normalImpulse,
                                   tangentialSlip: info.tangentialSlip, pocketId: nil)

        case .jaw:
            let q = geometry.jaws[e.extra]
            let b = balls[e.i]
            var n = SIMD2(b.position.x, b.position.y) - q
            let len = simd_length(n)
            guard len > 0, len <= R + 1e-7 else { return nil }
            n /= len
            var (out, info) = CushionCollision.resolve(b, inward: n, cushionHeight: table.cushionHeight,
                                                       parameters, mass: m, radius: R)
            let minDist = R + (info == nil ? CollisionThresholds.separationGap : 0)
            if len < minDist {
                let q3 = SIMD3(q.x, q.y, out.position.z)
                out.position = q3 + SIMD3(n.x, n.y, 0) * minDist
            }
            balls[e.i] = out
            guard let info else { return nil }
            return CollisionRecord(kind: .ballJaw, time: time, position: SIMD3(q.x, q.y, table.cushionHeight),
                                   ballIds: [out.id], relativeNormalSpeed: info.relativeNormalSpeed,
                                   impulse: info.normalImpulse, tangentialSlip: info.tangentialSlip, pocketId: nil)

        case .drop, .bounds:
            var b = balls[e.i]
            let speed = simd_length(b.velocity)
            let pocketId: Int
            if e.kind == .drop { pocketId = e.extra } else {
                let p = SIMD2(b.position.x, b.position.y)
                pocketId = geometry.pockets.min { simd_distance($0.center, p) < simd_distance($1.center, p) }!.id
            }
            let at = b.position
            b.state = .pocketed
            b.velocity = .zero
            b.angularVelocity = .zero
            balls[e.i] = b
            return CollisionRecord(kind: .ballDrop, time: time, position: at, ballIds: [b.id],
                                   relativeNormalSpeed: speed, impulse: m * speed, tangentialSlip: 0,
                                   pocketId: pocketId)
        }
    }
}
