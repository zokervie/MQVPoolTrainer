// 03/11/2026 — three owner requests, each tied to a source or to an explicit owner decision.
// A. Aim-true Đánh/Phá: no squirt, the ball leaves on the aim line (owner decision); Jump/Massé keep TP A.31.
// B. Massé: cue, ball and slate solved together (CueSlateContact.hpp, ported from build 28).
//    Published check: "more elevation results in less cue ball speed" (drdavepoolinfo FAQ massé/cue elevation).
// C. English at a cushion: running english lengthens the rebound angle and keeps speed, reverse shortens it and
//    slows the ball (Billiards Digest, July 2019). Side spin keeps its sense through a rail, so the same spin is
//    running on one rail and reverse on the opposite one: rebound angles alternate (the zigzag pattern).
#include "../BankLab/Core/Physics.hpp"
#include "../BankLab/UI/ShotKindPolicy.h"
#include <cmath>
#include <cstdio>
using namespace banklab;

static int failures = 0;
static void check(bool ok, const char* what) { std::printf("%s: %s\n", ok ? "PASS" : "FAIL", what); if (!ok) ++failures; }
static double deg(double r) { return r * 180 / pi; }

static World planar(bool squirt) { Config c; c.width = 40; c.length = 40; c.squirtEnabled = squirt; World w(c); Ball b; b.id = 0; w.balls = {b}; return w; }
static World raised(double elev, bool coupled, bool squirt = true) {
    Config c; c.width = 40; c.length = 40; c.coupledCushions = true; c.experimental3D = true; c.cueType = 0;
    c.cueElevationDegrees = elev; c.masseCoupledContact = coupled; c.squirtEnabled = squirt;
    World w(c); Ball b; b.id = 0; w.balls = {b}; return w;
}
static double energy(const Ball& b) {
    const double r = Config{}.radius, m = Config{}.mass;
    return .5 * m * (b.v.x * b.v.x + b.v.y * b.v.y + b.vertical * b.vertical) + .2 * m * r * r * (b.w.x * b.w.x + b.w.y * b.w.y + b.spin * b.spin);
}

