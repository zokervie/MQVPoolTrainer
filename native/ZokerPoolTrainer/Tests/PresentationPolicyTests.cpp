#include <vector>
#include "../BankLab/UI/PresentationPolicy.h"
#include <algorithm>
#include <array>
#include <cassert>
#include <cmath>
#include <iostream>
#include <limits>

namespace {
int scenarios = 0;
void passed(const char *name) { ++scenarios; std::cout << "PASS G1: " << name << '\n'; }
const double U = BL_SHOT_READY_SECONDS / 5;   // one test frame; 5 frames = the rest window
bool step(BLShotCameraState &s, double dt = U, bool moving = false,
          bool pocket = false, bool replay = false, bool local = true,
          bool editing = false, bool gesture = false) {
    return BLShotCameraTick(&s, dt, moving, pocket, replay, local, editing, gesture);
}
bool rest(BLShotCameraState &s, int frames = 5) {
    bool fired = false;
    for (int i = 0; i < frames; ++i) fired = step(s) || fired;
    return fired;
}
struct Rect { double x, y, w, h; };
bool overlaps(Rect a, Rect b) {
    return a.x < b.x+b.w-1e-8 && b.x < a.x+a.w-1e-8 &&
           a.y < b.y+b.h-1e-8 && b.y < a.y+a.h-1e-8;
}
void checkLayout(double width, double height, bool expanded) {
    auto m = BLRightHUDLayout(height, expanded);
    // B plus a gap are reserved on the left. Effect's maximum remains useful
    // on a compact landscape phone without touching the bridge control.
    m.spinSize=std::min(m.spinSize,std::max(52.0,width-100-8-BL_HUD_RAIL_WIDTH-6-BL_HUD_ELEVATION_WIDTH-8));
    const double railX = width-BL_HUD_EDGE-BL_HUD_RAIL_WIDTH;
    const double railHeight=BLHUDVisibleRailHeight(height);
    const Rect elevation{width-8-BL_HUD_ELEVATION_WIDTH,height-BL_HUD_BOTTOM-BL_HUD_ELEVATION_HEIGHT,BL_HUD_ELEVATION_WIDTH,BL_HUD_ELEVATION_HEIGHT};
    const Rect column{railX,elevation.y-6-railHeight,BL_HUD_RAIL_WIDTH,railHeight};
    const Rect spin{elevation.x-16-m.spinSize,height-12-m.spinSize,m.spinSize,m.spinSize};
    const Rect wheel{spin.x+(spin.w-44)/2,spin.y-8-100,44,100};
    const Rect menu{12,10,78,44}, bridge{12,height-12-72,72,72};
    const Rect coach{10,bridge.y-8-44,76,44};
    const std::array<Rect,6> controls{spin,elevation,column,coach,menu,bridge};
    if(!expanded){assert(wheel.x>=0 && wheel.y>=0);assert(!overlaps(wheel,column));assert(!overlaps(wheel,spin));}
    for (const auto &r : controls) {
        assert(r.x >= 0 && r.y >= 0 && r.x+r.w <= width+1e-8 && r.y+r.h <= height+1e-8);
        assert(r.w >= 44 && r.h >= 44);
    }
    for (unsigned i = 0; i < controls.size(); ++i)
        for (unsigned j = i+1; j < controls.size(); ++j) assert(!overlaps(controls[i],controls[j]));
    assert(elevation.x > spin.x+spin.w);
    assert(column.y+column.h < elevation.y);
    assert(width-(column.x+column.w) <= BL_HUD_EDGE+1e-8);
    assert(coach.y+coach.h < bridge.y);
    assert(std::abs(coach.x+coach.w/2-(bridge.x+bridge.w/2))<1e-8);
    assert(column.h<=BLHUDRailHeight());
    // Every button has a full-size content rect; scrolling reveals any portion
    // outside the viewport. The visible viewport fits at least two buttons.
    assert(BL_HUD_BUTTON_HEIGHT>=44 && column.h>=2*BL_HUD_BUTTON_HEIGHT);
    for(int i=0;i<BL_HUD_RAIL_ITEMS;++i) {
        const Rect content{0,i*(BL_HUD_BUTTON_HEIGHT+BL_HUD_BUTTON_GAP),BL_HUD_RAIL_WIDTH,BL_HUD_BUTTON_HEIGHT};
        assert(content.w>=44 && content.h>=44);
        assert(content.y+content.h<=BLHUDRailHeight()+1e-8);
    }
    assert(column.h==BLHUDRailHeight());
}

}


