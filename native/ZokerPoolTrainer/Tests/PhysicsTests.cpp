#include "../BankLab/Core/Physics.hpp"
#include <iostream>
#include <stdexcept>
#include <random>
using namespace banklab;
static int checks=0;
void check(bool condition,const char*name){checks++;if(!condition)throw std::runtime_error(name);}
void near(double a,double b,double eps,const char*name){check(std::abs(a-b)<eps,name);}
Ball ball(int id,V2 p,V2 v={}){Ball b;b.id=id;b.p=p;b.v=v;return b;}
Config frictionless(){Config c;c.width=100;c.length=100;c.rolling=0;c.sliding=0;c.spinDecay=0;c.ballFriction=0;c.ballRestitution=1;return c;}
int main(){try{
    {
        World w(frictionless());w.balls={ball(0,{-0.1,0},{1,0}),ball(1,{0,0})};
        for(int i=0;i<100;i++)w.step();
        near(w.balls[0].v.x,0,1e-9,"head-on transfer cue stops");near(w.balls[1].v.x,1,1e-9,"head-on object speed");
    }
    {
        World w(frictionless());w.balls={ball(0,{-0.12,-0.025},{2,0}),ball(1,{0,0})};
        double energy=World::energy(w.balls[0],w.config);for(int i=0;i<100;i++)w.step();
        near(World::energy(w.balls[0],w.config)+World::energy(w.balls[1],w.config),energy,1e-8,"cut conserves elastic energy");
        near(w.balls[0].v.x+w.balls[1].v.x,2,1e-8,"cut conserves x momentum");
        near(w.balls[0].v.y+w.balls[1].v.y,0,1e-8,"cut conserves y momentum");
        near(w.balls[0].v.dot(w.balls[1].v),0,1e-8,"cut 90-degree tangent relation");
    }
    {
        Config c=frictionless();c.sliding=.2;World w(c);w.balls={ball(0,{0,0},{1,0})};
        for(int i=0;i<960;i++)w.step();
        near(w.balls[0].v.x,5.0/7,1e-7,"sliding becomes rolling 5/7 speed");
        near((w.balls[0].v+w.balls[0].w.perp()*c.radius).length(),0,1e-7,"rolling contact has no slip");
    }
    {
        Config c=frictionless();c.rolling=.012;World w(c);Ball b=ball(0,{0,0},{1,0});b.w=b.v.perp()/c.radius;w.balls={b};
        for(int i=0;i<10000;i++)w.step();
        near(w.balls[0].p.x,1/(2*.012*9.81),1e-6,"rolling stopping distance");check(!w.moving(),"rolling stops without oscillation");
    }
    {
        Config c=frictionless();c.sliding=.2;World w(c);Ball b=ball(0,{-0.12,0},{2,0});b.w={0,-100};w.balls={b,ball(1,{0,0})};
        for(int i=0;i<180;i++){w.step();}
        check(w.balls[0].v.x<-.1,"draw reverses cue after contact");
    }
    {
        Config c;c.rolling=0;c.sliding=0;c.spinDecay=0;c.railHeight=0;c.railFriction=0;c.railRestitution=.82;
        World w(c);w.balls={ball(0,{.55,.35},{1,0})};for(int i=0;i<100;i++)w.step();
        near(w.balls[0].v.x,-.82,1e-8,"rail restitution");check(w.balls[0].rails==1,"single rail event");
    }
    {
        Config c;c.rolling=0;c.sliding=0;c.spinDecay=0;World a(c),b(c);
        a.balls={ball(0,{.55,.35},{1,.3})};b.balls=a.balls;a.balls[0].spin=50;b.balls[0].spin=-50;
        for(int i=0;i<100;i++){a.step();b.step();}check(std::abs(a.balls[0].v.y-b.balls[0].v.y)>.1,"side spin changes rail angle");
    }
    {
        Config c=frictionless();c.width=1.27;c.length=2.54;World w(c);w.balls={ball(0,{.5,0},{1,0})};
        for(int i=0;i<250;i++){w.step();}
        check(w.balls[0].sunk,"side pocket opening catches ball");
        check(w.events.back().kind==2&&w.events.back().b==3,"right side pocket identity");
    }
    {
        Config c=frictionless();c.width=1.27;c.length=2.54;World w(c);w.balls={ball(0,{.48,1.11},{1,1})};
        for(int i=0;i<250;i++){w.step();}
        check(w.balls[0].sunk,"corner mouth catches diagonal shot");
    }
    {
        World a,b;a.reset({ball(0,{0,-.4})});b.reset(a.balls);a.strike(.9,2,.3,.1);b.strike(.9,2,.3,.1);
        for(int i=0;i<120;i++){a.advance(1.0/60);}
        for(int i=0;i<60;i++){b.advance(1.0/30);}
        near(a.balls[0].p.x,b.balls[0].p.x,1e-9,"30 vs 60 Hz x deterministic");near(a.balls[0].p.y,b.balls[0].p.y,1e-9,"30 vs 60 Hz y deterministic");
    }
    {
        World w;w.reset({ball(0,{0,.3})});auto p=w.idealGuide({0,.3},.4,4);
        check(p.size()>=3&&p.size()<=6,"multi rail guide bounded");
        for(auto a:p)check(std::abs(a.x)<=.636&&std::abs(a.y)<=1.271,"guide within table");
        w.reset({ball(0,{0,0}),ball(1,{.3,0})});p=w.idealGuide({0,0},0,4);near(p.back().x,.3-2*w.config.radius,1e-8,"guide stops at object contact");
    }
    {
        std::mt19937 gen(99);std::uniform_real_distribution<double> u(-1,1);
        for(int k=0;k<1000;k++){
            Config c;c.sliding=0;c.rolling=0;c.spinDecay=0;World w(c);
            Ball a=ball(0,{c.width/2-c.railRadius()+.0001,.4},{.1+5*std::abs(u(gen)),3*u(gen)});
            a.w={100*u(gen),100*u(gen)};a.spin=150*u(gen);w.balls={a};
            double before=World::energy(a,c);w.step();
            check(World::energy(w.balls[0],c)<=before+1e-9,"isolated rail contact dissipates energy");
        }
    }
    {
        // Stress all spin combinations and strikes: stable, finite, bounded energy.
        std::mt19937 gen(42);std::uniform_real_distribution<double> a(-pi,pi),s(-.7,.7),v(.1,6);
        for(int k=0;k<150;k++){
            World w;w.reset({ball(0,{0,-.4}),ball(1,{.12,.3}),ball(2,{-.2,.6})});w.strike(a(gen),v(gen),s(gen),s(gen));
            double initial=0;for(auto b:w.balls)initial+=World::energy(b,w.config);
            double peak=initial;
            for(int i=0;i<960*12&&w.moving();i++){w.step();double e=0;for(auto b:w.balls){check(std::isfinite(b.p.x)&&std::isfinite(b.p.y),"stress finite positions");e+=World::energy(b,w.config);}peak=std::max(peak,e);}
            check(peak<=initial*1.0001+1e-8,"passive contacts cannot add energy");
        }
    }
    {
        Config c;c.sliding=0;c.rolling=0;c.spinDecay=0;c.railFriction=0;c.railHeight=.4;
        World w(c);Ball b=ball(0,{c.width/2-c.railRadius()+.00001,.4},{1,.2});b.w={3,4};b.spin=5;w.balls={b};w.step();
        near(w.balls[0].v.x,1-(1+c.railRestitution)*(1-.4*.4),1e-8,"tilted radial normal response");
        near(w.balls[0].v.y,.2,1e-8,"frictionless rail preserves tangent velocity");
        near(w.balls[0].w.x,3,1e-8,"radial normal cannot create x torque");
        near(w.balls[0].w.y,4,1e-8,"radial normal cannot create y torque");
        near(w.balls[0].spin,5,1e-8,"radial normal cannot create side spin");
    }
    {
        Config c=frictionless();c.ballFriction=.1;
        World w(c);Ball a=ball(0,{-2*c.radius+.00001,0},{1,0});a.w={0,20};
        w.balls={a,ball(1,{0,0})};double e=World::energy(a,c);w.step();
        check(w.balls[1].w.y<0,"vertical contact slip transfers topspin as opposite spin");
        check(w.balls[0].w.y<20,"contact reduces incident topspin");
        check(World::energy(w.balls[0],c)+World::energy(w.balls[1],c)<=e+1e-9,"3D tangential contact dissipates energy");
    }
    std::cout<<"PASS: "<<checks<<" physics assertions\n";return 0;
}catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<" after "<<checks<<" checks\n";return 1;}}
