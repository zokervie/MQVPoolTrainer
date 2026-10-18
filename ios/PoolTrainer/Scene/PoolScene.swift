import SceneKit
import UIKit
import simd

// Cảnh 3D: phòng, bàn 9 ft (vải có lỗ, băng + hàm lỗ, mặt gỗ, nút xà cừ), bi, cơ, đường ngắm, nhãn nút, camera 2D/3D.
// Toạ độ vật lý (x, z) dùng thẳng làm toạ độ SceneKit (y hướng lên) – không cần đổi trục.

private let CUSH_BACK = 0.05      // độ dày băng tính từ mũi băng
private let RAIL_W = 0.115        // bề rộng mặt gỗ
private let WOOD_TOP = 0.047
private let CUSH_TOP = 0.044

private func pbr(_ c: Any, rough: CGFloat, metal: CGFloat = 0) -> SCNMaterial {
    let m = SCNMaterial(); m.lightingModel = .physicallyBased
    m.diffuse.contents = c; m.roughness.contents = rough; m.metalness.contents = metal
    return m
}
private func flat(_ c: UIColor, alpha: CGFloat = 1) -> SCNMaterial {
    let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = c
    m.transparency = alpha; m.isDoubleSided = true; m.writesToDepthBuffer = alpha >= 1
    return m
}
@inline(__always) private func v3(_ x: Double, _ y: Double, _ z: Double) -> SCNVector3 { SCNVector3(Float(x), Float(y), Float(z)) }
@inline(__always) private func f3(_ x: Double, _ y: Double, _ z: Double) -> SIMD3<Float> { SIMD3(Float(x), Float(y), Float(z)) }

/// Đường vẽ trên mặt bàn (polyline), dash: (độ dài nét, khoảng hở).
struct GuidePath {
    var pts: [P2]
    var color: UIColor
    var width: Double = 0.005
    var opacity: CGFloat = 0.9
    var dash: (Double, Double)? = nil
}

struct CamState {
    var yaw = 0.0, pitch = 0.32, dist = 1.0, overview = 0.0
    var orthoZoom = 1.0
}

final class PoolScene {
    let scene = SCNScene()
    let camNode = SCNNode()
    let orthoNode = SCNNode()
    var cam = CamState()
    private(set) var is3D = true
    weak var view: SCNView?

    private let tableRoot = SCNNode(), ballRoot = SCNNode(), guides = SCNNode(), labelRoot = SCNNode(), zoneRoot = SCNNode()
    private let cue = SCNNode(), ghost = SCNNode(), lamp = SCNNode()
    private var ballNodes: [Int: SCNNode] = [:]
    private var drops: [Int: (t: Double, from: P2)] = [:]
    private var camPos = SIMD3<Float>(0, 3, 0), camLook = SIMD3<Float>(0, 0, 0)
    private var clothHex: UInt32 = 0

    init() { build() }

    // MARK: - dựng cảnh
    private func build() {
        let s = scene
        s.background.contents = UIColor(hex: 0x10161c)
        s.fogStartDistance = 6; s.fogEndDistance = 14; s.fogColor = UIColor(hex: 0x10161c)
        s.lightingEnvironment.contents = envImage(); s.lightingEnvironment.intensity = 0.55
        [tableRoot, ballRoot, guides, labelRoot, zoneRoot, lamp].forEach { s.rootNode.addChildNode($0) }
        buildLights(); buildRoom(); setCloth(0x1f5d9e); buildCue()
        // bi ma
        let gs = SCNSphere(radius: R); gs.segmentCount = 32; gs.materials = [flat(.white, alpha: 0.28)]
        ghost.geometry = gs; ghost.castsShadow = false; ghost.renderingOrder = 4
        let ring = SCNNode(geometry: SCNTube(innerRadius: R * 0.96, outerRadius: R * 1.04, height: 0.0005))
        ring.geometry?.materials = [flat(.white, alpha: 0.8)]; ring.position = v3(0, -R + 0.0015, 0); ring.castsShadow = false
        ghost.addChildNode(ring); ghost.isHidden = true; s.rootNode.addChildNode(ghost)
        // camera
        let c = SCNCamera(); c.fieldOfView = 45; c.zNear = 0.02; c.zFar = 40
        c.wantsHDR = true; c.bloomIntensity = 0.12; c.bloomThreshold = 1.4; c.bloomBlurRadius = 6
        c.vignettingIntensity = 0.35; c.vignettingPower = 0.8; c.contrast = 0.06; c.saturation = 1.05
        c.wantsExposureAdaptation = false; c.exposureOffset = 0; c.minimumExposure = 0; c.maximumExposure = 0
        c.screenSpaceAmbientOcclusionIntensity = 0.5; c.screenSpaceAmbientOcclusionRadius = 0.03
        camNode.camera = c; s.rootNode.addChildNode(camNode)
        let o = SCNCamera(); o.usesOrthographicProjection = true; o.zNear = 0.1; o.zFar = 20; o.wantsHDR = true; o.exposureOffset = 0
        orthoNode.camera = o; orthoNode.position = v3(0, 6, 0)
        orthoNode.simdLook(at: .zero, up: SIMD3(0, 0, -1), localFront: SIMD3(0, 0, -1))
        s.rootNode.addChildNode(orthoNode)
    }

