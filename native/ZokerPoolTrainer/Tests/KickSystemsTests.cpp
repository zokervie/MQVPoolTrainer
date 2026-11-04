// 0.21 — published diamond systems as calibration targets (owner request 03/11/2026: "solve the systems in the
// pictures, build one general formula usable in drills, from 0 effect to left/right effect").
//
// Corner-5 / Diamond System (PoolDawg chart; Alciatore TP 7.2): A = D - T with running english, medium speed. It is
// empirical: each table "plays long/short" by up to 5 units (half a diamond), so the check is on the SPREAD of the
// error after the table's mean shift, plus |shift| <= 5. One-rail mirror (halving) kicks: geometric halfway point.
// App profile = BLWorld.mm (coupled cushions, rail beta .30, side-spin decay 11).
#include "../BankLab/Core/KickSystems.hpp"
#include <cstdio>
using namespace banklab;

static int failures = 0;
static void check(bool ok, const char* what) { std::printf("%s: %s\n", ok ? "PASS" : "FAIL", what); if (!ok) ++failures; }

int main() {
    Config c = Config::app();   // 0.30: the app profile (rail friction .45 measured, spin decay 18)

    // ---- corner-5 holds at medium speed with ~1.5 tips running english ----
    const auto base = kick::corner5Fit(c, 3, .35);
    std::printf("REPORT: corner-5, 3 m/s, running 0.35R: n=%d, table shift %+.1f, spread %.1f (10 = 1 diamond)\n", base.n, base.mean, base.spread);
    check(base.n >= 15, "corner-5: the standard chart (D 35-70, T 10-30) is playable");
    check(std::abs(base.mean) <= 5 && base.spread <= 3.5, "corner-5: A = D - T within a normal table's shift (<= 5) and spread <= 3.5");

    // ---- the general rule's corrections: english lengthens, speed shortens (what players learn) ----
    std::printf("REPORT: correction table (mean T - (D - A)), rows speed, columns running english 0.2/0.3/0.4/0.5 R\n");
    double grid[3][4]; const double speeds[3] = {2, 3, 4.5}, eng[4] = {.2, .3, .4, .5};
    for (int i = 0; i < 3; ++i) {
        std::printf("REPORT:   %.1f m/s:", speeds[i]);
        for (int j = 0; j < 4; ++j) { grid[i][j] = kick::corner5Fit(c, speeds[i], eng[j]).mean; std::printf(" %+6.1f", grid[i][j]); }
        std::printf("\n");
    }
    check(grid[1][1] < grid[1][2] && grid[1][2] < grid[1][3] && grid[2][1] < grid[2][2], "more running english -> ball arrives longer");
    check(grid[0][1] > grid[1][1] && grid[1][1] > grid[2][1], "harder stroke -> ball arrives shorter");

    // ---- one-rail mirror (halving) kicks ----
    auto mean = [&](double speed, double e) { double s = 0; int n = 0;
        for (double sep : {1.0, 1.5, 2.0}) for (double d : {.75, 1.5, 2.5}) { const double m = kick::mirrorMiss(c, sep, d, speed, e); if (!std::isnan(m)) { s += m; ++n; } }
        return n ? s / n : NAN; };
    for (double v : {2.0, 3.5}) {
        const double none = mean(v, 0), run = mean(v, .3), rev = mean(v, -.3);
        std::printf("REPORT: mirror kick %.1f m/s: miss none %+.2f, running %+.2f, reverse %+.2f diamond\n", v, none, run, rev);
        check(std::abs(none) <= .3, "mirror kick without english: within 0.3 diamond of the halfway rule");
        check(run > none + .3, "running english widens a one-rail kick by > 0.3 diamond");
    }
    // Open item (reported, owner observation 03/11): at medium speed reverse english barely shortens the rebound in
    // this model; at hard speed it does. Needs table measurements before changing the rail model.
    check(mean(3.5, -.3) < mean(3.5, 0), "hard stroke: reverse english shortens a one-rail kick");

    std::printf("%s\n", failures ? "KickSystems: FAILED" : "KickSystems: all checks passed");
    return failures ? 1 : 0;
}
