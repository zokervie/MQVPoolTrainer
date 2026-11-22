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

// 0.43 (anh chốt 14/11: không làm miscue): giới hạn điểm chạm (phần của R) — MỘT nguồn cho lõi (Config::tipMaxOffset),
// bi effect, cơ 3D, hướng đánh, máy chơi và xem lại. ~0,5R là giới hạn miscue [TP B.17]; cơ nâng 0,50; tẩy mềm +0,05,
// cứng −0,05 [thiết kế]. Trước 0.43 giao diện cho 0,70R trong khi lõi kẹp 0,55R.                  [Tests/CueTipTests.cpp]
static inline double BLTipMaxOffset(int tipProfile, int elevated) {
    return (elevated ? 0.50 : 0.55) + (tipProfile == 1 ? 0.05 : tipProfile == 2 ? -0.05 : 0.0);
}

// Gậy phá: hệ số lực người chơi tạo được [thiết kế]; mức 30 ≈ 11,9 m/s với đầu cứng.  [Tests/CueTipTests.cpp]
#define BL_BREAK_SPEED_GAIN 1.4

// 0.22: Bao cơ chỉ có 3 gậy (Đánh / Jump / Phá). Massé không còn là gậy riêng: gậy Đánh nâng cơ từ 60° là Massé
// (đầu tẩy mềm, tiếp xúc đồng thời), hạ dưới 60° về Đánh.                                  [Tests/CueTipTests.cpp]
#define BL_MASSE_ELEVATION 60.0
static inline int BLShotKindForElevation(int shotKind, double elevationDegrees) {
    if (shotKind == 0 && elevationDegrees >= BL_MASSE_ELEVATION) return 3;
    if (shotKind == 3 && elevationDegrees < BL_MASSE_ELEVATION) return 0;
    return shotKind;
}

// 0.53 B2: hai nút cơ. "Cơ chơi" (kiểu 0/3): dựng cơ >= 37 độ tự thành Massé, < 33 độ trở lại Đánh. "Cơ phá" (kiểu 2/1): < 18 độ là Phá, >= 22 độ là Nhảy.
// Vùng đệm (histeresis) để cơ không nhấp nháy quanh ngưỡng. Ngưỡng là GIẢ ĐỊNH (cần đối chiếu trên bàn thật), đặt ở một chỗ này.
// Máy đối thủ (Opponent.hpp) vẫn dùng BL_MASSE_ELEVATION; dữ liệu cú và bản phát lại không đổi.
#define BL_PLAY_MASSE_UP 37.0
#define BL_PLAY_MASSE_DOWN 33.0
#define BL_BREAK_JUMP_UP 22.0
#define BL_JUMP_BREAK_DOWN 18.0
static inline int BLCueMergedKind(int shotKind, double deg) {
    if (shotKind == 0 && deg >= BL_PLAY_MASSE_UP) return 3;
    if (shotKind == 3 && deg < BL_PLAY_MASSE_DOWN) return 0;
    if (shotKind == 2 && deg >= BL_BREAK_JUMP_UP) return 1;
    if (shotKind == 1 && deg < BL_JUMP_BREAK_DOWN) return 2;
    return shotKind;
}

#endif
