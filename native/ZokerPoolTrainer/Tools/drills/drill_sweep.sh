#!/usr/bin/env bash
# Full drill search → Tools/drills/measured.json → BankLab/UI/DrillCatalogData.h. Run after editing catalog.py.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; root="$here/../.."
python3 "$here/gen_catalog.py" >/dev/null           # geometry first (measured values kept)
bin="$(mktemp -d)/drill_sweep"
"${CXX:-g++}" -O2 -std=c++17 -Wall -Wextra -Werror "$here/drill_sweep.cpp" "$root/BankLab/Core/Physics.cpp" \
  "$root/BankLab/Core/ElevatedPhysics.cpp" -o "$bin"
"$bin" "$@" | python3 -c '
import json, sys
path = sys.argv[1]
m = json.load(open(path)) if __import__("os").path.exists(path) else {}
for line in sys.stdin:
    r = json.loads(line); k = r.pop("key"); m[k] = r; print(k, r["percent"], "%", "window", r["window"], "°", flush=True)
json.dump(m, open(path, "w"), indent=1, sort_keys=True); open(path, "a").write("\n")
' "$here/measured.json"
python3 "$here/gen_catalog.py"
