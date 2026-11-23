import Foundation

// 0.58 L4: the player's wanted tip is kept; near the rail the used tip moves up at a low cue, comes back when the fan is raised or the ball leaves the rail.
@main enum RailBridgeTests {
    static var checks = 0
    static func check(_ ok: Bool, _ msg: String) { checks += 1; if !ok { print("FAIL: \(msg)"); exit(1) } }
    static func main() {
        let W = 1.27, L = 2.54, R = 0.028575, nose = 0.27, frozen = W / 2 - R * (1 - nose * nose).squareRoot(), a = Double.pi
        func solve(_ s: inout RailBridge, gap: Double, fan: Double = 0) {
            s.solve(x: frozen - gap, y: 0, angle: a, side: 0, fan: fan, maxElevation: 45, maxOffset: 0.55, width: W, length: L, radius: R, nose: nose, xs: [], ys: [])
        }
        var s = RailBridge(); s.playerChose(top: 0)
        solve(&s, gap: 0)
        check(s.moved && s.top > 0.4 && s.top <= 0.55 && s.elevation <= 15 + 1e-6, "frozen to the rail: the tip goes up (\(s.top) R) at ≤ 15°, not the cue to 90°")
        check(s.wantedTop == 0, "the player's wanted tip is kept")
        let frozenTop = s.top
        solve(&s, gap: 0, fan: 30)
        check(s.top <= frozenTop + 1e-9 && s.elevation >= 30 - 1e-9, "raising the fan keeps the cue at the player's angle")
        solve(&s, gap: 0.03, fan: 20)
        check(s.top < frozenTop && s.moved, "a ball 3 cm off the rail and a 20° fan: the tip comes down")
        solve(&s, gap: 0.10)
        check(!s.moved && s.top == 0 && s.elevation < 15, "10 cm from the rail: the wanted tip is back, nothing moved")
        s.playerChose(top: -0.3); solve(&s, gap: 0.30)
        check(s.top == -0.3 && !s.moved, "a new choice away from the rail is used as it is")
        solve(&s, gap: 0, fan: 45)
        check(s.top < 0 || s.top > -0.3 - 1e-9, "a high fan can keep a lower tip frozen to the rail")
        check(s.cap >= 45 - 1e-9, "the pad's reachable limit follows the fan")
        print("PASS RailBridge: \(checks) checks")
    }
}
