// Đối chiếu số liệu ĐÃ CÔNG BỐ (độc lập với engine khác). Ngưỡng là khoảng tham khảo của nguồn, không phải số đo dự án.
// - Throw: D. Alciatore, FAQ "maximum throw" + TP A.14 (ma sát bi–bi giảm theo tốc độ trượt, khớp dữ liệu Marlow):
//   throw do cắt lớn nhất ≈ 4–6° ở cú stun chậm quanh nửa bi; góc cắt nhỏ gần như không phụ thuộc tốc độ;
//   góc cắt lớn đánh nhanh throw ít hơn; bi lăn throw ít hơn bi stun.
// - Squirt: Alciatore TP A.31, tan α = 2,5·s·√(1−s²) / (1 + m/mₑ + 2,5·(1−s²)); bi lệch ngược phía effect.
// - Tốc độ bi: Alciatore TP A.30, v = (1+e)·V / (1 + m/M + 2,5·(d/R)²): cùng cú cơ, đánh lệch tâm bi đi chậm hơn.
// Các con số được cùng một cấu hình mặc định của app; đổi hệ số phải giữ các khoảng này.
#include "../BankLab/Core/Physics.hpp"
#include <cstdio>
#include <stdexcept>
#include <vector>
using namespace banklab;
static int checks = 0;
static void check(bool ok, const char* name) { checks++; if (!ok) throw std::runtime_error(name); }

// Chạy cả hai bộ bước: phẳng (Config mặc định) và A1 băng 3D (app bật mặc định qua BLWorld).
static bool coupled = false;

static Ball make(int id, V2 p) { Ball b; b.id = id; b.p = p; return b; }

// Throw (độ): bi cái đi theo +y với vận tốc v, xoáy tùy chọn; đường nối tâm lệch `cut` độ về phía −x.
// Dương = bi mục tiêu bị kéo về phía hướng đi của bi cái.
static double throwDeg(double cutDeg, double v, bool roll = false, double sideSpin = 0) {
    Config c; c.width = 10; c.length = 10; c.coupledCushions = coupled;
    World w(c);
    const double R = c.radius, cut = cutDeg * pi / 180;
    Ball cue = make(0, {0, -1e-5}), ob = make(1, {-2 * R * std::sin(cut), 2 * R * std::cos(cut)});
    cue.v = {0, v};
    if (roll) cue.w = cue.v.perp() / R;
    cue.spin = 2.5 * v * sideSpin / R;   // TP 4.2: ω_z = 5·v·s/(2R)
    w.balls = {cue, ob};
    for (int i = 0; i < 50 && w.events.empty(); i++) w.step();
    check(!w.events.empty(), "collision happened");
    const V2 ov = w.balls[1].v;
    const double ideal = std::atan2(std::cos(cut), -std::sin(cut)), dir = std::atan2(ov.y, ov.x);
    return (ideal - dir) * 180 / pi;
}

static World single(Config c = {}) { c.coupledCushions = coupled; World w(c); w.reset({make(0, {0, 0})}); return w; }

