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
# 0.45 M5: player progress file (player.json, .bak recovery, legacy stars → stable drill ids) and the launch flow.
xcrun swiftc -warnings-as-errors -import-objc-header BankLab/UI/DailyLoop.h BankLab/UI/PlayerStore047.swift BankLab/UI/DrillIDs047.swift Tests/PlayerStoreTests.swift -o build/lan-checks/PlayerStoreTests
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
