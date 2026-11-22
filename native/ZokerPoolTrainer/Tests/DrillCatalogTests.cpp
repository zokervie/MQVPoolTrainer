// 0.49b Xưởng bài — gate for the drill catalogue (BankLab/UI/DrillCatalog.h + generated DrillCatalogData.h).
// Every drill must be playable on the app's physics, its measured difficulty must still hold, jittered layouts must
// stay playable, ladders must climb, and the judge must agree with the rules the app has used since 0.47.
#include "../BankLab/Core/DrillCheck.hpp"
#include "../BankLab/UI/FirstShot.h"
#include <cmath>
#include <cstring>
#include <iostream>
#include <set>
#include <string>
using namespace banklab;

static int fails = 0, checks = 0;
static void check(bool ok, const std::string& what) { ++checks; if (!ok) { ++fails; std::cerr << "FAIL: " << what << "\n"; } }
static const BLDrillSpec& drill(const char* key) {
    const int32_t i = BLDrillIndex(key);
    if (i < 0) { std::cerr << "missing drill " << key << "\n"; std::exit(1); }
    return *BLDrillAt(i);
}
static bool near(double a, double b, double eps = 1e-9) { return std::abs(a - b) <= eps; }
static V2 ballOf(const BLDrillSpec& d, int id) { for (int k = 0; k < d.ballCount; ++k) if (d.balls[k].id == id) return {d.balls[k].x, d.balls[k].y}; return {NAN, NAN}; }

// ── 1. Existing keys keep the layouts of Models.swift ≤ 0.48 ────────────────────────────────────────────────────
static void legacyLayouts() {
    const BLDrillSpec& f = drill("first-shot");
    check(near(ballOf(f, 0).x, BLFirstShotCueX(), 1e-12) && near(ballOf(f, 0).y, BLFirstShotCueY(), 1e-12) &&
          near(ballOf(f, 1).x, BLFirstShotObjectX(), 1e-12) && near(ballOf(f, 1).y, BLFirstShotObjectY(), 1e-12) &&
          near(f.angle, BLFirstShotAngle(), 1e-12) && near(f.tipTop, BLFirstShotTop()), "first-shot = FirstShot.h");
    auto oldCut = [](double deg, double m, V2& cue, V2& obj, double& angle) {   // Models.swift cut(_:mirror:)
        const double L = std::hypot(0.42, 0.755), dx = 0.42 / L, dy = 0.755 / L, r = deg * pi / 180;
        const double ix = dx * std::cos(r) - dy * std::sin(r), iy = dx * std::sin(r) + dy * std::cos(r);
        const double gx = 0.25 - dx * 0.05715, gy = 0.55 - dy * 0.05715;
        cue = {(gx - ix * 0.65) * m, gy - iy * 0.65}; obj = {0.25 * m, 0.55}; angle = std::atan2(iy, ix * m);
    };
    for (auto [key, deg, m] : {std::tuple{"cut-30-r", 30.0, 1.0}, std::tuple{"cut-45-l", 45.0, -1.0}}) {
        V2 c, o; double a; oldCut(deg, m, c, o, a); const BLDrillSpec& d = drill(key);
        check(near(ballOf(d, 0).x, c.x, 1e-12) && near(ballOf(d, 0).y, c.y, 1e-12) && near(ballOf(d, 1).x, o.x) &&
              near(ballOf(d, 1).y, o.y) && near(d.angle, a, 1e-12), std::string(key) + " = Models.swift cut()");
    }
    struct K { const char* key; int rails, variant; };
    for (K k : {K{"kick1-mirror-b", 1, 0}, K{"kick1-blocker", 1, 1}, K{"kick1-blocker-far", 1, 2}, K{"kick2-blocker", 2, 1},
                K{"kick3-blocker-mid", 3, 1}, K{"kick3-blocker-high", 3, 2}}) {   // Models.swift kickLayout()
        const double s = k.variant * 0.055, x = -0.28 + s, y = -0.78 + (k.rails - 1) * 0.035, tx = 0.24 - s * 0.5,
                     ty = 0.46 - (k.rails - 1) * 0.04;
        const BLDrillSpec& d = drill(k.key);
        bool ok = near(ballOf(d, 0).x, x, 1e-12) && near(ballOf(d, 0).y, y, 1e-12) && near(ballOf(d, 1).x, tx, 1e-12) &&
                  near(ballOf(d, 1).y, ty, 1e-12) && near(d.angle, std::atan2(ty - y, tx - x), 1e-12) && d.rails == k.rails;
        if (k.variant) ok = ok && near(ballOf(d, 2).x, 0.02) && near(ballOf(d, 2).y, 0.03 + (k.variant - 1) * 0.14, 1e-12);
        check(ok, std::string(k.key) + " = Models.swift kickLayout()");
    }
    const BLDrillSpec& stop = drill("stop-hold");
    check(near(stop.goalX, 0.3044) && near(stop.goalY, 0.5789) && near(stop.goalR, 0.10) && stop.potRequired, "stop-hold goal unchanged");
}

