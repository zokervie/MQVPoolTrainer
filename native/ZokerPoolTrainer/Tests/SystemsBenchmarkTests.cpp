// 0.32 — benchmark set 2 (owner 08/11/2026: kicks 1-4 rails, banks 1-4, massé, jump, ball-on-ball jump, trick shots,
// spin effects; each with no english / running / reverse). Criteria come from published, real-table results:
// [TP] Alciatore technical proofs + HSV videos (billiards.colostate.edu); [BJ] Bob Jewett, Billiards Digest
// ("hard banks go short", corner/parallel kicks); [C5] Corner-5 / Diamond system chart (PoolDawg, TP 7.2);
// [CO] Coriolis 1835 / TP 4.? massé final direction; [PP] physical properties (slate e 0.5, rail e 0.6-0.9).
// Together with PublishedBenchmarkTests (20) this is the 60+ case calibration set the CI runs on every build.
#include "../BankLab/Core/KickSystems.hpp"
#include <cmath>
#include <cstdio>
#include <vector>
using namespace banklab;

static int failures = 0, total = 0;
static void bench(const char* id, const char* what, double v, double lo, double hi, const char* src) {
    ++total; const bool ok = std::isfinite(v) && v >= lo && v <= hi;
    std::printf("%s %-5s %-62s %9.3f  [%g, %g]  %s\n", ok ? "PASS" : "FAIL", id, what, v, lo, hi, src);
    if (!ok) ++failures;
}
static Ball mk(int id, V2 p) { Ball b; b.id = id; b.p = p; return b; }
static double deg(V2 v) { return std::atan2(v.y, v.x) * 180 / pi; }

struct Track { std::vector<V2> at, out; std::vector<double> impact; Ball end; double maxH = 0; bool sunk = false; };
// Plays a shot; for ball `id` records every rail contact point, the velocity 30 ms after it, and its impact speed.
static Track play(Config c, std::vector<Ball> balls, int id, double angle, double speed, double side, double top,
                  double elevation = 0, double seconds = 12) {
    c.squirtEnabled = false; c.cueElevationDegrees = elevation; if (elevation > 0) c.experimental3D = true;
    World w(c); w.balls = balls; w.strike(angle, speed, side, top);
    Track t; size_t n = 0;
    for (int i = 0; i < int(960 * seconds) && w.moving(); ++i) {
        w.step();
        for (const auto& b : w.balls) if (b.id == id) t.maxH = std::max(t.maxH, b.height);
        for (; n < w.events.size(); ++n) {
            const auto& e = w.events[n];
            if (e.kind == 0 && e.a == id) { t.at.push_back(e.p); t.impact.push_back(e.impact);
                World look = w; for (int k = 0; k < 29; ++k) look.step(); for (const auto& b : look.balls) if (b.id == id) t.out.push_back(b.v); }
            if (e.kind == 2 && e.a == id) t.sunk = true;
        }
    }
    for (const auto& b : w.balls) if (b.id == id) t.end = b;
    return t;
}
// Angle of a velocity from the normal of the rail it just left (long rails: normal = x; short: y).
static double fromNormal(V2 v, bool longRail) { return longRail ? std::atan2(std::abs(v.y), std::abs(v.x)) * 180 / pi : std::atan2(std::abs(v.x), std::abs(v.y)) * 180 / pi; }

