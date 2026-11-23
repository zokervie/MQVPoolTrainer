#ifndef BL_PUZZLE_DAILY_H
#define BL_PUZZLE_DAILY_H
#include "Puzzle.h"
#include "DailyLoop.h"
#include <stdio.h>
/* 0.51 — three loops on top of the puzzles (owner approval 21/11 22:50):
     1. "Thế bí của ngày": one puzzle a day, the same for everyone, six tries, a spoiler-free share line.
     2. "Đoán đường bi": the stroke is given, the player marks where the cue ball will stop; scored by distance.
        One number to show: "Chỉ số Mắt" (Elo-style).
     3. "Đặt thế bí cho bạn": a layout packed into a 15-character code; the checker validates it on the device.
   Plain C for the bridging header. Every threshold is GIẢ ĐỊNH until TestFlight data. No server anywhere. */

/* ── 1. Daily puzzle ────────────────────────────────────────────────────────────────────────────────────────── */
#define BL_DAILY_EPOCH_DAY 20788        /* 2026-12-01 (day index, BLDayIndex) = puzzle #1. Set to the release day. */
#define BL_DAILY_MAX_TRIES 6
#define BL_DAILY_POOL_MAX 256
static inline int64_t BLDailyNumber(int64_t day) { return day - BL_DAILY_EPOCH_DAY + 1; }
/* Monday easy … Sunday hard: puzzles sorted by their best route's make rate (high first) are cut into 7 bands, the
   weekday picks the band, the week walks through it; once a band has been walked, it comes back mirrored.
   Deterministic from the local date alone, so everyone gets the same puzzle on the same date.
   Returns the puzzle index (−1 when there is none); *mirrored says to show it with BLPuzzleMirror. */
static inline int32_t BLDailyPuzzle(int64_t day, int *mirrored) {
    int32_t order[BL_DAILY_POOL_MAX]; int32_t n = 0;
    for (int32_t i = 0; i < BLPuzzleCount() && n < BL_DAILY_POOL_MAX; ++i) if (BLPuzzleTable[i].spec.chapter > 0) order[n++] = i;
    if (mirrored) *mirrored = 0;
    if (n == 0) return -1;
    for (int32_t i = 1; i < n; ++i) {   /* insertion sort: make rate high → low, ties by index */
        const int32_t v = order[i]; int32_t j = i - 1;
        while (j >= 0 && BLPuzzleTable[order[j]].solutions[0].percent < BLPuzzleTable[v].solutions[0].percent) { order[j + 1] = order[j]; --j; }
        order[j + 1] = v;
    }
    const int32_t weekday = (int32_t)(((day + 3) % 7 + 7) % 7);   /* 0 = Monday (1970-01-01 was a Thursday) */
    const int64_t week = BLWeekIndex(day);
    int32_t from = weekday * n / 7, to = (weekday + 1) * n / 7;
    if (to <= from) { from = weekday % n; to = from + 1; }      /* fewer than 7 puzzles */
    const int32_t size = to - from;
    const int64_t turn = ((week % (2 * size)) + 2 * size) % (2 * size);
    if (mirrored) *mirrored = turn >= size;
    return order[from + (int32_t)(turn % size)];
}

/* First ball the cue ball touches (−1: none). */
static inline int32_t BLDrillFirstContact(int32_t eventCount, const int32_t *kind, const int32_t *a, const int32_t *b) {
    for (int32_t e = 0; e < eventCount; ++e)
        if (kind[e] == 1 && (a[e] == 0 || b[e] == 0)) return a[e] == 0 ? b[e] : a[e];
    return -1;
}
/* How far a missed shot was from counting, in metres (0 = it counted on this axis; −1 = cannot tell from the final
   balls: for a REACH puzzle pass the cue ball's closest approach to ball 1, minus 2R, from the replay samples).
   Pot: ball 1's distance to the nearest pocket. Zone puzzle with ball 1 down: cue ball's distance outside the zone.
   Hide: how far ball 2 is from blocking the line. */