// ── 2. Judge = the rules of TC+ShotLoop.swift finishShot (≤ 0.48) ───────────────────────────────────────────────
struct Ev { int k, a, b; };
static bool judge(const BLDrillSpec& d, std::vector<Ev> ev, std::vector<std::tuple<int, double, double, int>> balls) {
    std::vector<int32_t> k, a, b, ids, sunk; std::vector<double> xs, ys;
    for (auto e : ev) { k.push_back(e.k); a.push_back(e.a); b.push_back(e.b); }
    for (auto [id, x, y, s] : balls) { ids.push_back(id); xs.push_back(x); ys.push_back(y); sunk.push_back(s); }
    BLDrillLayout L; BLDrillLayoutFor(&d, 0, &L);
    return BLDrillJudge(&d, &L, int32_t(k.size()), k.data(), a.data(), b.data(), int32_t(ids.size()), ids.data(), xs.data(),
                        ys.data(), sunk.data()) != 0;
}
static void judgeRules() {
    const BLDrillSpec& k2 = drill("kick2-double-mirror");
    const auto rest = std::vector<std::tuple<int, double, double, int>>{{0, 0, 0, 0}, {1, 0.2, 0.4, 0}};
    check(judge(k2, {{0, 0, 1}, {0, 0, 2}, {1, 0, 1}}, rest), "kick: 2 rails then ball 1 = made");
    check(!judge(k2, {{0, 0, 1}, {1, 0, 1}}, rest), "kick: 1 rail then ball 1 = missed");
    check(!judge(k2, {{0, 0, 1}, {0, 0, 2}, {1, 1, 0}, {2, 0, 5}}, rest), "kick: right path but scratch = missed");
    check(judge(k2, {{0, 0, 1}, {0, 0, 2}, {1, 1, 0}}, rest), "kick: contact listed as (1, 0) also counts");
    const BLDrillSpec& b1 = drill("bank1");
    check(judge(b1, {{1, 0, 1}, {0, 1, 2}, {2, 1, 4}}, rest), "bank: 1 object rail then pocket = made");
    check(!judge(b1, {{1, 0, 1}, {2, 1, 4}}, rest), "bank: straight in = missed");
    check(!judge(b1, {{1, 0, 1}, {0, 1, 2}, {2, 1, -1}}, rest), "bank: ball recovered off the table never counts");
    const BLDrillSpec& stop = drill("stop-hold");
    check(judge(stop, {{1, 0, 1}, {2, 1, 5}}, {{0, 0.31, 0.58, 0}, {1, 0.6, 1.2, 1}}), "goal: pot + cue ball in zone = made");
    check(!judge(stop, {{1, 0, 1}}, {{0, 0.31, 0.58, 0}, {1, 0.6, 1.2, 0}}), "goal: zone without pot = missed");
    check(!judge(stop, {{1, 0, 1}, {2, 1, 5}}, {{0, 0.6, 0.58, 0}, {1, 0.6, 1.2, 1}}), "goal: pot, cue ball outside = missed");
    const BLDrillSpec& s = drill("safe-behind");
    check(judge(s, {{1, 0, 1}}, {{0, 0.0, -0.1, 0}, {1, 0.0, 0.8, 0}, {2, 0.01, 0.40, 0}}), "safety: ball 2 on the line = hidden");
    check(!judge(s, {{1, 0, 1}}, {{0, 0.0, -0.1, 0}, {1, 0.0, 0.8, 0}, {2, 0.2, 0.40, 0}}), "safety: clear line = not hidden");
    check(!judge(s, {{1, 0, 2}}, {{0, 0.0, -0.1, 0}, {1, 0.0, 0.8, 0}, {2, 0.01, 0.40, 0}}), "safety: ball 2 hit first = foul");
    check(!judge(s, {{1, 0, 1}, {2, 1, 4}}, {{0, 0.0, -0.1, 0}, {1, 0.0, 0.8, 1}, {2, 0.01, 0.40, 0}}), "safety: a pocketed ball = missed");
}

