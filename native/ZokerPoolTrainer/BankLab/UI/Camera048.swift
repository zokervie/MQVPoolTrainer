import UIKit
import SceneKit
import simd

/// 0.48 M2 "Máy quay": the replay angle menu is 2 automatic + 6 hand-picked angles. Every angle reads its camera path
/// (eye, target, lens) and its playback-speed curve from `BLCameraPlan`, planned ONCE on the whole recording when the
/// replay opens (the old action cameras placed the camera from the current frame and swung after every contact).
enum ReplayAngle048: Int, CaseIterable {
    case director = 0, learn, shooter, wide, overhead, followCue, railSide, pocketMeet

    var title: String {
        switch self {
        case .director: return L10n.tr("Đạo diễn")
        case .learn: return L10n.tr("Học")
        case .shooter: return L10n.tr("Người đánh")
        case .wide: return L10n.tr("Toàn bàn 3/4")
        case .overhead: return L10n.tr("Trên cao")
        case .followCue: return L10n.tr("Theo bi cái")
        case .railSide: return L10n.tr("Ngang băng")
        case .pocketMeet: return L10n.tr("Đón ở lỗ")
        }
    }
    var subtitle: String {
        switch self {
        case .director: return L10n.tr("Tự cắt cảnh như phim, chậm lúc va chạm")
        case .learn: return L10n.tr("Nhìn cao, vệt đường bi hiện dần, điểm chạm")
        default: return ""
        }
    }
    var style: BLCameraStyle { BLCameraStyle(rawValue: rawValue) ?? .director }
    static let automatic: [ReplayAngle048] = [.director, .learn]
    static let manual: [ReplayAngle048] = [.shooter, .wide, .overhead, .followCue, .railSide, .pocketMeet]