static bool hit(const BLRect& a, const BLRect& b) { return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h; }
static bool inside(const BLRect& r, double x0, double y0, double w, double h) { return r.x >= x0 - 1e-9 && r.y >= y0 - 1e-9 && r.x + r.w <= x0 + w + 1e-9 && r.y + r.h <= y0 + h + 1e-9; }
// 0.22 thumb-first HUD: every combination of device, hand, mode and effect expansion.
static void checkHUD022(double x0, double y0, double w, double h, int pad) {
    for (int left = 0; left < 2; ++left) for (int practice = 0; practice < 2; ++practice) for (int expanded = 0; expanded < 2; ++expanded) {
        const BLHUDFrames f = BLHUDLayout(x0, y0, w, h, pad, left, practice, expanded);
        assert(f.items == (practice ? 6 : 5));
        // while the effect ball is held only it and the wheel are shown
        std::vector<BLRect> shown{f.spin, f.wheel};
        if (!expanded) { shown.push_back(f.rail); shown.push_back(f.menu); shown.push_back(f.elevation); for (int k = 0; k < BL_CUE_ICONS; ++k) shown.push_back(BLHUDCueIcon(f, k)); }
        if (practice && !expanded) shown.push_back(f.coach);
        for (const auto& r : shown) { assert(inside(r, x0, y0, w, h)); assert(r.w >= 44 && r.h >= 40); }
        for (size_t a = 0; a < shown.size(); ++a) for (size_t b = a + 1; b < shown.size(); ++b) assert(!hit(shown[a], shown[b]));
        assert(f.button >= 44);
        const double cx = x0 + w / 2;
        // 0.30b: effect ball + cue icons bottom-left, column + wheel + fan right (right-handed); mirror for left
        if (!left) { assert(f.rail.x > cx && f.wheel.x > cx && f.elevation.x > cx && f.spin.x + f.spin.w < cx && f.cues.x + f.cues.w < cx && f.menu.x < cx); }
        else       { assert(f.rail.x + f.rail.w < cx && f.wheel.x + f.wheel.w < cx && f.spin.x > cx && f.cues.x > cx && f.menu.x > cx); }
        if (!left) assert(f.wheel.x + f.wheel.w <= f.rail.x); else assert(f.wheel.x >= f.rail.x + f.rail.w);
        assert(std::abs(f.wheel.y + f.wheel.h - (y0 + h - 6)) < 1e-9 && f.wheel.w > f.wheel.h);   // wheel on the bottom edge
        assert(f.elevation.y + f.elevation.h <= f.wheel.y && f.elevation.x >= f.wheel.x && f.elevation.x + f.elevation.w <= f.wheel.x + f.wheel.w);
        if (!expanded) { assert(f.cues.y + f.cues.h <= f.spin.y && f.spin.w >= (pad ? 100 : 76)); }
        else { assert(f.spin.w <= (pad ? 200 : 150) + 1e-9); }   // zoom, but not so big it hides the table
        if (left) { const BLHUDFrames r = BLHUDLayout(x0, y0, w, h, pad, 0, practice, expanded);
            assert(std::abs((f.spin.x - x0) - (w - (r.spin.x - x0) - r.spin.w)) < 1e-9 && std::abs(f.spin.y - r.spin.y) < 1e-9); }
    }
}
int main() {
    BLShotCameraState s{};
    assert(!rest(s,100)); passed("idle never emits a shot-ready signal");
    BLShotCameraStart(&s);
    for(int i=0;i<100;++i) assert(!step(s,U,true));
    assert(s.stableSeconds==0); passed("all motion blocks readiness");
    assert(!step(s,U)); assert(!step(s,U)); assert(!step(s,U)); assert(!step(s,U));
    assert(!step(s,U*0.9)); assert(step(s,U*0.1)); passed("readiness starts at the rest window (0.3 s), never earlier");
    BLShotCameraStart(&s); rest(s,4); assert(!step(s,U,true)); assert(!rest(s,4)); assert(step(s));
    passed("renewed motion resets uninterrupted rest");
    BLShotCameraStart(&s); for(int i=0;i<20;++i) assert(!step(s,U,false,true));
    passed("pocket animation blocks readiness");
    assert(!rest(s,4)); assert(step(s)); passed("pocket completion requires a fresh rest window");
    BLShotCameraStart(&s); for(int i=0;i<20;++i) assert(!step(s,U,false,false,true));
    passed("replay never emits a live-shot-ready signal");
    assert(!rest(s,4)); assert(step(s)); passed("replay exit restarts the full settle window");
    BLShotCameraStart(&s); for(int i=0;i<20;++i) assert(!step(s,U,false,false,false,false));
    passed("spectator remains free to observe");
    assert(!rest(s,4)); assert(step(s)); passed("local turn becomes ready after settling");
    BLShotCameraStart(&s); for(int i=0;i<20;++i) assert(!step(s,U,false,false,false,true,true));
    passed("ball editing suppresses readiness");
    assert(!rest(s,4)); assert(step(s)); passed("editing exit requires stable rest");
    BLShotCameraStart(&s); rest(s,4); assert(!step(s,U,false,false,false,true,false,true));
    passed("an active orbit or pinch defers readiness without changing pose");
    assert(!rest(s,4)); assert(step(s)); passed("manual observation becomes ready after gesture ends");
    BLShotCameraStart(&s);
    for(double dt : {0.0,-1.0,std::numeric_limits<double>::infinity(),std::numeric_limits<double>::quiet_NaN()}) assert(!step(s,dt));
    assert(s.stableSeconds==0); passed("invalid timing cannot complete a shot");
    assert(!step(s,3600)); assert(std::abs(s.stableSeconds-0.1)<1e-10);
    passed("resume gaps do not count as a full rest window");
    assert(rest(s,4)); for(int i=0;i<100;++i) assert(!step(s));
    passed("readiness is emitted once per shot");
    BLShotCameraStart(&s); assert(rest(s)); assert(BLShotCameraBusy(s));
    rest(s,4); assert(BLShotCameraBusy(s)); step(s,BL_SHOT_RETURN_SECONDS-4*U+1e-9); assert(!BLShotCameraBusy(s));
    passed("stroke remains blocked throughout the final settle guard");
    BLShotCameraStart(&s); rest(s,3); BLShotCameraReset(&s);
    assert(!BLShotCameraBusy(s)); assert(!rest(s,20)); passed("Undo cancels pending shot settlement");
    BLShotCameraStart(&s); rest(s,3); BLShotCameraStart(&s);
    assert(!rest(s,4)); assert(step(s)); passed("a new shot cannot inherit settle time");
    for(int fps : {30,60,120}) {
        BLShotCameraStart(&s); int emitted=0,first=0;
        for(int frame=1;frame<=fps*2;++frame) if(step(s,1.0/fps)){++emitted;first=frame;}
        assert(emitted==1); assert(std::abs(static_cast<double>(first)/fps-BL_SHOT_READY_SECONDS)<1e-8);
    }
    passed("30/60/120 Hz produce the same settle deadline");
    assert(BLStrokeAllowed(true,false,false,false,false,true));
    assert(!BLStrokeAllowed(false,false,false,false,false,true)); passed("spectator cannot shoot");
    assert(!BLStrokeAllowed(true,true,false,false,false,true)); passed("simulation and settlement cannot shoot");
    assert(!BLStrokeAllowed(true,false,true,false,false,true)); passed("Menu cannot shoot");
    assert(BLStrokeAllowed(true,false,false,true,false,true)); passed("0.30b: holding the effect ball (the lock) allows the stroke");
    assert(!BLStrokeAllowed(true,false,false,false,true,true)); passed("editing cannot shoot");
    assert(!BLStrokeAllowed(true,false,false,false,false,false)); passed("scratch cannot shoot before ball placement");
    int permitted=0;
    for(unsigned mask=0;mask<64;++mask) if(BLStrokeAllowed(mask&1,mask&2,mask&4,mask&8,mask&16,mask&32))++permitted;
    assert(permitted==2); passed("all 64 flag combinations fail closed except the effect-ball flag (0.30b)");
    for(auto size : {std::array<double,2>{568,299},{750,369},{830,388},{1024,744}})checkLayout(size[0],size[1],false);
    passed("compact vertical HUD and Coach fit phone and iPad safe areas");
    for(auto size : {std::array<double,2>{568,299},{750,369},{830,388},{1024,744}})checkLayout(size[0],size[1],true);
    passed("expanded effect leaves B, Coach, Menu, wheel and scroll column separate");
    // safe-area rects (landscape): iPhone SE, iPhone 15 Pro, 15 Pro Max, iPad 10.9", iPad Pro 13"
    checkHUD022(0, 0, 568, 299, 0); checkHUD022(59, 0, 734, 372, 0); checkHUD022(59, 0, 814, 409, 0);
    checkHUD022(0, 24, 1180, 776, 1); checkHUD022(0, 24, 1376, 1000, 1);
    passed("0.30b HUD: effect ball + 4 cue icons bottom-left, column + wheel + fan right, no B, left-hand mirror, no overlaps");
    assert(BLCueIconKind(0) == 0 && BLCueIconKind(1) == 1 && BLCueIconKind(2) == 3 && BLCueIconKind(3) == 2);
    assert(BLCueIconElevation(1) == 45 && BLCueIconElevation(2) == 70 && BLCueIconElevation(0) == 0 && BLCueIconElevation(3) == 0);
    assert(BLFanDegrees(60, 64, 64, 64, 0) == 0 && BLFanDegrees(0, 0, 64, 64, 0) == 90 && BLFanDegrees(40, 24, 64, 64, 0) == 45);
    assert(BLFanDegrees(24, 24, 64, 64, 1) == 45 && BLFanDegrees(70, 64, 64, 64, 0) == 0 && BLFanDegrees(-5, 30, 64, 64, 0) == 90);
    passed("0.30 cue icons Đánh/Jump/Massé/Break (45°/70° presets) and elevation fan 0-90°");
    {   double x = 9, y = 9; const double R = .028575;
        assert(BLFreeSpotNearCentre(nullptr, nullptr, 0, R, .635, 1.27, &x, &y) && x == 0 && y == 0);
        const double xs[3] = {0, .03, -.02}, ys[3] = {0, .01, -.04};
        assert(BLFreeSpotNearCentre(xs, ys, 3, R, .635, 1.27, &x, &y));
        for (int k = 0; k < 3; ++k) assert(std::hypot(xs[k] - x, ys[k] - y) >= 2 * R);
        assert(std::hypot(x, y) < .12);
    }
    passed("0.22 Đặt bi: free spot nearest the centre, never on another ball");
    {   int a = 0, b = 0; int w = -1;
        for (int k = 0; k < 4; ++k) { w = BLRaceRecordRack(&a, &b, 5, 0); assert(w == -1); w = BLRaceRecordRack(&a, &b, 5, 1); assert(w == -1); }
        assert(a == 4 && b == 4 && BLRaceRecordRack(&a, &b, 5, 1) == 1 && b == 5);
        assert(BLRaceRecordRack(&a, &b, 5, -1) == 1);   // no winner yet: score unchanged, match already decided
        assert(BLRaceNextBreaker(0) == 1 && BLRaceNextBreaker(1) == 0 && BLRaceClamp(0) == 1 && BLRaceClamp(99) == 25);
    }
    passed("0.29 race to N: frames tally, hill-hill decider, alternate break");
    for(int fps : {30,60,120}) {
        double remaining=0.45,value=0;
        while(remaining>0) {
            const double dt=std::min(1.0/fps,remaining);
            value+=(1-value)*BLCameraTweenBlend(remaining,dt,0.45);
            remaining=std::max(0.0,remaining-dt);
        }
        assert(std::abs(value-1)<1e-12);
    }
    passed("camera tween reaches its target at 0.45 seconds at every display rate");
    double remaining=0.45,value=0;
    for(int i=0;i<15;++i){value+=(1-value)*BLCameraTweenBlend(remaining,0.015,0.45);remaining-=0.015;}
    assert(std::abs(value-0.5)<1e-10);
    assert(BLCameraTweenBlend(0.45,0,0.45)==0 && BLCameraTweenBlend(0,0.1,0.45)==1);
    passed("camera easing is smoothstep with a stable midpoint and explicit endpoints");
    std::cout << "PASS: " << scenarios << " G1 policy scenarios (portable production C policy; UIKit integration still requires Xcode)\n";
}