// ── 3. Catalogue shape ──────────────────────────────────────────────────────────────────────────────────────────
static void shape() {
    std::set<std::string> keys; int last = 0;
    for (int32_t i = 0; i < BLDrillCount(); ++i) {
        const BLDrillSpec& d = *BLDrillAt(i);
        check(keys.insert(d.key).second, std::string("unique key ") + d.key);
        check(d.chapter >= last && d.chapter >= 1 && d.chapter <= BL_DRILL_CHAPTERS, std::string("chapter order ") + d.key);
        last = d.chapter;
        check(BLDrillIndex(d.key) == i, std::string("index of ") + d.key);
        BLDrillLayout L; BLDrillLayoutFor(&d, 0, &L);
        bool cue = false, obj = false;
        for (int k = 0; k < d.ballCount; ++k) { cue |= d.balls[k].id == 0; obj |= d.balls[k].id == 1; }
        check(cue && (obj || d.kind == BL_DRILL_GOAL), std::string("cue ball (and ball 1) present ") + d.key);
        check(d.makePercent > 0 && d.makePercent <= 100, std::string("measured (drill_sweep run) ") + d.key);
    }
    for (int c = 1; c <= BL_DRILL_CHAPTERS; ++c) {
        int32_t idx[64]; const int32_t n = BLDrillChapterDrills(c, idx, 64);
        check(n >= 2, "chapter " + std::to_string(c) + " (" + BLDrillChapterKey(c) + ") has at least 2 drills");
    }
    check(std::string(BLDrillChapterKey(1)) == "straight-speed" && std::string(BLDrillChapterKey(0)).empty(), "chapter keys");
    BLDrillSpec probe{}; probe.makePercent = 100; check(BLDrillPassPercent(&probe) == 70 && BLDrillPassMade(&probe, 10) == 7, "pass mark easy drill 7/10");
    probe.makePercent = 68; check(BLDrillPassMade(&probe, 10) == 6, "pass mark 68 % drill: 53 % → 6/10");
    probe.makePercent = 6; check(BLDrillPassPercent(&probe) == 20 && BLDrillPassMade(&probe, 10) == 2, "pass mark floor 2/10");
    double dl = 0, ds = 0;
    BLDrillDiamonds(0, 0, &dl, &ds); check(near(dl, 4) && near(ds, 2), "diamonds: centre spot = long 4, short 2");
    BLDrillDiamonds(-0.635, -1.27, &dl, &ds); check(near(dl, 0) && near(ds, 0), "diamonds: foot-left corner = 0, 0");
    BLDrillDiamonds(0.635, 1.27, &dl, &ds); check(near(dl, 8) && near(ds, 4), "diamonds: head-right corner = 8, 4");
    check(BLDrillStarsFromMakeRate(95) == 1 && BLDrillStarsFromMakeRate(70) == 2 && BLDrillStarsFromMakeRate(50) == 3 &&
          BLDrillStarsFromMakeRate(30) == 4 && BLDrillStarsFromMakeRate(5) == 5, "star bands");
}

