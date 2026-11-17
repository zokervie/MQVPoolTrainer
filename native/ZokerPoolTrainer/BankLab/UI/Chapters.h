#ifndef BL_CHAPTERS_H
#define BL_CHAPTERS_H
#include <stdint.h>
/* 0.47 M0 "Kho bài theo chương" — pure unlock rules, shared by Swift (bridging header) and Tests/ChapterTests.cpp.
   Plain C, static inline (like DailyLoop.h). Swift keeps the catalogue (which drill is in which chapter, the tip text);
   this file only decides what is open.

   Rules (brief, after Billiard University's ladder): every drill is played as a 5-shot round; ≥ 3/5 made opens the
   next rung. A drill's stars are the best round (stars = made shots, 5 needs an average ≥ 85), so "≥ 3 stars" is the
   same as "≥ 3/5 made". When every rung of a chapter is cleared the chapter exam opens: 10 shots without help,
   ≥ 7/10 opens the next chapter. Thresholds: GIẢ ĐỊNH (design, from the brief), not measured.
   Players from ≤ 0.46 keep what they earned: a chapter in which they already hold stars is open, and so is every
   chapter before it (nobody is sent back to relearn). A chapter whose drills are not written yet (0 drills) never
   blocks the chain: it is open as soon as the chapter before it is, and counts as passed. */
#define BL_RUNG_PASS_STARS 3
#define BL_EXAM_SHOTS 10
#define BL_EXAM_PASS_MADE 7
#define BL_CHAPTER_MAX 16

/* Rung `rung` (0-based) of a chapter whose chapter is open: the first rung, a rung after a cleared one, or a rung the
   player already has stars on. */
static inline int BLRungOpen(int32_t rung, int32_t previousStars, int32_t ownStars) {
    return rung <= 0 || previousStars >= BL_RUNG_PASS_STARS || ownStars > 0;
}
/* The exam opens when the chapter has drills and every one is cleared. */
static inline int BLExamOpen(const int32_t *stars, int32_t count) {
    if (!stars || count <= 0) return 0;
    for (int32_t i = 0; i < count; ++i) if (stars[i] < BL_RUNG_PASS_STARS) return 0;
    return 1;
}
/* A finished exam passes with ≥ 7 made out of exactly 10 shots (an interrupted exam never passes). */
static inline int BLExamPassed(int32_t made, int32_t shots) {
    return shots == BL_EXAM_SHOTS && made >= BL_EXAM_PASS_MADE && made <= shots;
}
/* For `count` chapters in order: drillCount[c], examPassed[c] (0/1), bestStars[c] = best stars on any of its drills.
   Writes open[c] = 0/1 and returns the number of open chapters. Chapter 0 is always open. */
static inline int32_t BLChaptersOpen(int32_t count, const int32_t *drillCount, const int32_t *examPassed,
                                     const int32_t *bestStars, int32_t *open) {
    if (!drillCount || !examPassed || !bestStars || !open || count <= 0) return 0;
    if (count > BL_CHAPTER_MAX) count = BL_CHAPTER_MAX;
    int32_t legacyUpTo = -1;   /* last chapter with stars already earned */
    for (int32_t c = 0; c < count; ++c) if (bestStars[c] > 0) legacyUpTo = c;
    int32_t n = 0;
    for (int32_t c = 0; c < count; ++c) {
        int o = c == 0 || c <= legacyUpTo;
        if (!o && open[c - 1]) o = examPassed[c - 1] != 0 || drillCount[c - 1] <= 0;
        open[c] = o ? 1 : 0;
        n += open[c];
    }
    return n;
}
#endif
