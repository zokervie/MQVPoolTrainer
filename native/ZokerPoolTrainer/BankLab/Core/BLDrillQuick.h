#ifndef BL_DRILL_QUICK_H
#define BL_DRILL_QUICK_H
#include "../UI/Puzzle.h"
#ifdef __cplusplus
extern "C" {
#endif
/* 0.51 N3 "Kiểm thế": the checker's quick route search (banklab::drillQuickFamilies, ~1 100 shots, a few seconds: call it OFF the main
   thread) for a puzzle layout. Fills `out` with up to `max` routes (best first) and returns how many were found (0 = no route). */
int32_t BLDrillQuickFamilies(const BLDrillSpec *spec, BLPuzzleSolution *out, int32_t max);
#ifdef __cplusplus
}
#endif
#endif
