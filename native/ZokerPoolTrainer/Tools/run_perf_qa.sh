#!/bin/bash
# 0.44-mm: đo giật trên Simulator — chế độ chơi (trận 9 bi, cú phá 7 m/s) và xem lại 1× của chính cú đó.
# Dùng: bash Tools/run_perf_qa.sh <thư-mục-kết-quả> [tham số app thêm, ví dụ -tuneFramePacing039 NO | --computer-qa]
# Cần app đã build (Verify-on-Mac.command). Simulator không thay thiết bị thật: so trước/sau trên cùng máy, cùng cú.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
out=${1:?thư mục kết quả}; shift || true
mkdir -p "$out"
app=build/Simulator/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app
bundle=com.zokervie.billiards
device=${ZOKER_SIM:-$(xcrun simctl list devices booted -j | python3 -c "import json,sys;d=[x for v in json.load(sys.stdin)['devices'].values() for x in v if x['state']=='Booted'];print(d[0]['udid'] if d else '')")}
[ -n "$device" ] || { echo "BLOCKED: chưa có Simulator đang chạy"; exit 2; }
xcrun simctl install "$device" "$app"
data=$(xcrun simctl get_app_container "$device" "$bundle" data)
rm -rf "$data/Documents/perf-qa"
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
xcrun simctl launch "$device" "$bundle" --visual-qa --perf-qa -qaSimFPS 60 "$@" >/dev/null
want=3; for a in "$@"; do [ "$a" = "--computer-qa" ] && want=1; done
for _ in $(seq 1 150); do
  n=$(ls "$data/Documents/perf-qa" 2>/dev/null | grep -c '\.json$' || true)
  [ "$n" -ge "$want" ] && break
  sleep 1
done
sleep 2
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
cp "$data/Documents/perf-qa/"*.json "$out/" 2>/dev/null || { echo "FAIL: không có số đo"; exit 1; }
python3 Tools/perf_judder.py "$out"/*.json
