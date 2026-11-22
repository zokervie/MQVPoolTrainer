#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
device_id=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; a=[d for g in json.load(sys.stdin)["devices"].values() for d in g if d.get("isAvailable") and "iPhone" in d["name"]]; a.sort(key=lambda d:d["state"]!="Booted"); assert a,"No available iPhone Simulator"; print(a[0]["udid"])')
# Screenshots leave a long-running SceneKit process behind. Start XCTest on a
# clean boot and one destination, without parallel Simulator clones.
xcrun simctl shutdown "$device_id" 2>/dev/null || true
xcrun simctl boot "$device_id"
xcrun simctl bootstatus "$device_id" -b
# Keep an xcresult per attempt; never accept a previous test run as evidence.
# CI shards (UI_SHARD=k/n): every n-th test of InteractionTests, in source order, starting at k. Unset = all tests.
only=(-only-testing:ZokerPoolTrainerUITests/InteractionTests)
log_name=ui-tests
if [ -n "${UI_SHARD:-}" ]; then
  k=${UI_SHARD%/*}; n=${UI_SHARD#*/}
  only=()
  i=0
  while read -r t; do
    if [ $(( i % n )) -eq $(( k - 1 )) ]; then only+=("-only-testing:ZokerPoolTrainerUITests/InteractionTests/$t"); fi
    i=$((i + 1))
  done < <(grep -oE 'func test[A-Za-z0-9_]+\(' UITests/InteractionTests.swift | sed -E 's/func (test[A-Za-z0-9_]+)\(/\1/')
  [ ${#only[@]} -gt 0 ] || { echo "UI_SHARD $UI_SHARD selects no test"; exit 1; }
  echo "UI shard $UI_SHARD: ${#only[@]} of $i tests"
  log_name="ui-tests-shard$k"
fi
result_path="$PWD/build/$log_name-$(date +%Y%m%d-%H%M%S).xcresult"
NSUnbufferedIO=YES xcodebuild test -project ZokerPoolTrainer.xcodeproj -scheme ZokerPoolTrainer \
  -configuration Debug -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$PWD/build/Simulator" -resultBundlePath "$result_path" \
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 \
  -destination-timeout 120 -test-timeouts-enabled YES -default-test-execution-time-allowance 900 -maximum-test-execution-time-allowance 900 \
  "${only[@]}" \
  ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO 2>&1 | tee "build/$log_name.log"
