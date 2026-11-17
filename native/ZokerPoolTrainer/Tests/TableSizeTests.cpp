// 0.46 M3: three WPA bed sizes (9 ft 2.54 × 1.27 · 8 ft 2.34 × 1.17 · 7 ft 1.98 × 0.99 m, WPA Equipment Specifications).
// For each: the constants match WPA, a straight shot into each corner pocket drops, a perpendicular cushion hit comes back
// straight with a plausible rebound, and pocket mouths in the render table sit inside the WPA ranges. 9 ft stays default.
#include "../BankLab/Core/Physics.hpp"
#include "../BankLab/UI/TableSizes.h"
#include <cmath>
#include <iostream>
using namespace banklab;
static Ball ball(int id,V2 p){Ball b;b.id=id;b.p=p;return b;}
int main(){
    int fails=0,checks=0;auto check=[&](bool ok,const char*what,int size){++checks;if(!ok){++fails;std::cerr<<"FAIL size "<<size<<": "<<what<<"\n";}};
    const double wpa[3][2]={{2.54,1.27},{2.34,1.17},{1.98,0.99}};
    check(BLTableDefaultSize()==0,"9 ft is the default",9);
    for(int s=0;s<3;++s){
        const int ft=9-s;
        check(std::abs(BLTableLength(s)-wpa[s][0])<1e-9&&std::abs(BLTableWidth(s)-wpa[s][1])<1e-9,"WPA bed size",ft);
        check(BLTableCornerMouth(s)>=0.114&&BLTableCornerMouth(s)<=0.117,"corner mouth 11.4–11.7 cm",ft);
        check(BLTableSideMouth(s)>=0.127&&BLTableSideMouth(s)<=0.130,"side mouth 12.7–13.0 cm",ft);
        Config c;c.width=BLTableWidth(s);c.length=BLTableLength(s);
        const double hx=c.width/2+.035,hy=c.length/2+.035;
        // straight shots into all four corners, a range of speeds
        const double sx[4]={1,-1,1,-1},sy[4]={1,1,-1,-1};const int pocket[4]={5,4,1,0};
        for(int k=0;k<4;++k)for(double v:{1.0,2.0,3.0}){
            const double d=0.70710678118654752;const V2 hole{sx[k]*hx,sy[k]*hy};
            const V2 obj{hole.x-sx[k]*d*0.40,hole.y-sy[k]*d*0.40},cue{obj.x-sx[k]*d*0.22,obj.y-sy[k]*d*0.22};
            World w(c);w.reset({ball(0,cue),ball(1,obj)});w.strike(std::atan2(obj.y-cue.y,obj.x-cue.x),v,0,-0.15);
            for(int n=0;n<960*20&&w.moving();++n)w.step();
            bool pot=false,scratch=false;for(auto&e:w.events)if(e.kind==2){if(e.a==1&&e.b==pocket[k])pot=true;if(e.a==0)scratch=true;}
            check(pot&&!scratch,"straight corner shot drops, cue ball stays",ft);
        }
        // perpendicular hit on the long (side) rail at x = +width/2: comes straight back, slower
        World w(c);w.reset({ball(0,{0,0.2})});w.strike(0,1.0,0,0);
        double vxAfter=0,vyAfter=0;bool hit=false;
        for(int n=0;n<960*6&&w.moving();++n){w.step();if(!hit){for(auto&e:w.events)if(e.kind==0&&e.a==0)hit=true;}
            if(hit&&w.balls[0].v.x<0){vxAfter=w.balls[0].v.x;vyAfter=w.balls[0].v.y;break;}}
        check(hit,"reaches the rail",ft);
        check(vxAfter<0&&std::abs(vyAfter)<0.02,"rebounds straight back",ft);
        check(std::abs(vxAfter)>0.3&&std::abs(vxAfter)<0.98,"rebound slower than incoming, plausible",ft);
    }
    if(fails){std::cerr<<"FAIL TableSize: "<<fails<<"/"<<checks<<"\n";return 1;}
    std::cout<<"PASS TableSize: "<<checks<<" checks (9/8/7 ft WPA beds, 4 corners × 3 speeds, perpendicular rebound, mouths)\n";
}
