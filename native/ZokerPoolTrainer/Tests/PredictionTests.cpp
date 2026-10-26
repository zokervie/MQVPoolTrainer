#include "../BankLab/Core/Physics.hpp"
#include <iostream>
#include <stdexcept>
using namespace banklab;
static Ball ball(int id,V2 p){Ball b;b.id=id;b.p=p;return b;}
static void near(double a,double b,const char*label){if(std::abs(a-b)>1e-9)throw std::runtime_error(label);}
int main(){try{
    Config c;c.width=100;c.length=100;c.rolling=0;c.sliding=.2;c.spinDecay=0;
    World sliding(c);sliding.reset({ball(0,{0,0})});sliding.strike(0,1,0,0);sliding.step(.1);
    near(sliding.balls[0].v.x,1-.2*9.81*.1,"sliding deceleration must be mu*g");
    near(sliding.balls[0].p.x,.1-.5*.2*9.81*.1*.1,"sliding displacement must integrate acceleration");
    World follow(c);follow.reset({ball(0,{0,0})});follow.strike(0,1,0,.6);follow.step(.01);
    near(follow.balls[0].v.x,1+.2*9.81*.01,"overspin accelerates centre until no-slip");
    c.rolling=.012;World rolling(c);Ball b=ball(0,{0,0});b.v={1,0};b.w={0,1/c.radius};rolling.balls={b};rolling.step(.1);
    near(rolling.balls[0].v.x,1-.012*9.81*.1,"rolling deceleration is distinct from sliding");
    Config freeConfig=c;freeConfig.rolling=0;freeConfig.sliding=0;
    World rotation(freeConfig);Ball rollingBall=ball(0,{0,0});
    rollingBall.v={1,0};rollingBall.w={0,1/freeConfig.radius};rotation.balls={rollingBall};
    rotation.step(pi*freeConfig.radius);
    near(std::abs(rotation.balls[0].rotation.y),1,"half circumference requires half turn");
    near(rotation.balls[0].rotation.w,0,"half turn quaternion scalar");
    World render30(freeConfig),render60(freeConfig);render30.balls={rollingBall};render60.balls={rollingBall};
    for(int i=0;i<60;++i)render60.advance(1.0/60);
    for(int i=0;i<30;++i)render30.advance(1.0/30);
    near(render30.balls[0].rotation.y,render60.balls[0].rotation.y,"rotation must not depend on render rate");
    near(render30.balls[0].rotation.w,render60.balls[0].rotation.w,"rotation scalar must not depend on render rate");
    World source;source.reset({ball(0,{-.2,-.6}),ball(1,{.1,.35})});
    const auto predicted=source.predict(1.2,2.3,.35,-.2);
    near(source.time,0,"preview must not advance live time");
    near(source.balls[0].p.x,-.2,"preview must not mutate live positions");
    if(!source.events.empty()||predicted.empty())throw std::runtime_error("preview state isolation");
    World live(source.config);live.reset(source.balls);live.strike(1.2,2.3,.35,-.2);
    int steps=0;
    for(const auto&p:predicted){
        const int wanted=static_cast<int>(std::llround(p.time/World::stepSize));
        while(steps<wanted){live.step();++steps;}
        const Ball& actual=live.balls[static_cast<size_t>(p.id)];
        near(p.p.x,actual.p.x,"prediction/live x mismatch");near(p.p.y,actual.p.y,"prediction/live y mismatch");
        if(p.sunk!=actual.sunk)throw std::runtime_error("prediction/live pocket mismatch");
    }
    std::cout<<"PASS: analytic acceleration and prediction/live consistency ("<<predicted.size()<<" samples)\n";
    return 0;
}catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}}
