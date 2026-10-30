import Foundation

/// Immutable presentation snapshots. Playback reads this value and never changes
/// the live BLWorld. Small shot inputs/labels stay in SavedShot for legacy replay.
struct ShotRecording: Codable {
    static let currentVersion = 1
    let schemaVersion: Int
    let createdAt: Date
    let frames: [[BallState]]
    let frameTimes: [Double]
    private let recordedEvents: [[String: Double]]

    init(frames: [[BallState]], frameTimes: [Double], events: [[String: NSNumber]]) {
        schemaVersion = Self.currentVersion
        createdAt = Date()
        self.frames = frames
        self.frameTimes = frameTimes
        recordedEvents = events.map { event in event.mapValues { $0.doubleValue } }
    }

    var events: [[String: NSNumber]] {
        recordedEvents.map { event in event.mapValues { NSNumber(value: $0) } }
    }

    var duration: Double { frameTimes.last ?? 0 }

    /// Bounds apply on both save and load, including legacy/corrupted disk data.
    /// Keeping every recorded frame under one limit avoids archive decode spikes.
    func validate() throws {
        guard schemaVersion == Self.currentVersion else { throw ShotArchiveError.unsupportedVersion }
        guard !frames.isEmpty, frames.count <= 7_201,
              frames.count == frameTimes.count,
              let firstTime = frameTimes.first, firstTime.isFinite, firstTime >= 0,
              firstTime <= 0.05, duration.isFinite, duration <= 120 else {
            throw ShotArchiveError.invalidRecording
        }
        var previousTime = -Double.infinity
        var expectedIDs: Set<Int>?
        for (frame, time) in zip(frames, frameTimes) {
            guard time.isFinite, time >= previousTime, (1...16).contains(frame.count) else {
                throw ShotArchiveError.invalidRecording
            }
            previousTime = time
            let ids = Set(frame.map { $0.id })
            guard ids.count == frame.count, ids.allSatisfy({ (0...15).contains($0) }),
                  expectedIDs == nil || expectedIDs == ids else {
                throw ShotArchiveError.invalidRecording
            }
            expectedIDs = ids
            for ball in frame {
                let values = [ball.x, ball.y, ball.wx, ball.wy, ball.spin,
                              ball.height ?? 0, ball.vertical ?? 0,
                              ball.vx ?? 0, ball.vy ?? 0,
                              ball.qx ?? 0, ball.qy ?? 0, ball.qz ?? 0, ball.qw ?? 1]
                guard values.allSatisfy({ $0.isFinite }), abs(ball.x) <= 8,
                      abs(ball.y) <= 8, (0...1_000_000).contains(ball.rails) else {
                    throw ShotArchiveError.invalidRecording
                }
            }
        }
        guard recordedEvents.count <= 32_768 else { throw ShotArchiveError.invalidRecording }
        var previousEventTime = -Double.infinity
        for event in recordedEvents {
            guard event.count <= 16, event.values.allSatisfy({ $0.isFinite }),
                  let kind = event["kind"], kind.rounded() == kind, (0...2).contains(kind),
                  let actor = event["a"], actor.rounded() == actor, (0...15).contains(actor),
                  let other = event["b"], other.rounded() == other,
                  let time = event["time"], time >= 0,
                  time >= previousEventTime, time <= duration + 0.25 else {
                throw ShotArchiveError.invalidRecording
            }
            switch Int(kind) {
            case 0: guard (0...3).contains(other) else { throw ShotArchiveError.invalidRecording }
            case 1: guard (0...15).contains(other), other != actor else { throw ShotArchiveError.invalidRecording }
            default: guard (-1...5).contains(other) else { throw ShotArchiveError.invalidRecording }
            }
            previousEventTime = time
        }
    }
}

