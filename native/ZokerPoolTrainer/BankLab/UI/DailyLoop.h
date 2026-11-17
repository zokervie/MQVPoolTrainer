#ifndef BL_DAILY_LOOP_H
#define BL_DAILY_LOOP_H
#include <math.h>
#include <stdint.h>
/* 0.47 "Quay lại mỗi ngày" — pure logic, shared by Swift (bridging header) and Tests/DailyLoopTests.cpp.
   Written by the cloud session on cho/native-0.47-core; the Mac session wires the UI.
   Plain C (static inline) so Swift can call it through the bridging header, like PowerScale.h / FirstShot.h.

   Sources of numbers: every threshold below is GIẢ ĐỊNH (design choice, not measured), marked where it appears.
   Days are local calendar days: BLDayIndex(unix seconds, the device's UTC offset at that instant). */

/* ---------- M1 · Power bar ---------------------------------------------------------------------------------------
   Fraction 0…1 of the bar → cue-ball speed (m/s). Geometric, like the 1–30 "Lực" scale (PowerScale.h): equal bar
   travel = equal speed RATIO, which matches how players judge "a bit harder". 0 → BL_POWER_BAR_MIN_SPEED,
   1 → maxSpeed (the Tuỳ chỉnh ceiling). Non-finite / out-of-range input is clamped. */
#define BL_POWER_BAR_MIN_SPEED 0.5   /* same floor as BL_POWER_MIN_SPEED */
static inline double BLPowerBarSpeed(double fraction, double maxSpeed) {
    if (!(maxSpeed > BL_POWER_BAR_MIN_SPEED) || !isfinite(maxSpeed)) return BL_POWER_BAR_MIN_SPEED;
    if (!(fraction > 0) || !isfinite(fraction)) fraction = 0;   /* NaN → 0 */
    if (fraction > 1) fraction = 1;
    return BL_POWER_BAR_MIN_SPEED * pow(maxSpeed / BL_POWER_BAR_MIN_SPEED, fraction);
}
/* Inverse (for showing where a remembered speed sits on the bar). */
static inline double BLPowerBarFraction(double speed, double maxSpeed) {
    if (!(maxSpeed > BL_POWER_BAR_MIN_SPEED) || !isfinite(maxSpeed) || !(speed > BL_POWER_BAR_MIN_SPEED) || !isfinite(speed)) return 0;
    if (speed >= maxSpeed) return 1;
    return log(speed / BL_POWER_BAR_MIN_SPEED) / log(maxSpeed / BL_POWER_BAR_MIN_SPEED);
}

/* ---------- Days ------------------------------------------------------------------------------------------------ */
static inline int64_t BLFloorDiv(int64_t a, int64_t b) { int64_t q = a / b; return (a % b != 0 && ((a < 0) != (b < 0))) ? q - 1 : q; }
/* Local calendar day number (days since 1970-01-01 local). utcOffsetSeconds = TimeZone.current.secondsFromGMT(for:). */
static inline int64_t BLDayIndex(int64_t unixSeconds, int32_t utcOffsetSeconds) { return BLFloorDiv(unixSeconds + utcOffsetSeconds, 86400); }
/* ISO week number since the epoch, weeks start on Monday (day 0 = Thursday 1970-01-01 → +3). */
static inline int64_t BLWeekIndex(int64_t day) { return BLFloorDiv(day + 3, 7); }

/* ---------- M2 · Streak with weekly freeze ------------------------------------------------------------------------
   Rule (brief): finishing ≥ 1 drill on a local day extends the streak by one. One freeze per week (refilled Monday)
   is spent automatically to cover exactly ONE missed day. Missing two days (or one with no freeze) resets to 1 on
   the next completion. A clock set backwards never adds to the streak. */
