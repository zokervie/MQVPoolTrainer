#!/bin/bash
# XCTest UI tests. Since 0.59 (ZB-035) the work is done by Tools/ui_test_supervisor.py: a watchdog kills a test that hangs
# (CI 45927685914: one test sat 58 min although xcodebuild had a 900 s allowance), the remaining tests carry on,
# and every failed or hung test is re-run once alone (pass = FLAKY warning, fail again = red).
# CI shards: UI_SHARD=k/n = every n-th test of InteractionTests in source order, starting at k. Unset = all tests.
# UI_BUDGET = seconds for the whole shard (default 4800 for a shard, 5400 for the full suite).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
if [ -n "${UI_SHARD:-}" ]; then budget="${UI_BUDGET:-4800}"; else budget="${UI_BUDGET:-5400}"; fi
# Screenshots leave a long-running SceneKit process behind: the supervisor reboots the Simulator before every attempt
# and before every retry, so XCTest starts on a clean boot and one destination, without parallel clones.
exec python3 Tools/ui_test_supervisor.py ${UI_SHARD:+--shard "$UI_SHARD"} --budget "$budget" --test-max "${UI_TEST_MAX:-720}" --stall "${UI_STALL:-600}"
