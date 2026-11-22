#ifndef BL_MASTERY_H
#define BL_MASTERY_H
/* 0.54 "Làm chủ chương" — ring ladders, chapter completion, titles and the take-back budget. Plain C (Swift imports it
 * through the bridging header, the C++ tests include it). Every threshold here is a product decision of the owner
 * (22/11/2026) or a GIẢ ĐỊNH to be tuned with TestFlight numbers; none is a physics value.
 *
 *  - A ring ladder is three consecutive catalogue rows with tier 1, 2, 3 (same layout, smaller ring).
 *  - Warm-up: the ladder starts scoring after BL_WARMUP_MADE shots made in the big ring          [chủ dự án: 5]
 *  - The next ring opens when the ring before it has BL_TIER_OPEN_STARS stars                    [chủ dự án: 3]
 *  - A scored round is 5 shots; its stars come from BLRoundStars.
 *  - Chapter completion % = best stars earned / (3 × rungs), rounded down.
 *  - Title = band of that % (10 bands; names live in Swift, keyed by the index).
 *  - Take-backs ("lùi cú") per chapter: 1 unlimited, 2 → 100, 3 → 70, 4 → 50, 5+ → 30            [chủ dự án]
 *    Running out never resets progress: the player keeps playing without take-backs.            [đề xuất, đã duyệt B]
 *  - "Tay sạch" seal: chapter finished (≥ BL_TITLE_FIRST_PERCENT) with no take-back used.
 */
#include <stdint.h>
#include "DrillCatalog.h"

#define BL_WARMUP_MADE 5
#define BL_TIER_OPEN_STARS 3
#define BL_TITLE_COUNT 10
#define BL_TITLE_FIRST_PERCENT 50   /* below this the player still gets title 0 ("Tay Mơ Có Chí") */

/* Title index 0…9 for a completion % (0…100). Bands: <50 · 50–64 · 65–70 · 71–75 · 76–80 · 81–85 · 86–90 · 91–95 · 96–99 · 100 */
static inline int32_t BLTitleIndex(int32_t percent) {
    static const int32_t lower[BL_TITLE_COUNT] = { 0, 50, 65, 71, 76, 81, 86, 91, 96, 100 };
    int32_t i = 0;
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;
    for (int32_t k = 1; k < BL_TITLE_COUNT; ++k) if (percent >= lower[k]) i = k;
    return i;
}
/* Lowest % of a title (for "còn N % nữa lên bậc"); index out of range → 100. */
static inline int32_t BLTitleLowerPercent(int32_t index) {
    static const int32_t lower[BL_TITLE_COUNT] = { 0, 50, 65, 71, 76, 81, 86, 91, 96, 100 };
    return index >= 0 && index < BL_TITLE_COUNT ? lower[index] : 100;
}
/* Completion % from the best stars (0…3) of the chapter's rungs. */
static inline int32_t BLChapterPercent(const int32_t *bestStars, int32_t count) {
    if (!bestStars || count <= 0) return 0;
    int32_t sum = 0;
    for (int32_t i = 0; i < count; ++i) sum += bestStars[i] < 0 ? 0 : (bestStars[i] > 3 ? 3 : bestStars[i]);
    return sum * 100 / (3 * count);
}
/* Stars of one scored round on a rung (`made` of `shots`): below the pass mark 0; pass mark 1; +1 made 2; +2 made
 * (or every shot) 3. The pass mark is the drill's own (BLDrillPassMade: measured make rate − 15 points), so a small
 * ring asks for fewer balls than a big one and three stars stay reachable on every rung.          [GIẢ ĐỊNH] */