    private func envImage() -> UIImage {
        let W: CGFloat = 1024, H: CGFloat = 512
        return UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: Textures.fmt1x).image { ctx in
            let c = ctx.cgContext
            UIColor(white: 0.05, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: W, height: H))
            let gr = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
            for (x, y, r) in [(0.25, 0.12, 110.0), (0.5, 0.06, 140.0), (0.75, 0.12, 110.0), (0.1, 0.45, 160.0), (0.6, 0.5, 200.0)] {
                c.drawRadialGradient(gr, startCenter: CGPoint(x: W * x, y: H * y), startRadius: 0, endCenter: CGPoint(x: W * x, y: H * y), endRadius: r, options: [])
            }
        }
    }

    private func buildLights() {
        let amb = SCNLight(); amb.type = .ambient; amb.intensity = 45; amb.color = UIColor(hex: 0xc9d6e3)
        let an = SCNNode(); an.light = amb; scene.rootNode.addChildNode(an)
        let key = SCNLight(); key.type = .directional; key.intensity = 700; key.color = UIColor(hex: 0xfff4e0)
        key.castsShadow = true; key.shadowMapSize = CGSize(width: 2048, height: 2048); key.shadowSampleCount = 8
        key.shadowRadius = 3; key.shadowColor = UIColor(white: 0, alpha: 0.6); key.shadowMode = .deferred
        key.automaticallyAdjustsShadowProjection = false; key.orthographicScale = 1.7; key.zNear = 0.5; key.zFar = 6; key.shadowBias = 0.6
        let kn = SCNNode(); kn.light = key; kn.position = v3(0.3, 3.2, 0.5); kn.simdLook(at: .zero)
        scene.rootNode.addChildNode(kn)
        for x in [-0.85, 0, 0.85] {
            let p = SCNLight(); p.type = .omni; p.intensity = 120; p.color = UIColor(hex: 0xffe7c2)
            p.attenuationStartDistance = 0.3; p.attenuationEndDistance = 3.5; p.attenuationFalloffExponent = 2
            let n = SCNNode(); n.light = p; n.position = v3(x, 1.05, 0); scene.rootNode.addChildNode(n)
        }
    }

    private func buildRoom() {
        let fl = SCNFloor(); fl.reflectivity = 0.04
        let fm = pbr(Textures.wood(0x2b211b), rough: 0.7)
        fm.diffuse.wrapS = .repeat; fm.diffuse.wrapT = .repeat; fm.diffuse.contentsTransform = SCNMatrix4MakeScale(10, 10, 1)
        fm.multiply.contents = UIColor(hex: 0x8a7a6c)
        fl.materials = [fm]
        let fn = SCNNode(geometry: fl); fn.position.y = -0.78; scene.rootNode.addChildNode(fn)
        // đèn bàn
        let shade = SCNNode(geometry: SCNBox(width: 1.9, height: 0.07, length: 0.28, chamferRadius: 0.01))
        shade.geometry?.materials = [pbr(UIColor(hex: 0x1b2a24), rough: 0.5, metal: 0.4)]
        lamp.addChildNode(shade)
        let glow = SCNNode(geometry: SCNPlane(width: 1.82, height: 0.22))
        let gm = SCNMaterial(); gm.lightingModel = .constant; gm.diffuse.contents = UIColor(hex: 0xfff3d6); gm.emission.contents = UIColor(hex: 0xfff3d6)
        glow.geometry?.materials = [gm]; glow.eulerAngles.x = .pi / 2; glow.position.y = -0.036; glow.castsShadow = false
        lamp.addChildNode(glow)
        for x in [-0.7, 0.7] {
            let rod = SCNNode(geometry: SCNCylinder(radius: 0.004, height: 2)); rod.geometry?.materials = [pbr(UIColor(white: 0.4, alpha: 1), rough: 0.3, metal: 0.8)]
            rod.position = v3(x, 1.0, 0); rod.castsShadow = false; lamp.addChildNode(rod)
        }
        lamp.position = v3(0, 1.12, 0)
        lamp.enumerateHierarchy { n, _ in n.castsShadow = false }
    }

    /// Hình phẳng (đường đi trên mặt bàn) đùn theo chiều đứng. Toạ độ path: (x, −z).
    private func extrude(_ path: UIBezierPath, depth: Double, top: Double, chamfer: Double = 0, _ m: SCNMaterial) -> SCNNode {
        let sh = SCNShape(path: path, extrusionDepth: CGFloat(depth))
        if chamfer > 0 { sh.chamferRadius = CGFloat(chamfer) }
        sh.materials = [m]
        let n = SCNNode(geometry: sh)
        n.eulerAngles.x = -.pi / 2
        n.position.y = Float(top - depth / 2)
        return n
    }

    func setCloth(_ hex: UInt32) {
        guard hex != clothHex else { return }
        clothHex = hex
        tableRoot.childNodes.forEach { $0.removeFromParentNode() }
        let t = tableRoot
        let clothImg = Textures.cloth(hex)
        let clothMat = pbr(clothImg, rough: 0.92)
        clothMat.diffuse.wrapS = .repeat; clothMat.diffuse.wrapT = .repeat; clothMat.diffuse.contentsTransform = SCNMatrix4MakeScale(18, 9, 1)
        let cushMat = pbr(clothImg, rough: 0.9); cushMat.multiply.contents = UIColor(white: 0.9, alpha: 1)
        cushMat.diffuse.wrapS = .repeat; cushMat.diffuse.wrapT = .repeat; cushMat.diffuse.contentsTransform = SCNMatrix4MakeScale(30, 2, 1)
        let woodMat = pbr(Textures.wood(0x6a3f22), rough: 0.45)
        woodMat.clearCoat.contents = 0.4; woodMat.clearCoatRoughness.contents = 0.3
        let darkWood = pbr(Textures.wood(0x2e1d12), rough: 0.5)
        let hole = SCNMaterial(); hole.lightingModel = .constant; hole.diffuse.contents = UIColor(hex: 0x050506); hole.isDoubleSided = true

        let HLc = TL / 2, HWc = TW / 2
        // mặt vải có lỗ (rộng hơn khung băng, phần thừa nằm dưới gỗ)
        let ext = 0.12
        let cp = UIBezierPath(rect: CGRect(x: -(HLc + ext), y: -(HWc + ext), width: 2 * (HLc + ext), height: 2 * (HWc + ext)))
        for p in POCKETS { cp.append(UIBezierPath(ovalIn: CGRect(x: p.p.x - p.r, y: -p.p.z - p.r, width: 2 * p.r, height: 2 * p.r))) }
        cp.usesEvenOddFillRule = true; cp.flatness = 0.002
        let cn = extrude(cp, depth: 0.01, top: 0, clothMat); t.addChildNode(cn)

        // lòng lỗ
        for p in POCKETS {
            let tube = SCNNode(geometry: SCNTube(innerRadius: p.r * 0.97, outerRadius: p.r, height: 0.024))
            tube.geometry?.materials = [hole]; tube.position = v3(p.p.x, -0.012, p.p.z); t.addChildNode(tube)
            let bottom = SCNNode(geometry: SCNCylinder(radius: p.r, height: 0.002))
            bottom.geometry?.materials = [hole]; bottom.position = v3(p.p.x, -0.0235, p.p.z); t.addChildNode(bottom)
        }

        // băng + hàm lỗ
        func jawAt(_ pt: P2) -> Cushion? { CUSHIONS.first { $0.isJaw && abs($0.a.x - pt.x) < 1e-9 && abs($0.a.z - pt.z) < 1e-9 } }
        for s in CUSHIONS where !s.isJaw {
            let pts = [s.a, s.b, jawAt(s.b)?.b ?? s.b, jawAt(s.a)?.b ?? s.a]
            let bp = UIBezierPath()
            bp.move(to: CGPoint(x: pts[0].x, y: -pts[0].z))
            for q in pts.dropFirst() { bp.addLine(to: CGPoint(x: q.x, y: -q.z)) }
            bp.close()
            let n = extrude(bp, depth: CUSH_TOP, top: CUSH_TOP, chamfer: 0.002, cushMat)
            t.addChildNode(n)
        }

        // mặt gỗ: chữ nhật bo góc ngoài – đường bao (khung băng ∪ lỗ) bên trong
        let OL = HLc + CUSH_BACK + RAIL_W, OW = HWc + CUSH_BACK + RAIL_W
        let wp = UIBezierPath(roundedRect: CGRect(x: -OL, y: -OW, width: 2 * OL, height: 2 * OW), cornerRadius: 0.05)
        let inner = unionOutline(HLc + CUSH_BACK, HWc + CUSH_BACK)
        let ip = UIBezierPath(); ip.move(to: CGPoint(x: inner[0].x, y: -inner[0].z))
        for q in inner.dropFirst() { ip.addLine(to: CGPoint(x: q.x, y: -q.z)) }
        ip.close(); wp.append(ip); wp.usesEvenOddFillRule = true
        let wood = extrude(wp, depth: 0.075, top: WOOD_TOP, chamfer: 0.004, woodMat); t.addChildNode(wood)

        // thân bàn + chân
        let apron = SCNNode(geometry: SCNBox(width: CGFloat(2 * OL - 0.05), height: 0.17, length: CGFloat(2 * OW - 0.05), chamferRadius: 0.01))
        apron.geometry?.materials = [darkWood]; apron.position = v3(0, WOOD_TOP - 0.075 - 0.085, 0); t.addChildNode(apron)
        for sx in [-1.0, 1.0] { for sz in [-1.0, 1.0] {
            let leg = SCNNode(geometry: SCNBox(width: 0.16, height: 0.62, length: 0.16, chamferRadius: 0.01))
            leg.geometry?.materials = [darkWood]; leg.position = v3(sx * (OL - 0.2), -0.47, sz * (OW - 0.18)); t.addChildNode(leg)
        } }

        // nút xà cừ
        let dm = pbr(UIColor(hex: 0xefe6d0), rough: 0.2); dm.clearCoat.contents = 1
        func diamond(_ p: P2) {
            let n = SCNNode(geometry: SCNBox(width: 0.012, height: 0.002, length: 0.019, chamferRadius: 0.0005))
            n.geometry?.materials = [dm]; n.position = v3(p.x, WOOD_TOP + 0.001, p.z)
            n.eulerAngles.y = (abs(p.x) > TL / 2) ? .pi / 2 : 0
            t.addChildNode(n)
        }
        for i in 0...8 where i % 4 != 0 { diamond(railPoint(Double(i), 0)); diamond(railPoint(Double(i), 4)) }
        for j in 1...3 { diamond(railPoint(0, Double(j))); diamond(railPoint(8, Double(j))) }
        // chấm đầu/chân bàn
        for x in [-TL / 4, TL / 4] {
            let sp = SCNNode(geometry: SCNCylinder(radius: 0.008, height: 0.0004))
            sp.geometry?.materials = [flat(.white, alpha: 0.55)]; sp.position = v3(x, 0.0008, 0); sp.castsShadow = false
            t.addChildNode(sp)
        }
    }

    /// Đường bao (khung băng ∪ các lỗ) bằng lấy mẫu cực quanh tâm bàn.
    private func unionOutline(_ HL: Double, _ HW: Double) -> [P2] {
        let N = 720
        var out: [P2] = []
        for i in 0..<N {
            let th = Double(i) / Double(N) * 2 * .pi, dx = cos(th), dz = sin(th)
            var t = min(abs(dx) > 1e-9 ? HL / abs(dx) : .infinity, abs(dz) > 1e-9 ? HW / abs(dz) : .infinity)
            for p in POCKETS {
                let b = dx * p.p.x + dz * p.p.z, c = p.p.x * p.p.x + p.p.z * p.p.z - p.r * p.r, disc = b * b - c
                if disc >= 0 { let t2 = b + disc.squareRoot(); if t2 > t { t = t2 } }
            }
            out.append(P2(dx * t, dz * t))
        }
        return out
    }

    private func buildCue() {
        // cơ dài 1,47 m: đầu cơ ở gốc toạ độ, thân chạy theo +y cục bộ
        let segs: [(y0: Double, y1: Double, r0: Double, r1: Double, col: UInt32, rough: CGFloat)] = [
            (0, 0.012, 0.0062, 0.0064, 0x5280c7, 0.8),       // đầu cơ (phấn xanh)
            (0.012, 0.035, 0.0066, 0.0066, 0xf2f0e6, 0.3),   // ferrule
            (0.035, 0.70, 0.0067, 0.0107, 0xe6c794, 0.35),   // thân gỗ phong
            (0.70, 0.74, 0.0118, 0.0112, 0x1f1f1f, 0.25),    // khớp nối
            (0.74, 1.0, 0.0112, 0.0128, 0x401f0f, 0.3),      // đuôi gỗ
            (1.0, 1.36, 0.0128, 0.0148, 0x19191c, 0.7),      // quấn tay
            (1.36, 1.47, 0.0148, 0.0152, 0x33170a, 0.3),     // chuôi
        ]
        let inner = SCNNode()
        for s in segs {
            let g = SCNCone(topRadius: CGFloat(s.r1), bottomRadius: CGFloat(s.r0), height: CGFloat(s.y1 - s.y0))
            g.radialSegmentCount = 32
            let m = pbr(UIColor(hex: s.col), rough: s.rough); m.clearCoat.contents = 0.6
            g.materials = [m]
            let n = SCNNode(geometry: g); n.position = v3(0, (s.y0 + s.y1) / 2, 0); inner.addChildNode(n)
        }
        cue.addChildNode(inner)
        cue.isHidden = true
        scene.rootNode.addChildNode(cue)
    }

    // MARK: - bi
    func syncBalls(_ balls: [Ball]) {
        let ids = Set(balls.map { $0.id })
        for (id, n) in ballNodes where !ids.contains(id) { n.removeFromParentNode(); ballNodes[id] = nil }
        for b in balls {
            if ballNodes[b.id] == nil {
                let s = SCNSphere(radius: R); s.segmentCount = 56
                let m = pbr(Textures.ball(b.id), rough: 0.12); m.clearCoat.contents = 1; m.clearCoatRoughness.contents = 0.04
                s.materials = [m]
                let n = SCNNode(geometry: s); n.castsShadow = true
                ballRoot.addChildNode(n); ballNodes[b.id] = n
            }
            drops[b.id] = nil
        }
    }

    func updateBalls(_ balls: [Ball], dt: Double) {
        for b in balls {
            guard let n = ballNodes[b.id] else { continue }
            if b.pocketed {
                let pk = POCKETS.first { $0.id == b.pocket } ?? POCKETS[0]
                var d = drops[b.id] ?? (0, b.dropFrom ?? b.pos)
                d.t += dt; drops[b.id] = d
                let k = min(1, d.t / 0.35)
                n.position = v3(d.from.x + (pk.p.x - d.from.x) * k, R - 0.13 * k * k, d.from.z + (pk.p.z - d.from.z) * k)
                n.isHidden = d.t > 0.6
            } else {
                drops[b.id] = nil
                n.isHidden = false
                n.position = v3(b.x, R, b.z)
            }
            n.simdOrientation = simd_quatf(ix: Float(b.q.x), iy: Float(b.q.y), iz: Float(b.q.z), r: Float(b.q.w))
        }
    }

    // MARK: - cơ & ngắm
    /// a, b: điểm đánh (theo R); pull: độ lùi cơ (m); elev: góc nâng (rad).
    func setCue(visible: Bool, cb: Ball?, dir: Double, a: Double, b: Double, pull: Double, elev: Double) {
        guard visible, let cb else { cue.isHidden = true; return }
        cue.isHidden = false
        let vis = max(elev, 0.07)
        let ux = cos(dir), uz = sin(dir), sx = -uz, sz = ux
        let k = max(0, 1 - a * a - b * b).squareRoot()
        let cx = cb.x + (-ux * k + sx * a) * R, cz = cb.z + (-uz * k + sz * a) * R, cy = R + b * R
        let back = 0.012 + pull
        cue.position = v3(cx - ux * back * cos(vis), cy + back * sin(vis), cz - uz * back * cos(vis))
        let tail = simd_normalize(f3(-ux * cos(vis), sin(vis), -uz * cos(vis)))
        cue.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: tail)
    }

    func setGhost(_ p: P2?) {
        ghost.isHidden = p == nil
        if let p { ghost.position = v3(p.x, R, p.z) }
    }

    func setPaths(_ paths: [GuidePath]) {
        guides.childNodes.forEach { $0.removeFromParentNode() }
        for p in paths {
            guard p.pts.count >= 2, let g = ribbon(p.pts, p.width, p.dash) else { continue }
            let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = p.color; m.transparency = p.opacity
            m.isDoubleSided = true; m.writesToDepthBuffer = false
            g.materials = [m]
            let n = SCNNode(geometry: g); n.position.y = 0.0015; n.renderingOrder = 5; n.castsShadow = false
            guides.addChildNode(n)
        }
    }

    private func ribbon(_ pts: [P2], _ w: Double, _ dash: (Double, Double)?) -> SCNGeometry? {
        var segs: [(P2, P2)] = []
        if let dd = dash {
            let on = dd.0, off = dd.1
            var acc = 0.0, draw = true
            for i in 0..<(pts.count - 1) {
                var a = pts[i]; let b = pts[i + 1]
                var len = a.dist(b)
                guard len > 1e-9 else { continue }
                let u = (b - a) * (1 / len)
                while len > 1e-6 {
                    let lim = (draw ? on : off) - acc, st = min(lim, len)
                    if draw { segs.append((a, a + u * st)) }
                    a = a + u * st; len -= st; acc += st
                    if acc >= (draw ? on : off) - 1e-9 { acc = 0; draw.toggle() }
                }
            }
        } else { for i in 0..<(pts.count - 1) { segs.append((pts[i], pts[i + 1])) } }
        var verts: [SCNVector3] = [], idx: [Int32] = []
        for (a, b) in segs {
            let len = a.dist(b); if len < 1e-7 { continue }
            let nx = -(b.z - a.z) / len * w / 2, nz = (b.x - a.x) / len * w / 2
            let i0 = Int32(verts.count)
            verts += [v3(a.x + nx, 0, a.z + nz), v3(a.x - nx, 0, a.z - nz), v3(b.x + nx, 0, b.z + nz), v3(b.x - nx, 0, b.z - nz)]
            idx += [i0, i0 + 2, i0 + 1, i0 + 1, i0 + 2, i0 + 3]
        }
        guard !idx.isEmpty else { return nil }
        return SCNGeometry(sources: [SCNGeometrySource(vertices: verts)], elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
    }

    func setZones(_ zones: [Zone]) {
        zoneRoot.childNodes.forEach { $0.removeFromParentNode() }
        for z in zones {
            let g = SCNNode()
            let fill = SCNNode(geometry: SCNCylinder(radius: z.r, height: 0.0003)); fill.geometry?.materials = [flat(UIColor(hex: 0xffd166), alpha: 0.16)]
            let ring = SCNNode(geometry: SCNTube(innerRadius: z.r - 0.004, outerRadius: z.r, height: 0.0005)); ring.geometry?.materials = [flat(UIColor(hex: 0xffd166), alpha: 0.9)]
            [fill, ring].forEach { $0.castsShadow = false; $0.renderingOrder = 3; g.addChildNode($0) }
            g.position = v3(z.c.x, 0.0012, z.c.z)
            zoneRoot.addChildNode(g)
        }
    }

    func setLabels(_ labels: [RailLabel]) {
        labelRoot.childNodes.forEach { $0.removeFromParentNode() }
        for lb in labels {
            let pl = SCNPlane(width: 0.075, height: 0.075)
            let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = Textures.text(lb.text, lb.color)
            m.writesToDepthBuffer = false; m.isDoubleSided = false
            pl.materials = [m]
            let n = SCNNode(geometry: pl); n.eulerAngles.x = -.pi / 2; n.renderingOrder = 6; n.castsShadow = false
            var p = lb.p
            let o = 0.042
            switch lb.side {
            case .top: p.z -= o
            case .bottom: p.z += o
            case .left: p.x -= o
            case .right: p.x += o
            case .bottom2: p.z -= DIAMOND_OFF + 0.035
            }
            n.position = v3(p.x, lb.side == .bottom2 ? 0.002 : WOOD_TOP + 0.005, p.z)
            if lb.side == .bottom2 { n.scale = SCNVector3(0.75, 0.75, 0.75) }
            labelRoot.addChildNode(n)
        }
    }

    // MARK: - camera
    func setMode3D(_ on: Bool) {
        is3D = on
        lamp.isHidden = !on
        view?.pointOfView = on ? camNode : orthoNode
        updateOrtho()
    }

    func updateOrtho() {
        guard let v = view, v.bounds.width > 0 else { return }
        let w = Double(v.bounds.width), h = Double(v.bounds.height)
        let padL = TL + 2 * (CUSH_BACK + RAIL_W) + 0.12, padW = TW + 2 * (CUSH_BACK + RAIL_W) + 0.12
        // orthographicScale = nửa chiều cao nhìn thấy
        let half = max(padW / 2, padL / 2 * h / w) * 1.04
        orthoNode.camera?.orthographicScale = half / cam.orthoZoom
    }

    func updateCamera(dt: Double, cb: Ball?) {
        guard is3D else { return }
        let c = cam
        let tgt = cb.map { f3($0.x, R, $0.z) } ?? .zero
        let behind = f3(-cos(c.yaw) * cos(c.pitch), sin(c.pitch), -sin(c.yaw) * cos(c.pitch))
        var look = tgt + f3(cos(c.yaw), 0, sin(c.yaw)) * Float(0.25 * (1 - c.pitch / 1.6))
        var pos = tgt + behind * Float(c.dist)
        let ovPos = f3(-cos(c.yaw) * 1.9, 2.3, -sin(c.yaw) * 1.3), ovLook = SIMD3<Float>(0, 0, 0)
        let ov = Float(c.overview)
        pos = pos + (ovPos - pos) * ov; look = look + (ovLook - look) * ov
        let k = Float(1 - exp(-dt * 7))
        camPos += (pos - camPos) * k; camLook += (look - camLook) * k
        if camPos.y < 0.09 { camPos.y = 0.09 }
        lamp.isHidden = camPos.y > 0.95      // nhìn từ trên cao: đèn bàn sẽ che mặt bàn
        camNode.simdPosition = camPos
        camNode.simdLook(at: camLook, up: SIMD3(0, 1, 0), localFront: SIMD3(0, 0, -1))
        camNode.camera?.focusDistance = CGFloat(simd_distance(camPos, tgt))
    }

    func snapCamera(_ cb: Ball?) { camPos = SIMD3(0, 3, 0); updateCamera(dt: 10, cb: cb) }

    /// Toạ độ màn hình → điểm trên mặt phẳng tâm bi.
    func pick(_ pt: CGPoint) -> P2? {
        guard let v = view else { return nil }
        let a = v.unprojectPoint(SCNVector3(Float(pt.x), Float(pt.y), 0)), b = v.unprojectPoint(SCNVector3(Float(pt.x), Float(pt.y), 1))
        let dy = Double(b.y - a.y); guard abs(dy) > 1e-9 else { return nil }
        let t = (R - Double(a.y)) / dy
        guard t > 0 else { return nil }
        return P2(Double(a.x) + Double(b.x - a.x) * t, Double(a.z) + Double(b.z - a.z) * t)
    }
}
