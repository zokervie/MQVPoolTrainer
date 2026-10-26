#include "../BankLab/Core/CushionCalibration.hpp"
#include <cassert>
#include <iostream>
using namespace banklab;
int main(){
 for(bool coupled:{false,true})for(int rail=0;rail<4;rail++){
  Config truth;truth.coupledCushions=coupled;truth.individualRails=true;truth.railBounce[rail]=.73;truth.railGrip[rail]=.11;
  std::vector<CushionSample> samples;V2 n=railNormal(rail),t=n.perp();
  for(int i=0;i<40;i++){Ball a;a.v=n*(-(.4+.05*i))+t*((i%5-2)*.3);a.w={double(i%7-3)*8,double(i%3-1)*11};a.spin=(i%9-4)*15;Ball b=a;World::cushionResponse(b,truth,n,rail);assert(World::energy(b,truth)<=World::energy(a,truth)+1e-10);samples.push_back({rail,a,b});}
  Config initial;initial.coupledCushions=coupled;auto fit=fitCushion(samples,initial,rail);assert(std::abs(fit.bounce-.73)<.003);assert(std::abs(fit.grip-.11)<.003);assert(fit.validation<fit.baseline);assert(fit.validationCount==10);
 }
 Config c;c.individualRails=true;c.railBounce[0]=.45;c.railBounce[1]=.95;Ball a;a.v={-1,0};Ball b=a;World::cushionResponse(a,c,{1,0},0);World::cushionResponse(b,c,{1,0},1);assert(b.v.x>a.v.x);
 World w;w.reset({Ball{}});w.strike(.7,2.4,.5,.2);while(w.time<6&&w.moving())w.step();assert(!w.events.empty());assert(std::isfinite(w.balls[0].spin));
 std::cout<<"PASS calibration: synthetic recovery (not real-world validation), holdout, four rail profiles and passive impacts\n";
}
