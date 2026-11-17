#ifndef BL_INTRO_BREAK_ACCESS_H
#define BL_INTRO_BREAK_ACCESS_H
#include "IntroBreak.h"
/* Swift sees C arrays as tuples; these read the generated intro break table by index. */
static inline double BLIntroBall(int i, int k) { return (i >= 0 && i < BL_INTRO_BALL_COUNT && k >= 0 && k < 3) ? BLIntroBalls[i][k] : 0; }
#endif
