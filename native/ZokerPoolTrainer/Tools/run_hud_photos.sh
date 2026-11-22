#!/bin/bash
# 0.56 K5: ảnh HUD (UI test testHudPhoto056) trên 3 máy: iPhone SE (3rd gen), iPhone 17 Pro Max, iPad Pro 11". Dùng: bash Tools/run_hud_photos.sh <thẻ> <thư-mục-kết-quả>
set -uo pipefail
cd -- "$(dirname -- "$0")/.."
tag=${1:?thẻ}; out=${2:?thư mục kết quả}; mkdir -p "$out"
for dev in "Zoker SE3" "iPhone 17 Pro Max" "iPad Pro 11-inch (M5)"; do
  id=$(xcrun simctl list devices available | grep -F "$dev (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  [ -n "$id" ] || { echo "NOT RUN: không có simulator $dev"; continue; }
  xcrun simctl boot "$id" 2>/dev/null || true
  rb=build/hud-$tag-$id.xcresult; rm -rf "$rb"
  xcodebuild test -project ZokerPoolTrainer.xcodeproj -scheme ZokerPoolTrainer -configuration Debug -destination "platform=iOS Simulator,id=$id" -derivedDataPath "$PWD/build/Simulator" -resultBundlePath "$rb" -parallel-testing-enabled NO -only-testing:ZokerPoolTrainerUITests/InteractionTests/testHudPhoto056 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO >/dev/null 2>&1
  tmp=$(mktemp -d); xcrun xcresulttool export attachments --path "$rb" --output-path "$tmp" >/dev/null 2>&1
  f=$(ls "$tmp"/*.png 2>/dev/null | head -1); [ -n "$f" ] && cp "$f" "$out/hud-$(echo "$dev" | tr ' ()"' '_')-$tag.png" || echo "FAIL: không có ảnh $dev"
done
ls "$out"