enum ShotArchiveError: LocalizedError {
    case invalidID, invalidRecording, unsupportedVersion, recordingTooLarge, missingRecording
    var errorDescription: String? {
        switch self {
        case .invalidID: return "Mã bản lưu không hợp lệ."
        case .invalidRecording: return "Dữ liệu phát lại không hợp lệ hoặc chưa hoàn chỉnh."
        case .unsupportedVersion: return "Bản ghi dùng phiên bản định dạng khác."
        case .recordingTooLarge: return "Bản ghi vượt giới hạn dung lượng."
        case .missingRecording: return "Bản ghi hình đã được dọn khỏi bộ nhớ; vẫn còn đầu vào cú đánh để dựng lại."
        }
    }
}

/// Disk work and JSON coding never run in CADisplayLink or on the main queue.
/// Atomic writes retain at most 20 recordings and 200 MiB; a single decode is
/// capped at 32 MiB. All completion handlers return on the main queue.
final class ShotArchive {
    static let shared = ShotArchive()
    static let maximumCount = 20
    static let maximumBytes = 200 * 1_024 * 1_024
    static let maximumRecordingBytes = 32 * 1_024 * 1_024
    private let queue = DispatchQueue(label: "vn.zoker.shot-archive", qos: .utility)
    private let fileManager = FileManager()
    private let root: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        root = base.appendingPathComponent("ShotRecordings-v1", isDirectory: true)
    }

    func save(_ recording: ShotRecording, id: String = UUID().uuidString,
              completion: @escaping (Result<String, Error>) -> Void) {
        queue.async { [self] in
            let result: Result<String, Error>
            do {
                let url = try recordingURL(id)
                try recording.validate()
                let data = try JSONEncoder().encode(recording)
                guard data.count <= Self.maximumRecordingBytes else {
                    throw ShotArchiveError.recordingTooLarge
                }
                try prepareDirectory()
                try data.write(to: url, options: .atomic)
                try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
                try prune(keeping: url)
                result = .success(id)
            } catch { result = .failure(error) }
            DispatchQueue.main.async { completion(result) }
        }
    }

    func load(id: String, completion: @escaping (Result<ShotRecording, Error>) -> Void) {
        queue.async { [self] in
            let result: Result<ShotRecording, Error>
            do {
                let url = try recordingURL(id)
                guard fileManager.fileExists(atPath: url.path) else {
                    throw ShotArchiveError.missingRecording
                }
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                guard let size = attributes[.size] as? NSNumber,
                      size.int64Value > 0, size.int64Value <= Int64(Self.maximumRecordingBytes) else {
                    throw ShotArchiveError.recordingTooLarge
                }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard data.count <= Self.maximumRecordingBytes else {
                    throw ShotArchiveError.recordingTooLarge
                }
                let recording = try JSONDecoder().decode(ShotRecording.self, from: data)
                try recording.validate()
                result = .success(recording)
            } catch { result = .failure(error) }
            DispatchQueue.main.async { completion(result) }
        }
    }

    func remove(id: String) {
        queue.async { [self] in
            guard let url = try? recordingURL(id) else { return }
            try? fileManager.removeItem(at: url)
        }
    }

    private func recordingURL(_ id: String) throws -> URL {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard !id.isEmpty, id.utf8.count <= 80,
              id.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw ShotArchiveError.invalidID
        }
        return root.appendingPathComponent(id).appendingPathExtension("json")
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        var directory = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
    }

    private func prune(keeping newest: URL) throws {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let contents = try fileManager.contentsOfDirectory(at: root,
            includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles)
        var entries: [(url: URL, bytes: Int, date: Date)] = []
        for url in contents where url.pathExtension == "json" {
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true else { continue }
            entries.append((url, max(0, values.fileSize ?? 0),
                            values.contentModificationDate ?? .distantPast))
        }
        entries.sort {
            if $0.url == $1.url { return false }
            if $0.url == newest { return true }
            if $1.url == newest { return false }
            if $0.date == $1.date { return $0.url.lastPathComponent < $1.url.lastPathComponent }
            return $0.date > $1.date
        }
        var count = 0, bytes = 0
        for entry in entries {
            if count < Self.maximumCount, entry.bytes <= Self.maximumBytes - bytes {
                count += 1; bytes += entry.bytes
            } else {
                try fileManager.removeItem(at: entry.url)
            }
        }
    }
}
