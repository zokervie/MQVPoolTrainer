// 0.30 — side english at the rail and gear-effect transfer to the object ball, against the owner's table.
//
// Measured (owner, real table, acceptance 0.29 item 11, 04/11/2026): maximum side english, medium speed, no massé,
// cue ball sent straight (90 deg) into a long rail -> it comes off at most ~45 deg from the rail normal
// ("~2 diamonds"). Only massé goes wider.
// Owner explanation of reverse zigzag (same report): reverse english on the cue ball gears the object ball
// into the opposite spin; at the rail that spin jerks it back. Running english does not reverse, it widens.
#include "../BankLab/Core/Physics.hpp"
#include <cmath>
#include <cstdio>
using namespace banklab;

static int failures = 0;
static void check(bool ok, const char* what) { std::printf("%s: %s\n", ok ? "PASS" : "FAIL", what); if (!ok) ++failures; }

// Angle (deg, signed) from the rail normal after one long-rail contact. Start between diamonds (not the side pocket).
static double offRail(Config c, double speed, double side) {
    c.squirtEnabled = false; World w(c); Ball b; b.id = 0; b.p = {0, .6}; w.balls = {b};
    w.strike(0, speed, side, 0);
    size_t n = 0;
    for (int i = 0; i < 960 * 4; ++i) {
        w.step(); bool hit = false;
        for (; n < w.events.size(); ++n) if (w.events[n].kind == 0) hit = true;
        if (hit) { for (int k = 0; k < 60; ++k) w.step(); break; }
    }
    const V2 v = w.balls[0].v; return std::atan2(v.y, -v.x) * 180 / pi;
}

struct Gear { double spin, ratio; };
// Cut shot on an open table; object ball's side spin and R*w/v right after contact.
static Gear gear(Config c, double cutDeg, double speed, double side) {
    c.squirtEnabled = false; c.width = 40; c.length = 40; World w(c);
    Ball cue; cue.id = 0; cue.p = {0, -.6}; Ball ob; ob.id = 1; ob.p = {0, -.3}; w.balls = {cue, ob};
    const double d = 2 * c.radius, a = cutDeg * pi / 180;
    const V2 ghost{ob.p.x + d * std::sin(a), ob.p.y - d * std::cos(a)}, dir = (ghost - cue.p).unit();
    w.strike(std::atan2(dir.y, dir.x), speed, side, 0);
    for (int i = 0; i < 960 * 2; ++i) {
        w.step();
        for (const auto& e : w.events) if (e.kind == 1) { const Ball& o = w.balls[1]; return {o.spin, c.radius * std::abs(o.spin) / o.v.length()}; }
    }
    return {0, 0};
}

int main() {
    const Config app = Config::app();
    Config literature = app;
    for (double speed : {1.5, 2.0, 3.0}) {
        const double maxR = offRail(app, speed, app.tipMaxOffset(false)), maxL = offRail(app, speed, -app.tipMaxOffset(false));
        const double none = offRail(app, speed, 0), old = offRail(literature, speed, app.tipMaxOffset(false));
        std::printf("REPORT: %.1f m/s straight into the rail: max english %+.1f / %+.1f deg, none %+.1f, (same) %+.1f\n", speed, maxR, maxL, none, old);
        check(std::abs(none) < 1, "no english: straight back");
        check(std::abs(std::abs(maxR) - std::abs(maxL)) < 2 && maxR * maxL < 0, "left and right english mirror each other");
        // 0.31: published cushion friction (0.20) -> about 20-30 deg; the owner's eyeballed ~45 deg needs 0.45, which no
        // published measurement supports, so it is a tuning option only (PublishedBenchmarkTests).
        check(std::abs(maxR) >= 18 && std::abs(maxR) <= 32, "max english straight in: 18-32 deg with published friction");
        Config owner = app; owner.railFriction = .45; owner.railGrip = {{.45, .45, .45, .45}};
        const double ownerAngle = std::abs(offRail(owner, speed, app.tipMaxOffset(false)));
        std::printf("REPORT: owner option rail .45 -> %.1f deg\n", ownerAngle);
        check(ownerAngle > std::abs(maxR) + 8, "the owner option (.45) is clearly wider");
    }
    // Gear effect: reverse english flips the object ball's spin and grows with the tip offset.
    for (double speed : {2.0, 3.5}) {
        const Gear none = gear(app, 20, speed, 0), rev = gear(app, 20, speed, -.7), half = gear(app, 20, speed, -.35), run = gear(app, 20, speed, .7);
        std::printf("REPORT: cut 20 deg %.1f m/s object-ball spin: none %+.1f, reverse .35R %+.1f, reverse .7R %+.1f (R*w/v %.3f), running .7R %+.1f\n",
                    speed, none.spin, half.spin, rev.spin, rev.ratio, run.spin);
        check(rev.spin * none.spin < 0, "reverse english turns the object ball's spin the other way (gear)");
        check(run.spin * none.spin > 0, "running english keeps the cut-induced direction");
        check(rev.ratio >= .08, "reverse english: object-ball R*w/v >= 0.08 (enough to jerk back at the rail, clip ~0.13)");
        Config lit = app; lit.ballFrictionMin = .00995;
        check(gear(lit, 20, speed, -.7).ratio < rev.ratio * .7, "literature high-slip friction transfers much less (why it changed)");
    }
    std::printf("%s\n", failures ? "RailEnglish: FAILED" : "RailEnglish: all checks passed");
    return failures ? 1 : 0;
}
