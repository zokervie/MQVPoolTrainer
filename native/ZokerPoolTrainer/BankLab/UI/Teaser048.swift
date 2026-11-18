import UIKit
import SceneKit
import AVFoundation

/// 0.48 M3 "Teaser 8 s": the Director cut shortened by the planner (style Teaser, ≤ 6.5 s of play) + a 1.5 s end card
/// (Zoker logo, the last challenge code from 0.47 M6) with the intro's sting (IntroMix0441, own synthesis) on the card.
/// Sound during play keeps the real event sounds at their real pitch and length (the exporter mixes each collision
/// sample at the video time it happens), so slow motion never stretches a click — like film.
enum Teaser048 {
    static let total = 8.0, card = 1.5
    static var playBudget: Double { total - card }
    static func cardStart(plannedWall: Double?) -> Double { min(playBudget, max(1, plannedWall ?? playBudget)) }
    static var lastFrame: UIImage?
    /// QA: exported files this run (UI test waits for it).
    static var qaExported = 0
    /// Offline render of the intro sting (layers: sound, gain, rate, at; master) to 48 kHz stereo float.
    static func musicBed(at time: Double) -> (buffer: AVAudioPCMBuffer, at: Double)? {
        guard UserDefaults.standard.object(forKey: "poolAudioEnabled") as? Bool ?? true,
              let sheet = NSDataAsset(name: "IntroMix0441").flatMap({ try? JSONSerialization.jsonObject(with: $0.data) as? [String: Any] }),
              let part = sheet["sting"] as? [String: Any], let layers = part["layers"] as? [[String: Any]],
              let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2) else { return nil }
        let master = Float((part["master"] as? Double) ?? 1), rate = 48_000.0
        var tracks: [(samples: [[Float]], step: Double, at: Double, gain: Float)] = []
        var length = 0
        for layer in layers {
            guard let name = layer["sound"] as? String, let data = NSDataAsset(name: name)?.data else { continue }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("teaser-" + name + ".wav")
            try? data.write(to: url)
            guard let file = try? AVAudioFile(forReading: url),
                  let b = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: b)) != nil, let ch = b.floatChannelData else { continue }
            let n = Int(b.frameLength), c = Int(b.format.channelCount)
            let samples = (0..<max(1, c)).map { k in Array(UnsafeBufferPointer(start: ch[min(k, c - 1)], count: n)) }
            let step = b.format.sampleRate * ((layer["rate"] as? Double) ?? 1) / rate
            let at = (layer["at"] as? Double) ?? 0
            tracks.append((samples, step, at, Float((layer["gain"] as? Double) ?? 1) * master))
            length = max(length, Int(at * rate) + Int(Double(n) / max(0.01, step)))
        }
        guard !tracks.isEmpty, length > 0, let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length)),
              let dst = out.floatChannelData else { return nil }
        out.frameLength = AVAudioFrameCount(length)
        for c in 0..<2 { for i in 0..<length { dst[c][i] = 0 } }
        for t in tracks {
            let start = Int(t.at * rate), n = t.samples[0].count
            for i in start..<length {
                let x = Double(i - start) * t.step; let k = Int(x); if k + 1 >= n { break }
                let f = Float(x - Double(k))
                for c in 0..<2 { let s = t.samples[min(c, t.samples.count - 1)]; dst[c][i] += (s[k] + (s[k + 1] - s[k]) * f) * t.gain }
            }
        }
        return (out, time)
    }
    /// End card: the last frame darkened, logo, app name and the challenge code (if one was issued this session).
    static func cardImage(size: CGSize, background: UIImage?, code: String?) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.rgb(0x0B0F12).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            background?.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: 0.35)
            let u = min(size.width, size.height) / 1080
            if let logo = UIImage(named: "ZokerLogo043") ?? UIImage(named: "LaunchLogo0441") {
                let side = 360 * u, aspect = logo.size.width / max(1, logo.size.height)
                let w = aspect >= 1 ? side : side * aspect, h = aspect >= 1 ? side / aspect : side
                logo.draw(in: CGRect(x: (size.width - w) / 2, y: size.height * 0.40 - h / 2, width: w, height: h))
            }
            func line(_ s: String, _ y: CGFloat, _ pt: CGFloat, _ colour: UIColor, _ weight: UIFont.Weight) {
                let p = NSMutableParagraphStyle(); p.alignment = .center
                (s as NSString).draw(in: CGRect(x: 0, y: y, width: size.width, height: pt * 1.5),
                                     withAttributes: [.font: UIFont.systemFont(ofSize: pt, weight: weight), .foregroundColor: colour, .paragraphStyle: p])
            }
            line("ZokerPoolTrainer", size.height * 0.40 + 210 * u, 54 * u, .white, .heavy)
            if let code = code {
                line(L10n.tr("Thách bạn") + ": " + ChallengeCode.pretty(code), size.height * 0.40 + 300 * u, 60 * u, ZDesign.Color.gold, .black)
                line(L10n.tr("Sảnh → Nhập mã thách đấu"), size.height * 0.40 + 390 * u, 32 * u, UIColor(white: 0.8, alpha: 1), .medium)
            }
        }
    }
}

