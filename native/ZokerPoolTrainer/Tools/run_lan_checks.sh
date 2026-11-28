#!/bin/bash
# Protocol/authority checks run the production Foundation codec. This is not two-device QA.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p build/lan-checks
xcrun swiftc -warnings-as-errors BankLab/Network/MatchWire.swift Tests/LANWireTests.swift -o build/lan-checks/LANWireTests
build/lan-checks/LANWireTests
# 0.44-mm Nearby Play: room/reconnect/invitation logic (Foundation only; real discovery needs two devices).
xcrun swiftc -warnings-as-errors BankLab/Network/NearbyLobby.swift Tests/NearbyLobbyTests.swift -o build/lan-checks/NearbyLobbyTests
build/lan-checks/NearbyLobbyTests
# 0.44.1: first-launch language follows the device, falls back to Vietnamese.
xcrun swiftc -warnings-as-errors BankLab/UI/L10nDefault0441.swift Tests/L10nDefaultTests.swift -o build/lan-checks/L10nDefaultTests
build/lan-checks/L10nDefaultTests
# 0.59 (owner, video bản 202): every Vietnamese literal of the app comes out English, no "ván mới sau seconds lát" mix.
python3 Tools/i18n/sweep_literals.py > build/lan-checks/l10n-literals.json
python3 Tools/i18n/check_unswizzled.py BankLab   # ZB-045: literals the swizzle never sees
xcrun swiftc -warnings-as-errors BankLab/UI/L10nCore059.swift BankLab/UI/L10nTable059.swift Tests/L10nSweepTests.swift -o build/lan-checks/L10nSweepTests
build/lan-checks/L10nSweepTests BankLab/Assets.xcassets/I18N_en.dataset/i18n.json build/lan-checks/l10n-literals.json Tools/i18n/sweep_allow.txt
# 0.59 A1/A2 (owner 28/11): foul card + turn pill decision.
xcrun swiftc -warnings-as-errors BankLab/UI/MatchNotice059.swift Tests/MatchNoticeTests.swift -o build/lan-checks/MatchNoticeTests
build/lan-checks/MatchNoticeTests
# 0.45 M5: player progress file (player.json, .bak recovery, legacy stars → stable drill ids) and the launch flow.
xcrun swiftc -warnings-as-errors -import-objc-header BankLab/UI/DailyLoop.h BankLab/UI/PlayerStore047.swift BankLab/UI/Achievements058.swift BankLab/UI/ResultNext058c.swift BankLab/UI/DrillIDs047.swift Tests/PlayerStoreTests.swift -o build/lan-checks/PlayerStoreTests
build/lan-checks/PlayerStoreTests
xcrun swiftc -warnings-as-errors BankLab/UI/AppFlow047.swift Tests/AppFlowTests.swift -o build/lan-checks/AppFlowTests
build/lan-checks/AppFlowTests
xcrun swiftc -warnings-as-errors BankLab/UI/Prefs047.swift BankLab/UI/FeatureFlags047.swift BankLab/UI/AppFlow047.swift Tests/PrefsTests.swift -o build/lan-checks/PrefsTests
build/lan-checks/PrefsTests
# 0.57 I1/I3: intro timeline, cue draw-back, FOV punch, music duck, particle budget.
xcrun swiftc -warnings-as-errors BankLab/UI/IntroTiming057.swift Tests/IntroTimingTests.swift -o build/lan-checks/IntroTimingTests
build/lan-checks/IntroTimingTests
# 0.58 L1: the take-back shelf never crosses drills or chapters.
xcrun swiftc -warnings-as-errors BankLab/UI/UndoShelf058.swift Tests/UndoShelfTests.swift -o build/lan-checks/UndoShelfTests
build/lan-checks/UndoShelfTests
# 0.58 L3: pushed screens have a readable "Đóng".
xcrun swiftc -warnings-as-errors BankLab/UI/PushedChrome058.swift Tests/PushedChromeTests.swift -o build/lan-checks/PushedChromeTests
build/lan-checks/PushedChromeTests
# 0.58 L4: the bridge policy glue (wanted tip, solve through the C core).
xcrun swiftc -warnings-as-errors -import-objc-header BankLab/UI/CueClearance.h BankLab/UI/RailBridge058.swift Tests/RailBridgeTests.swift -o build/lan-checks/RailBridgeTests
build/lan-checks/RailBridgeTests
# 0.58 P2: Thách bạn — 15-character ring challenge (C core + Swift wrapper).
xcrun swiftc -warnings-as-errors -import-objc-header Tests/RingChallengeBridge.h BankLab/UI/RingChallenge058.swift Tests/RingChallengeTests.swift -o build/lan-checks/RingChallengeTests
build/lan-checks/RingChallengeTests
# 0.58 T1–T4: auto-advance, achievement record, medal tiers, match tally.
xcrun swiftc -warnings-as-errors BankLab/UI/Achievements058.swift BankLab/UI/ResultNext058c.swift Tests/AchievementsTests.swift -o build/lan-checks/AchievementsTests
build/lan-checks/AchievementsTests
# 0.58: our own QR encoder (no CoreImage on the flyer path) is read back by an independent decoder.
xcrun swiftc -warnings-as-errors BankLab/UI/QRCode058.swift Tests/QRCodeTests.swift -o build/lan-checks/QRCodeTests
build/lan-checks/QRCodeTests
# 0.58c item 5: camera policy around the own stroke (Wi-Fi) and the aim camera once per turn.
xcrun swiftc -warnings-as-errors BankLab/UI/MatchCameraPolicy058c.swift Tests/MatchCameraPolicyTests.swift -o build/lan-checks/MatchCameraPolicyTests
build/lan-checks/MatchCameraPolicyTests
# 0.58c item 6: the result box's main button (exam) and the ring auto-next timing.
xcrun swiftc -warnings-as-errors BankLab/UI/ResultNext058c.swift Tests/ResultNextTests.swift -o build/lan-checks/ResultNextTests
build/lan-checks/ResultNextTests
# 0.58c: Petemoss + OFL.txt stay in Copy Bundle Resources (and UIAppFonts); the IPA step re-checks the packed .ipa.
python3 Tools/check_bundle_fonts.py
# 0.58d item 4: the provisional 15 Ball score on the point chips.
xcrun swiftc -warnings-as-errors BankLab/UI/PointChipsLogic058d.swift Tests/PointChipsTests.swift -o build/lan-checks/PointChipsTests
build/lan-checks/PointChipsTests
