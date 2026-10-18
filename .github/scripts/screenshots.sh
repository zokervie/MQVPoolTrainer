#!/usr/bin/env bash
# Chạy app trên iOS Simulator với các kịch bản -autotest, chụp màn hình và lấy file chẩn đoán.
# Kết quả nằm trong thư mục shots/. Dùng trong job CI `screenshots`.
set -uo pipefail
APP="$1"
BUNDLE="com.example.PoolTrainer"
mkdir -p shots

DEV=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
d = json.load(sys.stdin)["devices"]
cands = [x for rt, xs in d.items() if "iOS" in rt for x in xs if x["name"].startswith("iPhone")]
pro = [x for x in cands if "Pro" in x["name"] and "Max" not in x["name"]]
print((pro or cands)[0]["udid"])')
NAME=$(xcrun simctl list devices | grep "$DEV" | head -1 | sed 's/^ *//')
echo "REPORT: simulator $NAME"
xcrun simctl boot "$DEV" || true
xcrun simctl bootstatus "$DEV" -b > /dev/null
xcrun simctl install "$DEV" "$APP"

shoot() {  # shoot <tên-file> <giây-chờ>
  sleep "$2"
  xcrun simctl io "$DEV" screenshot "shots/$1.png" > /dev/null 2>&1
  # Ảnh chụp theo hướng thiết bị (dọc); xoay về ngang để dễ xem.
  sips -r 90 "shots/$1.png" > /dev/null 2>&1 || true
}

run() {  # run <kịch-bản> <tên> <giây-chờ> [<tên-2> <giây-chờ-2> ...]
  local scen="$1"; shift
  xcrun simctl terminate "$DEV" "$BUNDLE" > /dev/null 2>&1 || true
  xcrun simctl launch "$DEV" "$BUNDLE" -autotest "$scen" > /dev/null
  while [ $# -ge 2 ]; do shoot "$1" "$2"; shift 2; done
}

run home        01-home 4
run free        02-free-firstperson 5
run overview    03-overview 5
run effect      04-effect-expanded 5
run locked      05-locked 5
run shotlab     06-shotlab 5
run drill:thang-xa 07-drill-thang-xa 5
run shot:thang-xa  08-shot-start 2.3  09-shot-mid 0.7  10-shot-feedback 8
run shot:keo-bi-ve-giua 11-draw-mid 3.0  12-draw-feedback 8

# Lấy file chẩn đoán (app ghi sau ~9 s của mỗi kịch bản; kịch bản cuối vẫn đang chạy nên chờ thêm).
sleep 3
DATA=$(xcrun simctl get_app_container "$DEV" "$BUNDLE" data 2>/dev/null || true)
if [ -n "$DATA" ]; then cp "$DATA"/Documents/autotest-*.txt shots/ 2>/dev/null || true; fi
ls -la shots
for f in shots/autotest-*.txt; do [ -f "$f" ] && { echo "REPORT: ==== $f"; sed 's/^/REPORT:   /' "$f"; }; done
