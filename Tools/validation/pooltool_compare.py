#!/usr/bin/env python3
"""Tầng 2 — đối chứng PoolPhysics với pooltool (UPGRADE.md 3.2).

Cách làm (không phụ thuộc mô hình cú đánh của hai engine):
1. pooltool mô phỏng cú đánh. Lấy trạng thái bi ngay SAU cú đánh (vị trí, vận tốc, vận tốc góc).
2. Đưa đúng trạng thái đó vào PoolPhysics (`poolsim`), cùng tham số ma sát/phục hồi đọc từ pooltool.
3. So vị trí dừng, theo nhóm: chỉ chuyển động (motion), có va chạm bi–bi không chạm băng (ballball),
   có băng/lỗ (cushion).

Khớp pooltool KHÔNG chứng minh đúng với bàn thật (UPGRADE.md, nguyên tắc 6).

Dùng:
  python pooltool_compare.py make  <kịch-bản.json> [han2005]   # cần pooltool; han2005 = đổi mô hình băng
  python pooltool_compare.py report <kịch-bản.json> <kết-quả-poolsim.json>
"""
import json
import math
import random
import sys


# ---------------------------------------------------------------------------
# Đổi hệ tọa độ: pooltool (x theo chiều rộng, y theo chiều dài) ↔ PoolPhysics (x dài, y rộng).
# pt = (W − y, x): phép quay 90° cộng tịnh tiến — giữ chiều tay phải nên giữ dấu xoáy.
# ---------------------------------------------------------------------------
def pt_to_ours_pos(p, W):
    return [p[1], W - p[0], p[2]]


def pt_to_ours_vec(v):
    return [v[1], -v[0], v[2]]


def ours_to_pt_xy(x, y, W):
    return (W - y, x)


def event_kinds(system):
    names = []
    for e in getattr(system, "events", []):
        et = getattr(e, "event_type", "")
        names.append(str(getattr(et, "value", et)).lower())
    return names


def cushion_height_ratio(table, R):
    """Chiều cao mũi băng của pooltool (theo đường kính bi), đọc từ đoạn băng thẳng đầu tiên."""
    for attr in ("cushion_height",):
        for obj in (table, getattr(table, "specs", None)):
            if obj is not None and hasattr(obj, attr):
                return float(getattr(obj, attr)) / (2 * R)
    try:
        seg = next(iter(table.cushion_segments.linear.values()))
        return float(seg.height) / (2 * R)
    except Exception:  # noqa: BLE001
        return None


def make_engine(pt, cushion_model):
    """None → mô hình mặc định của pooltool; "han2005" → băng Han (2005), gần với mô hình của PoolPhysics."""
    if cushion_model is None:
        return None, "default"
    import attrs
    from pooltool.physics.engine import PhysicsEngine  # type: ignore
    from pooltool.physics.resolve.resolver import Resolver  # type: ignore
    from pooltool.physics.resolve.ball_cushion.han_2005.model import Han2005Linear, Han2005Circular  # type: ignore
    r = attrs.evolve(Resolver.default(), ball_linear_cushion=Han2005Linear(), ball_circular_cushion=Han2005Circular())
    return PhysicsEngine(resolver=r), "han2005"


