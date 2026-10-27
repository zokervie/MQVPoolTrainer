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

#endif
