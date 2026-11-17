import SceneKit
import UIKit

/// 0.44.1 M3 (owner 17/11: "cơ nhìn quá rẻ tiền… cơ khi mờ có khấc tròn ở khớp nối"). The old cue was 8–9 separate
/// cones/cylinders (or the kit mesh) plus a tip node; fading `cueRoot.opacity` showed every part's end caps and the
/// faces inside the joints. Now the cue is ONE lathe mesh turned from a profile — only outer surfaces, no caps between
/// parts — with one element per material, back faces culled and single-layer transparency.
///
/// Profile (distance from the tip apex, metres; GIẢ ĐỊNH from common playing-cue specs, not a measured cue):
/// tip 12.75 mm Ø, 4.5 mm tall, domed R 9.5 mm · ferrule 25 mm · shaft tapering evenly to 21 mm at the joint ·
/// metal joint collar · forearm · wrap · sleeve to 31 mm · rubber bumper. Total 1.47 m; the jump cue is the same mesh
/// scaled to 1.044 m along its axis (as the clearance model assumes). Local +Y points to the tip; apex at y = 0.
enum CueModel0441 {
    static let length: Float = 1.47, jumpLength: Float = 1.044
    struct Section { let name: String; let points: [(d: Float, r: Float)]; let smooth: Bool }

    static func profile() -> [Section] {
        let rt: Float = 0.012_75 / 2, rd: Float = 0.0095, tipH: Float = 0.0045
        var dome: [(Float, Float)] = []
        for k in 0...10 { let r = rt * Float(k) / 10; dome.append((rd - (rd * rd - r * r).squareRoot(), r)) }
        let sag = dome.last!.0
        func taper(_ d0: Float, _ d1: Float, _ r0: Float, _ r1: Float, steps: Int) -> [(d: Float, r: Float)] {
            (0...steps).map { i in let t = Float(i) / Float(steps); return (d0 + (d1 - d0) * t, r0 + (r1 - r0) * t) }
        }
        let rJoint: Float = 0.0105, rCollar: Float = 0.0108, rButt: Float = 0.0155
        return [
            Section(name: "tip", points: dome.map { (d: $0.0, r: $0.1) } + [(sag, rt), (tipH, rt)].map { (d: $0.0, r: $0.1) }, smooth: false),
            Section(name: "ferrule", points: taper(tipH, 0.0295, rt, rt + 0.000_05, steps: 2), smooth: true),
            Section(name: "shaft", points: taper(0.0295, 0.735, rt + 0.000_05, rJoint, steps: 24), smooth: true),
            Section(name: "metal", points: [(0.735, rJoint), (0.735, rCollar)], smooth: false),           // collar shoulder
            Section(name: "metal", points: taper(0.735, 0.760, rCollar, rCollar, steps: 1), smooth: true),
            Section(name: "forearm", points: taper(0.760, 1.000, rCollar, 0.0130, steps: 6), smooth: true),
            Section(name: "trim", points: [(1.000, 0.0130), (1.000, 0.0131)], smooth: false),
            Section(name: "trim", points: taper(1.000, 1.006, 0.0131, 0.0131, steps: 1), smooth: true),
            Section(name: "wrap", points: [(1.006, 0.0131), (1.006, 0.0129)], smooth: false),
            Section(name: "wrap", points: taper(1.006, 1.300, 0.0129, 0.0142, steps: 6), smooth: true),
            Section(name: "trim", points: [(1.300, 0.0142), (1.300, 0.0145)], smooth: false),
            Section(name: "trim", points: taper(1.300, 1.306, 0.0145, 0.0145, steps: 1), smooth: true),
            Section(name: "sleeve", points: taper(1.306, 1.440, 0.0145, rButt, steps: 4), smooth: true),
            Section(name: "bumper", points: [(1.440, rButt), (1.452, rButt - 0.0002), (1.466, rButt - 0.0012), (1.470, rButt - 0.004), (1.470, 0)], smooth: false),
        ]
    }

