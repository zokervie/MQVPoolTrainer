import RealityKit
import UIKit
import simd
import PoolPhysics
import PoolDrills

/// Dựng và cập nhật cảnh 3D trong ARView (chế độ non-AR).
/// Mọi tọa độ vật lý đổi sang RealityKit qua `RenderMapping` (hàm đổi tọa độ duy nhất).
@MainActor
final class TableScene {
    let root = AnchorEntity(world: .zero)
    let camera = PerspectiveCamera()
    private var ballEntities: [Int: ModelEntity] = [:]
    private var shadows: [Int: ModelEntity] = [:]
    private let cue = ModelEntity()
    private var markers = Entity()
    private var lastBalls: [Int: Ball] = [:]
    private var mapping: RenderMapping
    private var table: TableSpec
    private var orientations: [Int: simd_quatf] = [:]

    init(table: TableSpec) {
        self.table = table
        self.mapping = RenderMapping(table: table)
        buildTable()
        root.addChild(camera)
        root.addChild(markers)
        buildCue()
        addLights()
    }

    // MARK: Bàn

    private func buildTable() {
        let L = Float(table.length), W = Float(table.width)
        let Ld = table.length, Wd = table.width
        let map: TableDecor.Map = { [mapping] in mapping.toRender($0) }
        let feltTex = TableDecor.texture(kind: "felt"), woodTex = TableDecor.texture(kind: "wood")
        let clothColor = UIColor(red: 0.05, green: 0.36, blue: 0.22, alpha: 1)

        // Nỉ có thớ (một ô vân ~6 cm).
        let cloth = ModelEntity(mesh: .generatePlane(width: L, depth: W),
                                materials: [TableDecor.felt(clothColor, tiles: [L / 0.06, W / 0.06], texture: feltTex)])
        root.addChild(cloth)

        // Băng: tiết diện có mũi băng ở đúng chiều cao vật lý (u = 0 là đường băng, âm = ra ngoài bàn).
        let geo = TableGeometry(table)
        let hc = table.cushionHeight
        let hw = hc * 1.25                         // mặt gỗ
        let railDepth = 0.05, frame = 0.12
        let cushionProfile: [SIMD2<Double>] = [
            [-railDepth, 0], [-0.022, 0], [0, hc], [-0.006, hc + 0.007], [-railDepth, hc + 0.009]
        ]
        let woodProfile: [SIMD2<Double>] = [
            [-railDepth, 0], [-railDepth - frame, 0], [-railDepth - frame, hw - 0.008],
            [-railDepth - frame + 0.007, hw], [-railDepth, hw]
        ]
        let cushionMat = TableDecor.felt(UIColor(red: 0.045, green: 0.32, blue: 0.20, alpha: 1), tiles: [20, 2], texture: feltTex)
        let woodMat = TableDecor.wood(texture: woodTex)
        func ends(_ seg: TableGeometry.CushionSegment, extend e: Double) -> (SIMD2<Double>, SIMD2<Double>) {
            let f = seg.from - e, t = seg.to + e
            switch seg.rail {
            case 0: return (SIMD2(f, 0), SIMD2(t, 0))
            case 1: return (SIMD2(f, Wd), SIMD2(t, Wd))
            case 2: return (SIMD2(0, f), SIMD2(0, t))
            default: return (SIMD2(Ld, f), SIMD2(Ld, t))
            }
        }
        for seg in geo.cushions {
            let (a, b) = ends(seg, extend: 0)
            if let mesh = TableDecor.extrude(profile: cushionProfile, from: a, to: b, inward: seg.inwardNormal, map: map) {
                root.addChild(ModelEntity(mesh: mesh, materials: [cushionMat]))
            }
            let (wa, wb) = ends(seg, extend: 0.006)
            if let mesh = TableDecor.extrude(profile: woodProfile, from: wa, to: wb, inward: seg.inwardNormal, map: map) {
                root.addChild(ModelEntity(mesh: mesh, materials: [woodMat]))
            }
        }

        // Miệng lỗ: lòng lỗ tối + viền da trên mặt gỗ; khối gỗ góc và sau lỗ giữa (để lại chỗ khoét lỗ).
        let outer = railDepth + frame
        let corners: [(SIMD2<Double>, SIMD2<Double>)] = [
            (SIMD2(0, 0), SIMD2(-1, -1)), (SIMD2(Ld, 0), SIMD2(1, -1)),
            (SIMD2(0, Wd), SIMD2(-1, 1)), (SIMD2(Ld, Wd), SIMD2(1, 1))
        ]
        let dark = UnlitMaterial(color: UIColor(white: 0.015, alpha: 1))
        let leather = TableDecor.leather()
        func addBox(_ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double) {
            let e = ModelEntity(mesh: .generateBox(size: [Float(abs(x1 - x0)), Float(hw), Float(abs(y1 - y0))], cornerRadius: 0.004),
                                materials: [woodMat])
            e.position = map(SIMD3((x0 + x1) / 2, (y0 + y1) / 2, hw / 2))
            root.addChild(e)
        }
        func addPocket(center c: SIMD2<Double>, radius r: Double, outward theta: Double, halfArc: Double) {
            let disc = ModelEntity(mesh: .generateCylinder(height: 0.002, radius: Float(r)), materials: [dark])
            disc.position = map(SIMD3(c.x, c.y, 0.0009))
            root.addChild(disc)
            if let mesh = TableDecor.ring(center: c, inner: r, outer: r + 0.013, z: hw + 0.0006,
                                          from: theta - halfArc, to: theta + halfArc, map: map) {
                root.addChild(ModelEntity(mesh: mesh, materials: [leather]))
            }
        }
        let cr = 0.062, sr = 0.06
        for (corner, d) in corners {
            let c = corner + d * 0.0106
            addPocket(center: c, radius: cr, outward: atan2(d.y, d.x), halfArc: 3 * .pi / 4 + 0.15)
            // Khối gỗ góc hình chữ L, chừa vòng lỗ.
            let gx = corner.x + d.x * 0.075, ox = corner.x + d.x * outer
            let gy = corner.y + d.y * 0.075, oy = corner.y + d.y * outer
            let ix = corner.x - d.x * 0.075, iy = corner.y - d.y * 0.075
            addBox(gx, ox, iy, oy)
            addBox(ix, gx, gy, oy)
        }
        for (y, d) in [(0.0, -1.0), (Wd, 1.0)] {
            let c = SIMD2(Ld / 2, y + d * 0.03)
            addPocket(center: c, radius: sr, outward: d > 0 ? .pi / 2 : 3 * .pi / 2, halfArc: .pi / 2 + 0.25)
            addBox(Ld / 2 - 0.075, Ld / 2 + 0.075, y + d * 0.092, y + d * outer)
        }

        // Thân bàn và sàn phòng (mặt trên thân thấp hơn nỉ 1 cm để tránh z-fighting).
        let outerL = L + 2 * Float(outer), outerW = W + 2 * Float(outer)
        let body = ModelEntity(mesh: .generateBox(size: [outerL * 0.96, 0.22, outerW * 0.96]),
                               materials: [Self.material(UIColor(red: 0.18, green: 0.10, blue: 0.05, alpha: 1), roughness: 0.6)])
        body.position = [0, -0.12, 0]
        root.addChild(body)
        let floor = ModelEntity(mesh: .generatePlane(width: 14, depth: 10),
                                materials: [Self.material(UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1), roughness: 1)])
        floor.position = [0, -0.76, 0]
        root.addChild(floor)

