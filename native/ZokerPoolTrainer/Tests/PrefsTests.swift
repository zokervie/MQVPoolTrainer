import Foundation

/// 0.45 M5.4 / 0.46 M2: frozen UserDefaults key strings (a renamed key silently resets a player's setting) and the
/// language picker (Tiếng Việt + English; the five machine drafts only with Phòng thí nghiệm on).
@main struct PrefsTests {
    struct Failure: Error, CustomStringConvertible { var description: String }
    static func main() throws {
        var checks = 0
        func check(_ ok: Bool, _ what: String) throws { guard ok else { throw Failure(description: what) }; checks += 1 }
        let frozen: [(String, String)] = [(Prefs.language, "appLanguage042"), (Prefs.introSeen, "intro043Seen"), (Prefs.introEnabled, "introEnabled043"),
            (Prefs.tutorialSeen, "tutorial044Seen"), (Prefs.tutorialEnabled, "tutorialEnabled044"), (Prefs.tutorialHints, "tutorialHints0441"),
            (Prefs.tutorialHintSeen("spin"), "tutorialHint0441.spin"), (Prefs.recentPlay, "recentPlay046"), (Prefs.legacyLessonStars, "lessonStars035"),
            (Prefs.tuneFPS, "tuneFPS036"), (Prefs.audioEnabled, "poolAudioEnabled"), (Prefs.soundPack, "soundPack041"),
            (Prefs.diagLegacyStatus, "diagLegacyStatus039"), (Prefs.diagReplayNoSlow, "diagReplayNoSlow039"),
            (Prefs.hudOffset(left: true, "Menu"), "hudOffset036-L-Menu"), (Prefs.hudSlot(2, "hudOffset036-R-B"), "hudSlot038-2-hudOffset036-R-B"),
            (Prefs.cueBag(1, "jump"), "cueBag015.1.jump"), (Prefs.cuePreset(2), "cuePreset017-2"), (Prefs.labEnabled, "labEnabled047")]
        for (key, expected) in frozen { try check(key == expected, "frozen key \(expected) (got \(key))") }
        let suite = "PrefsTests-\(UUID().uuidString)"; let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        try check(!Prefs.flag(Prefs.labEnabled, false, d), "lab off by default")
        d.set(true, forKey: Prefs.labEnabled)
        try check(Prefs.flag(Prefs.labEnabled, false, d), "lab switch read back")
        let all = ["en", "vi", "fil", "es", "zh", "ja", "hi"]
        try check(LanguagePicker.codes(all: all, lab: false) == ["vi", "en"], "lab off: Tiếng Việt + English only")
        try check(LanguagePicker.codes(all: all, lab: true) == all, "lab on: all seven")
        print("PASS Prefs: \(checks) checks (frozen keys, Phòng thí nghiệm default off, language picker vi+en)")
    }
}
