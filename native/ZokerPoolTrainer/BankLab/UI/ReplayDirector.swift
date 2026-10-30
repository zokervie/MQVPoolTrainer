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

    private enum ViewStyle {
        case intro, overhead, oblique, rail, pocket
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
            // Scratches and recovery/out-of-table events never cause slow motion.
            let slow = pots.contains {
                clock >= $0.time - 0.70 && clock <= $0.time + 0.25
            } ? 0.48 : 1.0
            return ReplayDirector.camera(for: segments[selected], id: selected,
                                         balls: balls, angle: initialAngle,
                                         slowMotion: slow)
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

    private static func makeSegments(_ moments: [Moment], duration: Double) -> [Segment] {
        let pots = moments.filter { $0.kind == 2 && $0.actor > 0 }
        // A very early pot starts in a wide pocket approach view. This avoids a
        // sub-two-second cut from the cue view just as the ball reaches the hole.
        let earlyPot = pots.first.flatMap { $0.time < minimumCutInterval + 0.82 ? $0 : nil }
        let firstStyle: ViewStyle = earlyPot == nil ? .intro : .pocket
        var segments = [Segment(start: 0, style: firstStyle, moment: earlyPot)]

        // Reserve pocket approaches first; contacts and fallback views may not
        // force a second cut close to a selected hero shot.
        for pot in pots where pot.index != earlyPot?.index {
            let start = max(minimumCutInterval, pot.time - 0.82)
            append(Segment(start: start, style: .pocket, moment: pot),
                   to: &segments, duration: duration)
        }
        for moment in moments where moment.kind == 1 && moment.time > 0.75 {
            let start = max(minimumCutInterval, moment.time - 0.45)
            append(Segment(start: start, style: .overhead, moment: moment),
                   to: &segments, duration: duration)
        }
        for moment in moments where moment.kind == 0 && moment.time > 0.75 {
            let start = max(minimumCutInterval, moment.time - 0.35)
            append(Segment(start: start, style: .rail, moment: moment),
                   to: &segments, duration: duration)
        }
        // Long, quiet rolls still get a readable establishing view and a low
        // angle. The bounded loop also handles malformed archive durations.
        for slot in 0..<64 {
            let start = 2.8 + Double(slot) * 3.4
            if start >= duration - 0.35 { break }
            let style: ViewStyle
            switch slot % 3 {
            case 0: style = .overhead
            case 1: style = .oblique
            default: style = .rail
            }
            append(Segment(start: start, style: style, moment: nil),
                   to: &segments, duration: duration)
        }
        segments.sort { $0.start < $1.start }
        return segments
    }

    private static func append(_ candidate: Segment, to segments: inout [Segment],
                               duration: Double) {
        guard candidate.start > 0, candidate.start < duration - 0.35 else { return }
        let clear = segments.allSatisfy {
            abs($0.start - candidate.start) >= minimumCutInterval - 1e-8
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