typedef struct {
    int32_t count;       /* current streak in days (0 = none yet) */
    int32_t best;        /* longest streak ever */
    int64_t lastDay;     /* local day of the last completion; INT64_MIN-ish sentinel = never */
    int32_t freezes;     /* 0 or 1 available */
    int64_t freezeWeek;  /* week the freeze stock was last refilled */
    int32_t freezesUsed; /* lifetime count, for the progress screen */
} BLStreak;
#define BL_STREAK_NEVER (-1000000000LL)
#define BL_STREAK_FREEZES_PER_WEEK 1   /* GIẢ ĐỊNH (brief) */
static inline BLStreak BLStreakNew(void) { BLStreak s; s.count = 0; s.best = 0; s.lastDay = BL_STREAK_NEVER; s.freezes = 0; s.freezeWeek = BL_STREAK_NEVER; s.freezesUsed = 0; return s; }
static inline void BLStreakRefill(BLStreak *s, int64_t today) {
    const int64_t week = BLWeekIndex(today);
    if (week > s->freezeWeek) { s->freezes = BL_STREAK_FREEZES_PER_WEEK; s->freezeWeek = week; }
}
/* Record a completed drill on `today`. Returns 1 if the streak grew (show "+1 ngày"), 0 otherwise. */
static inline int BLStreakComplete(BLStreak *s, int64_t today) {
    if (s->lastDay != BL_STREAK_NEVER && today <= s->lastDay) return 0;   /* same day, or clock moved back */
    BLStreakRefill(s, today);
    const int64_t gap = s->lastDay == BL_STREAK_NEVER ? -1 : today - s->lastDay;
    if (gap == 1) s->count += 1;
    else if (gap == 2 && s->freezes > 0) { s->freezes -= 1; s->freezesUsed += 1; s->count += 1; }
    else s->count = 1;
    s->lastDay = today;
    if (s->count > s->best) s->best = s->count;
    return 1;
}
/* Streak to SHOW on `today` without recording anything: still alive if done today/yesterday, or the day before
   yesterday with a freeze that would cover yesterday. Otherwise 0 (it will restart at 1 on the next completion). */
static inline int32_t BLStreakShown(BLStreak s, int64_t today) {
    if (s.lastDay == BL_STREAK_NEVER || today < s.lastDay) return s.lastDay == BL_STREAK_NEVER ? 0 : s.count;
    BLStreakRefill(&s, today);
    const int64_t gap = today - s.lastDay;
    if (gap <= 1) return s.count;
    if (gap == 2 && s.freezes > 0) return s.count;
    return 0;
}

/* ---------- M2 · Level and "Bài hôm nay" ----------------------------------------------------------------------------
   Level 1–5 follows the last 7 days: ≥ 10 attempts and ≥ 70 % made → up one; < 35 % → down one (GIẢ ĐỊNH). */
