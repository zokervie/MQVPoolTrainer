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
            if mode == 1 {
                // 0.53 B3: a soft white mist around the mouth (alpha ~0.25), never covering the mouth itself.
                let tube = SCNTube(innerRadius: 0.07, outerRadius: 0.15, height: 0.002)
                let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = UIColor(white: 1, alpha: 0.25)
                m.isDoubleSided = true; m.readsFromDepthBuffer = false; m.writesToDepthBuffer = false
                tube.materials = [m]
                let node = SCNNode(geometry: tube); node.position = SCNVector3(Float(p.x), 0.03, Float(p.y)); node.renderingOrder = 3000
                node.castsShadow = false; root.addChildNode(node)
            } else {
                // after the call: one thin white arrow bobbing gently (about 2 cm, 1.2 s) pointing down at the pocket
                let white = SCNMaterial(); white.lightingModel = .constant; white.diffuse.contents = UIColor.white
                white.readsFromDepthBuffer = false; white.writesToDepthBuffer = false
                let cone = SCNCone(topRadius: 0, bottomRadius: 0.012, height: 0.03); cone.materials = [white]
                let shaft = SCNCylinder(radius: 0.0035, height: 0.05); shaft.materials = [white]
                let arrow = SCNNode()
                let tip = SCNNode(geometry: cone); tip.eulerAngles.x = .pi; tip.position = SCNVector3(0, 0.015, 0)   // tip down
                let rod = SCNNode(geometry: shaft); rod.position = SCNVector3(0, 0.055, 0)
                arrow.addChildNode(tip); arrow.addChildNode(rod)
                arrow.position = SCNVector3(Float(p.x), 0.10, Float(p.y)); arrow.renderingOrder = 3001
                arrow.enumerateChildNodes { n, _ in n.renderingOrder = 3001 }
                arrow.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.02, z: 0, duration: 0.6), .moveBy(x: 0, y: -0.02, z: 0, duration: 0.6)])))
                root.addChildNode(arrow)
            }
        }
    }
}
