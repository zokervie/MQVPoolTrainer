#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo 'Cần Xcode trên Mac để build. Mở Xcode và cài iOS platform trước.' >&2
  exit 1
fi
if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  echo 'Chưa có iOS SDK. Chọn bản Xcode đầy đủ trong Xcode → Settings → Locations.' >&2
  exit 1
fi
python3 Tools/check_resources.py
mkdir -p build dist
xcodebuild -project ZokerPoolTrainer.xcodeproj -scheme ZokerPoolTrainer -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$PWD/build/DerivedData" \
  ${BUILD_NUMBER:+CURRENT_PROJECT_VERSION=$BUILD_NUMBER} \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build 2>&1 | tee build/device-build.log
app_path="$PWD/build/DerivedData/Build/Products/Release-iphoneos/ZokerPoolTrainer.app"
if [ ! -d "$app_path" ]; then echo 'Không tìm thấy app sau build.' >&2; exit 1; fi
stage_dir="$(mktemp -d "$PWD/build/package.XXXXXX")"
trap 'rm -rf -- "$stage_dir"' EXIT
mkdir -p "$stage_dir/Payload"
ditto "$app_path" "$stage_dir/Payload/ZokerPoolTrainer.app"
if /usr/bin/codesign -dv "$stage_dir/Payload/ZokerPoolTrainer.app" >/dev/null 2>&1; then
  echo 'App có chữ ký ngoài dự kiến. Dừng đóng gói để kiểm tra.' >&2
  exit 1
fi
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_path/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app_path/Info.plist")
name="ZokerPoolTrainer-${version}-Build${build}.ipa"
rm -f "$PWD"/dist/*.ipa
output_path="$PWD/dist/$name"
package_path="$stage_dir/$name"
(cd "$stage_dir" && /usr/bin/zip -q -r "$package_path" Payload)
mv -f "$package_path" "$output_path"
/usr/bin/unzip -tq "$output_path"
ipa_bytes=$(stat -f%z "$output_path")
awk -v bytes="$ipa_bytes" 'BEGIN { printf "Dung lượng IPA: %.2f MB\n", bytes/1000000 }'
if [ "$ipa_bytes" -gt 100000000 ]; then
  echo 'IPA vượt ngân sách 100 MB; cần xem lại tài nguyên trước khi cài thử.' >&2
fi
echo "Đã xuất IPA chưa ký: $output_path"
echo 'Ký lại bằng chứng chỉ cá nhân hợp lệ trước khi cài.'
