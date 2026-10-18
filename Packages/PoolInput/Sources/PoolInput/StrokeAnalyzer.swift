import Foundation

/// Một mẫu cảm ứng, đã quy đổi sang milimét vật lý (dùng `coalescedTouches`).
public struct TouchSample: Codable, Equatable, Sendable {
    public var time: Double            // s (UITouch.timestamp)
    public var position: SIMD2<Double> // mm, trục y hướng xuống như UIKit
    public init(time: Double, position: SIMD2<Double>) {
        self.time = time
        self.position = position
    }
}

public struct StrokeResult: Equatable, Sendable {
    /// Tốc độ ngón theo hướng đẩy tại vạch chạm bi (mm/s).
    public var fingerSpeed: Double
    /// Tỉ lệ tốc độ ngang / tốc độ đẩy tại vạch chạm (0 = thẳng tuyệt đối).
    public var lateralRatio: Double
    /// Tốc độ tại vạch / tốc độ đẩy lớn nhất trước đó (< 1 nghĩa là ngắt cơ).
    public var followThroughRatio: Double
}

public enum StrokeOutcome: Equatable, Sendable {
    case inProgress
    case struck(StrokeResult)
    case cancelled
}

/// Phân tích cú vuốt ra cơ (docs/02-controls.md):
/// điểm đặt ngón ban đầu = vạch chạm bi; kéo lùi lấy đà; đẩy tới vượt vạch = chạm bi.
/// Không có ngẫu nhiên: cùng chuỗi mẫu → cùng kết quả.
public struct StrokeAnalyzer: Sendable {
    /// Hướng đẩy trên màn hình (mặc định: lên trên).
    public var forward = SIMD2<Double>(0, -1)
    /// Quãng lấy đà tối thiểu (mm).
    public var minBackswing: Double = 10
    /// Số mẫu dùng cho hồi quy tuyến tính quanh vạch.
    public var regressionWindow: Int = 5

    private var samples: [TouchSample] = []
    private var deepestBackswing: Double = 0
    private var finished = false

    public init() {}

    public init(config: StrokeConfig) {
        forward = config.forward
        minBackswing = config.minBackswing
        regressionWindow = config.regressionWindow
    }

    private func along(_ p: SIMD2<Double>) -> Double {
        let d = p - samples[0].position
        return d.x * forward.x + d.y * forward.y
    }
    private func lateral(_ p: SIMD2<Double>) -> Double {
        let d = p - samples[0].position
        return d.x * (-forward.y) + d.y * forward.x
    }

    public mutating func begin(_ s: TouchSample) {
        samples = [s]
        deepestBackswing = 0
        finished = false
    }

    /// Thêm mẫu (gọi cho từng coalesced touch theo thứ tự thời gian).
    public mutating func add(_ s: TouchSample) -> StrokeOutcome {
        guard !finished, !samples.isEmpty else { return .inProgress }
        samples.append(s)
        let a = along(s.position)
        deepestBackswing = min(deepestBackswing, a)
        let readied = -deepestBackswing >= minBackswing
        if readied && a >= 0 {
            finished = true
            return .struck(result())
        }
        return .inProgress
    }

    /// Nhấc tay. Chưa vượt vạch → ngưng cơ.
    public mutating func end() -> StrokeOutcome {
        defer { samples = []; finished = false }
        return finished ? .inProgress : .cancelled
    }

    private func result() -> StrokeResult {
        let window = Array(samples.suffix(max(2, regressionWindow)))
        let ts = window.map(\.time)
        let forwardSpeed = Self.slope(ts, window.map { along($0.position) })
        let lateralSpeed = Self.slope(ts, window.map { lateral($0.position) })

        // Tốc độ đẩy lớn nhất giữa các cặp mẫu liên tiếp trong pha đẩy.
        var peak = forwardSpeed
        if samples.count >= 2 {
            for i in 1..<samples.count {
                let dt = samples[i].time - samples[i - 1].time
                guard dt > 0 else { continue }
                let v = (along(samples[i].position) - along(samples[i - 1].position)) / dt
                peak = max(peak, v)
            }
        }
        let speed = max(0, forwardSpeed)
        return StrokeResult(
            fingerSpeed: speed,
            lateralRatio: speed > 0 ? lateralSpeed / speed : 0,
            followThroughRatio: peak > 0 ? min(1, speed / peak) : 1
        )
    }

    /// Hệ số góc hồi quy tuyến tính bình phương tối thiểu.
    static func slope(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        guard n >= 2 else { return 0 }
        let mx = x.reduce(0, +) / n, my = y.reduce(0, +) / n
        var num = 0.0, den = 0.0
        for i in x.indices {
            num += (x[i] - mx) * (y[i] - my)
            den += (x[i] - mx) * (x[i] - mx)
        }
        return den > 0 ? num / den : 0
    }
}
