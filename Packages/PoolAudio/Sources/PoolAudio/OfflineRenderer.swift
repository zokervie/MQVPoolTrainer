import Foundation

/// Trộn các giọng đã lên lịch thành một buffer stereo (xen kẽ L, R).
/// App dùng chính bộ trộn này để dựng sẵn âm thanh cả cú đánh rồi phát bằng một node,
/// nên âm thanh khớp tuyệt đối với timeline mô phỏng và replay.
public struct OfflineRenderer: Sendable {
    public var sampleRate: Double = 44_100
    /// Trần đỉnh của limiter (dBFS), KPI A3.
    public var ceilingDB: Double = -1
    /// Chế độ tai nghe: thêm lệch thời gian giữa hai tai (ITD) cho cảm giác không gian rõ hơn.
    public var headphoneMode: Bool = false
    public init() {}

    public struct Output: Sendable {
        public var interleaved: [Float]
        public var frames: Int
        public var peakDB: Double
    }

    public func render(_ voices: [ScheduledVoice], sample: (SampleID) -> [Float]) -> Output {
        let sr = sampleRate
        var cache: [SampleID: [Float]] = [:]
        func buf(_ id: SampleID) -> [Float] {
            if let b = cache[id] { return b }
            let b = sample(id); cache[id] = b; return b
        }
        let tail = voices.map { v in v.startTime + Double(max(buf(v.lower).count, buf(v.upper).count)) / sr }.max() ?? 0
        let frames = Int((tail * sr).rounded(.up)) + 1
        var l = [Float](repeating: 0, count: frames), r = l

        for v in voices {
            let lo = buf(v.lower), hi = buf(v.upper)
            let g = pow(10, v.gainDB / 20)
            // Pan đẳng công suất.
            let angle = (v.pan + 1) * .pi / 4
            let gl = Float(g * cos(angle)), gr = Float(g * sin(angle))
            // Lọc thông thấp một cực theo tần số cắt.
            let alpha = Float(1 - exp(-2 * .pi * v.cutoffHz / sr))
            // Transient: va chạm nhẹ làm mềm vài ms đầu.
            let softFrames = Int((1 - v.transient) * 0.004 * sr)
            let itd = headphoneMode ? Int(abs(v.pan) * 0.0006 * sr) : 0
            let start = Int((v.startTime * sr).rounded())
            var y: Float = 0
            let count = max(lo.count, hi.count)
            for i in 0..<count {
                let a = i < lo.count ? lo[i] : 0
                let b = i < hi.count ? hi[i] : 0
                var x = a * Float(1 - v.mix) + b * Float(v.mix)
                if i < softFrames { x *= Float(i) / Float(max(1, softFrames)) }
                y += alpha * (x - y)
                let il = start + i + (v.pan > 0 ? itd : 0)
                let ir = start + i + (v.pan < 0 ? itd : 0)
                if il < frames { l[il] += y * gl }
                if ir < frames { r[ir] += y * gr }
            }
        }

        // Limiter đỉnh: tấn công tức thời, nhả theo hàm mũ. Bảo đảm không vượt trần.
        let ceiling = Float(pow(10, ceilingDB / 20))
        let release = Float(exp(-1 / (0.05 * sr)))
        var gain: Float = 1
        var out = [Float](repeating: 0, count: frames * 2)
        var peak: Float = 0
        for i in 0..<frames {
            let p = max(abs(l[i]), abs(r[i]))
            let needed: Float = p * gain > ceiling ? ceiling / p : 1
            gain = min(needed, 1 - (1 - gain) * release)
            if p * gain > ceiling { gain = ceiling / p }
            let a = l[i] * gain, b = r[i] * gain
            out[2 * i] = a; out[2 * i + 1] = b
            peak = max(peak, abs(a), abs(b))
        }
        let peakDB = peak > 0 ? 20 * log10(Double(peak)) : -.infinity
        return Output(interleaved: out, frames: frames, peakDB: peakDB)
    }
}
