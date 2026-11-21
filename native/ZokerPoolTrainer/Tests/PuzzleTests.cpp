// 0.50 Thế bí — gate for the puzzle layer: judge flags, route signatures, skills → lessons, hint jar, stars, room
// unlocks, and every generated puzzle (BankLab/UI/PuzzleCatalogData.h): each listed route still solves it on
// Config::app with the same signature and make rate, its mirror is solvable, rooms climb.
#include "../BankLab/Core/DrillCheck.hpp"
#include "../BankLab/UI/Puzzle.h"
#include <cmath>
#include <iostream>
#include <set>
#include <string>
using namespace banklab;

static int fails = 0, checks = 0;
static void check(bool ok, const std::string& what) { ++checks; if (!ok) { ++fails; std::cerr << "FAIL: " << what << "\n"; } }

static int judge(const BLDrillSpec& d, std::vector<std::array<int, 3>> ev, std::vector<std::tuple<int, double, double, int>> balls) {
    std::vector<int32_t> k, a, b, ids, sunk; std::vector<double> xs, ys;
    for (auto e : ev) { k.push_back(e[0]); a.push_back(e[1]); b.push_back(e[2]); }
    for (auto [id, x, y, s] : balls) { ids.push_back(id); xs.push_back(x); ys.push_back(y); sunk.push_back(s); }
    BLDrillLayout L; BLDrillLayoutFor(&d, 0, &L);
    return BLDrillJudge(&d, &L, int32_t(k.size()), k.data(), a.data(), b.data(), int32_t(ids.size()), ids.data(), xs.data(),
                        ys.data(), sunk.data());
}
static int32_t sig(std::vector<std::array<int, 3>> ev) {
    std::vector<int32_t> k, a, b; for (auto e : ev) { k.push_back(e[0]); a.push_back(e[1]); b.push_back(e[2]); }
    return BLDrillSignature(int32_t(k.size()), k.data(), a.data(), b.data());
}

static void rules() {
    BLDrillSpec pot{}; pot.key = "t"; pot.kind = BL_DRILL_GOAL; pot.potOnly = 1; pot.ballCount = 3;
    pot.balls[0] = {0, 0, -.5}; pot.balls[1] = {1, 0, .3}; pot.balls[2] = {2, .3, .3};
    const auto rest = std::vector<std::tuple<int, double, double, int>>{{0, 0, 0, 0}, {1, 0, 0, 1}, {2, .3, .3, 0}};
    check(judge(pot, {{1, 0, 2}, {1, 2, 1}, {2, 1, 4}}, rest), "0.49 rule unchanged: a combination counts without flags");
    pot.flags = BL_DRILL_LEGAL_FIRST;
    check(!judge(pot, {{1, 0, 2}, {1, 2, 1}, {2, 1, 4}}, rest), "LEGAL_FIRST: ball 2 first = missed");
    check(judge(pot, {{1, 0, 1}, {1, 0, 2}, {2, 1, 4}}, rest), "LEGAL_FIRST: ball 1 first, ball 2 later = made");
    pot.flags = BL_DRILL_CLEAN;
    check(!judge(pot, {{1, 0, 1}, {1, 2, 0}, {2, 1, 4}}, rest), "CLEAN: cue ball touching ball 2 later = missed");
    BLDrillSpec reach{}; reach.key = "r"; reach.kind = BL_DRILL_REACH; reach.rails = 1; reach.ballCount = 2;
    reach.balls[0] = {0, 0, -.5}; reach.balls[1] = {1, 0, .3};
    const auto r2 = std::vector<std::tuple<int, double, double, int>>{{0, 0, 0, 0}, {1, 0, .3, 0}};
    check(judge(reach, {{0, 0, 1}, {0, 0, 2}, {1, 0, 1}}, r2), "REACH: two rails then ball 1 (≥ 1) = made");
    check(!judge(reach, {{1, 0, 1}}, r2), "REACH: straight at ball 1 = missed");
    check(sig({{1, 0, 1}, {2, 1, 4}}) == 5, "signature: direct pot in pocket 4 = 5");
    check(sig({{0, 0, 1}, {0, 0, 3}, {1, 0, 1}, {0, 1, 2}, {2, 1, 0}}) == 211, "signature: 2-rail kick, 1-rail bank, pocket 0");
    check(sig({{0, 0, 1}, {1, 0, 1}}) == 100, "signature: 1-rail kick, no pot");
    check(BLPuzzleRoute(&reach, 116) == 100 && BLPuzzleRoute(&pot, 116) == 116, "reach counts only the cue-ball route");
    check(BLPuzzleSameRoute(5, 3) && !BLPuzzleSameRoute(5, 15) && !BLPuzzleSameRoute(100, 101), "same route up to pocket");
    for (int s = 0; s < BL_SKILL_COUNT; ++s) check(BLSkillLesson(s) >= 0, "skill " + std::to_string(s) + " has a lesson");
}

