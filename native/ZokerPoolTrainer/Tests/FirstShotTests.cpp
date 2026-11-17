// 0.44.1 M1.2 "Cú đầu tiên": the first shot a new player sees must be straight and forgiving.
// Layout and default tip live in BankLab/UI/FirstShot.h (shared with Models.swift through the bridging header).
#include "../BankLab/Core/Physics.hpp"
#include "../BankLab/UI/FirstShot.h"
#include <cmath>
#include <iostream>
using namespace banklab;
static Ball ball(int id,V2 p){Ball b;b.id=id;b.p=p;return b;}
static int fails=0,checks=0;
static void check(bool ok,const char* what){++checks;if(!ok){++fails;std::cerr<<"FAIL: "<<what<<"\n";}}
int main(){
    const V2 cue{BLFirstShotCueX(),BLFirstShotCueY()},obj{BLFirstShotObjectX(),BLFirstShotObjectY()};
    World probe;const double hx=probe.config.width/2+.035,hy=probe.config.length/2+.035;
    const V2 hole{hx,hy};   // top-right corner pocket centre, World::pocket index 5
    // Geometry: cue, object ball and pocket in line (cut < 0.5°), distances inside the brief's ranges.
    const V2 aim=(obj-cue).unit(),toPocket=(hole-obj).unit();
    const double cut=std::acos(std::max(-1.0,std::min(1.0,aim.x*toPocket.x+aim.y*toPocket.y)))*180/pi;
    check(cut<0.5,"cut angle below 0.5°");
    const double dco=(obj-cue).length(),dop=(hole-obj).length();
    check(dco>=.20&&dco<=.30,"cue–object distance 0.20–0.30 m");
    check(dop>=.30&&dop<=.60,"object–pocket distance 0.30–0.60 m");
    check(std::abs(BLFirstShotAngle()-std::atan2(aim.y,aim.x))<1e-9,"default aim points straight at the object ball");
    check(BLFirstShotTop()<=0&&BLFirstShotTop()>=-0.5,"default tip at or slightly below centre");
    // Sweep: speed 0.8–4.0 m/s, aim error ±0.8°, default tip. Object ball in pocket 5, cue ball never pocketed.
    int worst=0;
    for(int si=8;si<=40;++si)for(int ei=-8;ei<=8;++ei){
        World w;w.reset({ball(0,cue),ball(1,obj)});
        w.strike(BLFirstShotAngle()+ei*.1*pi/180,si*.1,0,BLFirstShotTop());
        for(int n=0;n<960*30&&w.moving();++n)w.step();
        bool pot=false,scratch=false;
        for(const auto&e:w.events)if(e.kind==2){if(e.a==1&&e.b==5)pot=true;if(e.a==0)scratch=true;}
        if(!pot||scratch){++worst;std::cerr<<"  speed "<<si*.1<<" m/s, aim error "<<ei*.1<<"°: "<<(pot?"":"object missed ")<<(scratch?"cue ball pocketed":"")<<"\n";}
        check(pot&&!scratch,"object ball pocketed, cue ball stays on the table");
    }
    if(fails){std::cerr<<"FAIL FirstShot: "<<fails<<"/"<<checks<<" ("<<worst<<" sweep cases)\n";return 1;}
    std::cout<<"PASS FirstShot: "<<checks<<" checks (cut "<<cut<<"°, cue–object "<<dco<<" m, object–pocket "<<dop<<" m, 33 speeds × 17 aim errors)\n";
}
