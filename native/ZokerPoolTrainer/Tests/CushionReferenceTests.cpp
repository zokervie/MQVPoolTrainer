// 0.52 — cushion benchmark against the Mathavan–Jackson–Parkin 2010 two-contact impact model.
//
// Step 1 of the cushion work: the reference and the error table come first; the app's cushion model is NOT changed
// here. The reference is an independent re-implementation, in this file, of the published impulse equations
// (cushion contact I at height h, table contact C, sliding friction at both, energetic restitution):
//   Mathavan S., Jackson M.R., Parkin R.M., "A theoretical analysis of billiard ball dynamics under cushion
//   impacts", Proc. IMechE C 224(9), 2010 — equations (12)–(17); signs cross-checked against pooltool's
//   mathavan_2010 module (open source).                                              [đã công bố]
// Coefficients of the reference:
//   e_e = 0.98, μ_w = 0.14 (ball–cushion)            [đã đo — Mathavan 2010, snooker table, valid to 2.5 m/s normal]
//   μ_s = Config::sliding (0.20; paper 0.212)         [đã công bố]
//   nose height h: 7R/5 (paper, snooker)  and  1.27 R (WPA pool spec: 62.5–64.5 % of the ball diameter)  [đã công bố]
// Frame: x along the rail, y into the rail, z up. Rolling ball: ω = (−vy/R, vx/R, ·).
//
// What is asserted: (1) the reference itself — convergence, symmetry, no energy gain (hard); (2) the present app
// model's distance from the reference stays under the ceilings measured on 22/11/2026 (regression lock, the table
// is printed). A future cushion model behind a switch has to beat these numbers on the held-out rows.
#include "../BankLab/Core/Physics.hpp"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <iostream>
#include <string>
#include <vector>
using namespace banklab;
static int fails = 0, checks = 0;
static void check(bool ok, const std::string& what) { ++checks; if (!ok) { ++fails; std::cerr << "FAIL: " << what << "\n"; } }

struct St { double vx, vy, wx, wy, wz; };
static St mathavan(St s, double M, double R, double h, double ee, double muS, double muW, int steps = 5000) {
    const double sn = (h - R) / R, cs = std::sqrt(1 - sn * sn), f = 5 / (2 * M * R);
    auto advance = [&](St& q, double dp) {
        const double xi = q.vx + q.wy * R * sn - q.wz * R * cs, yi = -q.vy * sn + q.wx * R;
        const double xc = q.vx - q.wy * R, yc = q.vy + q.wx * R;
        const double li = std::hypot(xi, yi), lc = std::hypot(xc, yc);
        const double cp = li > 1e-12 ? xi / li : 0, sp = li > 1e-12 ? yi / li : 0, cq = lc > 1e-12 ? xc / lc : 0, sq = lc > 1e-12 ? yc / lc : 0;
        const double n = sn + muW * sp * cs;
        q.vx += -(1 / M) * (muW * cp + muS * cq * n) * dp;
        q.vy += -(1 / M) * (cs - muW * sn * sp + muS * sq * n) * dp;
        q.wx += -f * (muW * sp + muS * sq * n) * dp;
        q.wy += -f * (muW * cp * sn - muS * cq * n) * dp;
        q.wz += f * (muW * cp * cs) * dp;
    };
    double W = 0; const double dp = M * s.vy / steps;
    while (s.vy > 0) {                                   // compression: until the normal speed is zero
        St t = s; advance(t, dp);
        if (t.vy <= 0) { double lo = 0, hi = dp; for (int i = 0; i < 40; ++i) { const double mid = .5 * (lo + hi); St u = s; advance(u, mid); (u.vy > 0 ? lo : hi) = mid; }
            W += lo * std::abs(s.vy) * cs; advance(s, lo); break; }
        W += dp * std::abs(s.vy) * cs; s = t;
    }
    const double target = ee * ee * W; double Wr = 0;
    for (int guard = 0; Wr < target && guard < steps * 50; ++guard) {   // restitution: until e_e² of the compression work is returned
        const double dW = dp * std::abs(s.vy) * cs;
        if (Wr + dW >= target && std::abs(s.vy) > 1e-12) { advance(s, (target - Wr) / (std::abs(s.vy) * cs)); break; }
        Wr += dW; advance(s, dp);
    }
    return s;
}
// velocity once the ball has returned to natural roll on the cloth (v − 2/7 · slip at the table contact)
static V2 rollOut(const St& s, double R) { return {s.vx - 2. / 7 * (s.vx - s.wy * R), s.vy - 2. / 7 * (s.vy + s.wx * R)}; }
static double energy(const St& s, double M, double R) { return .5 * M * (s.vx * s.vx + s.vy * s.vy) + .2 * M * R * R * (s.wx * s.wx + s.wy * s.wy + s.wz * s.wz); }
static double deg(double r) { return r * 180 / pi; }

