"""0.49b Xưởng bài — the drill catalogue (single source). Edit here, then:

    python3 Tools/drills/gen_catalog.py            # writes BankLab/UI/DrillCatalogData.h
    Tools/drills/drill_sweep.sh [key …]            # measures reference stroke + make rate → measured.json, regenerates

Ladder order inside a chapter = order in this list. Coordinates in metres (origin table centre, x across ±0.635,
y along ±1.27). Ball ids: 0 cue, 1 object, ≥ 2 blocker / next ball.

kind: goal (cue-ball zone and/or pot), kick (cue ball `rails` cushions then ball 1), bank (ball 1 `rails` cushions
then a pocket), safety (legal hit on ball 1, nothing pocketed, ball 1 hidden behind another ball).
scan: aim scan half-width (degrees) for drill_sweep; 180 = every direction; 0 = not swept (assumed_pct used).
jitter: metres the cue ball moves between the shots of a round (0 = fixed).
Texts (title, note, tip, real-table card) live in Swift (Chapters047.swift / DrillTexts049.swift) keyed by `key`.
"""
from math import atan2, cos, sin, radians, hypot

R = 0.028575
CORNER_TR = (0.635 - R * 0.6, 1.27 - R * 0.6)    # aim point just inside the top-right corner mouth (Opponent.hpp mouths)
CORNER_TL = (-CORNER_TR[0], CORNER_TR[1])
SIDE_R = (0.635 + R * 0.2, 0.0)

# Chapters: (number, stable key). Exam progress is keyed by the stable key (DrillCatalog.h BLDrillChapterKey).
CHAPTERS = [
    (1, "straight-speed"), (2, "stop-follow-draw"), (3, "cut"), (4, "cue-path"), (5, "position"),
    (6, "kick"), (7, "bank"), (8, "safety"), (9, "special"),
]


def cut_layout(deg, side, dist, obj, hole):
    """Cue ball `dist` m behind the ghost ball for a `deg` cut of `obj` into `hole`; side +1 = cue ball on the right
    of the object-ball line (cut to the left of the shot line … as in Models.swift cut())."""
    ux, uy = hole[0] - obj[0], hole[1] - obj[1]
    n = hypot(ux, uy); ux, uy = ux / n, uy / n
    gx, gy = obj[0] - 2 * R * ux, obj[1] - 2 * R * uy
    r = radians(deg) * side
    ix, iy = ux * cos(r) - uy * sin(r), ux * sin(r) + uy * cos(r)
    return (gx - ix * dist, gy - iy * dist), atan2(iy, ix)


def old_cut(deg, m):
    """Models.swift ≤ 0.48 cut(_:mirror:) — kept bit-for-bit for the existing keys."""
    L = hypot(0.42, 0.755); dx, dy = 0.42 / L, 0.755 / L; r = radians(deg)
    ix, iy = dx * cos(r) - dy * sin(r), dx * sin(r) + dy * cos(r)
    gx, gy = 0.25 - dx * 0.05715, 0.55 - dy * 0.05715
    return ((gx - ix * 0.65) * m, gy - iy * 0.65), (0.25 * m, 0.55), atan2(iy, ix * m)


def old_kick(rails, variant):
    """Models.swift ≤ 0.48 kickLayout(rails:variant:)."""
    s = variant * 0.055
    x, y = -0.28 + s, -0.78 + (rails - 1) * 0.035
    tx, ty = 0.24 - s * 0.5, 0.46 - (rails - 1) * 0.04
    blockers = [] if variant == 0 else [(2, 0.02, 0.03 + (variant - 1) * 0.14)]
    return [(0, x, y), (1, tx, ty)] + blockers, atan2(ty - y, tx - x)


def D(key, chapter, kind, balls, angle, rails=0, goal=None, pot_required=False, pot_only=False, tip=0.0,
      jitter=0.03, scan=6.0, assumed_pct=None, tier=0):
    return dict(key=key, chapter=chapter, kind=kind, balls=balls, angle=angle, rails=rails, goal=goal,
                pot_required=pot_required, pot_only=pot_only, tip=tip, jitter=jitter, scan=scan,
                assumed_pct=assumed_pct, tier=tier)


def ladder(group, chapter, balls, angle, centre, radii, rails=0, pot_required=False, jitter=0.0, scan=4.0):
    """0.54 ring ladder: one layout, three rings (keys <group>-1…3, tier 1…3)."""
    return [D("%s-%d" % (group, t + 1), chapter, "goal", balls, angle, rails=rails, goal=(centre[0], centre[1], r),
              pot_required=pot_required, jitter=jitter, scan=scan, tier=t + 1) for t, r in enumerate(radii)]


