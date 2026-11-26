#include <cstdio>
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
    for (double s : {-0.6, 0.0, 0.6}) for (double t : {-0.6, 0.0, 0.6}) assert(minE(0, 0, 0, s, t) < 5); // giữa bàn: chỉ cần nghiêng vài độ (cơ thật luôn nghiêng 3–10°); 0.37: băng thật trên màn hình (gỗ 56 mm) → ≤ 4,3°
    // Bi sát băng phải (x = +), đánh về bên trái (a = π): cơ phải đi qua băng phải.
    const double a = M_PI;
    const double centre = minE(frozen, 0, a, 0, 0), high = minE(frozen, 0, a, 0, 0.55), low = minE(frozen, 0, a, 0, -0.5);
    std::cout << "REPORT cue-clearance frozen: top+0.55=" << high << "deg centre=" << centre << "deg draw-0.5=" << low << "deg\n";
    assert(high > 1 && high < 12);    // 0.58: băng gỗ 40 mm (trước 56 mm → ~38°): bi sát băng, đầu cơ +0,55R chỉ cần ~3° (đo).
    // Tâm/dưới tâm bi sát băng: điểm chạm nằm dưới mũi băng, đầu cơ (Ø13 mm) không lách vào được → không với tới.
    assert(centre > 89 && low > 89);
    assert(!BLCueReachable(frozen, 0, a, 0, -0.5, W, L, R, nose, 45));
    // Kẹp: điểm dưới tâm bị đẩy lên vùng với tới được, giữ nguyên ngang.
    const double clamped = BLCueClampTop(frozen, 0, a, 0.2, -0.5, W, L, R, nose, 45, 0.7);   // 0.37: normal-stroke limit 45°
    assert(clamped > 0.3 && BLCueReachable(frozen, 0, a, 0.2, clamped, W, L, R, nose, 45));
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
    // ---- 0.44: normal stance (owner item 14) ----
    // Ball 40 cm off the rail, centre hit: the straight cue clears the rail with a few degrees (drawn), stroke stays level.
    assert(minE(frozen - 0.4, 0, a, 0, 0) > 0 && BLCueStrokeElevation(minE(frozen - 0.4, 0, a, 0, 0)) == 0);
    // 10 cm off the rail: low hit needs far more than a high hit, and both are real elevated strokes.
    assert(BLCueStrokeElevation(minE(frozen - 0.1, 0, a, 0, -0.4)) > BLCueStrokeElevation(minE(frozen - 0.1, 0, a, 0, 0.45)));
    assert(BLCueStrokeElevation(minE(frozen - 0.1, 0, a, 0, -0.4)) > BL_CUE_STANCE_DEG);
    // The stroke angle never drops while the drawn clearance grows past the stance.
    assert(BLCueStrokeElevation(BL_CUE_STANCE_DEG + 0.01) > BL_CUE_STANCE_DEG && BLCueStrokeElevation(NAN) == 0);
    std::printf("REPORT stance: 40 cm centre %.1f° drawn / 0° stroke; 10 cm off rail high %.1f°, low %.1f°\n",
                minE(frozen - 0.4, 0, a, 0, 0), minE(frozen - 0.1, 0, a, 0, 0.45), minE(frozen - 0.1, 0, a, 0, -0.4));
    // ---- 0.30: balls behind the cue ball ----
    {   auto withBall = [&](double bx, double by, double s, double t) { const double xs[1] = {bx}, ys[1] = {by};
            return BLCueMinimumElevationBalls(0, 0, 0, s, t, W, L, R, nose, xs, ys, 1); };   // shooting +x, cue lies towards -x
        const double free = minE(0, 0, 0, 0, 0);
        assert(std::abs(withBall(0.5, 0, 0, 0) - free) < 1e-9);             // ball in front: irrelevant
        assert(std::abs(withBall(-0.3, 0.2, 0, 0) - free) < 1e-9);          // well off the cue line: irrelevant
        const double touching = withBall(-2 * R - 0.001, 0, 0, 0), near = withBall(-0.10, 0, 0, 0), far = withBall(-0.60, 0, 0, 0);
        std::cout << "REPORT cue over a ball behind: 1 mm gap " << touching << " deg, 10 cm " << near << " deg, 60 cm " << far << " deg\n";
        assert(touching > 45 && near > far && far > free && far < 12);       // closer ball -> steeper cue (jacked up)
        assert(withBall(-0.10, 0, 0, 0.5) < near);                            // follow (high tip) needs less elevation
        assert(withBall(-0.10, R + 0.009, 0, 0) < near);                      // ball partly off the line: less
        assert(withBall(-2.0, 0, 0, 0) == free);                              // beyond the cue's length
        const double xs[1] = {-0.10}, ys[1] = {0};
        const double clamped = BLCueClampTopBalls(0, 0, 0, 0, -0.5, W, L, R, nose, 25, 0.7, xs, ys, 1);   // normal stroke limit 35°; 25° forces a clamp
        assert(clamped > -0.5 && BLCueMinimumElevationBalls(0, 0, 0, 0, clamped, W, L, R, nose, xs, ys, 1) <= 25 + 1e-6);
        std::cout << "PASS CueClearance balls: cue lifts over balls behind, low tip clamps up\n";
    }
    // 0.58 cơ trên băng: near a rail the tip moves up instead of the cue going to 45–90°.
    {
        auto solve = [&](double gap, double t, double fan) { return BLCueRailBridgeSolve(frozen - gap, 0, a, 0, t, fan, 45, 0.55, W, L, R, nose, nullptr, nullptr, 0); };
        for (double gap : {0.10, 0.20, 0.40}) { const BLCueRailBridge b = solve(gap, 0, 0);
            assert(!b.moved && b.top == 0 && std::fabs(b.elevation - minE(frozen - gap, 0, a, 0, 0)) < 1e-9); }   // ≥ 10 cm: unchanged
        for (double gap : {0.0, 0.01, 0.03}) { const BLCueRailBridge b = solve(gap, 0, 0);   // 0.58: rail wood 40 mm, so from ~6 cm the 15° bridge is enough and the tip stays
            assert(b.moved && b.top > 0.2 && b.top <= 0.55 + 1e-9);
            assert(b.elevation <= std::fmax(b.floorDeg + BL_RAIL_BRIDGE_MARGIN_DEG, BL_RAIL_BRIDGE_COMFORT_DEG) + 1e-6);
            assert(b.elevation < minE(frozen - gap, 0, a, 0, 0));
            assert(std::fabs(minE(frozen - gap, 0, a, 0, b.top) - b.elevation) < 1e-6 || b.elevation >= minE(frozen - gap, 0, a, 0, b.top)); }
        { const BLCueRailBridge b = solve(0.06, 0, 0); assert(!b.moved && b.top == 0 && b.elevation <= 15); }   // 6 cm off the rail: unchanged
        double last = 1;   // raising the fan lets the tip go lower (never higher)
        for (double fan : {0.0, 20.0, 30.0, 45.0}) { const BLCueRailBridge b = solve(0.03, -0.3, fan); assert(b.top <= last + 1e-9 && b.elevation >= fan - 1e-9); last = b.top; }
        assert(solve(0.03, -0.3, 45).top < -0.29);   // high enough fan: the asked draw is kept
        std::cout << "REPORT rail bridge frozen: tip +" << solve(0, 0, 0).top << "R at " << solve(0, 0, 0).elevation << "deg (was centre at 90)\n";
    }
    // ---- 0.59 U3 (IMG_7920): ball off the rail, lower half locked. Geometry table first, then the lock rule. ----
    {
        // Independent check of the rail model, point by point (each rail profile point alone, plain scan of θ in 0.01° steps):
        // the cue's underside h_c + d·tanθ − r(d)/cosθ must be ≥ the point's height. Must agree with BLCueMinimumElevation within 1°.
        auto handE = [&](double gap, double t) {
            const double back = R * std::sqrt(1 - t * t), hc = R * (1 + t), d1 = std::fmax(0.0015, gap + (W / 2 - frozen) - back);
            double need = 0;
            for (int i = 0; i < BL_RAIL_PROFILE_COUNT; ++i) {
                const double d = d1 + BLRailProfile[i][0], h = i == 0 ? R * (1 + nose) : BLRailProfile[i][1];
                double deg = 90;
                for (int k = 0; k < 8975; ++k) { const double th = k * 0.01 * M_PI / 180;
                    if (hc + d * std::tan(th) - BLCueShaftRadius(d) / std::cos(th) >= h) { deg = k * 0.01; break; } }
                need = std::fmax(need, deg);
            }
            return need; };
        std::printf("REPORT U3 needed elevation (deg) by gap to rail × tip:  t=0   -0.30  -0.55  -0.70\n");
        for (double gap : {0.02, 0.05, 0.10, 0.15, 0.20, 0.30}) {
            std::printf("REPORT U3   %4.0f cm:", gap * 100);
            for (double t : {0.0, -0.30, -0.55, -0.70}) {
                const double e = minE(frozen - gap, 0, a, 0, t), h = handE(gap, t);
                assert(std::fabs(e - h) < 1.0 || (e > 89 && h > 60));   // the model is the plain geometry, nothing extra
                std::printf("  %5.1f", e);
            }
            std::printf("\n");
        }
        // Off the rail (≥ 5 cm) every tip up to 0.7R is playable with a stroke ≤ 45°: never locked.
        for (double gap : {0.05, 0.10, 0.20, 0.40}) for (double t : {0.0, -0.3, -0.55, -0.7})
            assert(!BLCueTipLocked(minE(frozen - gap, 0, a, 0, t), 45));
        // …but several of them need more than the 0.58 comfort ceiling (15°): that ceiling must not lock a touched tip.
        assert(minE(frozen - 0.10, 0, a, 0, -0.55) > BL_RAIL_BRIDGE_COMFORT_DEG);
        // Frozen to the rail, centre and below: under the nose — truly locked.
        assert(BLCueTipLocked(minE(frozen, 0, a, 0, 0), 45) && BLCueTipLocked(minE(frozen, 0, a, 0, -0.5), 45));
        // A touched tip raises the bridge fan to what it needs (≤ limit), so the bridge no longer moves it.
        const double need = minE(frozen - 0.10, 0, a, 0, -0.55), fan = BLCueBridgeFan(0, need, 45, 1);
        assert(std::fabs(fan - need) < 1e-12 && BLCueBridgeFan(0, need, 45, 0) == 0 && BLCueBridgeFan(0, 90, 45, 1) == 0 && BLCueBridgeFan(30, 20, 45, 1) == 30);
        const BLCueRailBridge touched = BLCueRailBridgeSolve(frozen - 0.10, 0, a, 0, -0.55, fan, 45, 0.7, W, L, R, nose, nullptr, nullptr, 0);
        const BLCueRailBridge chosenByApp = BLCueRailBridgeSolve(frozen - 0.10, 0, a, 0, -0.55, 0, 45, 0.7, W, L, R, nose, nullptr, nullptr, 0);
        assert(!touched.moved && touched.top == -0.55 && std::fabs(touched.elevation - need) < 1e-9);
        assert(chosenByApp.moved && chosenByApp.top > -0.55);   // 0.58 rule kept when the app picked the tip
        std::printf("REPORT U3 10 cm off the rail, touched draw -0.55R: cue %.1f° (was moved up to %+.2fR at ≤ 15°)\n", touched.elevation, chosenByApp.top);
    }
    std::cout << "PASS CueClearance\n";
}
