// Cơ tránh băng: góc nghiêng tối thiểu và vùng effect khả thi khi bi cái gần/sát băng.
#include "../BankLab/UI/CueClearance.h"
#include <cassert>
#include <cmath>
#include <iostream>
int main() {
    const double W = 1.27, L = 2.54, R = 0.028575, nose = 0.27, frozen = W / 2 - R * std::sqrt(1 - nose * nose);
    auto minE = [&](double x, double y, double a, double s, double t) {
        return BLCueMinimumElevation(x, y, a, s, t, W, L, R, nose);
    };
    // Giữa bàn: cơ nằm ngang được với mọi điểm chạm trong vùng 0,7R.
    for (double s : {-0.6, 0.0, 0.6}) for (double t : {-0.6, 0.0, 0.6}) assert(minE(0, 0, 0, s, t) < 4); // giữa bàn: chỉ cần nghiêng vài độ (cơ thật luôn nghiêng 3–10°)
    // Bi sát băng phải (x = +), đánh về bên trái (a = π): cơ phải đi qua băng phải.
    const double a = M_PI;
    const double centre = minE(frozen, 0, a, 0, 0), high = minE(frozen, 0, a, 0, 0.55), low = minE(frozen, 0, a, 0, -0.5);
    std::cout << "REPORT cue-clearance frozen: top+0.55=" << high << "deg centre=" << centre << "deg draw-0.5=" << low << "deg\n";
    assert(high < 20);                 // phần trên bi: chỉ cần nghiêng nhẹ trên băng
    // Tâm/dưới tâm bi sát băng: điểm chạm nằm dưới mũi băng, đầu cơ (Ø13 mm) không lách vào được → không với tới.
    assert(centre > 89 && low > 89);
    assert(!BLCueReachable(frozen, 0, a, 0, -0.5, W, L, R, nose, 35));
    // Kẹp: điểm dưới tâm bị đẩy lên vùng với tới được, giữ nguyên ngang.
    const double clamped = BLCueClampTop(frozen, 0, a, 0.2, -0.5, W, L, R, nose, 35, 0.7);
    assert(clamped > 0.3 && BLCueReachable(frozen, 0, a, 0.2, clamped, W, L, R, nose, 35));
    // Càng xa băng càng ít phải nghiêng; đối xứng trái/phải.
    double previous = 90;
    for (double gap : {0.0, 0.01, 0.03, 0.08, 0.2, 0.4}) {
        const double e = minE(frozen - gap, 0, a, 0, -0.3);
        assert(e <= previous + 1e-9); previous = e;
    }
    assert(minE(frozen - 0.4, 0, a, 0, -0.3) < 6);
    assert(std::abs(minE(frozen, 0.3, a, 0.4, 0.5) - minE(frozen, 0.3, a, -0.4, 0.5)) < 1e-9);
    // Đánh ra xa băng theo đường chéo: khoảng cách tới băng tính theo phương ngược hướng đánh.
    assert(std::abs(BLCueRailDistance(0, 0, M_PI, W, L) - W / 2) < 1e-12);
    assert(std::abs(BLCueRailDistance(0, 0, -M_PI / 2, W, L) - L / 2) < 1e-12);
    std::cout << "PASS CueClearance\n";
}
