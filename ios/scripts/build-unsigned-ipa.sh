#!/usr/bin/env bash
# Build PoolTrainer.ipa KHÔNG KÝ (dùng chung cho GitHub Actions và Codemagic).
# Cài lên iPhone bằng ESign / Sideloadly / AltStore – công cụ đó ký lại bằng Apple ID của bạn.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
mkdir -p build
xcodebuild -project PoolTrainer.xcodeproj -scheme PoolTrainer -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/dd \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build > build/xcodebuild.log 2>&1 \
  || { grep -E "error:" build/xcodebuild.log | sed -E 's#^.*/ios/##' | sort -u | head -150 > build/errors.txt || true
         cat build/errors.txt; tail -n 30 build/xcodebuild.log
         if [ -n "${GITHUB_ACTIONS:-}" ]; then
           [ -s build/errors.txt ] || tail -n 40 build/xcodebuild.log > build/errors.txt
           echo "::error title=xcodebuild::$(sed 's/%/%25/g' build/errors.txt | awk '{printf "%s%%0A", $0}')"
         fi
         exit 1; }
grep -E "warning:" build/xcodebuild.log | sort -u | head -40 || true
APP=build/dd/Build/Products/Release-iphoneos/PoolTrainer.app
test -d "$APP"
rm -rf build/Payload && mkdir -p build/Payload
cp -R "$APP" build/Payload/
(cd build && rm -f PoolTrainer.ipa && zip -qry PoolTrainer.ipa Payload)
ls -lh build/PoolTrainer.ipa
