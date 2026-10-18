import Foundation
import simd
import PoolPhysics

/// Điều kiện đạt của bài tập, phân tích từ chuỗi `dieu_kien_dat` (docs/04-drills.md).
public enum DrillCondition: Equatable, Sendable {
    /// Bi N vào lỗ; `pocket` = tên lỗ (TableGeometry.Pocket.name) hoặc nil = lỗ bất kỳ.
    case ballPocketed(ball: Int, pocket: String?)
    /// Bi cái dừng trong một vùng đích của bài.
    case cueBallInTarget
    /// Bi cái chạm ít nhất N lần băng.
    case cueBallCushions(Int)
    /// Điều kiện không nhận ra — bài tập bị coi là lỗi định dạng.
    case unknown(String)

    public static func parse(_ s: String) -> DrillCondition {
        let parts = s.split(separator: "_").map(String.init)
        if s == "bi_cai_trong_vung_dich" { return .cueBallInTarget }
        if parts.count == 5, s.hasPrefix("bi_cai_cham_bang_"), let n = Int(parts[4]) { return .cueBallCushions(n) }
        if parts.count >= 4, parts[0] == "bi", let n = Int(parts[1]), parts[2] == "vao", parts[3] == "lo" {
            return .ballPocketed(ball: n, pocket: parts.count > 4 ? parts[4...].joined(separator: "_") : nil)
        }
        return .unknown(s)
    }
}

public struct DrillOutcome: Equatable, Sendable {
    public var success: Bool
    /// Từng điều kiện và kết quả.
    public var conditions: [(DrillCondition, Bool)]
    /// Bi cái rơi lỗ: luôn tính là không đạt.
    public var cueBallScratched: Bool
    /// Khoảng cách từ vị trí dừng của bi cái tới tâm vùng đích gần nhất (mét), nếu bài có vùng đích.
    public var cueBallDistanceToTarget: Double?

    public static func == (a: DrillOutcome, b: DrillOutcome) -> Bool {
        a.success == b.success && a.cueBallScratched == b.cueBallScratched
            && a.cueBallDistanceToTarget == b.cueBallDistanceToTarget
            && a.conditions.map { $0.1 } == b.conditions.map { $0.1 }
            && a.conditions.map { $0.0 } == b.conditions.map { $0.0 }
    }
}

extension Drill {
    public var tableSpec: TableSpec {
        switch ban { case "8ft": .eightFoot; case "7ft": .sevenFoot; default: .nineFoot }
    }

    public var parsedConditions: [DrillCondition] { dieuKienDat.map(DrillCondition.parse) }

    /// Bi ban đầu (mét). `attempt` + `lechNgauNhien` cho độ lệch vị trí xác định theo lần đánh.
    public func initialBalls(attempt: Int = 0) -> [Ball] {
        let t = tableSpec
        var rng = SplitMix64(seed: UInt64(truncatingIfNeeded: id.hashValueStable) &+ UInt64(attempt))
        return bi.map { b in
            var d = SIMD2(b.x, b.y)
            if lechNgauNhien > 0 {
                d += SIMD2(rng.unit() * 2 - 1, rng.unit() * 2 - 1) * lechNgauNhien
            }
            let m = t.meters(fromDiamonds: d)
            let R = t.ballRadius
            let clamped = SIMD2(min(max(m.x, R + 0.001), t.length - R - 0.001),
                                min(max(m.y, R + 0.001), t.width - R - 0.001))
            return Ball(id: b.so, position: SIMD3(clamped.x, clamped.y, R))
        }
    }

    /// Các vùng đích (tâm mét, bán kính mét).
    public var targetZones: [(center: SIMD2<Double>, radius: Double)] {
        let t = tableSpec
        return danhDau.filter { $0.loai == "vung_dich" }.compactMap { m in
            guard let x = m.x, let y = m.y else { return nil }
            return (t.meters(fromDiamonds: SIMD2(x, y)), (m.banKinh ?? 0.5) * t.diamondSize)
        }
    }

    /// Cú đánh mẫu theo thẻ hướng dẫn (dùng cho Shot Lab và để tìm khoảng ngắm).
    public func guideStrike(aimAngle: Double) -> CueStrike {
        CueStrike(aimAngle: aimAngle, cueSpeed: SpeedScale.cueSpeed(level: huongDan.luc),
                  tipVertical: huongDan.diemCham.doc, tipHorizontal: huongDan.diemCham.ngang)
    }

    /// Điều kiện vào lỗ chính, dùng để tính khoảng ngắm (sai số ngắm chỉ tính khi có mục tiêu này).
    public var primaryPocketTarget: (ball: Int, pocket: String?)? {
        for c in parsedConditions { if case let .ballPocketed(b, p) = c { return (b, p) } }
        return nil
    }

    public func evaluate(_ result: ShotResult) -> DrillOutcome {
        let geometry = TableGeometry(tableSpec)
        let pocketName = Dictionary(uniqueKeysWithValues: geometry.pockets.map { ($0.id, $0.name) })
        let finalCue = result.finalBalls.first { $0.id == 0 }
        let scratched = finalCue?.state == .pocketed
        let zones = targetZones
        var distance: Double? = nil
        if let cue = finalCue, !scratched, !zones.isEmpty {
            let p = SIMD2(cue.position.x, cue.position.y)
            distance = zones.map { simd_distance($0.center, p) }.min()
        }
        var results: [(DrillCondition, Bool)] = []
        for c in parsedConditions {
            let ok: Bool
            switch c {
            case let .ballPocketed(ball, pocket):
                ok = result.pocketed.contains { $0.ballId == ball && (pocket == nil || pocketName[$0.pocketId] == pocket) }
            case .cueBallInTarget:
                if let cue = finalCue, !scratched {
                    let p = SIMD2(cue.position.x, cue.position.y)
                    ok = zones.contains { simd_distance($0.center, p) <= $0.radius }
                } else { ok = false }
            case let .cueBallCushions(n):
                ok = result.collisions.filter { $0.kind == .ballCushion && $0.ballIds == [0] }.count >= n
            case .unknown:
                ok = false
            }
            results.append((c, ok))
        }
        return DrillOutcome(success: !scratched && results.allSatisfy { $0.1 }, conditions: results,
                            cueBallScratched: scratched, cueBallDistanceToTarget: distance)
    }
}

extension String {
    /// Băm FNV-1a ổn định giữa các lần chạy (khác `hashValue`, vốn ngẫu nhiên theo tiến trình).
    var hashValueStable: UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in utf8 { h ^= UInt64(b); h &*= 0x0000_0100_0000_01b3 }
        return h
    }
}