#define BL_LEVEL_MIN_ATTEMPTS 10
#define BL_LEVEL_UP_RATE 0.70
#define BL_LEVEL_DOWN_RATE 0.35
static inline int32_t BLNextLevel(int32_t level, int32_t attempts7d, int32_t made7d) {
    if (level < 1) level = 1;
    if (level > 5) level = 5;
    if (attempts7d < BL_LEVEL_MIN_ATTEMPTS || made7d < 0 || made7d > attempts7d) return level;
    const double rate = (double)made7d / (double)attempts7d;
    if (rate >= BL_LEVEL_UP_RATE && level < 5) return level + 1;
    if (rate < BL_LEVEL_DOWN_RATE && level > 1) return level - 1;
    return level;
}
static inline uint64_t BLSplitMix64(uint64_t *x) {
    uint64_t z = (*x += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL; z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}
#define BL_DAILY_COUNT 3
/* Pick BL_DAILY_COUNT distinct drills for `day`. stars[i] = difficulty 1–5 of drill i (≤ 0 = not eligible, e.g. locked).
   Preference: |stars − level| = 0, then 1, then 2 …; inside a band the order is a deterministic shuffle seeded by the
   day, so everyone at the same level gets the same three on the same day and tomorrow differs.
   category[i] (may be NULL) = kind of drill (cut, bank, position…). Interleaving: inside the allowed bands a drill
   whose category is not yet in today's set is always taken before one that repeats a category — mixed (varied)
   practice gives better retention and transfer than blocked practice (contextual interference; motor-learning
   literature), while the level band keeps the difficulty right.
   Writes indices to out[0..n-1] in play order (easiest first) and returns n (< 3 only if fewer eligible drills). */
static inline int32_t BLDailyPickMixed(int64_t day, int32_t level, const int32_t *stars, const int32_t *category, int32_t drillCount, int32_t *out);
static inline int32_t BLDailyPick(int64_t day, int32_t level, const int32_t *stars, int32_t drillCount, int32_t *out) {
    return BLDailyPickMixed(day, level, stars, 0, drillCount, out);
}
static inline int32_t BLDailyPickMixed(int64_t day, int32_t level, const int32_t *stars, const int32_t *category, int32_t drillCount, int32_t *out) {
    if (!stars || !out || drillCount <= 0) return 0;
    uint64_t seed = (uint64_t)day * 0x2545F4914F6CDD1DULL ^ 0x5A6F6B6572ULL;   /* "Zoker" */
    int32_t n = 0;
    /* Pass 0 takes only drills of a category not yet picked; pass 1 fills what is left. Within a pass, the nearest
       difficulty band wins; inside a band the smallest day-seeded key wins. Variety may stretch difficulty by at most
       one level (pass 0 stops at band 1); beyond that a repeated kind at the right level is preferred. */
    for (int32_t pass = 0; pass < 2 && n < BL_DAILY_COUNT; ++pass) {
        for (int32_t band = 0; band <= (pass == 0 ? 1 : 4) && n < BL_DAILY_COUNT; ++band) {
            for (int32_t take = n; take < BL_DAILY_COUNT; ++take) {
                int32_t best = -1; uint64_t bestKey = 0;
                for (int32_t i = 0; i < drillCount; ++i) {
                    if (stars[i] <= 0) continue;
                    const int32_t d = stars[i] > level ? stars[i] - level : level - stars[i];
                    if (d != band) continue;
                    int dup = 0, sameKind = 0;
                    for (int32_t k = 0; k < n; ++k) {
                        if (out[k] == i) dup = 1;
                        if (category && category[out[k]] == category[i]) sameKind = 1;
                    }
                    if (dup || (pass == 0 && sameKind)) continue;
                    uint64_t x = seed ^ ((uint64_t)(i + 1) * 0x9E3779B97F4A7C15ULL);
                    const uint64_t key = BLSplitMix64(&x);
                    if (best < 0 || key < bestKey) { best = i; bestKey = key; }
                }
                if (best < 0) break;
                out[n++] = best;
            }
        }
    }
    /* easiest first (stable by index for equal stars) */
    for (int32_t a = 1; a < n; ++a) for (int32_t b = a; b > 0; --b) {
        const int32_t x = out[b - 1], y = out[b];
        if (stars[x] > stars[y] || (stars[x] == stars[y] && x > y)) { out[b - 1] = y; out[b] = x; } else break;
    }
    return n;
}

/* ---------- M3 · Difficulty stars and records --------------------------------------------------------------------
   marginDeg = half-width (degrees) of the aim window that still makes the shot, as computed by the same simulation
   sweep the computer opponent uses. Wider window = easier. Bands GIẢ ĐỊNH; "Cú đầu tiên" (makes at ±0.8° and more)
   must be 1–2 stars. */
static inline int32_t BLStarsFromMargin(double marginDeg) {
    if (!(marginDeg >= 0) || !isfinite(marginDeg)) return 5;
    if (marginDeg >= 2.0) return 1;
    if (marginDeg >= 1.2) return 2;
    if (marginDeg >= 0.7) return 3;
    if (marginDeg >= 0.4) return 4;
    return 5;
}
/* A personal best is announced only when there WAS a previous result and the new one beats it by more than
   epsilon (no "Kỷ lục mới!" on the very first try, nor on a tie). higherIsBetter: 1 for made-rate / stars, 0 for time. */
static inline int BLIsNewRecord(int hasPrevious, double previous, double value, int higherIsBetter, double epsilon) {
    if (!hasPrevious || !isfinite(previous) || !isfinite(value)) return 0;
    if (!(epsilon >= 0)) epsilon = 0;
    return higherIsBetter ? (value > previous + epsilon) : (value < previous - epsilon);
}
#endif
