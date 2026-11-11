import Foundation
import simd

/// A camera suggestion for a recorded replay. This value never advances the world.
struct ReplayCameraFrame {
    let mode: Int                   // 0 oblique, 1 overhead, 2 cue/aim
    let zoom: Float
    let yaw: Float                  // TableScene.orbit (including its -0.20 offset)
    let pitch: Float                // orbitPitch, or aimPitch for mode 2
    let focus: SIMD4<Float>?        // minX, maxX, minY, maxY in pool-table metres
    let slowMotion: Double          // multiply the replay clock's rate, not audio time
    let segmentID: Int              // stable across frames and when seeking
}

/// Pure snapshot-based director. Call only for replay/archive playback with its
/// complete recorded event list. Live shots and manual replay cameras do not use it.
enum ReplayDirector {
    static let minimumCutInterval: Double = 2.2

    static func endingRate(time: Double, duration: Double) -> Double {
        guard time.isFinite, duration.isFinite, duration>0, time>=0, time<duration else{return 1}
        return time>=max(0,duration-3) ? 0.48:1
    }

    private enum ViewStyle {
        case intro, overhead, oblique, rail, pocket, wide, follow
    }

    private struct Moment {
        let index: Int
        let kind: Int
        let actor: Int
        let other: Int
        let time: Double
        let point: SIMD2<Float>
    }

    private struct Segment {
        let start: Double
        let style: ViewStyle
        let moment: Moment?
    }

    /// Prepare once when opening a replay. Sorting the complete native event log
    /// for every display frame would waste CPU during long breaks and replays.
    struct Plan {
        private let duration: Double
        private let initialAngle: Double
        private let segments: [Segment]
        private let pots: [Moment]

        init(duration: Double, events: [[String: NSNumber]], initialAngle: Double) {
            let length = duration.isFinite ? max(0, duration) : 0
            let moments = ReplayDirector.recordedMoments(events, duration: length)
            self.duration = length
            self.initialAngle = initialAngle.isFinite ? initialAngle : Double.pi / 2
            segments = ReplayDirector.makeSegments(moments, duration: length)
            pots = moments.filter { $0.kind == 2 && $0.actor > 0 }
        }

        func frame(time: Double, balls: [BallState]) -> ReplayCameraFrame {
            let clock = time.isFinite ? min(max(0, time), duration) : 0
            var selected = 0
            for index in segments.indices where segments[index].start <= clock + 1e-8 {
                selected = index
            }
            // Only object pots add approach slow motion; the final three seconds
            // use a separate slowdown for every replay.
            let pocketRate: Double = pots.contains {
                clock >= $0.time - 0.70 && clock <= $0.time + 0.25
            } ? 0.48 : 1.0
            return ReplayDirector.camera(for: segments[selected], id: selected,
                                         balls: balls, angle: initialAngle,
                                         slowMotion: min(pocketRate, ReplayDirector.endingRate(time:clock,duration:duration)))
        }
    }

    static func frame(time: Double, duration: Double, balls: [BallState],
                      events: [[String: NSNumber]], initialAngle: Double) -> ReplayCameraFrame {
        Plan(duration: duration, events: events, initialAngle: initialAngle)
            .frame(time: time, balls: balls)
    }

    private static func recordedMoments(_ events: [[String: NSNumber]],
                                        duration: Double) -> [Moment] {
        var result: [Moment] = []
        for (index, event) in events.enumerated() {
            guard let stamp = event["time"]?.doubleValue, stamp.isFinite,
                  stamp >= 0, stamp <= duration + 0.25,
                  let kind = event["kind"]?.intValue,
                  let actor = event["a"]?.intValue,
                  let other = event["b"]?.intValue,
                  (0...2).contains(kind), (0...15).contains(actor) else { continue }
            if kind == 0 && !(0...3).contains(other) { continue }
            if kind == 1 && (!(0...15).contains(other) || actor == other) { continue }
            if kind == 2 && !(0...5).contains(other) { continue }
            let fallback = kind == 2 ? pocketPoint(other) : SIMD2<Float>(0, 0)
            let x = event["x"]?.doubleValue ?? Double(fallback.x)
            let y = event["y"]?.doubleValue ?? Double(fallback.y)
            let point = finitePoint(x: x, y: y) ?? fallback
            result.append(Moment(index: index, kind: kind, actor: actor,
                                 other: other, time: stamp, point: point))
        }
        result.sort { left, right in
            if left.time == right.time { return left.index < right.index }
            return left.time < right.time
        }
        return result
    }

