import Foundation
import Observation
import PoolPhysics
import PoolDrills

/// Lịch sử cú đánh, lưu JSON trong Application Support.
@MainActor @Observable
final class HistoryStore {
    private(set) var logs: [ShotLog] = []
    private let url: URL

    init() {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        url = dir.appendingPathComponent("history.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([ShotLog].self, from: data) {
            logs = decoded
        }
    }

    func append(_ log: ShotLog) {
        logs.append(log)
        if let data = try? JSONEncoder().encode(logs) { try? data.write(to: url, options: .atomic) }
    }

    func clear() {
        logs = []
        try? FileManager.default.removeItem(at: url)
    }
}

/// Hồ sơ bàn: định nghĩa bàn mặc định + hiệu chỉnh tay của người chơi (R5).
@MainActor @Observable
final class TableStore {
    let definition = TableDefinition.zoker9ft
    private(set) var calibration: CalibrationProfile?
    private let url: URL

    init() {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        url = dir.appendingPathComponent("calibration.json")
        if let data = try? Data(contentsOf: url) {
            let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
            calibration = try? d.decode(CalibrationProfile.self, from: data)
        }
    }

    var parameters: PhysicsParameters {
        if let c = calibration, let r = try? c.applied(to: definition) { return r.0 }
        return definition.physics
    }

    var provenance: [ParameterKey: Provenance] {
        if let c = calibration, let r = try? c.applied(to: definition) { return r.1 }
        return definition.physicsProvenance
    }

    func save(_ profile: CalibrationProfile?) {
        calibration = profile
        if let profile {
            let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
            if let data = try? e.encode(profile) { try? data.write(to: url, options: .atomic) }
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

enum DrillCatalog {
    /// Bài tập đóng gói trong thư mục `Drills` của app.
    static func load() -> [Drill] {
        guard let dir = Bundle.main.url(forResource: "Drills", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return [] }
        return files.filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? DrillLoader.load(Data(contentsOf: $0)) }
    }
}
