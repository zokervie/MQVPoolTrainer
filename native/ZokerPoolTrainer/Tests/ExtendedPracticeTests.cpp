#include "../BankLab/Core/Physics.hpp"
#include <iostream>
using namespace banklab;
static Ball ball(int id,V2 p){Ball b;b.id=id;b.p=p;return b;}
static void run(World&w){for(int i=0;i<960*30&&w.moving();++i)w.step();}
int main(){
    int goals=0;
    for(double target:{-.2,.1,.4,.7,1.0}){
        bool found=false;
        for(double speed=.2;speed<=1.21&&!found;speed+=.025){
            World w;w.reset({ball(0,{0,-.9})});w.strike(pi/2,speed,0,.4);run(w);
            found=!w.balls[0].sunk&&(w.balls[0].p-V2{0,target}).length()<.09;
        }
        if(!found){std::cerr<<"FAIL: stopping zone unreachable "<<target<<"\n";return 1;}++goals;
    }
    for(int degrees:{15,30,45,60})for(double mirror:{-1.,1.}){
        V2 d=V2{.42,.755}.unit();double a=degrees*pi/180;
        V2 direction{(d.x*std::cos(a)-d.y*std::sin(a))*mirror,d.x*std::sin(a)+d.y*std::cos(a)};
        V2 object{.25*mirror,.55},ghost=object-V2{d.x*mirror,d.y}*.05715,cue=ghost-direction*.65;
        bool found=false;
        for(int adjustment=-4;adjustment<=4&&!found;++adjustment)for(double speed=.5;speed<=3.51&&!found;speed+=.25){
            World w;w.reset({ball(0,cue),ball(1,object)});
            w.strike(std::atan2(direction.y,direction.x)+adjustment*.25*pi/180,speed,0,0);run(w);
            bool pot=false;for(const auto&e:w.events)if(e.kind==2&&e.a==1&&e.b>=0)pot=true;
            found=pot&&!w.balls[0].sunk;
        }
        if(!found){std::cerr<<"FAIL: cut drill unreachable "<<degrees<<" / "<<mirror<<"\n";return 1;}++goals;
    }
    std::cout<<"PASS: "<<goals<<" added practice goals have successful simulated shots\n";
}
