// 0.52 — draw (trô) checked against the sliding equations. The drill checker reported "weak draw" (8–12 cm from
// 0.69 m); these tests pin down that the core follows the published equations, so the finding is a drill-design
// matter (pace / distance), not a coefficient error.
//
// Sources and labels:
//  - slide → roll of a ball launched with speed v0 and spin Rω0 along the travel line (ω > 0 = topspin), cloth
//    friction μ:   t_r = 2 (v0 − Rω0) / (7 μ g),   v_r = (5/7) v0 + (2/7) Rω0     [đã công bố: Alciatore TP 4.1 / A.4;
//    Marlow, "The Physics of Pocket Billiards", ch. 3]. Analytic identity → hard tolerance.
//  - off-centre hit keeps v0 = s·k/(k + 2.5 b²), k = 1 + m/M, Rω0 = 2.5 b v0   [đã công bố: TP A.30]; b = tip offset / R.
//  - stun slide distance d = 12 v0² / (49 μ g)   [suy ra from the two lines above].
//  - at ball–ball contact the cue ball can lose at most 2.5 μ_bb (1+e)/2 · v_c of Rω (friction cap of the impulse
//    model)   [suy ra; μ_bb(0) = Config::ballFriction, đã công bố: Marlow fit, see Physics.hpp].
#include "../BankLab/Core/Physics.hpp"
#include <cmath>
#include <iostream>
#include <string>
using namespace banklab;
static int fails = 0, checks = 0;
static void check(bool ok, const std::string& what) { ++checks; if (!ok) { ++fails; std::cerr << "FAIL: " << what << "\n"; } }
static bool near(double a, double b, double rel, double abs_ = 0) { return std::abs(a - b) <= std::max(abs_, rel * std::abs(b)); }
static const double g = 9.81;

static Config cfg() { Config c = Config::app(); c.squirtEnabled = false; return c; }
static Ball mk(int id, V2 p) { Ball b; b.id = id; b.p = p; return b; }
// signed Rω along the travel direction `d` (+ = topspin), from the strike convention w = d.perp()·(Rω/R)
static double spinAlong(const Ball& b, V2 d, double R) { return b.w.dot(d.perp()) * R; }

static void slideToRoll() {
    const Config c = cfg(); const double mu = c.sliding, R = c.radius, k = 1 + c.mass / c.cueMass();
    for (double top : {0.0, -0.3, -0.5, 0.3}) for (double s : {1.5, 2.0, 3.0, 4.0}) {
        const double v0 = s * k / (k + 2.5 * top * top), rw0 = 2.5 * top * v0;
        const double tr = 2 * std::abs(v0 - rw0) / (7 * mu * g), vr = 5. / 7 * v0 + 2. / 7 * rw0;
        const double sign = v0 > rw0 ? -1 : 1;                       // friction slows a draw/stun ball, speeds up over-spun follow
        const double dr = v0 * tr + sign * .5 * mu * g * tr * tr;
        if (dr > 2.2) continue;                                      // would reach the head rail first
        World w(c); w.balls = {mk(0, {0, -1.15})}; w.strike(pi / 2, s, 0, top);
        const std::string tag = " (top " + std::to_string(top) + ", " + std::to_string(s) + " m/s)";
        check(near(w.balls[0].v.y, v0, 1e-9) && near(spinAlong(w.balls[0], {0, 1}, R), rw0, 1e-9, 1e-12), "launch speed and spin follow TP A.30" + tag);
        const int n = int(std::ceil(tr * 960));                      // whole steps: the short remainder is travelled rolling at v_r
        for (int i = 0; i < n; ++i) w.step();
        check(near(w.balls[0].p.y + 1.15, dr + vr * (n / 960.0 - tr), .005), "slide distance to natural roll" + tag);
        check(near(w.balls[0].v.y, vr, .005), "speed at natural roll = 5/7 v0 + 2/7 Rw0" + tag);
        check(near(spinAlong(w.balls[0], {0, 1}, R), w.balls[0].v.y, .01), "rolling without slip at t_r" + tag);
        if (top == 0.0) check(near(dr, 12 * v0 * v0 / (49 * mu * g), 1e-9), "stun slide distance = 12 v0^2 / (49 mu g)" + tag);
    }
}

