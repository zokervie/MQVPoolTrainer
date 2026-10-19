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
    private lazy var softShadow = TableDecor.softShadowMaterial()

    init(table: TableSpec) {
        self.table = table
        self.mapping = RenderMapping(table: table)
        buildTable()
        root.addChild(camera)
        root.addChild(markers)
        buildCue()
        buildRoom()
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
        var clothMat = TableDecor.felt(clothColor, tiles: [L / 0.06, W / 0.06], texture: feltTex)
        if let n = TableDecor.feltNormal() { clothMat.normal = .init(texture: .init(n)) }
        let cloth = ModelEntity(mesh: .generatePlane(width: L, depth: W), materials: [clothMat])
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
        var woodBoxMat = woodMat
        woodBoxMat.textureCoordinateTransform = .init(offset: .zero, scale: [1, 1], rotation: 0)
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
                                materials: [woodBoxMat])
            e.position = map(SIMD3((x0 + x1) / 2, (y0 + y1) / 2, hw / 2))
            root.addChild(e)
        }
        func addPocket(center c: SIMD2<Double>, radius r: Double, outward theta: Double, halfArc: Double) {
            let disc = ModelEntity(mesh: .generateCylinder(height: 0.002, radius: Float(r)), materials: [dark])
            disc.position = map(SIMD3(c.x, c.y, 0.0009))
            root.addChild(disc)
            if let mesh = TableDecor.ring(center: c, inner: r, outer: r + 0.02, z: hw + 0.0008,
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

    /// Cơ nhiều đoạn (đầu tẩy xanh phấn, khâu trắng, ngọn gỗ phong vuốt thon, khớp kim loại, gốc gỗ mun,
    /// cuốn tay đen). Trục +z của `cue` hướng về đuôi cơ, đầu tẩy ở gốc tọa độ.
    private func buildCue() {
        let parts: [(Float, Float, Float, Float, PhysicallyBasedMaterial)] = [
            (0.000, 0.006, 0.0062, 0.0064, TableDecor.pbr(UIColor(red: 0.18, green: 0.40, blue: 0.72, alpha: 1), roughness: 0.9)),
            (0.006, 0.030, 0.0064, 0.0065, TableDecor.pbr(UIColor(white: 0.96, alpha: 1), roughness: 0.25, clearcoat: 0.6)),
            (0.030, 0.740, 0.0065, 0.0105, TableDecor.pbr(UIColor(red: 0.90, green: 0.80, blue: 0.62, alpha: 1), roughness: 0.3, clearcoat: 0.8)),
            (0.740, 0.765, 0.0108, 0.0110, TableDecor.pbr(UIColor(white: 0.75, alpha: 1), roughness: 0.15, metallic: 1)),
            (0.765, 1.050, 0.0110, 0.0125, TableDecor.pbr(UIColor(red: 0.10, green: 0.05, blue: 0.03, alpha: 1), roughness: 0.2, clearcoat: 1)),
            (1.050, 1.300, 0.0128, 0.0135, TableDecor.pbr(UIColor(white: 0.06, alpha: 1), roughness: 0.85)),
            (1.300, 1.450, 0.0135, 0.0145, TableDecor.pbr(UIColor(red: 0.16, green: 0.07, blue: 0.04, alpha: 1), roughness: 0.2, clearcoat: 1))
        ]
        for (z0, z1, r0, r1, mat) in parts {
            guard let mesh = TableDecor.frustum(r0: r0, r1: r1, length: z1 - z0) else { continue }
            let e = ModelEntity(mesh: mesh, materials: [mat])
            e.position = [0, 0, z0]
            cue.addChild(e)
        }
        root.addChild(cue)
    }

    // MARK: Phòng bida

    private let lamp = Entity()

    /// Phòng: sàn gỗ, tường ốp ván gỗ (chân tường tối), trần tối, bộ đèn bàn dài, giá cơ và khung tranh.
    /// Chỉ để tạo không gian thật như ảnh tham khảo; không ảnh hưởng vật lý.
    private func buildRoom() {
        let floorY: Float = -0.76, wallH: Float = 3.4, halfX: Float = 4.0, halfZ: Float = 3.0
        var floorMat = TableDecor.pbr(UIColor(red: 0.30, green: 0.18, blue: 0.10, alpha: 1), roughness: 0.5, clearcoat: 0.3)
        if let t = TableDecor.planks(seed: 0xF100) {
            floorMat.baseColor = .init(tint: UIColor(red: 0.42, green: 0.26, blue: 0.15, alpha: 1), texture: .init(t))
            floorMat.textureCoordinateTransform = .init(offset: .zero, scale: [6, 4], rotation: .pi / 2)
        }
        let floor = ModelEntity(mesh: .generatePlane(width: 2 * halfX, depth: 2 * halfZ), materials: [floorMat])
        floor.position = [0, floorY + 0.001, 0]
        root.addChild(floor)

        var panel = TableDecor.pbr(UIColor(red: 0.45, green: 0.27, blue: 0.14, alpha: 1), roughness: 0.45, clearcoat: 0.4)
        if let t = TableDecor.planks(seed: 0xA11) {
            panel.baseColor = .init(tint: UIColor(red: 0.55, green: 0.33, blue: 0.18, alpha: 1), texture: .init(t))
            panel.textureCoordinateTransform = .init(offset: .zero, scale: [8, 1], rotation: 0)
        }
        var dado = panel
        dado.baseColor = .init(tint: UIColor(red: 0.20, green: 0.11, blue: 0.06, alpha: 1))
        let ceiling = TableDecor.pbr(UIColor(white: 0.07, alpha: 1), roughness: 0.9)
        // Bốn tường (mặt phẳng đứng hướng vào trong).
        let walls: [(SIMD3<Float>, Float, Float)] = [
            ([0, 0, -halfZ], 0, 2 * halfX), ([0, 0, halfZ], .pi, 2 * halfX),
            ([-halfX, 0, 0], .pi / 2, 2 * halfZ), ([halfX, 0, 0], -.pi / 2, 2 * halfZ)
        ]
        for (p, yaw, width) in walls {
            let upper = ModelEntity(mesh: .generatePlane(width: width, height: wallH - 1.0), materials: [panel])
            upper.position = p + [0, floorY + 1.0 + (wallH - 1.0) / 2, 0]
            upper.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            root.addChild(upper)
            let low = ModelEntity(mesh: .generatePlane(width: width, height: 1.0), materials: [dado])
            low.position = p + [0, floorY + 0.5, 0]
            low.orientation = upper.orientation
            root.addChild(low)
        }
        let ceil = ModelEntity(mesh: .generatePlane(width: 2 * halfX, depth: 2 * halfZ), materials: [ceiling])
        ceil.position = [0, floorY + wallH, 0]
        ceil.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        root.addChild(ceil)

        // Giá cơ trên tường xa (đầu bàn) và hai khung tranh.
        let rackWood = TableDecor.pbr(UIColor(red: 0.25, green: 0.13, blue: 0.07, alpha: 1), roughness: 0.4, clearcoat: 0.5)
        let rack = ModelEntity(mesh: .generateBox(size: [0.9, 0.06, 0.06], cornerRadius: 0.01), materials: [rackWood])
        rack.position = [-halfX + 0.04, floorY + 0.25, -0.9]
        rack.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
        root.addChild(rack)
        let maple = TableDecor.pbr(UIColor(red: 0.88, green: 0.77, blue: 0.58, alpha: 1), roughness: 0.3, clearcoat: 0.6)
        for k in 0..<5 {
            guard let m = TableDecor.frustum(r0: 0.014, r1: 0.007, length: 1.45, segments: 12) else { continue }
            let c = ModelEntity(mesh: m, materials: [maple])
            c.position = [-halfX + 0.06, floorY + 0.03, -1.25 + Float(k) * 0.17]
            c.orientation = simd_quatf(angle: -.pi / 2 + 0.06, axis: [1, 0, 0])
            root.addChild(c)
        }
        let frameMat = TableDecor.pbr(UIColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 1), roughness: 0.3, clearcoat: 0.8)
        let art = TableDecor.pbr(UIColor(red: 0.42, green: 0.36, blue: 0.27, alpha: 1), roughness: 0.8)
        for x: Float in [-1.2, 1.2] {
            let f = ModelEntity(mesh: .generateBox(size: [0.9, 0.62, 0.03]), materials: [frameMat])
            f.position = [x, floorY + 1.75, -halfZ + 0.02]
            root.addChild(f)
            let a = ModelEntity(mesh: .generatePlane(width: 0.78, height: 0.5), materials: [art])
            a.position = [x, floorY + 1.75, -halfZ + 0.04]
            root.addChild(a)
        }

        // Bộ đèn bàn: chụp kim loại dài, mặt dưới phát sáng ấm. Ẩn khi nhìn từ trên (che bàn).
        let metal = TableDecor.pbr(UIColor(red: 0.08, green: 0.16, blue: 0.10, alpha: 1), roughness: 0.35, metallic: 0.6)
        let shade = ModelEntity(mesh: .generateBox(size: [1.7, 0.12, 0.42], cornerRadius: 0.02), materials: [metal])
        shade.position = [0, 1.06, 0]
        lamp.addChild(shade)
        let glow = ModelEntity(mesh: .generatePlane(width: 1.6, depth: 0.34),
                               materials: [UnlitMaterial(color: UIColor(red: 1, green: 0.95, blue: 0.84, alpha: 1))])
        glow.position = [0, 0.999, 0]
        glow.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        lamp.addChild(glow)
        for x: Float in [-0.6, 0.6] {
            let rod = ModelEntity(mesh: .generateCylinder(height: 1.8, radius: 0.004), materials: [metal])
            rod.position = SIMD3<Float>(x, 2.02, 0)
            lamp.addChild(rod)
        }
        root.addChild(lamp)
    }

    /// Nhìn từ trên: ẩn bộ đèn để không che bàn (lỗi từng gặp ở BankLab 0.6).
    func setOverview(_ on: Bool) { lamp.isEnabled = !on }

    private func addLights() {
        // Đèn chính: hai đèn chiếu từ bộ đèn bàn xuống, có bóng đổ (mềm nhờ lọc PCF + bóng tiếp xúc riêng).
        // Ba đèn chiếu chùm rộng để mặt nỉ sáng đều tới góc bàn (hai đèn chùm hẹp để lại vùng tối ở giữa).
        for x: Float in [-0.75, 0, 0.75] {
            let spot = SpotLight()
            spot.light.intensity = 17_000
            spot.light.innerAngleInDegrees = 70
            spot.light.outerAngleInDegrees = 125
            spot.light.attenuationRadius = 4
            spot.light.color = UIColor(red: 1, green: 0.95, blue: 0.86, alpha: 1)
            spot.shadow = SpotLightComponent.Shadow()
            spot.position = [x, 0.98, 0]
            spot.look(at: [x, 0, 0], from: spot.position, relativeTo: nil)
            root.addChild(spot)
        }
        // Đèn phụ yếu từ phía người chơi, không bóng, để mặt trước bi không tối hẳn.
        let fill = DirectionalLight()
        fill.light.intensity = 1_600
        fill.look(at: .zero, from: [0.3, 1.5, 2.5], relativeTo: nil)
        root.addChild(fill)
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
                let s = ModelEntity(mesh: .generatePlane(width: R * 3.4, depth: R * 3.4), materials: [softShadow])
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
            // Bi nhảy: bóng loang rộng và nhạt dần theo độ cao.
            let lift = Float(max(0, b.position.z - table.ballRadius))
            shadows[b.id]?.scale = SIMD3(repeating: 1 + lift * 9)
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
        let tail = mapping.directionToRender(-axis)
        // Trục +z của entity `cue` hướng về phía đuôi cơ.
        cue.look(at: cue.position - tail, from: cue.position, relativeTo: nil)
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
            // Góc cúi đánh: mắt sau bi ~0,6 m (bản đầu 0,85 m — bàn nhìn xa và nhỏ), nhìn hơi xuống.
            let eye = anchor - dir * 0.6 + SIMD3(0, 0, eyeHeight)
            let target = anchor + dir * 1.0
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
