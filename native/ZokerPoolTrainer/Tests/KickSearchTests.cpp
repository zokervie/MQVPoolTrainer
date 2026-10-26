#include "../BankLab/Core/KickSearch.hpp"
#include <cassert>
#include <iostream>
using namespace banklab;
int main(){
    World w;Ball cue;cue.id=0;cue.p={-.2,-.6};Ball target;target.id=1;target.p={.2,.5};w.reset({cue,target});
    // Direct contact and wrong cushion count must not be interchangeable.
    double direct=std::atan2(1.1,.4);
    assert(evaluateKick(w,1,0,direct,2,0,0).hit);
    assert(!evaluateKick(w,1,1,direct,2,0,0).hit);
    assert(!evaluateKick(w,99,1,direct,2,0,0).hit);
    assert(!evaluateKick(w,1,1,direct,0,0,0).hit);
    // Derive reachable fixtures from a forward shot without a target ball.
    for(int count=1;count<=3;++count){
        bool found=false;
        for(double launch:{.4,.63,.9,1.2,1.8,2.4,3.5,4.3,5.3}){
        World path;path.reset({cue});path.strike(launch,4.0,.15,.2);
        for(int i=0;i<12000;++i){path.step();auto b=path.balls[0];
            if(b.rails==count && b.p.x>-.45&&b.p.x<.45&&std::abs(b.p.y)<1.0){
                target.p=b.p;World fixture;fixture.reset({cue,target});
                // Ensure insertion has not introduced an earlier target contact.
                if(!evaluateKick(fixture,1,count,launch,4,.15,.2).hit)continue;
                auto result=searchKick(fixture,1,count,4,.15,.2);
                assert(result.hit);assert(evaluateKick(fixture,1,count,result.angle,4,.15,.2).hit);
                assert(fixture.time==0 && !fixture.moving() && fixture.events.empty());
                found=true;break;
            }
        }
        if(found)break;
        }
        assert(found);
    }
    // A nearer blocker must invalidate an apparent line to the target.
    Ball blocker;blocker.id=2;blocker.p={0,-.05};w.reset({cue,target,blocker});
    target.p={.2,.5};w.reset({cue,target,blocker});
    assert(!evaluateKick(w,1,0,direct,2,0,0).hit);
    std::cout<<"Kick search: direct, 1/2/3 rails, obstruction, invalid input and nonmutation passed\n";
}
