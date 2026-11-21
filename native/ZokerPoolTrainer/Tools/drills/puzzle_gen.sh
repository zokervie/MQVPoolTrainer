#!/usr/bin/env bash
# 0.50 Thế bí: generate puzzles → Tools/drills/puzzles.json → BankLab/UI/PuzzleCatalogData.h.
# Slow (≈ 1 h on 2 cores). Usage: Tools/drills/puzzle_gen.sh            (default seeds and counts)
#        or collect only:          Tools/drills/puzzle_gen.sh --collect a.jsonl b.jsonl …
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$here/../.."
if [ "${1:-}" != "--collect" ]; then
  out="$(mktemp -d)"; bin="$out/puzzle_gen"
  "${CXX:-g++}" -O2 -std=c++17 -Wall -Wextra -Werror "$here/puzzle_gen.cpp" "$root/BankLab/Core/Physics.cpp" \
    "$root/BankLab/Core/ElevatedPhysics.cpp" -o "$bin"
  ( "$bin" pot 10 101 > "$out/pot.jsonl"; "$bin" reach 12 202 > "$out/reach.jsonl" ) &
  ( "$bin" straight 7 303 > "$out/straight.jsonl"; "$bin" position 7 404 2 > "$out/pos2.jsonl"
    "$bin" position 7 505 0 > "$out/pos0.jsonl"; "$bin" position 6 606 1 > "$out/pos1.jsonl"; "$bin" hide 7 707 > "$out/hide.jsonl" ) &
  wait
  set -- --collect "$out"/*.jsonl
fi
shift
python3 "$here/collect_puzzles.py" "$@"
python3 "$here/gen_catalog.py"
