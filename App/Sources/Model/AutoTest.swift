import Foundation
import QuartzCore
import simd
import PoolPhysics
import PoolDrills

/// Chế độ tự kiểm tra cho CI (chạy trên simulator, chụp màn hình, ghi chẩn đoán).
/// Kích hoạt bằng tham số khởi chạy: `-autotest <kịch bản>`. Không ảnh hưởng khi chạy bình thường.
///
/// Kịch bản: `home` · `free` · `overview` · `effect` · `locked` · `shotlab` · `drill:<id>` · `shot:<id>`
@MainActor
enum AutoTest {
    static var scenario: String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-autotest"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    /// `-autotest-slow`: phát lại cú chậm (×0,35) để ảnh chụp simulator (chậm ~1 s/ảnh) bắt được giữa cú.
    static var timeScale: Double {
        ProcessInfo.processInfo.arguments.contains("-autotest-slow") ? 0.35 : 1
    }

    // Thống kê khung hình do GameContainer ghi lại.
    static var frameTimes: [Double] = []
    static var renderedBallCount = 0
    static var lastCameraPosition = SIMD3<Float>(0, 0, 0)

    static func recordFrame(dt: Float, balls: Int, camera: SIMD3<Float>) {
        guard scenario != nil else { return }
        if frameTimes.count < 2_000 { frameTimes.append(Double(dt)) }
        renderedBallCount = balls
        lastCameraPosition = camera
    }

    static func run(model: GameModel, setPlaying: @escaping (Bool) -> Void) async {
        guard let s = scenario else { return }
        let drills = DrillCatalog.load()
        func drill(_ id: Substring) -> Drill? { drills.first { $0.id == id } }
        model.settings.seenLockHint = true

        switch s {
        case "home":
            break
        case "free":
            model.startFree(); setPlaying(true)
        case "overview":
            model.startFree(); model.cameraMode = .overview; setPlaying(true)
        case "effect":
            model.startFree(); setPlaying(true)
            model.effectExpanded = true
            model.setTip(SIMD2(0.3, -0.25))
        case "locked":
            model.startFree(); setPlaying(true)
            model.lockTapped()
        case "shotlab":
            model.startFree(); model.shotLabOpen = true; setPlaying(true)
        default:
            if s.hasPrefix("drill:"), let d = drill(s.dropFirst(6)) {
                model.startDrill(d); setPlaying(true)
            } else if s.hasPrefix("shot:"), let d = drill(s.dropFirst(5)) {
                model.startDrill(d); setPlaying(true)
                try? await Task.sleep(for: .seconds(2))
                model.shootShotLab(d.guideStrike(aimAngle: model.aimAngle))
            }
        }
        // Ghi chẩn đoán lặp lại (ghi đè) để CI lấy được bản mới nhất dù kết thúc app lúc nào.
        for _ in 0..<12 {
            try? await Task.sleep(for: .seconds(1.5))
            writeDiagnostics(model: model, scenario: s)
        }
    }

    static func writeDiagnostics(model: GameModel, scenario s: String) {
        var lines: [String] = []
        lines.append("scenario: \(s)")
        lines.append("state: \(model.state)")
        lines.append(String(format: "aimAngle: %.4f rad", model.aimAngle))
        lines.append("cameraMode: \(model.cameraMode)")
        lines.append("drill: \(model.drill?.id ?? "-")")
        lines.append("balls (physics): \(model.balls.count), rendered: \(renderedBallCount)")
        for b in model.balls {
            lines.append(String(format: "  ball %d: (%.4f, %.4f) %@", b.id, b.position.x, b.position.y, "\(b.state)"))
        }
        let c = lastCameraPosition
        lines.append(String(format: "camera (render): (%.3f, %.3f, %.3f)", c.x, c.y, c.z))
        if !frameTimes.isEmpty {
            let sorted = frameTimes.sorted()
            let mean = frameTimes.reduce(0, +) / Double(frameTimes.count)
            lines.append(String(format: "frames: %d, mean dt %.2f ms (%.0f fps), p99 dt %.2f ms (simulator, not device)",
                                frameTimes.count, mean * 1000, 1 / max(mean, 1e-6), sorted[Int(Double(sorted.count - 1) * 0.99)] * 1000))
        }
        if let r = model.result {
            lines.append(String(format: "shot: duration %.3f s, collisions %d, status %@, miscue %@",
                                r.trajectory.duration, r.collisions.count, "\(r.status)", "\(r.miscue)"))
            for k in CollisionKind.allCases {
                let n = r.collisions.filter { $0.kind == k }.count
                if n > 0 { lines.append("  \(k.rawValue): \(n)") }
            }
            lines.append("  pocketed: \(r.pocketed.map { "\($0.ballId)->\($0.pocketId)" })")
        }
        if let f = model.feedback {
            lines.append("feedback: success \(f.drillSuccess.map { "\($0)" } ?? "-"), level \(f.speedLevel), "
                         + String(format: "cue %.2f m/s, %.2f table lengths", f.cueSpeed, f.tableLengths))
            lines.append("  aim error: \(f.aimErrorDegrees.map { String(format: "%.3f°", $0) } ?? "-"), window: \(f.aimWindowDegrees.map { String(format: "%.2f°", $0) } ?? "-"), pending: \(f.aimPending)")
            for l in f.conditionLines { lines.append("  \(l)") }
        }
        let text = lines.joined(separator: "\n") + "\n"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let name = "autotest-" + s.replacingOccurrences(of: ":", with: "_") + ".txt"
            try? text.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
    }
}
