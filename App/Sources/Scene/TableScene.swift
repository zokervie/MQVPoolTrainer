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
        let cloth = ModelEntity(mesh: .generatePlane(width: L, depth: W),
                                materials: [Self.material(UIColor(red: 0.05, green: 0.33, blue: 0.20, alpha: 1), roughness: 0.9)])
        root.addChild(cloth)

        // Băng (cao su) và khung gỗ.
        let h = Float(table.cushionHeight)
        let rubber = Self.material(UIColor(red: 0.04, green: 0.28, blue: 0.17, alpha: 1), roughness: 0.8)
        let wood = Self.material(UIColor(red: 0.30, green: 0.16, blue: 0.08, alpha: 1), roughness: 0.45)
        let geo = TableGeometry(table)
        let railDepth: Float = 0.05, frame: Float = 0.12
        for seg in geo.cushions {
            let len = Float(seg.to - seg.from)
            let mid = Float((seg.from + seg.to) / 2)
            let box: ModelEntity
            switch seg.rail {
            case 0, 1:
                box = ModelEntity(mesh: .generateBox(size: [len, h, railDepth]), materials: [rubber])
                let z = seg.rail == 0 ? W / 2 + railDepth / 2 : -W / 2 - railDepth / 2
                box.position = [mid - L / 2, h / 2, z]
            default:
                box = ModelEntity(mesh: .generateBox(size: [railDepth, h, len]), materials: [rubber])
                let x = seg.rail == 2 ? -L / 2 - railDepth / 2 : L / 2 + railDepth / 2
                box.position = [x, h / 2, -(mid - W / 2)]
            }
            root.addChild(box)
        }
        let outerL = L + 2 * (railDepth + frame), outerW = W + 2 * (railDepth + frame)
        for (size, pos) in [
            (SIMD3<Float>(outerL, h * 1.25, frame), SIMD3<Float>(0, h * 0.62, W / 2 + railDepth + frame / 2)),
            (SIMD3<Float>(outerL, h * 1.25, frame), SIMD3<Float>(0, h * 0.62, -W / 2 - railDepth - frame / 2)),
            (SIMD3<Float>(frame, h * 1.25, outerW), SIMD3<Float>(L / 2 + railDepth + frame / 2, h * 0.62, 0)),
            (SIMD3<Float>(frame, h * 1.25, outerW), SIMD3<Float>(-L / 2 - railDepth - frame / 2, h * 0.62, 0))
        ] {
            let e = ModelEntity(mesh: .generateBox(size: size), materials: [wood])
            e.position = pos
            root.addChild(e)
        }
        // Lỗ: đĩa tối tại tâm lỗ.
        let dark = UnlitMaterial(color: UIColor(white: 0.02, alpha: 1))
        for p in geo.pockets {
            let r = Float(p.id < 4 ? table.cornerPocketMouth * 0.6 : table.sidePocketMouth * 0.55)
            let disc = ModelEntity(mesh: .generateCylinder(height: 0.002, radius: r), materials: [dark])
            disc.position = mapping.toRender(SIMD3(p.center.x, p.center.y, 0.001))
            root.addChild(disc)
        }
        // Kim cương trên khung: rõ và đúng vị trí (dùng cho công thức).
        let pearl = UnlitMaterial(color: UIColor(white: 0.95, alpha: 1))
        let topY = h * 1.25 + 0.001
        let offset = railDepth + frame / 2
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

    /// Cơ đặt sau bi cái theo hướng ngắm; ẩn khi bi đang chạy.
    func updateCue(aim: Double, tip: SIMD2<Double>, visible: Bool, pullBack: Float) {
        guard visible, let cueBall = lastBalls[0], cueBall.state != .pocketed else { cue.isEnabled = false; return }
        cue.isEnabled = true
        let R = table.ballRadius
        let dir = SIMD3(cos(aim), sin(aim), 0)
        let left = SIMD3(-dir.y, dir.x, 0)
        // Đầu cơ tại điểm chạm, lùi một chút; cơ hơi dốc lên phía người chơi.
        let contact = cueBall.position + tip.y * R * SIMD3(0, 0, 1) - tip.x * R * left
        let tipPos = contact - dir * (0.004 + Double(pullBack))
        cue.position = mapping.toRender(tipPos)
        let back = mapping.directionToRender(-dir + SIMD3(0, 0, 0.06))
        // Trục +z của entity `cue` hướng về phía đuôi cơ.
        cue.look(at: cue.position - back, from: cue.position, relativeTo: nil)
    }

    func updateCamera(mode: CameraMode, aim: Double, eyeHeight: Double, aspect: Float) {
        guard let cueBall = lastBalls[0] else { return }
        switch mode {
        case .firstPerson:
            let dir = SIMD3(cos(aim), sin(aim), 0)
            let eye = cueBall.position - dir * 0.85 + SIMD3(0, 0, eyeHeight)
            let target = cueBall.position + dir * 1.2
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
