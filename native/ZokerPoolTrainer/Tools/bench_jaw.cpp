// 0.60 calibration (26/11/2026): corner-pocket width vs approach angle and speed, compared with the measured curves of
// Jewett & Alciatore, Billiards Digest May 2013 "Just how big are the pockets" Diagram 3 (home table, generous pockets):
// widths are compared as ratios to the straight-in (45°) slow width, so the different mouth sizes cancel.
// Usage: bench_jaw [jawE jawGrip holeOff holeR physics]  — prints per-angle widths and the RMS ratio error. Not a CI test.
// Build: g++ -std=c++17 -O2 -IBankLab/Core Tools/bench_jaw.cpp BankLab/Core/Physics.cpp BankLab/Core/ElevatedPhysics.cpp -o /tmp/bench_jaw
#include "Physics.hpp"
#include <cmath>
#include <cstdio>
#include <cstdlib>
using namespace banklab;
// Read off Diagram 3 (angle from the rail in degrees; width in inches). Slow = rolling; fast = partly sliding.
static const double A[]={2,6,10,13,16,20,23,27,30,35,40,45};
static const double SLOW[]={3.90,4.57,5.03,5.20,4.95,4.39,4.07,3.77,3.38,3.52,3.54,3.49};
static const double FAST[]={3.66,2.31,2.62,2.71,2.82,3.16,3.21,3.20,3.54,3.68,3.80,3.74};
static double width(const Config&cfg,double fromRailDeg,bool fast){
    const double x=cfg.width/2,y=cfg.length/2,c=.1143/std::sqrt(2.0);const V2 mouth{x-c/2,y-c/2};
    const double a=(fromRailDeg+45)*M_PI/180;   // 45° from rail = along the pocket centre-line (π/4)... rail is +y: angle from +y axis
    const V2 d{std::sin((fromRailDeg)*M_PI/180),std::cos((fromRailDeg)*M_PI/180)};(void)a;
    const V2 p=d.perp();int ok=0;
    for(double s=-.11;s<=.11001;s+=.001){
        const V2 st=mouth-d*.45+p*s;if(std::abs(st.x)>x-cfg.radius-1e-4||std::abs(st.y)>y-cfg.radius-1e-4)continue;
        World w;w.config=cfg;Ball b;b.id=0;b.p=st;w.reset({b});
        const double sp=fast?3.0:.6;w.balls[0].v=d*sp;w.balls[0].w=fast?V2{}:(d*sp).perp()*(1/cfg.radius);
        for(int n=0;n<960*12&&w.moving();++n)w.step();
        for(auto&e:w.events)if(e.kind==2&&e.a==0&&e.b==5){ok++;break;}
    }
    return ok*.001/.0254;   // made positions × step = width (gaps not counted)
}
int main(int argc,char**argv){
    Config cfg=Config::app();
    if(argc>2){cfg.jawRestitution=std::atof(argv[1]);cfg.jawGrip=std::atof(argv[2]);}
    if(argc>4){cfg.cornerHoleOffset=std::atof(argv[3]);cfg.cornerHoleRadius=std::atof(argv[4]);}
    double ref=width(cfg,45,false),err=0;int n=0;
    for(int i=0;i<12;++i){double s=width(cfg,A[i],false),f=width(cfg,A[i],true);
        double rs=s/ref,rf=f/ref,ts=SLOW[i]/SLOW[11],tf=FAST[i]/SLOW[11];err+=(rs-ts)*(rs-ts)+(rf-tf)*(rf-tf);n+=2;
        std::printf("%4.0f° slow %.2f (x%.2f, real x%.2f)  fast %.2f (x%.2f, real x%.2f)\n",A[i],s,rs,ts,f,rf,tf);}
    std::printf("RMS ratio error %.3f  straight-in slow %.2f in\n",std::sqrt(err/n),ref);
}
