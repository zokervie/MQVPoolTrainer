import Foundation
import PoolPhysics

/// Bản ghi giấy phép cho từng mẫu (UPGRADE.md 6.7, KPI A5).
public struct LicenseRecord: Codable, Equatable, Sendable {
    public var source: String
    public var license: String
    public var commercialUse: Bool
    public var retrievedAt: String
    public var evidence: String
}

public struct SampleEntry: Codable, Equatable, Sendable {
    public var id: SampleID
    /// Tên file trong bundle; nil nếu mẫu được tổng hợp bằng `PlaceholderSynth`.
    public var fileName: String?
    public var license: LicenseRecord
}

public enum SampleLibraryError: Error, Equatable {
    case missingLicense(SampleID)
    case notCommercial(SampleID)
    case missingSample(SampleID)
}

public struct SampleLibrary: Codable, Equatable, Sendable {
    public var name: String
    /// Bộ mẫu tạm hay bộ thu từ bàn thật.
    public var isPlaceholder: Bool
    public var entries: [SampleEntry]

    public func entry(_ id: SampleID) -> SampleEntry? { entries.first { $0.id == id } }

    /// Kiểm tra: đủ mẫu cho mọi loại × lớp × biến thể, và mọi mẫu có giấy phép thương mại.
    public func validate(layers: Int, variants: Int) throws {
        for kind in CollisionKind.allCases {
            for layer in 0..<layers {
                for variant in 0..<variants {
                    let id = SampleID(kind: kind, layer: layer, variant: variant)
                    guard let e = entry(id) else { throw SampleLibraryError.missingSample(id) }
                    guard !e.license.license.isEmpty, !e.license.source.isEmpty else {
                        throw SampleLibraryError.missingLicense(id)
                    }
                    guard e.license.commercialUse else { throw SampleLibraryError.notCommercial(id) }
                }
            }
        }
    }

    /// Bộ mẫu tạm của R2: tổng hợp bằng thuật toán trong dự án, sở hữu toàn quyền.
    /// **Chưa** được nghe thử hay so với bàn thật (KPI A6–A7 thuộc R7).
    public static func placeholder(layers: Int = 5, variants: Int = 4) -> SampleLibrary {
        let license = LicenseRecord(
            source: "Tổng hợp bằng PlaceholderSynth trong mã nguồn dự án Zoker Pool Trainer",
            license: "Thuộc sở hữu dự án (mã nguồn tự viết, không dùng mẫu bên ngoài)",
            commercialUse: true, retrievedAt: "2026-10-18",
            evidence: "Packages/PoolAudio/Sources/PoolAudio/PlaceholderSynth.swift")
        var entries: [SampleEntry] = []
        for kind in CollisionKind.allCases {
            for layer in 0..<layers {
                for variant in 0..<variants {
                    entries.append(SampleEntry(id: SampleID(kind: kind, layer: layer, variant: variant),
                                               fileName: nil, license: license))
                }
            }
        }
        return SampleLibrary(name: "placeholder-synth-v1", isPlaceholder: true, entries: entries)
    }
}