    /// The lathe geometry with one element per material name (in `materialOrder`).
    static let materialOrder = ["tip", "ferrule", "shaft", "metal", "forearm", "trim", "wrap", "sleeve", "bumper"]
    static func geometry(segments: Int = 48) -> SCNGeometry {
        var v: [SCNVector3] = [], n: [SCNVector3] = [], uv: [CGPoint] = []
        var indices: [String: [Int32]] = [:]
        for section in profile() {
            let p = section.points
            guard p.count >= 2 else { continue }
            let span = max(1e-6, p.last!.d - p.first!.d)
            // per-segment normal in (radial, y) with y = -d: tangent (dr, -dd) → normal (dd, dr)
            func segNormal(_ a: (d: Float, r: Float), _ b: (d: Float, r: Float)) -> (Float, Float) {
                let dd = b.d - a.d, dr = b.r - a.r, l = max(1e-9, (dd * dd + dr * dr).squareRoot()); return (dd / l, dr / l)
            }
            // Flat sections get their own vertex pair per segment (hard edges); smooth ones share averaged normals.
            var rings: [(d: Float, r: Float, nr: Float, ny: Float, v: Float)] = []
            if section.smooth {
                for j in p.indices {
                    let a = j > 0 ? segNormal(p[j - 1], p[j]) : segNormal(p[j], p[j + 1])
                    let b = j < p.count - 1 ? segNormal(p[j], p[j + 1]) : a
                    let nr = a.0 + b.0, ny = a.1 + b.1, l = max(1e-9, (nr * nr + ny * ny).squareRoot())
                    rings.append((p[j].d, p[j].r, nr / l, ny / l, (p[j].d - p[0].d) / span))
                }
            } else {
                for j in 0..<(p.count - 1) {
                    let s = segNormal(p[j], p[j + 1])
                    rings.append((p[j].d, p[j].r, s.0, s.1, (p[j].d - p[0].d) / span))
                    rings.append((p[j + 1].d, p[j + 1].r, s.0, s.1, (p[j + 1].d - p[0].d) / span))
                }
            }
            let base = Int32(v.count), m = Int32(rings.count)
            for i in 0...segments {
                let a = Float(i) / Float(segments) * 2 * .pi, c = cos(a), s = sin(a)
                for q in rings {
                    v.append(SCNVector3(q.r * c, -q.d, q.r * s)); n.append(SCNVector3(q.nr * c, q.ny, q.nr * s))
                    uv.append(CGPoint(x: CGFloat(i) / CGFloat(segments), y: CGFloat(q.v)))
                }
            }
            let step = section.smooth ? 1 : 2
            var idx = indices[section.name] ?? []
            for i in 0..<Int32(segments) {
                var j: Int32 = 0
                while j < m - 1 {
                    let a = base + i * m + j, b = a + m, c = a + 1, d = b + 1   // a,b around; c,d one ring further along
                    idx += [a, b, c, b, d, c]
                    j += Int32(step)
                }
            }
            indices[section.name] = idx
        }
        let names = materialOrder.filter { indices[$0] != nil }
        let elements = names.map { SCNGeometryElement(indices: indices[$0]!, primitiveType: .triangles) }
        let g = SCNGeometry(sources: [SCNGeometrySource(vertices: v), SCNGeometrySource(normals: n), SCNGeometrySource(textureCoordinates: uv)], elements: elements)
        g.name = "cue-lathe-0441"
        return g
    }
    private static var cachedGeometry: SCNGeometry?
    private static var materialNames: [String] = []

    /// One cue node: kind 0 play, 1 jump, 2 break; `masse` = the massé look of the play cue.
    static func node(look: CueLook, kind: Int, masse: Bool) -> SCNNode {
        if cachedGeometry == nil {
            cachedGeometry = geometry()
            materialNames = materialOrder.filter { name in profile().contains { $0.name == name } }
        }
        let g = cachedGeometry!.copy() as! SCNGeometry
        g.materials = materialNames.map { material($0, look: look, kind: kind, masse: masse) }
        let node = SCNNode(geometry: g); node.name = "cue-lathe-" + look.id; node.castsShadow = false
        if kind == 1 { node.scale = SCNVector3(1, jumpLength / length, 1) }
        return node
    }

