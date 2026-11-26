// 0.60 measurement (26/11/2026): effective target size of the game's corner and side pockets vs approach angle and speed,
// to compare with Dr. Dave Alciatore's published values (TP 3.6: slow straight-in corner ≈ 3.05 in; slow corner max ≈ 3.4 in
// near 43° to the pocket line; rule of thumb ≈ mouth − 2 in). Not a CI test; changes nothing.
// Build: g++ -std=c++17 -O2 -IBankLab/Core Tools/bench_pocket.cpp BankLab/Core/Physics.cpp BankLab/Core/ElevatedPhysics.cpp -o /tmp/bench_pocket
#include "Physics.hpp"
#include <cmath>
#include <cstdio>
#include <cstdlib>
using namespace banklab;
static bool pots(const Config&cfg,V2 start,V2 dir,double speed,int pocketWanted){
    World w;w.config=cfg;Ball b;b.id=0;b.p=start;w.reset({b});
    // Rolling ball (no slip): v along dir, w = v.perp/R so the contact point is at rest.
    w.balls[0].v=dir*speed;w.balls[0].w=(dir*speed).perp()*(1.0/cfg.radius);
    for(int n=0;n<960*12&&w.moving();++n)w.step();
    for(auto&e:w.events)if(e.kind==2&&e.a==0)return e.b==pocketWanted;
    return false;
}
int main(int argc,char**argv){
    Config cfg=Config::app();
    if(argc>2){cfg.cornerHoleOffset=std::atof(argv[1]);cfg.cornerHoleRadius=std::atof(argv[2]);}
    if(argc>4){cfg.sideHoleOffset=std::atof(argv[3]);cfg.sideHoleRadius=std::atof(argv[4]);}
    const bool quick=argc>5;
    const double x=cfg.width/2,y=cfg.length/2,c=.1143/std::sqrt(2.0),g=.127/2;
    const double speeds[3]={.6,1.8,4.0};const char*sn[3]={"slow","medium","fast"};
    std::printf("pocket,angle_deg,speed,target_in,center_offset_in\n");
    for(int side=0;side<2;++side){
        // corner pocket index 5 at (+x,+y); side pocket index 3 at (+x,0)
        V2 mouth=side?V2{x,0}:V2{x-c/2,y-c/2};
        double base=side?0.0:M_PI/4;   // pocket centre-line direction (into the pocket)
        int idx=side?3:5;
        for(int ai=0;ai<=(side?6:9);++ai){
            if(quick&&!(side==0&&(ai==0||ai==9))&&!(side==1&&ai==0))continue;
            double ang=ai*5.0*M_PI/180;   // 0 = straight in; positive turns the path toward the long rail (corner) / toward the head (side)
            V2 dir{std::cos(base-ang),std::sin(base-ang)},perp=dir.perp();
            for(int si=0;si<3;++si){
                double lo=1e9,hi=-1e9;
                for(double s=-.09;s<=.09;s+=.0005){
                    V2 start=mouth-dir*.45+perp*s;
                    if(std::abs(start.x)>x-cfg.radius||std::abs(start.y)>y-cfg.radius)continue;
                    if(pots(cfg,start,dir,speeds[si],idx)){lo=std::min(lo,s);hi=std::max(hi,s);}
                }
                if(hi<lo){std::printf("%s,%d,%s,0,0\n",side?"side":"corner",ai*5,sn[si]);continue;}
                std::printf("%s,%d,%s,%.2f,%.2f\n",side?"side":"corner",ai*5,sn[si],(hi-lo+.0005)/.0254,(hi+lo)/2/.0254);
            }
        }
    }
}