static inline double BLPuzzleMissMetres(const BLDrillSpec *d, int32_t ballCount, const int32_t *ids, const double *xs,
                                        const double *ys, const int32_t *sunk) {
    static const double holes[6][2] = {{-.67, -1.305}, {.67, -1.305}, {-.706, 0}, {.706, 0}, {-.67, 1.305}, {.67, 1.305}};
    if (!d || !ids || !xs || !ys || !sunk) return -1;
    int32_t cue = -1, obj = -1;
    for (int32_t i = 0; i < ballCount; ++i) { if (ids[i] == 0) cue = i; if (ids[i] == 1) obj = i; }
    if (cue < 0 || obj < 0 || d->kind == BL_DRILL_REACH || d->kind == BL_DRILL_KICK) return -1;
    if (d->kind == BL_DRILL_SAFETY) {
        const double px = xs[cue], py = ys[cue], dx = xs[obj] - px, dy = ys[obj] - py, len2 = dx * dx + dy * dy;
        double best = -1;
        for (int32_t i = 0; i < ballCount; ++i) {
            if (i == cue || i == obj || sunk[i] || len2 < 1e-9) continue;
            double t = ((xs[i] - px) * dx + (ys[i] - py) * dy) / len2;
            if (t < 0) t = 0;
            if (t > 1) t = 1;
            const double gap = hypot(px + t * dx - xs[i], py + t * dy - ys[i]) - 2 * BL_DRILL_RADIUS;
            if (best < 0 || gap < best) best = gap;
        }
        return best < 0 ? -1 : (best > 0 ? best : 0);
    }
    if (!sunk[obj]) {
        double best = 1e9;
        for (int h = 0; h < 6; ++h) { const double m = hypot(xs[obj] - holes[h][0], ys[obj] - holes[h][1]); if (m < best) best = m; }
        return best;
    }
    if (d->goalR > 0) { const double out = hypot(xs[cue] - d->goalX, ys[cue] - d->goalY) - d->goalR; return out > 0 ? out : 0; }
    return 0;
}
/* Grade of one try for the share line: 2 = solved, 1 = near (ball 1 hit first and within 15 cm of counting),
   0 = far. `missMetres` < 0 = unknown = far. */
enum { BL_TRY_FAR = 0, BL_TRY_NEAR = 1, BL_TRY_SOLVED = 2 };
#define BL_TRY_NEAR_METRES 0.15
static inline int32_t BLDailyGrade(int solved, int32_t firstContact, double missMetres) {
    if (solved) return BL_TRY_SOLVED;
    return firstContact == 1 && missMetres >= 0 && missMetres <= BL_TRY_NEAR_METRES ? BL_TRY_NEAR : BL_TRY_FAR;
}
/* Share line, UTF-8, no spoiler: "Zoker #128 · 3/6\n⚪🟡🟢\n🔥 12". `tries` = number of grades (1…6); a run that
   never solved shows X/6. Streak line omitted under 2 days. Returns the length written (0 if the buffer is small). */
static inline int32_t BLDailyShareText(char *out, int32_t size, int64_t number, const int32_t *grades, int32_t tries, int32_t streak) {
    static const char *dot[3] = {"\xE2\x9A\xAA", "\xF0\x9F\x9F\xA1", "\xF0\x9F\x9F\xA2"};   /* ⚪ 🟡 🟢 */
    if (!out || size < 96 || !grades || tries < 1 || tries > BL_DAILY_MAX_TRIES) return 0;
    const int solved = grades[tries - 1] == BL_TRY_SOLVED;
    int n = solved ? snprintf(out, (size_t)size, "Zoker #%lld \xC2\xB7 %d/%d\n", (long long)number, (int)tries, BL_DAILY_MAX_TRIES)
                   : snprintf(out, (size_t)size, "Zoker #%lld \xC2\xB7 X/%d\n", (long long)number, BL_DAILY_MAX_TRIES);
    for (int32_t i = 0; i < tries; ++i) {
        const int32_t g = grades[i] < 0 ? 0 : (grades[i] > 2 ? 2 : grades[i]);
        n += snprintf(out + n, (size_t)(size - n), "%s", dot[g]);
    }
    if (streak >= 2) n += snprintf(out + n, (size_t)(size - n), "\n\xF0\x9F\x94\xA5 %d", (int)streak);   /* 🔥 */
    return n;
}

/* ── 2. Predict the path ────────────────────────────────────────────────────────────────────────────────────── */
/* Task number → which puzzle and which of its routes is played (deterministic), and a pace factor 0.85…1.15 so the
   ball does not always stop where the route's reference stroke leaves it. The app plays that stroke on the engine
   to get the true resting point of the cue ball; the player's mark is scored against it. */