# FirstShot.h (straight along the top-right diagonal: object 0.40 m from the pocket, cue 0.22 m behind)
_d = 0.70710678118654752440
_fo = (0.67 - _d * 0.40, 1.305 - _d * 0.40)
_fc = (_fo[0] - _d * 0.22, _fo[1] - _d * 0.22)
_stop = [(0, 0.02, 0.01), (1, 0.33, 0.63)]
_stopA = atan2(0.62, 0.31)
_stopL = [(0, -0.02, 0.01), (1, -0.33, 0.63)]             # mirrored for chapter 5 (new look, same skill + a purpose)
_stopLA = atan2(0.62, -0.31)
# 0.52 draw layouts: same object ball and line, cue ball 0.42 m from contact (was 0.69 m). From 0.69 m back-spin is
# gone before contact below ~2.6 m/s (Tests/DrawIdentityTests.cpp); 0.42 m measured 52 % with the zone 0.30 m back.
_draw = [(0, 0.1166, 0.2032), (1, 0.33, 0.63)]
_drawL = [(0, -0.1166, 0.2032), (1, -0.33, 0.63)]
_c30 = old_cut(30, 1); _c45 = old_cut(45, -1)
_c15 = cut_layout(15, 1, 0.65, (0.25, 0.55), CORNER_TR)
_c60 = cut_layout(60, 1, 0.50, (0.25, 0.55), CORNER_TR)
_cside = cut_layout(30, -1, 0.60, (0.42, 0.22), SIDE_R)
_xs = cut_layout(0, 1, 0.35, (0.50, 0.10), (2 * (0.635 - R) - (-0.635 - 0.2 * R), 0.0))   # mirror of the left side pocket
_cp = cut_layout(30, 1, 0.45, (0.25, 0.55), CORNER_TR)   # chapter 4: the same 30° cut, two different cue-ball rules

# 0.50 skills ("công cụ"), same order as BL_SKILL_* in DrillCatalog.h
SKILLS = ["straight", "speed", "spin", "ghost", "rule30", "rule90", "position", "mirror", "plus", "corner5", "bank", "hide"]


def skill_of(key):
    """What each 0.49 drill teaches. First drill of a skill in catalogue order = its lesson (BLSkillLesson)."""
    table = [("first-shot", "straight"), ("speed-", "speed"), ("stop-", "spin"), ("follow-", "spin"), ("draw-", "spin"),
             ("cut-", "ghost"), ("cue-path-30", "rule30"), ("cue-path-90", "rule90"), ("cue-path-2rail", "rule30"),
             ("pos-", "position"), ("kick1-", "mirror"), ("kick2-double", "mirror"), ("kick2-", "plus"),
             ("kick3-", "corner5"), ("kick4", "corner5"), ("bank", "bank"), ("safe-", "hide"),
             ("trick-combo", "ghost"), ("trick-kick3", "corner5")]
    for prefix, skill in table:
        if key.startswith(prefix):
            return SKILLS.index(skill)
    return -1