def make(path, n_per_category=70, seed=2026, cushion_model=None):
    import numpy as np
    import pooltool as pt
    engine, engine_label = make_engine(pt, cushion_model)

    rng = random.Random(seed)
    table = pt.Table.default()
    W, L = float(table.w), float(table.l)
    probe = pt.Ball.create("cue", xy=(W / 2, L / 4))
    p = probe.params
    R = float(getattr(p, "R", 0.028575))
    m = float(getattr(p, "m", 0.170097))
    g = float(getattr(p, "g", 9.81))

    def param(name, default):
        return float(getattr(p, name, default))

    params = {
        "gravity": g,
        "slidingFriction": param("u_s", 0.2),
        "rollingResistance": param("u_r", 0.01),
        "spinFriction": param("u_sp", 0.044) if not hasattr(p, "u_sp_proportionality") else 0.044,
        # pooltool 0.6 mặc định dùng AlciatoreBallBallFriction μ(v) = a + b·e^(−c·v), a=0,009951, b=0,108,
        # c=1,088 (KHÔNG dùng hằng số u_b). Ở dạng của ta μ0·(r + (1−r)e^(−cv)): μ0 = a+b, r = a/(a+b).
        # Trước đây đặt hằng số u_b=0,05 → lệch 15 mm (nguyên nhân gốc, xem PROGRESS.md).
        "ballBallFriction": 0.117951,
        "ballBallFrictionMinRatio": 0.084365,
        "ballBallFrictionDecay": 1.088,
        "ballBallRestitution": param("e_b", 0.95),
        "cushionRestitution": param("e_c", 0.85),
        "cushionFriction": param("f_c", 0.2),
    }

    shots, counts = [], {"motion": 0, "ballball": 0, "cushion": 0}
    attempts = 0
    while min(counts.values()) < n_per_category and attempts < 4000:
        attempts += 1
        want = min(counts, key=counts.get)
        # Kịch bản trong hệ tọa độ của ta (x dài, y rộng).
        cx, cy = rng.uniform(0.35 * L, 0.65 * L), rng.uniform(0.3 * W, 0.7 * W)
        aim = rng.uniform(0, 2 * math.pi)
        balls = {"cue": pt.Ball.create("cue", xy=ours_to_pt_xy(cx, cy, W))}
        if want != "motion":
            dist = rng.uniform(0.25, 0.5)
            cut = math.radians(rng.uniform(-40, 40))
            ox = cx + dist * math.cos(aim)  # bi mục tiêu nằm trên hướng ngắm, rồi lệch ngang theo góc cắt
            oy = cy + dist * math.sin(aim)
            # dịch bi mục tiêu sang ngang để tạo góc cắt
            off = 2 * R * math.sin(cut)
            ox += -math.sin(aim) * off
            oy += math.cos(aim) * off
            if not (R * 3 < ox < L - R * 3 and R * 3 < oy < W - R * 3):
                continue
            balls["1"] = pt.Ball.create("1", xy=ours_to_pt_xy(ox, oy, W))
        speed = {"motion": rng.uniform(0.4, 1.6), "ballball": rng.uniform(0.6, 2.2), "cushion": rng.uniform(2.0, 4.5)}[want]
        b = rng.uniform(-0.35, 0.35)
        system = pt.System(table=table, balls=balls, cue=pt.Cue(cue_ball_id="cue"))
        system.cue.set_state(V0=speed, phi=(math.degrees(aim) + 90.0) % 360.0, theta=0.0, a=0.0, b=b)
        if engine is None:
            pt.simulate(system, inplace=True)
        else:
            pt.simulate(system, engine=engine, inplace=True)

        kinds = event_kinds(system)
        has_cushion = any("cushion" in k or "pocket" in k for k in kinds)
        has_bb = any("ball_ball" in k for k in kinds)
        cat = "cushion" if has_cushion else ("ballball" if has_bb else "motion")
        if counts[cat] >= n_per_category:
            continue

        initial, final = [], []
        for bid, ball in system.balls.items():
            states = ball.history.states
            # Trạng thái ngay sau cú đánh: trạng thái đầu tiên của bi cái có vận tốc ≠ 0.
            s0 = states[0]
            if bid == "cue":
                for s in states:
                    if float(np.linalg.norm(s.rvw[1])) > 1e-9:
                        s0 = s
                        break
            rvw = s0.rvw
            initial.append({"id": 0 if bid == "cue" else int(bid),
                            "r": pt_to_ours_pos(rvw[0].tolist(), W),
                            "v": pt_to_ours_vec(rvw[1].tolist()),
                            "w": pt_to_ours_vec(rvw[2].tolist())})
            rf = ball.state.rvw[0].tolist()
            ours = pt_to_ours_pos(rf, W)
            final.append({"id": 0 if bid == "cue" else int(bid), "x": ours[0], "y": ours[1],
                          "pocketed": int(ball.state.s) == 4})
        counts[cat] += 1
        shots.append({"id": len(shots), "category": cat, "balls": initial, "pooltool": final})

    doc = {
        "pooltoolVersion": getattr(pt, "__version__", "unknown"),
        "table": {"length": L, "width": W, "ballRadius": R, "ballMass": m,
                  **({"cushionHeightRatio": chr_} if (chr_ := cushion_height_ratio(table, R)) else {})},
        "cushionModel": engine_label,
        "params": params,
        "shots": shots,
    }
    with open(path, "w") as f:
        json.dump(doc, f, indent=1)
    print(f"REPORT: pooltool {doc['pooltoolVersion']}, table {L:.3f}x{W:.3f} m, shots {counts}, attempts {attempts}")
    print(f"REPORT: pooltool params used: {params}; cushion model {engine_label}; "
          f"cushion height ratio {doc['table'].get('cushionHeightRatio')}")
    describe_pooltool_models(pt)


