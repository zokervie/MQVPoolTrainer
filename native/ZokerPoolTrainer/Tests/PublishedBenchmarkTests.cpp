// 0.31 — 20 published benchmarks (real-table measurements by others) run against the APP profile.
// Sources: [PP] Alciatore, "Physical properties of balls and tables" (billiards.colostate.edu/faq/physics/
// physical-properties) — ranges measured on real equipment; [TP x] Alciatore technical proofs (HSV-verified);
// [PT] pooltool (Kiefl, JOSS 2024) reference defaults. Each benchmark prints value and accepted range.
#include "../BankLab/Core/Physics.hpp"
#include <cmath>
#include <cstdio>
#include <functional>
#include <string>
using namespace banklab;

static int failures = 0, total = 0;
static void bench(int n, const char* what, double value, double lo, double hi, const char* src) {
    ++total; const bool ok = value >= lo && value <= hi;
    std::printf("%s B%02d %-58s %9.3f  [%g, %g]  %s\n", ok ? "PASS" : "FAIL", n, what, value, lo, hi, src);
    if (!ok) ++failures;
}
static Config open(Config c) { c.width = 20; c.length = 20; c.squirtEnabled = false; return c; }
static Ball make(int id, V2 p) { Ball b; b.id = id; b.p = p; return b; }
static void run(World& w, double s) { for (int i = 0; i < int(s * 960); ++i) w.step(); }
static double deg(V2 v) { return std::atan2(v.y, v.x) * 180 / pi; }

// cue ball (id 0) moving +y with given state hits object ball (id 1) at `cut` deg; returns after `after` s
struct Hit { Ball cue, ob; };
static Hit hit(Config c, double cutDeg, double v, double topRatio, double sideRatio, double after) {
    c = open(c); World w(c); const double R = c.radius, cut = cutDeg * pi / 180;
    Ball cue = make(0, {0, -1e-5}), ob = make(1, {-2 * R * std::sin(cut), 2 * R * std::cos(cut)});
    cue.v = {0, v}; cue.w = cue.v.perp() * (topRatio / R); cue.spin = 2.5 * v * sideRatio / R;
    w.balls = {cue, ob}; run(w, after); return {w.balls[0], w.balls[1]};
}