DRILLS = [
    # ── 1 · Cú thẳng và lực ── straight first, then pace (pace before spin: stop / follow / draw need it)
    D("first-shot", 1, "goal", [(0, *_fc), (1, *_fo)], atan2(_fo[1] - _fc[1], _fo[0] - _fc[0]), pot_only=True, tip=-0.15, scan=4),
    # ── 0.54 Chương 1 "Kiểm soát lực": 9 bài × 3 cỡ vòng (bài 10 = bài thi, do app ghép). Bi cái một mình; vòng đặt
    # ở chỗ bi dừng với một lực vừa (đo trên lõi). Bài có băng: bi cái phải chạm ĐÚNG số băng rồi dừng trong vòng.
    # Cỡ vòng: GIẢ ĐỊNH, chọn theo tỉ lệ đo của máy chấm (measured.json).
    *ladder("force-near", 1, [(0, 0.0, -0.9)], 1.5707963267949, (0.0, -0.25), (0.14, 0.10, 0.07)),
    *ladder("force-far", 1, [(0, 0.0, -0.9)], 1.5707963267949, (0.0, 0.75), (0.24, 0.17, 0.11)),
    *ladder("force-1rail-short", 1, [(0, 0.0, -0.6)], 1.5707963267949, (0.0, -0.193), (0.34, 0.25, 0.17), rails=1),
    *ladder("force-1rail-long", 1, [(0, -0.3, -0.6)], radians(20), (-0.149, 0.039), (0.22, 0.15, 0.10), rails=1),
    *ladder("force-2rail", 1, [(0, 0.25, -0.8)], radians(60), (-0.343, 0.125), (0.36, 0.27, 0.19), rails=2),
    *ladder("force-2rail-long", 1, [(0, 0.2, -0.9)], 1.5707963267949, (0.2, 0.247), (0.40, 0.30, 0.22), rails=2),
    *ladder("force-3rail", 1, [(0, -0.2, -0.5)], radians(48), (-0.228, -0.017), (0.36, 0.26, 0.17), rails=3),
    *ladder("force-follow", 1, _stop, _stopA, (0.50, 0.97), (0.17, 0.12, 0.09), pot_required=True, scan=6.0),
    *ladder("force-draw", 1, _draw, _stopA, (0.1703, 0.3106), (0.19, 0.14, 0.10), pot_required=True, scan=6.0),
    D("speed-1", 1, "goal", [(0, 0.0, -0.9)], 1.5707963267949, goal=(0.0, 0.10, 0.15), jitter=0.05, scan=4),
    D("speed-2", 1, "goal", [(0, 0.0, -0.9)], 1.5707963267949, goal=(0.0, 0.55, 0.14), jitter=0.05, scan=4),
    D("speed-3", 1, "goal", [(0, 0.0, -0.9)], 1.5707963267949, goal=(0.0, 0.95, 0.13), jitter=0.05, scan=4),
    # ── 2 · Dừng – theo – lùi
    D("stop-hold", 2, "goal", _stop, _stopA, goal=(0.3044, 0.5789, 0.10), pot_required=True),
    D("follow-zone", 2, "goal", _stop, _stopA, goal=(0.50, 0.97, 0.12), pot_required=True),
    # draw-zone (0.52): cue ball moved in to 0.42 m, zone back at the original spot 0.30 m behind contact
    D("draw-zone", 2, "goal", _draw, _stopA, goal=(0.1703, 0.3106, 0.14), pot_required=True),
    # ── 3 · Ngắm cắt ── thick → thin, corner and side
    D("cut-side-30", 3, "goal", [(0, *_cside[0]), (1, 0.42, 0.22)], _cside[1], pot_only=True, jitter=0.04),
    D("cut-30-r", 3, "goal", [(0, *_c30[0]), (1, *_c30[1])], _c30[2], pot_only=True, jitter=0.04),
    D("cut-15-r", 3, "goal", [(0, *_c15[0]), (1, 0.25, 0.55)], _c15[1], pot_only=True, jitter=0.04),
    D("cut-45-l", 3, "goal", [(0, *_c45[0]), (1, *_c45[1])], _c45[2], pot_only=True, jitter=0.04),
    D("cut-60-r", 3, "goal", [(0, *_c60[0]), (1, 0.25, 0.55)], _c60[1], pot_only=True, jitter=0.03),
    # ── 4 · Đường bi cái ── rolling ball leaves ~30°, stunned ball 90°, then a two-rail route back to the centre
    D("cue-path-30", 4, "goal", [(0, *_cp[0]), (1, 0.25, 0.55)], _cp[1], goal=(-0.40, 1.15, 0.13), pot_required=True),
    D("cue-path-90", 4, "goal", [(0, *_cp[0]), (1, 0.25, 0.55)], _cp[1], goal=(-0.52, 0.80, 0.13), pot_required=True),
    D("cue-path-2rail", 4, "goal", [(0, *_c45[0]), (1, *_c45[1])], _c45[2], goal=(0.41, 0.99, 0.16), pot_required=True),
    # ── 5 · Đi bi ── pot ball 1 AND land where ball 2 (next ball) is an easy cut
    D("pos-stop", 5, "goal", _stopL + [(2, -0.52, 0.12)], _stopLA, goal=(-0.3044, 0.5789, 0.10), pot_required=True),
    D("pos-follow", 5, "goal", _stopL + [(2, 0.15, 1.00)], _stopLA, goal=(-0.50, 0.97, 0.12), pot_required=True),
    D("pos-draw", 5, "goal", _drawL + [(2, -0.45, -0.20)], _stopLA, goal=(-0.1703, 0.3106, 0.14), pot_required=True),
    # ── 6 · Kick băng (Models.swift ≤ 0.48 layouts)
    D("kick1-mirror-a", 6, "kick", [(0, -0.25, -0.72), (1, -0.23, 0.56)], 0.91, rails=1, scan=180),
    D("kick1-blocker", 6, "kick", *old_kick(1, 1), rails=1, scan=180),
    D("kick1-mirror-b", 6, "kick", *old_kick(1, 0), rails=1, scan=180),
    D("kick1-blocker-far", 6, "kick", *old_kick(1, 2), rails=1, scan=180),
    D("kick2-plus", 6, "kick", [(0, -0.22, -0.95), (1, 0.30, 0.62), (2, 0.05, -0.20)], atan2(0.62 + 0.95, 0.30 + 0.22), rails=2, scan=180),
    D("kick2-double-mirror", 6, "kick", [(0, -0.28, -0.68), (1, 0.20, 0.40)], 0.49, rails=2, scan=180),
    D("kick2-blocker", 6, "kick", *old_kick(2, 1), rails=2, scan=180),
    D("kick3-blocker-high", 6, "kick", *old_kick(3, 2), rails=3, scan=180),
    D("kick3-corner5", 6, "kick", [(0, -0.30, -0.70), (1, 0.17, 0.50)], 0.36, rails=3, scan=180),
    D("kick3-blocker-mid", 6, "kick", *old_kick(3, 1), rails=3, scan=180),
    D("kick4", 6, "kick", [(0, -0.25, -0.60), (1, 0.15, 0.38)], 0.29, rails=4, scan=180),
    # ── 7 · Bank
    # bank1–3 (0.52): layouts found by backward search (object ball banked alone first, cue ball put straight behind it,
    # 28–48 cm away), kept only when every rail contact is ≥ 20 cm from the pocket (no jaw bounces). The ≤ 0.48 layouts
    # had the balls 0.6–0.9 m apart: windows ≈ 0.05°, 2–3 %. No true three-rail bank ≥ 5 % was found in 59 candidates,
    # so bank3 is a long two-rail bank (rails = 2): right rail, left rail, back into the right side pocket.
    # Owner decision 22/11/2026: keep it as the two-rail bank (option 1).
    # cross-side bank: straight in off the right rail into the left side pocket (first, easiest rung)
    D("bank-cross-side", 7, "bank", [(0, *_xs[0]), (1, 0.50, 0.10)], _xs[1], rails=1, scan=180),
    D("bank1", 7, "bank", [(0, -0.0468, -0.4810), (1, 0.2291, -0.4148)], 0.235619, rails=1, jitter=0.0, scan=25),
    D("bank2", 7, "bank", [(0, 0.0029, -0.3909), (1, -0.3519, -0.3347)], 2.984513, rails=2, jitter=0.0, scan=25),
    D("bank3", 7, "bank", [(0, -0.0468, 0.7576), (1, 0.2493, 0.6556)], 5.951573, rails=2, jitter=0.0, scan=25),
    # ── 8 · An toàn ── touch ball 1, pocket nothing, leave ball 1 hidden behind ball 2. Blocker spots: grid search of
    #    Physics.cpp (best share of random soft strokes that hide), then measured like every drill.
    D("safe-behind", 8, "safety", [(0, 0.0, -0.5), (1, 0.0, 0.30), (2, 0.0, 0.40)], 1.5707963267949, scan=14),
    D("safe-tuck", 8, "safety", [(0, 0.30, 0.20), (1, -0.20, 0.50), (2, -0.40, 0.60)], atan2(0.30, -0.50), scan=14),
    # ── 9 · Kỹ thuật đặc biệt
    D("trick-combo", 9, "goal", [(0, 0.10, 0.40), (2, 0.50, 1.10), (1, 0.5356, 1.1447)], atan2(0.70, 0.40), pot_only=True, jitter=0.0),
    D("trick-jump", 9, "goal", [(0, 0.15, -0.20), (2, 0.201, -0.027), (1, 0.55, 1.15)], atan2(1.35, 0.40), pot_only=True, jitter=0.0,
      scan=0, assumed_pct=35),
    D("trick-kick3-cluster", 9, "goal", [(0, -0.30, -0.70), (2, 0.05, 0.10), (3, 0.25, 0.25), (1, 0.52, 1.10)], 0.36, pot_only=True,
      jitter=0.0, scan=180),
    D("trick-masse", 9, "goal", [(0, -0.20, 0.10), (2, -0.12, 0.32), (1, 0.05, 0.85)], atan2(0.75, 0.25), pot_only=True, jitter=0.0,
      scan=0, assumed_pct=15),
    D("trick-reverse-zigzag", 9, "goal", [(0, -0.511, 0.316), (1, -0.054, 0.114)], atan2(-0.404, 0.914), pot_only=True, jitter=0.0,
      scan=0, assumed_pct=15),
]
