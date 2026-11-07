// 0.31 — contact ordering. Same physics must not depend on the order balls are listed, and a centred
// straight break of a symmetric rack must end mirror-symmetric (real breaks vary from rack gaps and
// aim error, never from the solver). Before 0.31 (pairs solved in array order) both were off by ~1.2 m.
#include "../BankLab/Core/Physics.hpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <vector>
using namespace banklab;

static int failures = 0;
static void check(bool ok, const char* what) { std::printf("%s: %s\n", ok ? "PASS" : "FAIL", what); if (!ok) ++failures; }

static std::vector<Ball> rack(double gap) {
    std::vector<Ball> v; const double R = Config().radius, d = 2 * R + gap; int id = 1;
    for (int row = 0; row < 5; ++row) for (int k = 0; k <= row; ++k) { Ball b; b.id = id++; b.p = {(k - row / 2.0) * d, .635 + row * d * std::sqrt(3) / 2}; v.push_back(b); }
    return v;
}
static std::vector<Ball> breakShot(double gap, bool reversed, double seconds) {
    World w(Config::app()); Ball cue; cue.id = 0; cue.p = {0, -.635}; auto r = rack(gap);
    if (reversed) std::reverse(r.begin(), r.end());
    w.balls = {cue}; for (const auto& b : r) w.balls.push_back(b);
    w.strike(pi / 2, 10, 0, 0);
    for (int i = 0; i < int(960 * seconds); ++i) w.step();
    std::vector<Ball> out(16); for (const auto& b : w.balls) out[b.id] = b; return out;
}

int main() {
    for (double gap : {0.0, 0.0005}) {
        const auto t0 = std::chrono::steady_clock::now();
        const auto a = breakShot(gap, false, 6), b = breakShot(gap, true, 6);
        const double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count() / 2;
        const auto r = rack(gap);
        double order = 0, mirror = 0; int sunkOrder = 0;
        for (int i = 1; i < 16; ++i) {
            if (a[i].sunk != b[i].sunk) { ++sunkOrder; continue; }
            if (!a[i].sunk) order = std::max(order, std::hypot(a[i].p.x - b[i].p.x, a[i].p.y - b[i].p.y));
        }
        for (const auto& p : r) for (const auto& q : r)
            if (std::abs(p.p.x + q.p.x) < 1e-9 && std::abs(p.p.y - q.p.y) < 1e-9 && !a[p.id].sunk && !a[q.id].sunk)
                mirror = std::max(mirror, std::hypot(a[p.id].p.x + a[q.id].p.x, a[p.id].p.y - a[q.id].p.y));
        std::printf("REPORT: rack gap %.1f mm, 10 m/s centred break: order effect %.1f mm, mirror asymmetry %.1f mm, %.0f ms per 6 s break\n",
                    gap * 1000, order * 1000, mirror * 1000, ms);
        check(sunkOrder == 0, "listing order does not change which balls are pocketed");
        check(order < (gap > 0 ? .002 : .05), "listing order moves no ball more than 2 mm (frozen rack: 5 cm)");
        check(mirror < (gap > 0 ? .002 : .05), "centred break ends mirror-symmetric");
        check(ms < 1500, "a full break simulates fast enough for the device");
    }
    std::printf("%s\n", failures ? "BreakSymmetry: FAILED" : "BreakSymmetry: all checks passed");
    return failures ? 1 : 0;
}
