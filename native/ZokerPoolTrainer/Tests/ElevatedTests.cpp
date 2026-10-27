#include "../BankLab/Core/Physics.hpp"
#include <iostream>
#include <stdexcept>
using namespace banklab;
void check(bool x,const char* message){if(!x)throw std::runtime_error(message);}
void near(double a,double b,double tolerance,const char* message){check(std::abs(a-b)<=tolerance,message);}
Ball ball(int id,double x,double y){Ball b;b.id=id;b.p={x,y};return b;}
int main(){
    Config c;c.experimental3D=true;
    {World w(c);w.reset({ball(0,0,-.4)});w.balls[0].height=.1;w.balls[0].vertical=1.5;w.balls[0].v={.5,0};
     for(int i=0;i<96;i++)w.step();
     near(w.balls[0].p.x,.05,1e-10,"ballistic horizontal path");
     near(w.balls[0].height,.1+1.5*.1-4.905*.01,1e-10,"ballistic height");
     near(w.balls[0].vertical,1.5-.981,1e-10,"ballistic vertical speed");}
    {c.cueType=1;c.cueElevationDegrees=60;World w(c);w.reset({ball(0,.1,-.8),ball(1,.1,-.6)});w.strike(pi/2,6,0,0);
     double peak=0;for(int i=0;i<550;i++){w.step();peak=std::max(peak,w.balls[0].height);for(auto&b:w.balls)check(std::isfinite(b.height+b.vertical+b.p.x+b.p.y),"finite jump");}
     check(peak>.06,"jump must lift above a ball diameter");
     check(std::none_of(w.events.begin(),w.events.end(),[](auto e){return e.kind==1;}),"high cue ball must clear object, not collide in 2D");}
    // 0.15 thang lực nhảy: vuốt = tốc độ bi cơ ngang (như cú phẳng). Bi cản gần cần cơ dốc, bi cản xa cần lực.
    {auto clears=[&](double elevation,double speed,double gap){
        Config j=c;j.cueType=1;j.cueElevationDegrees=elevation;World w(j);w.reset({ball(0,0,-.9),ball(1,0,-.9+gap)});w.strike(pi/2,speed,0,0);
        for(int i=0;i<2880;i++){w.step();if(w.balls[0].p.y>-.9+gap+.06)return true;
            if(std::any_of(w.events.begin(),w.events.end(),[](auto e){return e.kind==1;}))return false;}
        return false;};
     check(clears(60,3,.12),"medium stroke, steep jump cue clears a close obstacle");
     check(clears(45,4,.25),"firm stroke at 45 deg clears an obstacle a diamond away");
     check(!clears(45,3,.25),"soft stroke at 45 deg must not clear a diamond-away obstacle");
     check(!clears(60,3,.50),"steep short jump lands before a far obstacle");
     check(clears(45,6,.50),"hard stroke at 45 deg carries over a far obstacle");}
    // Cơ Đánh/Massé (cueType 0): nâng cơ không làm bi nhảy, chỉ tạo xoáy cong.
    {Config m=c;m.cueType=0;m.cueElevationDegrees=60;World w(m);w.reset({ball(0,0,-.9)});w.strike(pi/2,6,.4,0);
     double peak=0;for(int i=0;i<960;i++){w.step();peak=std::max(peak,w.balls[0].height);}
     check(peak<1e-9,"masse/normal cue must keep the ball on the slate");
     check(std::abs(w.balls[0].p.x)>.01,"elevated side spin on the masse cue still curves");}
    {c.cueElevationDegrees=0;World w(c);w.reset({ball(0,.1,-.8),ball(1,.1,-.6)});w.strike(pi/2,3,0,0);
     for(int i=0;i<1000;i++)w.step();
     check(std::any_of(w.events.begin(),w.events.end(),[](auto e){return e.kind==1;}),"ground shot must hit obstacle");}
    {c.cueType=0;c.cueElevationDegrees=70;
     auto run=[&](double side){World w(c);w.reset({ball(0,0,-.7)});w.strike(pi/2,2,side,0);double dev=0;for(int i=0;i<700;i++){w.step();dev=w.balls[0].p.x;}return dev;};
     const double left=run(-.45),right=run(.45);
     check(std::abs(left)>.005&&std::abs(right)>.005,"elevated side spin must create lateral motion");
     near(left,-right,1e-6,"masse candidates mirror under side-spin reversal");}
    {c.cueType=1;c.cueElevationDegrees=45;World a(c),b(c);a.reset({ball(0,0,-.8)});b.reset({ball(0,0,-.8)});
     a.strike(pi/2,3,0,0);b.strike(pi/2,3,0,0);for(int i=0;i<100;i++){a.advance(1./60);b.advance(1./120);b.advance(1./120);}
     near(a.balls[0].p.x,b.balls[0].p.x,1e-10,"fixed-step frame-independent x");
     near(a.balls[0].p.y,b.balls[0].p.y,1e-10,"fixed-step frame-independent y");
     near(a.balls[0].height,b.balls[0].height,1e-10,"fixed-step frame-independent height");}
    {c.cueType=0;c.cueElevationDegrees=70;World w(c);w.reset({ball(0,0,-.7)});w.strike(pi/2,2,.45,0);
     V2 early{},later{};for(int i=0;i<251;i++){w.step();if(i==50)early=w.balls[0].p-V2{0,-.7};if(i==250)later=w.balls[0].p-V2{0,-.7};}
     check(std::abs(early.x*later.y-early.y*later.x)>1e-5,"elevated spin path must curve, not only deflect onto a straight line");}
    std::cout<<"PASS: native ballistic flight, jump clearance, grounded collision, spin reversal, and display-rate determinism\n";
}
