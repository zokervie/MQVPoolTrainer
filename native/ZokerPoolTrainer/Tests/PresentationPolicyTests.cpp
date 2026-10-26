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
bool step(BLShotCameraState &s, double dt = 0.1, bool moving = false,
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
    const auto m = BLRightHUDLayout(height, expanded);
    const Rect spin{width-12-m.spinSize,height-12-m.spinSize,m.spinSize,m.spinSize};
    const Rect elevation{spin.x-8-44,height-12-120,44,120};
    const Rect row{width-12-154,height-m.railBottomInset-48,154,48};
    const Rect menu{width-12-78,10,78,44}, bridge{12,height-12-68,68,68};
    const std::array<Rect,5> controls{spin,elevation,row,menu,bridge};
    for (const auto &r : controls) {
        assert(r.x >= 0 && r.y >= 0 && r.x+r.w <= width+1e-8 && r.y+r.h <= height+1e-8);
        assert(r.w >= 44 && r.h >= 44);
    }
    for (unsigned i = 0; i < controls.size(); ++i)
        for (unsigned j = i+1; j < controls.size(); ++j) assert(!overlaps(controls[i],controls[j]));
    assert(spin.x > elevation.x+elevation.w);
    assert(row.y >= menu.y+menu.h+8-1e-8);
    if (!expanded) {
        const Rect fine{width/2-95,height-14-44,190,44};
        for (const auto &r : controls) assert(!overlaps(fine,r));
    }
}
}

int main() {
    BLShotCameraState s{};
    assert(!rest(s,100)); passed("idle has no unsolicited camera return");
    BLShotCameraStart(&s);
    for(int i=0;i<100;++i) assert(!step(s,0.1,true));
    assert(s.stableSeconds==0); passed("all motion blocks return");
    assert(!step(s,0.1)); assert(!step(s,0.1)); assert(!step(s,0.1)); assert(!step(s,0.1));
    assert(!step(s,0.09)); assert(step(s,0.01)); passed("return starts at 0.5 seconds, never earlier");
    BLShotCameraStart(&s); rest(s,4); assert(!step(s,0.1,true)); assert(!rest(s,4)); assert(step(s));
    passed("renewed motion resets uninterrupted rest");
    BLShotCameraStart(&s); for(int i=0;i<20;++i) assert(!step(s,0.1,false,true));
    passed("pocket fall blocks return");
    assert(!rest(s,4)); assert(step(s)); passed("pocket completion requires a fresh rest window");
    BLShotCameraStart(&s); for(int i=0;i<20;++i) assert(!step(s,0.1,false,false,true));
    passed("replay never forces aim");
    assert(!rest(s,4)); assert(step(s)); passed("replay exit restarts the full settle window");
    BLShotCameraStart(&s); for(int i=0;i<20;++i) assert(!step(s,0.1,false,false,false,false));
    passed("spectator remains free to observe");
    assert(!rest(s,4)); assert(step(s)); passed("local turn resumes aim after settling");
    BLShotCameraStart(&s); for(int i=0;i<20;++i) assert(!step(s,0.1,false,false,false,true,true));
    passed("ball editing suppresses automatic return");
    assert(!rest(s,4)); assert(step(s)); passed("editing exit requires stable rest");
    BLShotCameraStart(&s); rest(s,4); assert(!step(s,0.1,false,false,false,true,false,true));
    passed("an active orbit or pinch defers recentering");
    assert(!rest(s,4)); assert(step(s)); passed("manual observation still returns after gesture ends");
    BLShotCameraStart(&s);
    for(double dt : {0.0,-1.0,std::numeric_limits<double>::infinity(),std::numeric_limits<double>::quiet_NaN()}) assert(!step(s,dt));
    assert(s.stableSeconds==0); passed("invalid timing cannot complete a shot");
    assert(!step(s,3600)); assert(std::abs(s.stableSeconds-0.1)<1e-10);
    passed("resume gaps do not count as 0.5 seconds of observed rest");
    assert(rest(s,4)); for(int i=0;i<100;++i) assert(!step(s));
    passed("return is emitted once per shot");
    BLShotCameraStart(&s); assert(rest(s)); assert(BLShotCameraBusy(s));
    rest(s,4); assert(BLShotCameraBusy(s)); step(s,0.05); assert(!BLShotCameraBusy(s));
    passed("stroke remains blocked throughout the 0.45 second transition");
    BLShotCameraStart(&s); rest(s,3); BLShotCameraReset(&s);
    assert(!BLShotCameraBusy(s)); assert(!rest(s,20)); passed("Undo cancels pending camera work");
    BLShotCameraStart(&s); rest(s,3); BLShotCameraStart(&s);
    assert(!rest(s,4)); assert(step(s)); passed("a new shot cannot inherit settle time");
    for(int fps : {30,60,120}) {
        BLShotCameraStart(&s); int emitted=0,first=0;
        for(int frame=1;frame<=fps*2;++frame) if(step(s,1.0/fps)){++emitted;first=frame;}
        assert(emitted==1); assert(std::abs(static_cast<double>(first)/fps-0.5)<1e-8);
    }
    passed("30/60/120 Hz produce the same settle deadline");
    assert(BLStrokeAllowed(true,false,false,false,false,true));
    assert(!BLStrokeAllowed(false,false,false,false,false,true)); passed("spectator cannot shoot");
    assert(!BLStrokeAllowed(true,true,false,false,false,true)); passed("simulation and return cannot shoot");
    assert(!BLStrokeAllowed(true,false,true,false,false,true)); passed("Menu cannot shoot");
    assert(!BLStrokeAllowed(true,false,false,true,false,true)); passed("expanded effect cannot arm B or shoot");
    assert(!BLStrokeAllowed(true,false,false,false,true,true)); passed("editing cannot shoot");
    assert(!BLStrokeAllowed(true,false,false,false,false,false)); passed("scratch cannot shoot before ball placement");
    int permitted=0;
    for(unsigned mask=0;mask<64;++mask) if(BLStrokeAllowed(mask&1,mask&2,mask&4,mask&8,mask&16,mask&32))++permitted;
    assert(permitted==1); passed("all 64 input flag combinations fail closed");
    for(auto size : {std::array<double,2>{568,299},{750,369},{830,388},{1024,744}})checkLayout(size[0],size[1],false);
    passed("collapsed HUD fits small phone, 14 Pro Max, larger phone and iPad safe areas");
    for(auto size : {std::array<double,2>{568,299},{750,369},{830,388},{1024,744}})checkLayout(size[0],size[1],true);
    passed("expanded HUD keeps B, Menu, elevation, View and Undo hit regions separate");
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