static void jarAndStars() {
    BLHintJar j; BLHintJarInit(&j, 1000);
    check(j.count == 3 && BLHintJarNextIn(&j, 1000) == 0, "jar starts full");
    check(BLHintJarSpend(&j, 3, 1000) && j.count == 1, "level 3 costs 2");
    check(BLHintJarSpend(&j, 1, 1000) && j.count == 0, "level 1 costs 1");
    check(!BLHintJarSpend(&j, 2, 1000) && j.count == 0, "empty jar refuses");
    check(std::abs(BLHintJarNextIn(&j, 1000) - 1200) < 1e-9, "next hint in 20 minutes");
    BLHintJarUpdate(&j, 1000 + 1200 * 1.5); check(j.count == 1, "one refill after 30 minutes");
    BLHintJarUpdate(&j, 1000 + 1200 * 9); check(j.count == 3, "refills stop at 3");
    BLHintJarEarn(&j, 20000); check(j.count == 3, "learning cannot overfill");
    BLHintJarSpend(&j, 1, 30000); BLHintJarSpend(&j, 1, 30000); BLHintJarEarn(&j, 30000);
    check(j.count == 2, "learning earns a hint");
    BLHintJarUpdate(&j, 100); check(j.count == 2 && BLHintJarNextIn(&j, 100) == 1200, "clock moved back: nothing gained, timer restarts");
    BLPuzzleSpec two{}, zone{}, one{};
    two.solutionCount = 2; zone.solutionCount = 1; zone.spec.goalR = 0.13; one.solutionCount = 1;
    check(BLPuzzleThirdStarTask(&two) == BL_PUZZLE_THIRD_SECOND_ROUTE && BLPuzzleThirdStarTask(&zone) == BL_PUZZLE_THIRD_SMALL_TARGET &&
          BLPuzzleThirdStarTask(&one) == BL_PUZZLE_THIRD_FIRST_TRY, "third-star task by puzzle shape");
    check(BLPuzzleSessionStars(&two, 0, 0, 0, 0, 0, 0) == 0, "no solve = 0 stars");
    check(BLPuzzleSessionStars(&two, 7, 0, 0, 0, 1, 0) == 1, "solved late = 1");
    check(BLPuzzleSessionStars(&two, 3, 0, 0, 0, 1, 0) == 2, "≤ 3 tries = 2");
    check(BLPuzzleSessionStars(&two, 3, 0, 0, 0, 2, 0) == 3, "second route = 3");
    check(BLPuzzleSessionStars(&two, 1, 2, 0, 0, 2, 0) == 2, "aim-point hint caps the session at 2");
    check(BLPuzzleSessionStars(&two, 1, 3, 0, 0, 2, 0) == 1, "watched route caps the session at 1");
    check(BLPuzzleSessionStars(&two, 1, 0, 1000, 1000 + 3600, 2, 0) == 1, "still capped an hour after watching");
    check(BLPuzzleSessionStars(&two, 1, 0, 1000, 1000 + 90000, 2, 0) == 3, "a new solve 24 h later earns full stars");
    check(BLPuzzleSessionStars(&zone, 2, 0, 0, 0, 1, 1) == 3 && BLPuzzleSessionStars(&zone, 2, 0, 0, 0, 1, 0) == 2, "zone puzzle: small target");
    check(BLPuzzleSessionStars(&one, 1, 0, 0, 0, 1, 0) == 3 && BLPuzzleSessionStars(&one, 2, 0, 0, 0, 1, 0) == 2, "single route: first try");
    check(BLPuzzleBestStars(2, 1) == 2 && BLPuzzleBestStars(1, 3) == 3, "best session is kept");
    check(BLPuzzleMirrorSignature(5) == 6 && BLPuzzleMirrorSignature(116) == 115 && BLPuzzleMirrorSignature(200) == 200 &&
          BLPuzzleMirrorSignature(BLPuzzleMirrorSignature(213)) == 213, "mirror swaps pocket pairs");
    check(!BLPuzzleOfferEasier(1) && BLPuzzleOfferEasier(2), "easier puzzle after 2 failures in a row");
}

