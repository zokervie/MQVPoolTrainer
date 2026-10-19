#!/usr/bin/env bash
# Nối máy Mac vào quy trình tự động (chạy MỘT LẦN trên Mac):
#   curl -fsSL https://raw.githubusercontent.com/zokervie/MQVPoolTrainer/feature/zoker-mvp/Tools/mac/setup-runner.sh | bash
# Sau đó: mỗi lần có code mới trên feature/zoker-mvp, workflow "Mac – build & cài iPhone" chạy NGAY TRÊN MÁY NÀY
# bằng Xcode của bạn (miễn phí, không xếp hàng), và nếu iPhone đang cắm/ghép Wi-Fi thì tự cài + mở app.
set -euo pipefail
REPO="zokervie/MQVPoolTrainer"
DIR="$HOME/actions-runner-zoker"
LABEL="zoker-mac"
say() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }

[ "$(uname)" = "Darwin" ] || { echo "Script này chỉ chạy trên macOS."; exit 1; }

say "1/6 Kiểm tra Xcode"
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Chưa có Xcode đầy đủ. Cài Xcode từ App Store, mở một lần để đồng ý giấy phép, rồi chạy lại script."; exit 1
fi
xcodebuild -version | head -1

say "2/6 Cài công cụ (Homebrew, gh, xcodegen)"
command -v brew >/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
brew list gh >/dev/null 2>&1 || brew install gh
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen

say "3/6 Đăng nhập GitHub (tài khoản có quyền admin repo $REPO)"
gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web

say "4/6 Mã nhóm Apple (Team ID) để ký app cài lên iPhone"
echo "Xcode → Settings → Accounts → chọn Apple ID → Team (Apple ID thường cũng có 'Personal Team')."
echo "Team ID là chuỗi 10 ký tự, thấy trong Keychain (chứng chỉ 'Apple Development: … (XXXXXXXXXX)') hoặc developer.apple.com."
TEAM=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)
[ -n "$TEAM" ] && echo "Tìm thấy Team ID trong Keychain: $TEAM"
read -r -p "Team ID [${TEAM:-bỏ trống = chỉ build, không cài iPhone}]: " IN < /dev/tty || true
TEAM="${IN:-$TEAM}"
if [ -n "$TEAM" ]; then gh variable set APPLE_TEAM_ID --repo "$REPO" --body "$TEAM"; echo "Đã lưu APPLE_TEAM_ID."; fi

say "5/6 Cài GitHub Actions runner (nhãn $LABEL) thành dịch vụ chạy nền"
mkdir -p "$DIR" && cd "$DIR"
if [ ! -f ./config.sh ]; then
  ARCH=$([ "$(uname -m)" = "arm64" ] && echo arm64 || echo x64)
  URL=$(gh api repos/actions/runner/releases/latest --jq ".assets[] | select(.name | test(\"osx-${ARCH}-.*tar.gz$\")) | .browser_download_url")
  curl -fsSL "$URL" | tar xz
fi
[ -f .runner ] && { ./svc.sh stop >/dev/null 2>&1 || true; ./svc.sh uninstall >/dev/null 2>&1 || true; ./config.sh remove --token "$(gh api -X POST repos/$REPO/actions/runners/remove-token --jq .token)" || true; }
TOKEN=$(gh api -X POST "repos/$REPO/actions/runners/registration-token" --jq .token)
./config.sh --unattended --replace --url "https://github.com/$REPO" --token "$TOKEN" \
  --name "$(scutil --get ComputerName 2>/dev/null || hostname)-zoker" --labels "$LABEL"
./svc.sh install && ./svc.sh start
gh variable set MAC_RUNNER --repo "$REPO" --body on

say "6/6 An toàn cho repo công khai"
# Không để người lạ chạy code trên máy bạn qua Pull Request từ fork: bắt duyệt mọi người ngoài.
gh api -X PUT "repos/$REPO/actions/permissions/fork-pr-contributor-approval" -f approval_policy=all_external_contributors >/dev/null 2>&1 \
  && echo "Đã bật: PR từ người ngoài phải được bạn duyệt mới chạy workflow." \
  || echo "Không đặt được tự động — vào Settings → Actions → General → Fork pull request workflows → 'Require approval for all external contributors'."

cat <<MSG

✅ Xong. Runner "$LABEL" đang chạy nền (tự bật lại khi đăng nhập).
   • Giữ Mac thức khi cần build: System Settings → Battery/Energy → ngăn ngủ khi cắm sạc (hoặc chạy: caffeinate -dims &)
   • Cài thẳng lên iPhone: cắm cáp một lần, bấm "Tin cậy", bật Developer Mode trên iPhone (Settings → Privacy & Security).
     Sau đó Xcode → Window → Devices → "Connect via network" để cài qua Wi-Fi.
   • Gỡ: cd "$DIR" && ./svc.sh uninstall && ./config.sh remove && gh variable delete MAC_RUNNER --repo $REPO
MSG
