#!/bin/bash
# "Đêm thử" — virtual player tour. Plays the app scene by scene on Simulators (2 device sizes x vi/en), records one video
# per run, takes key-moment screenshots, then plays a Wi-Fi pair (two Simulators, video + screenshots of both), and
# writes everything under build/night/<stamp>/ with a manifest and automatic blank-frame findings.
# The independent reviewer (Docs/DEM-THU-REVIEW.md) reads that folder WITHOUT knowing what was fixed and writes bugs to the ZB ledger.
# Usage: Tools/run_night_tour.sh short|full [app path]
#   short = iPhone 17 Pro, vi+en, 6 scenes (~10 min).  full = iPhone 17 Pro + iPhone 17, vi+en, all scenes + Wi-Fi pair (~60 min).
# The Mac display must stay awake (caffeinate below): with the display off the Simulators stall.
set -uo pipefail
[ -z "${ZK_CAFFEINATED:-}" ] && exec env ZK_CAFFEINATED=1 caffeinate -dimsu "$0" "$@"
cd "$(dirname "$0")/.."
MODE="${1:-short}"
APP="${2:-build/Simulator/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app}"
BUNDLE=com.zokervie.billiards
[ -d "$APP" ] || { echo "BLOCKED: no app at $APP"; exit 2; }
STAMP="$(date +%Y%m%d-%H%M%S)"; OUT="build/night/$STAMP"; mkdir -p "$OUT"
MANIFEST="$OUT/manifest.tsv"; printf 'kind\tdevice\tlang\tscene\tsecond\tfile\n' > "$MANIFEST"
echo "commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown) mode=$MODE app=$APP started=$(date -u +%FT%TZ)" > "$OUT/RUN.txt"

pick() { xcrun simctl list devices available -j | python3 -c "import json,sys; a=[d for g in json.load(sys.stdin)['devices'].values() for d in g if d.get('isAvailable') and d['name']=='$1']; print(a[0]['udid'] if a else '')"; }

# scene = name:launch flags.  Same flags as Tools/ci_screenshots.sh, so each scene is a known-good entry point.
SCENES_SHORT=("table-aim:--camera-aim" "drill-list:--drill-list-qa" "drill-detail:--drill-detail-qa" "cue-library:--cue-library-qa" "calibration:--calibration-qa" "retry:--retry-qa")
SCENES_FULL=("table-overview:--camera-overview" "table-aim:--camera-aim" "table-top:--camera-top" "spin:--camera-top --spin-detail" "jump:--camera-aim --jump-qa"
  "library:--library-qa" "cue-library:--cue-library-qa" "calibration:--calibration-qa" "retry:--retry-qa" "drill-list:--drill-list-qa"
  "drill-detail:--drill-detail-qa" "cue-contact:--cue-contact-qa" "observation:--observation-qa" "orbit:--camera-orbit-qa" "tutorial:--tutorial-qa" "hud:--g1-hud-qa --spin-detail")
if [ "$MODE" = full ]; then SCENES=("${SCENES_FULL[@]}"); DEVICES=("iPhone 17 Pro" "iPhone 17"); else SCENES=("${SCENES_SHORT[@]}"); DEVICES=("iPhone 17 Pro"); fi

tour() { # $1 device name, $2 language code
  local name="$1" lang="$2" udid loc dir vid vpid t0
  udid=$(pick "$name"); [ -n "$udid" ] || { echo "SKIP: no Simulator '$name'"; return; }
  [ "$lang" = vi ] && loc=vi_VN || loc=en_US
  dir="$OUT/$(echo "$name" | tr ' ' '_')-$lang"; mkdir -p "$dir"
  xcrun simctl boot "$udid" 2>/dev/null || true; xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl terminate "$udid" $BUNDLE 2>/dev/null || true; xcrun simctl install "$udid" "$APP"
  xcrun simctl io "$udid" recordVideo --codec=h264 --force "$dir/tour.mp4" > "$dir/record.log" 2>&1 & vpid=$!
  t0=$(date +%s)
  for s in "${SCENES[@]}"; do
    local sname="${s%%:*}" flags="${s#*:}"
    xcrun simctl terminate "$udid" $BUNDLE 2>/dev/null || true
    xcrun simctl launch "$udid" $BUNDLE --visual-qa --l10n-real $flags -AppleLanguages "($lang)" -AppleLocale "$loc" >> "$dir/launch.log" 2>&1
    for sec in 5 10 16; do
      sleep $((sec - ${prev:-0})); prev=$sec
      xcrun simctl io "$udid" screenshot "$dir/$sname-t$sec.png" 2>/dev/null \
        && printf 'shot\t%s\t%s\t%s\t%s\t%s\n' "$name" "$lang" "$sname" "$sec" "$dir/$sname-t$sec.png" >> "$MANIFEST"
    done; prev=0
    printf 'scene\t%s\t%s\t%s\t%s\t%s\n' "$name" "$lang" "$sname" "$(( $(date +%s) - t0 ))" "$dir/tour.mp4" >> "$MANIFEST"
  done
  xcrun simctl terminate "$udid" $BUNDLE 2>/dev/null || true
  kill -INT $vpid 2>/dev/null; wait $vpid 2>/dev/null
  xcrun simctl spawn "$udid" log show --last 90m --style compact --predicate 'process == "ZokerPoolTrainer"' > "$dir/runtime.log" 2>&1 || true
}
for d in "${DEVICES[@]}"; do for l in vi en; do echo "== tour $d $l"; tour "$d" "$l"; done; done

# Wi-Fi pair with video + screenshots every 3 s on both Simulators (the pair script reads these env vars).
if [ "$MODE" = full ]; then
  echo "== Wi-Fi pair"; mkdir -p "$OUT/wifi-pair"
  ZOKER_QA_RECORD_DIR="$PWD/$OUT/wifi-pair" ZOKER_QA_SHOTS=8 ZK_CAFFEINATED=1 Tools/run_lan_pair_qa.sh "$APP" > "$OUT/wifi-pair/result.txt" 2>&1 || true
  for f in "$OUT"/wifi-pair/*.png "$OUT"/wifi-pair/*.mp4; do [ -f "$f" ] && printf 'pair\t-\t-\twifi\t-\t%s\n' "$f" >> "$MANIFEST"; done
  cp build/lan-pair/host.json build/lan-pair/guest.json "$OUT/wifi-pair/" 2>/dev/null || true
fi

# Automatic first pass: blank / black / white frames (the reviewer sees everything else).
python3 - "$OUT" <<'PY'
import sys, glob
from pathlib import Path
try:
    from PIL import Image
except Exception:
    print("PIL missing: blank-frame check NOT RUN"); raise SystemExit(0)
out = Path(sys.argv[1]); bad = []; n = 0
for p in sorted(out.rglob("*.png")):
    n += 1
    with Image.open(p) as im:
        px = list(im.convert("L").resize((64, 64)).getdata())
    spread = max(px) - min(px)
    if spread < 12: bad.append((p.relative_to(out), spread))
lines = ["# Auto findings (blank-frame check)", f"frames: {n}", f"blank/flat frames: {len(bad)}"]
lines += [f"- {p} (contrast spread {s})" for p, s in bad]
(out / "auto-findings.md").write_text("\n".join(lines) + "\n")
print("\n".join(lines))
PY
echo "finished=$(date -u +%FT%TZ)" >> "$OUT/RUN.txt"
echo "DONE $OUT"
