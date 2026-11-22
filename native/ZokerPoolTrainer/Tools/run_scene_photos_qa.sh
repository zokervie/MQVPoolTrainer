#!/bin/bash
# 0.53: ảnh phòng / chi tiết dựng offscreen (SCNRenderer + Metal). Dùng: bash Tools/run_scene_photos_qa.sh <thẻ> <thư-mục-kết-quả>
# Cần app Debug đã build. Ảnh Simulator: để so trước/sau, không thay kiểm trên thiết bị.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
tag=${1:?thẻ}; out=${2:?thư mục kết quả}; mkdir -p "$out"
app=build/Simulator/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app; bundle=com.maiquocviet.BankLabS
device=${ZOKER_SIM:-$(xcrun simctl list devices booted -j | python3 -c "import json,sys;d=[x for v in json.load(sys.stdin)['devices'].values() for x in v if x['state']=='Booted'];print(d[0]['udid'] if d else '')")}
[ -n "$device" ] || { echo "BLOCKED: chưa có Simulator đang chạy"; exit 2; }
xcrun simctl install "$device" "$app"; data=$(xcrun simctl get_app_container "$device" "$bundle" data)
rm -rf "$data/Documents/scene-photos-$tag"; xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
xcrun simctl launch "$device" "$bundle" --visual-qa --scene-photos-qa=$tag >/dev/null
for _ in $(seq 1 240); do [ -f "$data/Documents/scene-photos-$tag/done.txt" ] && break; sleep 1; done
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
[ -f "$data/Documents/scene-photos-$tag/done.txt" ] || { echo "FAIL: chưa xong"; exit 1; }
cp "$data/Documents/scene-photos-$tag/"*.png "$out/"; ls "$out" | wc -l
