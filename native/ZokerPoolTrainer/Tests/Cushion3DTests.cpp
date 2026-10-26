#include "../BankLab/Core/CushionContact3D.hpp"
#include "../BankLab/Core/Physics.hpp"
#include <cassert>
#include <iostream>
#include <random>
using namespace banklab;using contact3d::Vec;
double energy(Vec v,Vec w,double r){return .5*v.dot(v)+.2*r*r*w.dot(w);}
int main(){Config c;double r=c.radius,h=c.railHeight,k=std::sqrt(1-h*h);Vec n{k,0,-h};
 assert(std::abs(c.railNoseHeightMeters()-.03629025)<1e-12);
 for(bool ground:{false,true})for(int i=-8;i<=8;i++)for(int j=-8;j<=8;j++){
 Vec v{-1.5,.2*j,0},w{double(i)*9,double(j)*11,double(i-j)*7};auto o=contact3d::solve(v,w,n,r,.82,.16,.2,ground);
 assert(o.converged);assert(o.railNormal>=0&&o.slateNormal>=0);assert(o.railTangent.norm()<=.16*o.railNormal+1e-10);assert(o.slateTangent.norm()<=.2*o.slateNormal+1e-10);assert(std::abs(o.railTangent.dot(n))<1e-10);assert(energy(o.velocity,o.omega,r)<=energy(v,w,r)+1e-8);assert(std::abs(o.velocity.dot(n)-1.5*k*o.effectiveRestitution)<1e-8);if(ground)assert(o.velocity.z>=-1e-9);
 }
 auto a=contact3d::solve({-1,0,0},{0,0,0},n,r,.8,0,0,false);assert(a.velocity.z<0&&a.omega.norm()<1e-10);
 auto b=contact3d::solve({-1,0,0},{0,0,0},n,r,.8,0,0,true);assert(std::abs(b.velocity.z)<1e-10&&std::abs(b.velocity.x-.8)<1e-10);
 auto l=contact3d::solve({-1,.4,0},{0,0,40},n,r,.8,.2,.2,true),rr=contact3d::solve({-1,-.4,0},{0,0,-40},n,r,.8,.2,.2,true);assert(std::abs(l.velocity.y+rr.velocity.y)<1e-10);
 std::mt19937 generator(42);std::uniform_real_distribution<double> random(-1,1);int limited=0;
 for(int i=0;i<10000;i++){
   Vec v{-(.01+8*std::abs(random(generator))),8*random(generator),0},w{500*random(generator),500*random(generator),500*random(generator)};
   const double e=i%2?.4:.98,mu=i%3?.35:0;
   auto out=contact3d::solve(v,w,n,r,e,mu,.35,true);
   assert(out.converged);assert(energy(out.velocity,out.omega,r)<=energy(v,w,r)+1e-7);
   assert(out.railTangent.norm()<=mu*out.railNormal+1e-8);assert(out.slateTangent.norm()<=.35*out.slateNormal+1e-8);
   assert(std::abs(out.velocity.dot(n)-(-v.dot(n))*out.effectiveRestitution)<1e-7);
   if(out.passivityLimited)limited++;
 }
 assert(limited>0);
 c.coupledCushions=true;World world(c);world.reset({Ball{}});world.strike(.4,3,.4,.2);while(world.time<8&&world.moving())world.step();int count=0;for(auto&e:world.events)if(e.kind==0)count++;assert(count>=2);assert(std::isfinite(world.balls[0].spin));
 std::cout<<"PASS A1: geometry, free/grounded response, Coulomb disks, restitution, passivity, symmetry, multi-rail state\n";
}
