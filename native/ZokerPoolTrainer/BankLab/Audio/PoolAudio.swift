import Foundation
import UIKit
import AVFoundation

/// Preloaded recordings, scheduled on continuously running voices.
/// Source/licence/hash: Tools/AudioSources/manifest.json. The original assets stay
/// unchanged; decoding removes pre-impact room noise and shortens long room tails.
/// Hardware/Bluetooth output latency still needs measurement on the actual route.
final class PoolAudio {
    private struct Sample {
        let buffer: AVAudioPCMBuffer
        let removedOnset: Double
        let duration: Double
    }
    private struct Voice {
        let node: AVAudioPlayerNode
        var busy = false
        var token: UInt64 = 0
        var level: Float = 0
    }
    private struct Policy {
        let name: String
        let maximumDuration: Double
        let trimOnset: Bool
    }
    private static let policies: [[Policy]] = [
        [Policy(name: "PoolRail0", maximumDuration: 0.160, trimOnset: true)],
        [Policy(name: "PoolBall0", maximumDuration: 0.160, trimOnset: true),
         Policy(name: "PoolBall1", maximumDuration: 0.220, trimOnset: true),
         Policy(name: "PoolBall2", maximumDuration: 0.220, trimOnset: true),
         Policy(name: "PoolBall3", maximumDuration: 0.220, trimOnset: true)],
        [Policy(name: "PoolPocket0", maximumDuration: 0.400, trimOnset: false)],
        [Policy(name: "PoolCue0", maximumDuration: 0.140, trimOnset: true)]
    ]
    private let audioQueue = DispatchQueue(label: "com.ztrainer.pool-audio", qos: .userInteractive)
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
    private var engine = AVAudioEngine()
    private var voices: [Voice] = []
    private var groups: [[Sample]] = []
    private var variation = 0
    private var graphGeneration: UInt64 = 0
    private var scheduledCount = 0
    private var droppedCount = 0
    private var stolenCount = 0
    private var engineStarted = false
    private var canPlay = true
    private var interrupted = false
    private var restartPending = false
    private var observers: [NSObjectProtocol] = []
    private let requestedBufferDuration = 256.0 / 48_000.0

    var sampleCount: Int { read { groups.reduce(0) { $0 + $1.count } } }
    var scheduled: Int { read { scheduledCount } }
    var started: Bool { read { engineStarted } }
    var isRunning: Bool { read { engine.isRunning } }
    var droppedEvents: Int { read { droppedCount } }
    var stolenVoices: Int { read { stolenCount } }
    /// Session-reported route latency is diagnostic evidence, not an acoustic test.
    var estimatedOutputLatency: Double {
        read {
            let session = AVAudioSession.sharedInstance()
            return session.outputLatency + session.ioBufferDuration
        }
    }
    var diagnostics: [String: Double] {
        read {
            let session = AVAudioSession.sharedInstance()
            return ["requestedBufferMs": requestedBufferDuration * 1000,
                    "actualBufferMs": session.ioBufferDuration * 1000,
                    "outputLatencyMs": session.outputLatency * 1000,
                    "sampleRate": session.sampleRate,
                    "maximumRemovedOnsetMs": (groups.flatMap { $0 }.map { $0.removedOnset }.max() ?? 0) * 1000,
                    "maximumClipMs": (groups.flatMap { $0 }.map { $0.duration }.max() ?? 0) * 1000,
                    "scheduled": Double(scheduledCount), "dropped": Double(droppedCount),
                    "stolenVoices": Double(stolenCount)]
        }
    }

    init() {
        audioQueue.setSpecific(key: queueKey, value: 1)
        audioQueue.sync {
            groups = Self.policies.map { policies in
                policies.compactMap { policy in
                    guard let data = NSDataAsset(name: policy.name)?.data else {
                        NSLog("PoolAudio: missing recorded asset %@", policy.name)
                        return nil
                    }
                    do { return try Self.decode(data, policy: policy, format: format) }
                    catch {
                        NSLog("PoolAudio: invalid asset %@: %@", policy.name, String(describing: error))
                        return nil
                    }
                }
            }
            buildGraph()
            start()
        }
        observe(AVAudioSession.interruptionNotification) { audio, note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if raw == AVAudioSession.InterruptionType.began.rawValue {
                audio.interrupted = true
                audio.suspend()
            } else if raw == AVAudioSession.InterruptionType.ended.rawValue {
                audio.interrupted = false
                audio.start()
            }
        }
        observe(AVAudioSession.routeChangeNotification) { audio, _ in audio.restartSoon() }
        observe(AVAudioSession.mediaServicesWereResetNotification) { audio, _ in
            audio.buildGraph()
            audio.start()
        }
        observe(.AVAudioEngineConfigurationChange) { audio, note in
            guard let source = note.object as? AVAudioEngine, source === audio.engine else { return }
            audio.restartSoon()
        }
        observe(UIApplication.didEnterBackgroundNotification) { audio, _ in
            audio.canPlay = false
            audio.suspend()
        }
        observe(UIApplication.didBecomeActiveNotification) { audio, _ in
            audio.canPlay = true
            audio.start()
        }
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        read {
            for voice in voices { voice.node.stop() }
            engine.stop()
        }
    }

