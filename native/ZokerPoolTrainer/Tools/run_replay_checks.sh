#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p build/replay-checks
# Use the actual production value model, without UIKit-only screen controllers.
python3 - <<'PY'
from pathlib import Path
source=Path('BankLab/UI/Models.swift').read_text()
model=source[source.index('struct BallState:'):source.index('struct Layout:')]
Path('build/replay-checks/BallState.swift').write_text('import Foundation\n'+model)
PY
xcrun swiftc -warnings-as-errors build/replay-checks/BallState.swift BankLab/UI/ShotArchive.swift BankLab/UI/ReplayDirector.swift Tests/ReplayRecordingTests.swift -o build/replay-checks/ReplayRecordingTests
build/replay-checks/ReplayRecordingTests
