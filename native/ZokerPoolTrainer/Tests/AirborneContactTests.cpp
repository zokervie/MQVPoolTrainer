// 0.37 (owner replay: "bi mục tiêu chạy trước khi bi chủ chạm tới"). An object ball may only start moving when the
// cue ball actually touches it in 3D (centre distance ~2R, heights included) — never while the cue ball flies past.
#include "../BankLab/Core/Physics.hpp"
#include <algorithm>
#include <cmath>
#include <iostream>
#include <stdexcept>
using namespace banklab;
static void check(bool x,const char*m){if(!x)throw std::runtime_error(m);}
static Ball ball(int id,double x,double y){Ball b;b.id=id;b.p={x,y};return b;}
int main(){
    Config base;base.experimental3D=true;base.cueType=1;
    const double R=base.radius;
    int contacts=0,clears=0;double worst=0;
    for(double elevation:{30.0,45.0,60.0})for(double speed:{2.0,3.0,4.5,6.0})for(double gap:{.10,.18,.30,.45})for(double lateral:{0.0,.015,.03,.045}){
        Config c=base;c.cueElevationDegrees=elevation;World w(c);
        w.reset({ball(0,0,-.9),ball(1,lateral,-.9+gap)});w.strike(pi/2,speed,0,0);
        bool moved=false;
        for(int i=0;i<4000&&!moved;i++){
            const Ball before0=w.balls[0],before1=w.balls[1];
            w.step();
            const Ball&o=w.balls[1];
            if(std::hypot(o.v.x,o.v.y)+std::abs(o.vertical)>1e-9){
                moved=true;contacts++;
                // distance at the START and END of the step that set it moving; the contact lies between them
                auto dist=[&](const Ball&a,const Ball&b){return std::sqrt(std::pow(a.p.x-b.p.x,2)+std::pow(a.p.y-b.p.y,2)+std::pow(a.height-b.height,2));};
                const double d=std::min(dist(before0,before1),dist(w.balls[0],o));
                worst=std::max(worst,d-2*R);
                if(d>2*R+0.002){
                    std::cerr<<"elev "<<elevation<<" v "<<speed<<" gap "<<gap<<" lat "<<lateral<<" moved at 3D distance "<<d<<" (2R "<<2*R<<") h0 "<<before0.height<<"\n";
                    throw std::runtime_error("object ball moved before the cue ball touched it");
                }
            }
            if(!w.moving())break;
        }
        if(!moved)clears++;
    }
    std::cout<<"REPORT airborne contacts "<<contacts<<" clean jumps "<<clears<<" worst gap "<<worst*1000<<" mm\n";
    check(contacts>10&&clears>5,"sweep covers both hits and clean jumps");
    std::cout<<"PASS AirborneContact: object balls move only on a real 3D touch\n";
}