int main() {
    // ---------- A. aim-true ----------
    // 0.21 policy: squirt on for every cue, faded in by elevation (BL_SQUIRT_RAMP_DEGREES). Level cue = aim line.
    for (int kind = 0; kind < 4; ++kind) {
        Config c; c.width = 40; c.length = 40; c.squirtEnabled = true; c.squirtRampDegrees = BL_SQUIRT_RAMP_DEGREES;
        c.tipProfile = BLTipForShotKind(kind); c.cueElevationDegrees = 0;
        World w(c); Ball b; b.id = 0; w.balls = {b}; w.strike(.4, 2, .5, 0);
        check(std::abs(std::remainder(std::atan2(w.balls[0].v.y, w.balls[0].v.x) - .4, 2 * pi)) < 1e-12, "policy 0.21: level cue leaves on the aim line for every shot kind");
        c.cueElevationDegrees = 7.5; World h(c); h.balls = {b}; h.strike(.4, 2, .5, 0);
        c.cueElevationDegrees = 15; World f(c); f.balls = {b}; f.strike(.4, 2, .5, 0);
        const double dh = std::remainder(std::atan2(h.balls[0].v.y, h.balls[0].v.x) - .4, 2 * pi), df = std::remainder(std::atan2(f.balls[0].v.y, f.balls[0].v.x) - .4, 2 * pi);
        check(std::abs(dh - df / 2) < 1e-9 && std::abs(df) > .3 * pi / 180, "policy 0.21: raised cue deflects, half at half the ramp");
    }
    for (double side : {.5, -.5, .3}) for (double aim : {0.0, 1.1, -2.4}) {
        World off = planar(false), on = planar(true);
        off.strike(aim, 2, side, .2); on.strike(aim, 2, side, .2);
        const double dOff = std::remainder(std::atan2(off.balls[0].v.y, off.balls[0].v.x) - aim, 2 * pi);
        const double dOn = std::remainder(std::atan2(on.balls[0].v.y, on.balls[0].v.x) - aim, 2 * pi);
        if (side == .5 && aim == 0) std::printf("REPORT: side 0.5R  squirt off %.4f deg, on %.3f deg\n", deg(dOff), deg(dOn));
        check(std::abs(dOff) < 1e-12, "squirt off: cue ball leaves exactly on the aim line");
        check(std::abs(dOn) > .5 * pi / 180, "squirt on (literature default) still deflects");
        check(std::abs(off.balls[0].spin - on.balls[0].spin) < 1e-12 && std::abs(off.balls[0].v.length() - on.balls[0].v.length()) < 1e-12,
              "squirt off keeps the same speed and side spin");
    }
    {   // Slightly raised Đánh cue: no squirt term. What remains is the slate pushing back on a cue driven
        // down into the ball (start of swerve) — real physics, kept; it is small and only with a raised cue.
        World w = raised(8, false, false), s = raised(8, false, true); w.strike(.7, 2, .4, 0); s.strike(.7, 2, .4, 0);
        const double d = std::remainder(std::atan2(w.balls[0].v.y, w.balls[0].v.x) - .7, 2 * pi);
        const double ds = std::remainder(std::atan2(s.balls[0].v.y, s.balls[0].v.x) - .7, 2 * pi);
        std::printf("REPORT: 8 deg cue, side 0.4R: launch off-aim %.3f deg without squirt, %.3f deg with\n", deg(d), deg(ds));
        check(std::abs(d) < .5 * pi / 180 && std::abs(d) < std::abs(ds), "raised Đánh cue: no squirt term, only the small slate swerve remains");
    }

    // ---------- B. massé ----------
    double prevSpeed = 1e9, prevSpin = 0, cueKE = 0;
    for (double e : {30., 45., 60., 70., 80.}) {
        World w = raised(e, true); w.strike(pi / 2, 1.91, .389, -.389);
        const Ball& b = w.balls[0];
        const double spin = std::sqrt(b.w.x * b.w.x + b.w.y * b.w.y + b.spin * b.spin);
        std::printf("REPORT: coupled massé %2.0f deg: horizontal %.3f m/s, |omega| %.1f rad/s\n", e, b.v.length(), spin);
        check(b.v.length() < prevSpeed, "more elevation, less cue ball speed (Dr. Dave)");
        check(spin > prevSpin, "more elevation, more massé spin (cue-slate pinch)");
        prevSpeed = b.v.length(); prevSpin = spin;
        const double M = Config{}.cueMass(), u = (.78 / .88) * 1.91 * (1 + Config{}.mass / M) / 1.35;
        cueKE = .5 * M * u * u;
        check(energy(b) <= cueKE + 1e-9, "coupled massé never creates energy");
    }
    {
        World a = raised(80, true), b = raised(80, true);
        a.strike(pi / 2, 1.91, .389, -.389); b.strike(pi / 2, 1.91, -.389, -.389);
        check(std::abs(a.balls[0].v.x + b.balls[0].v.x) < 1e-9 && std::abs(a.balls[0].v.y - b.balls[0].v.y) < 1e-9, "coupled massé mirrors left/right english");
        World seq = raised(80, false), cpl = raised(80, true);
        seq.strike(pi / 2, 1.91, .389, -.389); cpl.strike(pi / 2, 1.91, .389, -.389);
        std::printf("REPORT: 80 deg 4:30 power 15: sequential %.3f m/s, coupled %.3f m/s\n", seq.balls[0].v.length(), cpl.balls[0].v.length());
        check(cpl.balls[0].v.length() > seq.balls[0].v.length(), "coupled massé launches stronger than the sequential approximation");
        World lo = raised(80, true), hi = raised(80, true);
        lo.strike(pi / 2, 1.2, .389, -.389); hi.strike(pi / 2, 3.1, .389, -.389);
        check(hi.balls[0].v.length() > lo.balls[0].v.length(), "massé speed grows with power");
        World flat = raised(0, true), flatSeq = raised(0, false);
        flat.strike(.3, 2, .2, .1); flatSeq.strike(.3, 2, .2, .1);
        check(std::abs(flat.balls[0].v.x - flatSeq.balls[0].v.x) < 1e-12 && std::abs(flat.balls[0].v.y - flatSeq.balls[0].v.y) < 1e-12,
              "level cue is unchanged by the massé option");
    }

    // ---------- C. english at the cushion ----------
    // Ball rolling at 30 deg incidence into a rail; returns tangential/normal ratio after the rail (forward > 0).
    auto rebound = [](double sideSpin, bool rightRail, double* speedOut = nullptr, double* spinOut = nullptr) {
        Config c; c.coupledCushions = true;
        Ball b; b.id = 0; const double r = c.radius, s = 1.5, a = 30 * pi / 180;
        b.v = {(rightRail ? 1 : -1) * s * std::cos(a), s * std::sin(a)}; b.w = b.v.perp() / r; b.spin = sideSpin;
        World::cushionResponse(b, c, V2{rightRail ? -1.0 : 1.0, 0}, rightRail ? 1 : 0);
        if (speedOut) *speedOut = b.v.length();
        if (spinOut) *spinOut = b.spin;
        return b.v.y / std::abs(b.v.x);
    };
    const double base = rebound(0, true), running = rebound(-60, true), reverse = rebound(60, true);
    std::printf("REPORT: rebound angle from normal: none %.2f, running %.2f, reverse %.2f deg\n",
                deg(std::atan(base)), deg(std::atan(running)), deg(std::atan(reverse)));
    check(running > base, "running english lengthens the rebound angle (BD Jul 2019)");
    check(reverse < base, "reverse english shortens the rebound angle (BD Jul 2019)");
    double vRun = 0, vRev = 0, wRun = 0, wRev = 0;
    rebound(-60, true, &vRun, &wRun); rebound(60, true, &vRev, &wRev);
    check(vRev < vRun, "reverse english leaves the rail slower than running english (BD Jul 2019)");
    check(wRun < 0 && wRev > 0, "side spin keeps its sense through the rail");
    // Same spin, opposite rails: running on one, reverse on the other.
    const double dRight = rebound(60, true) - rebound(0, true), dLeft = rebound(60, false) - rebound(0, false);
    std::printf("REPORT: same +60 rad/s spin: right-rail shift %+.3f, left-rail shift %+.3f (tan of angle)\n", dRight, dLeft);
    check(dRight * dLeft < 0, "zigzag: one spin lengthens on one rail and shortens on the opposite rail");

    std::printf("%s: AimMasseRail, %d failures\n", failures ? "FAIL" : "PASS", failures);
    return failures ? 1 : 0;
}
