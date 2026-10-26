#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
if ! command -v python3 >/dev/null 2>&1; then
  echo 'Cần cài Python 3 (có sẵn qua Homebrew hoặc Python.org)'; exit 2
fi
python3 assemble_full_source.py "$@"
