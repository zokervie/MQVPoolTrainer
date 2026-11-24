#ifndef BL_MASTERY059_H
#define BL_MASTERY059_H
/* 0.59 "Thang 5 sao" — one star scale for every ring, a round length by chapter, take-backs that get scarcer in
 * proportion to the chapter, a start aim that is NOT the solution, and a fixed set of 5 layouts per ring.
 * Owner approval 24/11/2026 ("CHẤP THUẬN hết"); design: Project doc claude/zoker-he-thong-bai-tap-va-ho-so-2026-11-24.md.
 * Plain C (Swift via the bridging header, C++ tests include it). Nothing here is a physics value.
 *
 * Labels: [chủ dự án] owner decision · [suy ra] derived from an owner number · [GIẢ ĐỊNH] tune with TestFlight data.
 *
 *  Stars 0…5 from shots made in one scored round:
 *    chapter 1–2: 5 shots, stars = shots made                                                        [chủ dự án]
 *    chapter 3–4: 5 shots, stars = shots made, at most 4 when a take-back was used in the round         [chủ dự án]
 *    chapter 5–6: 10 shots, 9 → 5 · 8 → 4 · 6–7 → 3 · 4–5 → 2 · 2–3 → 1; at most 3 with a take-back  [5 & 3 sao: chủ dự án; dải giữa: GIẢ ĐỊNH]
 *    chapter 7+ : 10 shots, 10 → 5 · 9 → 4 · 7–8 → 3 · 5–6 → 2 · 3–4 → 1; at most 3 with a take-back [như trên]
 *  Next ring opens at 3 stars (every chapter).                                                       [chủ dự án]
 *  Warm-up (5 made in the big ring before scoring) in chapters 1–6; none from chapter 7.               [chủ dự án]
 *  Take-backs inside one scored round: unlimited in chapters 1–6, one from chapter 7.                 [chủ dự án]
 *  Chapter take-back fund = share × (rungs × shots per round); shares are the owner's 100/70/50/30 over
 *  chapter 1's 135 shots, kept for chapters 2–5 and extended 24/20/16/14 for 6–9+.                   [suy ra]
 */
#include <math.h>
#include <stdint.h>
#include <string.h>
#include "DrillCatalog.h"

#define BL_STARS5_MAX 5
#define BL_TIER_OPEN_STARS5 3
#define BL_AIM_OFFSET_FLOOR_DEG 1.5   /* the start aim is never closer than this to the solution (chapter ≥ 2) */
#define BL_POSE_COUNT 5               /* layouts in a ring's set; pose 0 = the catalogue layout */
#define BL_POSE_MIN_APART 0.015       /* metres between the cue balls of any two poses of a set (they must look different) */

static inline int32_t BLChapterClamp(int32_t chapter) { return chapter < 1 ? 1 : chapter; }

/* Shots in one scored round. */
static inline int32_t BLRoundShots(int32_t chapter) { return BLChapterClamp(chapter) <= 4 ? 5 : 10; }

/* Stars (0…5) of a scored round: `made` of BLRoundShots(chapter), `undoInRound` take-backs used in that round. */
static inline int32_t BLRoundStars5(int32_t chapter, int32_t made, int32_t undoInRound) {
    chapter = BLChapterClamp(chapter);
    const int32_t shots = BLRoundShots(chapter);
    if (made < 0) made = 0;
    if (made > shots) made = shots;
    int32_t s;
    if (shots == 5) s = made;
    else if (chapter <= 6) s = made >= 9 ? 5 : made == 8 ? 4 : made >= 6 ? 3 : made >= 4 ? 2 : made >= 2 ? 1 : 0;
    else s = made >= 10 ? 5 : made == 9 ? 4 : made >= 7 ? 3 : made >= 5 ? 2 : made >= 3 ? 1 : 0;
    if (undoInRound > 0) {
        const int32_t cap = chapter <= 2 ? 5 : chapter <= 4 ? 4 : 3;
        if (s > cap) s = cap;
    }
    return s;
}
/* Fewest shots made that give `stars` with no take-back (for "cần N cú để lên vòng"); > shots when unreachable. */
static inline int32_t BLMadeForStars5(int32_t chapter, int32_t stars) {
    const int32_t shots = BLRoundShots(chapter);
    for (int32_t m = 0; m <= shots; ++m) if (BLRoundStars5(chapter, m, 0) >= stars) return m;
    return shots + 1;
}
static inline int BLTierOpen5(int32_t tier, int32_t starsOfPreviousTier) {
    return tier <= 1 || starsOfPreviousTier >= BL_TIER_OPEN_STARS5;
}
static inline int32_t BLWarmupMadeFor(int32_t chapter) { return BLChapterClamp(chapter) <= 6 ? 5 : 0; }
/* Take-backs allowed inside one scored round; -1 = no limit (the chapter fund still applies). */
static inline int32_t BLRoundUndoLimit(int32_t chapter) { return BLChapterClamp(chapter) <= 6 ? -1 : 1; }

