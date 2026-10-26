#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo 'Cần Xcode đầy đủ trên macOS để biên dịch IPA.' >&2
  exit 1
fi
# The offline Lab bundle is already generated; Node is optional for a local build.
python3 Tools/check_resources.py
python3 Tools/check_zupe_integration.py
bash Verify-on-Mac.command
bash Build-Unsigned-IPA.command
