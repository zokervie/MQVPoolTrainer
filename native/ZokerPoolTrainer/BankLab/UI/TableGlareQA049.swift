import SceneKit
import UIKit

/// 0.49c G5 probe (`--table-glare-qa`, Debug only): every table look (4 families × 3 colourways) in the standard room (space 0),
/// rendered OFFSCREEN (SCNRenderer + Metal: the SCNView snapshot reads black on the Simulator) from above and obliquely, no balls.
/// Measures the share of near-white pixels (all channels >= 250) over the table area. Writes Documents/glare-qa/summary.json + PNGs.
/// Simulator light is darker than a phone: the numbers rank the looks and show before/after, they do not replace a device check.
extension TrainingController {
    static func glarePercent(_ image: UIImage, region: CGRect) -> (percent: Double, mean: Double) {
        guard let cg = image.cgImage else { return (-1, -1) }
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return (-1, -1) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let x0 = Int(Double(w) * region.minX), x1 = Int(Double(w) * region.maxX), y0 = Int(Double(h) * region.minY), y1 = Int(Double(h) * region.maxY)
        var hot = 0, total = 0, sum = 0
        for y in stride(from: y0, to: y1, by: 2) { for x in stride(from: x0, to: x1, by: 2) {
            let i = (y * w + x) * 4; total += 1
            sum += Int(data[i]) + Int(data[i + 1]) + Int(data[i + 2])
            if data[i] >= 250 && data[i + 1] >= 250 && data[i + 2] >= 250 { hot += 1 }
        } }
        return total > 0 ? (Double(hot) / Double(total) * 100, Double(sum) / Double(total) / 3) : (-1, -1)
    }
    func startTableGlareQA() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("glare-qa")
        try? FileManager.default.removeItem(at: dir); try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for v in view.subviews where v !== scn { v.isHidden = true }
        let original = TableLook.selected
        table.setClothColor(nil); table.selectSpace(0)
        var rows: [[String: Any]] = []
        func finish() {
            let worst = rows.compactMap { $0["worstPercent"] as? Double }.max() ?? -1
            let summary: [String: Any] = ["rows": rows, "worstPercent": worst, "gatePercent": 2.0, "result": rows.isEmpty ? "NOT_RUN" : (worst < 0 ? "NOT_RUN" : (worst <= 2.0 ? "PASS" : "FAIL"))]
            if let d = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) { try? d.write(to: dir.appendingPathComponent("summary.json"), options: .atomic) }
            glareSummary = "\(summary["result"] ?? "NOT_RUN"):\(String(format: "%.2f", worst))"
            table.selectTable(original)
        }
        func next(_ i: Int) {
            guard i < TableLook.all.count else { finish(); return }
            let look = TableLook.all[i]
            table.selectTable(look)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                var row: [String: Any] = ["look": look.id]
                var worst = -1.0
                for (name, oblique, region) in [("top", false, CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)), ("oblique", true, CGRect(x: 0.15, y: 0.25, width: 0.7, height: 0.6))] {
                    if let image = self.table.probeImage(size: CGSize(width: 1280, height: name == "top" ? 640 : 800), oblique: oblique) {
                        let m = Self.glarePercent(image, region: region)
                        row[name + "Percent"] = m.percent; row[name + "Mean"] = m.mean
                        if m.mean >= 8 { worst = max(worst, m.percent) }   // a near-black frame is not a measurement
                        try? image.pngData()?.write(to: dir.appendingPathComponent(look.id + "-" + name + ".png"))
                    }
                }
                row["worstPercent"] = worst
                rows.append(row); next(i + 1)
            }
        }
        next(0)
    }
}