/* Chapter take-back fund; -1 = unlimited. `rungs` × `shotsPerRound` = shots of one clean pass through the chapter
 * (≤ 0 → chapter 1's 27 × 5). Rounded to the nearest take-back, never below 1. */
static inline int32_t BLChapterUndoFund(int32_t chapter, int32_t rungs, int32_t shotsPerRound) {
    static const int32_t per135[10] = { -1, -1, 100, 70, 50, 30, 24, 20, 16, 14 };   /* index = chapter, 9 = 9+ */
    chapter = BLChapterClamp(chapter);
    const int32_t base = per135[chapter > 9 ? 9 : chapter];
    if (base < 0) return -1;
    const int32_t shots = rungs > 0 && shotsPerRound > 0 ? rungs * shotsPerRound : 135;
    const int32_t fund = (int32_t)((base * (int64_t)shots + 67) / 135);
    return fund < 1 ? 1 : fund;
}
static inline int32_t BLChapterUndoFundLeft(int32_t chapter, int32_t rungs, int32_t shotsPerRound, int32_t used) {
    const int32_t fund = BLChapterUndoFund(chapter, rungs, shotsPerRound);
    if (fund < 0) return -1;
    if (used < 0) used = 0;
    return used >= fund ? 0 : fund - used;
}

/* Chapter completion % from best stars (0…5) of its rungs, rounded down. */
static inline int32_t BLChapterPercent5(const int32_t *bestStars, int32_t count) {
    if (!bestStars || count <= 0) return 0;
    int64_t sum = 0;
    for (int32_t i = 0; i < count; ++i) sum += bestStars[i] < 0 ? 0 : (bestStars[i] > 5 ? 5 : bestStars[i]);
    return (int32_t)(sum * 100 / (5 * (int64_t)count));
}

/* Old ring stars (0…3, ≤ 0.58) → new scale. With the best round's shots made out of 5 known (bestMade ≥ 0) the new
 * stars are recomputed exactly (never below the conservative map); otherwise 1 → 2, 2 → 3, 3 → 4.            [GIẢ ĐỊNH] */
static inline int32_t BLStarsMigrate058(int32_t chapter, int32_t oldStars, int32_t bestMade) {
    const int32_t floor = oldStars <= 0 ? 0 : (oldStars >= 3 ? 4 : oldStars + 1);
    if (bestMade >= 0 && BLRoundShots(chapter) == 5) {
        const int32_t s = BLRoundStars5(chapter, bestMade, 0);
        return s > floor ? s : floor;
    }
    return floor;
}

