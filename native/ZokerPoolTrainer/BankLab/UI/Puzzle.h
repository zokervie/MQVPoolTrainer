#ifndef BL_PUZZLE_H
#define BL_PUZZLE_H
#include "DrillCatalog.h"
/* 0.50 "Thế bí" — puzzles built on the drill catalogue (design: Project doc zoker-he-thong-the-bi-2026-11-21).
   A puzzle is a BLDrillSpec (same judge, BLDrillJudge) plus the routes the checker found that solve it.
   Rooms 1–9 = drill chapters. Table: PuzzleCatalogData.h, generated from Tools/drills/puzzles.json
   (Tools/drills/puzzle_gen + gen_catalog.py). All numbers below are GIẢ ĐỊNH until TestFlight data. */

enum { BL_PUZZLE_POT = 0, BL_PUZZLE_REACH = 1, BL_PUZZLE_POSITION = 2, BL_PUZZLE_HIDE = 3 };
#define BL_PUZZLE_MAX_SOLUTIONS 4

typedef struct {
    int32_t signature;        /* BLDrillSignature of the route */
    double angle, speed, top; /* reference stroke of the route */
    int32_t percent;          /* made rate of that route under a player's error (DrillCheck.hpp drillRouteRate) */
    double hintX, hintY;      /* level-2 hint: first cushion contact (kick/bank) or ghost-ball centre */
} BLPuzzleSolution;

typedef struct {
    BLDrillSpec spec;         /* key "p-<room>-<nn>", chapter = room, skill = skill of the best route */
    int32_t style;            /* BL_PUZZLE_* (picks the one-line task text) */
    int32_t solutionCount;
    BLPuzzleSolution solutions[BL_PUZZLE_MAX_SOLUTIONS];   /* best first */
} BLPuzzleSpec;

#include "PuzzleCatalogData.h"   /* generated */

static inline int32_t BLPuzzleCount(void) { return (int32_t)(sizeof(BLPuzzleTable) / sizeof(BLPuzzleTable[0])); }
static inline const BLPuzzleSpec *BLPuzzleAt(int32_t i) { return i >= 0 && i < BLPuzzleCount() ? &BLPuzzleTable[i] : 0; }
static inline int32_t BLPuzzleIndex(const char *key) {
    if (!key) return -1;
    for (int32_t i = 0; i < BLPuzzleCount(); ++i) if (strcmp(BLPuzzleTable[i].spec.key, key) == 0) return i;
    return -1;
}
/* Route of a made shot as the puzzle counts it. Reach and hide puzzles only care how the cue ball got to ball 1
   (its cushions); where ball 1 rolled afterwards is not a different solution. */
static inline int32_t BLPuzzleRoute(const BLDrillSpec *d, int32_t signature) {
    if (d && (d->kind == BL_DRILL_REACH || d->kind == BL_DRILL_SAFETY)) return (signature / 100) * 100;
    return signature;
}
/* Which listed route a made shot took (its BLDrillSignature), or -1 for a route the table does not list. */
static inline int32_t BLPuzzleSolutionIndex(const BLPuzzleSpec *p, int32_t signature) {
    if (!p) return -1;
    const int32_t route = BLPuzzleRoute(&p->spec, signature);
    for (int32_t i = 0; i < p->solutionCount; ++i) if (p->solutions[i].signature == route) return i;
    return -1;
}
static inline int32_t BLPuzzleRoomCount(int32_t room, int32_t *out, int32_t max) {
    int32_t n = 0;
    for (int32_t i = 0; i < BLPuzzleCount(); ++i) if (BLPuzzleTable[i].spec.chapter == room) { if (out && n < max) out[n] = i; ++n; }
    return n;
}

/* Pockets (Physics.cpp holes): 0 foot-left, 1 foot-right, 2 side-left, 3 side-right, 4 head-left, 5 head-right.
   A left–right mirror swaps each pair; the signature stores pocket + 1 in its last digit (0 = no pot). */
