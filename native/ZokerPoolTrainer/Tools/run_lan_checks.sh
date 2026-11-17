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