    private static var textureCache: [String: UIImage] = [:]
    private static func texture(_ name: String) -> UIImage? {
        if let t = textureCache[name] { return t }
        let t = UIImage(named: name); textureCache[name] = t; return t
    }
    private static func base(_ colour: UIColor, roughness: CGFloat, metal: CGFloat = 0, coat: CGFloat = 0) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .physicallyBased
        m.diffuse.contents = colour; m.roughness.contents = roughness; m.metalness.contents = metal
        if coat > 0 { m.clearCoat.contents = coat; m.clearCoatRoughness.contents = 0.06 }
        // One layer only: back faces culled, depth written, so a faded cue never shows its far side or joints.
        m.isDoubleSided = false; m.writesToDepthBuffer = true; m.transparencyMode = .singleLayer
        return m
    }
    static func material(_ name: String, look: CueLook, kind: Int, masse: Bool) -> SCNMaterial {
        let body = UIColor.rgb(masse ? 0x6a1820 : look.color), trim = UIColor.rgb(masse ? 0xd0d4d8 : look.accent)
        switch name {
        case "tip":
            if kind == 2 { let m = base(UIColor(red: 0.94, green: 0.93, blue: 0.89, alpha: 1), roughness: 0.16, coat: 0.9); return m }
            if kind == 1 { return base(UIColor(white: 0.06, alpha: 1), roughness: 0.2, coat: 0.8) }
            return base(look.inlay > 0 ? .rgb(look.tip) : .rgb(0x1E4F6E), roughness: 0.92)
        case "ferrule":
            return base(look.inlay > 0 ? .rgb(look.ferrule) : UIColor(red: 0.93, green: 0.91, blue: 0.81, alpha: 1), roughness: 0.23, coat: 0.5)
        case "shaft":
            if look.carbon { let m = base(.white, roughness: 0.3, coat: 0.7); m.diffuse.contents = texture("CueTex0441-carbon") ?? UIColor(white: 0.12, alpha: 1); m.multiply.contents = UIColor(white: 0.32, alpha: 1); return m }
            let m = base(.white, roughness: 0.38, coat: 0.55); m.diffuse.contents = texture("CueTex0441-maple") ?? UIColor(red: 0.92, green: 0.85, blue: 0.7, alpha: 1); return m
        case "metal": return base(trim, roughness: 0.22, metal: 0.92)
        case "trim": return base(trim, roughness: 0.28, metal: 0.6, coat: 0.4)
        case "forearm":
            let m = base(.white, roughness: 0.24, coat: 0.85)
            if !masse, look.inlay > 0, let t = texture("CueTex0441-fa-" + look.id) { m.diffuse.contents = t; return m }
            m.diffuse.contents = texture(look.carbon ? "CueTex0441-carbon" : "CueTex0441-grain") ?? body; m.multiply.contents = body; return m
        case "wrap":
            let m = base(.white, roughness: 0.9); m.diffuse.contents = texture("CueTex0441-wrap") ?? UIColor(white: 0.1, alpha: 1)
            m.multiply.contents = UIColor(white: 0.16, alpha: 1).blended(with: body, 0.25); return m
        case "sleeve":
            let m = base(.white, roughness: 0.24, coat: 0.85); m.diffuse.contents = sleeveTexture(look, body: body, trim: trim); return m
        default:
            let m = base(UIColor(white: 0.025, alpha: 1), roughness: 0.96); m.specular.contents = UIColor.black; return m   // rubber bumper: no rim glint
        }
    }
    /// Butt sleeve: the cue's wood (or carbon) under clear coat, accent rings and the printed Zoker name on two faces.
    static func sleeveTexture(_ look: CueLook, body: UIColor, trim: UIColor) -> UIImage {
        let key = "sleeve-" + look.id + body.description
        if let t = textureCache[key] { return t }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 512), format: format).image { c in
            let g = c.cgContext
            body.setFill(); g.fill(CGRect(x: 0, y: 0, width: 256, height: 512))
            if let grain = texture(look.carbon ? "CueTex0441-carbon" : "CueTex0441-grain") {
                grain.draw(in: CGRect(x: 0, y: 0, width: 256, height: 512), blendMode: .multiply, alpha: 1)
            }
            trim.setFill(); for y in [CGFloat(18), 486] { g.fill(CGRect(x: 0, y: y, width: 256, height: 8)) }
            if look.inlay == 2 || look.inlay == 3 { UIColor.rgb(look.stone).setFill(); for k in 0..<4 { g.fillEllipse(in: CGRect(x: CGFloat(k) * 64 + 22, y: 50, width: 20, height: 20)) } }
            for u in [CGFloat(64), 192] {
                g.saveGState(); g.translateBy(x: u, y: 270); g.rotate(by: -.pi / 2)
                let text = look.printed as NSString
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34, weight: .heavy), .foregroundColor: trim, .kern: 2]
                let size = text.size(withAttributes: attributes); text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attributes)
                g.restoreGState()
            }
        }
        textureCache[key] = image; return image
    }
}

