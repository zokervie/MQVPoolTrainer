import UIKit
import SceneKit
import AVFoundation
import Photos

/// 0.44 (owner item 17: "xuất file video cú đánh hay để flexing / đăng YouTube, Facebook, TikTok").
///
/// Not a screen recording: the replay is re-played OFFLINE — the display link is paused and the controller's own frame
/// step is driven with a fixed 1/60 s clock, each frame rendered by the SceneKit view itself (`snapshot`, full native
/// resolution, never the HUD). So the file is a steady 60 fps whatever the device managed live, at the screen's aspect,
/// long side 1920 px, H.264 High + AAC 48 kHz stereo (the same recordings as the game, mixed offline). Option: the
/// stroke card (power on the 7-colour scale, tip contact, cue, elevation) burnt into the top-right corner.
final class ReplayVideoExport {
    let includeInfo: Bool
    let url: URL
    private(set) var frame = 0
    private var sounds: [(time: Double, kind: Int, impact: Double, pan: Double)] = []
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private(set) var size = CGSize(width: 1920, height: 1080)
    var info: (speed: Double, side: Double, top: Double, elevation: Double, cue: String)?
    var cancelled = false
    /// 0.48 M3: fixed output frame (1920×1080 or 1080×1920), rendered off-screen at that size (not the screen's aspect).
    var fixedSize: CGSize?
    /// 0.48 M3 teaser: music bed (48 kHz stereo float) mixed in at `at` seconds of the video.
    var music: (buffer: AVAudioPCMBuffer, at: Double)?
    static let fps: Int32 = 60
    static let maxSeconds = 40.0

    init(includeInfo: Bool) {
        self.includeInfo = includeInfo
        url = FileManager.default.temporaryDirectory.appendingPathComponent("ZokerPool-shot-\(Int(Date().timeIntervalSince1970))-video.mp4")
    }
    var videoTime: Double { Double(frame) / Double(Self.fps) }
    func sound(kind: Int, impact: Double, pan: Double) { sounds.append((videoTime, kind, impact, pan)) }