        let h = Float(hc)
        let frameF = Float(frame), railDepthF = Float(railDepth)
        // Kim cương trên khung: rõ và đúng vị trí (dùng cho công thức).
        let pearl = UnlitMaterial(color: UIColor(red: 0.95, green: 0.94, blue: 0.9, alpha: 1))
        let topY = h * 1.25 + 0.001
        let offset = railDepthF + frameF / 2
        for k in 1..<8 where k != 4 {
            let x = Float(k) * L / 8 - L / 2
            for z in [W / 2 + offset, -W / 2 - offset] {
                let d = ModelEntity(mesh: .generateCylinder(height: 0.001, radius: 0.007), materials: [pearl])
                d.position = [x, topY, z]
                root.addChild(d)
            }
        }
        for k in 1..<4 {
            let z = Float(k) * W / 4 - W / 2
            for x in [L / 2 + offset, -L / 2 - offset] {
                let d = ModelEntity(mesh: .generateCylinder(height: 0.001, radius: 0.007), materials: [pearl])
                d.position = [x, topY, z]
                root.addChild(d)
            }
        }
    }

    private func buildCue() {
        let shaft = ModelEntity(mesh: .generateCylinder(height: 1.45, radius: 0.0065),
                                materials: [Self.material(UIColor(red: 0.85, green: 0.72, blue: 0.50, alpha: 1), roughness: 0.4)])
        // Trục cylinder dọc theo y; xoay để nằm dọc theo trục −z của entity cha `cue`.
        shaft.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        shaft.position = [0, 0, 0.725]
        cue.addChild(shaft)
        root.addChild(cue)
    }

    private func addLights() {
        let light = DirectionalLight()
        light.light.intensity = 2_500
        light.shadow = DirectionalLightComponent.Shadow(maximumDistance: 4, depthBias: 2)
        light.look(at: .zero, from: [0.3, 2.2, 0.6], relativeTo: nil)
        root.addChild(light)
        // Đèn trần phòng bida: hai bóng treo trên bàn, sáng tập trung mặt nỉ.
        for x: Float in [-0.6, 0.6] {
            let lamp = PointLight()
            lamp.light.intensity = 9_000
            lamp.light.attenuationRadius = 2.2
            lamp.light.color = UIColor(red: 1, green: 0.96, blue: 0.88, alpha: 1)
            lamp.position = [x, 1.0, 0]
            root.addChild(lamp)
        }
    }

    static func translucent(_ color: UIColor, opacity: Float) -> UnlitMaterial {
        var m = UnlitMaterial(color: color)
        m.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return m
    }

    static func material(_ color: UIColor, roughness: Float) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = 0.0
        return m
    }

    private func ballMaterial(_ number: Int) -> any RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        if let img = BallTextures.image(for: number),
           let tex = try? TextureResource.generate(from: img, options: .init(semantic: .color)) {
            m.baseColor = .init(tint: .white, texture: .init(tex))
        } else {
            m.baseColor = .init(tint: BallTextures.colors[number] ?? .white)
        }
        m.roughness = 0.12
        m.metallic = 0.0
        m.clearcoat = 1.0
        m.clearcoatRoughness = 0.05
        return m
    }

    // MARK: Cập nhật mỗi khung hình

    func updateBalls(_ balls: [Ball], dt: Float) {
        let R = Float(table.ballRadius)
        for b in balls {
            let e: ModelEntity
            if let existing = ballEntities[b.id] { e = existing } else {
                e = ModelEntity(mesh: .generateSphere(radius: R), materials: [ballMaterial(b.id)])
                root.addChild(e)
                ballEntities[b.id] = e
                let s = ModelEntity(mesh: .generateCylinder(height: 0.0005, radius: R * 0.9),
                                    materials: [Self.translucent(UIColor(white: 0, alpha: 1), opacity: 0.35)])
                root.addChild(s)
                shadows[b.id] = s
                orientations[b.id] = simd_quatf(angle: -.pi / 2, axis: [0, 1, 0])
            }
            let hidden = b.state == .pocketed
            e.isEnabled = !hidden
            shadows[b.id]?.isEnabled = !hidden
            guard !hidden else { continue }
            e.position = mapping.toRender(b.position)
            shadows[b.id]?.position = mapping.toRender(SIMD3(b.position.x, b.position.y, 0.0006))
            // Tích phân hướng quay chỉ để hiển thị xoáy.
            let w = mapping.directionToRender(b.angularVelocity)
            let speed = simd_length(w)
            if speed > 1e-6, dt > 0 {
                let q = simd_quatf(angle: speed * dt, axis: w / speed)
                orientations[b.id] = simd_normalize(q * (orientations[b.id] ?? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)))
            }
            if let q = orientations[b.id] { e.orientation = q }
        }
        lastBalls = Dictionary(uniqueKeysWithValues: balls.map { ($0.id, $0) })
    }

    /// Vị trí bi cái lúc ra cơ: cơ đi tiếp (follow-through) tại đây, không chạy theo bi.
    private var cueAnchor: SIMD3<Double>?

    /// Cơ đặt sau bi cái theo hướng ngắm và độ dốc. `pullBack` (m): khoảng đầu cơ cách mặt bi
    /// (âm = đầu cơ đã đi qua vị trí bi — follow-through). `follow` = false: giữ vị trí bi lúc ra cơ.
    func updateCue(aim: Double, tip: SIMD2<Double>, elevation: Double, visible: Bool, pullBack: Float, follow: Bool) {
        if follow, let b = lastBalls[0], b.state != .pocketed { cueAnchor = b.position }
        guard visible, let anchor = cueAnchor else { cue.isEnabled = false; return }
        cue.isEnabled = true
        let R = table.ballRadius
        let dir = SIMD3(cos(aim), sin(aim), 0)
        let left = SIMD3(-dir.y, dir.x, 0)
        // Trục cơ hướng vào bi; cơ ngang vẫn nâng nhẹ ~3° như khi chống cầu tay thật.
        let el = max(elevation, 0.05)
        let axis = cos(el) * dir - sin(el) * SIMD3(0, 0, 1)
        let up = simd_normalize(SIMD3(0, 0, 1) + sin(el) * axis)
        let offset = tip.y * R * up - tip.x * R * left
        let back = max(0, R * R - simd_length_squared(offset)).squareRoot()
        let contact = anchor + offset - back * axis        // điểm chạm trên mặt bi
        let tipPos = contact - axis * (0.002 + Double(pullBack))
        cue.position = mapping.toRender(tipPos)
        let butt = mapping.directionToRender(-axis)
        // Trục +z của entity `cue` hướng về phía đuôi cơ.
        cue.look(at: cue.position - butt, from: cue.position, relativeTo: nil)
    }

    /// Vị trí bi cái mà camera ngôi thứ nhất bám theo. Bị đóng băng khi cú đang chạy/xem lại:
    /// người chơi phải thấy đường bi từ đúng chỗ mình đứng ngắm, không bị camera kéo theo bi cái.
    private var cameraAnchor: SIMD3<Double>?

    func updateCamera(mode: CameraMode, aim: Double, eyeHeight: Double, aspect: Float, follow: Bool = true) {
        if follow || cameraAnchor == nil, let cueBall = lastBalls[0], cueBall.state != .pocketed {
            cameraAnchor = cueBall.position
        }
        guard let anchor = cameraAnchor else { return }
        switch mode {
        case .firstPerson:
            let dir = SIMD3(cos(aim), sin(aim), 0)
            let eye = anchor - dir * 0.85 + SIMD3(0, 0, eyeHeight)
            let target = anchor + dir * 1.2
            camera.look(at: mapping.toRender(target), from: mapping.toRender(eye), relativeTo: nil)
            // FOV dọc ~42°, thu hẹp khi màn hình rất dài để không méo mép.
            camera.camera.fieldOfViewInDegrees = aspect > 2 ? 40 : 44
        case .overview:
            camera.look(at: [0, 0, 0], from: [0, 2.35, 0], upVector: [0, 0, -1], relativeTo: nil)
            camera.camera.fieldOfViewInDegrees = 40
        }
    }

    // MARK: Đánh dấu bài tập (nhãn dán trên nỉ, không phải tia ngắm)

    func showMarkers(for drill: Drill?) {
        markers.removeFromParent()
        markers = Entity()
        root.addChild(markers)
        guard let drill else { return }
        let t = drill.tableSpec
        let zoneMat = Self.translucent(UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1), opacity: 0.28)
        let spotMat = Self.translucent(UIColor(white: 1, alpha: 1), opacity: 0.45)
        for m in drill.danhDau {
            switch m.loai {
            case "vung_dich":
                guard let x = m.x, let y = m.y else { continue }
                let c = t.meters(fromDiamonds: SIMD2(x, y))
                let r = Float((m.banKinh ?? 0.5) * t.diamondSize)
                let e = ModelEntity(mesh: .generateCylinder(height: 0.0004, radius: r), materials: [zoneMat])
                e.position = mapping.toRender(SIMD3(c.x, c.y, 0.0004))
                markers.addChild(e)
            case "vi_tri_bi":
                guard let x = m.x, let y = m.y else { continue }
                let c = t.meters(fromDiamonds: SIMD2(x, y))
                let e = ModelEntity(mesh: .generateCylinder(height: 0.0003, radius: Float(t.ballRadius) * 0.35), materials: [spotMat])
                e.position = mapping.toRender(SIMD3(c.x, c.y, 0.0003))
                markers.addChild(e)
            case "diem_bang":
                guard let canh = m.canh, let k = m.kimCuong else { continue }
                let along = k * t.diamondSize
                let p: SIMD2<Double>
                switch canh {
                case "dai_duoi": p = SIMD2(along, 0.01)
                case "dai_tren": p = SIMD2(along, t.width - 0.01)
                case "ngan_trai": p = SIMD2(0.01, along)
                default: p = SIMD2(t.length - 0.01, along)
                }
                let e = ModelEntity(mesh: .generateCylinder(height: 0.0004, radius: 0.012), materials: [spotMat])
                e.position = mapping.toRender(SIMD3(p.x, p.y, 0.0004))
                markers.addChild(e)
            default: continue
            }
        }
    }
}
