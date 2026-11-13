import Foundation

/// 0.42 (owner acceptance 0.41 item 10): on the opponent's stroke and in replays the cue tip must visibly meet the
/// cue ball at the contact point, then follow through — before, the cue was hidden the moment the balls moved.
struct CueStrikeAnim {
    var start: Double, origin: BallState, angle: Double, side: Double, top: Double, elevation: Double, cueType: Int
    var fromPull: Double, lead: Double
}
extension TrainingController {
    private static var strikeAnim: CueStrikeAnim?
    /// `lead`: seconds of forward stroke before contact (0 when the balls already move); `fromPull`: back-swing start.
    func beginCueStrikeAnim(origin: BallState, angle: Double, side: Double, top: Double, elevation: Double, cueType: Int,
                            fromPull: Double, lead: Double) {
        Self.strikeAnim = CueStrikeAnim(start: ProcessInfo.processInfo.systemUptime, origin: origin, angle: angle, side: side,
                                        top: top, elevation: elevation, cueType: cueType, fromPull: max(0, fromPull), lead: max(0, lead))
        wakeRendering()
    }
    /// Current pose of the strike animation, nil when it is over. Pull > 0 = drawn back, 0 = tip on the ball,
    /// < 0 = follow-through past the contact point.
    func cueStrikeAnimPose() -> (anim: CueStrikeAnim, pull: Double)? {
        guard let a = Self.strikeAnim else { return nil }
        let t = ProcessInfo.processInfo.systemUptime - a.start
        if t < a.lead { let u = t / max(a.lead, 1e-3); return (a, a.fromPull * (1 - u * u)) }   // accelerating forward
        let f = t - a.lead
        if f < 0.26 { return (a, -Self.followThrough(f)) }
        Self.strikeAnim = nil; return nil
    }
    static func followThrough(_ f: Double) -> Double { 0.18 * min(1, f / 0.08) }
    /// Replay: the last 0.14 s before contact closes the back-swing to the ball.
    func replayStrokePull(_ recorded: Double, clock: Double) -> Double {
        clock > -0.14 && clock < 0 ? recorded * (-clock / 0.14) * (-clock / 0.14) : recorded
    }
}
