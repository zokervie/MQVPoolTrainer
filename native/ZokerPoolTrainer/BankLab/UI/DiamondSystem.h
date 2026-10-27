#ifndef ZOKER_DIAMOND_SYSTEM_H
#define ZOKER_DIAMOND_SYSTEM_H

#include <math.h>

// Toạ độ nút kim cương (dùng chung UIKit + test C++ Tests/DiamondSystemTests.cpp).
// Quy ước: băng dài đánh số 0…8 từ băng ngắn y = −L/2 tới y = +L/2 (nút 4 = lỗ giữa);
// băng ngắn đánh số 0…4 từ x = −W/2 tới x = +W/2. Toạ độ tính trên đường mũi băng.
// Hệ gương: bi cái phản xạ như tia sáng trên đường biên tâm bi (mũi băng lùi vào một khoảng
// R·√(1−h²)). Đây là mốc hình học, KHÔNG tính ma sát băng, xoáy, tốc độ; vật lý app cho kết quả thật.

typedef enum { BLRailLeft = 0, BLRailRight = 1, BLRailFoot = 2, BLRailHead = 3 } BLRail;

static inline double BLDiamondAlongLong(double y, double length) { return (y + length / 2) / (length / 8); }
static inline double BLDiamondAlongShort(double x, double width) { return (x + width / 2) / (width / 4); }

// Băng gần nhất với tâm bi (dùng cho vị trí va băng do solver báo).
static inline BLRail BLNearestRail(double x, double y, double width, double length) {
    const double dl = x + width / 2, dr = width / 2 - x, df = y + length / 2, dh = length / 2 - y;
    double best = dl; BLRail rail = BLRailLeft;
    if (dr < best) { best = dr; rail = BLRailRight; }
    if (df < best) { best = df; rail = BLRailFoot; }
    if (dh < best) { rail = BLRailHead; }
    return rail;
}

// Số nút của điểm va băng (chiếu tâm bi lên băng đó).
static inline double BLRailDiamond(double x, double y, BLRail rail, double width, double length) {
    return (rail == BLRailLeft || rail == BLRailRight) ? BLDiamondAlongLong(y, length) : BLDiamondAlongShort(x, width);
}

// Kick 1 băng theo hệ gương: điểm chạm (toạ độ tâm bi) trên đường biên của băng `rail`.
// Trả về số nút; NAN nếu không có đường gương hợp lệ (bi cái và bi đích khác phía, v.v.).
static inline double BLMirrorKickDiamond(double cx, double cy, double tx, double ty, BLRail rail,
                                         double width, double length, double radius, double noseRatio) {
    const double inset = radius * sqrt(fmax(0.0, 1 - noseRatio * noseRatio));
    double a, c1, c2, t1, t2, along1, along2;
    if (rail == BLRailLeft || rail == BLRailRight) {
        a = rail == BLRailLeft ? -width / 2 + inset : width / 2 - inset;
        c1 = cx; t1 = tx; along1 = cy; along2 = ty; c2 = 0; t2 = 0;
    } else {
        a = rail == BLRailFoot ? -length / 2 + inset : length / 2 - inset;
        c1 = cy; t1 = ty; along1 = cx; along2 = tx; c2 = 0; t2 = 0;
    }
    (void)c2; (void)t2;
    const double mirrored = 2 * a - t1;              // ảnh của bi đích qua đường biên
    const double denominator = mirrored - c1;
    if (fabs(denominator) < 1e-12) return NAN;
    const double s = (a - c1) / denominator;         // tham số dọc C → T'
    if (s <= 0 || s >= 1) return NAN;
    const double hit = along1 + (along2 - along1) * s;
    return (rail == BLRailLeft || rail == BLRailRight) ? BLDiamondAlongLong(hit, length) : BLDiamondAlongShort(hit, width);
}

static inline const char *BLRailNameVI(BLRail rail) {
    switch (rail) {
        case BLRailLeft: return "băng dài trái";
        case BLRailRight: return "băng dài phải";
        case BLRailFoot: return "băng ngắn dưới";
        default: return "băng ngắn trên";
    }
}

#endif
