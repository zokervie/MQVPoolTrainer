#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p build
xcodebuild -project ZokerPoolTrainer.xcodeproj -scheme ZokerPoolTrainer -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$PWD/build/Simulator" CODE_SIGNING_ALLOWED=NO build \
  2>&1 | tee build/simulator-build.log
echo 'Build Simulator hoàn tất. Mở project trong Xcode, chọn Simulator và bấm Run để thử giao diện.'
