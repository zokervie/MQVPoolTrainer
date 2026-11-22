// 0.54 — ring ladders, chapter completion, titles, take-back budget (BankLab/UI/Mastery.h) and the force-control
// chapter data. Rules are product decisions (owner 22/11/2026); the physics is only used to prove each rung has a
// reference stroke that the judge accepts.
extern "C" {
#include "../BankLab/UI/Mastery.h"
}
#include "../BankLab/Core/DrillCheck.hpp"
#include <cstring>
#include <iostream>
#include <string>
#include <vector>
using namespace banklab;
static int fails = 0, checks = 0;
static void check(bool ok, const std::string& what) { ++checks; if (!ok) { ++fails; std::cerr << "FAIL: " << what << "\n"; } }

int main() {
    // titles
    const int at[][2] = {{0, 0}, {49, 0}, {50, 1}, {64, 1}, {65, 2}, {70, 2}, {71, 3}, {75, 3}, {76, 4}, {80, 4}, {81, 5}, {85, 5},
                         {86, 6}, {90, 6}, {91, 7}, {95, 7}, {96, 8}, {99, 8}, {100, 9}, {140, 9}, {-5, 0}};
    for (auto& p : at) check(BLTitleIndex(p[0]) == p[1], "title band at " + std::to_string(p[0]) + " %");
    for (int i = 0; i < BL_TITLE_COUNT; ++i) check(BLTitleIndex(BLTitleLowerPercent(i)) == i, "title lower bound round trip");
    // completion
    { const int32_t s[4] = {3, 3, 3, 3}, h[4] = {3, 2, 0, 1}, bad[3] = {9, -2, 3};
      check(BLChapterPercent(s, 4) == 100 && BLChapterPercent(h, 4) == 50 && BLChapterPercent(bad, 3) == 66 && BLChapterPercent(nullptr, 3) == 0,
            "chapter % = best stars / (3 × rungs), clamped"); }
    // rings and warm-up
    check(BLTierOpen(1, 0) && !BLTierOpen(2, 2) && BLTierOpen(2, 3) && BLTierOpen(3, 3) && BLTierOpen(0, 0), "next ring opens at 3 stars");
    check(!BLWarmupDone(4) && BLWarmupDone(5), "warm-up: 5 made in the big ring");
    // take-backs
    check(BLChapterUndoBudget(1) == -1 && BLChapterUndoBudget(2) == 100 && BLChapterUndoBudget(3) == 70 && BLChapterUndoBudget(4) == 50 &&
          BLChapterUndoBudget(5) == 30 && BLChapterUndoBudget(9) == 30, "take-back budgets by chapter");
    check(BLChapterUndoLeft(2, 0) == 100 && BLChapterUndoLeft(2, 99) == 1 && BLChapterUndoLeft(2, 100) == 0 && BLChapterUndoLeft(2, 300) == 0 &&
          BLChapterUndoLeft(1, 999) == -1, "take-backs left never go negative; chapter 1 unlimited");
    check(BLChapterUndoAllowed(1, 500) && BLChapterUndoAllowed(3, 69) && !BLChapterUndoAllowed(3, 70), "take-back allowed until the budget is spent");
    check(BLChapterCleanSeal(72, 0) && !BLChapterCleanSeal(72, 1) && !BLChapterCleanSeal(40, 0), "clean seal: finished, no take-back");

    // the force-control chapter: 9 ladders × 3 rings, rings shrink, measured rate falls, three stars reachable
    int32_t rungs[64]; const int32_t n = BLLadderRungs(1, rungs, 64);
    check(n == 27, "chapter 1 has 27 rungs (9 ladders × 3 rings), found " + std::to_string(n));
    for (int32_t k = 0; k < n && k < 64; ++k) {
        const BLDrillSpec* d = BLDrillAt(rungs[k]); const std::string key = d->key;
        check(d->kind == BL_DRILL_GOAL && d->goalR > 0 && d->tier >= 1 && d->tier <= 3, key + ": ring rung");
        check(key.size() > 2 && key[key.size() - 2] == '-' && key.back() == char('0' + d->tier), key + ": key ends with the tier");
        check(d->makePercent >= 20 && d->makePercent <= 90, key + ": measured make rate in 20–90 %, got " + std::to_string(d->makePercent));
        const int32_t prev = BLLadderPrevious(rungs[k]);
        check((d->tier == 1) == (prev < 0), key + ": previous ring link");
        if (prev >= 0) {
            const BLDrillSpec* p = BLDrillAt(prev);
            check(std::string(p->key).substr(0, key.size() - 1) == key.substr(0, key.size() - 1), key + ": same ladder as the ring before");
            check(p->goalR > d->goalR && p->goalX == d->goalX && p->goalY == d->goalY, key + ": smaller ring, same centre");
            check(p->makePercent > d->makePercent, key + ": harder than the ring before (" + std::to_string(p->makePercent) + " → " + std::to_string(d->makePercent) + ")");
            bool same = p->ballCount == d->ballCount && p->rails == d->rails;
            for (int i = 0; same && i < d->ballCount; ++i) same = p->balls[i].x == d->balls[i].x && p->balls[i].y == d->balls[i].y;
            check(same, key + ": same layout as the ring before");
        }
        // stars: 0 below the pass mark, 3 reachable, monotonic
        const int32_t pass = BLDrillPassMade(d, 5);
        check(pass >= 1 && pass <= 5, key + ": pass mark within a 5-shot round");
        check(BLRoundStars(d, pass - 1, 5) == 0 && BLRoundStars(d, pass, 5) >= 1 && BLRoundStars(d, 5, 5) == 3, key + ": round stars at the pass mark and at 5/5");
        int last = 0; bool mono = true; for (int m = 0; m <= 5; ++m) { const int s = BLRoundStars(d, m, 5); mono = mono && s >= last; last = s; }
        check(mono, key + ": more made never gives fewer stars");
        // the reference stroke is accepted by the judge, with the exact cushion count
        BLDrillLayout L; BLDrillLayoutFor(d, 0, &L);
        check(drillShot(*d, L, d->solveAngle, d->solveSpeed, 0, d->solveTop), key + ": reference stroke makes the rung");
    }
    // exact cushion rule (judge): a force rung with rails = 1 rejects 0 and 2 cushions even inside the ring
    {
        BLDrillSpec d{}; d.key = "t"; d.kind = BL_DRILL_GOAL; d.rails = 1; d.ballCount = 1; d.goalX = 0; d.goalY = 0; d.goalR = 0.2;
        const int32_t ids[1] = {0}, sunk[1] = {0}; const double xs[1] = {0.05}, ys[1] = {0.05};
        const int32_t k0[1] = {0}, a0[1] = {0}, b0[1] = {2}, k2[2] = {0, 0}, a2[2] = {0, 0}, b2[2] = {2, 3};
        check(BLDrillJudge(&d, nullptr, 1, k0, a0, b0, 1, ids, xs, ys, sunk) == 1, "judge: one cushion, in the ring");
        check(BLDrillJudge(&d, nullptr, 0, nullptr, nullptr, nullptr, 1, ids, xs, ys, sunk) == 0, "judge: no cushion is not the drill");
        check(BLDrillJudge(&d, nullptr, 2, k2, a2, b2, 1, ids, xs, ys, sunk) == 0, "judge: two cushions is not the drill");
        d.rails = 0; check(BLDrillJudge(&d, nullptr, 2, k2, a2, b2, 1, ids, xs, ys, sunk) == 1, "judge: rails 0 keeps the old rule (any path)");
    }
    std::cout << (fails ? "FAILED " : "PASS Mastery: ") << checks - fails << "/" << checks << " checks; titles, completion, ring ladders, take-backs, force chapter\n";
    return fails ? 1 : 0;
}
