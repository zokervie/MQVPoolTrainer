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
