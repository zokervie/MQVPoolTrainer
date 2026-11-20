// 0.49b Xưởng bài — full search for every drill (minutes; not part of the CI gate). Prints one JSON object per line:
//   {"key":…, "angle":…, "speed":…, "top":…, "percent":…, "window":…, "shots":…}
// Tools/drills/drill_sweep.sh merges them into measured.json and regenerates DrillCatalogData.h.
// Usage: drill_sweep [key …]   (no key = every swept drill)
#include "../../BankLab/Core/DrillCheck.hpp"
#include <cstdio>
#include <cstring>
using namespace banklab;
int main(int argc, char** argv) {
    int failed = 0;
    for (int32_t i = 0; i < BLDrillCount(); ++i) {
        const BLDrillSpec* d = BLDrillAt(i);
        if (d->scanDegrees <= 0) continue;
        bool wanted = argc < 2;
        for (int k = 1; k < argc; ++k) if (!strcmp(argv[k], d->key)) wanted = true;
        if (!wanted) continue;
        BLDrillLayout L; BLDrillLayoutFor(d, 0, &L);
        const DrillSweep r = sweepDrill(*d, L);
        if (!r.solvable) { ++failed; fprintf(stderr, "NO SOLUTION: %s\n", d->key); continue; }
        printf("{\"key\":\"%s\",\"angle\":%.6f,\"speed\":%.3f,\"top\":%.3f,\"percent\":%d,\"window\":%.2f,\"shots\":%ld}\n",
               d->key, r.angle, r.speed, r.top, int(std::lround(r.makeRate * 100)), r.windowDeg, r.shots);
        fflush(stdout);
    }
    return failed ? 1 : 0;
}
