#include "../BankLab/Core/Physics.hpp"
#include <iostream>
#include <stdexcept>
using namespace banklab;
static Ball ball(int id,V2 p){Ball b;b.id=id;b.p=p;return b;}
static void simulate(World& w){for(int n=0;n<960*45 && w.moving();++n)w.step();}
int main(){
    // Reachability, NOT empirical accuracy. Same layouts as Models.swift 10–13.
    const V2 targets[]={{0,.55},{.3044,.5789},{.50,.97},{.17,.31}};
    const double radii[]={.15,.10,.12,.12};
    for(int goal=0;goal<4;++goal){
        bool found=false;
        for(int si=3;si<=50 && !found;++si){
            for(int ti=-7;ti<=7 && !found;++ti){
                World w;
                if(goal==0)w.reset({ball(0,{0,-.85})});
                else w.reset({ball(0,{.02,.01}),ball(1,{.33,.63})});
                w.strike(goal==0 ? pi/2:std::atan2(.62,.31),si*.1,0,ti*.1);
                simulate(w);
                bool pot=goal==0;
                for(const auto&e:w.events)if(e.kind==2&&e.a==1&&e.b>=0)pot=true;
                const Ball& cue=w.balls[0];
                found=!w.moving()&&!cue.sunk&&pot&&(cue.p-targets[goal]).length()<=radii[goal];
                if(found)std::cout<<"Goal "<<goal<<" reachable: speed="<<si*.1<<", top="<<ti*.1<<"\n";
            }
        }
        if(!found){std::cerr<<"FAIL: goal "<<goal<<" unreachable in scan\n";return 1;}
    }
    std::cout<<"PASS: four target-zone drills have successful simulated shots\n";
}
