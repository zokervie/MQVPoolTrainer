// 0.50 Thế bí — puzzle generator (minutes to hours; not part of the CI gate).
// Usage: puzzle_gen <style> <wanted> <seed> [variant]
//   style: straight | pot | reach | position | hide
//   variant (position only): 0 = random layout (rooms 4/5), 1 = with a next ball (room 5), 2 = near-straight (room 2)
// Prints one JSON object per accepted puzzle. Tools/drills/puzzle_gen.sh collects them into puzzles.json.
// A layout is kept when its best route is made 30–90 % of the time by a player with typical error
// (DrillCheck.hpp drillRouteRate) — hard enough to be a puzzle, easy enough to be fair.
#include "../../BankLab/Core/DrillCheck.hpp"
#include <cstdio>
#include <cstring>
#include <string>
using namespace banklab;

namespace {
const V2 kHoles[6] = {{-.67, -1.305}, {.67, -1.305}, {-.706, 0}, {.706, 0}, {-.67, 1.305}, {.67, 1.305}};

struct Gen {
    DrillRng rng;
    explicit Gen(uint64_t seed) : rng(seed) {}
    double uni(double a, double b) { return a + (b - a) * rng.uniform(); }
    V2 spot() { return {uni(-.55, .55), uni(-1.16, 1.16)}; }
    bool clear(const std::vector<V2>& placed, V2 p, double gap = .10) {
        for (const auto& q : placed) if ((p - q).length() < gap) return false;
        for (const auto& h : kHoles) if ((p - h).length() < .14) return false;
        return std::abs(p.x) <= .57 && std::abs(p.y) <= 1.20;
    }
};

BLDrillSpec makeSpec(int kind, const std::vector<std::pair<int, V2>>& balls, double angle) {
    BLDrillSpec d{};
    d.key = "candidate"; d.chapter = 1; d.kind = kind; d.ballCount = int32_t(balls.size());
    for (size_t i = 0; i < balls.size(); ++i) d.balls[i] = {balls[i].first, balls[i].second.x, balls[i].second.y};
    d.angle = angle; d.flags = BL_DRILL_LEGAL_FIRST; d.skill = BL_SKILL_NONE;
    return d;
}
BLDrillLayout layoutOf(const BLDrillSpec& d) { BLDrillLayout L; BLDrillLayoutFor(&d, 0, &L); return L; }

const std::vector<DrillStroke>& railStrokes() {
    static const std::vector<DrillStroke> v{{1.4, 0}, {2.2, 0}, {3.2, 0}, {1.4, .3}, {2.2, .3}, {3.2, .3}};
    return v;
}
const std::vector<DrillStroke>& potStrokes() {
    static const std::vector<DrillStroke> v{{.9, -.3}, {1.4, -.3}, {2.2, -.3}, {.9, 0}, {1.4, 0}, {2.2, 0}, {3.2, 0},
                                            {.9, .3}, {1.4, .3}, {2.2, .3}};
    return v;
}
const std::vector<DrillStroke>& softStrokes() {
    static const std::vector<DrillStroke> v{{.45, -.3}, {.65, -.3}, {.9, -.3}, {.45, 0}, {.65, 0}, {.9, 0}, {1.2, 0},
                                            {.45, .3}, {.65, .3}, {.9, .3}};
    return v;
}

// Cut angle (degrees) of a direct pot: cue travel direction vs ball 1 → pocket.
double cutDegrees(const BLDrillSpec& d, const DrillFamily& f) {
    V2 obj{}; for (int k = 0; k < d.ballCount; ++k) if (d.balls[k].id == 1) obj = {d.balls[k].x, d.balls[k].y};
    const int pocket = f.signature % 10 - 1;
    if (pocket < 0) return 0;
    const V2 to = kHoles[pocket] - obj;
    const double a = std::atan2(to.y, to.x), diff = std::remainder(a - f.angle, 2 * pi);
    return std::abs(diff) * 180 / pi;
}

int skillOfRoute(int32_t sig) {
    const int cueRails = sig / 100, objRails = (sig / 10) % 10;
    if (objRails > 0) return BL_SKILL_BANK;
    if (cueRails == 1) return BL_SKILL_MIRROR;
    if (cueRails == 2) return BL_SKILL_PLUS;
    if (cueRails >= 3) return BL_SKILL_CORNER5;
    return BL_SKILL_GHOST;
}
int roomOfSkill(int skill) {
    switch (skill) {
    case BL_SKILL_STRAIGHT: case BL_SKILL_SPEED: return 1;
    case BL_SKILL_SPIN: return 2;
    case BL_SKILL_GHOST: return 3;
    case BL_SKILL_RULE30: case BL_SKILL_RULE90: return 4;
    case BL_SKILL_POSITION: return 5;
    case BL_SKILL_MIRROR: case BL_SKILL_PLUS: case BL_SKILL_CORNER5: return 6;
    case BL_SKILL_BANK: return 7;
    case BL_SKILL_HIDE: return 8;
    default: return 9;
    }
}

void emit(const char* style, int styleId, const BLDrillSpec& d, int skill, const std::vector<DrillFamily>& fams, double cut) {
    printf("{\"style\":\"%s\",\"styleId\":%d,\"room\":%d,\"skill\":%d,\"kind\":%d,\"rails\":%d,\"flags\":%d,"
           "\"potRequired\":%d,\"potOnly\":%d,\"goal\":[%.17g,%.17g,%.17g],\"angle\":%.17g,\"cut\":%.1f,\"balls\":[",
           style, styleId, roomOfSkill(skill), skill, d.kind, d.rails, d.flags, d.potRequired, d.potOnly, d.goalX, d.goalY,
           d.goalR, d.angle, cut);
    for (int k = 0; k < d.ballCount; ++k) printf("%s[%d,%.17g,%.17g]", k ? "," : "", d.balls[k].id, d.balls[k].x, d.balls[k].y);
    printf("],\"solutions\":[");
    for (size_t i = 0; i < fams.size(); ++i)
        printf("%s{\"sig\":%d,\"angle\":%.17g,\"speed\":%.17g,\"top\":%.17g,\"percent\":%d,\"hint\":[%.17g,%.17g]}", i ? "," : "",
               fams[i].signature, fams[i].angle, fams[i].speed, fams[i].top, fams[i].percent, fams[i].hint.x, fams[i].hint.y);
    printf("]}\n");
    fflush(stdout);
}
// Near-straight layout: object ball 0.30–0.80 m from a pocket, cue ball 0.30–0.90 m behind it, cut under 8°.
bool straightLayout(Gen& g, V2& cue, V2& obj) {
    const V2 hole = kHoles[int(g.rng.uniform() * 6) % 6];
    const V2 toCentre = V2{0, 0} - hole;
    const double base = std::atan2(toCentre.y, toCentre.x) + g.uni(-.5, .5);
    obj = hole + V2{std::cos(base), std::sin(base)} * g.uni(.30, .80);
    const double cutRad = g.uni(-8, 8) * pi / 180;
    cue = obj + V2{std::cos(base + cutRad), std::sin(base + cutRad)} * g.uni(.30, .90);
    return g.clear({}, obj) && g.clear({obj}, cue, .12);
}
bool fair(const std::vector<DrillFamily>& f) { return !f.empty() && f[0].percent >= 30 && f[0].percent <= 90; }
}  // namespace

