#ifndef ZOKER_SHOT_KIND_POLICY_H
#define ZOKER_SHOT_KIND_POLICY_H

// Kiểu cú trên giao diện (shotKind017): 0 Đánh, 1 Jump, 2 Phá, 3 Massé. Dùng chung UIKit và test C++.
//
// Squirt (TP A.31) — bi cái lệch nhẹ ngược phía effect — chỉ bật cho Jump và Massé.
// Đánh/Phá: bi đi đúng đường ngắm để người chơi tự hình dung góc chạm bi mục tiêu bằng mắt;
// phần lệch do squirt ngoài đời để người chơi tự bù trên bàn thật.     [quyết định chủ dự án 03/11/2026]
static inline int BLSquirtForShotKind(int shotKind) {
    return shotKind == 1 || shotKind == 3;
}

// Massé: giải đồng thời cơ–bi–mặt bàn (CueSlateContact.hpp) thay cho "cơ trước, mặt bàn sau" — cú massé mạnh và
// xoáy tăng theo độ nâng cơ. Chỉ kiểu Massé (3); Đánh/Jump/Phá giữ mô hình cũ.        [Tests/AimMasseRailTests.cpp]
static inline int BLMasseCoupledForShotKind(int shotKind) {
    return shotKind == 3;
}

#endif
