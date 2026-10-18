import Foundation

/// Bản ghi một cú đánh để lưu lịch sử (App lưu bằng SwiftData/JSON).
public struct ShotLog: Codable, Equatable, Sendable {
    public var date: Date
    public var drillId: String?
    public var attempt: Int
    public var success: Bool?
    public var cueSpeed: Double
    public var speedLevel: Int
    /// Sai số ngắm (độ, có dấu; dương = cần ngắm sang trái), chỉ khi bài có mục tiêu vào lỗ.
    public var aimErrorDegrees: Double?
    /// Độ rộng khoảng ngắm đạt (độ) — cú dễ hay khó.
    public var aimWindowDegrees: Double?
    public var lateralRatio: Double?
    public var followThroughRatio: Double?
    public var cueBallDistanceToTarget: Double?
    public var shotLab: Bool

    public init(date: Date, drillId: String?, attempt: Int, success: Bool?, cueSpeed: Double,
                aimErrorDegrees: Double? = nil, aimWindowDegrees: Double? = nil,
                lateralRatio: Double? = nil, followThroughRatio: Double? = nil,
                cueBallDistanceToTarget: Double? = nil, shotLab: Bool = false) {
        self.date = date; self.drillId = drillId; self.attempt = attempt; self.success = success
        self.cueSpeed = cueSpeed; self.speedLevel = SpeedScale.level(forCueSpeed: cueSpeed)
        self.aimErrorDegrees = aimErrorDegrees; self.aimWindowDegrees = aimWindowDegrees
        self.lateralRatio = lateralRatio; self.followThroughRatio = followThroughRatio
        self.cueBallDistanceToTarget = cueBallDistanceToTarget; self.shotLab = shotLab
    }
}

extension SpeedScale {
    /// Mức 1–7 gần nhất với tốc độ cơ (so trên thang log).
    public static func level(forCueSpeed v: Double) -> Int {
        guard v > 0 else { return 1 }
        var best = 1, bestD = Double.infinity
        for (k, s) in cueSpeeds.enumerated() {
            let d = abs(log(v / s))
            if d < bestD { bestD = d; best = k + 1 }
        }
        return best
    }
}

/// Thống kê một phiên tập của một bài.
public struct DrillStats: Equatable, Sendable {
    public var attempts: Int
    public var successes: Int
    public var successRate: Double
    /// Hệ số biến thiên tốc độ cơ (độ đều lực).
    public var speedCV: Double?
    public var meanAbsAimError: Double?
    public var meanTargetDistance: Double?

    public init(_ logs: [ShotLog]) {
        attempts = logs.count
        successes = logs.filter { $0.success == true }.count
        successRate = attempts > 0 ? Double(successes) / Double(attempts) : 0
        let speeds = logs.map(\.cueSpeed)
        if speeds.count >= 3 {
            let mean = speeds.reduce(0, +) / Double(speeds.count)
            let sd = (speeds.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(speeds.count - 1)).squareRoot()
            speedCV = mean > 0 ? sd / mean : nil
        }
        let aims = logs.compactMap(\.aimErrorDegrees).map(abs)
        meanAbsAimError = aims.isEmpty ? nil : aims.reduce(0, +) / Double(aims.count)
        let d = logs.compactMap(\.cueBallDistanceToTarget)
        meanTargetDistance = d.isEmpty ? nil : d.reduce(0, +) / Double(d.count)
    }
}

/// Phân tích lỗi lặp lại bằng quy tắc đơn giản (không dùng mô hình AI) → gợi ý bài tập.
public struct Insight: Equatable, Sendable {
    public enum Code: String, Sendable { case aimBiasLeft, aimBiasRight, inconsistentSpeed, crookedStroke, decelerating }
    public var code: Code
    public var message: String
    public var suggestedDrillId: String?
}

public enum ErrorAnalysis {
    /// Cần ít nhất `minimumShots` cú có dữ liệu cho mỗi quy tắc.
    public static func insights(_ logs: [ShotLog], minimumShots: Int = 8) -> [Insight] {
        let natural = logs.filter { !$0.shotLab }
        var out: [Insight] = []

        let aims = natural.compactMap(\.aimErrorDegrees)
        if aims.count >= minimumShots {
            let bias = aims.reduce(0, +) / Double(aims.count)
            // aimError dương = lẽ ra phải ngắm sang trái hơn = người chơi hay ngắm lệch phải.
            if bias > 0.3 {
                out.append(Insight(code: .aimBiasRight, message: String(format: "Bạn thường ngắm lệch sang phải khoảng %.1f°.", bias), suggestedDrillId: "thang-xa"))
            } else if bias < -0.3 {
                out.append(Insight(code: .aimBiasLeft, message: String(format: "Bạn thường ngắm lệch sang trái khoảng %.1f°.", -bias), suggestedDrillId: "thang-xa"))
            }
        }

        // Độ đều lực: theo từng bài (cùng lực yêu cầu).
        let byDrill = Dictionary(grouping: natural.filter { $0.drillId != nil }, by: { $0.drillId! })
        let cvs = byDrill.values.filter { $0.count >= minimumShots }.compactMap { DrillStats($0).speedCV }
        if let worst = cvs.max(), worst > 0.15 {
            out.append(Insight(code: .inconsistentSpeed, message: String(format: "Lực đánh chưa đều (dao động %.0f%%).", worst * 100), suggestedDrillId: "lag-hai-bang"))
        }

        let laterals = natural.compactMap(\.lateralRatio).map(abs)
        if laterals.count >= minimumShots, laterals.reduce(0, +) / Double(laterals.count) > 0.1 {
            out.append(Insight(code: .crookedStroke, message: "Cú vuốt thường lệch ngang, làm cơ đi chệch.", suggestedDrillId: "thang-xa"))
        }

        let follow = natural.compactMap(\.followThroughRatio)
        if follow.count >= minimumShots, Double(follow.filter { $0 < 0.85 }.count) / Double(follow.count) > 0.3 {
            out.append(Insight(code: .decelerating, message: "Bạn hay giảm tốc trước khi chạm bi (ngắt cơ).", suggestedDrillId: "dung-bi"))
        }
        return out
    }
}
