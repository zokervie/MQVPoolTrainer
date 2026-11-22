import SceneKit
import UIKit

/// 0.53 photo QA (`--scene-photos-qa=<tag>`, Debug only): "standard room" photos rendered OFFSCREEN (SCNRenderer + Metal; the SCNView snapshot reads black
/// on the Simulator). Per room: the real play camera, a standing view and an overhead view. Details (diamond numbers, rack frame, the neighbour table,
/// the logo wall, the call markers) in room 0. Writes Documents/scene-photos-<tag>/*.png; Tools/run_scene_photos_qa.sh copies them out.
extension TrainingController {
    func startScenePhotosQA(tag: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("scene-photos-" + tag)
        try? FileManager.default.removeItem(at: dir); try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for v in view.subviews where v !== scn { v.isHidden = true }
        let size = CGSize(width: 960, height: 540)
        func save(_ name: String, _ image: UIImage?) { if let d = image?.pngData() { try? d.write(to: dir.appendingPathComponent(name + ".png")) } }
        func details() {
            table.selectSpace(0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                // diamond numbers from the low aiming camera and from a corner
                TableScene.qaLegacyDiamonds = tag.hasPrefix("before"); self.table.qaForceDiamonds(true)
                self.wakeRendering()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.table.qaForceDiamonds(true)
                    save("diamonds-play", self.table.photo(size: size))
                    save("diamonds-corner", self.table.photo(size: size, eye: SCNVector3(0.55, 0.5, -1.55), target: SCNVector3(-0.4, 0.02, 0.6), fov: 60))
                    save("diamonds-side", self.table.photo(size: size, eye: SCNVector3(-1.15, 0.9, -0.4), target: SCNVector3(0.3, 0.02, 0.3), fov: 60))
                    self.table.qaForceDiamonds(false)
                    // the racked balls with the frame, close and from the shooter
                    self.startMatch(rule: "nineBall", network: false)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.table.qaShowRackFrame(self.balls)
                        save("rack-close", self.table.photo(size: size, eye: SCNVector3(0.5, 0.55, 0.15), target: SCNVector3(0, 0.02, 0.85), fov: 45))
                        save("rack-top", self.table.photo(size: size, eye: SCNVector3(0, 1.3, 0.85), target: SCNVector3(0, 0, 0.85), fov: 40, up: SCNVector3(1, 0, 0)))
                        // the neighbour table and the logo wall
                        save("neighbour-wide", self.table.photo(size: size, eye: SCNVector3(0, 1.7, -3.6), target: SCNVector3(0, 0.4, 0.4), fov: 70))
                        save("logo-wall", self.table.photo(size: size, eye: SCNVector3(0, 1.0, 1.2), target: SCNVector3(0, 1.0, -4.6), fov: 60))
                        save("logo-wall-low", self.table.photo(size: size, eye: SCNVector3(0, 0.55, -1.7), target: SCNVector3(0, 0.9, -4.6), fov: 60))
                        // call markers (mist, then the chosen pocket's arrow)
                        self.showCallPockets(1); self.wakeRendering()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            save("call-mist", self.table.photo(size: size, eye: SCNVector3(0, 1.5, 0), target: SCNVector3(0, 0, 0), fov: 60, up: SCNVector3(1, 0, 0)))
                            save("call-mist-low", self.table.photo(size: size, eye: SCNVector3(0.5, 0.5, -1.5), target: SCNVector3(0.4, 0.02, 0.5), fov: 60))
                            self.showCallPockets(2, chosen: 3)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                save("call-arrow-low", self.table.photo(size: size, eye: SCNVector3(-0.5, 0.5, -1.0), target: SCNVector3(0.6, 0.03, 0), fov: 50))
                                try? "done".write(to: dir.appendingPathComponent("done.txt"), atomically: true, encoding: .utf8)
                            }
                        }
                    }
                }
            }
        }
        func room(_ k: Int) {
            guard k < TableScene.spaces.count else { details(); return }
            table.selectSpace(k)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                save("room\(k)-play", self.table.photo(size: size))
                save("room\(k)-standing", self.table.photo(size: size, eye: SCNVector3(-1.4, 1.65, -2.7), target: SCNVector3(0, 0.55, 0.2), fov: 62))
                save("room\(k)-top", self.table.photo(size: size, eye: SCNVector3(0, 2.0, 0.02), target: SCNVector3(0, 0, 0), fov: 62, up: SCNVector3(1, 0, 0)))
                room(k + 1)
            }
        }
        room(0)
    }
}
