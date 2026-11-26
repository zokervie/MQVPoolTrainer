import Foundation

/// 0.58 L4 — "cơ trên băng". The player's WANTED tip point is remembered; near a rail the tip actually used is moved straight up
/// (BLCueRailBridgeSolve in CueClearance.h, the rule lives in the C core) instead of raising the cue to 45–90°. Raising the elevation
/// fan lets the tip come back down; away from the rail it returns to the wanted point. Foundation + the C header only: Tests/RailBridgeTests.swift.
struct RailBridge {
    /// What the player picked on the effect ball (updated by touches, never by the bridge itself).
    var wantedTop = 0.0
    /// 0.59 U3: true when the wanted tip came from the player's finger (not a reset or a drill default).
    private(set) var touched = false
    private(set) var top = 0.0, elevation = 0.0, cap = 45.0, moved = false
    mutating func playerChose(top t: Double, touched byFinger: Bool = false) { wantedTop = t; touched = byFinger }
    mutating func solve(x: Double, y: Double, angle: Double, side: Double, fan playerFan: Double, maxElevation: Double, maxOffset: Double,
                        width: Double, length: Double, radius: Double, nose: Double, xs: [Double], ys: [Double]) {
        // 0.59 U3: a touched tip is kept whenever a stroke can reach it — the cue rises to what it needs (BLCueBridgeFan).
        var bx = xs, by = ys
        let needed = touched ? BLCueMinimumElevationBalls(x, y, angle, side, wantedTop, width, length, radius, nose, &bx, &by, Int32(xs.count)) : 0
        let fan = BLCueBridgeFan(playerFan, needed, maxElevation, touched ? 1 : 0)
        let b = BLCueRailBridgeSolve(x, y, angle, side, wantedTop, fan, maxElevation, maxOffset, width, length, radius, nose, xs, ys, Int32(xs.count))
        top = b.top; elevation = b.elevation; moved = b.moved != 0
        // the highest elevation the bridge allows with this fan: the pad greys out tip points that need more
        cap = min(max(max(fan, b.floorDeg + BL_RAIL_BRIDGE_MARGIN_DEG), BL_RAIL_BRIDGE_COMFORT_DEG), max(maxElevation, b.floorDeg))
    }
}