int main() {
    const Config app = Config::app(); const double R = app.radius, g = 9.81;
    // B01 stun straight: object-ball speed / cue speed = (1+e)/2 with e 0.92-0.98 [PP]
    { Hit h = hit(app, 0, 2, 0, 0, 0.002); bench(1, "stun straight: OB speed / CB speed", h.ob.v.length() / 2, .96, .99, "[PP] e 0.92-0.98"); }
    // B02 stop shot: stun straight -> cue ball stops [TP A.4]
    { Hit h = hit(app, 0, 2, 0, 0, 0.002); bench(2, "stop shot: CB speed left (m/s)", h.cue.v.length(), 0, .08, "[TP A.4]"); }
    // B03 90-degree rule: stun cut 30 deg, CB leaves ~90 deg from OB [TP A.4] (throw/e make it 85-90)
    { Hit h = hit(app, 30, 1.5, 0, 0, 0.003); double a = std::abs(deg(h.cue.v) - deg(h.ob.v)); if (a > 180) a = 360 - a;
      bench(3, "90 rule: stun 30 deg cut, CB-OB separation (deg)", a, 80, 90, "[TP A.4] 90 minus e and throw"); }
    // B04 30-degree rule: rolling CB, half-ball hit, final CB deflection 27-34 deg (theory 33.7) [TP A.5]
    { Hit h = hit(app, 30, 1.5, 1, 0, 1.5); bench(4, "30 rule: rolling half-ball, CB deflection (deg)", std::abs(90 - deg(h.cue.v)), 27, 34.5, "[TP A.5]"); }
    // B05 cut-induced throw, slow stun half-ball: 4-6.5 deg [TP A.14 / Marlow]
    { Hit h = hit(app, 30, .5, 0, 0, 0.003); bench(5, "CIT: slow stun half-ball throw (deg)", std::abs(deg(h.ob.v) - (90 + 30)), 3.5, 6.5, "[TP A.14]"); }
    // B06 throw falls with speed: fast (4 m/s) half-ball < slow [TP A.14]
    { Hit s = hit(app, 30, .5, 0, 0, .003), f = hit(app, 30, 4, 0, 0, .003);
      bench(6, "CIT: fast/slow throw ratio half-ball", std::abs(deg(f.ob.v) - 120) / std::abs(deg(s.ob.v) - 120), .2, .9, "[TP A.14]"); }
    // B07 rolling CB throws less than stun [TP A.14]
    { Hit s = hit(app, 30, 1, 0, 0, .003), r = hit(app, 30, 1, 1, 0, .003);
      bench(7, "CIT: rolling/stun throw ratio half-ball", std::abs(deg(r.ob.v) - 120) / std::abs(deg(s.ob.v) - 120), .3, .95, "[TP A.14]"); }
    // B08 gearing outside english (R*w = v sin(cut)) removes throw [TP A.14 / "gearing english"]
    { const double cut = 30 * pi / 180; Hit h = hit(app, 30, 1, 0, -std::sin(cut) * .4, .003);
      Hit h2 = hit(app, 30, 1, 0, std::sin(cut) * .4, .003);
      const double t1 = std::abs(deg(h.ob.v) - 120), t2 = std::abs(deg(h2.ob.v) - 120);
      bench(8, "gearing english: min throw of +/- gearing spin (deg)", std::min(t1, t2), 0, .6, "[TP A.14]"); }
    // B09 stun -> roll distance d = 12 v^2 / (49 mu_s g), mu_s 0.15-0.4 [TP 4.1, PP]
    { Config c = open(app); World w(c); Ball b = make(0, {0, 0}); b.v = {0, 2}; w.balls = {b}; double t = 0;
      while (t < 3) { w.step(); t += 1 / 960.0; const Ball& q = w.balls[0]; if (std::abs(q.v.y - q.w.x * 0 - (q.w.perp().y * 0)) < 0) break;
          const V2 slip = q.v - q.w.perp() * (-R); if (slip.length() < 1e-3) break; (void)slip; }
      const double d = w.balls[0].p.y, mu = 12 * 4 / (49 * d * g);
      bench(9, "stun->roll: implied sliding friction mu_s", mu, .15, .4, "[TP 4.1, PP]"); }
    // B10 natural roll speed = 5/7 of a stun start [TP 4.1]
    { Config c = open(app); World w(c); Ball b = make(0, {0, 0}); b.v = {0, 2}; w.balls = {b}; run(w, .6);
      bench(10, "stun->roll: rolling speed / start speed", (w.balls[0].v.length() + c.rolling * g * (.6 - 2 * 2 / (7 * c.sliding * g))) / 2, .69, .74, "[TP 4.1] 5/7"); }
    // B11 rolling resistance mu_r 0.005-0.015 [PP]: 1 m/s rolling ball distance
    { Config c = open(app); World w(c); Ball b = make(0, {0, 0}); b.v = {0, 1}; b.w = b.v.perp() * (1 / R); w.balls = {b}; run(w, 30);
      bench(11, "rolling: implied mu_r from stopping distance", 1 / (2 * g * w.balls[0].p.y), .005, .015, "[PP]"); }
    // B12 spin deceleration rate 5-15 rad/s^2 [PP]
    { Config c = open(app); World w(c); Ball b = make(0, {0, 0}); b.v = {0, 1}; b.w = b.v.perp() * (1 / R); b.spin = 40; w.balls = {b}; run(w, .5);
      bench(12, "side spin decay rate, rolling ball (rad/s^2)", (40 - w.balls[0].spin) / .5, 5, 15, "[PP]"); }
    // B13 draw: 0.5R draw at 2 m/s, OB 0.5 m away -> CB comes back [TP B.?, standard draw]
    { Config c = open(app); World w(c); w.balls = {make(0, {0, 0}), make(1, {0, .3})}; w.strike(pi / 2, 3, 0, -.5); run(w, 4);
      bench(13, "draw 0.5R 3 m/s, OB at 0.3 m: CB draw-back (m)", .3 - 2 * R - w.balls[0].p.y, .2, 2.0, "[TP 4.1/B]"); }
    // B14 follow: rolling straight hit -> CB keeps ~2/7 of its speed after regaining roll [TP A.?]
    { Hit h = hit(app, 0, 2, 1, 0, .8); bench(14, "follow: CB rolling speed after straight hit / v", (h.cue.v.length() + app.rolling * g * .8) / 2, .22, .34, "[TP] ~2/7"); }
    // B15 ball-rail restitution 0.6-0.9 [PP]: stun straight into rail
    { Config c = app; c.squirtEnabled = false; World w(c); w.balls = {make(0, {0, .3})}; w.balls[0].v = {1.5, 0}; size_t n = 0; double vin = 1.5;
      for (int i = 0; i < 960 * 2; ++i) { w.step(); for (; n < w.events.size(); ++n) if (w.events[n].kind == 0) { vin = w.events[n].impact; for (int k = 0; k < 10; ++k) w.step(); i = 1 << 30; break; } }
      bench(15, "ball-rail: rebound / impact normal speed", std::abs(w.balls[0].v.x) / vin, .6, .9, "[PP]"); }
    // B16 break cue-ball speed, full power break cue: 11-13.4 m/s (25-30 mph pro) [Alciatore break speed]
    { Config c = app; c.cueType = 2; World w(c); w.balls = {make(0, {0, 0})}; w.strike(pi / 2, 8.5, 0, 0);
      bench(16, "break cue full power: CB speed (m/s)", w.balls[0].v.length(), 10, 13.5, "[Alciatore break speed]"); }
    // B17 miscue limit: max tip contact offset ~0.5-0.6R [TP A.? miscue]
    bench(17, "max tip offset, level cue (R)", app.tipMaxOffset(false), .5, .6, "[TP miscue limit]");
    // B18 max side spin / speed ratio R*w/v at miscue limit = 2.5*offset (<= 1.5) [TP 4.2]
    bench(18, "max english R*w/v at limit", 2.5 * app.tipMaxOffset(false) * (1 + app.cueMass() / app.mass) / (1 + app.cueMass() / app.mass + 2.5 * std::pow(app.tipMaxOffset(false), 2)) , .6, 1.25, "[TP 4.2, A.30]");
    // B19 ball-ball friction at slow slip within 0.03-0.08 band at typical shot slip (1 m/s) [PP]
    bench(19, "ball-ball friction at 1 m/s slip", app.ballFrictionAt(1.0), .03, .08, "[PP]");
    // B20 0.43: fast-slip friction follows the TP A.14 fit (Marlow data) for normal balls: mu(4 m/s) = 0.0114
    bench(20, "ball-ball friction at 4 m/s slip (normal balls)", app.ballFrictionAt(4.0), .009, .014, "[TP A.14] 0.0114");
    // B27 0.43: spin transfer, straight stop shot, slow, 20 % english: <= 35.7 % (5/14) [TP A.27]
    {   Config c = open(app); World w(c); Ball cue = make(0, {0, 0}), ob = make(1, {0, 2 * R + 1e-5});
        cue.v = {0, .5}; cue.spin = 2.5 * .5 * .2 / R; const double s0 = cue.spin; w.balls = {cue, ob}; run(w, .02);
        bench(27, "spin transfer, slow straight, 20% english (fraction)", -w.balls[1].spin / s0, .25, .3571, "[TP A.27] max 5/14"); }
    // B28 0.43: fast (3 m/s) shots with 45 % english transfer little (normal balls): < 6 % [TP A.27 with TP A.14 friction]
    {   Config c = open(app); World w(c); Ball cue = make(0, {0, 0}), ob = make(1, {0, 2 * R + 1e-5});
        cue.v = {0, 3}; cue.spin = 2.5 * 3 * .45 / R; const double s0 = cue.spin; w.balls = {cue, ob}; run(w, .02);
        bench(28, "spin transfer, fast straight, 45% english (fraction)", -w.balls[1].spin / s0, 0, .06, "[TP A.27/A.14]"); }
    // ---- 0.43: Mathavan, Jackson & Parkin 2009 (Am. J. Phys. 77, 788) — high-speed overhead camera, 120-1000 fps,
    // snooker table [M09]. Snooker and pool cloth/cushions are close but not identical: ranges keep a margin.
    // B21 rolling deceleration 0.124-0.126 m/s^2 [M09] (pool cloth spread: 0.10-0.16)
    { Config c = open(app); World w(c); Ball b = make(0, {0, 0}); b.v = {0, 1}; b.w = b.v.perp() * (1 / R); w.balls = {b}; run(w, 2);
      bench(21, "rolling deceleration (m/s^2)", (1 - w.balls[0].v.length()) / 2, .10, .16, "[M09] 0.124-0.126"); }
    // B22 sliding friction 0.178-0.245 [M09]
    bench(22, "ball-cloth sliding friction mu_s", app.sliding, .178, .245, "[M09] 1.75-2.40 m/s^2");
    // B23-25 rolling ball straight into a cushion, no side: rebound speed right after the impulse vs the measured fit
    // y = -0.0877x^2 + 1.131x - 0.0953 (31 shots, 0.28-3.5 m/s) [M09 Fig. 9], +-12 % (snooker cushions: pool sources
    // read lower — DigiBall 0.73-0.77 — so the app sits between; see Config::app railRestitution)
    {   int n = 23;
        for (double vin : {0.6, 1.5, 3.0}) {
            Config c = app; c.squirtEnabled = false; c.width = 1.27; c.length = 2.54; World w(c);
            Ball b = make(0, {0, 0.6}); b.v = {vin, 0}; b.w = b.v.perp() * (1 / R); w.balls = {b};   // y 0.6: clear of the side pocket
            // run to the cushion, then 6 ms past the end of contact (impulse over, before cloth friction acts much)
            // speed of the ball as it leaves the cushion: peak outward speed within 25 ms after the velocity reverses
            bool hitRail = false; int after = 0; double out = 0;
            for (int i = 0; i < 960 * 4 && after < 24; ++i) { w.step(); if (!hitRail && w.balls[0].v.x < 0) hitRail = true;
                if (hitRail) { ++after; out = std::max(out, w.balls[0].v.length()); } }
            double vi = vin; for (const auto& e : w.events) if (e.kind == 0) { vi = e.impact; break; }   // speed AT impact
            const double fit = -0.0877 * vi * vi + 1.131 * vi - 0.0953;
            char label[96]; std::snprintf(label, sizeof label, "cushion rebound/fit, rolling %.1f m/s straight in", vi);
            bench(n++, label, out / fit, .88, 1.12, "[M09 Fig.9] +-12%");
        }
    }
    // B26 oblique ball-ball collisions, rolling cue ball: post-slip object-ball speed / measured (5 shots, Table I) [M09]
    {   const double table1[5][4] = {{1.539, 33.83, .816, .836}, {1.032, 26.36, .520, .629}, {1.364, 40.52, .925, .700},
                                     {1.731, 46.50, 1.275, .787}, {.942, 18.05, .365, .581}};
        double worst = 0;
        for (const auto& r : table1) {
            Config c = open(app); World w(c); const double cut = r[1] * pi / 180;
            Ball cue = make(0, {0, -0.3}), ob = make(1, {-2 * R * std::sin(cut), 2 * R * std::cos(cut)});
            // rolling at r[0] when it reaches the object ball: start a little faster to cover 0.3 m of rolling drag
            const double v0 = std::sqrt(r[0] * r[0] + 2 * c.rolling * g * 0.3);
            cue.v = {0, v0}; cue.w = cue.v.perp() * (1 / R); w.balls = {cue, ob};
            double vo = -1, vc = -1; bool contact = false;
            for (int i = 0; i < 960 * 3 && (vo < 0 || vc < 0); ++i) {
                w.step(); if (!contact && w.balls[1].v.length() > 1e-3) contact = true; if (!contact) continue;
                for (int k = 0; k < 2; ++k) { const Ball& q = w.balls[size_t(k)]; const double slip = (q.v + q.w.perp() * R).length();
                    double& out = k ? vo : vc; if (out < 0 && slip < 2e-3 && q.v.length() > 1e-3) out = q.v.length(); }
            }
            worst = std::max({worst, std::abs(vo / r[3] - 1), std::abs(vc / r[2] - 1)});
            std::printf("REPORT M09 Table I V %.3f cut %.1f: OB %.3f (meas %.3f)  CB %.3f (meas %.3f)\n", r[0], r[1], vo, r[3], vc, r[2]);
        }
        bench(26, "oblique collisions: worst post-slip speed error vs measured", worst, 0, .15, "[M09 Table I] theory itself 2-12%");
    }
    std::printf("%d/%d published benchmarks in range\n", total - failures, total);
    return failures ? 1 : 0;
}
