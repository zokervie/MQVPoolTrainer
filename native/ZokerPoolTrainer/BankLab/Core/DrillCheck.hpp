#pragma once
// 0.49b "Xưởng bài" — máy chấm bài tập. Đọc một bài trong BankLab/UI/DrillCatalog.h, chấm một cú giống hệt app
// (BLDrillJudge trong DrillCatalog.h, cùng hàm mà TC+ShotLoop.swift gọi), và quét cú đánh trên vật lý của app
// (Config::app) để biết bài có lời giải không và khó tới đâu.
//
// Độ khó đo thật: tìm "lời giải mẫu" (hướng, lực, điểm chạm) rồi đánh lại cú đó 200 lần với sai số của một người chơi
// (DrillErrors); tỉ lệ vào = makePercent, sao = BLDrillStarsFromMakeRate. Đo trên MÔ PHỎNG: sai số người là GIẢ ĐỊNH,
// chỉnh lại bằng tỉ lệ đạt thật khi có TestFlight.
#include "Physics.hpp"
#include "../UI/DrillCatalog.h"
#include "../UI/DailyLoop.h"
#include <algorithm>
#include <cmath>
#include <vector>

namespace banklab {

inline std::vector<Ball> drillBalls(const BLDrillSpec& d, const BLDrillLayout& L) {
    std::vector<Ball> v;
    for (int k = 0; k < d.ballCount; ++k) { Ball b; b.id = d.balls[k].id; b.p = {L.x[k], L.y[k]}; v.push_back(b); }
    return v;
}

/// True once the shot can no longer count (lets the sweep stop early; never changes a verdict).
inline bool drillHopeless(const BLDrillSpec& d, const std::vector<Event>& ev, size_t from, int& cueRails, int& objRails,
                          bool& contact) {
    for (size_t i = from; i < ev.size(); ++i) {
        const Event& e = ev[i];
        if (e.kind == 2 && e.a == 0) return true;   // scratch
        if (d.kind == BL_DRILL_KICK) {
            if (e.kind == 0 && e.a == 0 && !contact && ++cueRails > d.rails) return true;
            if (e.kind == 1 && (e.a == 0 || e.b == 0) && !contact) {
                contact = true;
                if ((e.a == 0 ? e.b : e.a) != 1 || cueRails != d.rails) return true;
            }
        } else if (d.kind == BL_DRILL_BANK) {
            if (e.kind == 0 && e.a == 1 && ++objRails > d.rails) return true;
            if (e.kind == 2 && e.a == 1 && (objRails != d.rails || e.b < 0)) return true;
        } else if (d.kind == BL_DRILL_SAFETY) {
            if (e.kind == 2) return true;
            if (e.kind == 1 && (e.a == 0 || e.b == 0) && !contact) { contact = true; if ((e.a == 0 ? e.b : e.a) != 1) return true; }
        } else if (e.kind == 2 && e.a == 1 && e.b < 0) {
            return true;
        }
    }
    return false;
}

/// Plays one shot and judges it exactly like the app (BLDrillJudge).
inline bool drillShot(const BLDrillSpec& d, const BLDrillLayout& L, double angle, double speed, double side, double top,
                      double seconds = 14) {
    World w(Config::app());
    w.reset(drillBalls(d, L));
    w.strike(angle, speed, side, top);
    int cueRails = 0, objRails = 0; bool contact = false; size_t seen = 0;
    for (int n = 0; n < int(seconds / World::stepSize) && w.moving(); ++n) {
        w.step();
        if (w.events.size() != seen) { if (drillHopeless(d, w.events, seen, cueRails, objRails, contact)) return false; seen = w.events.size(); }
    }
    if (w.moving()) return false;   // the app never counts a shot that has not stopped
    std::vector<int32_t> kind, a, b;
    for (const auto& e : w.events) { kind.push_back(e.kind); a.push_back(e.a); b.push_back(e.b); }
    std::vector<int32_t> ids, sunk; std::vector<double> xs, ys;
    for (const auto& ball : w.balls) { ids.push_back(ball.id); xs.push_back(ball.p.x); ys.push_back(ball.p.y); sunk.push_back(ball.sunk); }
    return BLDrillJudge(&d, &L, int32_t(kind.size()), kind.data(), a.data(), b.data(),
                        int32_t(ids.size()), ids.data(), xs.data(), ys.data(), sunk.data()) != 0;
}

struct DrillStroke { double speed, top; };
struct DrillSweep {
    bool solvable = false;
    double angle = 0, speed = 0, top = 0;   // best stroke found
    double windowDeg = 0;                   // half-width of the contiguous aim window at that stroke
    double makeRate = 0;                    // share made under DrillErrors at that stroke
    int stars = 5;
    long shots = 0;
};

/// Strokes swept (speed m/s at a centre hit; tip as a fraction of R). Rail drills: fewer, the window is set by the aim.
inline std::vector<DrillStroke> drillStrokes(const BLDrillSpec& d) {
    std::vector<DrillStroke> v;
    if (d.kind == BL_DRILL_BANK) {   // banks: narrow windows that move with pace (bank3 only shows up at 2.8–3.4 m/s)
        for (double s : {1.4, 2.2, 2.8, 3.4, 4.2}) for (double t : {-0.2, 0.0, 0.3}) v.push_back({s, t});
    } else if (d.kind == BL_DRILL_KICK || d.scanDegrees > 90) {
        for (double s : {1.4, 2.4, 3.6}) for (double t : {0.0, 0.3}) v.push_back({s, t});
    } else {
        for (double s : {0.5, 0.75, 1.0, 1.3, 1.7, 2.2, 2.8, 3.5, 4.3}) for (double t : {-0.55, -0.3, -0.1, 0.1, 0.3, 0.5}) v.push_back({s, t});
    }
    return v;
}

/// Half-width (degrees) of the contiguous made window around `angle`, probing 0.1° steps up to `limitDeg`.
inline double drillWindow(const BLDrillSpec& d, const BLDrillLayout& L, double angle, DrillStroke s, double limitDeg, long& shots) {
    auto ok = [&](double deg) { ++shots; return drillShot(d, L, angle + deg * pi / 180, s.speed, 0, s.top); };
    if (!ok(0)) return 0;
    double lo = 0, hi = 0;
    while (hi + 0.1 <= limitDeg + 1e-9 && ok(hi + 0.1)) hi += 0.1;
    while (lo + 0.1 <= limitDeg + 1e-9 && ok(-(lo + 0.1))) lo += 0.1;
    return (lo + hi) / 2 + 0.05;   // half the window's width (+ half a probe step)
}

// ── Make rate under a player's error ─────────────────────────────────────────────────────────────────────────
// The aim window alone calls a stop shot "hard" and a 3-rail kick "easy": it ignores speed and tip. Difficulty is
// instead the share of shots made when a player repeats the reference stroke with typical errors. Error model
// (GIẢ ĐỊNH: a club player with a repeatable stroke — the level a finished chapter should reach; re-fit on
// TestFlight made rates): aim σ 0.3° · speed σ 6 % · tip height σ 0.06 R · side σ 0.03 R (unintended english).
// A kick or a bank has no line to look at: the aim point is estimated (diamond system, mirror), so its aim σ grows
// with the rails: 0.6° + 0.3° per rail (kick 1 rail 0.9°, kick 3 rails 1.5°). Also GIẢ ĐỊNH.
// Deterministic: own generator (std::normal_distribution differs between libstdc++ and libc++).
struct DrillErrors { double aimDeg = 0.3, speedRel = 0.06, tip = 0.06, side = 0.03; };
inline DrillErrors drillErrors(const BLDrillSpec& d) {
    DrillErrors e;
    if (d.kind == BL_DRILL_KICK || d.kind == BL_DRILL_BANK) e.aimDeg = 0.6 + 0.3 * d.rails;
    return e;
}
struct DrillRng {
    uint64_t s;
    explicit DrillRng(uint64_t seed) : s(seed * 6364136223846793005ULL + 1442695040888963407ULL) {}
    double uniform() { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return ((s >> 11) + 0.5) / 9007199254740992.0; }
    double normal() { const double u = uniform(), v = uniform(); return std::sqrt(-2 * std::log(u)) * std::cos(2 * pi * v); }
};
/// Made share (0…1) over `samples` shots of the stroke (angle, speed, top) with DrillErrors.
inline double drillMakeRate(const BLDrillSpec& d, const BLDrillLayout& L, double angle, double speed, double top,
                            int samples = 200, uint64_t seed = 1) {
    const DrillErrors e = drillErrors(d);
    DrillRng rng(seed ^ BLDrillHash(d.key, 0));
    int made = 0;
    for (int i = 0; i < samples; ++i) {
        const double a = angle + rng.normal() * e.aimDeg * pi / 180;
        const double v = std::max(0.2, speed * (1 + rng.normal() * e.speedRel));
        const double t = std::clamp(top + rng.normal() * e.tip, -0.6, 0.6);
        const double sd = std::clamp(rng.normal() * e.side, -0.3, 0.3);
        if (drillShot(d, L, a, v, sd, t)) ++made;
    }
    return double(made) / samples;
}

/// Sweep: coarse aim scan around the layout's default aim (±scanDegrees) for every stroke; then the made runs.
struct DrillCandidate { double angle; DrillStroke s; int length; };
inline std::vector<DrillCandidate> drillCandidates(const BLDrillSpec& d, const BLDrillLayout& L, double around, double half,
                                                  const std::vector<DrillStroke>& strokes, long& shots) {
    const double step = half > 90 ? 0.5 : 0.2;
    std::vector<DrillCandidate> runs;
    for (DrillStroke s : strokes) {
        int length = 0; double first = 0;
        const int n = int(std::lround(2 * half / step));
        for (int i = 0; i <= n + 1; ++i) {
            const double deg = -half + i * step;
            const bool made = i <= n && (++shots, drillShot(d, L, around + deg * pi / 180, s.speed, 0, s.top));
            if (made) { if (!length) first = deg; ++length; }
            else if (length) { runs.push_back({around + (first + (length - 1) * step / 2) * pi / 180, s, length}); length = 0; }
        }
    }
    std::sort(runs.begin(), runs.end(), [](const DrillCandidate& x, const DrillCandidate& y) { return x.length > y.length; });
    return runs;
}

/// Full search (Tools/drill_sweep.cpp, minutes): best reference stroke = highest make rate among the 6 widest runs.
inline DrillSweep sweepDrill(const BLDrillSpec& d, const BLDrillLayout& L) {
    DrillSweep out;
    auto runs = drillCandidates(d, L, L.angle, d.scanDegrees, drillStrokes(d), out.shots);
    if (runs.empty()) return out;
    out.solvable = true;
    double best = -1;
    for (size_t i = 0; i < runs.size() && i < 6; ++i) {
        // centre the run precisely at 0.1° before rating it
        const double w = drillWindow(d, L, runs[i].angle, runs[i].s, 4.0, out.shots);
        if (w <= 0) continue;
        const double p = drillMakeRate(d, L, runs[i].angle, runs[i].s.speed, runs[i].s.top, 60);
        out.shots += 60;
        if (p > best) { best = p; out.angle = runs[i].angle; out.speed = runs[i].s.speed; out.top = runs[i].s.top; out.windowDeg = w; }
    }
    out.makeRate = drillMakeRate(d, L, out.angle, out.speed, out.top, 200);
    out.shots += 200;
    out.stars = BLDrillStarsFromMakeRate(int32_t(std::lround(out.makeRate * 100)));
    return out;
}

}  // namespace banklab
