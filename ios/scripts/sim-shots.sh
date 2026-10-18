#!/usr/bin/env bash
# Chạy app trên iOS Simulator theo các kịch bản tự động và chụp màn hình (dùng trong CI để kiểm tra giao diện, bắt crash).
set -uo pipefail
cd "$(dirname "$0")/.."
OUT=build/shots; mkdir -p "$OUT"
xcodegen generate >/dev/null
xcodebuild -project PoolTrainer.xcodeproj -scheme PoolTrainer -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/sim CODE_SIGNING_ALLOWED=NO build > build/sim.log 2>&1 \
  || { grep -E "error:" build/sim.log | head -50; exit 1; }
APP=build/sim/Build/Products/Debug-iphonesimulator/PoolTrainer.app
DT=$(xcrun simctl list devicetypes | grep -Eo "iPhone 1[5-7] Pro \(com[^)]*\)" | head -1 | sed -E 's/.*\((.*)\)/\1/')
RT=$(xcrun simctl list runtimes | grep -Eo "com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+" | tail -1)
echo "device $DT runtime $RT"
UDID=$(xcrun simctl create shot "$DT" "$RT")
xcrun simctl boot "$UDID"; xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
BID=com.zoker.pooltrainer
STATUS="$OUT/status.txt"; : > "$STATUS"

run() { # tên  "kịch bản"  các mốc giây chụp...
  local name=$1 script=$2; shift 2
  xcrun simctl terminate "$UDID" $BID >/dev/null 2>&1
  if [ -n "$script" ]; then xcrun simctl launch "$UDID" $BID -auto "$script" >/dev/null; else xcrun simctl launch "$UDID" $BID >/dev/null; fi
  local t0=0
  for t in "$@"; do
    sleep $(echo "$t - $t0" | bc); t0=$t
    xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name-$t.png" >/dev/null 2>&1
  done
  if xcrun simctl spawn "$UDID" launchctl list | grep -q "$BID"; then echo "$name: OK" >> "$STATUS"; else echo "$name: CRASH/EXIT" >> "$STATUS"; fi
}

run 01-menu "" 5
run 02-card "menucard:c-90" 8
run 03-aim "drill:a-half" 5
run 04-demo "drill:c-draw,wait:2,demo" 5 7.5 11
run 05-sys2d "view2d,drill:s-c5ref" 5
run 06-guide2 "view3d,guide:2,drill:c-30,spin:0.3:0.2" 5
run 07-break "free:9,wait:2,shoot:1" 4.5 5.2 8
run 08-run9 "drill:g-run9,guide:1" 5
cat "$STATUS"
# nhật ký crash nếu có
ls ~/Library/Logs/DiagnosticReports 2>/dev/null | grep -i pool && cp ~/Library/Logs/DiagnosticReports/*PoolTrainer* "$OUT"/ 2>/dev/null
for f in "$OUT"/*.png; do sips -s format jpeg -s formatOptions 70 -Z 1400 "$f" --out "${f%.png}.jpg" >/dev/null && rm "$f"; done
ls -la "$OUT"
