#!/usr/bin/env python3
"""Merges puzzle_gen output (JSON lines) into Tools/drills/puzzles.json, then re-centres and re-rates every route on
the exact stored values (puzzle_measure) until the table is stable. Per room: best route's make rate high → low
(easier first), capped per room, keys p-<room>-<nn>. A puzzle stays only if its best route is made 30–90 %."""
import json, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CAP = {1: 6, 2: 6, 3: 10, 4: 6, 5: 6, 6: 14, 7: 4, 8: 6}
PATH = os.path.join(HERE, "puzzles.json")


def arrange(rows):
    out = []
    for room in sorted(CAP):
        mine = [r for r in rows if r["room"] == room and r["solutions"] and 30 <= r["solutions"][0]["percent"] <= 90]
        mine.sort(key=lambda r: (-r["solutions"][0]["percent"], -len(r["solutions"])))
        for n, r in enumerate(mine[:CAP[room]]):
            r["key"] = "p-%d-%02d" % (room, n + 1)
            out.append(r)
    return out


def save(rows):
    json.dump(rows, open(PATH, "w"), indent=1, sort_keys=True)
    open(PATH, "a").write("\n")
    subprocess.run([sys.executable, os.path.join(HERE, "gen_catalog.py")], check=True, stdout=subprocess.DEVNULL)


def measure():
    exe = os.path.join(tempfile.mkdtemp(), "puzzle_measure")
    subprocess.run([os.environ.get("CXX", "g++"), "-O2", "-std=c++17", os.path.join(HERE, "puzzle_measure.cpp"),
                    os.path.join(ROOT, "BankLab/Core/Physics.cpp"), os.path.join(ROOT, "BankLab/Core/ElevatedPhysics.cpp"),
                    "-o", exe], check=True)
    out = subprocess.run([exe], check=True, capture_output=True, text=True).stdout
    return [json.loads(l) for l in out.splitlines() if l.startswith("{")]


rows = []
for path in sys.argv[1:]:
    for line in open(path):
        if line.strip().startswith("{"):
            rows.append(json.loads(line))
for r in rows:   # reach / hide: a route is how the cue ball reached ball 1 (BLPuzzleRoute)
    if r["style"] in ("reach", "hide"):
        best = {}
        for s in r["solutions"]:
            s["sig"] = s["sig"] // 100 * 100
            if s["sig"] not in best or s["percent"] > best[s["sig"]]["percent"]:
                best[s["sig"]] = s
        r["solutions"] = sorted(best.values(), key=lambda s: -s["percent"])
    if r["style"] == "reach":
        rails = r["solutions"][0]["sig"] // 100
        r["skill"] = 7 if rails <= 1 else (8 if rails == 2 else 9)   # mirror / plus / corner-5
        r["room"] = 6
rows = arrange(rows)
for rnd in range(3):
    save(rows)
    fixes = {(m["key"], m["i"]): m for m in measure()}
    changed = False
    for r in rows:
        keep = []
        for i, s in enumerate(r["solutions"]):
            m = fixes.get((r["key"], i))
            if not m or not m["ok"]:
                changed = True
                continue
            if m["angle"] != s["angle"] or m["percent"] != s["percent"]:
                changed = True
            s["angle"], s["percent"], s["hint"] = m["angle"], m["percent"], m["hint"]
            keep.append(s)
        keep.sort(key=lambda s: -s["percent"])
        r["solutions"] = [s for s in keep if s["percent"] >= 10][:4]
    rows = arrange(rows)
    if not changed:
        break
for r in rows:   # skill follows the best route after re-rating
    if r["style"] == "reach":
        rails = r["solutions"][0]["sig"] // 100
        r["skill"] = 7 if rails <= 1 else (8 if rails == 2 else 9)
save(rows)
print("puzzles.json:", len(rows), "puzzles;", {room: sum(1 for r in rows if r["room"] == room) for room in CAP})
