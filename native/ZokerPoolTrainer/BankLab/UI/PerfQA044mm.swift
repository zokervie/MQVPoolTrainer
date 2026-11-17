import UIKit
import SceneKit

/// 0.44-mm (anh: "giật khi chơi nhưng replay mượt"). Measure before fixing: one segment per live shot and per replay,
/// each with (a) what the renderer drew every frame (FramePacer probe: ball + camera positions, render clock) and
/// (b) main-thread CPU per display tick split into match/network + computer + clock, the live solver/replay block,
/// audio, camera, and how often UIKit laid the HUD out while balls moved. Written to Documents/perf-qa/<n>-<kind>.json;
/// Tools/perf_judder.py turns the frames into a judder score. Active only with --perf-qa (or the diagnostics menu).
final class PerfSegment {
    let kind: String
    var tick: [Double] = [], match: [Double] = [], motion: [Double] = [], audio: [Double] = [], camera: [Double] = []
    var dt: [Double] = [], physicsDt: [Double] = []
    var layoutPasses = 0, hudRelayouts = 0, audioCalls = 0
    var strike: [String: Double] = [:], strikeEnd = 0.0, layoutTime = 0.0
    init(kind: String) { self.kind = kind }
}

extension TrainingController {
    static var perfSegment: PerfSegment?
    static var perfIndex = 0
    static var perfQA: Bool { ProcessInfo.processInfo.arguments.contains("--perf-qa") }

