#!/bin/bash
# 0.44.1 M3: ảnh cây cơ — cơ rõ / cơ mờ ở góc ngắm với độ dốc 5°, 42°, 70°, nhìn ngang, và bốn phím cơ (góc phải màn hình).
# Dùng: bash Tools/run_cue_look_qa.sh <thư-mục-kết-quả>   (cần app đã build: Verify-on-Mac.command)
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
out=${1:?thư mục kết quả}; mkdir -p "$out"
app=build/Simulator/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app
bundle=com.zokervie.billiards
device=${ZOKER_SIM:-$(xcrun simctl list devices booted -j | python3 -c "import json,sys;d=[x for v in json.load(sys.stdin)['devices'].values() for x in v if x['state']=='Booted'];print(d[0]['udid'] if d else '')")}
[ -n "$device" ] || { echo "BLOCKED: chưa có Simulator đang chạy"; exit 2; }
xcrun simctl install "$device" "$app"
data=$(xcrun simctl get_app_container "$device" "$bundle" data)
rm -rf "$data/Documents/cue-qa"
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
xcrun simctl launch "$device" "$bundle" --visual-qa --cue-look-qa >/dev/null
for _ in $(seq 1 90); do [ -f "$data/Documents/cue-qa/done.txt" ] && break; sleep 1; done
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
[ -f "$data/Documents/cue-qa/done.txt" ] || { echo "FAIL: đầu dò cơ không xong"; exit 1; }
cp "$data/Documents/cue-qa/"*.png "$out/" && ls "$out" | tr '\n' ' '; echo
