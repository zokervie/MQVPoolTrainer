#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
python3 Tools/check_suite_lists.py
python3 Tools/check_resources.py
python3 Tools/build_zupe_lab.py
python3 Tools/check_zupe_integration.py
python3 Tools/check_gestures.py
node Research/ZUPE/tests/test.mjs
for suite in elevated-cue golden-calibration integration; do
  node "Research/ZUPE/tests/$suite.test.mjs"
done
mkdir -p build/physics-checks
if [ -n "${CXX:-}" ]; then compiler=("$CXX"); elif command -v xcrun >/dev/null 2>&1; then compiler=(xcrun clang++); else compiler=(c++); fi
for suite in Physics Prediction Practice Contact ExtendedPractice Research Elevated KickSearch Calibration Cushion3D Presentation SpinTransfer PresentationPolicy Determinism Literature CueClearance DiamondSystem; do
  "${compiler[@]}" -std=c++17 -O2 -Wall -Wextra -Wpedantic -Werror "Tests/${suite}Tests.cpp" BankLab/Core/Physics.cpp BankLab/Core/ElevatedPhysics.cpp -o "build/physics-checks/$suite"
  "build/physics-checks/$suite"
done
