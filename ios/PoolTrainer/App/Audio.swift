import AVFoundation
import UIKit

/// Âm thanh tổng hợp (không cần file âm thanh) – tiếng nhiễu lọc qua biquad giống bản WebAudio, cộng rung phản hồi.
final class SoundFX {
    static let shared = SoundFX()
    var enabled = true
    var haptics = true

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private let format: AVAudioFormat
    private var started = false
    private let rate: Double
    private var lastPlay = [String: CFTimeInterval]()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        rate = 44100
        format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        for _ in 0..<10 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
    }

    private func start() {
        if started && engine.isRunning { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            players.forEach { $0.play() }
            started = true
        } catch { started = false }
    }

    enum Filter { case bandpass, lowpass }

    /// Nhiễu trắng tắt dần theo hàm mũ, qua bộ lọc biquad (RBJ).
    private func burst(freq: Double, q: Double, dur: Double, gain: Double, filter: Filter = .bandpass, decay: Double, key: String) {
        guard enabled else { return }
        let now = CACurrentMediaTime()
        if let t = lastPlay[key], now - t < 0.012 { return }   // tránh dồn tiếng khi va liên tục
        lastPlay[key] = now
        start()
        guard started else { return }
        let n = AVAudioFrameCount(rate * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n), let ch = buf.floatChannelData?[0] else { return }
        buf.frameLength = n
        let w0 = 2 * Double.pi * freq / rate, alpha = sin(w0) / (2 * q), cw = cos(w0)
        var b0: Double, b1: Double, b2: Double
        let a0 = 1 + alpha, a1 = -2 * cw, a2 = 1 - alpha
        switch filter {
        case .bandpass: b0 = alpha; b1 = 0; b2 = -alpha
        case .lowpass: b0 = (1 - cw) / 2; b1 = 1 - cw; b2 = (1 - cw) / 2
        }
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        for i in 0..<Int(n) {
            let x = Double.random(in: -1...1) * exp(-Double(i) / (rate * decay))
            let y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
            x2 = x1; x1 = x; y2 = y1; y1 = y
            ch[i] = Float(max(-1, min(1, y * gain * 2.2)))
        }
        let p = players[next]; next = (next + 1) % players.count
        p.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        if !p.isPlaying { p.play() }
    }

    func ball(_ speed: Double) {
        let v = min(1, speed / 4)
        guard v > 0.02 else { return }
        burst(freq: 2600 + v * 1800, q: 6, dur: 0.06, gain: 0.15 + v * 0.7, decay: 0.008, key: "ball")
        if haptics && v > 0.15 { impactRigid.impactOccurred(intensity: CGFloat(min(1, 0.3 + v))) }
    }
    func cushion(_ speed: Double) {
        let v = min(1, speed / 4)
        guard v > 0.03 else { return }
        burst(freq: 260, q: 1.2, dur: 0.09, gain: 0.25 + v * 0.6, filter: .lowpass, decay: 0.02, key: "cush")
        if haptics && v > 0.3 { impactLight.impactOccurred(intensity: CGFloat(v)) }
    }
    func cue(_ power: Double) {
        burst(freq: 1500, q: 3, dur: 0.05, gain: 0.25 + power * 0.6, decay: 0.006, key: "cue")
        if haptics { impactHeavy.impactOccurred(intensity: CGFloat(0.35 + 0.65 * power)) }
    }
    func pocket() {
        burst(freq: 180, q: 1, dur: 0.25, gain: 0.7, filter: .lowpass, decay: 0.06, key: "pocket")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { self.burst(freq: 900, q: 4, dur: 0.06, gain: 0.25, decay: 0.01, key: "pocket2") }
        if haptics { impactRigid.impactOccurred(intensity: 0.8) }
    }
    func ok() {
        if haptics { notify.notificationOccurred(.success) }
        guard enabled else { return }
        start()
        guard started else { return }
        for (i, f) in [660.0, 880.0].enumerated() {
            let n = AVAudioFrameCount(rate * 0.3)
            guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n), let ch = buf.floatChannelData?[0] else { continue }
            buf.frameLength = n
            for k in 0..<Int(n) {
                let t = Double(k) / rate
                let env = t < 0.02 ? t / 0.02 : exp(-(t - 0.02) * 14)
                ch[k] = Float(sin(2 * .pi * f * t) * env * 0.18)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.09) {
                let p = self.players[self.next]; self.next = (self.next + 1) % self.players.count
                p.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
                if !p.isPlaying { p.play() }
            }
        }
    }
    func fail() { if haptics { notify.notificationOccurred(.error) } }
    func tick() { if haptics { impactLight.impactOccurred(intensity: 0.4) } }
}
