// 0.21 — owner decisions 03/11/2026 on cues and tips:
//  - medium tip (Đánh) keeps the current physics exactly;
//  - soft tip (Massé) may strike further from centre; same contact point = same spin (real physics), so the
//    extra bite comes only from the larger offset before a miscue;
//  - massé must be strong enough for practice trick shots: reference clip D_lf-6KgFTo ("most insane massé"),
//    rectified to diamonds: near-vertical stroke sends the cue ball 3 diamonds (0.95 m) in 0.47 s ~ 2.0 m/s;
//  - jump cue jumps only when raised; break cue hits harder (hard tip + break gain, Config::cueSpeedGain);
//  - power levels 28-30 were all 6 m/s (old planar clamp) — they must now differ.
#include "../BankLab/Core/Physics.hpp"
#include "../BankLab/UI/PowerScale.h"
#include "../BankLab/UI/ShotKindPolicy.h"
#include <array>
#include <cmath>
#include <cstdio>
using namespace banklab;

static int failures = 0;
static void check(bool ok, const char* what) { std::printf("%s: %s\n", ok ? "PASS" : "FAIL", what); if (!ok) ++failures; }

static World one(Config c) { c.width = 40; c.length = 40; World w(c); Ball b; b.id = 0; w.balls = {b}; return w; }
static Config forKind(int kind, double elevation) {
    Config c; c.coupledCushions = true; c.cueType = kind == 3 ? 0 : kind; c.tipProfile = BLTipForShotKind(kind);
    c.breakSpeedGain = BL_BREAK_SPEED_GAIN; c.squirtEnabled = true; c.squirtRampDegrees = BL_SQUIRT_RAMP_DEGREES;
    c.masseCoupledContact = BLMasseCoupledForShotKind(kind); c.cueElevationDegrees = elevation; c.experimental3D = elevation > 0 || kind == 1;
    return c;
}

