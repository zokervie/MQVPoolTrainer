import SceneKit
import UIKit

/// 0.46 M3 probe (`--table-family-qa`): the four table families (colourway 1 each) in the standard room (space 0), the
/// real play camera in the overview orbit that shows legs and cabinet. Each frame: blown-out pixels (luma > 0.95) of
/// the whole 3D view < 2 %. Writes Documents/table-qa/family-<name>.png + summary.json; Tools/run_table_family_qa.sh
/// copies them out and gates on the summary. The saved table choice is restored at the end.
extension TrainingController {
    static let tableQABlownMax = 0.02

    func startTableFamilyQA() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("table-qa")
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for v in view.subviews where v !== scn { v.isHidden = true }
        let original = TableLook.selected
        table.setClothColor(nil)
        table.selectSpace(0); table.cameraMode = 0; table.orbit = 0.62; table.zoom = 1.35
        var measures: [[String: Any]] = []
        func finish() {
            let pass = measures.count == TableFamily.allCases.count && measures.allSatisfy { ($0["pass"] as? Bool) == true }
            let summary: [String: Any] = ["result": pass ? "PASS" : "FAIL", "families": measures.count, "space": 0,
                                          "blownMax": Self.tableQABlownMax, "measures": measures]
            if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: dir.appendingPathComponent("summary.json"), options: .atomic)
            }
            table.selectTable(original)
        }
        func shot(_ i: Int) {
            guard i < TableFamily.allCases.count else { finish(); return }
            let family = TableFamily.allCases[i], look = TableLook.reference(family)
            table.selectTable(look)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self = self else { return }
                let image = self.scn.snapshot()
                let name = "family-" + family.name.lowercased().replacingOccurrences(of: "z-", with: "")
                try? image.pngData()?.write(to: dir.appendingPathComponent(name + ".png"))
                let stats = Self.lumaStats(image, rect: CGRect(origin: .zero, size: image.size))
                let pass = stats.mean > 0 && stats.blown < Self.tableQABlownMax
                measures.append(["family": family.name, "look": look.id, "image": name + ".png", "mean": stats.mean,
                                 "blown": stats.blown, "pass": pass])
                shot(i + 1)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { shot(0) }
    }
}
