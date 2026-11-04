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

// Mép dưới của cơ tại khoảng cách ngang d (tính từ điểm chạm) với góc θ (rad).
static inline double BLCueUnderside(double contactHeight, double d, double theta) {
    return contactHeight + d * tan(theta) - BL_CUE_TIP_RADIUS / cos(theta);
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
    const double d1 = fmax(0.0015, rail - back), d2 = d1 + BL_RAIL_WOOD_SETBACK;
    const double h1 = radius * (1.0 + noseRatio), h2 = h1 + BL_RAIL_WOOD_RISE;
    double lo = 0, hi = 89.5 * M_PI / 180;
    if (BLCueUnderside(contactHeight, d1, 0) >= h1 && BLCueUnderside(contactHeight, d2, 0) >= h2) return 0;
    for (int i = 0; i < 60; ++i) {
        const double mid = (lo + hi) / 2;
        if (BLCueUnderside(contactHeight, d1, mid) >= h1 && BLCueUnderside(contactHeight, d2, mid) >= h2) hi = mid;
        else lo = mid;
    }
    return hi * 180 / M_PI;
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
static inline double BLCueRadiusAt(double d) { return BL_CUE_TIP_RADIUS + 0.0035 * fmin(1.0, fmax(0.0, d) / 0.7); }

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

#endif