def describe_pooltool_models(pt):
    """R1.1: ghi mô hình va chạm mặc định của pooltool đang dùng (đọc từ gói đã cài)."""
    import os
    root = os.path.dirname(pt.__file__)
    found = False
    for dirpath, _, files in os.walk(root):
        for f in files:
            if "resolver" in f.lower() and f.endswith((".yaml", ".yml", ".json")):
                path = os.path.join(dirpath, f)
                lines = [l.rstrip() for l in open(path, encoding="utf-8", errors="replace") if l.strip()]
                print(f"REPORT: pooltool resolver config {os.path.relpath(path, root)}: " + " ; ".join(lines[:40]))
                found = True
    try:
        from pooltool.physics.resolve.resolver import Resolver  # type: ignore
        r = Resolver.default()
        for name in ("ball_ball", "ball_linear_cushion", "ball_circular_cushion", "stick_ball", "ball_pocket"):
            if hasattr(r, name):
                obj = getattr(r, name)
                fields = {k: (type(v).__name__ if hasattr(v, "__dict__") else v)
                          for k, v in getattr(obj, "__dict__", {}).items()}
                print(f"REPORT: pooltool default {name}: {type(obj).__name__} {fields}")
                friction = getattr(obj, "friction", None)
                if friction is not None:
                    print(f"REPORT: pooltool {name}.friction: {type(friction).__name__} {getattr(friction, '__dict__', {})}")
                found = True
    except Exception as e:  # noqa: BLE001
        print(f"REPORT: pooltool Resolver introspection failed: {type(e).__name__}: {e}")
    if not found:
        print("REPORT: pooltool resolver config not found")


def percentile(xs, q):
    if not xs:
        return float("nan")
    s = sorted(xs)
    k = min(len(s) - 1, max(0, int(round(q * (len(s) - 1)))))
    return s[k]


def report(scen_path, ours_path):
    scen = json.load(open(scen_path))
    ours = {s["id"]: s for s in json.load(open(ours_path))["shots"]}
    by_cat = {}
    worst = []
    for shot in scen["shots"]:
        o = ours.get(shot["id"])
        if o is None:
            continue
        mine = {b["id"]: b for b in o["final"]}
        for ref in shot["pooltool"]:
            m = mine.get(ref["id"])
            if m is None or ref["pocketed"] or m["pocketed"]:
                if m is not None and ref["pocketed"] != m["pocketed"]:
                    by_cat.setdefault(shot["category"] + "_pocket_mismatch", []).append(1.0)
                continue
            err = math.hypot(m["x"] - ref["x"], m["y"] - ref["y"])
            by_cat.setdefault(shot["category"], []).append(err)
            worst.append((err, shot["id"], shot["category"]))
    for cat, errs in sorted(by_cat.items()):
        if cat.endswith("_pocket_mismatch"):
            print(f"REPORT: P {cat}: {len(errs)} bi vào lỗ ở một engine nhưng không ở engine kia")
            continue
        within = sum(1 for e in errs if e <= 0.005) / len(errs)
        print(f"REPORT: P1 {cat}: n={len(errs)} median {1000*percentile(errs,0.5):.1f} mm, "
              f"p90 {1000*percentile(errs,0.9):.1f} mm, max {1000*max(errs):.1f} mm, ≤5mm {100*within:.0f}%")
    worst.sort(reverse=True)
    for err, sid, cat in worst[:3]:
        print(f"REPORT: P3 worst: shot {sid} ({cat}) {1000*err:.1f} mm")


def variant(src, dst, assignments):
    doc = json.load(open(src))
    for a in assignments:
        k, v = a.split("=", 1)
        doc["params"][k] = float(v)
    json.dump(doc, open(dst, "w"), indent=1)


def report_labeled(label, scen_path, ours_path):
    print(f"REPORT: ---- variant: {label} ----")
    report(scen_path, ours_path)


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "make":
        make(sys.argv[2], cushion_model=sys.argv[3] if len(sys.argv) > 3 else None)
    elif len(sys.argv) >= 4 and sys.argv[1] == "variant":
        variant(sys.argv[2], sys.argv[3], sys.argv[4:])
    elif len(sys.argv) >= 4 and sys.argv[1] == "report":
        report(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(2)
