#!/bin/bash
# 0.44.1 M2: tranh trên tường — đầu dò --wall-photo-qa trên Simulator (cần app đã build: Verify-on-Mac.command).
# Dùng: bash Tools/run_wall_photo_qa.sh <thư-mục-kết-quả>
# Cổng: mỗi ảnh trong mỗi phòng có ảnh: điểm cháy (luma > 0,95) < 2 %, luma trung bình 0,35–0,65,
# độ tương phản (độ lệch chuẩn luma) >= 60 % của ảnh gốc. Ghi summary.json + ảnh room-NN / photo-NN-KK.
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
rm -rf "$data/Documents/wall-qa"
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
xcrun simctl launch "$device" "$bundle" --visual-qa --wall-photo-qa "$@" >/dev/null
for _ in $(seq 1 240); do [ -f "$data/Documents/wall-qa/summary.json" ] && break; sleep 1; done
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
[ -f "$data/Documents/wall-qa/summary.json" ] || { echo "FAIL: đầu dò không ghi summary.json"; exit 1; }
cp "$data/Documents/wall-qa/"* "$out/"
python3 - "$out/summary.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
for m in r['measures']:
    print(f"phòng {m['space']} ảnh {m['photo']:>2}: cháy {m['blown']*100:5.2f}%  sáng TB {m['mean']:.3f}  tương phản {m['contrastRatio']*100:5.1f}%  {'PASS' if m['pass'] else 'FAIL'}")
print(f"{r['result']} wall photos: {r['photos']} ảnh / {r['roomsWithPhotos']} phòng có ảnh")
raise SystemExit(0 if r['result']=='PASS' else 1)
PY
