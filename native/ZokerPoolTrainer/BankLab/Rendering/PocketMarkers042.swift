import SceneKit
import UIKit

/// 0.42 (owner 13/11 17:57): calling a pocket — the camera goes top-down, the six pockets blink through the spectrum
/// for the player to tap, and the chosen pocket keeps a check mark until the stroke is over.
extension TableScene {
    private var pocketMarkerRoot: SCNNode {
        if let n = scene.rootNode.childNode(withName: "pocket-markers", recursively: false) { return n }
        let n = SCNNode(); n.name = "pocket-markers"; scene.rootNode.addChildNode(n); return n
    }
    /// Pocket centres in solver order (Physics World::pocket): 0/1 head corners, 2/3 sides, 4/5 foot corners.
    static func pocketPoints(width: Double, length: Double) -> [SIMD2<Double>] {
        let x = width / 2, y = length / 2
        return [SIMD2(-x, -y), SIMD2(x, -y), SIMD2(-x, 0), SIMD2(x, 0), SIMD2(-x, y), SIMD2(x, y)]
    }
    /// mode 0: none · 1: all six blink (picker) · 2: only `chosen` with a check mark.
    func showPocketMarkers(mode: Int, chosen: Int = -1, width: Double, length: Double) {
        let root = pocketMarkerRoot
        root.childNodes.forEach { $0.removeFromParentNode() }
        guard mode > 0 else { return }
        for (k, p) in Self.pocketPoints(width: width, length: length).enumerated() {
            if mode == 2 && k != chosen { continue }
            let ring = SCNTorus(ringRadius: 0.075, pipeRadius: 0.009)
            let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = UIColor.white
            m.emission.contents = UIColor.white; m.readsFromDepthBuffer = false; m.writesToDepthBuffer = false
            ring.materials = [m]
            let node = SCNNode(geometry: ring); node.position = SCNVector3(Float(p.x), 0.03, Float(p.y)); node.renderingOrder = 3000
            node.castsShadow = false; root.addChildNode(node)
            if mode == 1 {
                // spectrum cycle, phase-shifted per pocket, plus a soft breathing scale
                let hues: [CGFloat] = [0.78, 0.68, 0.58, 0.36, 0.16, 0.08, 0.0]
                let cycle = SCNAction.customAction(duration: 1.4) { n, t in
                    let u = (t / 1.4 + CGFloat(k) / 6).truncatingRemainder(dividingBy: 1)
                    let f = u * CGFloat(hues.count - 1), i = Int(f), w = f - CGFloat(i)
                    let h = hues[i] * (1 - w) + hues[min(i + 1, hues.count - 1)] * w
                    let c = UIColor(hue: h, saturation: 0.9, brightness: 1, alpha: 1)
                    n.geometry?.firstMaterial?.diffuse.contents = c; n.geometry?.firstMaterial?.emission.contents = c
                }
                let pulse = SCNAction.sequence([.scale(to: 1.25, duration: 0.35), .scale(to: 0.9, duration: 0.35)])
                node.runAction(.repeatForever(.group([cycle, .repeat(pulse, count: 2)])))
            } else {
                m.diffuse.contents = UIColor(red: 0.2, green: 0.95, blue: 0.4, alpha: 1); m.emission.contents = m.diffuse.contents
                let check = SCNNode(geometry: SCNText(string: "✓", extrusionDepth: 0.2))
                if let text = check.geometry as? SCNText {
                    text.font = UIFont.systemFont(ofSize: 1, weight: .black); text.flatness = 0.05; text.materials = [m]
                    let (lo, hi) = check.boundingBox
                    check.pivot = SCNMatrix4MakeTranslation((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, 0)
                }
                check.scale = SCNVector3(0.12, 0.12, 0.02)
                check.position = SCNVector3(Float(p.x), 0.05, Float(p.y)); check.renderingOrder = 3001
                let billboard = SCNBillboardConstraint(); billboard.freeAxes = .all; check.constraints = [billboard]
                root.addChildNode(check)
            }
        }
    }
}