    /// 0.41–0.47 stored 0…13 under `replayCamera041`; each old angle maps to the nearest new one (no setting is lost).
    static func fromLegacy041(_ k: Int) -> ReplayAngle048 {
        switch k {
        case 1: return .shooter
        case 2, 7: return .wide          // Toàn bàn, Cẩu quay
        case 3, 12: return .overhead     // Trên cao, Trên đầu theo bi
        case 4, 5, 10: return .followCue // bám bi cái, bám bi mục tiêu, chéo 45°
        case 6, 11: return .pocketMeet   // đón ở lỗ, đón đầu
        case 9: return .railSide
        default: return .director        // Điện ảnh, Action Mix, Xoay va chạm, unknown
        }
    }
    static let key = "replayCamera048"
    static var stored: ReplayAngle048 {
        get {
            let d = UserDefaults.standard
            if let v = d.object(forKey: key) as? Int { return ReplayAngle048(rawValue: v) ?? .director }
            let migrated = fromLegacy041(d.integer(forKey: Prefs.replayCamera))
            d.set(migrated.rawValue, forKey: key)
            return migrated
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

/// Builds the planner input from the replay buffers (frames × balls, flattened row-major in the order of `ids`).
enum CameraPlan048 {
    static func make(frames: [[BallState]], times: [Double], events: [[String: NSNumber]], aimAngle: Double,
                     angle: ReplayAngle048, aspect: Double, lead: Double, tail: Double, teaser: Bool = false) -> BLCameraPlan? {
        guard !frames.isEmpty, frames.count == times.count else { return nil }
        var ids: [Int32] = []
        var seen = Set<Int>()
        for frame in frames { for b in frame where !seen.contains(b.id) { seen.insert(b.id); ids.append(Int32(b.id)) } }
        let m = ids.count, n = frames.count
        guard m > 0 else { return nil }
        let column = Dictionary(uniqueKeysWithValues: ids.enumerated().map { (Int($0.element), $0.offset) })
        var xs = [Double](repeating: 0, count: n * m), ys = xs
        var sunk = [UInt8](repeating: 1, count: n * m)
        var last = [Int: (Double, Double)]()
        for (f, frame) in frames.enumerated() {
            var present = Set<Int>()
            for b in frame { guard let c = column[b.id] else { continue }
                xs[f * m + c] = b.x; ys[f * m + c] = b.y; sunk[f * m + c] = b.sunk ? 1 : 0; last[b.id] = (b.x, b.y); present.insert(b.id) }
            for (id, c) in column where !present.contains(id) { if let p = last[id] { xs[f * m + c] = p.0; ys[f * m + c] = p.1 } }
        }
        let style: BLCameraStyle = teaser ? .teaser : angle.style
        return times.withUnsafeBufferPointer { t in ids.withUnsafeBufferPointer { i in xs.withUnsafeBufferPointer { x in
            ys.withUnsafeBufferPointer { y in sunk.withUnsafeBufferPointer { s in
                BLCameraPlan(frameCount: n, times: t.baseAddress!, ballCount: m, ids: i.baseAddress!, xs: x.baseAddress!, ys: y.baseAddress!,
                             sunk: s.baseAddress!, events: events, aimAngle: aimAngle, style: style,
                             aspect: aspect.isFinite && aspect > 0 ? aspect : 16.0 / 9.0, lead: lead, tail: tail)
            } } } } }
    }
}

/// 0.48 M4: measured smoothness of the camera the viewer actually saw in the last replay (rendered camera node,
/// including glides), shown in Diagnostics as "Tốc độ góc máy p95/max".
final class CameraSmoothness048 {
    static var last: (p95: Double, peak: Double, planP95: Double, planPeak: Double, visible: Double, samples: Int)?
    private var previous: SIMD3<Float>?
    private var speeds: [Double] = []
    private var lastScene = -1
    func sample(front: SIMD3<Float>, dt: Double, scene: Int) {
        defer { previous = front; lastScene = scene }
        guard dt > 1e-4, let prev = previous, scene == lastScene else { return }   // a planned cut is not a swing
        let c = Double(max(-1, min(1, simd_dot(simd_normalize(prev), simd_normalize(front)))))
        speeds.append(acos(c) * 180 / .pi / dt)
    }
    func finish(plan: BLCameraPlan?) {
        guard !speeds.isEmpty else { return }
        let sorted = speeds.sorted()
        let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        Self.last = (p95, sorted.last ?? 0, plan?.p95AngularSpeed ?? 0, plan?.peakAngularSpeed ?? 0, plan?.minVisibleFraction ?? 0, sorted.count)
    }
}

extension TrainingController {
    /// Plans the camera for the replay buffers now loaded, for the chosen angle and the view's aspect.
    func planReplayCamera048(aspect: Double? = nil) {
        let a = aspect ?? Double(scn.bounds.width / max(1, scn.bounds.height))
        cameraPlan048 = CameraPlan048.make(frames: frames, times: frameTimes, events: lastShotEvents,
                                           aimAngle: lastShot?.aimAngle ?? angle, angle: replayAngle048, aspect: a,
                                           lead: replayLead, tail: Self.replayTail, teaser: teaserExport048)
        trailCache048 = nil; trailShown048 = -1
    }
    /// Per replay frame: camera from the plan (unless the viewer took the camera by hand) + trails in Learn / Director's wrap.
    func applyReplayCamera048(clock: Double, dt: Double) {
        guard let plan = cameraPlan048 else { table.actionCamera = nil; return }
        if cameraManual { table.actionCamera = nil }
        else {
            var eye = simd_float3(), target = simd_float3(); var fov: Float = 40
            plan.pose(at: clock, eye: &eye, target: &target, fov: &fov)
            if eye.x.isFinite, eye.y.isFinite, eye.z.isFinite, target.x.isFinite, fov.isFinite {
                table.actionCamera = (eye: eye, target: target, fov: fov)
            }
            if !replayPaused { cameraSmooth048.sample(front: table.camera.simdWorldFront, dt: dt, scene: plan.sceneIndex(at: clock)) }
        }
        updateReplayTrails048(clock: clock, reveal: plan.trailReveal(at: clock))
    }
    /// Trails: cue ball white, object balls in their own colour; Learn grows them with time and marks rails + the ghost ball.
    func updateReplayTrails048(clock: Double, reveal: Double) {
        let learn = replayAngle048 == .learn
        if !learn && reveal < 0.5 { if trailShown048 != 0 { table.replayTrails048([:], ghost: nil); table.showRailContacts([]); trailShown048 = 0 }; return }
        if trailCache048 == nil {
            var cache: [Int: [(Double, SIMD3<Float>)]] = [:]
            var lastT = -1.0
            for (f, frame) in frames.enumerated() where f == 0 || f == frames.count - 1 || frameTimes[f] - lastT >= 1.0 / 30 {
                lastT = frameTimes[f]
                for b in frame where !b.sunk { cache[b.id, default: []].append((frameTimes[f], SIMD3(Float(b.x), Float((b.height ?? 0) + 0.004), Float(b.y)))) }
            }
            trailCache048 = cache
        }
        let until = learn ? clock : .infinity
        let cache = trailCache048 ?? [:]
        let count = cache.values.reduce(0) { $0 + $1.prefix { $0.0 <= until }.count }
        guard count != trailShown048 else { return }
        trailShown048 = count
        var paths: [Int: [SIMD3<Float>]] = [:]
        for (id, pts) in cache { let p = pts.prefix { $0.0 <= until }.map { $0.1 }; if p.count > 1 { paths[id] = p } }
        // Ghost ball: where the cue ball was at its first ball contact (Learn only, once that moment has played).
        var ghost: SIMD2<Float>?
        if learn, let hit = lastShotEvents.first(where: { $0["kind"]?.intValue == 1 && ($0["a"]?.intValue == 0 || $0["b"]?.intValue == 0) }),
           let t = hit["time"]?.doubleValue, t <= until, let f = frameTimes.lastIndex(where: { $0 <= t }),
           let cue = frames[f].first(where: { $0.id == 0 }) { ghost = SIMD2(Float(cue.x), Float(cue.y)) }
        table.replayTrails048(paths, ghost: ghost)
        let rails = lastShotEvents.filter { $0["kind"]?.intValue == 0 && ($0["time"]?.doubleValue ?? 0) <= until }
            .compactMap { e -> (x: Double, y: Double)? in guard let x = e["x"]?.doubleValue, let y = e["y"]?.doubleValue else { return nil }; return (x, y) }
        table.showRailContacts(learn ? rails : [])
    }
}

extension TableScene {
    /// 0.48: replay trail map (cue white, object balls in ball colour) + optional ghost ball, in the trail layer.
    func replayTrails048(_ paths: [Int: [SIMD3<Float>]], ghost: SIMD2<Float>?) {
        trails([:])
        let root = replayTrailRoot048
        root.childNodes.forEach { $0.removeFromParentNode() }
        for (id, points) in paths where points.count > 1 {
            let source = SCNGeometrySource(vertices: points.map { SCNVector3($0.x, max(0.004, $0.y), $0.z) })
            var indices: [Int32] = []
            for i in 1..<points.count { indices += [Int32(i - 1), Int32(i)] }
            let g = SCNGeometry(sources: [source], elements: [SCNGeometryElement(indices: indices, primitiveType: .line)])
            let m = SCNMaterial(); m.lightingModel = .constant; m.writesToDepthBuffer = false
            let colour = id == 0 ? UIColor(white: 0.97, alpha: 1) : TableScene.colors[id <= 8 ? id : max(1, id - 8)]
            m.diffuse.contents = colour.withAlphaComponent(0.85)
            g.materials = [m]; let n = SCNNode(geometry: g); n.castsShadow = false; n.renderingOrder = 40; root.addChildNode(n)
        }
        if let g = ghost {
            let sphere = SCNSphere(radius: 0.028575); sphere.segmentCount = 24
            let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = UIColor(white: 1, alpha: 0.30); m.writesToDepthBuffer = false
            sphere.materials = [m]
            let n = SCNNode(geometry: sphere); n.position = SCNVector3(g.x, 0.028575, g.y); n.castsShadow = false; n.renderingOrder = 41
            root.addChildNode(n)
        }
    }
    var replayTrailRoot048: SCNNode {
        if let n = scene.rootNode.childNode(withName: "replay-trails-048", recursively: false) { return n }
        let n = SCNNode(); n.name = "replay-trails-048"; scene.rootNode.addChildNode(n); return n
    }
}