struct Row { const char* name; double alpha, speed, top, side; bool heldOut; };   // top: Rω_roll/v (1 = rolling, 0 = stun), side: Rω_z/v
struct Out { St in{}, app{}; bool ok = false; };
// The app's response: a ball placed just in front of the head rail with the requested state; states are read one
// step before and right after the rail event.
static Out appRebound(const Config& c, const Row& r) {
    const double R = c.radius, a = r.alpha * pi / 180; const V2 d{std::cos(a), std::sin(a)};
    World w(c); Ball b; b.id = 0; b.p = V2{-0.25, 1.20} + d * 0.0; b.v = d * r.speed;
    b.w = d.perp() * (r.top * r.speed / R); b.spin = r.side * r.speed / R; w.balls = {b};
    Out o; Ball before = b;
    for (int i = 0; i < 960 * 2; ++i) {
        before = w.balls[0]; const size_t n = w.events.size(); w.step();
        for (size_t j = n; j < w.events.size(); ++j) if (w.events[j].kind == 0 && w.events[j].a == 0) o.ok = true;
        if (o.ok) break;
    }
    // world → rail frame (head rail: x along = world x, y into the rail = world y); app w is the horizontal part of ω
    auto conv = [&](const Ball& q) { const V2 px = V2{1, 0}.perp(); const double sgn = px.y;   // perp of +x is (0, sgn)
        return St{q.v.x, q.v.y, sgn > 0 ? q.w.x : -q.w.x, sgn > 0 ? q.w.y : -q.w.y, q.spin}; };
    o.in = conv(before); o.app = conv(w.balls[0]);
    return o;
}

