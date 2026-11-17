// 0.44.1 M5: the intro's break is real physics. Re-simulating the stored start state must reproduce every stored pocket
// event (ball, pocket, time within 1 ms), the first drop is in a corner pocket inside the intro window, the cue ball
// stays on the table, and two runs are bit-identical (the intro replays live with the same solver).
#include "../BankLab/Core/Physics.hpp"
#include "../BankLab/Core/MatchRules.hpp"
#include "../BankLab/UI/IntroBreak.h"
#include <cmath>
#include <iostream>
using namespace banklab;
using banklab::match::Rules;using banklab::match::Discipline;
static std::vector<Event> run(){
    Rules rules(Discipline::NineBall);auto balls=rules.rack(BL_INTRO_RACK_SEED);balls[0].p={BL_INTRO_CUE_X,BL_INTRO_CUE_Y};
    World w;w.reset(balls);w.strike(BL_INTRO_ANGLE,BL_INTRO_SPEED,0,BL_INTRO_TOP);
    for(int n=0;n<960*20&&w.moving();++n)w.step();
    std::vector<Event> pots;for(auto&e:w.events)if(e.kind==2)pots.push_back(e);return pots;
}
int main(){
    int fails=0;auto check=[&](bool ok,const char*what){if(!ok){++fails;std::cerr<<"FAIL: "<<what<<"\n";}};
    const auto a=run(),b=run();
    check(static_cast<int>(a.size())==BL_INTRO_POT_COUNT,"same number of pocket events as stored");
    for(std::size_t i=0;i<a.size()&&static_cast<int>(i)<BL_INTRO_POT_COUNT;++i){
        check(a[i].a==BLIntroPotBall[i],"same ball");check(a[i].b==BLIntroPotPocket[i],"same pocket");
        check(std::abs(a[i].time-BLIntroPotTime[i])<0.001,"same time within 1 ms");
    }
    check(a.size()==b.size(),"deterministic count");
    for(std::size_t i=0;i<a.size()&&i<b.size();++i)check(a[i].a==b[i].a&&a[i].b==b[i].b&&a[i].time==b[i].time,"bit-identical replay");
    // The stored start state (read by the Swift intro) is exactly rack(seed) with the cue ball moved.
    {Rules rules(Discipline::NineBall);auto balls=rules.rack(BL_INTRO_RACK_SEED);balls[0].p={BL_INTRO_CUE_X,BL_INTRO_CUE_Y};
     check(static_cast<int>(balls.size())==BL_INTRO_BALL_COUNT,"stored ball count");
     for(std::size_t i=0;i<balls.size()&&static_cast<int>(i)<BL_INTRO_BALL_COUNT;++i)
         check(static_cast<int>(BLIntroBalls[i][0])==balls[i].id&&BLIntroBalls[i][1]==balls[i].p.x&&BLIntroBalls[i][2]==balls[i].p.y,"stored start state equals the rack");}
    bool scratch=false;for(auto&e:a)if(e.a==0)scratch=true;
    check(!scratch,"cue ball stays on the table");
    check(!a.empty()&&a[0].b!=2&&a[0].b!=3&&a[0].b>=0,"first drop is a corner pocket");
    // Intro timeline (IntroDirector0441.simTime): strike at 1.6 s, 1× for 0.125 s, 0.5 s of wall time at 0.25×, then 1×.
    const double wall=a.empty()?0:1.6+0.625+(a[0].time-0.25);
    check(wall>=1.8&&wall<=3.6,"first drop lands inside the intro's follow-the-ball window");
    if(fails){std::cerr<<"FAIL IntroBreak: "<<fails<<"\n";return 1;}
    std::cout<<"PASS IntroBreak: "<<a.size()<<" pocket event(s) reproduced (first: ball "<<a[0].a<<", pocket "<<a[0].b<<", "<<a[0].time<<" s; intro wall time "<<wall<<" s), deterministic\n";
}