    func perfBegin(_ kind: String) {
        guard Self.perfQA, Self.perfSegment == nil else { return }
        Self.perfSegment = PerfSegment(kind: kind)
        table.pacer.startProbe(nodes: table.probeBallNodes, camera: table.camera)
    }
    func perfEnd() {
        guard let segment = Self.perfSegment else { return }
        Self.perfSegment = nil
        let frames = table.pacer.stopProbe()
        Self.perfIndex += 1
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("perf-qa")
        let record: [String: Any] = [
            "kind": segment.kind, "index": Self.perfIndex, "frameRate": shotProfile.frameRate,
            "tick": segment.tick, "match": segment.match, "motion": segment.motion, "audio": segment.audio, "camera": segment.camera,
            "dt": segment.dt, "physicsDt": segment.physicsDt, "layoutPasses": segment.layoutPasses, "hudRelayouts": segment.hudRelayouts, "audioCalls": segment.audioCalls,
            "pacing": FramePacer.enabled, "strike": segment.strike, "layoutTime": segment.layoutTime, "matchActive": matchPlay.active, "computer": matchPlay.computerLevel != nil,
            "frames": frames.map { frame -> [String: Any] in
                var balls: [String: [Float]] = [:]
                for (id, p) in frame.balls { balls[String(id)] = [p.x, p.y, p.z] }
                return ["t": frame.time, "host": frame.host, "camera": [frame.camera.x, frame.camera.y, frame.camera.z], "balls": balls]
            }]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            try data.write(to: directory.appendingPathComponent(String(format: "%02lld-%@.json", Self.perfIndex, segment.kind)), options: .atomic)
        } catch { NSLog("perf-qa write failed: \(error)") }
    }
    /// Scripted session: a pass-and-play 9-ball match, a 7 m/s break (live), then its replay at 1×.
    /// With --computer-qa as well, the computer breaks instead and only the live segment is recorded.
    func startPerfQA() {
        guard Self.perfQA, !ProcessInfo.processInfo.arguments.contains("--computer-qa") else { return }
        UserDefaults.standard.set(true, forKey: "diagReplayNoSlow039")   // 1× replay: same clock rate as live
        let delay = max(1.5, UserDefaults.standard.double(forKey: "qaPerfDelay"))   // -qaPerfDelay 10: time to attach a profiler
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.startMatch(rule: "nineBall", network: false)
            self.table.cameraMode = 2; self.table.zoom = 1.18
            self.perfFire(7.0)
        }
    }
    /// One stroke exactly like stroke.shot (shoot → collapse → setHold(false)), retried until it starts, timed by part.
    func perfFire(_ speed: Double, attempts: Int = 30) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, !self.shotActive, self.replayIndex == nil else { return }
            self.locked = true; self.shoot(speed)
            guard self.shotActive else { if attempts > 0 { self.perfFire(speed, attempts: attempts - 1) }; return }
            let t0 = CACurrentMediaTime(); self.spin.collapse()
            let t1 = CACurrentMediaTime(); self.setHold(false)
            let t2 = CACurrentMediaTime()
            Self.perfSegment?.strike["spinCollapse"] = t1 - t0; Self.perfSegment?.strike["setHoldFalse"] = t2 - t1
            // Everything after this point until the next tick is UIKit/Core Animation commit (layout, display).
            CATransaction.setCompletionBlock { Self.perfSegment?.strike["commitDone"] = CACurrentMediaTime() - t2 }
            Self.perfSegment?.strikeEnd = t2
        }
    }
    /// Called from stopReplay: after the measured replay, one more live stroke (is the strike stall per shot or once?).
    func perfAfterReplay() {
        guard Self.perfQA, !ProcessInfo.processInfo.arguments.contains("--computer-qa"), Self.perfIndex == 2 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.perfFire(3.0) }
    }
    /// Called from finishShot: after a recorded live shot, play its replay once (pass-and-play keeps the turn local).
    func perfAfterShot() {
        guard Self.perfQA, !ProcessInfo.processInfo.arguments.contains("--computer-qa"), Self.perfIndex == 1 else { return }
        func tryReplay(_ left: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if self.replayIndex == nil && !self.presentationBusy && self.localTurn {
                    self.replayCamera = 0; self.replay()
                    if self.replayIndex != nil { self.perfBegin("replay"); return }
                }
                if left > 0 { tryReplay(left - 1) }
            }
        }
        tryReplay(20)
    }

    // MARK: 0.44-mm two-Simulator Wi‑Fi probe (MultipeerConnectivity between Simulators on one Mac).
    static var qaGuestRecordFrames = 0, qaGuestRecordsFinished = 0
    func writeQA(_ name: String, _ values: [String: Any]) {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("perf-qa")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent(name + ".json"), options: .atomic)
        } catch { NSLog("qa write failed: \(error)") }
    }
    /// Host: open room ZOKER_QA_ROOM, wait for the guest, break at 7 m/s, report. Guest: join, watch, report its lockstep.
    func startLANQA() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--lan-host-qa") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                self.startMatch(rule: "nineBall", network: true)
                func waitAndShoot(_ left: Int) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard let self = self else { return }
                        self.writeQA("lan-host", ["connected": self.matchPlay.session.isConnected, "room": self.matchPlay.session.roomCode,
                                                  "shotsStarted": self.frames.isEmpty ? 0 : 1, "waitingSeconds": 120 - left])
                        guard self.frames.isEmpty else { return }
                        if self.matchPlay.session.isConnected && left < 116 && !self.shotActive {   // 4 s for the first full sync
                            self.locked = true; self.shoot(7.0)
                            if self.shotActive { self.spin.collapse(); self.setHold(false) }
                        }
                        if left > 0 { waitAndShoot(left - 1) }
                    }
                }
                waitAndShoot(120)
            }
        }
        if args.contains("--lan-join-qa"), let code = ProcessInfo.processInfo.environment["ZOKER_QA_ROOM"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                self.prepareGuestMatch()
                _ = self.matchPlay.session.joinRoom(code: code)
                self.setMenu(false); self.syncMatchControls(); self.updateControls()
                func report(_ left: Int) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard let self = self else { return }
                        let m = self.matchPlay
                        self.writeQA("lan-guest", ["connected": m.session.isConnected, "lockstepShots": m.lockstepShots,
                                                   "verifiedChecks": m.predictorVerified, "fallbacks": m.lockstepFallbacks,
                                                   "predictorActive": m.predictor != nil, "recordsFinished": Self.qaGuestRecordsFinished,
                                                   "recordFrames": Self.qaGuestRecordFrames, "highlights": Self.highlights.count,
                                                   "lastGuestShot": m.lastGuestShot, "snapshots": m.snapshots.count])
                        if left > 0 { report(left - 1) }
                    }
                }
                report(150)
            }
        }
    }
}