static inline int32_t BLPredictTask(int64_t number, int32_t *solution, double *paceFactor) {
    int32_t pool[BL_DAILY_POOL_MAX]; int32_t n = 0;
    for (int32_t i = 0; i < BLPuzzleCount() && n < BL_DAILY_POOL_MAX; ++i) if (BLPuzzleTable[i].spec.chapter > 0) pool[n++] = i;
    if (n == 0) return -1;
    uint64_t s = (uint64_t)number * 0x9E3779B97F4A7C15ULL + 0x51ED27;
    const uint64_t r1 = BLSplitMix64(&s), r2 = BLSplitMix64(&s), r3 = BLSplitMix64(&s);
    const int32_t p = pool[r1 % (uint64_t)n];
    if (solution) *solution = (int32_t)(r2 % (uint64_t)BLPuzzleTable[p].solutionCount);
    if (paceFactor) *paceFactor = 0.85 + 0.30 * (double)(r3 % 1000) / 999.0;
    return p;
}
/* 0…100 from the distance between the mark and where the ball really stopped: 100 within 2 cm, about 67 at 10 cm,
   37 at 25 cm, 2 at 1 m. */
static inline int32_t BLPredictScore(double errorMetres) {
    if (!(errorMetres >= 0)) return 0;
    if (errorMetres <= 0.02) return 100;
    const double v = 100.0 * exp(-errorMetres / 0.25);
    return (int32_t)(v + 0.5);
}

/* "Chỉ số Mắt": Elo. Start 1000. A task has a rating; a result is 0…1 (prediction score / 100, or 1 / 0 for a
   puzzle solved within three tries or not). K = 24. */
#define BL_EYE_START 1000.0
#define BL_EYE_K 24.0
static inline double BLEyeExpected(double rating, double taskRating) { return 1.0 / (1.0 + pow(10.0, (taskRating - rating) / 400.0)); }
static inline double BLEyeUpdate(double rating, double taskRating, double result) {
    if (result < 0) result = 0;
    if (result > 1) result = 1;
    const double next = rating + BL_EYE_K * (result - BLEyeExpected(rating, taskRating));
    return next < 100 ? 100 : next;
}
/* Rating of a prediction task: more cushions before the ball stops and more pace = harder to foresee. */
static inline double BLPredictTaskRating(int32_t signature, double speed) {
    const int32_t rails = signature / 100 + (signature / 10) % 10;
    return 900.0 + 120.0 * rails + (speed > 2.0 ? 80.0 : 0.0) + (speed > 3.0 ? 80.0 : 0.0);
}
/* Rating of a puzzle from its measured make rate: 50 % = 1000, 80 % ≈ 760, 30 % ≈ 1150. */
static inline double BLPuzzleTaskRating(int32_t percent) {
    const double p = percent < 5 ? 5 : (percent > 95 ? 95 : percent);
    return 1000.0 + 400.0 * log10((100.0 - p) / p);
}

/* ── 3. A puzzle for a friend ───────────────────────────────────────────────────────────────────────────────────
   Code: 15 Crockford base-32 characters = 64 payload bits + 10 check bits. Payload: style (2 bits: POT, REACH,
   HIDE), blockers (2 bits: 0…2), then cue ball, ball 1 and two blocker slots, each x in cm from the left rail
   (7 bits) and y in cm from the foot rail (8 bits). The receiver rebuilds the layout to the centimetre and its
   own checker (DrillCheck.hpp drillQuickFamilies) lists the routes: nothing but the layout travels. */
#define BL_USER_PUZZLE_CODE_LEN 15
static inline uint32_t BLUserPuzzleCheck(uint64_t payload) {
    uint64_t s = payload ^ 0x5A4F4B4552ULL;   /* "ZOKER" */
    return (uint32_t)(BLSplitMix64(&s) & 0x3FF);
}
static inline int BLUserPuzzleSpotOK(double x, double y) { return fabs(x) <= 0.635 - 0.04 && fabs(y) <= 1.27 - 0.04; }
/* Layout rules for a shareable puzzle: POT / REACH / HIDE, cue ball + ball 1 + 0…2 blockers, every ball ≥ 4 cm off
   the cushions and ≥ 7 cm from every other ball (after rounding to the centimetre). */