extension TrainingController {
    /// Off-screen render of the scene view's camera at the export size (16:9 or 9:16), never the HUD.
    func renderExportFrame048(_ size: CGSize) -> UIImage {
        if exportRenderer048 == nil { let r = SCNRenderer(device: scn.device, options: nil); r.scene = scn.scene; exportRenderer048 = r }
        guard let r = exportRenderer048 else { return scn.snapshot() }
        r.pointOfView = scn.pointOfView
        let image = r.snapshot(atTime: CACurrentMediaTime(), with: size, antialiasingMode: .multisampling4X)
        Teaser048.lastFrame = image
        return image
    }
    func startTeaserClock048(_ plan: BLCameraPlan) {
        replayClock = max(-replayLead, plan.startTime)
        replayIndex = frameTimes.lastIndex(where: { $0 <= replayClock }) ?? 0
        replayAudioIndex = lastShotEvents.prefix(while: { ($0["time"]?.doubleValue ?? 0) <= replayClock }).count
        replayStrikePlayed = replayClock >= 0
    }
    func teaserReachedEnd048(_ export: ReplayVideoExport) -> Bool {
        if export.videoTime >= Teaser048.playBudget { return true }
        if let plan = cameraPlan048, replayClock >= plan.endTime { return true }
        return false
    }
    func appendTeaserCard048(_ export: ReplayVideoExport) {
        let size = export.fixedSize ?? export.size
        let card = Teaser048.cardImage(size: size, background: Teaser048.lastFrame, code: ChallengeCode.lastIssued)
        if let bed = export.music, export.videoTime + 0.05 < bed.at {   // the play part ended early: the sting starts with the card
            export.music = (bed.buffer, export.videoTime)
        }
        for _ in 0..<Int(Teaser048.card * Double(ReplayVideoExport.fps)) { guard export.append(card) else { break } }
        Teaser048.lastFrame = nil
    }
    /// "Ảnh thẻ": the best still (first contact or the drop) of the last shot, Director framing, 16:9 with the logo.
    func shareStillCard048(source: UIView?) {
        guard replayIndex == nil, !shotActive, !frames.isEmpty,
              let plan = CameraPlan048.make(frames: frames, times: frameTimes, events: lastShotEvents, aimAngle: lastShot?.aimAngle ?? angle,
                                            angle: .director, aspect: 16.0 / 9.0, lead: replayLead, tail: Self.replayTail) else {
            notifyStatus("Chưa có cú đánh để xuất video"); return
        }
        let t = max(0, min(plan.bestStillTime, frameTimes.last ?? 0))
        let i = frameTimes.lastIndex(where: { $0 <= t }) ?? 0, j = min(i + 1, frames.count - 1)
        let span = frameTimes[j] - frameTimes[i]
        table.replay(frames[i], to: frames[j], fraction: span > 0 ? (t - frameTimes[i]) / span : 0, span: span)
        var eye = simd_float3(), target = simd_float3(); var fov: Float = 40
        plan.pose(at: t, eye: &eye, target: &target, fov: &fov)
        let saved = table.actionCamera
        table.actionCamera = (eye, target, fov)
        table.placeCamera(cue: nil, angle: angle, aspect: 16.0 / 9.0)
        exportRenderer048 = nil
        let frame = renderExportFrame048(CGSize(width: 1920, height: 1080))
        exportRenderer048 = nil; Teaser048.lastFrame = nil
        table.actionCamera = saved; table.update(balls, dt: 0); wakeRendering()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1920, height: 1080), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }()).image { _ in
            frame.draw(in: CGRect(x: 0, y: 0, width: 1920, height: 1080))
            if let logo = UIImage(named: "ZokerLogo043") {
                let h: CGFloat = 120, w = h * logo.size.width / max(1, logo.size.height)
                logo.draw(in: CGRect(x: 1920 - w - 48, y: 1080 - h - 40, width: w, height: h), blendMode: .normal, alpha: 0.9)
            }
        }
        let share = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = source ?? view
        topPresenter.present(share, animated: true)
    }
}
