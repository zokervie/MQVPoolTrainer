import Foundation
import Observation

/// Cài đặt người dùng, lưu trong UserDefaults.
@MainActor @Observable
final class AppSettings {
    var effectsVolume: Double
    var muted: Bool
    var spatialAudio: Bool
    var headphoneMode: Bool
    var leftHanded: Bool
    /// Độ cao mắt so với mặt bàn (m), 0,15–0,30.
    var eyeHeight: Double
    /// Hệ số đổi điểm màn hình → mm (màn hiệu chỉnh).
    var mmPerPoint: Double
    var seenLockHint: Bool
    /// Cơ đang dùng (`CueSpec.library`).
    var cueId: String

    private let defaults = UserDefaults.standard

    init() {
        let d = UserDefaults.standard
        effectsVolume = d.object(forKey: "effectsVolume") as? Double ?? 0.8
        muted = d.bool(forKey: "muted")
        spatialAudio = d.object(forKey: "spatialAudio") as? Bool ?? true
        headphoneMode = d.bool(forKey: "headphoneMode")
        leftHanded = d.bool(forKey: "leftHanded")
        eyeHeight = d.object(forKey: "eyeHeight") as? Double ?? 0.22
        // Mặc định: 1 điểm ≈ 1/163 inch (đa số iPhone); người dùng hiệu chỉnh lại.
        mmPerPoint = d.object(forKey: "mmPerPoint") as? Double ?? 25.4 / 163
        seenLockHint = d.bool(forKey: "seenLockHint")
        cueId = d.string(forKey: "cueId") ?? "playing"
    }

    func save() {
        defaults.set(effectsVolume, forKey: "effectsVolume")
        defaults.set(muted, forKey: "muted")
        defaults.set(spatialAudio, forKey: "spatialAudio")
        defaults.set(headphoneMode, forKey: "headphoneMode")
        defaults.set(leftHanded, forKey: "leftHanded")
        defaults.set(eyeHeight, forKey: "eyeHeight")
        defaults.set(mmPerPoint, forKey: "mmPerPoint")
        defaults.set(seenLockHint, forKey: "seenLockHint")
        defaults.set(cueId, forKey: "cueId")
    }
}
