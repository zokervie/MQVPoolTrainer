#include "../BankLab/Core/Physics.hpp"
#include "../BankLab/Core/CushionContact3D.hpp"
#include <cassert>
#include <iostream>
using namespace banklab;
static World collide(double vy,double spin,double friction=.035){
    Config c;c.width=100;c.length=100;c.sliding=0;c.rolling=0;c.spinDecay=0;
    c.ballRestitution=.94;c.ballFriction=friction;
    World w(c);Ball a;a.id=0;a.p={-2*c.radius,0};a.v={1,vy};a.spin=spin;
    Ball b;b.id=1;w.balls={a,b};w.step(1e-8);assert(w.events.size()==1);return w;
}
int main(){
    const double radius=Config{}.radius;
    for(double vy:{-.6,-.2,0.,.2,.6})for(double spin:{-60.,-10.,0.,10.,60.}){
        auto w=collide(vy,spin),mirror=collide(-vy,-spin);
        const auto&a=w.balls[0];const auto&b=w.balls[1];
        assert(std::abs(a.v.x+b.v.x-1)<1e-10);
        assert(std::abs(a.v.y+b.v.y-vy)<1e-10);
        assert(std::abs(b.v.x-mirror.balls[1].v.x)<1e-8);
        assert(std::abs(b.v.y+mirror.balls[1].v.y)<1e-8);
        assert(std::abs(b.spin+mirror.balls[1].spin)<1e-6);
        const double before=.5*.17*(1+vy*vy)+.2*.17*radius*radius*spin*spin;
        assert(World::energy(a,w.config)+World::energy(b,w.config)<=before+1e-7);
        // Both ball torques arise from the same tangential impulse, with
        // opposite lever arms and opposite forces, not a forced gear ratio.
        assert(std::abs((a.spin-spin)-b.spin)<1e-8);
    }
    assert(collide(0,40).balls[1].spin<0);
    assert(std::abs(collide(0,40,0).balls[1].spin)<1e-9);
    assert(std::abs(collide(.4,-.4/radius).balls[1].spin)<1e-5);
    assert(collide(.4,-.1/radius).balls[1].spin<0); // Can share the cue spin sign.
    assert(collide(.4,-.8/radius).balls[1].spin>0); // Over-gearing reverses transfer.
    using contact3d::Vec;
    const double h=.27,k=std::sqrt(1-h*h);
    for(double spin:{-60.,-20.,20.,60.}){
        Vec incoming{1,.3,0},omega{0,0,spin};
        auto first=contact3d::solve(incoming,omega,{-k,0,-h},radius,.82,.16,.20,true);
        auto second=contact3d::solve(first.velocity,first.omega,{k,0,-h},radius,.82,.16,.20,true);
        auto erased=contact3d::solve(first.velocity,{0,0,0},{k,0,-h},radius,.82,.16,.20,true);
        auto reflected=contact3d::solve({incoming.x,-incoming.y,0},{0,0,-spin},{-k,0,-h},radius,.82,.16,.20,true);
        assert(first.converged&&second.converged);
        assert(first.velocity.x<0&&second.velocity.x>0);
        assert(std::abs(first.velocity.y+reflected.velocity.y)<1e-8);
        assert(std::abs(second.velocity.y-erased.velocity.y)>1e-5);
        assert(std::isfinite(second.omega.z));
    }
    std::cout<<"PASS: gearing, cut/spin transfer, mirror symmetry, passive collisions and spin retained across two opposing cushions\n";
}
