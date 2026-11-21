#!/bin/bash
# 0.46 M3: 4 họ bàn — đầu dò --table-family-qa trên Simulator (cần app đã build: Verify-on-Mac.command).
# Dùng: bash Tools/run_table_family_qa.sh <thư-mục-kết-quả>
# Chụp Z-Arena / Z-Heritage / Z-Loft / Z-Club (phối 1) trong phòng chuẩn (space 0), camera tổng quan nghiêng thấy chân bàn.
# Cổng: mỗi ảnh có điểm cháy (luma > 0,95) < 2 %. Ghi summary.json + family-<họ>.png.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
out=${1:?thư mục kết quả}; shift || true
mkdir -p "$out"
app=build/Simulator/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app
bundle=com.maiquocviet.BankLabS
device=${ZOKER_SIM:-$(xcrun simctl list devices booted -j | python3 -c "import json,sys;d=[x for v in json.load(sys.stdin)['devices'].values() for x in v if x['state']=='Booted'];print(d[0]['udid'] if d else '')")}
[ -n "$device" ] || { echo "BLOCKED: chưa có Simulator đang chạy"; exit 2; }
xcrun simctl install "$device" "$app"
data=$(xcrun simctl get_app_container "$device" "$bundle" data)
rm -rf "$data/Documents/table-qa"
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
xcrun simctl launch "$device" "$bundle" --visual-qa --table-family-qa "$@" >/dev/null
for _ in $(seq 1 120); do [ -f "$data/Documents/table-qa/summary.json" ] && break; sleep 1; done
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
[ -f "$data/Documents/table-qa/summary.json" ] || { echo "FAIL: đầu dò không ghi summary.json"; exit 1; }
cp "$data/Documents/table-qa/"* "$out/"
python3 - "$out/summary.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
for m in r['measures']:
    print(f"{m['family']:<11} ({m['look']}): cháy {m['blown']*100:5.2f}%  sáng TB {m['mean']:.3f}  {'BLANK' if m.get('blank') else ('PASS' if m['pass'] else 'FAIL')}")
if r['result']=='NOT_RUN':
    print("NOT_RUN: ảnh chụp đen (độ sáng TB < ngưỡng) — không phải số đo; không báo PASS"); raise SystemExit(3)
print(f"{r['result']} table families: {r['families']} họ, phòng {r['space']}")
raise SystemExit(0 if r['result']=='PASS' and r['families']==4 else 1)
PY