// ── 4. Playable: reference stroke makes it; make rate still as measured; ladders climb ──────────────────────────
static void playable() {
    for (int32_t i = 0; i < BLDrillCount(); ++i) {
        const BLDrillSpec& d = *BLDrillAt(i);
        if (d.scanDegrees <= 0) continue;
        BLDrillLayout L; BLDrillLayoutFor(&d, 0, &L);
        check(drillShot(d, L, d.solveAngle, d.solveSpeed, 0, d.solveTop), std::string("reference stroke makes ") + d.key);
        const int p = int(std::lround(drillMakeRate(d, L, d.solveAngle, d.solveSpeed, d.solveTop, 200) * 100));
        // Same seed, same samples as drill_sweep; the slack only absorbs libm differences between compilers.
        check(std::abs(p - d.makePercent) <= 6, std::string("make rate ") + d.key + " " + std::to_string(p) + "% vs catalogue " +
                                                    std::to_string(d.makePercent) + "%");
    }
    // A ladder may not get much easier after a harder rung (15 points slack: rungs teach different skills).
    for (int c = 1; c <= BL_DRILL_CHAPTERS; ++c) {
        int32_t idx[64]; const int32_t n = BLDrillChapterDrills(c, idx, 64);
        int hardest = 101;
        for (int32_t r = 0; r < n; ++r) {
            const BLDrillSpec& d = *BLDrillAt(idx[r]);
            if (d.tier > 0) continue;   // 0.54 ring ladders restart at the big ring: their order is checked in MasteryTests
            check(d.makePercent <= hardest + 15, std::string("ladder climbs at ") + d.key + " (" + std::to_string(d.makePercent) +
                                                      "% after a " + std::to_string(hardest) + "% rung)");
            hardest = std::min(hardest, int(d.makePercent));
        }
    }
}

// ── 5. Jitter: deterministic, valid, still playable ─────────────────────────────────────────────────────────────
static void jitter() {
    for (int32_t i = 0; i < BLDrillCount(); ++i) {
        const BLDrillSpec& d = *BLDrillAt(i);
        BLDrillLayout base, again; BLDrillLayoutFor(&d, 0, &base);
        for (int v = 1; v <= 3; ++v) {
            BLDrillLayout L; BLDrillLayoutFor(&d, v, &L); BLDrillLayoutFor(&d, v, &again);
            check(!std::memcmp(&L, &again, sizeof L), std::string("jitter deterministic ") + d.key);
            int cue = 0; for (int k = 0; k < d.ballCount; ++k) if (d.balls[k].id == 0) cue = k;
            const double moved = std::hypot(L.x[cue] - base.x[cue], L.y[cue] - base.y[cue]);
            check(moved <= d.jitter + 1e-12 && (d.jitter <= 0 || moved > 0), std::string("jitter within range ") + d.key);
            check(BLDrillLayoutValid(&d, &L, cue), std::string("jittered layout valid ") + d.key);
            if (d.jitter <= 0 || d.scanDegrees <= 0) continue;
            // Re-aimed reference stroke (aim turned like the default aim), then a ±3° search at three paces.
            const double aim = d.solveAngle + (L.angle - base.angle);
            bool ok = false;
            for (double pace : {1.0, 0.85, 1.15}) {
                for (int s = 0; s <= 60 && !ok; ++s) {
                    const double deg = (s % 2 ? 1 : -1) * ((s + 1) / 2) * 0.1;
                    ok = drillShot(d, L, aim + deg * pi / 180, d.solveSpeed * pace, 0, d.solveTop);
                }
                if (ok) break;
            }
            check(ok, std::string("jittered layout playable ") + d.key + " #" + std::to_string(v));
        }
    }
}

int main() {
    legacyLayouts();
    judgeRules();
    shape();
    playable();
    jitter();
    if (fails) { std::cerr << "FAIL DrillCatalog: " << fails << "/" << checks << "\n"; return 1; }
    std::cout << "PASS DrillCatalog: " << checks << " checks, " << BLDrillCount() << " drills, " << BL_DRILL_CHAPTERS << " chapters\n";
}
