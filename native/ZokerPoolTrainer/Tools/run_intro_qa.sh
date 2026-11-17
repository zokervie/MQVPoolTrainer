#!/bin/bash
# 0.44.1 M5: đầu dò intro trên Simulator (cần app đã build: Verify-on-Mac.command).
# Dùng: bash Tools/run_intro_qa.sh <thư-mục-kết-quả>
# Cổng: ảnh tại 0,5 · 1 · 2 · 3 · 4,5 s (khung 3D + lớp 2D) có độ sáng TB ≥ 0,08 và ≥ 15 % điểm ảnh > 0,10; không khung nào
# dài quá 33 ms trong intro (số đo Simulator). Thêm 5 ảnh màn hình thật (simctl) cùng thời điểm để đối chiếu.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
out=${1:?thư mục kết quả}; mkdir -p "$out"
app=build/Simulator/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app
bundle=com.maiquocviet.BankLabS
device=${ZOKER_SIM:-$(xcrun simctl list devices booted -j | python3 -c "import json,sys;d=[x for v in json.load(sys.stdin)['devices'].values() for x in v if x['state']=='Booted'];print(d[0]['udid'] if d else '')")}
[ -n "$device" ] || { echo "BLOCKED: chưa có Simulator đang chạy"; exit 2; }
xcrun simctl install "$device" "$app"
data=$(xcrun simctl get_app_container "$device" "$bundle" data)
rm -rf "$data/Documents/intro-qa"
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
xcrun simctl launch "$device" "$bundle" --intro-qa "$@" >/dev/null
prev=0; for t in 0.5 1.0 2.0 3.0 4.5; do sleep "$(python3 -c "print(max(0,$t-$prev))")"; prev=$t; xcrun simctl io "$device" screenshot "$out/screen-${t}s.png" >/dev/null 2>&1 || true; done
for _ in $(seq 1 20); do [ -f "$data/Documents/intro-qa/summary.json" ] && break; sleep 1; done
xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
[ -f "$data/Documents/intro-qa/summary.json" ] || { echo "FAIL: đầu dò intro không ghi summary.json"; exit 1; }
cp "$data/Documents/intro-qa/"* "$out/"
python3 - "$out/summary.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
for s in sorted(r['stills'],key=lambda s:s['t']): print(f"t={s['t']:.1f}s  sáng TB {s['mean']:.3f}  điểm >0,10: {s['lit']*100:.0f}%  {s['mode']}  {'PASS' if s['pass'] else 'FAIL'}")
frames_ok=r['maxFrameMs']<=33.0
print(f"khung dài nhất {r['maxFrameMs']:.1f} ms trên {r['frames']} khung: {'PASS' if frames_ok else 'FAIL'} (≤ 33 ms, Simulator)")
ok=r['result']=='PASS' and frames_ok
print(('PASS' if ok else 'FAIL')+' intro probe · chế độ '+r['mode'])
raise SystemExit(0 if ok else 1)
PY
