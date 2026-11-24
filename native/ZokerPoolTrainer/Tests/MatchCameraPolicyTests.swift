import Foundation

/// 0.58c item 5: the camera decision around the local player's own stroke (Wi-Fi) and the once-per-turn aim camera.
@main enum MatchCameraPolicyTests {
    static var checks = 0
    static func check(_ ok: Bool, _ message: String) {
        checks += 1
        if !ok { print("FAIL MatchCameraPolicy: \(message)"); exit(1) }
    }
    static func main() {
        typealias P = MatchCameraPolicy
        // Wi-Fi host: own stroke starts (balls move → permission lost, turn still mine): hold, no spectator camera.
        var o = P.decide(wasLocal: true, isLocal: false, currentPlayer: 0, localPlayer: 0, networked: true, motion: true, holdingOwnShot: false, cameraIsAim: true)
        check(o.action == .holdAndZoomOut && o.holdingOwnShot, "own stroke starts → hold + zoom out, never spectator")
        // …while the balls roll (several syncs): still holding, no action (no yaw change).
        o = P.decide(wasLocal: false, isLocal: false, currentPlayer: 0, localPlayer: 0, networked: true, motion: true, holdingOwnShot: true, cameraIsAim: true)
        check(o.action == .none && o.holdingOwnShot, "balls rolling → keep holding")
        // Rules pass the turn but the balls still move on the guest's snapshot → still own angle.
        o = P.decide(wasLocal: false, isLocal: false, currentPlayer: 1, localPlayer: 0, networked: true, motion: true, holdingOwnShot: true, cameraIsAim: true)
        check(o.action == .none && o.holdingOwnShot, "turn passed but balls still moving → own angle")
        // Balls stopped, turn is the opponent's → the broadcast view (as before 0.58c), hold released.
        o = P.decide(wasLocal: false, isLocal: false, currentPlayer: 1, localPlayer: 0, networked: true, motion: false, holdingOwnShot: true, cameraIsAim: true)
        check(o.action == .spectator && !o.holdingOwnShot, "balls stopped + opponent's turn → spectator")
        // Own pot keeps the turn: permission returns → saved aim pose restored (eye comes back in).
        o = P.decide(wasLocal: false, isLocal: true, currentPlayer: 0, localPlayer: 0, networked: true, motion: false, holdingOwnShot: true, cameraIsAim: true)
        check(o.action == .restoreAim && !o.holdingOwnShot, "turn kept after the stroke → restore the aim pose")
        // Guest: command pending (permission lost, turn still mine) → hold too.
        o = P.decide(wasLocal: true, isLocal: false, currentPlayer: 1, localPlayer: 1, networked: true, motion: false, holdingOwnShot: false, cameraIsAim: true)
        check(o.action == .holdAndZoomOut, "guest command pending → hold")
        // Watching the opponent play: unchanged behaviour.
        o = P.decide(wasLocal: true, isLocal: false, currentPlayer: 1, localPlayer: 0, networked: true, motion: false, holdingOwnShot: false, cameraIsAim: true)
        check(o.action == .spectator, "turn already the opponent's when permission is lost → spectator")
        o = P.decide(wasLocal: false, isLocal: true, currentPlayer: 0, localPlayer: 0, networked: true, motion: false, holdingOwnShot: false, cameraIsAim: false)
        check(o.action == .restoreAim, "turn comes back while the camera is not aim → aim view")
        o = P.decide(wasLocal: false, isLocal: true, currentPlayer: 0, localPlayer: 0, networked: true, motion: false, holdingOwnShot: false, cameraIsAim: true)
        check(o.action == .none, "turn comes back and the camera is already aim → nothing")
        // Pass & play never loses the turn mid-stroke; a permission loss there is the computer's turn → spectator as before.
        o = P.decide(wasLocal: true, isLocal: false, currentPlayer: 1, localPlayer: 0, networked: false, motion: false, holdingOwnShot: false, cameraIsAim: true)
        check(o.action == .spectator, "computer's turn → spectator")
        // Zoom-out is bounded and only grows the distance.
        check(P.zoomAfterOwnShot(1.0) > 1.0 && P.zoomAfterOwnShot(1.0) <= 1.3, "gentle pull-back")
        check(P.zoomAfterOwnShot(2.5) == P.maxZoom, "clamped at the pinch limit")
        // Once-per-turn aim camera.
        check(P.wantsAimCamera(turnKey: "1-0-0-0", lastKey: "", localTurn: true, busy: false), "entering the match asks for the aim camera")
        check(!P.wantsAimCamera(turnKey: "1-0-0-0", lastKey: "1-0-0-0", localTurn: true, busy: false), "not twice for the same turn")
        check(P.wantsAimCamera(turnKey: "1-0-0-1", lastKey: "1-0-0-0", localTurn: true, busy: false), "ball-in-hand → placed is a new key")
        check(!P.wantsAimCamera(turnKey: "1-1-1-0", lastKey: "", localTurn: false, busy: false), "not while it is not our turn")
        print("PASS MatchCameraPolicy: \(checks) checks (Wi-Fi own-stroke hold, spectator timing, aim camera once per turn)")
    }
}
