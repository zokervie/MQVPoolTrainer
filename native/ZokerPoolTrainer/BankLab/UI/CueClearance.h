#ifndef ZOKER_CUE_CLEARANCE_H
#define ZOKER_CUE_CLEARANCE_H

#include <stdbool.h>
#include <math.h>

// Cây cơ phải đi qua phía trên băng (mũi cao su và gờ gỗ) phía sau bi cái.
// Dùng chung cho UIKit (vẽ cơ, vùng effect khả thi) và test C++ (Tests/CueClearanceTests.cpp).
//
// Mô hình (giả thiết, ghi rõ để kiểm chứng trên bàn thật):
// - Tọa độ bàn: x ∈ ±width/2, y ∈ ±length/2 là đường mũi băng; hướng đánh d = (cos a, sin a).
// - Chướng ngại 1: mũi băng ở khoảng cách ngang L (từ tâm bi, ngược hướng đánh), cao R·(1+nose).
// - Chướng ngại 2: gờ gỗ sau mũi băng 0,05 m, cao hơn mũi băng 0,008 m.            [giả định]
// - Cơ là đường thẳng qua điểm chạm, bán kính đầu cơ 6,5 mm; nghiêng θ so với mặt bàn. [đầu cơ 13 mm: đã công bố]
// - Điểm chạm trên mặt bi: lùi R·√(1−s²−t²) so với tâm theo phương ngang, cao R·(1+t).
// - Bỏ qua miệng lỗ (bảo thủ: coi như có băng).
// Kết quả: góc nghiêng tối thiểu để mép dưới cơ không chạm băng; điểm chạm khả thi khi góc đó ≤ góc tối đa.

#define BL_CUE_TIP_RADIUS 0.0065
#define BL_RAIL_WOOD_SETBACK 0.05
#define BL_RAIL_WOOD_RISE 0.008

static inline double BLCueRailDistance(double x, double y, double angle,
                                       double width, double length) {
    const double dx = -cos(angle), dy = -sin(angle);
    double best = INFINITY;
    if (dx > 1e-12) best = fmin(best, (width / 2 - x) / dx);
    if (dx < -1e-12) best = fmin(best, (-width / 2 - x) / dx);
    if (dy > 1e-12) best = fmin(best, (length / 2 - y) / dy);
    if (dy < -1e-12) best = fmin(best, (-length / 2 - y) / dy);
    return fmax(0, best);
}

// Mép dưới của cơ tại khoảng cách ngang d (tính từ điểm chạm) với góc θ (rad). 0.37: bán kính thân cơ to dần theo d.
static inline double BLCueShaftRadius(double d) { return 0.0065 + 0.0035 * fmin(1.0, fmax(0.0, d) / 0.7); }
static inline double BLCueUnderside(double contactHeight, double d, double theta) {
    return contactHeight + d * tan(theta) - BLCueShaftRadius(d) / cos(theta);
}

// 0.37 (owner screenshot: cue through the rail): the obstacle is the RENDERED rail, not two guessed points.
// (setback behind the nose line, height above the bed) for a 57.15 mm ball — the cushion profile in
// TableScene.cushionPath and the deck (top 40 mm since 0.58, was 56; generate_table_mesh.py RAIL_TOP) out to the outer edge 172 mm back.
// Heights scale with the ball radius. First point is replaced by the actual nose height R(1+nose).
#define BL_RAIL_PROFILE_COUNT 8
static const double BLRailProfile[BL_RAIL_PROFILE_COUNT][2] = {
    {0.0, 0.03629025}, {0.006, 0.0375}, {0.014, 0.0385}, {0.030, 0.0390},
    {0.050, 0.0398}, {0.053, 0.0400}, {0.110, 0.0400}, {0.1725, 0.0400}};

static inline int BLCueClearsRail(double contactHeight, double d1, double radius, double noseRatio, double theta) {
    const double k = radius / 0.028575;
    for (int i = 0; i < BL_RAIL_PROFILE_COUNT; ++i) {
        const double h = i == 0 ? radius * (1.0 + noseRatio) : BLRailProfile[i][1] * k;
        if (BLCueUnderside(contactHeight, d1 + BLRailProfile[i][0] * k, theta) < h) return 0;
    }
    return 1;
}