    /// eventAge is optional so existing callers remain source-compatible. An old
    /// catch-up burst is dropped rather than producing impacts long after contact.
    func play(kind: Int, impact: Double, pan: Double, eventAge: Double = 0) {
        guard (0...3).contains(kind), impact.isFinite, pan.isFinite, eventAge.isFinite, impact > 0 else { return }
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            guard eventAge <= 0.120, self.canPlay, !self.interrupted else { self.droppedCount += 1; return }
            if !self.engine.isRunning { self.start() }
            guard self.engine.isRunning else { self.droppedCount += 1; return }
            let type = max(0, min(3, kind))
            guard self.groups.indices.contains(type), !self.groups[type].isEmpty else { return }
            let samples = self.groups[type]
            let sample = samples[self.variation % samples.count]
            self.variation = (self.variation + 1) % 1_000_000
            let kindGain = type == 0 ? 0.82 : (type == 2 ? 0.78 : (type == 3 ? 0.86 : 1.0))
            let level = Float(min(0.88, pow(max(0.005, min(1, impact / 3.2)), 0.65) * kindGain))
            let index: Int
            if let free = self.voices.firstIndex(where: { !$0.busy }) {
                index = free
            } else if let quietest = self.voices.indices.min(by: { self.voices[$0].level < self.voices[$1].level }) {
                // Only saturation steals a tail. Normal impacts never stop/play a
                // node and never queue behind a preceding recording on that voice.
                guard level >= self.voices[quietest].level * 0.8 else { self.droppedCount += 1; return }
                index = quietest
                self.voices[index].node.stop()
                self.voices[index].node.play()
                self.stolenCount += 1
            } else { return }
            self.voices[index].token &+= 1
            let token = self.voices[index].token
            let generation = self.graphGeneration
            self.voices[index].busy = true
            self.voices[index].level = level
            // Bound the sum of voice gains instead of clipping a dense break.
            // Existing tails only duck; they are never boosted when another ends.
            let sum = self.voices.reduce(Float(0)) { $0 + ($1.busy ? $1.level : 0) }
            let headroom = min(Float(1), 0.88 / max(0.001, sum))
            for i in self.voices.indices where self.voices[i].busy {
                self.voices[i].level *= headroom
                self.voices[i].node.volume = self.voices[i].level
            }
            let node = self.voices[index].node
            node.pan = Float(max(-1, min(1, pan)))
            // Keep the voice reserved through playback. dataConsumed can fire
            // before the route has rendered the tail, making a subsequent
            // impact queue behind it instead of sounding immediately.
            node.scheduleBuffer(sample.buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                self?.audioQueue.async { [weak self] in
                    guard let self = self, generation == self.graphGeneration,
                          self.voices.indices.contains(index), self.voices[index].token == token else { return }
                    self.voices[index].busy = false
                    self.voices[index].level = 0
                }
            }
            self.scheduledCount += 1
        }
    }

    private func read<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) == 1 { return work() }
        return audioQueue.sync(execute: work)
    }
    private func observe(_ name: Notification.Name, action: @escaping (PoolAudio, Notification) -> Void) {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            self?.audioQueue.async { [weak self] in
                guard let self = self else { return }
                action(self, note)
            }
        })
    }
    private func buildGraph() {
        graphGeneration &+= 1
        for voice in voices { voice.node.stop() }
        engine.stop()
        engine = AVAudioEngine()
        voices.removeAll(keepingCapacity: true)
        for _ in 0..<16 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            voices.append(Voice(node: node))
        }
        engine.mainMixerNode.outputVolume = 1
        engine.prepare()
        engineStarted = false
    }
    private func suspend() {
        for i in voices.indices {
            voices[i].token &+= 1
            voices[i].busy = false
            voices[i].level = 0
            voices[i].node.stop()
        }
        engine.pause()
        engineStarted = false
    }
    private func start() {
        guard canPlay, !interrupted else { return }
        if engine.isRunning {
            for voice in voices where !voice.node.isPlaying { voice.node.play() }
            engineStarted = true
            return
        }
        do {
            // An external engine/route stop must not replay an old scheduled tail
            // when audio resumes. This is a lifecycle reset, never a normal hit.
            for i in voices.indices {
                voices[i].token &+= 1
                voices[i].busy = false
                voices[i].level = 0
                voices[i].node.stop()
            }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(48_000)
            try session.setPreferredIOBufferDuration(requestedBufferDuration)
            try session.setActive(true)
            engine.prepare()
            try engine.start()
            for voice in voices { voice.node.play() }
            engineStarted = true
        } catch {
            engineStarted = false
            NSLog("PoolAudio: engine unavailable: %@", String(describing: error))
        }
    }
    private func restartSoon() {
        guard !restartPending else { return }
        restartPending = true
        audioQueue.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self = self else { return }
            self.restartPending = false
            self.suspend()
            self.start()
        }
    }

    private enum DecodeError: Error { case invalidWAV, unsupportedPCM, emptyPCM }
    private static func decode(_ data: Data, policy: Policy, format: AVAudioFormat) throws -> Sample {
        func text(_ start: Int, _ count: Int) -> String {
            String(data: data.subdata(in: start..<(start + count)), encoding: .ascii) ?? ""
        }
        func u16(_ index: Int) -> Int { Int(data[index]) | (Int(data[index + 1]) << 8) }
        func u32(_ index: Int) -> Int { u16(index) | (u16(index + 2) << 16) }
        guard data.count >= 12, text(0, 4) == "RIFF", text(8, 4) == "WAVE", u32(4) <= data.count - 8 else { throw DecodeError.invalidWAV }
        var cursor = 12, pcmStart = 0, pcmBytes = 0, sourceRate = 0
        while cursor + 8 <= data.count {
            let size = u32(cursor + 4), begin = cursor + 8
            guard size >= 0, begin <= data.count, size <= data.count - begin else { throw DecodeError.invalidWAV }
            let kind = text(cursor, 4)
            if kind == "fmt " {
                guard size >= 16, u16(begin) == 1, u16(begin + 2) == 1, u16(begin + 14) == 16 else { throw DecodeError.unsupportedPCM }
                sourceRate = u32(begin + 4)
            } else if kind == "data" { pcmStart = begin; pcmBytes = size }
            cursor = begin + size + (size & 1)
        }
        guard sourceRate >= 8_000, sourceRate <= 192_000, pcmBytes >= 2, pcmBytes % 2 == 0 else { throw DecodeError.emptyPCM }
        let sourceCount = pcmBytes / 2
        guard sourceCount <= sourceRate * 2 else { throw DecodeError.invalidWAV }
        var input = [Float](repeating: 0, count: sourceCount)
        for i in input.indices {
            let raw = UInt16(u16(pcmStart + i * 2))
            input[i] = Float(Int16(bitPattern: raw)) / 32768
        }
        let peak = input.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > 0.0001 else { throw DecodeError.emptyPCM }
        var first = 0
        if policy.trimOnset, peak > 0.0001, let onset = input.firstIndex(where: { abs($0) >= peak * 0.10 }) {
            first = max(0, onset - Int(Double(sourceRate) * 0.001))
        }
        let count = min(sourceCount - first, max(1, Int(policy.maximumDuration * Double(sourceRate))))
        let frames = max(1, Int((Double(count) * format.sampleRate / Double(sourceRate)).rounded(.down)))
        guard let result = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let channel = result.floatChannelData?[0] else { throw DecodeError.emptyPCM }
        result.frameLength = AVAudioFrameCount(frames)
        let fadeIn = max(1, Int(format.sampleRate * 0.00015))
        let fadeOut = max(1, Int(format.sampleRate * 0.014))
        for i in 0..<frames {
            let position = Double(i) * Double(sourceRate) / format.sampleRate
            let left = min(count - 1, Int(position)), right = min(count - 1, left + 1)
            let weight = Float(position - Double(left))
            var value = input[first + left] * (1 - weight) + input[first + right] * weight
            if policy.trimOnset {
                value *= min(1, Float(i) / Float(fadeIn))
                value *= min(1, Float(frames - 1 - i) / Float(fadeOut))
            }
            channel[i] = value
        }
        return Sample(buffer: result, removedOnset: Double(first) / Double(sourceRate), duration: Double(frames) / format.sampleRate)
    }
}
