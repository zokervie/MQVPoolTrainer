// Toạ độ nút kim cương, hệ gương kick 1 băng, và Coach phản thực tế: World::simulate trùng cú thật.
#include "../BankLab/Core/Physics.hpp"
#include "../BankLab/UI/DiamondSystem.h"
#include <cassert>
#include <cmath>
#include <iostream>
using namespace banklab;
static bool close(double a, double b, double e = 1e-9) { return std::abs(a - b) <= e; }
int main() {
    const double W = 1.27, L = 2.54, R = 0.028575, h = 0.27;
    assert(close(BLDiamondAlongLong(0, L), 4) && close(BLDiamondAlongShort(0, W), 2));
    assert(close(BLDiamondAlongLong(-L / 2, L), 0) && close(BLDiamondAlongLong(L / 2, L), 8));
    assert(close(BLDiamondAlongShort(W / 2, W), 4));
    assert(BLNearestRail(-0.6, 0.1, W, L) == BLRailLeft && BLNearestRail(0.1, 1.2, W, L) == BLRailHead);
    // Hệ gương đối xứng: bi cái và bi đích cùng khoảng cách tới băng phải → chạm đúng giữa hai bi theo chiều dài.
    const double d = BLMirrorKickDiamond(0.2, -0.6, 0.2, 0.6, BLRailRight, W, L, R, h);
    assert(close(d, 4, 1e-9));
    // Bi đích gần băng hơn → điểm chạm lệch về phía bi đích.
    assert(BLMirrorKickDiamond(0.0, -0.6, 0.4, 0.6, BLRailRight, W, L, R, h) > 4);
    assert(std::isnan(BLMirrorKickDiamond(0.0, -0.6, 0.0, 0.6, BLRailFoot, W, L, R, h)) == false);
    std::cout << "REPORT mirror-kick symmetric=" << d << "\n";

    // Vật lý app khác gương: cú chậm có ma sát băng → góc ra khác góc vào. Ghi lại để so với bàn thật.
    Config c; World w(c);
    // Điểm chạm nút 2 băng dài phải (tránh miệng lỗ giữa ở nút 4).
    Ball cue; cue.id = 0; cue.p = {0.2, -1.0}; Ball target; target.id = 1; target.p = {0.2, -0.27};
    w.reset({cue, target});
    const double inset = R * std::sqrt(1 - h * h), a = W / 2 - inset;
    const double hitY = -0.635, angle = std::atan2(hitY - (-1.0), a - 0.2);
    const Outcome o = w.simulate(angle, 2.0, 0, 0);
    double firstRail = NAN;
    for (const auto &e : o.events) if (e.kind == 0 && e.a == 0) { firstRail = BLDiamondAlongLong(e.p.y, L); break; }
    assert(close(firstRail, 2, 0.02));  // ngắm đúng điểm gương → chạm băng đúng nút gương
    std::cout << "REPORT physics-first-rail=" << firstRail << "\n";

    // simulate() trùng hoàn toàn cú thật (cùng solver, bước cố định): nền cho Coach phản thực tế.
    World real(c); real.reset({cue, target}); real.strike(angle, 2.0, 0.2, -0.1);
    for (int i = 0; i < 960 * 60 && real.moving(); ++i) real.step();
    World copy(c); copy.reset({cue, target});
    const Outcome sim = copy.simulate(angle, 2.0, 0.2, -0.1);
    assert(sim.events.size() == real.events.size());
    for (size_t i = 0; i < sim.events.size(); ++i)
        assert(sim.events[i].kind == real.events[i].kind && close(sim.events[i].p.x, real.events[i].p.x, 1e-12) && close(sim.events[i].time, real.events[i].time, 1e-12));
    for (size_t i = 0; i < sim.balls.size(); ++i) assert(close(sim.balls[i].p.x, real.balls[i].p.x, 1e-12) && close(sim.balls[i].p.y, real.balls[i].p.y, 1e-12));
    assert(copy.events.empty() && copy.time == 0);  // bản gốc không bị đổi
    std::cout << "PASS DiamondSystem\n";
}
