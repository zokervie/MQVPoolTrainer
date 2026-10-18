import Foundation
import PoolPhysics

/// Cặp vật liệu tại va chạm (khi biết). Hồ sơ vật liệu chi tiết theo bàn: R7 (UPGRADE.md 6.3).
public enum MaterialPair: String, Codable, Sendable {
    case leatherPhenolic      // đầu cơ – bi
    case phenolicPhenolic     // bi – bi
    case phenolicRubber       // bi – cao su băng
    case phenolicJaw          // bi – mũi băng ở miệng lỗ
    case phenolicPocket       // bi – lỗ (da / lưới)
}

/// Sự kiện âm thanh, suy ra từ `CollisionRecord` của PoolPhysics. Không chứa dữ liệu âm thanh.
public struct AudioEvent: Equatable, Sendable {
    public var kind: CollisionKind
    public var time: Double
    public var position: SIMD3<Double>
    public var relativeNormalSpeed: Double
    public var impulse: Double
    public var tangentialSlip: Double
    public var materials: MaterialPair
    public var sourceIds: [Int]
    /// Định danh cú đánh + thứ tự sự kiện: dùng chọn biến thể mẫu một cách xác định.
    public var shotId: UInt64
    public var index: Int
}

public enum AudioEventBuilder {
    public static func events(from records: [CollisionRecord], shotId: UInt64) -> [AudioEvent] {
        records.enumerated().map { k, r in
            AudioEvent(kind: r.kind, time: r.time, position: r.position,
                       relativeNormalSpeed: r.relativeNormalSpeed, impulse: r.impulse,
                       tangentialSlip: r.tangentialSlip, materials: material(for: r.kind),
                       sourceIds: r.ballIds, shotId: shotId, index: k)
        }
    }

    public static func material(for kind: CollisionKind) -> MaterialPair {
        switch kind {
        case .cueTip, .miscue: .leatherPhenolic
        case .ballBall: .phenolicPhenolic
        case .ballCushion: .phenolicRubber
        case .ballJaw: .phenolicJaw
        case .ballDrop: .phenolicPocket
        }
    }
}
