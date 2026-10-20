import Foundation

/// Cấu hình bộ phân tích được lưu cùng bản ghi, để phát lại cho đúng kết quả (KPI U2).
public struct StrokeConfig: Codable, Equatable, Sendable {
    public var forward = SIMD2<Double>(0, -1)
    public var minBackswing: Double = 10
    public var regressionWindow: Int = 5
    /// Cửa sổ hồi quy theo thời gian (s) quanh vạch chạm. nil = theo số mẫu (`regressionWindow`, bản ghi cũ).
    /// Theo thời gian thì cùng một chuyển động ngón cho cùng tốc độ dù máy lấy mẫu 60, 120 hay 240 Hz,
    /// và trung bình đủ dài (35 ms) để lực không giật theo nhiễu cảm ứng. Giả định, chỉnh theo số đo U4.
    public var regressionDuration: Double? = 0.035
    public init() {}

    private enum CodingKeys: String, CodingKey { case forward, minBackswing, regressionWindow, regressionDuration }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        forward = try c.decode(SIMD2<Double>.self, forKey: .forward)
        minBackswing = try c.decode(Double.self, forKey: .minBackswing)
        regressionWindow = try c.decode(Int.self, forKey: .regressionWindow)
        // Bản ghi cũ không có khóa này → giữ cách tính cũ để phát lại y hệt.
        regressionDuration = try c.decodeIfPresent(Double.self, forKey: .regressionDuration)
    }
}

/// Bản ghi cảm ứng thô của một cú vuốt. Dùng để:
/// - phát lại và kiểm tra cùng đầu vào → cùng kết quả;
/// - tách lỗi người chơi khỏi lỗi điều khiển và lỗi vật lý (REVIEW.md C5).
public struct TouchRecording: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var deviceModel: String
    /// Hệ số đổi điểm màn hình → milimét (từ màn hiệu chỉnh).
    public var mmPerPoint: Double
    public var config: StrokeConfig
    /// Mẫu đã đổi sang mm, theo thứ tự thời gian.
    public var samples: [TouchSample]

    public init(deviceModel: String, mmPerPoint: Double,
                config: StrokeConfig = StrokeConfig(), samples: [TouchSample]) {
        self.formatVersion = Self.currentFormatVersion
        self.deviceModel = deviceModel
        self.mmPerPoint = mmPerPoint
        self.config = config
        self.samples = samples
    }

    /// Chạy lại bộ phân tích trên bản ghi. Không có ngẫu nhiên: luôn ra cùng kết quả.
    public func replay() -> StrokeOutcome {
        guard let first = samples.first else { return .cancelled }
        var a = StrokeAnalyzer(config: config)
        a.begin(first)
        for s in samples.dropFirst() {
            let r = a.add(s)
            if case .struck = r { return r }
        }
        return a.end()
    }
}