int main() {
    try {
      for (bool mode : {false, true}) {
        coupled = mode;
        std::printf("REPORT: --- %s ---\n", mode ? "A1 coupled (app default)" : "planar");
        const double slow = .45, medium = 1.3, fast = 3.1;
        // 1) Throw do cắt lớn nhất ở cú stun chậm.
        double best = 0, bestCut = 0;
        for (double cut = 5; cut <= 60; cut += 1) { double t = throwDeg(cut, slow); if (t > best) { best = t; bestCut = cut; } }
        std::printf("REPORT: max cut-induced throw (stun, slow) %.2f deg at %.0f deg cut\n", best, bestCut);
        for (double cut : {15.0, 30.0, 45.0})
            std::printf("REPORT: cut %.0f: slow %.2f medium %.2f fast %.2f roll %.2f\n", cut, throwDeg(cut, slow),
                        throwDeg(cut, medium), throwDeg(cut, fast), throwDeg(cut, medium, true));
        check(best > 4.0 && best < 6.5, "max throw 4-6.5 deg (Alciatore)");
        check(bestCut >= 22 && bestCut <= 42, "max throw near half-ball");
        // 2) Góc cắt nhỏ: gần như không phụ thuộc tốc độ.
        for (double cut : {5.0, 10.0, 15.0}) check(std::abs(throwDeg(cut, slow) - throwDeg(cut, fast)) < .25, "small cut speed independent");
        // 3) Góc cắt lớn: nhanh throw ít hơn.
        for (double cut : {35.0, 45.0, 55.0}) check(throwDeg(cut, slow) > throwDeg(cut, fast), "large cut throw falls with speed");
        // 4) Bi lăn throw ít hơn stun.
        for (double cut : {15.0, 30.0, 45.0}) check(throwDeg(cut, medium, true) < throwDeg(cut, medium), "rolling throws less");
        // 5) Throw do xoáy ngang (cú thẳng, chậm): có, lớn nhất quanh 0,15–0,35R, không quá 6,5°.
        double sBest = 0, sAt = 0;
        for (double s = .1; s <= .8001; s += .05) { double t = std::abs(throwDeg(0, slow, false, s)); if (t > sBest) { sBest = t; sAt = s; } }
        std::printf("REPORT: spin-induced throw straight slow: max %.2f deg at %.2fR\n", sBest, sAt);
        check(sBest > .5 && sBest < 6.5 && sAt >= .15 && sAt <= .35, "spin-induced throw peak");

        // 6) Squirt: bi lệch ngược phía effect, độ lớn theo TP A.31 (đầu cơ 7 g).
        {
            const double s = .5, m = .17, me = .007;
            const double expected = std::atan(2.5 * s * std::sqrt(1 - s * s) / (1 + m / me + 2.5 * (1 - s * s)));
            for (double side : {s, -s}) {
                World w = single(); w.strike(0, 2, side, 0);
                const Ball& b = w.balls[0];
                const double dev = std::atan2(b.v.y, b.v.x);
                std::printf("REPORT: squirt side %+.1f: %.2f deg (TP A.31 %.2f), spin %.1f rad/s\n", side, dev * 180 / pi, expected * 180 / pi, b.spin);
                check(std::abs(std::abs(dev) - expected) < 1e-9, "squirt magnitude TP A.31");
                check(dev * b.spin > 0, "squirt deflects opposite to english (rotation sense of spin)");
            }
            World w = single(); w.strike(0, 2, 0, .4);
            check(std::abs(w.balls[0].v.y) < 1e-12, "no squirt for pure top/bottom");
        }
        // 7) Cùng cú cơ: đánh lệch tâm bi đi chậm hơn, đánh tâm giữ nguyên tốc độ nhập.
        {
            World a = single(), b = single(), c2 = single();
            a.strike(0, 2, 0, 0); b.strike(0, 2, 0, -.5); c2.strike(0, 2, .3, .3);
            const double M = .54, m = .17, k = 1 + m / M;
            check(std::abs(a.balls[0].v.length() - 2) < 1e-12, "center hit keeps nominal speed");
            check(std::abs(b.balls[0].v.length() - 2 * k / (k + 2.5 * .25)) < 1e-12, "draw 0.5R slower (TP A.30)");
            check(std::abs(c2.balls[0].v.length() - 2 * k / (k + 2.5 * .18)) < 1e-12, "diagonal offset slower (TP A.30)");
            const double e0 = World::energy(a.balls[0], a.config), e1 = World::energy(b.balls[0], b.config);
            std::printf("REPORT: energy draw 0.5R / center = %.2f (was 1.62)\n", e1 / e0);
            check(e1 / e0 < 1.15, "draw shot not more energetic than real stroke allows");
        }
        // 8) Cố định: cùng đầu vào, cùng kết quả.
        {
            World a = single(), b = single();
            a.strike(.3, 3, .2, -.3); b.strike(.3, 3, .2, -.3);
            for (int i = 0; i < 2000; i++) { a.step(); b.step(); }
            check(a.balls[0].p.x == b.balls[0].p.x && a.balls[0].p.y == b.balls[0].p.y, "deterministic");
        }
      }
        std::printf("Literature checks passed: %d\n", checks);
        return 0;
    } catch (const std::exception& e) {
        std::printf("FAILED: %s (after %d checks)\n", e.what(), checks);
        return 1;
    }
}
