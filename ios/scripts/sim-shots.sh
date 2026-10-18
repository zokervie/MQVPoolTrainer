#!/usr/bin/env bash
# Chạy app trên iOS Simulator theo các kịch bản tự động và chụp màn hình (dùng trong CI để kiểm tra giao diện, bắt crash).
set -uo pipefail
cd "$(dirname "$0")/.."
OUT=build/shots; mkdir -p "$OUT"
xcodegen generate >/dev/null
xcodebuild -project PoolTrainer.xcodeproj -scheme PoolTrainer -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/sim CODE_SIGNING_ALLOWED=NO build > build/sim.log 2>&1 \
  || { grep -E "error:" build/sim.log | head -50; exit 1; }
APP=build/sim/Build/Products/Release-iphonesimulator/PoolTrainer.app
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
  local procs; procs=$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null)
  if echo "$procs" | grep "$BID" >/dev/null; then echo "$name: OK" >> "$STATUS"; else echo "$name: CRASH/EXIT" >> "$STATUS"; fi
}

run 01-menu "" 7
run 03-predator "table:predator-apex9,drill:a-half" 7
run 04-feedback "table:diamond-proam9-tight,drill:a-half,wait:1,shoot:0.45" 9
run 05-diamond7 "table:diamond-proam7,view2d,drill:c-x" 7
run 07-break "view3d,table:mrsung-acurra9,free:9,wait:3,shoot:1" 11
run 09-realistic "table:brunswick-gc6,realistic,drill:a-ladder" 7
run 10-editor "editor" 6
cat "$STATUS"
# nhật ký crash nếu có
ls ~/Library/Logs/DiagnosticReports 2>/dev/null | grep -i pool && cp ~/Library/Logs/DiagnosticReports/*PoolTrainer* "$OUT"/ 2>/dev/null
for f in "$OUT"/*.png; do sips -s format jpeg -s formatOptions 70 -Z 1400 "$f" --out "${f%.png}.jpg" >/dev/null && rm "$f"; done
ls -la "$OUT"