    private func open(for image: UIImage) -> Bool {
        if let fixed = fixedSize { size = fixed } else {
            let px = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
            let scale = min(1, 1920 / max(px.width, px.height))
            size = CGSize(width: (px.width * scale / 2).rounded() * 2, height: (px.height * scale / 2).rounded() * 2)
        }
        try? FileManager.default.removeItem(at: url)
        guard let w = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return false }
        let bitrate = Int(size.width * size.height * 60 * 0.13)   // ≈ 16 Mbit/s at 1080p60
        let i = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                              AVVideoMaxKeyFrameIntervalKey: 60, AVVideoExpectedSourceFrameRateKey: 60]])
        i.expectsMediaDataInRealTime = false
        let a = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: i, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height)])
        guard w.canAdd(i) else { return false }
        w.add(i); guard w.startWriting() else { return false }
        w.startSession(atSourceTime: .zero)
        writer = w; input = i; adaptor = a
        return true
    }
    /// Appends one rendered frame (+ optional stroke card). Returns false when the writer failed.
    func append(_ image: UIImage) -> Bool {
        if writer == nil && !open(for: image) { return false }
        guard let input = input, let adaptor = adaptor, let cg = image.cgImage else { return false }
        var waited = 0
        while !input.isReadyForMoreMediaData && waited < 400 { Thread.sleep(forTimeInterval: 0.002); waited += 1 }
        guard input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return false }
        var buffer: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer); guard let pb = buffer else { return false }
        CVPixelBufferLockBaseAddress(pb, [])
        if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                               bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
            ctx.interpolationQuality = .high
            // Aspect-fill (0.48: the off-screen render already has the output's aspect, so this is a plain copy).
            let iw = CGFloat(cg.width), ih = CGFloat(cg.height), k = max(size.width / max(1, iw), size.height / max(1, ih))
            ctx.draw(cg, in: CGRect(x: (size.width - iw * k) / 2, y: (size.height - ih * k) / 2, width: iw * k, height: ih * k))
            if includeInfo, let info = info, videoTime >= 0.2 { drawCard(ctx, info) }
        }
        CVPixelBufferUnlockBaseAddress(pb, [])
        let ok = adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: Self.fps))
        frame += 1
        return ok
    }
    /// The stroke card in CoreGraphics (y up): 7-colour power bar with needle, numbers, effect ball with the tip contact.
    private func drawCard(_ ctx: CGContext, _ info: (speed: Double, side: Double, top: Double, elevation: Double, cue: String)) {
        let u = size.height / 1080, w = 420 * u, h = 118 * u
        let box = CGRect(x: size.width - w - 36 * u, y: size.height - h - 36 * u, width: w, height: h)
        ctx.saveGState()
        ctx.setFillColor(UIColor(white: 0.02, alpha: 0.62).cgColor)
        ctx.addPath(UIBezierPath(roundedRect: box, cornerRadius: 18 * u).cgPath); ctx.fillPath()
        let t = max(0, min(1, info.speed / 8))
        let bar = CGRect(x: box.minX + 24 * u, y: box.minY + 30 * u, width: w - 150 * u, height: 12 * u)
        let colours = (0...6).map { PowerFX.color(Double($0) / 6).cgColor } as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: nil) {
            ctx.saveGState(); ctx.addPath(UIBezierPath(roundedRect: bar, cornerRadius: 6 * u).cgPath); ctx.clip()
            ctx.drawLinearGradient(gradient, start: CGPoint(x: bar.minX, y: bar.midY), end: CGPoint(x: bar.maxX, y: bar.midY), options: [])
            ctx.restoreGState()
        }
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(x: bar.minX + bar.width * CGFloat(t) - 2.5 * u, y: bar.minY - 7 * u, width: 5 * u, height: bar.height + 14 * u))
        // text (UIKit draws y-down: flip locally)
        let text = String(format: "%.1f m/s  ·  %@  ·  %lld°", info.speed, info.cue, Int(info.elevation.rounded()))
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: 30 * u, weight: .heavy),
                                                         .foregroundColor: PowerFX.color(t)]
        UIGraphicsPushContext(ctx)
        ctx.saveGState(); ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: 1, y: -1)
        (text as NSString).draw(at: CGPoint(x: box.minX + 24 * u, y: size.height - box.maxY + 18 * u), withAttributes: attributes)
        ctx.restoreGState()
        UIGraphicsPopContext()
        // effect ball
        let r = 40 * u, centre = CGPoint(x: box.maxX - 24 * u - r, y: box.midY)
        ctx.setFillColor(UIColor(white: 0.96, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r))
        ctx.setStrokeColor(UIColor(white: 0.55, alpha: 1).cgColor); ctx.setLineWidth(1.5 * u)
        ctx.strokeLineSegments(between: [CGPoint(x: centre.x - r, y: centre.y), CGPoint(x: centre.x + r, y: centre.y),
                                         CGPoint(x: centre.x, y: centre.y - r), CGPoint(x: centre.x, y: centre.y + r)])
        let dot = CGPoint(x: centre.x + CGFloat(info.side) * r, y: centre.y + CGFloat(info.top) * r)
        ctx.setFillColor(UIColor.rgb(0xE23B3B).cgColor)
        ctx.fillEllipse(in: CGRect(x: dot.x - 7 * u, y: dot.y - 7 * u, width: 14 * u, height: 14 * u))
        ctx.restoreGState()
    }
    /// Closes the video, mixes the audio and muxes both into the final MP4 (H.264 passthrough + AAC 48 kHz).
    func finish(audio: PoolAudio, done: @escaping (URL?) -> Void) {
        guard let writer = writer, let input = input, frame > 0 else { done(nil); return }
        input.markAsFinished()
        let duration = videoTime, events = sounds, videoURL = url, music = self.music
        writer.finishWriting {
            guard writer.status == .completed else { DispatchQueue.main.async { done(nil) }; return }
            DispatchQueue.global(qos: .userInitiated).async {
                let audioURL = videoURL.deletingPathExtension().appendingPathExtension("m4a")
                try? FileManager.default.removeItem(at: audioURL)
                var haveAudio = false
                if let mix = audio.offlineMix(events, duration: duration + 0.5).map({ ReplayVideoExport.addMusic(music, to: $0) }),
                   let file = try? AVAudioFile(forWriting: audioURL, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000,
                                                                                 AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192_000],
                                               commonFormat: .pcmFormatFloat32, interleaved: false) {
                    haveAudio = (try? file.write(from: mix)) != nil
                }
                guard haveAudio else { DispatchQueue.main.async { done(videoURL) }; return }
                let output = videoURL.deletingLastPathComponent().appendingPathComponent(videoURL.lastPathComponent.replacingOccurrences(of: "-video", with: ""))
                try? FileManager.default.removeItem(at: output)
                let composition = AVMutableComposition()
                let video = AVURLAsset(url: videoURL), sound = AVURLAsset(url: audioURL)
                let range = CMTimeRange(start: .zero, duration: video.duration)
                if let source = video.tracks(withMediaType: .video).first,
                   let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try? track.insertTimeRange(range, of: source, at: .zero)
                }
                if let source = sound.tracks(withMediaType: .audio).first,
                   let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try? track.insertTimeRange(CMTimeRange(start: .zero, duration: min(range.duration, sound.duration)), of: source, at: .zero)
                }
                guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
                    DispatchQueue.main.async { done(videoURL) }; return
                }
                session.outputURL = output; session.outputFileType = .mp4; session.shouldOptimizeForNetworkUse = true
                session.exportAsynchronously {
                    let ok = session.status == .completed
                    if ok { try? FileManager.default.removeItem(at: videoURL) }
                    try? FileManager.default.removeItem(at: audioURL)
                    DispatchQueue.main.async { done(ok ? output : videoURL) }
                }
            }
        }
    }
    /// 0.48 M3: adds the teaser's music bed (same sample rate expected; other rates are resampled linearly).
    static func addMusic(_ music: (buffer: AVAudioPCMBuffer, at: Double)?, to mix: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let music = music, let src = music.buffer.floatChannelData, let dst = mix.floatChannelData else { return mix }
        let ratio = music.buffer.format.sampleRate / mix.format.sampleRate
        let start = Int(max(0, music.at) * mix.format.sampleRate), n = Int(mix.frameLength), m = Int(music.buffer.frameLength)
        let srcChannels = Int(music.buffer.format.channelCount), dstChannels = Int(mix.format.channelCount)
        guard m > 1, srcChannels > 0 else { return mix }
        for i in start..<n {
            let x = Double(i - start) * ratio; let k = Int(x); if k + 1 >= m { break }
            let f = Float(x - Double(k))
            for c in 0..<dstChannels {
                let s = src[min(c, srcChannels - 1)]
                dst[c][i] = max(-1, min(1, dst[c][i] + s[k] + (s[k + 1] - s[k]) * f))
            }
        }
        return mix
    }
    func discard() {
        input?.markAsFinished(); writer?.cancelWriting(); try? FileManager.default.removeItem(at: url)
    }
}

