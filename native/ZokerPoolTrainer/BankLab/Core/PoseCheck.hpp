#pragma once
// 0.59 bộ 5 thế — rating one layout of a drill with the app's judge (BLDrillJudge via drillShot) and the checker's
// player error (DrillErrors). Used by Tools/drills/pose_pick (picks the set offline) and Tests/Mastery059Tests.cpp
// (re-proves the stored set). Same function both ways, so the stored numbers are reproduced exactly.
#include "DrillCheck.hpp"
extern "C" {
#include "../UI/Mastery059.h"
}
#include <algorithm>
#include <vector>

namespace banklab {

struct PoseStroke { double speed = 0, top = 0, aim = 0; int percent = 0; };

/// Make rate (%) of one stroke on layout L: the made aim with the widest window within ±1.6° of `aim` (0.2° probes),
/// then `samples` shots with the player's error. 0 when nothing in the band is made.
inline PoseStroke poseRateStroke(const BLDrillSpec& d, const BLDrillLayout& L, double aim, double speed, double top, int samples = 100) {
    PoseStroke out; out.speed = speed; out.top = top; out.aim = aim;
    double best = -1; long shots = 0;
    for (int k = -8; k <= 8; ++k) {
        const double a = aim + k * 0.2 * pi / 180;
        if (!drillShot(d, L, a, speed, 0, top)) continue;
        const double w = drillWindow(d, L, a, DrillStroke{speed, top}, 0.8, shots);
        if (w > best) { best = w; out.aim = a; }
    }
    if (best < 0) return out;
    out.percent = int(std::lround(drillMakeRate(d, L, out.aim, speed, top, samples) * 100));
    return out;
}

/// Best stroke near the reference one: pace ×0.85…1.3 and tip ref, ref ± 0.2 (the pose moved the cue ball, so the
/// pace and tip that reach the target change with it). Aim starts at the reference aim turned with the pose.
inline PoseStroke poseBestStroke(const BLDrillSpec& d, const BLDrillLayout& L, double aim) {
    PoseStroke best;
    for (double ks : {1.0, 0.85, 1.15, 1.3, 0.7})
        for (double dt : {0.0, -0.2, 0.2}) {
            const double top = std::clamp(d.solveTop + dt, -0.6, 0.6);
            const PoseStroke s = poseRateStroke(d, L, aim, d.solveSpeed * ks, top, 80);
            if (s.percent > best.percent) best = s;
        }
    if (best.percent > 0) best = poseRateStroke(d, L, best.aim, best.speed, best.top, 200);   // final rating: 200 shots
    return best;
}

/// Reference aim for layout L: the catalogue solution turned by the angle the pose turned the aim line.
inline double poseReferenceAim(const BLDrillSpec& d, const BLDrillLayout& L) {
    BLDrillLayout base; BLDrillLayoutFor(&d, 0, &base);
    return d.solveAngle + std::remainder(L.angle - base.angle, 2 * pi);
}

}  // namespace banklab
