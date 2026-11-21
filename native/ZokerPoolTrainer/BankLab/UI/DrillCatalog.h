#ifndef BL_DRILL_CATALOG_H
#define BL_DRILL_CATALOG_H
#include <math.h>
#include <stdint.h>
#include <string.h>
/* 0.49b "Xưởng bài" — the drill catalogue as data. One table shared by Swift (bridging header) and the C++ drill
   checker (BankLab/Core/DrillCheck.hpp, Tests/DrillCatalogTests.cpp). Geometry, goal, judging rule, chapter, ladder
   order and MEASURED difficulty live here; the texts (title, note, tip, real-table card) stay in Swift for L10n,
   keyed by `key`.

   Coordinates: metres, origin at the table centre, x across (±0.635), y along (±1.27), 9 ft table (1.27 × 2.54 m).
   Ball ids: 0 cue ball, 1 object ball, ≥ 2 blockers / second object ball.

   `key` never changes (progress is keyed by it — DrillIDs047.swift). Existing keys keep the exact layout they had in
   Models.swift ≤ 0.48 (Tests/DrillCatalogTests.cpp checks the literals against the old formulas).

   `makePercent` / stars (BLDrillStars) = difficulty MEASURED by Tools/drills/drill_sweep: the share of shots made when
   the reference stroke is repeated with a typical player's error (DrillCheck.hpp) on Config::app.
   Tests/DrillCatalogTests.cpp fails when a drill has no solution, when the reference stroke stops working, when
   makePercent drifts from the measurement, when a jittered layout has none, or when a ladder gets harder then much
   easier again.
   Drills with `scanDegrees == 0` are not swept (jump / massé / side-spin trick shots need an elevated cue the sweep
   does not model): their makePercent is GIẢ ĐỊNH (catalog.py: assumed_pct). */

enum { BL_DRILL_GOAL = 0, BL_DRILL_KICK = 1, BL_DRILL_BANK = 2, BL_DRILL_SAFETY = 3 };
#define BL_DRILL_MAX_BALLS 6
#define BL_DRILL_RADIUS 0.028575

typedef struct { int32_t id; double x, y; } BLDrillBall;
typedef struct {
    const char *key;
    int32_t chapter;          /* 1-based, BLDrillChapterKey */
    int32_t kind;             /* BL_DRILL_* */
    int32_t rails;            /* kick: cue-ball rails before ball 1; bank: object-ball rails before the pocket */
    int32_t ballCount;
    BLDrillBall balls[BL_DRILL_MAX_BALLS];
    double angle;             /* default aim shown when the drill loads (radians) */
    double goalX, goalY, goalR;   /* cue-ball target zone (GOAL kind, goalR > 0) */
    int32_t potRequired, potOnly;
    double tipTop;            /* default vertical tip (fraction of R) */
    double jitter;            /* metres the cue ball may move between shots (0 = fixed layout) */
    double scanDegrees;       /* aim scan half-width for the checker; 0 = not swept; 180 = all directions */
    double solveAngle, solveSpeed, solveTop;   /* reference stroke found by Tools/drills/drill_sweep (the "lời giải mẫu") */
    int32_t makePercent;      /* % made with that stroke under the checker's player error (DrillCheck.hpp) */
} BLDrillSpec;

/* Difficulty 1–5 from the measured make rate (bands GIẢ ĐỊNH; ≥ 70 % made is "Đạt" in the 0.49 mastery rule). */
static inline int32_t BLDrillStarsFromMakeRate(int32_t percent) {
    if (percent >= 85) return 1;
    if (percent >= 65) return 2;
    if (percent >= 45) return 3;
    if (percent >= 25) return 4;
    return 5;
}
static inline int32_t BLDrillStars(const BLDrillSpec *d) { return d ? BLDrillStarsFromMakeRate(d->makePercent) : 0; }
/* Pass mark scaled to the drill (proposal for the 0.49 mastery rule): a club player makes `makePercent` %, so the
   pass mark is 15 points under that, never above 70 % and never below 20 %. A first shot (100 %) needs 7/10,
   a stop shot (≈ 68 %) about 5/10, a long bank (≈ 6 %) 2/10. GIẢ ĐỊNH until TestFlight made rates exist. */
static inline int32_t BLDrillPassPercent(const BLDrillSpec *d) {
    if (!d) return 70;
    int32_t p = d->makePercent - 15;
    return p > 70 ? 70 : (p < 20 ? 20 : p);
}
/* Shots that must be made out of `shots` (rounded up). */
static inline int32_t BLDrillPassMade(const BLDrillSpec *d, int32_t shots) {
    if (shots <= 0) return 0;
    return (BLDrillPassPercent(d) * shots + 99) / 100;
}

/* A concrete layout for one shot (catalogue layout or a jittered one). */
typedef struct { double x[BL_DRILL_MAX_BALLS], y[BL_DRILL_MAX_BALLS]; double angle; } BLDrillLayout;