int main(int argc, char** argv) {
    if (argc < 4) { fprintf(stderr, "usage: puzzle_gen <pot|reach|position|hide> <wanted> <seed> [variant]\n"); return 2; }
    const std::string style = argv[1];
    const int wanted = atoi(argv[2]);
    const int variant = argc > 4 ? atoi(argv[4]) : 0;
    Gen g(strtoull(argv[3], nullptr, 10));
    int found = 0; long shots = 0;
    for (int attempt = 0; attempt < 4000 && found < wanted; ++attempt) {
        std::vector<V2> placed;
        auto place = [&](double gap = .10) { for (int t = 0; t < 200; ++t) { V2 p = g.spot(); if (g.clear(placed, p, gap)) { placed.push_back(p); return p; } } return V2{9, 9}; };
        if (style == "pot") {
            const V2 cue = place(), obj = place(.25);
            std::vector<std::pair<int, V2>> balls{{0, cue}, {1, obj}};
            const int blockers = 1 + int(g.rng.uniform() * 2);
            for (int b = 0; b < blockers; ++b) balls.push_back({2 + b, place()});
            bool bad = false; for (auto& b : balls) bad |= b.second.x > 5;
            if (bad) continue;
            BLDrillSpec d = makeSpec(BL_DRILL_GOAL, balls, std::atan2(obj.y - cue.y, obj.x - cue.x));
            d.potOnly = 1;
            const BLDrillLayout L = layoutOf(d);
            auto fams = drillFamilies(d, L, L.angle, 180, railStrokes(), 100, shots);
            if (!fair(fams)) continue;
            const double cut = fams[0].signature / 10 == 0 ? cutDegrees(d, fams[0]) : 0;
            int skill = skillOfRoute(fams[0].signature);
            if (skill == BL_SKILL_GHOST && cut < 12) skill = BL_SKILL_STRAIGHT;
            emit("pot", 0, d, skill, fams, cut); ++found;
        } else if (style == "straight") {
            V2 cue, obj;
            if (!straightLayout(g, cue, obj)) continue;
            BLDrillSpec d = makeSpec(BL_DRILL_GOAL, {{0, cue}, {1, obj}}, std::atan2(obj.y - cue.y, obj.x - cue.x));
            d.potOnly = 1;
            const BLDrillLayout L = layoutOf(d);
            auto fams = drillFamilies(d, L, L.angle, 6, potStrokes(), 100, shots);
            if (!fair(fams) || fams[0].percent > 85) continue;   // room 1 still needs a little bite
            emit("pot", 0, d, BL_SKILL_STRAIGHT, fams, cutDegrees(d, fams[0])); ++found;
        } else if (style == "reach") {
            const V2 cue = place(), obj = place(.45);
            if (cue.x > 5 || obj.x > 5) continue;
            const V2 dir = (obj - cue) / (obj - cue).length(), nrm{-dir.y, dir.x};
            const double t = g.uni(.35, .65), off = g.uni(-.015, .015);
            const V2 blk = cue + (obj - cue) * t + nrm * off;
            if (!g.clear({cue, obj}, blk, .08)) continue;
            BLDrillSpec d = makeSpec(BL_DRILL_REACH, {{0, cue}, {1, obj}, {2, blk}}, std::atan2(dir.y, dir.x));
            d.rails = 1;
            const BLDrillLayout L = layoutOf(d);
            auto fams = drillFamilies(d, L, L.angle, 180, railStrokes(), 100, shots);
            if (!fair(fams)) continue;
            emit("reach", 1, d, skillOfRoute(fams[0].signature), fams, 0); ++found;
        } else if (style == "position") {
            V2 cue, obj;
            if (variant == 2) { if (!straightLayout(g, cue, obj)) continue; }
            else { cue = place(); obj = place(.30); if (cue.x > 5 || obj.x > 5) continue; }
            BLDrillSpec d = makeSpec(BL_DRILL_GOAL, {{0, cue}, {1, obj}}, std::atan2(obj.y - cue.y, obj.x - cue.x));
            d.potOnly = 1;
            BLDrillLayout L = layoutOf(d);
            auto pots = drillFamilies(d, L, L.angle, 6, potStrokes(), 60, shots, 40, 1);
            if (pots.empty() || pots[0].signature / 10 != 0) continue;
            const DrillFamily& f = pots[0];
            // Where does the cue ball stop with this stroke? Zone = centre of that cloud.
            DrillRng rng(g.rng.s); V2 sum{}; int n = 0;
            for (int i = 0; i < 60; ++i) {
                DrillShotInfo info; ++shots;
                if (drillShot(d, L, f.angle + rng.normal() * .3 * pi / 180, f.speed * (1 + rng.normal() * .06), 0,
                              std::clamp(f.top + rng.normal() * .06, -.6, .6), 14, &info)) { sum = sum + info.cueRest; ++n; }
            }
            if (n < 20) continue;
            const V2 zone = sum / double(n);
            if (std::abs(zone.x) > .56 || std::abs(zone.y) > 1.19 || (zone - cue).length() < .12) continue;
            d.potOnly = 0; d.potRequired = 1; d.goalX = zone.x; d.goalY = zone.y; d.goalR = .13;
            int skill;
            const double cut = cutDegrees(d, f);
            if (variant == 1) {
                // next ball: between the zone and a pocket, 45–60 % of the way, so the next shot is a gentle cut
                const V2 hole = kHoles[int(g.rng.uniform() * 6) % 6];
                const V2 next = zone + (hole - zone) * g.uni(.45, .60);
                if (!g.clear({cue, obj, zone}, next, .12) || (hole - zone).length() < .45) continue;
                d.ballCount = 3; d.balls[2] = {2, next.x, next.y};
                skill = BL_SKILL_POSITION;
            } else {
                skill = cut < 12 ? BL_SKILL_SPIN : (cut <= 50 ? (f.top >= .1 ? BL_SKILL_RULE30 : BL_SKILL_RULE90) : BL_SKILL_POSITION);
            }
            L = layoutOf(d);
            auto fams = drillFamilies(d, L, f.angle, 6, potStrokes(), 100, shots);
            if (!fair(fams)) continue;
            emit("position", 2, d, skill, fams, cut); ++found;
        } else if (style == "hide") {
            const V2 cue = place(), obj = place(.30);
            if (cue.x > 5 || obj.x > 5) continue;
            const double r = g.uni(.10, .30), a = g.uni(0, 2 * pi);
            const V2 blk = obj + V2{std::cos(a), std::sin(a)} * r;
            if (!g.clear({cue, obj}, blk, .07)) continue;
            BLDrillSpec d = makeSpec(BL_DRILL_SAFETY, {{0, cue}, {1, obj}, {2, blk}}, std::atan2(obj.y - cue.y, obj.x - cue.x));
            const BLDrillLayout L = layoutOf(d);
            auto fams = drillFamilies(d, L, L.angle, 10, softStrokes(), 100, shots);
            if (!fair(fams)) continue;
            emit("hide", 3, d, BL_SKILL_HIDE, fams, 0); ++found;
        } else { fprintf(stderr, "unknown style\n"); return 2; }
    }
    fprintf(stderr, "%s: %d found, %ld shots\n", style.c_str(), found, shots);
    return 0;
}
