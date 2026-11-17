import SceneKit
import UIKit

/// 0.44.1 M3 stills (`--cue-look-qa`): the cue solid and ghosted (0.42) at stroke elevations 5°, 42°, 70°, seen from
/// behind (the aim view, where the old multi-part model showed round discs at the joints when faded) and from the
/// side, plus the cue key icons as drawn on the HUD. Writes Documents/cue-qa/*.png (Tools/run_cue_look_qa.sh).
extension TrainingController {
    func startCueLookQA() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("cue-qa")
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        loadDrill(Drill.free); table.cameraMode = 2
        for v in view.subviews where v !== scn { v.isHidden = true }
        let eye = SCNNode(); eye.camera = (table.camera.camera?.copy() as? SCNCamera) ?? SCNCamera()
        eye.camera?.fieldOfView = 40
        table.scene.rootNode.addChildNode(eye)
        func save(_ image: UIImage, _ name: String) { try? image.pngData()?.write(to: dir.appendingPathComponent(name + ".png")) }
        // Icons: every key size used by the app, on the HUD's dark key colour, 4 roles in the bag + the 10 designs.
        let keys = (0...2).map { CueBag.cue($0) } + [CueBag.cue(0)]
        let strip = UIGraphicsImageRenderer(size: CGSize(width: 4 * 70, height: 40)).image { c in
            UIColor(white: 0.08, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 280, height: 40))
            for (i, look) in keys.enumerated() { look.iconImage().draw(in: CGRect(x: CGFloat(i) * 70 + 13, y: 14, width: 44, height: 12)) }
        }
        save(strip, "keys")
        let all = UIGraphicsImageRenderer(size: CGSize(width: 300, height: CGFloat(CueLook.all.count) * 22 + 8)).image { c in
            UIColor(white: 0.08, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 300, height: CGFloat(CueLook.all.count) * 22 + 8))
            for (i, look) in CueLook.all.enumerated() { look.iconImage(size: CGSize(width: 64, height: 14)).draw(at: CGPoint(x: 8, y: CGFloat(i) * 22 + 6)) }
        }
        save(all, "bag")
        let cases: [(String, Double, Float, Bool)] = [5.0, 42, 70].flatMap { e in [("aim-e\(Int(e))-solid", e, Float(1), false), ("aim-e\(Int(e))-ghost", e, Float(0.42), false)] }
            + [("side-solid", 8, 1, true), ("side-ghost", 8, 0.42, true)]
        func run(_ i: Int) {
            guard i < cases.count else {
                table.qaCueFade = nil; scn.pointOfView = table.camera; eye.removeFromParentNode()
                try? Data("done".utf8).write(to: dir.appendingPathComponent("done.txt")); return
            }
            let (name, elevation, fade, side) = cases[i]
            table.cueElevation = elevation; table.qaCueFade = fade
            refresh(); wakeRendering()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self = self else { return }
                let (tip, joint) = self.table.qaCueAxis(back: 0.75), butt = self.table.qaCueAxis(back: 1.45).butt
                func sub(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 { SCNVector3(a.x - b.x, a.y - b.y, a.z - b.z) }
                let axis = sub(butt, tip), len = max(0.001, sqrt(axis.x * axis.x + axis.y * axis.y + axis.z * axis.z))
                let u = SCNVector3(axis.x / len, axis.y / len, axis.z / len)   // tip → butt
                if side {
                    let n = SCNVector3(-u.z, 0, u.x), nl = max(0.001, sqrt(n.x * n.x + n.z * n.z))
                    eye.position = SCNVector3(joint.x + n.x / nl * 0.9, joint.y + 0.18, joint.z + n.z / nl * 0.9)
                    eye.look(at: joint, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
                } else {   // aim view: behind and just above the butt, looking down the cue at the tip
                    eye.position = SCNVector3(butt.x + u.x * 0.25, butt.y + 0.12 + u.y * 0.25, butt.z + u.z * 0.25)
                    eye.look(at: tip, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
                }
                self.scn.pointOfView = eye
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                    guard let self = self else { return }
                    save(self.scn.snapshot(), name); run(i + 1)
                }
            }
        }
        run(0)
    }
}
