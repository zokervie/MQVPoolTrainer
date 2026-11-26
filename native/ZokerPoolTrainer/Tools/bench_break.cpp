// 0.60 measurement only (26/11/2026): how does the CURRENT physics break 8/9/10-ball racks? Not a CI test; changes nothing.
// Sweeps cue-ball position behind the head string x cue-ball speed x top/draw, perfect and loose racks, and prints
// pocketing rate, balls made, scratch rate, balls reaching a rail, cue-ball resting place and spread.
// Build: g++ -std=c++17 -O2 -IBankLab/Core Tools/bench_break.cpp BankLab/Core/Physics.cpp BankLab/Core/ElevatedPhysics.cpp -o /tmp/bench_break
#include "Physics.hpp"
#include "MatchRules.hpp"
#include <cmath>
#include <cstdio>
#include <random>
#include <set>
#include <cstdlib>
using namespace banklab;
using banklab::match::Rules;using banklab::match::Discipline;
struct Acc{int n=0,made=0,scratch=0,legal=0,four=0,offTable=0;double balls=0,cueR=0,spread=0,settle=0;};
int main(int argc,char**argv){
    const bool appLike=true;
    const double aimSigmaDeg=argc>1?std::atof(argv[1]):0.0, jitterMm=argc>2?std::atof(argv[2]):0.4;   // human aim error, loose-rack gap
    const int seeds=argc>3?std::atoi(argv[3]):8;
    const Discipline ds[3]={Discipline::EightBall,Discipline::NineBall,Discipline::TenBall};const char* dn[3]={"8-ball","9-ball","10-ball"};
    const double xs[]={0,-.15,.15,-.30,.30,-.45,.45};const double speeds[]={7.0,9.0,11.0};const double tops[]={-.2,0,.2};
    std::printf("discipline,rack,x,speed,top,n,made%%,balls,scratch%%,legal%%,4rail%%,cueR_m,spread_m,settle_s\n");
    for(int d=0;d<3;++d){Acc total[2];
      for(int loose=0;loose<2;++loose)for(double x:xs)for(double sp:speeds)for(double top:tops){Acc a;
        for(int seed=1;seed<=seeds;++seed){
            Rules rules(ds[d]);auto balls=rules.rack(1000+seed);balls[0].p={x,-.90};
            std::mt19937_64 rng(7*seed+loose);std::uniform_real_distribution<double> j(-jitterMm/1000,jitterMm/1000);std::normal_distribution<double> aim(0,aimSigmaDeg*M_PI/180);
            if(loose)for(auto&b:balls)if(b.id!=0){b.p.x+=j(rng);b.p.y+=j(rng);}
            V2 head{};for(auto&b:balls)if(b.id==(ds[d]==Discipline::EightBall?balls[1].id:1))head=b.p;
            if(ds[d]==Discipline::EightBall){double best=1e9;for(auto&b:balls)if(b.id&&b.p.y<best){best=b.p.y;head=b.p;}}
            World w;if(appLike){w.config.coupledCushions=true;w.config.cueType=2;w.config.squirtEnabled=false;w.config.spinDecay=11;}
            w.reset(balls);w.strike(std::atan2(head.y-balls[0].p.y,head.x-balls[0].p.x)+aim(rng),sp,0,top);
            int n=0;for(;n<960*30&&w.moving();++n)w.step();
            std::set<int> made,railed;bool scratch=false;
            for(auto&e:w.events){if(e.kind==2){if(e.a==0)scratch=true;else made.insert(e.a);}if(e.kind==0&&e.a!=0)railed.insert(e.a);}
            V2 cue{};double cx=0,cy=0;int left=0;for(auto&b:w.balls){if(b.id==0)cue=b.p;else if(!b.sunk){cx+=b.p.x;cy+=b.p.y;++left;}}
            double spread=0;if(left){cx/=left;cy/=left;for(auto&b:w.balls)if(b.id&&!b.sunk)spread+=std::hypot(b.p.x-cx,b.p.y-cy);spread/=left;}
            const int railedCount=(int)railed.size()+(int)made.size();
            a.n++;a.made+=!made.empty();a.balls+=made.size();a.scratch+=scratch;a.four+=railedCount>=4;
            a.legal+=(!scratch)&&(!made.empty()||railedCount>=4);a.cueR+=scratch?0:std::hypot(cue.x,cue.y);a.spread+=spread;a.settle+=n/960.0;}
        std::printf("%s,%s,%.2f,%.0f,%.1f,%d,%.0f,%.2f,%.0f,%.0f,%.0f,%.2f,%.2f,%.1f\n",dn[d],loose?"loose":"tight",x,sp,top,a.n,
            100.0*a.made/a.n,a.balls/a.n,100.0*a.scratch/a.n,100.0*a.legal/a.n,100.0*a.four/a.n,a.cueR/std::max(1,a.n-a.scratch),a.spread/a.n,a.settle/a.n);
        Acc&t=total[loose];t.n+=a.n;t.made+=a.made;t.balls+=a.balls;t.scratch+=a.scratch;t.legal+=a.legal;}
      for(int l=0;l<2;++l)std::fprintf(stderr,"TOTAL %s %s: made %.0f%%  balls/break %.2f  scratch %.0f%%  legal %.0f%%  (n=%d)\n",dn[d],l?"loose":"tight",
          100.0*total[l].made/total[l].n,total[l].balls/total[l].n,100.0*total[l].scratch/total[l].n,100.0*total[l].legal/total[l].n,total[l].n);}
}
