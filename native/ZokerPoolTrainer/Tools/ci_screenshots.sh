#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/screenshots
xcrun simctl list devices available -j > build/screenshots/devices.json
device_id=$(python3 - <<'PY'
import json
from pathlib import Path
items=[x for group in json.loads(Path('build/screenshots/devices.json').read_text())['devices'].values() for x in group if x.get('isAvailable') and 'iPhone' in x['name']]
if not items:raise SystemExit('No available iPhone Simulator')
items.sort(key=lambda x:x['state']!='Booted')
print(items[0]['udid'])
PY
)
xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
app_path="$PWD/build/Simulator/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app"
xcrun simctl install "$device_id" "$app_path"
data_path=$(xcrun simctl get_app_container "$device_id" com.maiquocviet.BankLabS data)
# Always retain runtime diagnostics even when a probe or visibility check fails.
trap 'qa_exit_code=$?; xcrun simctl spawn "$device_id" log show --last 8m --style compact --predicate '''process == "ZokerPoolTrainer"''' > build/ios-runtime.log 2>&1 || true; exit "$qa_exit_code"' EXIT
# Remove only generated probe records, so a previous run cannot satisfy a gate.
for probe in default hud hud-expanded return spectator audio; do
 rm -f "$data_path/Documents/g1-qa/$probe.json"
done
for camera in g1-default g1-hud g1-hud-expanded g1-return g1-spectator g1-audio overview top aim spin jump table-arc table-classic library cue-library calibration retry orbit-zoom drill-list drill-detail cue-contact observation; do
 xcrun simctl terminate "$device_id" com.maiquocviet.BankLabS 2>/dev/null || true
 if [ "$camera" = g1-hud-expanded ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --g1-hud-qa --spin-detail
 elif [[ "$camera" = g1-* ]]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa "--$camera-qa"
 elif [ "$camera" = cue-contact ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --cue-contact-qa
 elif [ "$camera" = observation ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --observation-qa
 elif [ "$camera" = spin ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --camera-top --spin-detail
 elif [ "$camera" = jump ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --camera-aim --jump-qa
 elif [ "$camera" = retry ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --retry-qa
 elif [ "$camera" = orbit-zoom ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --camera-orbit-qa
 elif [ "$camera" = drill-list ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --drill-list-qa
 elif [ "$camera" = drill-detail ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --drill-detail-qa
 elif [ "$camera" = calibration ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --calibration-qa
 elif [ "$camera" = cue-library ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --cue-library-qa
 elif [ "$camera" = library ]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --library-qa
 elif [[ "$camera" = table-* ]]; then
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa "--$camera"
 else
  xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa "--camera-$camera"
 fi
 # Cold-start shader compilation can outlast the first eight seconds.
 # Retry only first-scene readiness; retain the same final visibility gate.
 for attempt in 1 2 3 4 5 6 7 8; do
  if [ "$camera" = observation ]; then sleep 2; else sleep 8; fi
  xcrun simctl io "$device_id" screenshot "build/screenshots/$camera.png"
  case "$camera" in cue-library|calibration|drill-list) break;; esac
  # Đầu dò G1: chờ tới khi controller thật ghi bản ghi PASS (máy Mac Intel biên dịch shader lâu hơn 8 giây,
  # đầu dò "return" còn phải đánh và chờ bi dừng). Cổng kiểm tra bản ghi phía dưới giữ nguyên.
  # Chưa có bản ghi → thử lại; có rồi thì vẫn phải qua kiểm tra "bàn đã hiện" như các ảnh khác.
  if [[ "$camera" = g1-* ]] && [ ! -f "$data_path/Documents/g1-qa/${camera#g1-}.json" ]; then continue; fi
  if [[ "$camera" = g1-* ]]; then
   python3 - "$data_path/Documents/g1-qa/${camera#g1-}.json" <<'PROBE'
import json,sys
record=json.load(open(sys.argv[1]))
if record.get('result')!='PASS':
 print('FAIL UIKit probe:',json.dumps(record,ensure_ascii=False,indent=2))
 raise SystemExit(1)
PROBE
  fi
  if CAMERA="$camera" python3 - <<'READY'
import os
from PIL import Image
name=os.environ["CAMERA"]
with Image.open(f"build/screenshots/{name}.png") as image:
 pixels=list(image.convert("RGB").resize((256,256)).getdata())
 count=sum(1 for r,g,b in pixels if g>35 and g>r*1.25 and b>25)
 print(f"{name} readiness: {count} cloth-color pixels")
 raise SystemExit(0 if count>=(250 if name=="library" else 1500) else 1)
READY
  then break; fi
 done
done

# Preconditions in the real UIKit controller write these only after passing.
# Their absence is a failure; screenshots alone cannot establish interaction.
data_path=$(xcrun simctl get_app_container "$device_id" com.maiquocviet.BankLabS data)
mkdir -p build/screenshots/g1-qa
cp "$data_path"/Documents/g1-qa/*.json build/screenshots/g1-qa/
python3 - <<'G1'
from pathlib import Path
import json
for name in ['default','hud','hud-expanded','return','spectator','audio']:
 record=json.loads((Path('build/screenshots/g1-qa')/(name+'.json')).read_text())
 assert record['result']=='PASS',record
 print('PASS UIKit G1:',name,record)
G1

# Preserve launch/render diagnostics, including simulator crashes, for visual QA.
xcrun simctl spawn "$device_id" log show --last 8m --style compact --predicate 'process == "ZokerPoolTrainer"' > build/ios-runtime.log 2>&1 || true
python3 - <<'PY'
from pathlib import Path
from PIL import Image
failed=[]
log=Path("build/ios-runtime.log").read_text()
if "MTLDebugValidateMTLPixelFormat" in log:failed.append("Metal pixel format assertion")
for path in sorted(Path("build/screenshots").glob("*.png")):
 with Image.open(path) as image:
  pixels=list(image.convert("RGB").resize((256,256)).getdata())
  cloth=sum(1 for r,g,b in pixels if g>35 and g>r*1.25 and b>25)
  print(f"{path.name}: table-color pixels={cloth}")
  # Full-screen drill catalog intentionally covers the 3D table; verify
  # table visibility only on scenes that are supposed to show the playing surface.
  if path.stem not in ("cue-library","calibration","drill-list") and cloth<(250 if path.stem=="library" else 1500):failed.append(path.name)
if failed:raise SystemExit("Visual QA failed: table not visible in "+", ".join(failed))
PY