/* ── Start aim: never the solution ──────────────────────────────────────────────────────────────────────────── */
/* Offset band in degrees by chapter.                                                                     [GIẢ ĐỊNH] */
static inline void BLAimOffsetBand(int32_t chapter, double *minDeg, double *maxDeg) {
    chapter = BLChapterClamp(chapter);
    double lo = 0, hi = 0;
    if (chapter == 2) { lo = 2; hi = 4; }
    else if (chapter >= 3 && chapter <= 4) { lo = 5; hi = 10; }
    else if (chapter >= 5 && chapter <= 6) { lo = 10; hi = 20; }
    else if (chapter >= 7) { lo = 15; hi = 30; }
    if (minDeg) *minDeg = lo;
    if (maxDeg) *maxDeg = hi;
}
/* Signed offset (degrees) of the start aim for shot `shot` of round `round` on drill `key`: same on every device. */
static inline double BLStartAimOffsetDeg(const char *key, int32_t chapter, int32_t round, int32_t shot) {
    double lo, hi;
    BLAimOffsetBand(chapter, &lo, &hi);
    if (hi <= 0) return 0;
    if (lo < BL_AIM_OFFSET_FLOOR_DEG) lo = BL_AIM_OFFSET_FLOOR_DEG;
    const uint32_t h = BLDrillHash(key, 7919 + round * 131 + shot);
    const double mag = lo + (hi - lo) * ((h >> 8) & 0xffff) / 65535.0;
    return (h & 1u) ? mag : -mag;
}
static inline int BLStartTipCentred(int32_t chapter) { return BLChapterClamp(chapter) >= 5; }
static inline int BLStartCameraStanding(int32_t chapter) { return BLChapterClamp(chapter) >= 7; }

/* ── Pose set: 5 fixed layouts per ring, shuffled per round ───────────────────────────────────────────────────
 * Pose 0 is the catalogue layout. Poses 1–4: with an object ball, the cue ball turns about the ghost-ball point
 * (the object ball still leaves along the same line, so it still goes where the drill wants) by ± cut degrees and
 * moves along that line by ± distance; in chapter 2 it moves 3–5 cm in a spread direction. Without an object ball the cue
 * ball shifts sideways. Directions alternate, so the set covers both sides. A candidate off the bed, touching a
 * ball, with a ball in the cue ball's path or a cut over 75° is replaced by a smaller one, and finally by the
 * catalogue layout. Geometry alone does not make a pose playable (pace and tip change with it): the set is picked
 * offline by the checker and stored (DrillPoseData.h), then re-proven in Tests/Mastery059Tests.cpp. [biên độ: GIẢ ĐỊNH] */
