import Foundation
import PoolPhysics

/// Mã mẫu: loại va chạm × lớp lực × biến thể.
public struct SampleID: Hashable, Codable, Sendable, Comparable {
    public var kind: CollisionKind
    public var layer: Int
    public var variant: Int
    public static func < (a: SampleID, b: SampleID) -> Bool {
        (a.kind.rawValue, a.layer, a.variant) < (b.kind.rawValue, b.layer, b.variant)
    }
}

/// Một giọng đã lên lịch: hai lớp lực trộn chéo, cùng thời điểm và tham số.
public struct ScheduledVoice: Equatable, Sendable {
    public var startTime: Double          // giây, trên timeline phát (đã tính tốc độ phát)
    public var lower: SampleID
    public var upper: SampleID
    public var mix: Double                // 0 = toàn lớp dưới
    public var gainDB: Double
    public var cutoffHz: Double
    public var transient: Double
    public var pan: Double
    public var sourceEvent: Int
}

public struct SchedulerConfig: Codable, Equatable, Sendable {
    /// Số giọng đồng thời tối đa.
    public var maxVoices: Int = 24
    /// Gộp va chạm cùng loại, cùng bi trong cửa sổ này (giây).
    public var mergeWindow: Double = 0.004
    /// Độ dài ước lượng của một giọng (giây), để đếm giọng đang phát.
    public var voiceDuration: Double = 0.35
    /// Khi phát chậm hơn ngưỡng này, chỉ giữ va chạm đủ mạnh.
    public var slowMotionThreshold: Double = 0.5
    public var slowMotionMinGainDB: Double = -24
    public var variants: Int = 4
    public init() {}
}

/// Lên lịch phát xác định cho một cú đánh (UPGRADE.md 6.5, KPI A2):
/// cùng sự kiện + cùng cấu hình → cùng danh sách giọng. Không dùng ngẫu nhiên.
public struct AudioScheduler: Sendable {
    public var mapping: AcousticMapping
    public var config: SchedulerConfig

    public init(mapping: AcousticMapping = AcousticMapping(), config: SchedulerConfig = SchedulerConfig()) {
        self.mapping = mapping
        self.config = config
    }

    /// - Parameters:
    ///   - rate: tốc độ phát (1 = thời gian thực, 0,25 = chậm 4 lần). Giãn thời điểm, không đổi cao độ.
    ///   - from: vị trí bắt đầu phát trên timeline mô phỏng (tua).
    ///   - spatial: false → pan = 0 (tắt âm thanh không gian).
    public func schedule(_ events: [AudioEvent], listener: ListenerPose, rate: Double = 1,
                         from start: Double = 0, spatial: Bool = true) -> [ScheduledVoice] {
        let ordered = events.filter { $0.time >= start }.sorted { ($0.time, $0.index) < ($1.time, $1.index) }

        // 1. Gộp sự kiện cùng loại, cùng bộ bi, quá gần nhau: giữ xung lực lớn nhất.
        var merged: [AudioEvent] = []
        for e in ordered {
            if let k = merged.lastIndex(where: { $0.kind == e.kind && $0.sourceIds == e.sourceIds }),
               e.time - merged[k].time <= config.mergeWindow {
                if e.impulse > merged[k].impulse {
                    var keep = e; keep.time = merged[k].time; merged[k] = keep
                }
                continue
            }
            merged.append(e)
        }

        // 2. Tính tham số từng giọng.
        var voices: [ScheduledVoice] = []
        for e in merged {
            let blend = mapping.layerBlend(e.kind, impulse: e.impulse)
            let variant = Self.variant(e, count: config.variants)
            let s = listener.spatial(e.position)
            let gain = mapping.gainDB(e.kind, impulse: e.impulse) + s.attenuationDB
            if rate < config.slowMotionThreshold && gain < config.slowMotionMinGainDB { continue }
            voices.append(ScheduledVoice(
                startTime: (e.time - start) / rate,
                lower: SampleID(kind: e.kind, layer: blend.lower, variant: variant),
                upper: SampleID(kind: e.kind, layer: blend.upper, variant: variant),
                mix: blend.mix, gainDB: gain,
                cutoffHz: mapping.cutoffHz(e.kind, impulse: e.impulse),
                transient: mapping.transient(speed: e.relativeNormalSpeed),
                pan: spatial ? s.pan : 0, sourceEvent: e.index))
        }

        // 3. Giới hạn số giọng đồng thời: khi vượt, bỏ giọng yếu nhất (kể cả giọng mới).
        var kept: [ScheduledVoice] = []
        for v in voices {
            let active = kept.indices.filter { v.startTime - kept[$0].startTime < config.voiceDuration }
            if active.count < config.maxVoices { kept.append(v); continue }
            let weakest = active.min { (kept[$0].gainDB, -kept[$0].sourceEvent) < (kept[$1].gainDB, -kept[$1].sourceEvent) }!
            if kept[weakest].gainDB < v.gainDB {
                kept.remove(at: weakest)
                kept.append(v)
            }
        }
        return kept
    }

    /// Chọn biến thể bằng hàm băm FNV-1a của (shotId, index, sourceIds).
    static func variant(_ e: AudioEvent, count: Int) -> Int {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ x: UInt64) {
            var v = x
            for _ in 0..<8 { h ^= v & 0xff; h &*= 0x0000_0100_0000_01b3; v >>= 8 }
        }
        mix(e.shotId); mix(UInt64(e.index))
        for id in e.sourceIds { mix(UInt64(bitPattern: Int64(id))) }
        return Int(h % UInt64(max(1, count)))
    }
}
