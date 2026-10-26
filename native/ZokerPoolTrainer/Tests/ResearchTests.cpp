#include "../BankLab/Core/Physics.hpp"
#include <iostream>
#include <stdexcept>
using namespace banklab;
static double reflected(double speed,double sensitivity){
    Config c;c.sliding=0;c.rolling=0;c.spinDecay=0;c.railHeight=0;c.railFriction=0;
    c.railSpeedSensitivity=sensitivity;
    World world(c);Ball ball;ball.id=0;ball.p={.5,.3};world.reset({ball});world.balls[0].v={speed,0};
    for(int i=0;i<3000&&world.events.empty();i++)world.step();
    if(world.events.empty()||world.events[0].kind!=0)throw std::runtime_error("no rail contact");
    return -world.balls[0].v.x/speed;
}
int main(){
    for(double speed:{.2,1.,3.,6.}){
        if(std::abs(reflected(speed,0)-.82)>1e-8)throw std::runtime_error("baseline regression");
        const double expected=std::clamp(.82-.05*speed,.4,.98);
        if(std::abs(reflected(speed,.05)-expected)>1e-8)throw std::runtime_error("speed-dependent restitution");
    }
    std::cout<<"PASS: optional native ZUPE rail response at four speeds; default preserves v0.9\n";
}
