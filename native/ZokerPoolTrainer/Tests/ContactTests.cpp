#include "../BankLab/Core/Physics.hpp"
#include <iostream>
#include <stdexcept>
using namespace banklab;
static int checks=0;
void check(bool b,const char*message){++checks;if(!b)throw std::runtime_error(message);}
void near(double a,double b,double tolerance,const char*message){check(std::abs(a-b)<tolerance,message);}
int main(){try{
    // Independent analytic oracle: equal elastic spheres struck at a prescribed angle.
    // A finite-step overlap normal gave several degrees of error at fast, thin cuts.
    for(double speed:{.2,.5,1.,2.,4.,6.})for(int degrees=5;degrees<=75;degrees+=5)for(int sign:{-1,1}){
        Config c;c.width=100;c.length=100;c.sliding=0;c.rolling=0;c.spinDecay=0;c.ballRestitution=1;c.ballFriction=0;
        World w(c);double phi=degrees*pi/180*sign;
        Ball cue;cue.id=0;cue.p={-2*c.radius*std::cos(phi)-.2137,-2*c.radius*std::sin(phi)};cue.v={speed,0};
        Ball object;object.id=1;w.balls={cue,object};
        for(int i=0;i<6000&&w.events.empty();++i)w.step();
        check(!w.events.empty(),"fast/thin cut contact detected");
        const auto&v=w.balls[1].v;
        near(std::atan2(v.y,v.x),phi,2e-5,"cut outgoing angle matches analytic line of centres");
        near(v.length(),speed*std::cos(phi),2e-5,"cut outgoing speed matches analytic oracle");
        near(w.events[0].time,.2137/speed,2e-6,"contact time matches swept-sphere oracle");
    }
    // Independent plane reflection oracle, with no spin/friction and nose at centre height.
    for(double restitution:{.6,.82,1.})for(double tangent:{-.8,-.3,.1,.5}){
        Config c;c.sliding=0;c.rolling=0;c.spinDecay=0;c.railHeight=0;c.railFriction=0;c.railRestitution=restitution;
        World w(c);Ball b;b.p={.55,.4};b.v={1,tangent};w.balls={b};
        for(int i=0;i<300&&w.events.empty();++i)w.step();
        check(!w.events.empty(),"plane reflection detected");
        near(w.balls[0].v.x,-restitution,1e-8,"normal velocity restitution oracle");
        near(w.balls[0].v.y,tangent,1e-8,"tangent velocity conserved without friction");
    }
    {
        World w;
        V2 cornerA{},cornerB{};
        for(const auto&s:w.segments){
            if(std::abs(s.a.x-.635)<1e-9&&std::abs(s.b.x-.635)<1e-9&&s.b.y>cornerA.y)cornerA=s.b;
            if(std::abs(s.a.y-1.27)<1e-9&&std::abs(s.b.y-1.27)<1e-9&&s.b.x>cornerB.x)cornerB=s.b;
        }
        near((cornerA-cornerB).length(),.1143,1e-12,"114.3 mm standard corner mouth geometry");
        double sideEnd=1;
        for(const auto&s:w.segments)if(std::abs(s.a.x-.635)<1e-9&&std::abs(s.b.x-.635)<1e-9)
            sideEnd=std::min(sideEnd,std::min(std::abs(s.a.y),std::abs(s.b.y)));
        near(2*sideEnd,.127,1e-12,"127 mm standard side mouth geometry");
        near(w.config.radius*(1+w.config.railHeight),.05715*.635,1e-12,"WPA midrange nose height");
        Ball b;b.p={.50,0};b.v={.8,0};w.balls={b};
        for(int i=0;i<3000&&!w.balls[0].sunk;++i)w.step();
        check(w.balls[0].sunk&&w.events.back().b==3,"side pocket accepts a centred approach");
        check(w.balls[0].p.x>.635,"side pocket cannot swallow cue inside playing rectangle");
    }
    std::cout<<"PASS: "<<checks<<" analytic cut/contact, rebound and pocket geometry checks\n";
    return 0;
}catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}}