    /// 0.37 (owner: cinematic replay for future promo cuts): at most THREE shots, smooth 0.9 s dissolves —
    /// 1 wide establishing view of the whole table, 2 a low view along the cue ball's path framing the first contact,
    /// 3 the pocket the ball drops in (or a high three-quarter view following the moving balls).
    private static func makeSegments(_ moments: [Moment], duration: Double) -> [Segment] {
        var segments = [Segment(start: 0, style: .wide, moment: nil)]
        let contact = moments.first { $0.kind == 1 && ($0.actor == 0 || $0.other == 0) }
        let pot = moments.first { $0.kind == 2 && $0.actor > 0 }
        if let contact = contact, contact.time > 0.5 {
            append(Segment(start: max(0.6, contact.time - 0.55), style: .follow, moment: contact),
                   to: &segments, duration: duration, gap: 1.0)
        } else if duration > 1.6 {
            append(Segment(start: 0.8, style: .follow, moment: nil), to: &segments, duration: duration, gap: 0.8)
        }
        if let pot = pot {
            append(Segment(start: max(1.2, pot.time - 1.0), style: .pocket, moment: pot),
                   to: &segments, duration: duration, gap: 1.0)
        } else if let last = segments.last, duration - last.start > 3.0 {
            append(Segment(start: last.start + 2.2, style: .oblique, moment: nil), to: &segments, duration: duration, gap: 1.0)
        }
        segments.sort { $0.start < $1.start }
        return Array(segments.prefix(3))
    }

    private static func append(_ candidate: Segment, to segments: inout [Segment],
                               duration: Double, gap: Double = minimumCutInterval) {
        guard candidate.start > 0, candidate.start < duration - 0.35 else { return }
        let clear = segments.allSatisfy {
            abs($0.start - candidate.start) >= gap - 1e-8
        }
        if clear { segments.append(candidate) }
    }

    private static func camera(for segment: Segment, id: Int, balls: [BallState],
                               angle: Double, slowMotion: Double) -> ReplayCameraFrame {
        var mode = 0
        var zoom: Float = 1.0
        var yaw = angle + 0.85 - 0.20
        var pitch: Float = 0.68
        var focus: SIMD4<Float>?
        switch segment.style {
        case .wide:
            // establishing: three-quarter angle on the shooter's side. 0.39 (owner: the first cut was so high that the
            // lamp fixture hid the balls): lower (0.72 → 0.46 rad) and a little closer, still the whole table in frame.
            mode = 0
            zoom = 1.0
            yaw = angle + 0.55 - 0.20
            pitch = 0.46
            focus = nil
        case .follow:
            // low, behind the cue ball's line of travel, framing the cue ball and what it is about to hit
            pitch = 0.30
            zoom = 1.02
            yaw = angle - 0.20
            if let moment = segment.moment {
                var points = [moment.point]
                if let cue = balls.first(where: { $0.id == 0 }), let p = finitePoint(x: cue.x, y: cue.y) { points.append(p) }
                focus = boundedFocus(points, margin: 0.22, minWidth: 0.90, minLength: 1.10)
            } else {
                focus = movingFocus(balls)
            }
        case .intro:
            mode = 2
            pitch = 0.57
            yaw = angle
        case .overhead:
            mode = 1
            // Preserve the landscape table orientation of TableScene's top view.
            yaw = 0
            pitch = 1.40
        case .oblique:
            zoom = 1.04
            focus = movingFocus(balls)
        case .rail:
            pitch = 0.36
            if let moment = segment.moment {
                yaw = railYaw(moment.other) - 0.20
                var points = [moment.point]
                if let actor = balls.first(where: { $0.id == moment.actor }),
                   let point = finitePoint(x: actor.x, y: actor.y) {
                    points.append(point)
                }
                focus = boundedFocus(points, margin: 0.24, minWidth: 0.95, minLength: 1.20)
            } else {
                yaw = angle - 0.85 - 0.20
                focus = movingFocus(balls)
            }
        case .pocket:
            pitch = 0.26
            zoom = 1.04
            if let moment = segment.moment {
                let hole = pocketPoint(moment.other)
                // Eye lies toward the table interior, so the rail does not hide
                // the approaching ball. Keep this yaw fixed throughout the shot.
                yaw = atan2(Double(-hole.y), Double(-hole.x)) + 0.22 - 0.20
                var points = [hole, moment.point]
                if let actor = balls.first(where: { $0.id == moment.actor }),
                   let point = finitePoint(x: actor.x, y: actor.y) {
                    // Sunk snapshots retain their final coordinates: retaining
                    // that point avoids a framing jump when the sunk flag flips.
                    points.append(point)
                }
                focus = boundedFocus(points, margin: 0.18, minWidth: 0.78, minLength: 0.96)
            }
        }
        return ReplayCameraFrame(mode: mode, zoom: zoom, yaw: wrappedYaw(yaw),
                                 pitch: pitch, focus: focus,
                                 slowMotion: slowMotion, segmentID: id)
    }

