#pragma once
// Diamond (kick) systems, evaluated with the app's own physics. Used by the drill system and Tests/KickSystemsTests.cpp.
//
// Numbering = pool "Diamond System" / corner-5 as taught by PoolDawg ("three rail kicking systems"):
//   - first rail (aim A): a long rail, counted from the corner the ball travels toward: 10 per diamond up to the side
//     pocket (40), then 10 per HALF diamond (50 = 4.5, 60 = 5 ... 90 = 6.5);
//   - departure D: where the cue line, extended backward, crosses the far rails: 50 at the corner, 5 per diamond along
//     the long rail (45, 40 ... 20), 10 per diamond down the short rail (60, 70, 80, 90);
//   - arrival T: the 3rd rail (the long rail opposite the first), counted like the first rail.
//   Rule: A = D - T, running english, medium speed (Alciatore TP 7.2 gives the same rule in diamonds: T = D - F).
// Positions are read "through the diamonds": diamond centres sit 3 11/16 in (93.6 mm) behind the cushion nose (WPA).
#include "Physics.hpp"
#include <cmath>
#include <vector>

namespace banklab::kick {

constexpr double diamondOffset = .0936;

inline double numberToDiamond(double n) { return n <= 40 ? n / 10 : 4 + (n - 40) / 20; }
inline double diamondToNumber(double u) { return u <= 4 ? u * 10 : 40 + (u - 4) * 20; }

// Table frame for the system: u along the long axis 0..8 (y = -L/2 .. +L/2), v across 0..4 (x = -W/2 first rail .. +W/2).
inline V2 point(const Config& c, double u, double v) { return {-c.width / 2 + v * c.width / 4, -c.length / 2 + u * c.length / 8}; }

struct Corner5Shot { V2 cue; double angle = 0; bool valid = false; };

// Cue ball on the system line from departure D through first-rail aim A, `fraction` of the way back from the rail.
inline Corner5Shot corner5Setup(const Config& c, double D, double A, double fraction = .45) {
    V2 pd = D <= 50 ? point(c, 8 - (50 - D) / 5, 4) : point(c, 8, 4 - (D - 50) / 10);
    if (D <= 50) pd.x += diamondOffset; else pd.y += diamondOffset;
    V2 pa = point(c, numberToDiamond(A), 0); pa.x -= diamondOffset;
    Corner5Shot s; s.cue = pa + (pd - pa).unit() * ((pd - pa).length() * fraction);
    const V2 d = (pa - s.cue).unit(); s.angle = std::atan2(d.y, d.x);
    s.valid = std::abs(s.cue.x) < c.width / 2 - .04 && std::abs(s.cue.y) < c.length / 2 - .04;
    return s;
}

// Running english for this geometry is side > 0 (contact slip on the first rail is v_y - w_z R; w_z = -2.5 side v / R).
// Returns the simulated arrival number T on the 3rd rail, or NAN if the ball does not go first rail -> ... -> 3rd rail.
inline double corner5Arrival(const Config& base, double D, double A, double speed, double runningEnglish) {
    Config c = base; const auto s = corner5Setup(c, D, A);
    if (!s.valid) return NAN;
    World w(c); Ball b; b.id = 0; b.p = s.cue; w.balls = {b};
    w.strike(s.angle, speed, runningEnglish, 0);
    std::vector<V2> rails; size_t seen = 0;
    for (int i = 0; i < 960 * 15 && w.moving() && rails.size() < 3; ++i) {
        w.step();
        for (; seen < w.events.size(); ++seen) if (w.events[seen].kind == 0) rails.push_back(w.events[seen].p);
    }
    if (rails.size() < 3 || rails[0].x > -c.width / 2 + .05 || rails[2].x < c.width / 2 - .05) return NAN;
    const V2 a = rails[1], b2 = rails[2];
    const double t = ((c.width / 2 + diamondOffset) - a.x) / (b2.x - a.x);
    const V2 hit = a + (b2 - a) * t;
    return diamondToNumber((hit.y + c.length / 2) / (c.length / 8));
}

struct SystemFit { int n = 0; double mean = 0, spread = 0; };

// Mean offset ("table plays long/short") and spread of (simulated T - (D - A)) over the standard chart.
inline SystemFit corner5Fit(const Config& c, double speed, double runningEnglish) {
    double s1 = 0, s2 = 0; int n = 0;
    for (double D : {50., 45., 40., 35., 60., 70.}) for (double T : {10., 20., 30.}) {
        const double A = D - T; if (A < 5 || A > 70) continue;
        const double sim = corner5Arrival(c, D, A, speed, runningEnglish);
        if (std::isnan(sim)) continue;
        s1 += sim - T; s2 += (sim - T) * (sim - T); ++n;
    }
    SystemFit f; f.n = n; if (n) { f.mean = s1 / n; f.spread = std::sqrt(std::max(0.0, s2 / n - f.mean * f.mean)); }
    return f;
}

// One-rail mirror kick: cue ball and target both `distance` diamonds from a long rail, `separation` diamonds apart,
// aimed at the geometric halfway point. Returns the miss along the rail (diamonds, + = long) where the ball crosses
// the target's distance line; NAN if it never does.
inline double mirrorMiss(const Config& c, double separation, double distance, double speed, double english) {
    const double dia = c.length / 8, inset = c.radius * std::sqrt(1 - c.railHeight * c.railHeight), xr = c.width / 2 - inset, y0 = -2 * dia;
    const V2 cb{xr - distance * dia, y0 - separation / 2 * dia}, tg{xr - distance * dia, y0 + separation / 2 * dia};
    const V2 d = (V2{xr, y0} - cb).unit();
    World w(c); Ball b; b.id = 0; b.p = cb; w.balls = {b};
    w.strike(std::atan2(d.y, d.x), speed, english, 0);   // english > 0 = running for this geometry
    bool hit = false; V2 prev = w.balls[0].p;
    for (int i = 0; i < 960 * 10 && w.moving(); ++i) {
        w.step(); const V2 p = w.balls[0].p; if (w.balls[0].rails > 0) hit = true;
        if (hit && prev.x >= tg.x && p.x < tg.x) { const double t = (tg.x - prev.x) / (p.x - prev.x); return (prev.y + (p.y - prev.y) * t - tg.y) / dia; }
        prev = p;
    }
    return NAN;
}

}  // namespace banklab::kick