static inline int32_t BLRoundStars(const BLDrillSpec *d, int32_t made, int32_t shots) {
    if (!d || shots <= 0) return 0;
    if (made > shots) made = shots;
    const int32_t pass = BLDrillPassMade(d, shots);
    if (made < pass) return 0;
    if (made >= shots || made >= pass + 2) return 3;
    return made >= pass + 1 ? 2 : 1;
}
/* Is this rung playable? Tier 0/1 always; tier 2/3 when the ring before it has the stars. */
static inline int BLTierOpen(int32_t tier, int32_t starsOfPreviousTier) {
    return tier <= 1 || starsOfPreviousTier >= BL_TIER_OPEN_STARS;
}
static inline int BLWarmupDone(int32_t madeInBigRing) { return madeInBigRing >= BL_WARMUP_MADE; }
/* Take-backs granted for a chapter; -1 = unlimited. */
static inline int32_t BLChapterUndoBudget(int32_t chapter) {
    if (chapter <= 1) return -1;
    if (chapter == 2) return 100;
    if (chapter == 3) return 70;
    if (chapter == 4) return 50;
    return 30;
}
/* Take-backs left (never negative); -1 = unlimited. */
static inline int32_t BLChapterUndoLeft(int32_t chapter, int32_t used) {
    const int32_t budget = BLChapterUndoBudget(chapter);
    if (budget < 0) return -1;
    return used >= budget ? 0 : budget - (used < 0 ? 0 : used);
}
static inline int BLChapterUndoAllowed(int32_t chapter, int32_t used) { return BLChapterUndoLeft(chapter, used) != 0; }
static inline int BLChapterCleanSeal(int32_t percent, int32_t undoUsed) { return percent >= BL_TITLE_FIRST_PERCENT && undoUsed == 0; }

/* 0.56 power-bar rescue (owner 22/11 18:21): no power-bar switch on the play screen. The bar is offered only as a
 * rescue, inside a chapter with a take-back budget, when the player is down to the last BL_RESCUE_UNDO_LEFT take-backs
 * AND the rung is hard (measured make rate < BL_RESCUE_HARD_PERCENT) or has beaten them BL_RESCUE_FAILED_ROUNDS
 * scored rounds in a row. Never in chapter 1 (the force chapter: the bar would do the drill for them).
 * Using the rescue counts as help: no "Tay sạch" seal for that chapter.     [quyết định chủ dự án; 35 % và 3: GIẢ ĐỊNH] */
#define BL_RESCUE_UNDO_LEFT 10
#define BL_RESCUE_HARD_PERCENT 35
#define BL_RESCUE_FAILED_ROUNDS 3
static inline int BLPowerBarRescue(int32_t chapter, int32_t undoUsed, int32_t makePercent, int32_t failedRoundsInARow) {
    if (chapter <= 1) return 0;
    const int32_t left = BLChapterUndoLeft(chapter, undoUsed);
    if (left < 0 || left > BL_RESCUE_UNDO_LEFT) return 0;
    return makePercent < BL_RESCUE_HARD_PERCENT || failedRoundsInARow >= BL_RESCUE_FAILED_ROUNDS;
}
static inline int BLChapterCleanSealNoHelp(int32_t percent, int32_t undoUsed, int32_t rescueUsed) {
    return BLChapterCleanSeal(percent, undoUsed) && rescueUsed == 0;
}

/* Ladder helpers on the catalogue: rungs of a chapter (rows with tier > 0), and the row of the previous ring. */
static inline int32_t BLLadderRungs(int32_t chapter, int32_t *indices, int32_t capacity) {
    int32_t n = 0;
    for (int32_t i = 0; i < BLDrillCount(); ++i) {
        const BLDrillSpec *d = BLDrillAt(i);
        if (d && d->chapter == chapter && d->tier > 0) { if (indices && n < capacity) indices[n] = i; ++n; }
    }
    return n;
}
static inline int32_t BLLadderPrevious(int32_t index) {
    const BLDrillSpec *d = BLDrillAt(index), *p = BLDrillAt(index - 1);
    return d && p && d->tier > 1 && p->tier == d->tier - 1 && p->chapter == d->chapter ? index - 1 : -1;
}
#endif