// Straight draw shot down the line of the "stop / draw" drills (object ball goes to the head-right corner pocket,
// the cue ball has 1.4 m of free cloth behind it).
struct Draw { double vc = 0, rwc = 0, v1 = 0, rw1 = 0, back = 0; bool hit = false, railed = false; };
static Draw draw(double L, double s, double top) {
    const Config c = cfg(); const double R = c.radius; const V2 ob{0.33, 0.63};
    const double a = std::atan2(0.62, 0.31); const V2 d{std::cos(a), std::sin(a)};
    const V2 contact = ob - d * (2 * R), cue = contact - d * L;
    World w(c); w.balls = {mk(0, cue), mk(1, ob)}; w.strike(a, s, 0, top);
    Draw r; Ball before = w.balls[0];
    for (int i = 0; i < 960 * 30 && w.moving(); ++i) {
        if (!r.hit) before = w.balls[0];
        const size_t n = w.events.size(); w.step();
        for (size_t j = n; j < w.events.size(); ++j) {
            const Event& e = w.events[j];
            if (e.kind == 1 && !r.hit) { r.hit = true; r.vc = before.v.dot(d); r.rwc = spinAlong(before, d, R); r.v1 = w.balls[0].v.dot(d); r.rw1 = spinAlong(w.balls[0], d, R); }
            else if (r.hit && e.a == 0 && e.kind != 2) r.railed = true;      // cue ball touched a rail or a ball again
            else if (r.hit && e.kind == 1 && e.b == 0) r.railed = true;
        }
    }
    r.back = (contact - w.balls[0].p).dot(d);
    return r;
}

static void drawBack() {
    const Config c = cfg(); const double mu = c.sliding, mur = c.rolling, k = 1 + c.mass / c.cueMass(), e = c.ballRestitution;
    double last = -1;
    for (double L : {0.30, 0.45, 0.64}) for (double s : {2.6, 3.0, 3.4}) {
        const double top = -0.5, v0 = s * k / (k + 2.5 * top * top), rw0 = 2.5 * top * v0;
        const double a = .5 * mu * g, t = (v0 - std::sqrt(v0 * v0 - 4 * a * L)) / (2 * a);
        const double vc = v0 - mu * g * t, rwc = rw0 + 2.5 * mu * g * t;
        const Draw r = draw(L, s, top);
        const std::string tag = " (L " + std::to_string(L) + ", " + std::to_string(s) + " m/s)";
        check(r.hit && near(r.vc, vc, .01) && near(r.rwc, rwc, .01, .005), "speed and back-spin arriving at the object ball" + tag);
        // collision: forward speed left ≤ (1−e)/2 v_c; back-spin lost to ball–ball friction within the friction cap
        check(r.v1 >= -1e-6 && r.v1 <= (1 - e) / 2 * vc + 1e-6, "cue ball keeps at most (1-e)/2 of its speed" + tag);
        const double lost = r.rw1 - r.rwc, cap = 2.5 * c.ballFriction * (1 + e) / 2 * vc;
        check(std::abs(lost) <= cap + 1e-6, "spin changed at contact stays within the ball-ball friction cap" + tag);
        // after contact: slide to roll, then roll out — from the state the core reports
        const double vf = 5. / 7 * r.v1 + 2. / 7 * r.rw1;
        const double back = -((r.v1 * r.v1 - vf * vf) / (2 * mu * g)) + vf * vf / (2 * mur * g);
        if (vf < 0 && !r.railed) {
            check(near(r.back, back, .08, .01), "draw-back distance = slide + roll-out from the post-contact state" + tag +
                  " sim " + std::to_string(r.back) + " eq " + std::to_string(back));
            if (s > 2.6) check(r.back > last, "more pace → more draw at the same distance" + tag);
        }
        last = s == 3.4 ? -1 : r.back;
    }
    // the checker's finding, as a behaviour lock: from 0.64 m a 2 m/s stroke cannot draw (spin gone before contact),
    // a 4 m/s stroke draws back more than 0.5 m.
    const Draw slow = draw(0.64, 2.0, -0.5), fast = draw(0.64, 4.0, -0.5);
    check(slow.back < 0.02 && near(slow.rwc, slow.vc, .03), "0.64 m at 2 m/s: natural roll before contact, no draw");
    check(fast.rwc < -1.5 && (fast.back > 0.5 || fast.railed), "0.64 m at 4 m/s: plenty of back-spin left");
}

int main() {
    slideToRoll(); drawBack();
    std::cout << (fails ? "FAILED " : "OK ") << checks - fails << "/" << checks << " draw identity checks\n";
    return fails ? 1 : 0;
}
