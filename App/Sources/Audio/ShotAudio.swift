import AVFoundation
import QuartzCore
import PoolPhysics
import PoolAudio

/// Phát âm thanh cú đánh bằng AVAudioEngine (Zoker Acoustic Physics, bậc A).
/// Cả cú đánh được dựng sẵn thành một buffer bằng `OfflineRenderer` (lịch phát xác định,
/// có limiter), rồi phát bằng một player node tại đúng thời điểm máy — khớp với timeline hình ảnh.
@MainActor
final class ShotAudio {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var configured = false
    let library = SampleLibrary.placeholder()
    let scheduler = AudioScheduler()

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        let session = AVAudioSession.sharedInstance()
        // .ambient: tôn trọng công tắc im lặng, không ngắt nhạc của người dùng.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try? engine.start()
        configured = true
    }

    /// Dựng âm thanh cho một cú (chạy nền), trả về mẫu xen kẽ L/R.
    nonisolated static func render(records: [CollisionRecord], shotId: UInt64, listener: ListenerPose,
                                   rate: Double, spatial: Bool, headphones: Bool,
                                   scheduler: AudioScheduler) -> OfflineRenderer.Output {
        let events = AudioEventBuilder.events(from: records, shotId: shotId)
        let voices = scheduler.schedule(events, listener: listener, rate: rate, spatial: spatial)
        var renderer = OfflineRenderer()
        renderer.headphoneMode = headphones
        return renderer.render(voices) { PlaceholderSynth.render($0) }
    }

    /// Phát buffer đã dựng, bắt đầu tại `hostStart` (giây, cùng đồng hồ với CACurrentMediaTime).
    func play(_ output: OfflineRenderer.Output, at hostStart: CFTimeInterval, volume: Double) {
        configureIfNeeded()
        guard engine.isRunning, output.frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(output.frames)),
              let channels = buffer.floatChannelData else { return }
        buffer.frameLength = AVAudioFrameCount(output.frames)
        for i in 0..<output.frames {
            channels[0][i] = output.interleaved[2 * i]
            channels[1][i] = output.interleaved[2 * i + 1]
        }
        engine.mainMixerNode.outputVolume = Float(volume)
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        let delay = max(0, hostStart - CACurrentMediaTime())
        let when = AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delay))
        player.play(at: when)
    }

    func stop() {
        if configured { player.stop() }
    }
}