extension TrainingController {
    /// Replay bar "Video" / Menu → "Xuất video cú vừa rồi": choose plain or with the stroke card.
    func offerVideoExport(source: UIView?) {
        guard videoExport == nil, !shotActive, !frames.isEmpty else { notifyStatus("Chưa có cú đánh để xuất video"); return }
        let sheet = UIAlertController(title: L10n.tr("Xuất video cú đánh"),
                                      message: L10n.tr("MP4 · 60 khung/giây · góc máy") + ": " + replayAngle048.title + ". " + L10n.tr("Không có phím trên video."),
                                      preferredStyle: .actionSheet)
        // 0.48 M3: 16:9 (YouTube) or 9:16 (TikTok/Reels/Shorts) — the camera re-plans its framing for the portrait frame.
        sheet.addAction(UIAlertAction(title: L10n.tr("Video ngang 16:9"), style: .default) { [weak self] _ in self?.startVideoExport(includeInfo: false) })
        sheet.addAction(UIAlertAction(title: L10n.tr("Video dọc 9:16 (TikTok, Reels, Shorts)"), style: .default) { [weak self] _ in self?.startVideoExport(includeInfo: false, portrait: true) })
        sheet.addAction(UIAlertAction(title: L10n.tr("Teaser 8 giây · dọc 9:16"), style: .default) { [weak self] _ in self?.startVideoExport(includeInfo: false, portrait: true, teaser: true) })
        sheet.addAction(UIAlertAction(title: L10n.tr("Teaser 8 giây · ngang 16:9"), style: .default) { [weak self] _ in self?.startVideoExport(includeInfo: false, teaser: true) })
        sheet.addAction(UIAlertAction(title: L10n.tr("Video ngang + thông số cú đánh"), style: .default) { [weak self] _ in self?.startVideoExport(includeInfo: true) })
        sheet.addAction(UIAlertAction(title: L10n.tr("Ảnh thẻ (khung đẹp nhất)"), style: .default) { [weak self] _ in self?.shareStillCard048(source: source) })
        sheet.addAction(UIAlertAction(title: L10n.tr("Huỷ"), style: .cancel))
        presentSheet(sheet, source: source)
    }
    private static var exportOverlay: UIView?
    func startVideoExport(includeInfo: Bool, portrait: Bool = false, teaser: Bool = false) {
        guard videoExport == nil, !shotActive, !frames.isEmpty else { return }
        if replayIndex != nil { stopReplay() }
        let export = ReplayVideoExport(includeInfo: includeInfo)
        export.fixedSize = portrait ? CGSize(width: 1080, height: 1920) : CGSize(width: 1920, height: 1080)
        teaserExport048 = teaser; exportRenderer048 = nil
        if teaser { export.music = Teaser048.musicBed(at: Teaser048.cardStart(plannedWall: nil)) }
        if let shot = lastShot {
            let cue = shot.cueType == 1 ? "Jump" : (shot.cueType == 2 ? "Break" : (shot.elevation > 35 ? "Massé" : L10n.tr("Đánh")))
            export.info = (shot.speed, shot.side, shot.top, shot.elevation, cue)
        }
        videoExport = export
        replay()
        guard replayIndex != nil else {   // review 0.48 #9: the replay could not open — no file
            videoExport = nil; teaserExport048 = false; notifyStatus("Không tạo được video"); return
        }
        if teaser, let plan = cameraPlan048 { startTeaserClock048(plan) }
        replayBar.isHidden = true; menuButton.isHidden = true
        displayLink?.isPaused = true
        // progress overlay (UIKit, never in the video)
        let overlay = UIView(frame: view.bounds); overlay.backgroundColor = UIColor(white: 0, alpha: 0.35)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]; overlay.accessibilityIdentifier = "VideoExportProgress"
        let label = UILabel(); label.tag = 1; label.textColor = .white; label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center; label.text = "Đang xuất video… 0%"
        let cancel = UIButton(type: .system); cancel.setTitle("Huỷ", for: .normal); cancel.tintColor = .rgb(0xEAC583)
        cancel.addAction(UIAction { [weak self] _ in self?.videoExport?.cancelled = true }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [label, cancel]); stack.axis = .vertical; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false; overlay.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor), stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)])
        view.addSubview(overlay); Self.exportOverlay = overlay
        // After replay()'s own async camera choice (FIFO main queue), so frame 0 already uses the chosen angle.
        let start = ProcessInfo.processInfo.systemUptime
        lastTime = start
        DispatchQueue.main.async { [weak self] in self?.exportVideoFrames(clock: start) }
    }
    /// Renders a batch of frames, then yields to the run loop so the progress label updates.
    private func exportVideoFrames(clock: Double) {
        guard let export = videoExport else { return }
        var virtual = clock
        let total = (frameTimes.last ?? 1) + Self.replayTail + replayLead
        for _ in 0..<6 {
            if export.cancelled || replayIndex == nil || export.videoTime > ReplayVideoExport.maxSeconds * 3 { break }
            virtual += 1.0 / Double(ReplayVideoExport.fps)
            frameStep(targetTimestamp: virtual, linkStamp: virtual)
            if replayIndex == nil { break }   // the step reached the end and closed the replay
            guard export.append(renderExportFrame048(export.fixedSize ?? export.size)) else { export.cancelled = true; break }
            if teaserExport048, teaserReachedEnd048(export) { stopReplay(); break }
        }
        let percent = Int(min(99, export.videoTime / max(0.1, total * 1.6) * 100))
        (Self.exportOverlay?.subviews.first?.subviews.first as? UILabel)?.text = "Đang xuất video… \(percent)%"
        if replayIndex == nil, !export.cancelled, export.videoTime < ReplayVideoExport.maxSeconds * 3, loadNextHighlight() {
            replay(); replayBar.isHidden = true; menuButton.isHidden = true   // highlight reel: next shot, same file
            DispatchQueue.main.async { [weak self] in self?.exportVideoFrames(clock: virtual) }
            return
        }
        if export.cancelled || replayIndex == nil || export.videoTime > ReplayVideoExport.maxSeconds * (Self.highlightQueue.isEmpty ? 1 : 3) {
            Self.highlightQueue = []
            finishVideoExport(); return
        }
        DispatchQueue.main.async { [weak self] in self?.exportVideoFrames(clock: virtual) }
    }
    private func finishVideoExport() {
        guard let export = videoExport else { return }
        if replayIndex != nil { stopReplay() }
        if teaserExport048, !export.cancelled { appendTeaserCard048(export) }
        teaserExport048 = false; exportRenderer048 = nil; Teaser048.lastFrame = nil
        videoExport = nil
        lastTime = 0; displayLink?.isPaused = false; wakeRendering()
        if export.cancelled {
            export.discard(); Self.exportOverlay?.removeFromSuperview(); Self.exportOverlay = nil
            notifyStatus("Đã huỷ xuất video"); return
        }
        (Self.exportOverlay?.subviews.first?.subviews.first as? UILabel)?.text = "Đang hoàn tất video…"
        export.finish(audio: poolAudio) { [weak self] url in
            Self.exportOverlay?.removeFromSuperview(); Self.exportOverlay = nil
            guard let self = self else { return }
            guard let url = url else { self.notifyStatus("Không tạo được video"); return }
            Teaser048.qaExported += 1
            self.presentExportedVideo(url)
        }
    }
    private func presentExportedVideo(_ url: URL) {
        let sheet = UIAlertController(title: "Video đã sẵn sàng", message: "MP4 · 60 khung/giây · có âm thanh.", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Lưu vào Ảnh", style: .default) { [weak self] _ in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    DispatchQueue.main.async { self?.notifyStatus("Chưa cho phép lưu vào Ảnh (Cài đặt → Quyền riêng tư → Ảnh)") }; return
                }
                PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }) { ok, _ in
                    DispatchQueue.main.async { self?.notifyStatus(ok ? "Đã lưu video vào Ảnh" : "Không lưu được video") }
                }
            }
        })
        sheet.addAction(UIAlertAction(title: "Chia sẻ… (TikTok, Facebook, YouTube…)", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            share.popoverPresentationController?.sourceView = self.menuButton
            self.present(share, animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        presentSheet(sheet, source: menuButton)
    }
}