int main() {
    Config c = Config::app(); c.squirtEnabled = false;
    const double M = c.mass, R = c.radius, muS = c.sliding; double ee = 0.98, muW = 0.14; const double hPaper = 1.4 * R, hPool = 1.27 * R;
    // ── (1) the reference itself
    for (double al : {90.0, 60.0, 35.0}) for (double side : {0.0, 0.6, -0.6}) {
        const double a = al * pi / 180, v = 1.5; const St in{v * std::cos(a), v * std::sin(a), -v * std::sin(a) / R, v * std::cos(a) / R, side * v / R};
        const St o1 = mathavan(in, M, R, hPaper, ee, muS, muW, 5000), o2 = mathavan(in, M, R, hPaper, ee, muS, muW, 20000);
        const double dv = std::max({std::abs(o1.vx - o2.vx), std::abs(o1.vy - o2.vy), std::abs(o1.wz - o2.wz) * R});
        check(dv < 2e-3, "reference converged at 5000 steps (diff " + std::to_string(dv) + " m/s)");
        check(o1.vy < 0 && energy(o1, M, R) <= energy(in, M, R) + 1e-9, "reference: ball leaves the rail and gains no energy");
        const St mir{-in.vx, in.vy, in.wx, -in.wy, -in.wz}, om = mathavan(mir, M, R, hPaper, ee, muS, muW);
        check(std::abs(om.vx + o1.vx) < 1e-6 && std::abs(om.vy - o1.vy) < 1e-6 && std::abs(om.wz + o1.wz) < 1e-4, "reference: mirror symmetry along the rail");
    }
    // ── (2) the app against the reference
    const std::vector<Row> rows{
        {"roll 90", 90, 1.0, 1, 0, false}, {"roll 90 fast", 90, 2.4, 1, 0, true}, {"roll 60", 60, 1.5, 1, 0, false}, {"roll 60 fast", 60, 2.6, 1, 0, true},
        {"roll 45", 45, 1.5, 1, 0, false}, {"roll 45 slow", 45, 0.8, 1, 0, true}, {"roll 30", 30, 1.5, 1, 0, false}, {"roll 30 fast", 30, 3.0, 1, 0, true},
        {"stun 60", 60, 2.0, 0, 0, false}, {"stun 45", 45, 2.0, 0, 0, true}, {"stun 30", 30, 2.5, 0, 0, false},
        {"roll 90 running .5", 90, 1.5, 1, 0.5, false}, {"roll 60 running .5", 60, 1.5, 1, 0.5, true}, {"roll 60 reverse .5", 60, 1.5, 1, -0.5, false},
        {"roll 45 running .5", 45, 1.5, 1, 0.5, false}, {"roll 45 reverse .5", 45, 1.5, 1, -0.5, true}, {"roll 30 running .5", 30, 2.0, 1, 0.5, true}};
    struct Err { double tune = 0, held = 0, speed = 0, mean = 0; };
    auto table = [&](const Config& cfg, const char* title) {
        std::printf("\n== %s ==\n", title);
std::printf("%-20s %5s | rebound angle from the rail after roll-out (deg)   | speed kept after roll-out\n", "case", "in");
        std::printf("%-20s %5s | %7s %7s %7s  err-paper err-pool | %6s %6s %6s\n", "", "", "app", "h=1.40R", "h=1.27R", "app", "1.40R", "1.27R");
        double worstTune = 0, worstHeld = 0, worstSpeed = 0, sumAbs = 0; int n = 0;
        for (const Row& r : rows) {
            const Out o = appRebound(cfg, r); check(o.ok, std::string("app ball reaches the rail: ") + r.name); if (!o.ok) continue;
            const St p = mathavan(o.in, M, R, hPaper, ee, muS, muW), q = mathavan(o.in, M, R, hPool, ee, muS, muW);
            const V2 va = rollOut(o.app, R), vp = rollOut(p, R), vq = rollOut(q, R);
            const double v0 = std::hypot(o.in.vx, o.in.vy);
            const double aa = deg(std::atan2(-va.y, va.x)), ap = deg(std::atan2(-vp.y, vp.x)), aq = deg(std::atan2(-vq.y, vq.x));
            const double ka = std::hypot(va.x, va.y) / v0, kp = std::hypot(vp.x, vp.y) / v0, kq = std::hypot(vq.x, vq.y) / v0;
            std::printf("%-20s %5.1f | %7.2f %7.2f %7.2f  %8.2f %8.2f | %6.3f %6.3f %6.3f %s\n", r.name, deg(std::atan2(o.in.vy, o.in.vx)), aa, ap, aq, aa - ap, aa - aq, ka, kp, kq, r.heldOut ? "(giữ riêng)" : "");
            (r.heldOut ? worstHeld : worstTune) = std::max(r.heldOut ? worstHeld : worstTune, std::abs(aa - aq));
            worstSpeed = std::max(worstSpeed, std::abs(ka - kq)); sumAbs += std::abs(aa - aq); ++n;
        }
        std::printf("vs pool-height reference: worst angle error — tuning rows %.2f deg, held-out rows %.2f deg; mean %.2f deg; worst speed-kept error %.3f\n",
                    worstTune, worstHeld, sumAbs / std::max(1, n), worstSpeed);
        Err e; e.tune = worstTune; e.held = worstHeld; e.speed = worstSpeed; e.mean = sumAbs / std::max(1, n); return e;
    };
    const Err old = table(c, "model 0 (present, default) vs the paper's coefficients (e .98, mu .14)");
    Config m = c; m.cushionModel = 1; ee = m.cushionE; muW = m.cushionFriction;   // model 1 is checked against the same equations with its own coefficients
    const Err neu = table(m, "model 1 (behind the switch) vs the reference with the same coefficients");
    std::printf("\nmodel 0 vs paper reference -> model 1 vs its own reference: tuning %.2f -> %.2f deg | held-out %.2f -> %.2f deg | mean %.2f -> %.2f deg | speed %.3f -> %.3f\n",
                old.tune, neu.tune, old.held, neu.held, old.mean, neu.mean, old.speed, neu.speed);
    const double worstTune = old.tune, worstHeld = old.held, worstSpeed = old.speed;
    check(neu.tune <= 0.5 && neu.held <= 0.5 && neu.speed <= 0.01, "model 1 within 0.5 deg and 0.01 of the reference on tuning and held-out rows");
    check(Config::app().cushionModel == 0 && Config().cushionModel == 0, "model 1 stays off by default");
    // Regression lock on the present model (measured 22/11/2026: 2.51 / 2.50 deg, 0.094). Not a claim of accuracy.
    check(worstTune <= 3.0 && worstHeld <= 3.0, "app rebound angle within 3 deg of the pool-height reference (present model)");
    check(worstSpeed <= 0.11, "app speed kept within 0.11 of the pool-height reference (present model)");
    std::cout << (fails ? "FAILED " : "OK ") << checks - fails << "/" << checks << " cushion reference checks\n";
    return fails ? 1 : 0;
}
