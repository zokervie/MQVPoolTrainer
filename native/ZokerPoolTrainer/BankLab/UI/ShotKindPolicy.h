#ifndef ZOKER_SHOT_KIND_POLICY_H
#define ZOKER_SHOT_KIND_POLICY_H

// Kiểu cú trên giao diện (shotKind017): 0 Đánh, 1 Jump, 2 Phá, 3 Massé. Dùng chung UIKit và test C++.

// 0.21 (quyết định chủ dự án 03/11/2026): mọi gậy ra bi đúng hướng ngắm khi cơ nằm ngang, dù effect xa hay gần
// tâm. Độ lệch (squirt, TP A.31) chỉ xuất hiện khi nâng cơ, tăng dần tới đủ ở BL_SQUIRT_RAMP_DEGREES
// [độ dốc là thiết kế, tránh nhảy bậc ở 0°]. Thay cho chính sách 0.20 theo kiểu cú.
#define BL_SQUIRT_RAMP_DEGREES 15.0

// Massé: giải đồng thời cơ–bi–mặt bàn (CueSlateContact.hpp). Chỉ kiểu Massé (3).     [Tests/AimMasseRailTests.cpp]
static inline int BLMasseCoupledForShotKind(int shotKind) {
    return shotKind == 3;
}

// Đầu tẩy theo kiểu cú (Config::tipProfile): 0 trung tính (Đánh — vật lý mặc định), 1 mềm (Massé — chạm xa tâm
// hơn), 2 cứng (Jump/Phá — phenolic, trả năng lượng nhiều hơn).                       [Tests/CueTipTests.cpp]
static inline int BLTipForShotKind(int shotKind) {
    return shotKind == 3 ? 1 : (shotKind == 1 || shotKind == 2) ? 2 : 0;
}

// Gậy phá: hệ số lực người chơi tạo được [thiết kế]; mức 30 ≈ 11,9 m/s với đầu cứng.  [Tests/CueTipTests.cpp]
#define BL_BREAK_SPEED_GAIN 1.4

#endif