int main() {
    const Config app = Config::app(); const double R = app.radius;
    const double side[3] = {0, .3, -.3};   // none, running, reverse

    // ---------------- KICK 1 rail (cue ball, 45 deg into a long rail, away from the side pocket) ----------------
    // [TP/BJ]: medium speed no english ~ mirror (out ~ in); running english widens, reverse narrows; harder = shorter.
    double k1[3][3];
    for (int s = 0; s < 3; ++s) for (int v = 0; v < 3; ++v) {
        const double sp[3] = {1.5, 3, 5};
        const Track t = play(app, {mk(0, {0, -1.0})}, 0, pi / 4, sp[v], side[s], 0);
        k1[s][v] = t.out.empty() ? NAN : fromNormal(t.out[0], true);
    }
    bench("K1a", "kick 1 rail, no english, medium: out angle (in 45)", k1[0][1], 38, 50, "[TP] mirror");
    bench("K1b", "kick 1 rail, running english: wider than none (deg)", k1[1][1] - k1[0][1], 3, 30, "[TP]");
    // Reverse english at 45 deg: the rail contact already slides without english, so Coulomb friction saturates and
    // reverse adds little (running english acts more than reverse). It must not go wider than none.
    bench("K1c", "kick 1 rail, reverse english: not wider than none (deg)", k1[0][1] - k1[2][1], -1.5, 30, "[TP] friction saturates");
    bench("K1h", "kick 1 rail: running english acts more than reverse (deg)", (k1[1][1] - k1[0][1]) - std::abs(k1[0][1] - k1[2][1]), 1, 40, "[TP]");
    bench("K1d", "kick 1 rail, no english: hard (5) shorter than soft (1.5) (deg)", k1[0][0] - k1[0][2], 0.5, 20, "[BJ]");
    bench("K1e", "kick 1 rail, running english hard: still wider than none hard", k1[1][2] - k1[0][2], 1, 30, "[TP]");
    bench("K1f", "kick 1 rail, reverse english soft: narrower than none soft", k1[0][0] - k1[2][0], 1, 35, "[TP]");
    // follow vs draw into the rail: topspin bends the path forward after the rail (wider later), draw shorter
    { const Track f = play(app, {mk(0, {0, -1.0})}, 0, pi / 4, 2, 0, .4), d = play(app, {mk(0, {0, -1.0})}, 0, pi / 4, 2, 0, -.4);
      // overall path after the rail (rail point -> where the ball stops), not the instant after contact
      const double fa = fromNormal(f.end.p - f.at[0], true), da = fromNormal(d.end.p - d.at[0], true);
      bench("K1g", "kick 1 rail: follow ends wider than draw (deg)", fa - da, 0, 45, "[TP B.? rail follow/draw]"); }

    // ---------------- KICK 2 rails: through a corner, stun no english exits ~parallel (antiparallel) ----------------
    { const Track t = play(app, {mk(0, {-.2, .6})}, 0, std::atan2(.5, .45), 2.5, 0, 0);
      if (t.out.size() >= 2) { double turn = std::abs(deg(t.out[1]) - deg(V2{.45, .5})); if (turn > 180) turn = 360 - turn;
        bench("K2a", "kick 2 rails through a corner, no english: reversal (deg, 180 = parallel)", turn, 165, 195, "[BJ] parallel corner"); }
      else bench("K2a", "kick 2 rails through a corner", NAN, 0, 1, "[BJ]"); }
    for (int s = 1; s < 3; ++s) {
        const Track t = play(app, {mk(0, {-.2, .6})}, 0, std::atan2(.5, .45), 2.5, side[s], 0);
        double turn = t.out.size() >= 2 ? std::abs(deg(t.out[1]) - deg(V2{.45, .5})) : NAN; if (turn > 180) turn = 360 - turn;
        bench(s == 1 ? "K2b" : "K2c", s == 1 ? "kick 2 rails, running english: still a clean 2-rail return (deg)" : "kick 2 rails, reverse english: clean 2-rail return (deg)", turn, 140, 220, "[BJ]");
    }
    // ---------------- KICK 3 rails: Corner-5 chart ----------------
    { const auto f = kick::corner5Fit(app, 3, .35);
      bench("K3a", "kick 3 rails, Corner-5 A = D - T: table shift (units)", f.mean, -5, 5, "[C5]");
      bench("K3b", "kick 3 rails, Corner-5: spread (units, 10 = 1 diamond)", f.spread, 0, 3.5, "[C5]");
      const auto h = kick::corner5Fit(app, 4.5, .35), sl = kick::corner5Fit(app, 2, .35);
      bench("K3c", "kick 3 rails: harder stroke arrives shorter (units)", sl.mean - h.mean, 0.5, 40, "[C5 speed note]");
      const auto lo = kick::corner5Fit(app, 3, .2), hi = kick::corner5Fit(app, 3, .5);
      bench("K3d", "kick 3 rails: more running english arrives longer (units)", hi.mean - lo.mean, 0.5, 40, "[C5 english note]"); }
    // ---------------- KICK 4 rails: energy left after each rail ----------------
    { const Track t = play(app, {mk(0, {-.3, -.9})}, 0, std::atan2(1.2, 1.0), 4, 0, 0);
      bench("K4a", "kick 4+ rails: rails reached at 4 m/s", double(t.impact.size()), 4, 12, "[PP]");
      if (t.impact.size() >= 4) { double worst = 1; for (size_t i = 1; i < 4; ++i) worst = std::min(worst, t.impact[i] / t.impact[i - 1]);
        bench("K4b", "kick 4 rails: speed kept rail to rail (min ratio)", worst, .45, .95, "[PP] rail e 0.6-0.9 + cloth"); } }

    // ---------------- BANK 1 rail (object ball), full hit 45 deg ----------------
    double b1[3];
    for (int v = 0; v < 3; ++v) { const double sp[3] = {1.5, 3, 5}; const V2 dir = V2{1, 1}.unit();
        std::vector<Ball> bs = {mk(0, V2{0, -.7} - dir * .2), mk(1, {0, -.7})};
        const Track t = play(app, bs, 1, std::atan2(dir.y, dir.x), sp[v], 0, 0); b1[v] = t.out.empty() ? NAN : fromNormal(t.out[0], true); }
    bench("B1a", "bank 1 rail, soft: object ball mirrors (deg, in 45)", b1[0], 40, 50, "[BJ]");
    bench("B1b", "bank 1 rail: hard banks go short (soft - hard, deg)", b1[0] - b1[2], 2, 20, "[BJ] hard banks go short");
    bench("B1c", "bank 1 rail: medium between soft and hard", (b1[1] - b1[2]) * (b1[0] - b1[1]) > 0 ? 1 : 0, 1, 1, "[BJ]");
    // cut-induced spin on the object ball changes the bank: cutting it gives it spin -> rebound shifts (>0.5 deg)
    { const V2 dir = V2{1, 1}.unit(); const double cut = 25 * pi / 180;
      const V2 ob{0, -.7}, ghost = ob - V2{dir.x * std::cos(cut) - dir.y * std::sin(cut), dir.x * std::sin(cut) + dir.y * std::cos(cut)} * (2 * R);
      const V2 aim = (ghost - (ghost - V2{0.15, .15})).unit(); (void)aim;
      const V2 cueStart = ghost - dir * .25; const V2 to = (ghost - cueStart).unit();
      const Track cutBank = play(app, {mk(0, cueStart), mk(1, ob)}, 1, std::atan2(to.y, to.x), 3, 0, 0);
      bench("B1d", "bank 1 rail cut 25 deg: object ball still banks (rails)", double(cutBank.out.size()), 1, 10, "[TP cut-induced spin]"); }
    // ---------------- BANK 2-4 rails: object ball keeps going around the table ----------------
    for (int nr = 2; nr <= 4; ++nr) { const V2 dir = V2{1, 1.6}.unit();
        const Track t = play(app, {mk(0, V2{-.3, -.9} - dir * .2), mk(1, {-.3, -.9})}, 1, std::atan2(dir.y, dir.x), 2 + 1.2 * nr, 0, 0);
        char id[8], what[96]; std::snprintf(id, 8, "B%da", nr); std::snprintf(what, 96, "bank %d rails: object ball reaches %d rails at %.1f m/s", nr, nr, 2 + 1.2 * nr);
        bench(id, what, double(t.out.size()), nr, 20, "[BJ]"); }

    // ---------------- MASSÉ: final direction = Coriolis 5/7 v0 - 2/7 R perp(w0); curve side follows english ----------------
    for (double el : {30.0, 60.0, 75.0}) for (double s : {-.4, .4}) {
        Config c = app; c.cueElevationDegrees = el; c.experimental3D = true; c.masseCoupledContact = el >= 60; c.squirtEnabled = false;
        World w(c); w.balls = {mk(0, {0, -.8})}; w.strike(pi / 2, 2, s, -.2);
        for (int i = 0; i < 960 * 2 && (w.balls[0].height > 1e-6 || std::abs(w.balls[0].vertical) > 1e-6); ++i) w.step();
        const Ball b = w.balls[0]; const V2 pred = b.v * (5.0 / 7) - b.w.perp() * (2.0 / 7 * R);
        for (int i = 0; i < 960 * 3; ++i) { w.step(); if ((w.balls[0].v + w.balls[0].w.perp() * R).length() < 2e-3) break; }
        char id[8], what[96]; std::snprintf(id, 8, "M%02.0f%c", el, s < 0 ? 'L' : 'R');
        std::snprintf(what, 96, "massé %.0f deg %s english: final direction error vs Coriolis (deg)", el, s < 0 ? "left" : "right");
        double err = std::abs(deg(w.balls[0].v) - deg(pred)); if (err > 180) err = 360 - err;
        bench(id, what, err, 0, 1.5, "[CO]");
    }
    { // curve grows with elevation and follows the english side
        auto bend = [&](double el, double s) { Config c = app; c.cueElevationDegrees = el; c.experimental3D = true; c.masseCoupledContact = el >= 60;
            const Track t = play(c, {mk(0, {0, -.8})}, 0, pi / 2, 2, s, -.2, el, 3); return deg(t.end.p - V2{0, -.8}) - 90; };
        const double l30 = bend(30, -.4), l75 = bend(75, -.4), r75 = bend(75, .4);
        bench("M-a", "massé: more elevation curves more (|75| - |30|, deg)", std::abs(l75) - std::abs(l30), 5, 120, "[TP massé]");
        bench("M-b", "massé: left and right english curve opposite ways", l75 * r75 < 0 ? 1 : 0, 1, 1, "[TP massé]"); }

    // ---------------- JUMP ----------------
    { Config c = app; c.cueType = 1;
      const Track lvl = play(c, {mk(0, {0, -.8})}, 0, pi / 2, 5, 0, 0, 0, 2);
      bench("J1", "jump cue level: no jump (mm)", lvl.maxH * 1000, 0, 1, "[TP jump: needs elevation]");
      const Track j = play(c, {mk(0, {0, -.8})}, 0, pi / 2, 4, 0, 0, 45, 2);
      bench("J2", "jump cue 45 deg, 4 m/s: clears a ball (height mm >= 2R)", j.maxH * 1000, 57, 400, "[TP jump]");
      // jump over a blocker 0.25 m ahead to an object ball 0.6 m ahead
      const Track over = play(c, {mk(0, {0, -.8}), mk(2, {0, -.55}), mk(1, {0, -.2})}, 2, pi / 2, 4, 0, 0, 45, 3);
      bench("J3", "jump over a blocker 25 cm away: blocker not touched (m/s)", over.end.v.length(), 0, .02, "[TP jump]");
      // airborne cue ball lands on the object ball above its equator -> object ball hops (cue ball acts as a jump cue)
      Config cj = c; World w([&] { Config x = cj; x.cueElevationDegrees = 45; x.experimental3D = true; x.squirtEnabled = false; return x; }());
      w.balls = {mk(0, {0, -.8}), mk(1, {0, -.26})}; w.strike(pi / 2, 4, 0, 0); double hop = 0;
      for (int i = 0; i < 960 * 2; ++i) { w.step(); hop = std::max(hop, w.balls[1].height); }
      bench("J4", "airborne cue ball hits object ball high: object ball hops (mm)", hop * 1000, 3, 200, "[TP HSV ball-on-ball jump]"); }

    // ---------------- TRICK SHOTS / SPIN EFFECTS ----------------
    // frozen combination: front ball thrown 2-7 deg toward the back ball's direction [TP frozen-ball throw]
    for (double cut : {15.0, 30.0, 45.0}) {
        const double cr = cut * pi / 180; const V2 n{std::sin(cr), std::cos(cr)}, ghost = V2{0, 0} - n * (2 * R);
        Config c = app; c.width = 10; c.length = 10; c.squirtEnabled = false;
        World w(c); w.balls = {mk(0, ghost - n * .4), mk(1, {0, 0}), mk(2, {0, 2 * R})};
        w.strike(std::atan2(n.y, n.x), 1.5, 0, 0); for (int i = 0; i < 700; ++i) w.step();
        char id[8], what[96]; std::snprintf(id, 8, "T-c%02.0f", cut); std::snprintf(what, 96, "frozen combo, back ball pushed %.0f deg: front ball throw (deg)", cut);
        bench(id, what, 90 - deg(w.balls[2].v), 1, 7, "[TP frozen-ball throw]");
    }
    // gear (spin transfer): reverse english turns the object ball's spin, running keeps it [TP A.14 / RailEnglishTests]
    for (int s = 1; s < 3; ++s) {
        Config c = app; c.width = 40; c.length = 40; c.squirtEnabled = false; World w(c);
        const double cut = 20 * pi / 180; const V2 ob{0, -.3}, ghost{ob.x + 2 * R * std::sin(cut), ob.y - 2 * R * std::cos(cut)}; const V2 cue{0, -.6}, d = (ghost - cue).unit();
        w.balls = {mk(0, cue), mk(1, ob)}; w.strike(std::atan2(d.y, d.x), 3, side[s] * 2, 0);
        Config c0 = c; World w0(c0); w0.balls = w.balls; (void)w0;
        double spin = 0; for (int i = 0; i < 960 && spin == 0; ++i) { w.step(); for (const auto& e : w.events) if (e.kind == 1) spin = w.balls[1].spin; }
        World n0(c); n0.balls = {mk(0, cue), mk(1, ob)}; n0.strike(std::atan2(d.y, d.x), 3, 0, 0); double none = 0;
        for (int i = 0; i < 960 && none == 0; ++i) { n0.step(); for (const auto& e : n0.events) if (e.kind == 1) none = n0.balls[1].spin; }
        bench(s == 1 ? "T-g1" : "T-g2", s == 1 ? "gear: running english keeps object-ball spin sign" : "gear: reverse english flips object-ball spin sign",
              s == 1 ? (spin * none > 0 ? 1 : 0) : (spin * none < 0 ? 1 : 0), 1, 1, "[TP A.14 gearing]");
    }
    // swerve: slightly raised cue (15 deg) with english curves the cue ball (no squirt here) [TP swerve]
    { const Track l = play(app, {mk(0, {0, -1})}, 0, pi / 2, 2, -.4, 0, 15, 3), r = play(app, {mk(0, {0, -1})}, 0, pi / 2, 2, .4, 0, 15, 3);
      bench("T-sw", "swerve 15 deg: left/right english curve opposite ways", (l.end.p.x) * (r.end.p.x) < 0 ? 1 : 0, 1, 1, "[TP swerve]"); }
    // stun-run-through vs drag draw: draw slows down then still comes back (cloth)
    { const Track d = play(app, {mk(0, {0, -1}), mk(1, {0, -.2})}, 0, pi / 2, 4, 0, -.5);
      bench("T-dd", "drag draw over 0.8 m at 4 m/s: cue ball still comes back (m)", -.2 - 2 * R - d.end.p.y, .05, 3, "[TP draw]"); }

    std::printf("%d/%d system benchmarks pass\n", total - failures, total);
    return failures ? 1 : 0;
}
