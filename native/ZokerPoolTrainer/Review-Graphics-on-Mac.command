#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/visual-review
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Cần chọn Xcode đầy đủ trước khi chạy."; exit 1
fi
# Prefer an already running iPhone. A Simulator is not required to match the physical phone.
xcrun simctl list devices available -j > build/visual-review/devices.json
review_device=$(python3 - <<'PY'
import json
from pathlib import Path
d=json.loads(Path('build/visual-review/devices.json').read_text())
a=[x for group in d['devices'].values() for x in group if x.get('isAvailable') and 'iPhone' in x['name']]
a.sort(key=lambda x:(x['state']!='Booted',x['name']!='iPhone 14 Pro Max',x['name']))
if not a: raise SystemExit('Chưa có iPhone Simulator. Cài runtime trong Xcode Settings > Platforms/Components.')
print(a[0]['udid'])
PY
)
if ! xcrun simctl boot "$review_device" 2>/dev/null; then
  echo "Dùng Simulator đã mở hoặc đang khởi động."
fi
open -a Simulator
xcrun simctl bootstatus "$review_device" -b
xcodebuild -project ZokerPoolTrainer.xcodeproj -scheme ZokerPoolTrainer -configuration Debug \
  -destination "platform=iOS Simulator,id=$review_device" \
  -derivedDataPath build/visual-review/DerivedData CODE_SIGNING_ALLOWED=NO build \
  > build/visual-review/build.log 2>&1 || {
    tail -60 build/visual-review/build.log
    echo "Build lỗi; xem build/visual-review/build.log"; exit 1;
  }
review_app="build/visual-review/DerivedData/Build/Products/Debug-iphonesimulator/ZokerPoolTrainer.app"
review_bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$review_app/Info.plist")
xcrun simctl install "$review_device" "$review_app"
for review_view in overview top aim; do
  xcrun simctl terminate "$review_device" "$review_bundle" >/dev/null 2>&1 || true
  xcrun simctl launch "$review_device" "$review_bundle" --visual-qa "--camera-$review_view"
  sleep 4
  xcrun simctl io "$review_device" screenshot "build/visual-review/$review_view.png"
done
open build/visual-review
echo "Đã build và chụp ba góc của app thật. Gửi overview.png, top.png, aim.png nếu cần sửa tiếp."
echo "Các ảnh này là Simulator, chưa xác nhận hiệu năng iPhone thật."
