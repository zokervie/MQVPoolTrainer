import UIKit

// 0.49b X3 — "thế bi xê dịch": shot k of a round (k = 0, 1, …) is played on BLDrillLayoutFor(spec, k): shot 0 is exactly the catalogue
// layout, later shots move the cue ball a little (same key + k → same layout on every device, so a challenge code or a replay
// reproduces it). Drills with `jitter == 0` and drills outside the catalogue never move.
extension TrainingController {
    /// The layout of variant `k` as balls (nil: no catalogue entry, or nothing moves for this drill / variant).
    func drillVariantBalls(_ d: Drill, _ k: Int) -> (balls: [BallState], angle: Double)? {
        guard var spec = d.spec, spec.jitter > 0, k > 0 else { return nil }
        var layout = BLDrillLayout()
        BLDrillLayoutFor(&spec, Int32(k), &layout)
        var moved = d.balls
        for i in moved.indices { moved[i].x = BLDrillLayoutX(&layout, Int32(i)); moved[i].y = BLDrillLayoutY(&layout, Int32(i)) }
        return (moved, layout.angle)
    }
    func drillHasVariants() -> Bool {
        Drill.all.indices.contains(drillIndex) && (Drill.all[drillIndex].spec?.jitter ?? 0) > 0
    }
    /// Right after `loadDrill`: put the table on variant `k` (the default aim points at the same spot as the catalogue's).
    func applyDrillVariant(_ k: Int) {
        drillVariant = k
        let d = Drill.all[drillIndex]
        guard let v = drillVariantBalls(d, k) else { return }
        initial = v.balls; before = v.balls; angle = v.angle
        engine.loadLayout(v.balls.map { $0.dictionary }); clearShot(); locked = false
        refresh(); updateControls(); wakeRendering()
    }
    /// Between the shots of a 5-shot round: re-rack on variant `k` (replaces "back to before the shot" for drills that move).
    func relayDrill(variant k: Int) {
        guard matchAllowsEditing, localTurn, !isPlacingBalls else { return }
        lockButton.releaseHold(); setHold(false)
        drillVariant = k
        let d = Drill.all[drillIndex]
        let v = drillVariantBalls(d, k) ?? (d.balls, d.angle)
        initial = v.balls; before = v.balls
        engine.loadLayout(v.balls.map { $0.dictionary }); clearShot(); restoreAimCamera(); locked = false
        angle = v.angle; spin.reset(); applyDrillTip()
        statusLabel.text = L10n.tr("Thế bi đã xếp lại · cú") + " \(k + 1)/5"
        refresh(); updateControls(); wakeRendering()
    }
}