static inline int32_t BLPuzzleMirrorSignature(int32_t signature) {
    const int32_t pocket = signature % 10;
    return pocket == 0 ? signature : signature - pocket + (((pocket - 1) ^ 1) + 1);
}
/* Swift cannot index a C array member: accessor (NULL when out of range). */
static inline const BLPuzzleSolution *BLPuzzleSolutionAt(const BLPuzzleSpec *p, int32_t i) {
    return p && i >= 0 && i < p->solutionCount ? &p->solutions[i] : 0;
}

/* ── Review: left–right mirror (spaced review shows the same problem, not the same picture) ───────────────────
   The table is symmetric about x = 0, so the mirrored puzzle has the same routes, mirrored. */
static inline void BLPuzzleMirror(const BLPuzzleSpec *in, BLPuzzleSpec *out) {
    if (!in || !out) return;
    const double PI = 3.14159265358979323846;
    *out = *in;
    for (int32_t i = 0; i < out->spec.ballCount; ++i) out->spec.balls[i].x = -out->spec.balls[i].x;
    out->spec.goalX = -out->spec.goalX;
    out->spec.angle = PI - out->spec.angle;
    out->spec.solveAngle = PI - out->spec.solveAngle;
    for (int32_t i = 0; i < out->solutionCount; ++i) {
        out->solutions[i].angle = PI - out->solutions[i].angle;
        out->solutions[i].hintX = -out->solutions[i].hintX;
        out->solutions[i].signature = BLPuzzleMirrorSignature(out->solutions[i].signature);
    }
}
/* Two signatures describe the same route up to the pocket (mirror review compares this way). */
static inline int BLPuzzleSameRoute(int32_t a, int32_t b) { return a / 10 == b / 10 && ((a % 10) == 0) == ((b % 10) == 0); }

/* ── Hint jar ───────────────────────────────────────────────────────────────────────────────────────────────────
   Holds up to 3 hints; one refills every 20 minutes; passing a round of the linked lesson adds one (learning is the
   fastest way to earn hints). Level 1 (skill + "Ra bàn tập") costs 1, level 2 (aim point) 1, level 3 (watch the
   route) 2. Shots are never limited: only hints are. Times are seconds (any monotonic wall clock). */
#define BL_HINT_CAPACITY 3
#define BL_HINT_REFILL_SECONDS 1200.0
typedef struct { int32_t count; double refillFrom; } BLHintJar;
static inline void BLHintJarInit(BLHintJar *j, double now) { if (j) { j->count = BL_HINT_CAPACITY; j->refillFrom = now; } }
static inline void BLHintJarUpdate(BLHintJar *j, double now) {
    if (!j) return;
    if (j->count >= BL_HINT_CAPACITY) { j->count = BL_HINT_CAPACITY; j->refillFrom = now; return; }
    if (now < j->refillFrom) { j->refillFrom = now; return; }   /* clock moved back: restart the timer, give nothing */
    const int32_t gained = (int32_t)((now - j->refillFrom) / BL_HINT_REFILL_SECONDS);
    if (gained <= 0) return;
    j->count += gained;
    if (j->count >= BL_HINT_CAPACITY) { j->count = BL_HINT_CAPACITY; j->refillFrom = now; }
    else j->refillFrom += gained * BL_HINT_REFILL_SECONDS;
}
/* Seconds until the next refill (0 when full). */
static inline double BLHintJarNextIn(const BLHintJar *j, double now) {
    if (!j || j->count >= BL_HINT_CAPACITY) return 0;
    const double left = j->refillFrom + BL_HINT_REFILL_SECONDS - now;
    return left > 0 ? left : 0;
}
static inline int32_t BLHintCost(int32_t level) { return level == 3 ? 2 : (level == 1 || level == 2 ? 1 : 0); }
/* Spends the hint if affordable; returns 1 on success. */
static inline int BLHintJarSpend(BLHintJar *j, int32_t level, double now) {
    if (!j) return 0;
    BLHintJarUpdate(j, now);
    const int32_t cost = BLHintCost(level);
    if (cost <= 0 || j->count < cost) return 0;
    if (j->count >= BL_HINT_CAPACITY) j->refillFrom = now;   /* timer starts when the jar stops being full */
    j->count -= cost;
    return 1;
}
/* Passing a round of the lesson a hint pointed to. */
static inline void BLHintJarEarn(BLHintJar *j, double now) {
    if (!j) return;
    BLHintJarUpdate(j, now);
    if (j->count < BL_HINT_CAPACITY) ++j->count;
    if (j->count >= BL_HINT_CAPACITY) j->refillFrom = now;
}