static inline int BLUserPuzzleValid(int32_t style, int32_t ballCount, const double *xs, const double *ys) {
    if ((style != BL_PUZZLE_POT && style != BL_PUZZLE_REACH && style != BL_PUZZLE_HIDE) || ballCount < 2 || ballCount > 4 || !xs || !ys) return 0;
    if (style != BL_PUZZLE_POT && ballCount < 3) return 0;   /* reach and hide need a blocker */
    for (int32_t i = 0; i < ballCount; ++i) {
        if (!BLUserPuzzleSpotOK(xs[i], ys[i])) return 0;
        for (int32_t j = 0; j < i; ++j) if (hypot(xs[i] - xs[j], ys[i] - ys[j]) < 0.07) return 0;
    }
    return 1;
}
/* Balls in order: cue ball, ball 1, blockers. Writes 15 characters + NUL. Returns 1 on success. */
static inline int BLUserPuzzleEncode(int32_t style, int32_t ballCount, const double *xs, const double *ys, char *out) {
    static const char alphabet[] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    if (!out || !BLUserPuzzleValid(style, ballCount, xs, ys)) return 0;
    double qx[4] = {0, 0, 0, 0}, qy[4] = {0, 0, 0, 0};
    uint64_t payload = ((uint64_t)style << 2) | (uint64_t)(ballCount - 2);
    for (int32_t i = 0; i < 4; ++i) {
        uint64_t cx = 0, cy = 0;
        if (i < ballCount) {
            cx = (uint64_t)floor((xs[i] + 0.635) * 100.0 + 0.5); cy = (uint64_t)floor((ys[i] + 1.27) * 100.0 + 0.5);
            qx[i] = (double)cx / 100.0 - 0.635; qy[i] = (double)cy / 100.0 - 1.27;
        }
        payload = (payload << 15) | (cx << 8) | cy;
    }
    if (!BLUserPuzzleValid(style, ballCount, qx, qy)) return 0;   /* rounding must not create a touch */
    const uint32_t check = BLUserPuzzleCheck(payload);
    /* 13 characters of payload (65 bits, top bit 0) then 2 characters of check */
    for (int i = 12; i >= 0; --i) { out[i] = alphabet[payload & 31]; payload >>= 5; }
    out[13] = alphabet[(check >> 5) & 31]; out[14] = alphabet[check & 31]; out[15] = 0;
    return 1;
}
static inline int32_t BLUserPuzzleDigit(char c) {
    if (c >= 'a' && c <= 'z') c = (char)(c - 'a' + 'A');
    if (c == 'O') c = '0';
    if (c == 'I' || c == 'L') c = '1';
    static const char alphabet[] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    for (int32_t i = 0; i < 32; ++i) if (alphabet[i] == c) return i;
    return -1;
}
/* Reads a code (spaces and dashes ignored, case-insensitive) into a puzzle spec ready for BLDrillJudge and the
   checker: key "user", room 0, no routes listed yet (solutionCount 0). Returns 1 when the code is well-formed. */
static inline int BLUserPuzzleDecode(const char *text, BLPuzzleSpec *out) {
    if (!text || !out) return 0;
    int32_t digits[BL_USER_PUZZLE_CODE_LEN]; int32_t n = 0;
    for (const char *p = text; *p; ++p) {
        if (*p == ' ' || *p == '-') continue;
        const int32_t v = BLUserPuzzleDigit(*p);
        if (v < 0 || n >= BL_USER_PUZZLE_CODE_LEN) return 0;
        digits[n++] = v;
    }
    if (n != BL_USER_PUZZLE_CODE_LEN || digits[0] > 15) return 0;   /* 13 × 5 = 65 bits: the top one must be 0 */
    uint64_t payload = 0;
    for (int32_t i = 0; i < 13; ++i) payload = (payload << 5) | (uint64_t)digits[i];
    if (BLUserPuzzleCheck(payload) != (uint32_t)((digits[13] << 5) | digits[14])) return 0;
    const int32_t style = (int32_t)((payload >> 62) & 3), ballCount = (int32_t)((payload >> 60) & 3) + 2;
    double xs[4], ys[4];
    for (int32_t i = 0; i < 4; ++i) {
        const uint64_t slot = (payload >> (15 * (3 - i))) & 0x7FFF;
        xs[i] = (double)(slot >> 8) / 100.0 - 0.635; ys[i] = (double)(slot & 0xFF) / 100.0 - 1.27;
        if (i >= ballCount && slot != 0) return 0;
    }
    if (!BLUserPuzzleValid(style, ballCount, xs, ys)) return 0;
    memset(out, 0, sizeof *out);
    BLDrillSpec *d = &out->spec;
    d->key = "user"; d->chapter = 0; d->ballCount = ballCount; d->skill = BL_SKILL_NONE; d->flags = BL_DRILL_LEGAL_FIRST;
    d->kind = style == BL_PUZZLE_REACH ? BL_DRILL_REACH : (style == BL_PUZZLE_HIDE ? BL_DRILL_SAFETY : BL_DRILL_GOAL);
    d->rails = style == BL_PUZZLE_REACH ? 1 : 0;
    d->potOnly = style == BL_PUZZLE_POT;
    for (int32_t i = 0; i < ballCount; ++i) { d->balls[i].id = i; d->balls[i].x = xs[i]; d->balls[i].y = ys[i]; }
    d->angle = atan2(ys[1] - ys[0], xs[1] - xs[0]);
    out->style = style;
    return 1;
}

