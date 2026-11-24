#!/usr/bin/env bash
# 0.59 bộ 5 thế: pick the pose set of every chapter 2–5 drill → BankLab/UI/DrillPoseData.h. Run after drill_sweep.sh
# (the picks start from the measured reference stroke). Minutes; not part of the CI gate.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$here/../.."
bin="$(mktemp -d)/pose_pick"
"${CXX:-g++}" -O2 -std=c++17 -Wall -Wextra -Werror "$here/pose_pick.cpp" "$root/BankLab/Core/Physics.cpp" \
  "$root/BankLab/Core/ElevatedPhysics.cpp" -o "$bin"
out="$root/BankLab/UI/DrillPoseData.h"
"$bin" "$@" > "$out.tmp" && mv "$out.tmp" "$out"
echo "wrote $out"