/* ── Stars of one puzzle ────────────────────────────────────────────────────────────────────────────────────────
   Stars are earned per solving session (from loading the puzzle to solving it) and the best session is kept.
   ① solved, any way.
   ② solved within 3 tries, without watching the route (level-3 hint) in this session or in the last 24 h.
   ③ ② without the aim-point hint (level 2) in this session, plus the puzzle's third-star task:
      - a second listed route found (ever), when the puzzle lists two or more;
      - else the small target (goal radius × 0.6), when it has a cue-ball zone;
      - else solved at the first try.
   Every puzzle can reach 3 stars (review 21/11: single-route puzzles without a zone could not before). */
enum { BL_PUZZLE_THIRD_SECOND_ROUTE = 0, BL_PUZZLE_THIRD_SMALL_TARGET = 1, BL_PUZZLE_THIRD_FIRST_TRY = 2 };
static inline int32_t BLPuzzleThirdStarTask(const BLPuzzleSpec *p) {
    if (p && p->solutionCount >= 2) return BL_PUZZLE_THIRD_SECOND_ROUTE;
    if (p && p->spec.goalR > 0) return BL_PUZZLE_THIRD_SMALL_TARGET;
    return BL_PUZZLE_THIRD_FIRST_TRY;
}
/* tries: shots in this session up to and including the solving one (≥ 1). hintLevel: highest level used in this
   session (0–3). watchedAt: when the route of this puzzle was last watched (≤ 0 = never). routesFound: distinct
   listed routes found so far, this session included. smallTarget: the solving shot also stopped in the small zone. */
static inline int32_t BLPuzzleSessionStars(const BLPuzzleSpec *p, int32_t tries, int32_t hintLevel, double watchedAt,
                                           double now, int32_t routesFound, int smallTarget) {
    if (!p || tries < 1) return 0;
    if (hintLevel >= 3 || (watchedAt > 0 && now - watchedAt < 86400.0)) return 1;
    if (tries > 3) return 1;
    if (hintLevel >= 2) return 2;
    switch (BLPuzzleThirdStarTask(p)) {
    case BL_PUZZLE_THIRD_SECOND_ROUTE: return routesFound >= 2 ? 3 : 2;
    case BL_PUZZLE_THIRD_SMALL_TARGET: return smallTarget ? 3 : 2;
    default: return tries == 1 ? 3 : 2;
    }
}
static inline int32_t BLPuzzleBestStars(int32_t stored, int32_t session) { return session > stored ? session : stored; }

/* ── Rooms ──────────────────────────────────────────────────────────────────────────────────────────────────────
   Room 1 is open. Room n opens when the previous non-blocking room holds ≥ 60 % of its stars (3 per puzzle).
   Room 7 (Bank) never blocks (owner decision D2, 21/11): its windows are ≈ 0.1° on Config::app. An empty room
   never blocks either. `starsInRoom[r]` = stars earned in room r (index 1…BL_DRILL_CHAPTERS). */
#define BL_ROOM_UNLOCK_PERCENT 60
static inline int BLRoomBlocks(int32_t room) { return room != 7 && BLPuzzleRoomCount(room, 0, 0) > 0; }
static inline int BLRoomOpen(int32_t room, const int32_t *starsInRoom) {
    if (room <= 1) return 1;
    if (room > BL_DRILL_CHAPTERS || !starsInRoom) return 0;
    for (int32_t r = room - 1; r >= 1; --r) {
        if (!BLRoomBlocks(r)) continue;
        const int32_t max = 3 * BLPuzzleRoomCount(r, 0, 0);
        return starsInRoom[r] * 100 >= max * BL_ROOM_UNLOCK_PERCENT && BLRoomOpen(r, starsInRoom);
    }
    return 1;
}

/* ── Good ending: after 2 failed puzzles in a row, offer an easier open one ─────────────────────────────────── */
static inline int BLPuzzleOfferEasier(int32_t failedInRow) { return failedInRow >= 2; }

#endif
