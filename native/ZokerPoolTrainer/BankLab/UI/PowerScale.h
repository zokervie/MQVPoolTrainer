#ifndef ZOKER_POWER_SCALE_H
#define ZOKER_POWER_SCALE_H

#include <math.h>

// Thang "Lực" 1–30 cho chế độ Lực cố định (0.16). Dùng chung cho UIKit và test C++ (Tests/PowerScaleTests.cpp).
//
// Mục đích: cú đánh lặp lại được. Người dùng đặt trước một mức lực, vuốt cơ chỉ là động tác kích hoạt,
// nên HLV có thể nói "Lực 15 → 14" và người dùng làm đúng y như vậy.
//
// Thang hình học: mức 1 = 0,5 m/s, mức 30 = 8,0 m/s (bằng mức trên cùng của thang 7 mức cũ).
// Mỗi nấc ≈ +10% tốc độ bi đầu — khớp các bước "nhẹ/mạnh hơn ~8–15%" mà HLV đã dùng.     [thiết kế, không phải số đo]

#define BL_POWER_LEVELS 30
#define BL_POWER_MIN_SPEED 0.5
#define BL_POWER_MAX_SPEED 8.0
#define BL_POWER_DEFAULT_LEVEL 15

static inline int BLPowerClampLevel(int level) {
    return level < 1 ? 1 : (level > BL_POWER_LEVELS ? BL_POWER_LEVELS : level);
}

static inline double BLPowerStepRatio(void) {
    return pow(BL_POWER_MAX_SPEED / BL_POWER_MIN_SPEED, 1.0 / (BL_POWER_LEVELS - 1));
}

// Tốc độ bi đầu (m/s) của một mức lực.
static inline double BLPowerSpeed(int level) {
    return BL_POWER_MIN_SPEED * pow(BLPowerStepRatio(), BLPowerClampLevel(level) - 1);
}

// Mức gần nhất (theo tỷ lệ, không theo hiệu) với một tốc độ bất kỳ — dùng khi cú đến từ chế độ Cảm giác.
static inline int BLPowerLevelForSpeed(double speed) {
    if (!(speed > 0) || !isfinite(speed)) return 1;
    const double n = log(speed / BL_POWER_MIN_SPEED) / log(BLPowerStepRatio());
    return BLPowerClampLevel((int)lround(n) + 1);
}

#endif
