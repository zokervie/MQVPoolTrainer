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
        // 0.59: aim camera sight line over the rails (bản 200: the rail hid the cue ball and the cue).
        typealias S = AimRailSight
        let r = 0.4854, base = 0.325
        check(S.clearPitch(ballX: 0, ballZ: 0, dirX: 0, dirZ: -1, radius: r, pitch: base) == base, "mid-table: pitch unchanged")
        let low = 0.15   // the player dragged the aim camera down (IMG_7966 shows a low eye)
        check(S.clearPitch(ballX: 0, ballZ: 1.17, dirX: 0, dirZ: -1, radius: r, pitch: base) == base, "10 cm from the rail at the default pitch is already clear")
        let tenCm = S.clearPitch(ballX: 0, ballZ: 1.17, dirX: 0, dirZ: -1, radius: r, pitch: low)
        let fourCm = S.clearPitch(ballX: 0, ballZ: 1.23, dirX: 0, dirZ: -1, radius: r, pitch: base)
        let frozen = S.clearPitch(ballX: 0, ballZ: 1.27 - 0.028575, dirX: 0, dirZ: -1, radius: r, pitch: base)
        let parallel = S.clearPitch(ballX: 0.60, ballZ: 0, dirX: 0, dirZ: -1, radius: r, pitch: base)
        let away = S.clearPitch(ballX: 0, ballZ: 1.17, dirX: 0, dirZ: 1, radius: r, pitch: base)
        check(tenCm > low, "10 cm from the near rail, low eye behind it → raised")
        check(fourCm > base, "4 cm from the near rail at the default pitch → raised")
        check(S.clear(ballX: 0, ballZ: 1.17, dirX: 0, dirZ: -1, radius: r, pitch: tenCm), "raised pitch really clears")
        check(!S.clear(ballX: 0, ballZ: 1.17, dirX: 0, dirZ: -1, radius: r, pitch: tenCm - 0.02), "and it is the smallest one (±1 step)")
        check(frozen > fourCm && frozen <= 1.2, "frozen to the rail needs more, still bounded")
        check(parallel == base, "near a side rail but shooting along it → unchanged")
        check(away == base, "shooting toward the near rail (eye over the cloth) → unchanged")
        check(S.clearPitch(ballX: 0, ballZ: 1.17, dirX: 0, dirZ: -1, radius: r, pitch: 0.9) == 0.9, "never lowers a high camera")
        check(S.cueClearPitch(cueElevationDegrees: 0, pitch: 0.02) == S.cueGap, "level cue: the lowest eye still sits above the cue line")
        check(abs(S.cueClearPitch(cueElevationDegrees: 10, pitch: 0.02) - (10 * .pi / 180 + S.cueGap)) < 1e-9, "10° cue: eye ≥ 10° + gap")
        check(S.cueClearPitch(cueElevationDegrees: 10, pitch: 0.325) == 0.325, "default pitch already clears a 10° cue → unchanged")
        check(S.cueClearPitch(cueElevationDegrees: 60, pitch: 0.3) == 0.3, "massé cue rises above the eye → unchanged")
        // ZB-039: the view tilts up only when the eye was forced up, never so far that the cue ball leaves the screen
        let half = 19 * Double.pi / 180   // aim camera 38° field of view
        check(S.viewTilt(forced: 0, halfFov: half) == 0 && S.viewTilt(forced: 0.02, halfFov: half) == 0, "nothing forced: the cue ball stays centred")
        check(S.viewTilt(forced: 0.15, halfFov: half) > 0.1 && S.viewTilt(forced: 0.15, halfFov: half) < S.viewTilt(forced: 0.2, halfFov: half), "more forced, more tilt")
        check(abs(S.viewTilt(forced: 2, halfFov: half) - 0.7 * half) < 1e-12, "capped: the cue ball stays inside the lower third")
        let frozenCue = S.cueClearPitch(cueElevationDegrees: 15, pitch: 0.02)   // owner photo: ↑15° cue on the rail, eye dragged down
        check(S.viewTilt(forced: frozenCue - 0.02, halfFov: half) > 0.2, "frozen cue ball, 15° cue, eye pulled low: tilts up ≥ 11°")
        check(S.obstacle(x: 0, z: 0) == 0 && S.obstacle(x: 0, z: 1.30) > 0.036 && S.obstacle(x: 0, z: 1.50) == 0, "rail height: cloth 0, rail 36–40 mm, floor 0")
        print(String(format: "REPORT AimRailSight: low eye 10 cm from rail %.2f rad (%.0f°), 4 cm %.2f rad (%.0f°), frozen %.2f rad (%.0f°), default %.3f rad (%.0f°)", tenCm, tenCm * 57.3, fourCm, fourCm * 57.3, frozen, frozen * 57.3, base, base * 57.3))
        print("PASS MatchCameraPolicy: \(checks) checks (Wi-Fi own-stroke hold, spectator timing, aim camera once per turn)")
    }
}