static void catalogue() {
    std::set<std::string> keys;
    int listed = 0;
    for (int32_t i = 0; i < BLPuzzleCount(); ++i) {
        const BLPuzzleSpec& p = *BLPuzzleAt(i);
        if (p.spec.chapter <= 0) continue;   // inert placeholder when no puzzle is generated
        ++listed;
        const BLDrillSpec& d = p.spec;
        check(keys.insert(d.key).second, std::string("unique key ") + d.key);
        check(BLPuzzleSolutionAt(&p, 0) == &p.solutions[0] && !BLPuzzleSolutionAt(&p, p.solutionCount), std::string("accessor ") + d.key);
        check(p.solutionCount >= 1 && p.solutionCount <= BL_PUZZLE_MAX_SOLUTIONS, std::string("routes listed ") + d.key);
        check(d.skill >= 0 && d.skill < BL_SKILL_COUNT && BLSkillLesson(d.skill) >= 0, std::string("needs a taught skill ") + d.key);
        check(p.solutions[0].percent >= 30 && p.solutions[0].percent <= 90, std::string("fair: best route 30–90 % ") + d.key);
        BLDrillLayout L; BLDrillLayoutFor(&d, 0, &L);
        for (int k = 0; k < d.ballCount; ++k) {
            check(std::abs(L.x[k]) < .635 - BL_DRILL_RADIUS && std::abs(L.y[k]) < 1.27 - BL_DRILL_RADIUS, std::string("on the bed ") + d.key);
            for (int m = 0; m < k; ++m) check(std::hypot(L.x[k] - L.x[m], L.y[k] - L.y[m]) > 2 * BL_DRILL_RADIUS, std::string("no overlap ") + d.key);
        }
        for (int32_t s = 0; s < p.solutionCount; ++s) {
            const BLPuzzleSolution& so = p.solutions[s];
            DrillShotInfo info;
            const bool made = drillShot(d, L, so.angle, so.speed, 0, so.top, 14, &info);
            check(made && BLPuzzleRoute(&d, info.signature) == so.signature, std::string("route ") + std::to_string(so.signature) + " still solves " + d.key);
            DrillFamily f; f.signature = so.signature; f.angle = so.angle; f.speed = so.speed; f.top = so.top;
            const int rate = int(std::lround(drillRouteRate(d, L, f, 100, 1) * 100));
            check(std::abs(rate - so.percent) <= 8, std::string("route rate ") + d.key + " " + std::to_string(rate) + "% vs " +
                                                    std::to_string(so.percent) + "%");
            check(BLPuzzleSolutionIndex(&p, so.signature) == s, std::string("route index ") + d.key);
        }
        BLPuzzleSpec m; BLPuzzleMirror(&p, &m);
        BLDrillLayout ML; BLDrillLayoutFor(&m.spec, 0, &ML);
        bool ok = false;
        for (int t = 0; t <= 20 && !ok; ++t) {   // mirror: same route within ±1° (the table is symmetric, the rails nearly so)
            const double deg = (t % 2 ? 1 : -1) * ((t + 1) / 2) * 0.1;
            DrillShotInfo info;
            ok = drillShot(m.spec, ML, m.solutions[0].angle + deg * pi / 180, m.solutions[0].speed, 0, m.solutions[0].top, 14, &info) &&
                 BLPuzzleSolutionIndex(&m, info.signature) == 0;   // the mirrored table names the mirrored pocket
        }
        check(ok, std::string("mirrored review is solvable ") + d.key);
    }
    for (int room = 1; room <= BL_DRILL_CHAPTERS; ++room) {
        int32_t idx[64]; const int32_t n = BLPuzzleRoomCount(room, idx, 64);
        int hardest = 101;
        for (int32_t i = 0; i < n; ++i) {
            const int p = BLPuzzleAt(idx[i])->solutions[0].percent;
            check(p <= hardest + 15, "room " + std::to_string(room) + " climbs");
            hardest = std::min(hardest, p);
        }
    }
    int32_t none[BL_DRILL_CHAPTERS + 1] = {0}, all[BL_DRILL_CHAPTERS + 1] = {0};
    for (int r = 1; r <= BL_DRILL_CHAPTERS; ++r) all[r] = 3 * BLPuzzleRoomCount(r, 0, 0);
    check(BLRoomOpen(1, none), "room 1 always open");
    for (int r = 2; r <= BL_DRILL_CHAPTERS; ++r) check(BLRoomOpen(r, all), "full stars open room " + std::to_string(r));
    if (BLPuzzleRoomCount(1, 0, 0) > 0) check(!BLRoomOpen(2, none), "room 2 locked with no stars");
    int32_t upTo7[BL_DRILL_CHAPTERS + 1] = {0};
    for (int r = 1; r <= 6; ++r) upTo7[r] = all[r];
    check(BLRoomOpen(8, upTo7), "bank room never blocks the next");
    std::cout << "puzzles listed: " << listed << "\n";
}

int main() {
    rules();
    jarAndStars();
    catalogue();
    if (fails) { std::cerr << "FAIL Puzzle: " << fails << "/" << checks << "\n"; return 1; }
    std::cout << "PASS Puzzle: " << checks << " checks\n";
}
