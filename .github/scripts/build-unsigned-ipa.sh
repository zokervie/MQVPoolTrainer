#!/usr/bin/env bash
# Build bản Release cho iPhone thật, KHÔNG ký, đóng gói thành .ipa để tự ký khi cài
# (Sideloadly / AltStore / ký lại bằng chứng chỉ riêng). Dùng chung cho Codemagic và GitHub Actions.
# Dùng: build-unsigned-ipa.sh [số-build]
set -euo pipefail
BUILD_NO="${1:-1}"
command -v xcodegen > /dev/null || brew install xcodegen > /dev/null
xcodegen generate --quiet
agvtool new-version -all "$BUILD_NO" > /dev/null
VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml | head -1)
mkdir -p build/ipa
xcodebuild archive \
  -project PoolTrainer.xcodeproj -scheme PoolTrainer -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/PoolTrainer.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  > build/archive.log 2>&1 || { grep -E "error:|BUILD FAILED|ARCHIVE FAILED" build/archive.log | head -30; exit 1; }
APP=build/PoolTrainer.xcarchive/Products/Applications/PoolTrainer.app
test -d "$APP"
rm -rf build/Payload && mkdir -p build/Payload && cp -R "$APP" build/Payload/
( cd build && zip -qry "ipa/PoolTrainer-${VERSION}-${BUILD_NO}-unsigned.ipa" Payload )
IPA=$(ls build/ipa/*.ipa)
echo "IPA: $IPA ($(du -h "$IPA" | cut -f1)), version ${VERSION} (${BUILD_NO}), bundle $(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist"), archs $(lipo -archs "$APP/PoolTrainer")"
