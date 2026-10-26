#include "../BankLab/Core/Physics.hpp"
#include <cassert>
#include <iostream>
using namespace banklab;
int main(){Config c;c.coupledCushions=true;World a(c),b(c);a.reset({Ball{}});b.reset({Ball{}});a.strike(.4,3,.4,.2);b.strike(.4,3,.4,.2);
 for(int i=0;i<300;i++){double dt=(i%3==0?1./30:1./60);a.advance(dt);b.advance(dt);auto before=a.balls;auto p=a.presentation();assert(p.size()==before.size());assert(a.balls[0].p.x==before[0].p.x);assert(a.balls[0].v.x==b.balls[0].v.x);assert(a.balls[0].p.x==b.balls[0].p.x);assert(std::hypot(p[0].p.x-before[0].p.x,p[0].p.y-before[0].p.y)<.02);}
 assert(a.events.size()==b.events.size());a.reset({Ball{}});assert(a.presentation()[0].p.x==0);std::cout<<"PASS presentation: variable frame intervals, nonmutation, physics equality and reset\n";
}