#include "DrillCatalogData.h"   /* generated: Tools/drills/gen_catalog.py from Tools/drills/catalog.py */

static inline int32_t BLDrillCount(void) { return (int32_t)(sizeof(BLDrillTable) / sizeof(BLDrillTable[0])); }
static inline const BLDrillSpec *BLDrillAt(int32_t i) { return i >= 0 && i < BLDrillCount() ? &BLDrillTable[i] : 0; }
static inline int32_t BLDrillIndex(const char *key) {
    if (!key) return -1;
    for (int32_t i = 0; i < BLDrillCount(); ++i) if (strcmp(BLDrillTable[i].key, key) == 0) return i;
    return -1;
}

/* ── Chapters: stable keys (exam progress is keyed by these, never by the chapter number) ──────────────────── */
static inline const char *BLDrillChapterKey(int32_t chapter) {
    return chapter >= 1 && chapter <= BL_DRILL_CHAPTERS ? BLDrillChapterKeys[chapter - 1] : "";
}
/* Ladder of a chapter: writes up to `max` drill indices in order, returns how many. */
static inline int32_t BLDrillChapterDrills(int32_t chapter, int32_t *out, int32_t max) {
    int32_t n = 0;
    for (int32_t i = 0; i < BLDrillCount(); ++i) if (BLDrillTable[i].chapter == chapter) { if (out && n < max) out[n] = i; ++n; }
    return n;
}

/* ── Jitter: a slightly different layout on every shot so the round is read, not memorised ──────────────────
   Variant 0 = the catalogue layout (first shot of a round, exams, challenge codes). Variant v > 0 moves the cue ball by
   up to `jitter` metres in a deterministic direction (same key + variant → same layout on every device, so a
   challenge code or a replay reproduces it). The default aim keeps pointing at the same spot. Rejected candidates
   (off the table, touching a ball) fall back to smaller moves, and finally to the catalogue layout. */
static inline uint32_t BLDrillHash(const char *key, int32_t variant) {
    uint32_t h = 2166136261u;
    for (const char *p = key; p && *p; ++p) { h ^= (uint8_t)*p; h *= 16777619u; }
    h ^= (uint32_t)variant * 2654435761u; h ^= h >> 15; h *= 2246822519u; h ^= h >> 13;
    return h;
}
/* Only the cue ball moves: it must stay on the bed and clear of every other ball. */
static inline int BLDrillLayoutValid(const BLDrillSpec *d, const BLDrillLayout *L, int32_t cue) {
    const double r = BL_DRILL_RADIUS, hx = 0.635 - r * 1.05, hy = 1.27 - r * 1.05;
    if (fabs(L->x[cue]) > hx || fabs(L->y[cue]) > hy) return 0;
    for (int32_t j = 0; j < d->ballCount; ++j)
        if (j != cue && hypot(L->x[cue] - L->x[j], L->y[cue] - L->y[j]) < 2 * r + 0.004) return 0;
    return 1;
}
static inline void BLDrillLayoutFor(const BLDrillSpec *d, int32_t variant, BLDrillLayout *L) {
    if (!d || !L) return;
    memset(L, 0, sizeof *L);
    int32_t cue = -1;
    for (int32_t i = 0; i < d->ballCount; ++i) { L->x[i] = d->balls[i].x; L->y[i] = d->balls[i].y; if (d->balls[i].id == 0) cue = i; }
    L->angle = d->angle;
    if (variant <= 0 || d->jitter <= 0 || cue < 0) return;
    /* the default aim points at the spot `reach` metres ahead (the object ball's distance, or 0.45 m) */
    double reach = 0.45;
    for (int32_t i = 0; i < d->ballCount; ++i)
        if (d->balls[i].id == 1) reach = hypot(d->balls[i].x - d->balls[cue].x, d->balls[i].y - d->balls[cue].y);
    const double ax = d->balls[cue].x + cos(d->angle) * reach, ay = d->balls[cue].y + sin(d->angle) * reach;
    const uint32_t h = BLDrillHash(d->key, variant);
    const double dir = (h & 0xffff) / 65536.0 * 6.28318530717958647692, amount = 0.5 + 0.5 * ((h >> 16) & 0xffff) / 65536.0;
    for (int k = 0; k < 4; ++k) {
        const double m = d->jitter * amount * (1.0 - k * 0.3);
        BLDrillLayout t = *L;
        t.x[cue] = d->balls[cue].x + cos(dir) * m; t.y[cue] = d->balls[cue].y + sin(dir) * m;
        if (BLDrillLayoutValid(d, &t, cue)) { t.angle = atan2(ay - t.y[cue], ax - t.x[cue]); *L = t; return; }
    }
}

