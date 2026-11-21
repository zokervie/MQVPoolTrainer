// 0.50 Thế bí — re-centres and re-rates every listed route against the compiled puzzle table (run by
// collect_puzzles.py after puzzles.json changes). One JSON line per route: key, index, ok, angle, percent.
#include "../../BankLab/Core/DrillCheck.hpp"
#include "../../BankLab/UI/Puzzle.h"
#include <cstdio>
using namespace banklab;
int main() {
    for (int32_t i = 0; i < BLPuzzleCount(); ++i) {
        const BLPuzzleSpec& p = *BLPuzzleAt(i);
        if (p.spec.chapter <= 0) continue;
        BLDrillLayout L; BLDrillLayoutFor(&p.spec, 0, &L);
        for (int32_t s = 0; s < p.solutionCount; ++s) {
            const BLPuzzleSolution& so = p.solutions[s];
            const double step = 0.05; const int half = 30;   // ±1.5°
            int bestLen = 0, bestFirst = 0, len = 0, first = 0;
            for (int k = -half; k <= half + 1; ++k) {
                DrillShotInfo info;
                const bool ok = k <= half && drillShot(p.spec, L, so.angle + k * step * pi / 180, so.speed, 0, so.top, 14, &info) &&
                                BLPuzzleRoute(&p.spec, info.signature) == so.signature;
                if (ok) { if (!len) first = k; ++len; }
                else if (len) { if (len > bestLen) { bestLen = len; bestFirst = first; } len = 0; }
            }
            if (!bestLen) { printf("{\"key\":\"%s\",\"i\":%d,\"ok\":0}\n", p.spec.key, s); continue; }
            DrillFamily f; f.signature = so.signature; f.speed = so.speed; f.top = so.top;
            f.angle = so.angle + (bestFirst + (bestLen - 1) / 2.0) * step * pi / 180;
            DrillShotInfo info;
            const bool ok = drillShot(p.spec, L, f.angle, f.speed, 0, f.top, 14, &info) && BLPuzzleRoute(&p.spec, info.signature) == so.signature;
            const int pct = ok ? int(std::lround(drillRouteRate(p.spec, L, f, 100, 1) * 100)) : 0;
            printf("{\"key\":\"%s\",\"i\":%d,\"ok\":%d,\"angle\":%.17g,\"percent\":%d,\"hint\":[%.17g,%.17g]}\n", p.spec.key, s, ok ? 1 : 0,
                   f.angle, pct, info.hint.x, info.hint.y);
            fflush(stdout);
        }
    }
}