// Góc nghiêng tối thiểu (độ) để cơ qua được băng; 0 khi bi ở xa băng.
static inline double BLCueMinimumElevation(double x, double y, double angle,
                                           double side, double top,
                                           double width, double length,
                                           double radius, double noseRatio) {
    if (!isfinite(x) || !isfinite(y) || !isfinite(angle) || radius <= 0) return 0;
    const double s2 = fmin(1.0, side * side + top * top);
    const double back = radius * sqrt(fmax(0.0, 1.0 - s2));
    const double contactHeight = radius * (1.0 + top);
    const double rail = BLCueRailDistance(x, y, angle, width, length);
    // Khe tối thiểu 1,5 mm giữa điểm chạm và mũi băng (đầu cơ không lách được xuống dưới mũi băng).
    const double d1 = fmax(0.0015, rail - back);
    if (BLCueClearsRail(contactHeight, d1, radius, noseRatio, 0)) return 0;
    // Not monotone near vertical (the shaft's horizontal section r/cos θ grows): scan up, then refine.
    double lo = 0, hi = -1;
    for (int k = 1; k <= 340; ++k) {
        const double th = k * 0.25 * M_PI / 180;
        if (BLCueClearsRail(contactHeight, d1, radius, noseRatio, th)) { hi = th; break; }
        lo = th;
    }
    if (hi < 0) return 90;
    for (int i = 0; i < 40; ++i) {
        const double mid = (lo + hi) / 2;
        if (BLCueClearsRail(contactHeight, d1, radius, noseRatio, mid)) hi = mid;
        else lo = mid;
    }
    return hi * 180 / M_PI;
}

// 0.44 (owner item 14: "ở ngoài anh vẫn có góc song song với bàn"). A cue is a straight line, so with the cue ball 30–60 cm
// from a rail a mathematically level cue would still have to pass over the rail behind (≈ 3–7°). A player does exactly
// that with the normal stance — rear hand a little higher than the bridge — and calls it "level"; published squirt /
// swerve figures are measured in that stance. So up to BL_CUE_STANCE_DEG of rail clearance is the stance itself: it is
// DRAWN (the cue never passes through the rail) but the stroke stays a level stroke. Above it the stroke really is
// elevated (bridge on the rail, ball near the cushion, low tip) and the fan/solver use the full angle.  [giả định: 6°]
#define BL_CUE_STANCE_DEG 6.0
static inline double BLCueStrokeElevation(double clearanceDeg) {
    return (isfinite(clearanceDeg) && clearanceDeg > BL_CUE_STANCE_DEG) ? clearanceDeg : 0.0;
}

static inline bool BLCueReachable(double x, double y, double angle, double side, double top,
                                  double width, double length, double radius, double noseRatio,
                                  double maxElevationDeg) {
    return BLCueMinimumElevation(x, y, angle, side, top, width, length, radius, noseRatio) <= maxElevationDeg + 1e-9;
}

// Khi điểm chạm không với tới: giữ ngang (side), nâng dần lên cao (như ngoài đời: chỉ đánh được phần trên bi).
// Trả về top mới; nếu cả điểm cao nhất cũng không với tới thì trả về điểm cao nhất (mép vùng effect).
static inline double BLCueClampTop(double x, double y, double angle, double side, double top,
                                   double width, double length, double radius, double noseRatio,
                                   double maxElevationDeg, double maxOffset) {
    if (BLCueReachable(x, y, angle, side, top, width, length, radius, noseRatio, maxElevationDeg)) return top;
    const double ceiling = sqrt(fmax(0.0, maxOffset * maxOffset - side * side));
    if (!BLCueReachable(x, y, angle, side, ceiling, width, length, radius, noseRatio, maxElevationDeg)) return ceiling;
    double lo = top, hi = ceiling;
    for (int i = 0; i < 50; ++i) {
        const double mid = (lo + hi) / 2;
        if (BLCueReachable(x, y, angle, side, mid, width, length, radius, noseRatio, maxElevationDeg)) hi = mid;
        else lo = mid;
    }
    return hi;
}

