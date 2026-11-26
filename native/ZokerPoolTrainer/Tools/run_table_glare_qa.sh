#!/bin/bash
# 0.49c G5: % pixel gần trắng (>= 250) trên bàn, 12 bàn, dựng offscreen (SCNRenderer + Metal). Dùng: bash Tools/run_table_glare_qa.sh <thư-mục-kết-quả>
# Cần app Debug đã build. Simulator tối hơn máy thật: số để so trước/sau và xếp hạng, KHÔNG thay kiểm trên thiết bị.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
out=${1:?thư mục kết quả}; mkdir -p "$out"
app=build/Simulator/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app; bundle=com.zokervie.billiards
device=${ZOKER_SIM:-$(xcrun simctl list devices booted -j | python3 -c "import json,sys;d=[x for v in json.load(sys.stdin)['devices'].values() for x in v if x['state']=='Booted'];print(d[0]['udid'] if d else '')")}
[ -n "$device" ] || { echo "BLOCKED: chưa có Simulator đang chạy"; exit 2; }
xcrun simctl install "$device" "$app"; data=$(xcrun simctl get_app_container "$device" "$bundle" data)
rm -rf "$data/Documents/glare-qa"; xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
xcrun simctl launch "$device" "$bundle" --visual-qa --table-glare-qa >/dev/null
for _ in $(seq 1 120); do [ -f "$data/Documents/glare-qa/summary.json" ] && break; sleep 1; done
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
[ -f "$data/Documents/glare-qa/summary.json" ] || { echo "FAIL: không có summary.json"; exit 1; }
cp "$data/Documents/glare-qa/"* "$out/"
python3 - "$out/summary.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
for m in r['rows']: print(f"{m['look']:<12} top {m.get('topPercent',-1):6.2f}% (TB {m.get('topMean',-1):5.1f})  oblique {m.get('obliquePercent',-1):6.2f}% (TB {m.get('obliqueMean',-1):5.1f})")
print(r['result'], 'xấu nhất', round(r['worstPercent'],2), '% (cổng', r['gatePercent'], '%)')
raise SystemExit(0 if r['result']=='PASS' else (3 if r['result']=='NOT_RUN' else 1))
PY
