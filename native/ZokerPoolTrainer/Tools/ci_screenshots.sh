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
# Prefer the acceptance target size class: iPhone 14 Pro Max, then any Pro Max.
items.sort(key=lambda x:(x['name']!='iPhone 14 Pro Max','Pro Max' not in x['name'],x['state']!='Booted'))
print(items[0]['udid'])
PY
)
xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
app_path="$PWD/build/Simulator/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app"
xcrun simctl install "$device_id" "$app_path"
data_path=$(xcrun simctl get_app_container "$device_id" com.maiquocviet.BankLabS data)
# Always retain runtime diagnostics even when a probe or visibility check fails.
capture_runtime() {
 qa_exit_code=$?
 trap - EXIT
 xcrun simctl spawn "$device_id" log show --last 8m --style compact --predicate 'process == "ZokerPoolTrainer"' > build/ios-runtime.log 2>&1 || true
 exit "$qa_exit_code"
}
trap capture_runtime EXIT
# Remove only generated probe records, so a previous run cannot satisfy a gate.
for probe in premium-aim premium-top premium-overview premium-high-aim premium-high-top premium-high-overview default hud hud-expanded return spectator audio; do
 rm -f "$data_path/Documents/g1-qa/$probe.json"
done
launch_camera(){
 local camera="$1"
 xcrun simctl terminate "$device_id" com.maiquocviet.BankLabS 2>/dev/null || true
 if [[ "$camera" = premium-* ]]; then
  mode="${camera##*-}"
  if [[ "$camera" = premium-high-* ]]; then
   xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --premium-qa --premium-high "--camera-$mode"
  else
   xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --visual-qa --premium-qa "--camera-$mode"
  fi
 elif [ "$camera" = g1-hud-expanded ]; then
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
}
for camera in premium-aim premium-top premium-overview premium-high-aim premium-high-top premium-high-overview g1-default g1-hud g1-hud-expanded g1-return g1-spectator g1-audio overview top aim spin jump table-arc table-classic library cue-library calibration retry orbit-zoom drill-list drill-detail cue-contact observation space-0 space-1 space-2 space-3 space-4 space-5 space-6 space-7 space-8 space-9 table-zmax; do
 launch_camera "$camera"
 # Cold-start shader compilation can outlast the first eight seconds.
 # Retry only first-scene readiness; retain the same final visibility gate.
 for attempt in $(seq 1 16); do   # 0.32: up to ~128 s — slow Intel runners missed premium-aim at 64 s
  if [ "$camera" = observation ]; then sleep 2; else sleep 8; fi
  # 0.42b: run 43470155409 — simctl "Error creating the image" (transient display error) aborted the whole stage.
  xcrun simctl io "$device_id" screenshot "build/screenshots/$camera.png" || { echo "$camera: screenshot error at attempt $attempt — retry"; continue; }
  case "$camera" in cue-library|calibration|drill-list) break;; esac
  # Đầu dò G1: chờ tới khi controller thật ghi bản ghi PASS (máy Mac Intel biên dịch shader lâu hơn 8 giây,
  # đầu dò "return" còn phải đánh và chờ bi dừng). Cổng kiểm tra bản ghi phía dưới giữ nguyên.
  # Chưa có bản ghi → thử lại; có rồi thì vẫn phải qua kiểm tra "bàn đã hiện" như các ảnh khác.
  # 0.36b: run 42525378366 — the app was gone (home screen) for premium-high-aim, so the probe never wrote. If the
  # app is no longer running, relaunch it (once per 4 attempts) instead of waiting the full 128 s on a dead process.
  if [ $((attempt % 4)) -eq 0 ] && ! xcrun simctl spawn "$device_id" launchctl list 2>/dev/null | grep -q com.maiquocviet.BankLabS; then
   echo "$camera: app not running at attempt $attempt — relaunch"; launch_camera "$camera"; continue
  fi
  if [[ "$camera" = premium-* ]] && [ ! -f "$data_path/Documents/g1-qa/$camera.json" ]; then continue; fi
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
 # 0.36: cloth is darker now (owner: "nỉ quá sáng"); green-dominant pixels at any brightness above black
 # 0.36: the default table is the grey Z-Max (owner reference), so "green cloth" is no longer a valid gate for any
 # shot — require a rendered scene (not a black, white or blank frame) everywhere.
 count=sum(1 for r,g,b in pixels if 40<(r+g+b)/3<235)
 print(f"{name} readiness: {count} cloth-color pixels")
 # 0.38: run 42678922728 accepted top/jump/space-5/table-zmax at ~1800-2000 px = HUD only, 3D scene not drawn yet
 # (slow runner, shaders still compiling). A drawn table is >=6000 px in every scene; wait for it.
 raise SystemExit(0 if count>=(250 if name=="library" else 4000) else 1)
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
for name in ['premium-aim','premium-top','premium-overview','premium-high-aim','premium-high-top','premium-high-overview','default','hud','hud-expanded','return','spectator','audio']:
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
  cloth=sum(1 for r,g,b in pixels if 40<(r+g+b)/3<235)   # 0.36: colour-agnostic (default cloth is grey)
  print(f"{path.name}: table-color pixels={cloth}")
  # Full-screen drill catalog intentionally covers the 3D table; verify
  # table visibility only on scenes that are supposed to show the playing surface.
  if path.stem not in ("cue-library","calibration","drill-list") and cloth<(250 if path.stem=="library" else 4000):failed.append(path.name)
# 0.37 (owner 0.36 video: concentric bands on the cloth = 8-bit banding). With dithering a flat-looking cloth area has
# short runs of identical values; long identical runs mean visible contour bands. Gate on the top views.
for name in ("premium-top","top"):
 path=Path("build/screenshots")/(name+".png")
 if not path.exists():continue
 with Image.open(path) as image:
  g=image.convert("L");w,h=g.size;box=g.crop((int(w*0.30),int(h*0.35),int(w*0.70),int(h*0.65)));bw,bh=box.size;px=box.load()
  runs=[];
  for y in range(0,bh,max(1,bh//24)):
   n=1
   for x in range(1,bw):
    if px[x,y]==px[x-1,y]:n+=1
    else:runs.append(n);n=1
   runs.append(n)
  mean=sum(runs)/len(runs);longest=max(runs)
  print(f"{name}: cloth banding mean run {mean:.1f} px, longest {longest} px")
  if mean>40:failed.append(name+" (cloth banding)")
if failed:raise SystemExit("Visual QA failed: "+", ".join(failed))
PY

# 0.43: intro "The Golden Break" — screen recording (no audio in simctl) + 4 stills, for review only (never a gate).
set +e
xcrun simctl terminate "$device_id" com.maiquocviet.BankLabS 2>/dev/null
xcrun simctl io "$device_id" recordVideo --codec h264 --force build/screenshots/intro.mp4 > build/intro-record.log 2>&1 &
rec_pid=$!
sleep 1
xcrun simctl launch "$device_id" com.maiquocviet.BankLabS --intro-qa
i=0; for t in 1.2 0.8 1.6 1.4; do sleep "$t"; i=$((i+1)); xcrun simctl io "$device_id" screenshot "build/screenshots/intro-$i.png" 2>/dev/null; done
sleep 3
kill -INT "$rec_pid" 2>/dev/null; wait "$rec_pid" 2>/dev/null
ls -la build/screenshots/intro* 2>/dev/null
set -e
