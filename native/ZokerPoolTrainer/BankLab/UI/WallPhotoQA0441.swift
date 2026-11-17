import SceneKit
import UIKit

/// 0.44.1 M2 probe (`--wall-photo-qa`): for every room that hangs photos, put a camera (a copy of the play camera:
/// same HDR, exposure and tone settings) square in front of each photo, render the real SceneKit frame, and measure
/// the photo area: blown-out pixels (luma > 0.95) < 2 %, mean luma 0.35–0.65, contrast (luma std-dev) ≥ 60 % of the
/// source photo's. Also renders one wide view per room for the before/after sheet. Writes Documents/wall-qa/*.png and
/// summary.json; Tools/run_wall_photo_qa.sh copies them out and gates on the summary.
extension TrainingController {
    struct WallPhotoMeasure: Codable {
        var space: Int, photo: Int, mean: Double, blown: Double, contrast: Double, sourceContrast: Double, contrastRatio: Double, pass: Bool
    }
    static let wallQAMeanRange = 0.35...0.65, wallQABlownMax = 0.02, wallQAContrastMin = 0.60

    func startWallPhotoQA() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("wall-qa")
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for v in view.subviews where v !== scn { v.isHidden = true }
        let qaCamera = SCNNode()
        qaCamera.camera = (table.camera.camera?.copy() as? SCNCamera) ?? SCNCamera()
        table.scene.rootNode.addChildNode(qaCamera)
        var results: [WallPhotoMeasure] = []
        var rooms: [Int: Int] = [:]
        func photos() -> [(SCNNode, Int)] {
            var found: [(SCNNode, Int)] = []
            table.scene.rootNode.enumerateHierarchy { node, _ in
                if node.name == "wall-photo", let group = node.parent?.name, group.hasPrefix("photo-"), let k = Int(group.dropFirst(6)) { found.append((node, k)) }
            }
            return found
        }
        func save(_ image: UIImage, _ name: String) { try? image.pngData()?.write(to: dir.appendingPathComponent(name + ".png")) }
        func finish() {
            let pass = !results.isEmpty && results.allSatisfy { $0.pass }
            let summary: [String: Any] = ["result": pass ? "PASS" : "FAIL", "photos": results.count, "roomsWithPhotos": rooms.count,
                                          "rooms": rooms.map { "\($0.key):\($0.value)" }.sorted(),
                                          "measures": results.map { ["space": $0.space, "photo": $0.photo, "mean": $0.mean, "blown": $0.blown,
                                                                      "contrast": $0.contrast, "sourceContrast": $0.sourceContrast,
                                                                      "contrastRatio": $0.contrastRatio, "pass": $0.pass] }]
            if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: dir.appendingPathComponent("summary.json"), options: .atomic)
            }
            scn.pointOfView = table.camera; qaCamera.removeFromParentNode()
        }
        func room(_ k: Int) {
            guard k < TableScene.spaces.count else { finish(); return }
            table.selectSpace(k)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self = self else { return }
                let list = photos()
                if list.isEmpty { room(k + 1); return }
                rooms[k] = list.count
                func shot(_ i: Int) {
                    guard i < list.count else { room(k + 1); return }
                    let (node, id) = list[i]
                    let centre = node.convertPosition(SCNVector3Zero, to: nil)
                    let normal = node.convertVector(SCNVector3(0, 0, 1), to: nil)
                    let size = Float((node.geometry as? SCNPlane)?.width ?? 0.9)
                    // Wide view of the first photo's wall (before/after sheet), then a square-on view for the gate.
                    let wide = i == 0
                    let distance = wide ? 3.1 : size * 1.9
                    func place(_ d: Float, side: Float) {
                        let right = SCNVector3(normal.z, 0, -normal.x)
                        qaCamera.position = SCNVector3(centre.x + normal.x * d + right.x * side, centre.y - 0.05, centre.z + normal.z * d + right.z * side)
                        qaCamera.look(at: centre, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
                    }
                    self.scn.pointOfView = qaCamera
                    if wide {
                        place(distance, side: 0.6)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                            guard let self = self else { return }
                            save(self.scn.snapshot(), String(format: "room-%02lld", k))
                            self.measurePhoto(node: node, id: id, space: k, size: size, centre: centre, normal: normal, camera: qaCamera, save: save) { results.append($0); shot(i + 1) }
                        }
                    } else {
                        self.measurePhoto(node: node, id: id, space: k, size: size, centre: centre, normal: normal, camera: qaCamera, save: save) { results.append($0); shot(i + 1) }
                    }
                }
                shot(0)
            }
        }
        room(0)
    }

    private func measurePhoto(node: SCNNode, id: Int, space: Int, size: Float, centre: SCNVector3, normal: SCNVector3, camera: SCNNode,
                              save: @escaping (UIImage, String) -> Void, done: @escaping (WallPhotoMeasure) -> Void) {
        let d = size * 1.9
        camera.position = SCNVector3(centre.x + normal.x * d, centre.y, centre.z + normal.z * d)
        camera.look(at: centre, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            let image = self.scn.snapshot()
            save(image, String(format: "photo-%02lld-%02lld", space, id))
            // Photo rectangle on screen from its four corners, inset 6 % so the mat and frame never count.
            let h = size / 2 * 0.94
            let corners = [SCNVector3(-h, -h, 0), SCNVector3(h, -h, 0), SCNVector3(h, h, 0), SCNVector3(-h, h, 0)].map {
                self.scn.projectPoint(node.convertPosition($0, to: nil))
            }
            let xs = corners.map { CGFloat($0.x) }, ys = corners.map { CGFloat($0.y) }
            let rect = CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0, width: (xs.max() ?? 0) - (xs.min() ?? 0), height: (ys.max() ?? 0) - (ys.min() ?? 0))
            // projectPoint is in view points; the snapshot may come back at pixel size with scale 1 — map by width.
            let k = (image.cgImage.map { CGFloat($0.width) } ?? 1) / max(self.scn.bounds.width, 1)
            let shown = Self.lumaStats(image, rect: rect, pixelsPerPoint: k)
            let source = UIImage(named: String(format: "ZWall%02lld", max(1, min(TableScene.photoCount, id))))
            let original = source.map { Self.lumaStats($0, rect: CGRect(origin: .zero, size: $0.size)) } ?? (mean: 0, blown: 0, std: 0)
            let ratio = original.std > 1e-6 ? shown.std / original.std : 0
            let pass = shown.blown < Self.wallQABlownMax && Self.wallQAMeanRange.contains(shown.mean) && ratio >= Self.wallQAContrastMin
            done(WallPhotoMeasure(space: space, photo: id, mean: shown.mean, blown: shown.blown, contrast: shown.std,
                                  sourceContrast: original.std, contrastRatio: ratio, pass: pass))
        }
    }

    /// Rec. 709 luma of sRGB-encoded pixels (0…1) inside `rect` (points of `image`): mean, share above 0.95, std-dev.
    static func lumaStats(_ image: UIImage, rect: CGRect, pixelsPerPoint: CGFloat? = nil) -> (mean: Double, blown: Double, std: Double) {
        guard let cg = image.cgImage else { return (0, 0, 0) }
        let s = pixelsPerPoint ?? CGFloat(cg.width) / max(image.size.width, 1)
        let crop = CGRect(x: rect.minX * s, y: rect.minY * s, width: rect.width * s, height: rect.height * s).integral
            .intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard crop.width >= 4, crop.height >= 4, let part = cg.cropping(to: crop) else { return (0, 0, 0) }
        let w = 160, hgt = max(4, Int(160 * crop.height / crop.width))
        var px = [UInt8](repeating: 0, count: w * hgt * 4)
        guard let ctx = CGContext(data: &px, width: w, height: hgt, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return (0, 0, 0) }
        ctx.interpolationQuality = .medium
        ctx.draw(part, in: CGRect(x: 0, y: 0, width: w, height: hgt))
        var sum = 0.0, sum2 = 0.0, blown = 0
        let n = w * hgt
        for i in 0..<n {
            let y = (0.2126 * Double(px[i * 4]) + 0.7152 * Double(px[i * 4 + 1]) + 0.0722 * Double(px[i * 4 + 2])) / 255
            sum += y; sum2 += y * y; if y > 0.95 { blown += 1 }
        }
        let mean = sum / Double(n)
        return (mean, Double(blown) / Double(n), sqrt(max(0, sum2 / Double(n) - mean * mean)))
    }
}