// ---- 0.30: other balls behind the cue ball (owner: "côn bi" — never draw the cue through a ball) ----
// Each obstacle ball j is cut by the vertical plane of the cue line at lateral offset e' = max(0, |e| - r_cue):
// a circle of radius rho = sqrt(R^2 - e'^2) centred at height R, along-distance a_j behind the cue-ball centre.
// The underside line z(d) = h_c + d tan(theta) - r_cue / cos(theta) must pass above it:
//   z(a_j - back) >= R + rho / cos(theta)   (line-circle distance, exact in that plane).
// Shaft radius grows from the tip 6.5 mm to 10 mm at 0.7 m [assumed, typical taper]; cue length 1.45 m.
#define BL_CUE_LENGTH 1.45
static inline double BLCueRadiusAt(double d) { return BLCueShaftRadius(d); }

static inline int BLCueClearsBall(double contactHeight, double back, double along, double lateral, double radius, double theta) {
    const double d = along - back;
    const double rc = BLCueRadiusAt(d);
    const double e = fmax(0.0, fabs(lateral) - rc);
    if (e >= radius) return 1;
    const double rho = sqrt(radius * radius - e * e);
    const double z = contactHeight + d * tan(theta) - rc / cos(theta);
    return z >= radius + rho / cos(theta);
}

static inline double BLCueMinimumElevationBalls(double x, double y, double angle, double side, double top,
                                                double width, double length, double radius, double noseRatio,
                                                const double *bx, const double *by, int n) {
    double best = BLCueMinimumElevation(x, y, angle, side, top, width, length, radius, noseRatio);
    if (!bx || !by || n <= 0 || !isfinite(x) || !isfinite(y) || !isfinite(angle) || radius <= 0) return best;
    const double s2 = fmin(1.0, side * side + top * top);
    const double back = radius * sqrt(fmax(0.0, 1.0 - s2)), contactHeight = radius * (1.0 + top);
    const double dx = -cos(angle), dy = -sin(angle);   // towards the butt
    for (int j = 0; j < n; ++j) {
        const double rx = bx[j] - x, ry = by[j] - y;
        const double along = rx * dx + ry * dy, lateral = -rx * dy + ry * dx;
        if (along <= 0 || along > BL_CUE_LENGTH + radius) continue;
        if (fabs(lateral) >= radius + BLCueRadiusAt(along)) continue;
        if (BLCueClearsBall(contactHeight, back, along, lateral, radius, 0)) continue;
        double lo = 0, hi = 89.5 * M_PI / 180;
        if (!BLCueClearsBall(contactHeight, back, along, lateral, radius, hi)) return 90;
        for (int i = 0; i < 60; ++i) { const double mid = (lo + hi) / 2; if (BLCueClearsBall(contactHeight, back, along, lateral, radius, mid)) hi = mid; else lo = mid; }
        best = fmax(best, hi * 180 / M_PI);
    }
    return best;
}

// Same as BLCueClampTop, with the balls behind the cue ball as obstacles too.
static inline double BLCueClampTopBalls(double x, double y, double angle, double side, double top,
                                        double width, double length, double radius, double noseRatio,
                                        double maxElevationDeg, double maxOffset, const double *bx, const double *by, int n) {
#define BL_REACH(t) (BLCueMinimumElevationBalls(x, y, angle, side, (t), width, length, radius, noseRatio, bx, by, n) <= maxElevationDeg + 1e-9)
    if (BL_REACH(top)) return top;
    const double ceiling = sqrt(fmax(0.0, maxOffset * maxOffset - side * side));
    if (!BL_REACH(ceiling)) return ceiling;
    double lo = top, hi = ceiling;
    for (int i = 0; i < 50; ++i) { const double mid = (lo + hi) / 2; if (BL_REACH(mid)) hi = mid; else lo = mid; }
    return hi;
#undef BL_REACH
}

