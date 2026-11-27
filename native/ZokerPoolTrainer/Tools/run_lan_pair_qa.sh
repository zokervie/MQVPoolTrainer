#!/bin/bash
# 0.59 (sổ lỗi ZB-002/003/004/005/010/011): two Simulators play 9 Ball against each other through a LOCAL relay
# (MultipeerConnectivity cannot pair two Simulators — NGHIEM-THU-0.44-MM). Guest-side checks, written by the app
# (LANPairQA) to Documents/perf-qa/lan-pair-guest.json:
#   soundRepeats = 0 (no impact heard twice), strikeAngleErrorMaxDeg < 1 on the guest's own strokes,
#   breakCueOnNormalTurn = 0, statusContradictions = [], rewinds = 0 (picture clock never runs back), shots done.
# The Mac display must be awake (the script holds it with caffeinate): with the display off the Simulators stall.
# Usage: Tools/run_lan_pair_qa.sh [app path]   (ZOKER_QA_EXTRA="--sound-dedupe-off-qa" = the "before" run)   (default: build/Simulator Debug app; build it first)
set -euo pipefail
[ -z "${ZK_CAFFEINATED:-}" ] && exec env ZK_CAFFEINATED=1 caffeinate -dimsu "$0" "$@"
cd "$(dirname "$0")/.."
APP="${1:-build/Simulator/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app}"
BUNDLE=com.zokervie.billiards
ROOM=QAPAZR22; SHOTS="${ZOKER_QA_SHOTS:-6}"; SECONDS_MAX="${ZOKER_QA_SECONDS:-240}"   # online alphabet has no I, O, 0, 1
RELAY_PORT=8787; RELAY="ws://127.0.0.1:$RELAY_PORT"
[ -d "$APP" ] || { echo "BLOCKED: no app at $APP"; exit 2; }
mkdir -p build/lan-pair

# 1. local relay (same code as production, Cloudflare Workers runtime in local mode)
if ! curl -s -o /dev/null "http://127.0.0.1:$RELAY_PORT/"; then
  (cd Server/relay && npx -y wrangler@4 dev --local --port $RELAY_PORT > ../../build/lan-pair/relay.log 2>&1 &)
  for _ in $(seq 1 60); do curl -s -o /dev/null "http://127.0.0.1:$RELAY_PORT/" && break; sleep 1; done
fi
(cd Server/relay && RELAY=$RELAY node test/e2e.mjs) || { echo "FAIL relay not reachable"; exit 1; }

# 2. two iPhone Simulators
pick() { xcrun simctl list devices available -j | python3 -c "import json,sys; a=[d for g in json.load(sys.stdin)['devices'].values() for d in g if d.get('isAvailable') and d['name']=='$1']; print(a[0]['udid'] if a else '')"; }
HOST=$(pick "iPhone 17 Pro"); GUEST=$(pick "iPhone 17")
[ -n "$HOST" ] && [ -n "$GUEST" ] || { echo "BLOCKED: need Simulators 'iPhone 17 Pro' and 'iPhone 17'"; exit 2; }
for d in $HOST $GUEST; do
  xcrun simctl boot "$d" 2>/dev/null || true; xcrun simctl bootstatus "$d" -b >/dev/null
  xcrun simctl terminate "$d" $BUNDLE 2>/dev/null || true
  xcrun simctl install "$d" "$APP"
  rm -rf "$(xcrun simctl get_app_container "$d" $BUNDLE data)/Documents/perf-qa"
done
ENVS=(SIMCTL_CHILD_ZOKER_QA_RELAY=$RELAY SIMCTL_CHILD_ZOKER_QA_ROOM=$ROOM SIMCTL_CHILD_ZOKER_QA_SHOTS=$SHOTS SIMCTL_CHILD_ZOKER_QA_SECONDS=$SECONDS_MAX)
env "${ENVS[@]}" xcrun simctl launch --terminate-running-process --console-pty "$HOST" $BUNDLE --lan-host-qa --visual-qa ${ZOKER_QA_EXTRA:-} > build/lan-pair/host.log 2>&1 &
sleep 2
env "${ENVS[@]}" xcrun simctl launch --terminate-running-process --console-pty "$GUEST" $BUNDLE --lan-join-qa --visual-qa ${ZOKER_QA_EXTRA:-} > build/lan-pair/guest.log 2>&1 &

