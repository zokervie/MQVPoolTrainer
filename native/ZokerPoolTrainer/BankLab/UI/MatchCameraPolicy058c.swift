import Foundation

/// 0.58c item 5: what the camera does when the local player's input permission changes in a match.
/// Pure (Foundation only) so it has a test that runs everywhere; TrainingController.syncMatchControls applies the result.
///
/// Owner (real devices, Wi-Fi): after every stroke of their own the camera flew to another angle (dizzy). The cause: the
/// moment the stroke starts, input permission is lost (host: the balls move; guest: the command is pending), and losing
/// it was read as "the opponent is playing" → spectator camera + spectator pivot. The turn is still the player's own until
/// the rules say otherwise, so the view stays where it is (only a gentle pull-back along the same line of sight), and the
/// spectator view comes only after the balls have stopped AND the turn really passed to the opponent.
enum MatchCameraPolicy {
    enum Action: Equatable {
        case none
        case restoreAim          // own turn (again): default aim camera behind the cue ball, along the cue
        case holdAndZoomOut      // own stroke in flight: same yaw, ease back along the line of sight
        case spectator           // opponent's turn: the broadcast view (unchanged from 0.49)
    }
    struct Outcome: Equatable { var action: Action; var holdingOwnShot: Bool }

    /// How far (×) the eye eases back along the aim axis while the own stroke runs. Yaw is never touched.
    static let ownShotZoomOut: Float = 1.22
    static let maxZoom: Float = 2.6   // same clamp as the pinch gesture

    static func zoomAfterOwnShot(_ zoom: Float) -> Float { min(maxZoom, zoom * ownShotZoomOut) }

    /// - wasLocal / isLocal: input permission before / after this sync.
    /// - networked: a host or guest of a Wi-Fi / online match (pass & play and the computer never lose the turn mid-stroke).
    /// - motion: balls of the stroke are still rolling (host: shot active or shot camera busy; guest: snapshot says moving).
    static func decide(wasLocal: Bool, isLocal: Bool, currentPlayer: Int, localPlayer: Int,
                       networked: Bool, motion: Bool, holdingOwnShot: Bool, cameraIsAim: Bool) -> Outcome {
        if isLocal {
            // Permission is (back) with the player: leave the hold; go to the aim camera unless it is already the aim view.
            // After a hold the eye was pulled back, so the saved pre-stroke aim pose is restored even if the mode is still "aim".
            let needsAim = holdingOwnShot || (!wasLocal && !cameraIsAim)
            return Outcome(action: needsAim ? .restoreAim : .none, holdingOwnShot: false)
        }
        let ownTurnStillThen = networked && currentPlayer == localPlayer
        if ownTurnStillThen {
            // Own stroke in flight (or the guest waiting for the host to confirm it): keep the angle.
            if wasLocal && !holdingOwnShot { return Outcome(action: .holdAndZoomOut, holdingOwnShot: true) }
            return Outcome(action: .none, holdingOwnShot: holdingOwnShot)
        }
        // The turn is not ours (any more).
        if holdingOwnShot {
            if motion { return Outcome(action: .none, holdingOwnShot: true) }   // watch the balls from our own angle until they stop
            return Outcome(action: .spectator, holdingOwnShot: false)
        }
        if wasLocal { return Outcome(action: .spectator, holdingOwnShot: false) }
        return Outcome(action: .none, holdingOwnShot: false)
    }

    /// Match start / new turn / after placing the cue ball: the aim camera is wanted once per turn key.
    static func wantsAimCamera(turnKey: String, lastKey: String, localTurn: Bool, busy: Bool) -> Bool {
        localTurn && !busy && turnKey != lastKey
    }
}

/// 0.59 (bản 200, owner photo IMG_7966 + video 17:11): with the cue ball near a rail and the aim camera behind that rail, the rail top
/// (36.3 mm nose → 40 mm cap, higher than the ball centre 28.6 mm) hid the lower half of the cue ball and the whole cue. The old guard
/// only lifted the EYE above the wood (70 mm); it never checked the SIGHT LINE. This raises the aim pitch, only as much as needed, until
/// the line from the eye to a point half a radius above the cloth on the ball's axis clears every rail it crosses (+2 mm).
/// Pure (Foundation only): Tests/MatchCameraPolicyTests.swift. Geometry = TableScene cushion profile + CueClearance.h BLRailProfile.
enum AimRailSight {
    static let halfWidth = 0.635, halfLength = 1.27          // playing area (cushion noses)
    static let outerWidth = 0.80, outerLength = 1.44         // outer edge of the wooden rail (TableScene.pocketWallLimit)
    static let noseHeight = 0.03629, capHeight = 0.0400, capStart = 0.053
    static let lookHeight = 0.014                            // half a ball radius: the upper ball, its centre and the tip contact stay in view
    static let margin = 0.002, step = 0.005, pitchStep = 0.01
    /// Height of the rail at a point of the table plane (0 over the cloth and outside the table).
    static func obstacle(x: Double, z: Double) -> Double {
        let outside = max(abs(x) - halfWidth, abs(z) - halfLength)
        guard outside > 0, abs(x) <= outerWidth, abs(z) <= outerLength else { return 0 }
        return outside < capStart ? noseHeight + (capHeight - noseHeight) * outside / capStart : capHeight
    }
    /// True when the sight line from an eye at `pitch` (distance `radius`, behind the ball against the aim direction) clears the rails.
    static func clear(ballX: Double, ballZ: Double, dirX: Double, dirZ: Double, radius: Double, pitch: Double) -> Bool {
        let h = radius * cos(pitch), eyeY = radius * sin(pitch)
        guard h > step else { return true }
        var s = step
        while s <= h {
            let height = obstacle(x: ballX - dirX * s, z: ballZ - dirZ * s)
            if height > 0 && lookHeight + (eyeY - lookHeight) * s / h < height + margin { return false }
            s += step
        }
        return true
    }
    /// The smallest pitch ≥ `pitch` with a clear sight line (never lowers the camera; capped at `maxPitch`).
    static func clearPitch(ballX: Double, ballZ: Double, dirX: Double, dirZ: Double, radius: Double, pitch: Double, maxPitch: Double = 1.2) -> Double {
        var p = pitch
        while p < maxPitch {
            if clear(ballX: ballX, ballZ: ballZ, dirX: dirX, dirZ: dirZ, radius: radius, pitch: p) { return p }
            p += pitchStep
        }
        return maxPitch
    }
}