int main() {
    // ---- medium tip = old physics ----
    for (double v : {1.0, 3.0, 5.5}) {
        Config c; World a = one(c); a.strike(.3, v, .35, -.2);
        const double k = 1 + c.mass / c.cueMass(), expect = v * k / (k + 2.5 * (.35 * .35 + .2 * .2));
        check(std::abs(a.balls[0].v.length() - expect) < 1e-12, "medium tip, default gain: launch speed unchanged (TP A.30)");
    }
    // ---- power: no more dead top levels ----
    double prev = 0;
    for (int level = 26; level <= BL_POWER_LEVELS; ++level) {
        World w = one(Config{}); w.strike(0, BLPowerSpeed(level), 0, 0);
        check(w.balls[0].v.length() > prev + .1, "power levels 26-30 give increasing speed (old 6 m/s clamp removed)");
        prev = w.balls[0].v.length();
    }
    std::printf("REPORT: Đánh level 30 = %.2f m/s\n", prev);
    {   World w = one(forKind(2, 0)); w.strike(0, BLPowerSpeed(BL_POWER_LEVELS), 0, 0);
        const double s = w.balls[0].v.length();
        std::printf("REPORT: Phá level 30 = %.2f m/s (pro breaks ~11-13 m/s)\n", s);
        check(s > 11 && s <= Config::maxBallSpeed, "break cue level 30 reaches pro break speed (11-12.5 m/s)");
        World d = one(forKind(0, 0)); d.strike(0, BLPowerSpeed(15), 0, 0); World p = one(forKind(2, 0)); p.strike(0, BLPowerSpeed(15), 0, 0);
        check(p.balls[0].v.length() > 1.4 * d.balls[0].v.length(), "same power level: break cue hits harder than the playing cue");
    }
    // ---- soft tip: same offset = same spin, larger max offset ----
    {   Config med = forKind(0, 0), soft = med; soft.tipProfile = 1;
        World a = one(med), b = one(soft); a.strike(0, 2, .5, 0); b.strike(0, 2, .5, 0);
        check(std::abs(a.balls[0].spin * soft.tipSpeedFactor() - b.balls[0].spin) < 1e-9, "soft tip: same contact point, spin differs only by tip efficiency");
        // Effect "bite" = spin-to-speed ratio wR/v = 2.5 d (what sets draw distance, rail effect and massé curve).
        // Absolute spin per cue speed peaks near d = 0.72 R (TP A.30 speed loss), so the gain is in the ratio.
        World am = one(med), bm = one(soft); am.strike(0, 2, .9, 0); bm.strike(0, 2, .9, 0);
        const double rm = std::abs(am.balls[0].spin) * med.radius / am.balls[0].v.length(), rs = std::abs(bm.balls[0].spin) * soft.radius / bm.balls[0].v.length();
        std::printf("REPORT: max effect ratio wR/v: medium %.2f, soft %.2f (max offset %.2f / %.2f R)\n", rm, rs, med.tipMaxOffset(false), soft.tipMaxOffset(false));
        check(rs > 1.1 * rm, "soft tip: more effect per stroke (holds further from centre)");
    }
    // ---- massé strength, reference clip ~2 m/s ----
    for (double e : {70.0, 80.0}) {
        World w = one(forKind(3, e)); w.strike(1.0, BLPowerSpeed(BL_POWER_LEVELS), .5, -.3);
        const Ball b = w.balls[0];
        const double spin = std::sqrt(b.w.x * b.w.x + b.w.y * b.w.y + b.spin * b.spin);
        std::printf("REPORT: massé %2.0f deg, level 30: horizontal %.2f m/s, |omega| %.0f rad/s\n", e, b.v.length(), spin);
        check(b.v.length() > 1.2 && b.v.length() < 4, "massé at full power: 1.2-4 m/s (clip ~2 m/s), usable for trick shots");
        // the path must curve: compare launch direction with the direction after 0.6 s
        const double a0 = std::atan2(b.v.y, b.v.x);
        for (int i = 0; i < 960; ++i) w.step();
        const double a1 = std::atan2(w.balls[0].v.y, w.balls[0].v.x), bend = std::abs(std::remainder(a1 - a0, 2 * pi)) * 180 / pi;
        std::printf("REPORT: massé %2.0f deg: path turns %.0f deg in the first 1.0 s\n", e, bend);
        check(bend > 30, "massé path curves (> 30 deg in 1 s). Curve SHAPE vs clip D_lf-6KgFTo: open calibration item");
    }
    // ---- jump only when raised ----
    {   World flat = one(forKind(1, 0)); flat.strike(0, 5, 0, 0);
        double maxH = 0; for (int i = 0; i < 960; ++i) { flat.step(); maxH = std::max(maxH, flat.balls[0].height); }
        check(maxH < 1e-6, "jump cue with a level cue does not jump");
        World up = one(forKind(1, 45)); up.strike(0, 5, 0, 0);
        maxH = 0; for (int i = 0; i < 960; ++i) { up.step(); maxH = std::max(maxH, up.balls[0].height); }
        std::printf("REPORT: jump cue 45 deg, 5 m/s: peak height %.1f mm\n", maxH * 1000);
        check(maxH > .005, "jump cue raised 45 deg leaves the cloth");
    }
    // ---- 0.22: three cues in the bag; Massé follows the playing cue's elevation ----
    check(BLShotKindForElevation(0, 59.9) == 0 && BLShotKindForElevation(0, 60) == 3 && BLShotKindForElevation(3, 45) == 0 &&
          BLShotKindForElevation(1, 80) == 1 && BLShotKindForElevation(2, 70) == 2, "Đánh raised to 60 deg becomes Massé (soft tip); Jump/Break unchanged");
    // ---- 0.29: a ball spinning in place is at rest (no multi-second wait); draw/follow untouched ----
    {   auto spinner = [](bool settle) { Config c; c.coupledCushions = true; c.settleSpinInPlace = settle; c.width = 40; c.length = 40;
            World w(c); Ball b; b.id = 0; b.spin = 40; w.balls = {b}; double t = 0; while (w.moving() && t < 10) { w.step(); t += World::stepSize; } return t; };
        const double fast = spinner(true), slow = spinner(false);
        std::printf("REPORT: ball spinning in place at 40 rad/s: at rest after %.2f s (was %.2f s)\n", fast, slow);
        check(fast < .01 && slow > 2, "spin in place no longer delays the next shot");
        auto drawShot = [](bool settle) { Config c; c.coupledCushions = true; c.settleSpinInPlace = settle; c.width = 40; c.length = 40;
            World w(c); Ball b; b.id = 0; Ball o; o.id = 1; o.p = {.25, 0}; w.balls = {b, o}; w.strike(0, 3.5, 0, -.6); double minX = 0, maxX = 0;
            for (int i = 0; i < 960 * 15 && w.moving(); ++i) { w.step(); minX = std::min(minX, w.balls[0].p.x); maxX = std::max(maxX, w.balls[0].p.x); }
            return std::array<double,3>{w.balls[0].p.x, maxX, minX}; };
        const auto a = drawShot(true), b = drawShot(false);
        std::printf("REPORT: draw shot into a ball: cue ends at x=%.3f m (furthest %.3f) with settle, %.3f without\n", a[0], a[1], b[0]);
        check(std::abs(a[0] - b[0]) < .002 && a[0] < a[1] - .05, "draw shot path unchanged (still draws back), within 2 mm");
    }
    std::printf("%s\n", failures ? "CueTip: FAILED" : "CueTip: all checks passed");
    return failures ? 1 : 0;
}
