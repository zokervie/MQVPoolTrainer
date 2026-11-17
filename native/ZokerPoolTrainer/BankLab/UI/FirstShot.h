#ifndef BL_FIRST_SHOT_H
#define BL_FIRST_SHOT_H
#include <math.h>
/* 0.44.1 M1.2 "Cú đầu tiên" — the startup layout (Drill.startup). Shared by Models.swift (bridging header) and
   Tests/FirstShotTests.cpp. Table coordinates in metres, origin at the table centre, 9 ft table (1.27 × 2.54 m).
   Straight in along the 45° diagonal of the top-right corner pocket (World::pocket hole 5 at (0.67, 1.305)).
   Distances: chosen from the brief's ranges (cue–object 0.20–0.30 m, object–pocket 0.30–0.60 m) by a sweep of
   Physics.cpp (speed 0.8–4.0 m/s × aim error ±0.8°) — GIẢ ĐỊNH tuned to the solver, not measured on a table.
   Default tip 15 % of the radius below centre (brief allows "slightly below") so the cue ball never follows in. */
#define BL_FIRST_SHOT_POCKET_X (0.635 + 0.035)
#define BL_FIRST_SHOT_POCKET_Y (1.27 + 0.035)
#define BL_FIRST_SHOT_DIAGONAL 0.70710678118654752440
#define BL_FIRST_SHOT_OBJECT_TO_POCKET 0.40
#define BL_FIRST_SHOT_CUE_TO_OBJECT 0.22
/* Swift imports only literal macros, so the derived positions are inline functions. */
static inline double BLFirstShotObjectX(void) { return BL_FIRST_SHOT_POCKET_X - BL_FIRST_SHOT_DIAGONAL * BL_FIRST_SHOT_OBJECT_TO_POCKET; }
static inline double BLFirstShotObjectY(void) { return BL_FIRST_SHOT_POCKET_Y - BL_FIRST_SHOT_DIAGONAL * BL_FIRST_SHOT_OBJECT_TO_POCKET; }
static inline double BLFirstShotCueX(void) { return BLFirstShotObjectX() - BL_FIRST_SHOT_DIAGONAL * BL_FIRST_SHOT_CUE_TO_OBJECT; }
static inline double BLFirstShotCueY(void) { return BLFirstShotObjectY() - BL_FIRST_SHOT_DIAGONAL * BL_FIRST_SHOT_CUE_TO_OBJECT; }
static inline double BLFirstShotTop(void) { return -0.15; }
static inline double BLFirstShotAngle(void) {
    return atan2(BLFirstShotObjectY() - BLFirstShotCueY(), BLFirstShotObjectX() - BLFirstShotCueX());
}
#endif
