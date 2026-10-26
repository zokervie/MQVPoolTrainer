#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
device_id=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; a=[d for g in json.load(sys.stdin)["devices"].values() for d in g if d.get("isAvailable") and "iPhone" in d["name"]]; a.sort(key=lambda d:d["state"]!="Booted"); assert a,"No available iPhone Simulator"; print(a[0]["udid"])')
xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
# Keep an xcresult per attempt; never accept a previous test run as evidence.
result_path="$PWD/build/ui-tests-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild test -project ZokerPoolTrainer.xcodeproj -scheme ZokerPoolTrainer \
  -configuration Debug -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$PWD/build/Simulator" -resultBundlePath "$result_path" \
  -only-testing:ZokerPoolTrainerUITests/InteractionTests \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee build/ui-tests.log