    private static func movingFocus(_ balls: [BallState]) -> SIMD4<Float>? {
        var moving = balls.filter { ball in
            guard !ball.sunk, ball.x.isFinite, ball.y.isFinite else { return false }
            let vx = ball.vx ?? 0
            let vy = ball.vy ?? 0
            return vx.isFinite && vy.isFinite && hypot(vx, vy) > 0.02
        }
        // A break scatters the action: prefer the full table over a narrow crop.
        guard !moving.isEmpty, moving.count <= 4 else { return nil }
        moving.sort { $0.id < $1.id }
        let points = moving.compactMap { finitePoint(x: $0.x, y: $0.y) }
        return boundedFocus(points, margin: 0.24, minWidth: 0.98, minLength: 1.32)
    }

    private static func boundedFocus(_ points: [SIMD2<Float>], margin: Float,
                                     minWidth: Float, minLength: Float) -> SIMD4<Float>? {
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        let width = min(1.56, max(minWidth, maxX - minX + margin * 2))
        let length = min(2.86, max(minLength, maxY - minY + margin * 2))
        let centerX = min(0.78 - width / 2, max(-0.78 + width / 2, (minX + maxX) / 2))
        let centerY = min(1.43 - length / 2, max(-1.43 + length / 2, (minY + maxY) / 2))
        return SIMD4(centerX - width / 2, centerX + width / 2,
                     centerY - length / 2, centerY + length / 2)
    }

    private static func finitePoint(x: Double, y: Double) -> SIMD2<Float>? {
        guard x.isFinite, y.isFinite else { return nil }
        return SIMD2(Float(min(0.78, max(-0.78, x))), Float(min(1.43, max(-1.43, y))))
    }

    private static func pocketPoint(_ id: Int) -> SIMD2<Float> {
        // Pool pocket IDs match World::pocket. Callers validate 0...5 first.
        switch id {
        case 0: return SIMD2(-0.670, -1.305)
        case 1: return SIMD2(0.670, -1.305)
        case 2: return SIMD2(-0.706, 0)
        case 3: return SIMD2(0.706, 0)
        case 4: return SIMD2(-0.670, 1.305)
        case 5: return SIMD2(0.670, 1.305)
        default: return SIMD2(0, 0)
        }
    }

    private static func railYaw(_ id: Int) -> Double {
        switch id {
        case 0: return 0
        case 1: return Double.pi
        case 2: return Double.pi / 2
        default: return -Double.pi / 2
        }
    }

    private static func wrappedYaw(_ value: Double) -> Float {
        var angle = value.truncatingRemainder(dividingBy: 2 * Double.pi)
        if angle > Double.pi { angle -= 2 * Double.pi }
        if angle < -Double.pi { angle += 2 * Double.pi }
        return Float(angle)
    }
}
