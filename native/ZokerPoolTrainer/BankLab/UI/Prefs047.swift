import Foundation

/// 0.45 M5.4 — every UserDefaults key in one place. The STRINGS ARE FROZEN: they are what is already saved on players'
/// devices (changing one silently resets that setting). New code uses `Prefs.x`; old call sites move over as the files
/// are touched (list of the ones still using bare strings: Docs/ASYNC-CON-LAI.md, section "Prefs").
/// Player progress (stars, attempts, streak) is NOT here: it lives in PlayerStore (player.json).
enum Prefs {
    // App / flow
    static let language = "appLanguage042"
    static let introSeen = "intro043Seen"
    static let introEnabled = "introEnabled043"
    static let replayMode = "replayMode059"   // 0.59: 0 Điện ảnh (slow-mo on the first pot) · 1 Nhanh (always 1×) · 2 Tắt (no gold "Xem lại cú" chip)
    static let oldIntroNoPost = "oldIntroNoPost"
    static let tutorialSeen = "tutorial044Seen"
    static let tutorialEnabled = "tutorialEnabled044"
    static let tutorialHints = "tutorialHints0441"
    static func tutorialHintSeen(_ id: String) -> String { "tutorialHint0441." + id }
    static let recentPlay = "recentPlay046"
    /// 0.46 M2: Phòng thí nghiệm (Tuỳ chỉnh → Máy). Off by default: engineer tools hidden from every menu.
    static let labEnabled = "labEnabled047"
    /// 0.47: feature flags (FeatureFlags047.swift) — one key per feature, default ON for the test build.
    static func featureFlag(_ name: String) -> String { "ff047." + name }
    /// 0.47 M1: stroke input. Absent = automatic (power bar for a new player, < 50 shots); 1 = power bar; 0 = swipe B.
    static let powerBarMode = "powerBarMode047"
    /// 0.57 I4: ball clicks panned left/right by where they happen on the table, ±3 % pitch variety. Default on.
    static let ballStereo = "ballStereo057"
    /// 0.47 M4: in-play effects (pocket sparks, strike haptic by power, light camera shake on a hard break).
    static let playFX = "playFX047"
    // Legacy progress (read once by the PlayerStore migration, then left untouched for rollback)
    static let legacyLessonStars = "lessonStars035"
    static let practiceHistory = "practiceHistory"
    static let savedShots = "savedShots015"
    static let layouts = "layouts"
    // Physics / engine
    static let physics = "physics"
    static let physicsModelVersion = "physicsModelVersion"
    static let sensitivity = "sensitivity"
    static let squirtRealistic = "squirtRealistic043"
    // Shot / aim
    static let shotKind = "shotKind017"
    static func cuePreset(_ kind: Int) -> String { "cuePreset017-\(kind)" }
    static let aimCameraPitch = "aimCameraPitch014"
    static let aimCameraZoom = "aimCameraZoom013"
    static let guideMode = "guideMode035"
    static let numbersOn = "numbersOn033"
    static let coachCard = "coachCard044"
    static let leftHanded = "leftHanded022"
    static let autoSaveEveryShot = "autoSaveEveryShot025"
    static let replayCamera = "replayCamera041"
    // Tuning (Tuỳ chỉnh)
    static let tuneBall = "tuneBall036", tuneCloth = "tuneCloth036", tuneLight = "tuneLight036", tuneDiamond = "tuneDiamond036"
    static let tuneShadow = "tuneShadow037", tuneWeave = "tuneWeave038", tuneGuideColor = "tuneGuideColor038", tuneGuideWidth = "tuneGuideWidth038"
    static let tuneWeavePitch = "tuneWeavePitch040"
    static let tuneMaxPower = "tuneMaxPower036", tuneFPS = "tuneFPS036", tuneScale = "tuneScale036"
    static let tuneHUDFade = "tuneHUDFade037", tuneEffectLock = "tuneEffectLock037", tunePredictFirst = "tunePredictFirst037", tuneVolume = "tuneVolume037"
    static let tuneHUDScale = "tuneHUDScale038", tuneHUDAlpha = "tuneHUDAlpha038", tuneAutoNumbers = "tuneAutoNumbers038", tuneGuideSkill = "tuneGuideSkill038"
    static let tuneAimPitch = "tuneAimPitch038", tuneAimZoom = "tuneAimZoom038", tuneAimFOV = "tuneAimFOV038"
    static let tuneRealShadow = "tuneRealShadow039", tuneCueFade = "tuneCueFade039", tuneFramePacing = "tuneFramePacing039"
    static let tuneCueGhost = "tuneCueGhost040", tunePowerFX = "tunePowerFX041", tuneFrameRange = "tuneFrameRange045"
    static func hudOffset(left: Bool, _ name: String) -> String { "hudOffset036-" + (left ? "L" : "R") + "-" + name }
    static func hudSlot(_ n: Int, _ offsetKey: String) -> String { "hudSlot038-\(n)-" + offsetKey }
    // Table / equipment / look
    static let clothTintIndex = "clothTintIndex", clothTintMigrated = "clothTintMigrated040", clothWear = "clothWear021"
    static let ballWear = "ballWear021", tableLook = "tableLook015", tableDefault = "tableDefault034", tableSpace = "tableSpace034"
    static let activeBag = "activeBag015"
    static func cueBag(_ bag: Int, _ role: String) -> String { "cueBag015.\(bag).\(role)" }
    static let highGraphics = "highGraphics018", exposure = "zokerExposure017", legacyCue = "legacyCue0441"
    static let scoreboardStyle = "scoreboardStyle040"
    // Sound
    static let audioEnabled = "poolAudioEnabled", soundPack = "soundPack041", musicVolume = "musicVolume042", broadcastSound = "broadcastSound042"
    // Match / network
    static let shotClock = "shotClock040", raceTo = "raceTo029", computerLevel = "computerLevel040", lockstep = "lockstep044"
    static let playerName0 = "playerName0", playerName1 = "playerName1"
    static let spectatorCam = "spectatorCam042", opponentShotCard = "opponentShotCard042", loupes = "loupes042"
    static let lanPeerIdentity = "lanPeerIdentity018", onlineRelayURL = "onlineRelayURL019"
    // Diagnostics / A-B (Phòng thí nghiệm)
    /// 0.49c G8 / G4 (frozen): Luật phá 3 bi (giải đấu), dải quang phổ lực khi vuốt (chẩn đoán).
    static let puzzleGhostPath = "puzzleGhostPath051"
    static let threeBallBreak = "threeBallBreak049", diagPowerSpectrum = "diagPowerSpectrum049"
    static let diagLegacyStatus = "diagLegacyStatus039", diagReplayNoSlow = "diagReplayNoSlow039"
    // QA only (set by launch arguments -key value in CI; never by the player)
    static let qaSimFPS = "qaSimFPS", qaPerfDelay = "qaPerfDelay", qaPhotoGlow = "qaPhotoGlow", qaPhotoTarget = "qaPhotoTarget", qaPhotoWhite = "qaPhotoWhite"

    static func flag(_ key: String, _ fallback: Bool, _ d: UserDefaults = .standard) -> Bool { d.object(forKey: key) as? Bool ?? fallback }
    /// Phòng thí nghiệm on? (engineer tools + machine-translated languages visible)
    static var lab: Bool { flag(labEnabled, false) }
}

/// 0.46 M2: the language picker shows Tiếng Việt + English; the five machine-translated drafts only with the Lab on
/// (until a native speaker reviews them). A saved choice of a draft language keeps working either way.
enum LanguagePicker {
    static let reviewed = ["vi", "en"]
    static func codes(all: [String], lab: Bool) -> [String] { lab ? all : reviewed.filter { all.contains($0) } }
}