typedef struct { double shiftMin, shiftMax, cutDeg; } BLPoseBand;
static inline BLPoseBand BLPoseBandFor(int32_t chapter) {
    BLPoseBand b = { 0, 0, 0 };
    chapter = BLChapterClamp(chapter);
    if (chapter == 2) { b.shiftMin = 0.03; b.shiftMax = 0.05; }
    else if (chapter >= 3 && chapter <= 4) { b.shiftMin = 0.08; b.shiftMax = 0.15; b.cutDeg = 5; }
    else if (chapter >= 5) { b.shiftMin = 0.10; b.shiftMax = 0.20; b.cutDeg = 10; }
    return b;
}
/* Van der Corput radical inverse of n in base b (0…1): evenly spread fractions 1/2, 1/4, 3/4, … */
static inline double BLRadicalInverse(int32_t n, int32_t b) {
    double r = 0, f = 1.0 / b;
    for (; n > 0; n /= b, f /= b) r += f * (n % b);
    return r;
}
static inline double BLSegmentDistance(double ax, double ay, double bx, double by, double px, double py) {
    const double vx = bx - ax, vy = by - ay, L2 = vx * vx + vy * vy;
    double t = L2 > 0 ? ((px - ax) * vx + (py - ay) * vy) / L2 : 0;
    t = t < 0 ? 0 : (t > 1 ? 1 : t);
    return hypot(ax + vx * t - px, ay + vy * t - py);
}
/* Ghost-ball point of the drill's reference stroke (object ball id 1); returns 0 when there is none. */
static inline int BLDrillGhost(const BLDrillSpec *d, double *gx, double *gy, int32_t *cueOut, int32_t *objOut) {
    int32_t cue = -1, obj = -1;
    for (int32_t i = 0; i < d->ballCount; ++i) { if (d->balls[i].id == 0) cue = i; if (d->balls[i].id == 1) obj = i; }
    if (cueOut) *cueOut = cue;
    if (objOut) *objOut = obj;
    if (cue < 0 || obj < 0) return 0;
    const double a = d->solveSpeed > 0 ? d->solveAngle : d->angle;
    const double ux = cos(a), uy = sin(a), cx = d->balls[cue].x, cy = d->balls[cue].y;
    const double ox = d->balls[obj].x - cx, oy = d->balls[obj].y - cy, along = ox * ux + oy * uy;
    const double side2 = ox * ox + oy * oy - along * along, rr = 4 * BL_DRILL_RADIUS * BL_DRILL_RADIUS;
    if (along <= 0 || side2 >= rr) return 0;
    const double t = along - sqrt(rr - side2);
    *gx = cx + ux * t; *gy = cy + uy * t;
    return 1;
}
static inline int BLPoseValid(const BLDrillSpec *d, const BLDrillLayout *L, int32_t cue, int32_t obj, double gx, double gy) {
    if (!BLDrillLayoutValid(d, L, cue)) return 0;
    if (obj < 0) return 1;
    /* cut angle ≤ 75°: angle between the cue ball's travel and the object ball's line (ghost → object) */
    const double tx = gx - L->x[cue], ty = gy - L->y[cue], lx = L->x[obj] - gx, ly = L->y[obj] - gy;
    const double c = (tx * lx + ty * ly) / (hypot(tx, ty) * hypot(lx, ly) + 1e-12);
    if (c < cos(75.0 * 3.14159265358979323846 / 180)) return 0;
    for (int32_t j = 0; j < d->ballCount; ++j)
        if (j != cue && j != obj && BLSegmentDistance(L->x[cue], L->y[cue], gx, gy, L->x[j], L->y[j]) < 2 * BL_DRILL_RADIUS + 0.004) return 0;
    return 1;
}
/* Candidate layout `cand` (≥ 1) of drill `d` in chapter `chapter`; cand 0 = the catalogue layout. Odd candidates turn
 * one way, even the other. Returns 0 when every shrink step failed (the catalogue layout is written). L->angle points
 * the solution way (at the ghost ball, or the catalogue aim): add BLStartAimOffsetDeg for the start aim. */
static inline int BLDrillPoseCandidate(const BLDrillSpec *d, int32_t chapter, int32_t cand, BLDrillLayout *L) {
    if (!d || !L) return 0;
    BLDrillLayoutFor(d, 0, L);
    const BLPoseBand band = BLPoseBandFor(chapter);
    if (cand <= 0 || band.shiftMax <= 0) return cand <= 0;
    int32_t cue, obj; double gx = 0, gy = 0;
    const int ghost = BLDrillGhost(d, &gx, &gy, &cue, &obj);
    if (cue < 0) return 0;
    /* spread, not hashed: candidate pairs (one per side) walk low-discrepancy sequences, so no two coincide */
    const int32_t j = (cand - 1) / 2;
    const double u1 = BLRadicalInverse(j + 1, 3), u2 = BLRadicalInverse(j + 1, 2);
    const double sign = (cand & 1) ? 1.0 : -1.0;
    const double away = (j & 1) ? -1.0 : 1.0;                /* farther from or nearer to the ghost ball */
    const double shift = band.shiftMin + (band.shiftMax - band.shiftMin) * u1;
    for (int k = 0; k < 4; ++k) {
        const double shrink = 1.0 - 0.25 * k;
        BLDrillLayout t = *L;
        if (ghost) {
            const double bx = d->balls[cue].x - gx, by = d->balls[cue].y - gy, dist = hypot(bx, by);
            double turn, len;
            if (band.cutDeg > 0) {
                turn = sign * band.cutDeg * (0.5 + 0.5 * u2) * shrink * 3.14159265358979323846 / 180;
                len = dist + away * shift * shrink;
            } else {   /* chapter 2: a 3–5 cm move in a spread direction (20°…160° off the line, either side) */
                const double alpha = sign * (20.0 + 140.0 * u2) * 3.14159265358979323846 / 180, m = shift * shrink;
                const double along = dist + m * cos(alpha), across = m * sin(alpha);
                turn = atan2(across, along);
                len = hypot(along, across);
            }
            if (len < 0.12) len = 0.12;
            const double c = cos(turn), s = sin(turn);
            t.x[cue] = gx + (bx * c - by * s) / dist * len;
            t.y[cue] = gy + (bx * s + by * c) / dist * len;
            t.angle = atan2(gy - t.y[cue], gx - t.x[cue]);
            if (BLPoseValid(d, &t, cue, obj, gx, gy)) { *L = t; return 1; }
        } else {
            const double dir = d->angle + sign * 1.5707963267948966;
            t.x[cue] = d->balls[cue].x + cos(dir) * shift * shrink;
            t.y[cue] = d->balls[cue].y + sin(dir) * shift * shrink;
            t.angle = d->angle;
            if (BLDrillLayoutValid(d, &t, cue)) { *L = t; return 1; }
        }
    }
    return 0;
}

