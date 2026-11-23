// 0.58 L2: replay smoothness of a rolling target ball. The shot is sampled exactly like TrainingController (240 Hz while anything
// is faster than 0.8 m/s, 60 Hz to 0.25, 30 Hz below) and replayed at 60 fps with TableScene.replay's linear interpolation; the shown
// position is compared with the 240 Hz truth of the same shot. Measured result: no frame is off by more than 2 mm (worst ~1.6 mm), so the
// visible tremble of the target ball is NOT in the sampling/interpolation of positions (see Docs/NGHIEM-THU-0.58.md).
#include "../BankLab/Core/Physics.hpp"
#include <cmath>
#include <cstdio>
#include <iostream>
#include <vector>
using namespace banklab;
struct Snap{double t;std::vector<Ball> b;};
static double maxSpeed(const World&w){double s=0;for(auto&b:w.balls)if(!b.sunk)s=std::max(s,b.v.length()+std::abs(b.vertical));return s;}
int main(){
    int fails=0;double overall=0;
    for(double speed:{0.8,1.5,3.0,5.0}){
        World w(Config::app());std::vector<Ball> L(2);L[0].id=0;L[0].p={-0.5,-0.3};L[1].id=1;L[1].p={0.2,-0.3};
        w.reset(L);w.strike(0.06,speed,0,0);
        std::vector<Snap> rec,truth;rec.push_back({0,w.balls});double clk=0;
        while(w.moving()&&w.time<40){
            double rem=1.0/60;
            while(rem>1e-9){const double h=std::min(1.0/240,rem);w.advance(h);rem-=h;clk+=h;
                const double f=maxSpeed(w),iv=f>0.8?1.0/240:(f>0.25?1.0/60:1.0/30);
                if(clk>=iv-1e-9){clk=0;rec.push_back({w.time,w.balls});}
                truth.push_back({w.time,w.balls});}
        }
        rec.push_back({w.time,w.balls});
        double worst=0;size_t i=0,ti=0;
        for(double t=0;t<=rec.back().t;t+=1.0/60){
            while(i+1<rec.size()&&t>=rec[i+1].t)++i;
            const size_t j=std::min(i+1,rec.size()-1);const double span=rec[j].t-rec[i].t,f=span>0?(t-rec[i].t)/span:0;
            const Ball&a=rec[i].b[1],&b=rec[j].b[1];
            const double x=a.p.x+(b.p.x-a.p.x)*f,y=a.p.y+(b.p.y-a.p.y)*f;
            while(ti+2<truth.size()&&truth[ti+1].t<t)++ti;
            const double dt=truth[ti+1].t-truth[ti].t,tf=dt>0?std::min(1.0,std::max(0.0,(t-truth[ti].t)/dt)):0;
            const double qx=truth[ti].b[1].p.x+(truth[ti+1].b[1].p.x-truth[ti].b[1].p.x)*tf,qy=truth[ti].b[1].p.y+(truth[ti+1].b[1].p.y-truth[ti].b[1].p.y)*tf;
            worst=std::max(worst,std::hypot(x-qx,y-qy));
        }
        overall=std::max(overall,worst);
        if(worst>0.002){++fails;std::cerr<<"FAIL: speed "<<speed<<" worst "<<worst*1000<<" mm > 2 mm\n";}
    }
    if(fails)return 1;
    std::printf("PASS ReplaySmooth: replayed target-ball position within 2 mm of the 240 Hz truth (worst %.2f mm over 4 shots)\n",overall*1000);
}
