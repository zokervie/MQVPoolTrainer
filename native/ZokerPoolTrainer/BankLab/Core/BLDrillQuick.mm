#import <Foundation/Foundation.h>
#include "BLDrillQuick.h"
#include "DrillCheck.hpp"
using namespace banklab;

int32_t BLDrillQuickFamilies(const BLDrillSpec *spec, BLPuzzleSolution *out, int32_t max) {
    if (!spec || !out || max <= 0) return 0;
    const std::vector<DrillFamily> families = drillQuickFamilies(*spec);
    int32_t n = 0;
    for (const DrillFamily &f : families) {
        if (n >= max) break;
        out[n].signature = f.signature; out[n].angle = f.angle; out[n].speed = f.speed; out[n].top = f.top;
        out[n].percent = f.percent; out[n].hintX = f.hint.x; out[n].hintY = f.hint.y;
        ++n;
    }
    return n;
}
