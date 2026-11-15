// 0.44 lockstep (owner item 2: Wi‑Fi play not as smooth as practice). The guest now runs the same solver from the host's
// LANShotStart instead of interpolating 10–20 Hz snapshots. That is only sound if the trajectory depends on nothing but
// the start state and the strike: not on how each device slices frame time (60/120 Hz, dropped frames), and not on hidden
// solver state the wire does not carry. These checks hold the guarantee the guest's 1 mm verifier relies on.
#include "../BankLab/Core/Physics.hpp"
#include <cmath>
#include <cstdio>
#include <vector>
using namespace banklab;

static int failures = 0;
static void check(bool ok, const char* what) { std::printf("%s: %s\n", ok ? "PASS" : "FAIL", what); if (!ok) ++failures; }

static std::vector<Ball> layout() {
    std::vector<Ball> v; const double R = Config().radius, d = 2 * R + 0.0002; int id = 1;
    Ball cue; cue.id = 0; cue.p = {0.11, -.62}; v.push_back(cue);
    for (int row = 0; row < 5; ++row) for (int k = 0; k <= row; ++k) { Ball b; b.id = id++; b.p = {(k - row / 2.0) * d, .635 + row * d * std::sqrt(3) / 2}; v.push_back(b); }
    return v;
}
// Bitwise comparison of everything the guest draws or the referee rules on.
static bool same(const World& a, const World& b) {
    if (a.balls.size() != b.balls.size() || a.events.size() != b.events.size()) return false;
    for (size_t i = 0; i < a.balls.size(); ++i) {
        const Ball &x = a.balls[i], &y = b.balls[i];
        if (x.id != y.id || x.sunk != y.sunk || x.p.x != y.p.x || x.p.y != y.p.y || x.v.x != y.v.x || x.v.y != y.v.y ||
            x.w.x != y.w.x || x.w.y != y.w.y || x.spin != y.spin || x.height != y.height || x.vertical != y.vertical) return false;
    }
    return true;
}
// Host: frame-sliced advance (jittery 60/120 Hz, 1/240 chunks as the controller does). Guest: 1/960 slices.
static int run(const Config& config, double angle, double speed, double side, double top, double seconds, int* compared) {
    World host(config), guest(config);
    host.reset(layout());
    // Host normalises through the same "layout" path the guest uses (loadLayout = reset with positions only).
    guest.reset(host.balls);
    host.strike(angle, speed, side, top); guest.strike(angle, speed, side, top);
    const double frames[] = {1.0 / 60, 1.0 / 120, 1.0 / 60 + 0.004, 1.0 / 90, 1.0 / 60 - 0.003, 1.0 / 30};
    int mismatches = 0; *compared = 0; int k = 0;
    while (host.time < seconds && host.moving()) {
        double dt = frames[k++ % 6];
        while (dt > 1e-12) { const double h = std::min(1.0 / 240.0, dt); host.advance(h); dt -= h; }
        while (guest.time + 1e-12 < host.time) guest.advance(1.0 / 960.0);
        if (std::abs(guest.time - host.time) < 1e-9) { ++*compared; if (!same(host, guest)) ++mismatches; }
    }
    return mismatches;
}

int main() {
    int compared = 0;
    check(run(Config::app(), pi / 2, 7.5, 0, 0, 6, &compared) == 0 && compared > 50, "break: guest and host bit-identical at every shared solver step");
    std::printf("REPORT lockstep break compared=%d\n", compared);
    check(run(Config::app(), pi / 2 + 0.02, 3.2, 0.35, -0.3, 8, &compared) == 0 && compared > 50, "spin shot with draw and english: bit-identical");
    Config jump = Config::app(); jump.experimental3D = true; jump.cueElevationDegrees = 45;
    check(run(jump, pi / 2, 4.5, 0, 0.1, 4, &compared) == 0 && compared > 20, "elevated (jump) solver: bit-identical");
    std::printf("%s\n", failures ? "Lockstep checks FAILED" : "All lockstep checks passed");
    return failures ? 1 : 0;
}
