#!/usr/bin/env bash
# Nghiệm thu cục bộ trên Mac: chạy đúng các cổng như CI (Tools/run_acceptance.py), không build giả.
# Dùng: bash Tools/accept_local.sh            (đủ: C++, Simulator, ảnh, UI test, IPA không ký)
#       bash Tools/accept_local.sh --portable (chỉ cổng C++ portable, vài phút)
set -uo pipefail
cd "$(dirname "$0")/.."
[ "$(uname)" = "Darwin" ] || { echo "BLOCKED: cần macOS + Xcode"; exit 2; }
command -v xcodebuild >/dev/null || { echo "BLOCKED: thiếu xcodebuild"; exit 2; }
free_gb=$(df -g . | awk 'NR==2{print $4}')
[ "${free_gb:-0}" -ge 15 ] || { echo "BLOCKED: ổ đĩa còn ${free_gb} GB, cần >= 15 GB"; exit 2; }
echo "branch=$(git rev-parse --abbrev-ref HEAD) sha=$(git rev-parse --short HEAD)"
echo "xcode=$(xcodebuild -version | tr '\n' ' ')  (CI dùng Xcode 16.4 — kết quả local chưa thay được CI)"
git status --porcelain | head -5
python3 Tools/run_acceptance.py "$@"
code=$?
latest=$(ls -t dist/ACCEPTANCE-*.json 2>/dev/null | head -1)
[ -n "$latest" ] && python3 - "$latest" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
print('STATUS',r['status'])
for s in r['stages']:print(' ',s['status'].ljust(8),s['name'])
print('Ảnh/log:','build/screenshots  build/acceptance/')
PY
echo "exit=$code"
exit $code