# 2b. optional recording for the night tour: video of both Simulators + a screenshot every 3 s (ZOKER_QA_RECORD_DIR)
RECPIDS=""
if [ -n "${ZOKER_QA_RECORD_DIR:-}" ]; then
  mkdir -p "$ZOKER_QA_RECORD_DIR"
  xcrun simctl io "$HOST" recordVideo --codec=h264 --force "$ZOKER_QA_RECORD_DIR/host.mp4" > /dev/null 2>&1 & RECPIDS="$!"
  xcrun simctl io "$GUEST" recordVideo --codec=h264 --force "$ZOKER_QA_RECORD_DIR/guest.mp4" > /dev/null 2>&1 & RECPIDS="$RECPIDS $!"
  ( i=0; while true; do sleep 3; i=$((i+3)); xcrun simctl io "$HOST" screenshot "$ZOKER_QA_RECORD_DIR/host-t$(printf %04d $i).png" 2>/dev/null; xcrun simctl io "$GUEST" screenshot "$ZOKER_QA_RECORD_DIR/guest-t$(printf %04d $i).png" 2>/dev/null; done ) & RECPIDS="$RECPIDS $!"
fi
# 3. wait for the shots, then judge the guest report
GJ="$(xcrun simctl get_app_container "$GUEST" $BUNDLE data)/Documents/perf-qa/lan-pair-guest.json"
HJ="$(xcrun simctl get_app_container "$HOST" $BUNDLE data)/Documents/perf-qa/lan-pair-host.json"
for _ in $(seq 1 "$SECONDS_MAX"); do
  sleep 1
  [ -f "$GJ" ] && [ -f "$HJ" ] || continue
  done_shots=$(python3 -c "import json; print(json.load(open('$GJ'))['shots'] + json.load(open('$HJ'))['shots'])" 2>/dev/null || echo 0)
  [ "$done_shots" -ge "$SHOTS" ] && sleep 12 && break
done
cp "$GJ" build/lan-pair/guest.json 2>/dev/null || true; cp "$HJ" build/lan-pair/host.json 2>/dev/null || true
[ -n "$RECPIDS" ] && { kill -INT $RECPIDS 2>/dev/null; wait $RECPIDS 2>/dev/null; }
xcrun simctl terminate "$HOST" $BUNDLE 2>/dev/null || true; xcrun simctl terminate "$GUEST" $BUNDLE 2>/dev/null || true
python3 - <<'PY'
import json, sys
try:
    g = json.load(open('build/lan-pair/guest.json')); h = json.load(open('build/lan-pair/host.json'))
except Exception as e:
    print('FAIL lan pair: no report', e); sys.exit(1)
checks = [
    ('connected', g.get('connected') is True and h.get('connected') is True),
    ('strokes played (host %d + guest %d)' % (h['shots'], g['shots']), h['shots'] + g['shots'] >= 2),
    ('guest played its own stroke (%d)' % g['ownStrikes'], g['ownStrikes'] >= 1),
    ('ZB-004 no impact heard twice (%d of %d)' % (g['soundRepeats'], g['soundsPlayed']), g['soundRepeats'] == 0 and g['soundsPlayed'] > 0),
    ('ZB-003 own-stroke cue angle error %.2f°' % g['strikeAngleErrorMaxDeg'], g['strikeAngleErrorMaxDeg'] < 1.0),
    ('ZB-002 break cue on a normal turn (%d)' % g['breakCueOnNormalTurn'], g['breakCueOnNormalTurn'] == 0),
    ('ZB-010/011 status contradictions %s' % g['statusContradictions'], not g['statusContradictions']),
    ('ZB-005 picture clock rewinds (%d)' % g['rewinds'], g['rewinds'] == 0),
]
bad = [n for n, ok in checks if not ok]
for n, ok in checks: print(('PASS ' if ok else 'FAIL ') + n)
print('REPORT lan pair: lockstep shots %s, fallbacks %s' % (g.get('lockstepShots'), g.get('fallbacks')))
print(('PASS' if not bad else 'FAIL') + ' LANPair: %d checks' % len(checks))
sys.exit(1 if bad else 0)
PY