/* ── 4. "Thách bạn" (0.58 P2): a ring challenge in the puzzle-code format ────────────────────────────────────────
   Same 15 characters, same check: style field 3 (puzzles use 0…2) marks a challenge. Payload (64 bits): style 3 (2) ·
   version 0 (2) · ring index in the stable catalogue (12) · stars 0…5 (3) · shots made 0…5 (3) · 42 bits of filler that
   the decoder recomputes from the first 22 bits (so every single-character typo is rejected, and the code looks like
   any other code). Nothing else travels: the receiver plays that ring and compares. */
#define BL_RING_CHALLENGE_STYLE 3
static inline uint64_t BLRingChallengeFill(uint64_t head22) {
    uint64_t s = head22 ^ 0x5448414348ULL;   /* "THACH" */
    return BLSplitMix64(&s) & ((1ULL << 42) - 1);
}
static inline int BLRingChallengeEncode(int32_t ring, int32_t stars, int32_t made, char *out) {
    static const char alphabet[] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    if (!out || ring < 0 || ring > 4095 || stars < 0 || stars > 5 || made < 0 || made > 5) return 0;
    const uint64_t head = ((uint64_t)BL_RING_CHALLENGE_STYLE << 20) | ((uint64_t)ring << 6) | ((uint64_t)stars << 3) | (uint64_t)made;
    uint64_t payload = (head << 42) | BLRingChallengeFill(head);
    const uint32_t check = BLUserPuzzleCheck(payload);
    for (int i = 12; i >= 0; --i) { out[i] = alphabet[payload & 31]; payload >>= 5; }
    out[13] = alphabet[(check >> 5) & 31]; out[14] = alphabet[check & 31]; out[15] = 0;
    return 1;
}
/* 1 and the three fields when `text` is a well-formed challenge (spaces and dashes ignored, case-insensitive); else 0. */
static inline int BLRingChallengeDecode(const char *text, int32_t *ring, int32_t *stars, int32_t *made) {
    if (!text || !ring || !stars || !made) return 0;
    int32_t digits[BL_USER_PUZZLE_CODE_LEN]; int32_t n = 0;
    for (const char *p = text; *p; ++p) {
        if (*p == ' ' || *p == '-') continue;
        const int32_t v = BLUserPuzzleDigit(*p);
        if (v < 0 || n >= BL_USER_PUZZLE_CODE_LEN) return 0;
        digits[n++] = v;
    }
    if (n != BL_USER_PUZZLE_CODE_LEN || digits[0] > 15) return 0;
    uint64_t payload = 0;
    for (int32_t i = 0; i < 13; ++i) payload = (payload << 5) | (uint64_t)digits[i];
    if (BLUserPuzzleCheck(payload) != (uint32_t)((digits[13] << 5) | digits[14])) return 0;
    const uint64_t head = payload >> 42;
    if ((head >> 20) != BL_RING_CHALLENGE_STYLE || ((head >> 18) & 3) != 0 || (payload & ((1ULL << 42) - 1)) != BLRingChallengeFill(head)) return 0;
    const int32_t st = (int32_t)((head >> 3) & 7), m = (int32_t)(head & 7);
    if (st > 5 || m > 5) return 0;
    *ring = (int32_t)((head >> 6) & 0xFFF); *stars = st; *made = m;
    return 1;
}
#endif