/* The ring's set: candidates picked OFFLINE by Tools/drills/pose_pick (each made by a reference stroke whose make rate
 * under the checker's player error is within 10 points of the catalogue layout's), generated into DrillPoseData.h.
 * A drill with no entry, or a pose with no pick (cand 0), plays the catalogue layout. */
typedef struct { const char *key; int32_t chapter; int32_t basePercent; int32_t cand[BL_POSE_COUNT - 1];
                 double speed[BL_POSE_COUNT - 1], top[BL_POSE_COUNT - 1], aimDelta[BL_POSE_COUNT - 1]; int32_t percent[BL_POSE_COUNT - 1]; } BLPoseSet;
#include "DrillPoseData.h"   /* generated: Tools/drills/pose_pick.sh */
static inline const BLPoseSet *BLPoseSetFor(const char *key) {
    if (!key) return 0;
    for (int32_t i = 0; i < (int32_t)(sizeof(BLPoseSets) / sizeof(BLPoseSets[0])); ++i)
        if (BLPoseSets[i].key && strcmp(BLPoseSets[i].key, key) == 0) return &BLPoseSets[i];
    return 0;
}
static inline int32_t BLPoseSetSize(const char *key) {
    const BLPoseSet *s = BLPoseSetFor(key);
    int32_t n = 1;
    if (s) for (int32_t i = 0; i < BL_POSE_COUNT - 1; ++i) n += s->cand[i] > 0;
    return n;
}
/* Layout of pose `pose` (0…BL_POSE_COUNT-1) of drill `d` (its own chapter). */
static inline void BLDrillPoseFor(const BLDrillSpec *d, int32_t pose, BLDrillLayout *L) {
    if (!d || !L) return;
    const BLPoseSet *s = BLPoseSetFor(d->key);
    if (!s || pose <= 0 || pose >= BL_POSE_COUNT || s->cand[pose - 1] <= 0 || !BLDrillPoseCandidate(d, s->chapter, s->cand[pose - 1], L))
        BLDrillLayoutFor(d, 0, L);
}
/* Order of the 5 poses in round `round` (Fisher–Yates on the drill's hash; same on every device). */
static inline void BLRoundPoseOrder(const char *key, int32_t round, int32_t out[BL_POSE_COUNT]) {
    for (int32_t i = 0; i < BL_POSE_COUNT; ++i) out[i] = i;
    uint32_t h = BLDrillHash(key, 104729 + round);
    for (int32_t i = BL_POSE_COUNT - 1; i > 0; --i) {
        h ^= h << 13; h ^= h >> 17; h ^= h << 5;
        const int32_t j = (int32_t)(h % (uint32_t)(i + 1)), tmp = out[i];
        out[i] = out[j]; out[j] = tmp;
    }
}
/* Pose of shot `shot` (0-based) in round `round`: rounds of 10 play the set twice, each half shuffled. */
static inline int32_t BLRoundPose(const char *key, int32_t round, int32_t shot) {
    int32_t order[BL_POSE_COUNT];
    BLRoundPoseOrder(key, round * 2 + (shot >= BL_POSE_COUNT ? 1 : 0), order);
    return order[(shot < 0 ? 0 : shot) % BL_POSE_COUNT];
}
#endif
