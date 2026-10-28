// Thang Lực cố định 1–30: cú đánh phải lặp lại được và HLV phải nói bằng đơn vị người dùng chỉnh được.
#include "../BankLab/UI/PowerScale.h"
#include <cassert>
#include <cmath>
#include <iostream>
int main() {
    // Hai đầu thang khớp phạm vi tốc độ của thang 7 mức cũ.
    assert(std::fabs(BLPowerSpeed(1) - 0.5) < 1e-9);
    assert(std::fabs(BLPowerSpeed(BL_POWER_LEVELS) - 8.0) < 1e-9);
    // Tăng ngặt; mỗi nấc đúng một tỷ lệ ≈ 10% (9–11%), để "1 nấc" luôn mang cùng một ý nghĩa.
    for (int l = 1; l < BL_POWER_LEVELS; ++l) {
        const double r = BLPowerSpeed(l + 1) / BLPowerSpeed(l);
        assert(r > 1.09 && r < 1.11);
    }
    // Ngoài thang: kẹp, không trả NaN.
    assert(BLPowerSpeed(0) == BLPowerSpeed(1) && BLPowerSpeed(99) == BLPowerSpeed(BL_POWER_LEVELS));
    // Khứ hồi mức → tốc độ → mức là chính xác (yêu cầu cốt lõi: đánh lại đúng cú).
    for (int l = 1; l <= BL_POWER_LEVELS; ++l) assert(BLPowerLevelForSpeed(BLPowerSpeed(l)) == l);
    // Tốc độ lẻ (từ chế độ Cảm giác) về mức gần nhất theo tỷ lệ; giá trị hỏng về mức 1.
    assert(BLPowerLevelForSpeed(BLPowerSpeed(10) * 1.04) == 10);
    assert(BLPowerLevelForSpeed(BLPowerSpeed(10) * 1.06) == 11);
    assert(BLPowerLevelForSpeed(0) == 1 && BLPowerLevelForSpeed(-3) == 1 && BLPowerLevelForSpeed(NAN) == 1);
    assert(BLPowerLevelForSpeed(50) == BL_POWER_LEVELS);
    // Mức mặc định ≈ 2 m/s (cú tập luyện trung bình, bằng tốc độ "Đánh thử" cũ).
    const double d = BLPowerSpeed(BL_POWER_DEFAULT_LEVEL);
    assert(d > 1.8 && d < 2.2);
    std::cout << "REPORT power-scale: step=" << BLPowerStepRatio() << " default=" << d << " m/s\n";
    std::cout << "PowerScale tests passed\n";
}