// ---- 0.58 "cơ trên băng" (owner 23/11, screenshots at 85° and 45°): near a rail a player keeps the cue as low as the
// rail allows and hits HIGHER on the cue ball; the cue is raised only when the player chooses to. The old behaviour
// kept the chosen tip point and raised the cue up to the 45° stroke limit. Policy:
//   floor = the lowest elevation that reaches ANY tip point on the requested side (scan up to the miscue ceiling),
//   cap   = max(player's own elevation, floor + BL_RAIL_BRIDGE_MARGIN_DEG, BL_RAIL_BRIDGE_COMFORT_DEG),
//   tip   = the requested tip if reachable under cap, else moved straight up to the first point that is.
// So the cue sits on the rail at the lowest workable angle; dragging the elevation fan up lets the tip go lower.
// Up to BL_RAIL_BRIDGE_COMFORT_DEG the chosen tip is kept (a bridge on the rail at ≤ 15° is an ordinary stroke), so shots
// 10 cm or more from a rail do not change. Not a physics change: the stroke uses the resulting (tip, elevation) as before.
//                                                     [quyết định chủ dự án; lề 2°, ngưỡng 15°: giả định]
#define BL_RAIL_BRIDGE_MARGIN_DEG 2.0
#define BL_RAIL_BRIDGE_COMFORT_DEG 15.0
typedef struct { double top; double elevation; double floorDeg; int moved; } BLCueRailBridge;
static inline BLCueRailBridge BLCueRailBridgeSolve(double x, double y, double angle, double side, double top,
                                                   double playerElevationDeg, double maxElevationDeg, double maxOffset,
                                                   double width, double length, double radius, double noseRatio,
                                                   const double *bx, const double *by, int n) {
    BLCueRailBridge r; r.top = top; r.moved = 0;
#define BL_E(t) BLCueMinimumElevationBalls(x, y, angle, side, (t), width, length, radius, noseRatio, bx, by, n)
    const double ceiling = sqrt(fmax(0.0, maxOffset * maxOffset - side * side));
    double floorDeg = BL_E(top);
    for (int k = 0; k <= 40; ++k) { const double t = top + (ceiling - top) * k / 40.0; floorDeg = fmin(floorDeg, BL_E(t)); }
    r.floorDeg = floorDeg;
    double cap = fmax(fmax(playerElevationDeg, floorDeg + BL_RAIL_BRIDGE_MARGIN_DEG), BL_RAIL_BRIDGE_COMFORT_DEG);
    cap = fmin(cap, fmax(maxElevationDeg, floorDeg));
    if (BL_E(top) > cap + 1e-9) {
        double lo = top, hi = ceiling;
        if (BL_E(hi) > cap + 1e-9) {   /* the ceiling itself is not the cheapest point (a ball behind): take the first reachable */
            for (int k = 1; k <= 40; ++k) { const double t = top + (ceiling - top) * k / 40.0; if (BL_E(t) <= cap + 1e-9) { hi = t; break; } }
        }
        for (int i = 0; i < 50; ++i) { const double mid = (lo + hi) / 2; if (BL_E(mid) <= cap + 1e-9) hi = mid; else lo = mid; }
        r.top = hi; r.moved = 1;
    }
    r.elevation = fmax(playerElevationDeg, BL_E(r.top));
#undef BL_E
    return r;
}

// 0.59 U3 (anh 25/11, IMG_7920: bi cái còn cách băng mà nửa dưới bi bị khoá). The geometry above is not the cause
// (Tests/CueClearanceTests.cpp, "U3" table: e.g. 10 cm off the rail a 0.55R draw needs ~16.5°, a stroke anyone can play);
// the lock came from the 0.58 bridge ceiling (BL_RAIL_BRIDGE_COMFORT_DEG = 15°) being used to grey out and clamp TOUCHED tips.
// Rule now: a tip the player touched is locked only when no stroke reaches it — it needs more than the stroke limit
// (maxElevationDeg) or it sits under the rail nose (90°). Up to that limit the cue rises to what the rail demands (the fan
// shows it). The 0.58 rule (move the tip up rather than raise the cue) stays for tips the app chose (reset, drill default).
static inline double BLCueBridgeFan(double fanDeg, double neededDeg, double maxElevationDeg, int explicitPick) {
    return (explicitPick && isfinite(neededDeg) && neededDeg <= maxElevationDeg + 1e-9) ? fmax(fanDeg, neededDeg) : fanDeg;
}
// The pad's lock: only what no stroke can reach.
static inline int BLCueTipLocked(double neededDeg, double maxElevationDeg) {
    return !(isfinite(neededDeg) && neededDeg <= maxElevationDeg + 1e-9);
}

#endif