/* Swift cannot index a C array member: element accessors (0 when out of range). */
static inline double BLDrillLayoutX(const BLDrillLayout *L, int32_t i) { return L && i >= 0 && i < BL_DRILL_MAX_BALLS ? L->x[i] : 0; }
static inline double BLDrillLayoutY(const BLDrillLayout *L, int32_t i) { return L && i >= 0 && i < BL_DRILL_MAX_BALLS ? L->y[i] : 0; }

/* ── Real-table card: a spot in diamonds, the way it is set up on a real table ─────────────────────────────────
   Long rail 0…8 from the foot (y = −1.27) to the head, short rail 0…4 from the left (x = −0.635), one diamond =
   0.3175 m on a 9 ft table. Rounded to 0.1 diamond (≈ 3 cm) for the card. */
static inline void BLDrillDiamonds(double x, double y, double *alongLong, double *acrossShort) {
    const double unit = 0.3175;
    if (alongLong) *alongLong = round((y + 1.27) / unit * 10.0) / 10.0;
    if (acrossShort) *acrossShort = round((x + 0.635) / unit * 10.0) / 10.0;
}

/* ── Judge: the one rule the app (TC+ShotLoop.swift finishShot) and the checker both use ─────────────────────
   events: kind (0 cushion, 1 ball–ball, 2 pocket), a, b as in Physics.hpp Event (pocket b < 0 = recovered off
   the table, never "made"). Final balls: id, x, y, sunk. Returns 1 when the shot counts as made. A shot that timed
   out is never made (the caller checks that). */
static inline int BLDrillJudge(const BLDrillSpec *d, const BLDrillLayout *L, int32_t eventCount, const int32_t *kind,
                               const int32_t *a, const int32_t *b, int32_t ballCount, const int32_t *ids,
                               const double *xs, const double *ys, const int32_t *sunk) {
    (void)L;
    if (!d || eventCount < 0 || ballCount <= 0 || (eventCount > 0 && (!kind || !a || !b)) || !ids || !xs || !ys || !sunk) return 0;
    for (int32_t e = 0; e < eventCount; ++e) if (kind[e] == 2 && a[e] == 0) return 0;   /* scratch */
    int32_t cue = -1, obj = -1;
    for (int32_t i = 0; i < ballCount; ++i) { if (ids[i] == 0) cue = i; if (ids[i] == 1) obj = i; }
    if (cue < 0 || sunk[cue]) return 0;
    int made = 0;
    for (int32_t e = 0; e < eventCount; ++e) if (kind[e] == 2 && a[e] == 1 && b[e] >= 0) made = 1;
    switch (d->kind) {
    case BL_DRILL_GOAL:
        if (d->potOnly) return made;
        if (d->potRequired && !made) return 0;
        return hypot(xs[cue] - d->goalX, ys[cue] - d->goalY) <= d->goalR;
    case BL_DRILL_KICK: {
        int32_t rails = 0;
        for (int32_t e = 0; e < eventCount; ++e) {
            if (kind[e] == 0 && a[e] == 0) ++rails;
            if (kind[e] == 1 && (a[e] == 0 || b[e] == 0)) return (a[e] == 0 ? b[e] : a[e]) == 1 && rails == d->rails;
        }
        return 0;
    }
    case BL_DRILL_BANK: {
        int32_t rails = 0;
        for (int32_t e = 0; e < eventCount; ++e) {
            if (kind[e] == 0 && a[e] == 1) ++rails;
            if (kind[e] == 2 && a[e] == 1) return rails == d->rails && b[e] >= 0;
        }
        return 0;
    }
    case BL_DRILL_SAFETY: {
        /* legal hit (cue ball meets ball 1 first), nothing pocketed, and ball 1 hidden: the straight path from the
           cue ball to ball 1 is blocked by another ball (its centre within 2R of the segment). */
        int legal = 0;
        for (int32_t e = 0; e < eventCount; ++e) {
            if (kind[e] == 2) return 0;
            if (kind[e] == 1 && (a[e] == 0 || b[e] == 0)) { if (!legal) legal = (a[e] == 0 ? b[e] : a[e]) == 1 ? 1 : -1; }
        }
        if (legal != 1 || obj < 0 || sunk[obj]) return 0;
        const double px = xs[cue], py = ys[cue], qx = xs[obj], qy = ys[obj], dx = qx - px, dy = qy - py;
        const double len2 = dx * dx + dy * dy;
        if (len2 < 1e-9) return 0;
        for (int32_t i = 0; i < ballCount; ++i) {
            if (i == cue || i == obj || sunk[i]) continue;
            double t = ((xs[i] - px) * dx + (ys[i] - py) * dy) / len2;
            if (t <= 0 || t >= 1) continue;
            const double cx = px + t * dx - xs[i], cy = py + t * dy - ys[i];
            if (cx * cx + cy * cy < (2 * BL_DRILL_RADIUS) * (2 * BL_DRILL_RADIUS)) return 1;
        }
        return 0;
    }
    default: return 0;
    }
}
#endif
