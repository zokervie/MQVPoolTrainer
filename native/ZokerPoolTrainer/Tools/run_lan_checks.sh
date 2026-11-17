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
xcrun swiftc -warnings-as-errors BankLab/UI/Prefs047.swift Tests/PrefsTests.swift -o build/lan-checks/PrefsTests
build/lan-checks/PrefsTests