private extension UIColor {
    func blended(with other: UIColor, _ t: CGFloat) -> UIColor {
        var a: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0), b: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&a.0, green: &a.1, blue: &a.2, alpha: &a.3); other.getRed(&b.0, green: &b.1, blue: &b.2, alpha: &b.3)
        return UIColor(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t, alpha: 1)
    }
}

/// 0.44.1 M3: cue key / bag icons rendered from the 3D cue itself (offscreen SCNRenderer, @3x, transparent), cached
/// in memory and in Caches. The radius is exaggerated ×7 so a 1.47 m cue still reads at 44 × 12 pt.
enum CueIcon0441 {
    static let version = "0441b"
    private static var memory: [String: UIImage] = [:]
    private static let renderer: SCNRenderer? = {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        return SCNRenderer(device: device, options: nil)
    }()
    static func image(_ look: CueLook, size: CGSize) -> UIImage? {
        let kind = look.role
        let key = "\(version)-\(look.id)-\(Int(size.width))x\(Int(size.height))"
        if let m = memory[key] { return m }
        let file = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("cue-icons-" + key + ".png")
        if let data = try? Data(contentsOf: file), let cached = UIImage(data: data, scale: 3) { memory[key] = cached; return cached }
        guard let renderer = renderer else { return nil }
        let scene = SCNScene(); scene.background.contents = UIColor.clear
        let cue = CueModel0441.node(look: look, kind: kind, masse: false)
        let holder = SCNNode(); holder.addChildNode(cue)
        cue.scale = SCNVector3(7, kind == 1 ? CueModel0441.jumpLength / CueModel0441.length : 1, 7)
        holder.eulerAngles = SCNVector3(0.25, 0, -Float.pi / 2)   // tip to the right, rolled to show the top highlight
        holder.position = SCNVector3(CueModel0441.length / 2 * (kind == 1 ? CueModel0441.jumpLength / CueModel0441.length : 1), 0, 0)
        scene.rootNode.addChildNode(holder)
        let eye = SCNNode(); eye.camera = SCNCamera(); eye.camera?.usesOrthographicProjection = true
        eye.camera?.orthographicScale = Double(CueModel0441.length / 2 * 1.04) * Double(size.height / size.width)
        eye.camera?.zNear = 0.01; eye.camera?.zFar = 10
        eye.position = SCNVector3(0, 0, 3); scene.rootNode.addChildNode(eye)
        let key1 = SCNNode(); key1.light = SCNLight(); key1.light?.type = .directional; key1.light?.intensity = 1100
        key1.eulerAngles = SCNVector3(-0.9, 0.3, 0); scene.rootNode.addChildNode(key1)
        let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .ambient; fill.light?.intensity = 420; scene.rootNode.addChildNode(fill)
        renderer.scene = scene; renderer.pointOfView = eye
        let px = CGSize(width: size.width * 3, height: size.height * 3)
        let raw = renderer.snapshot(atTime: 0, with: px, antialiasingMode: .multisampling4X)
        guard let cg = raw.cgImage else { return nil }
        let image = UIImage(cgImage: cg, scale: 3, orientation: .up).withRenderingMode(.alwaysOriginal)
        memory[key] = image
        if let data = image.pngData() { try? data.write(to: file, options: .atomic) }
        return image
    }
}
