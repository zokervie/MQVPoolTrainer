#pragma once
#include "Physics.hpp"
#include <limits>

namespace banklab {
// An inverse query against the existing forward model, not an empirical law.
// Fix speed/contact/settings, search angle, and verify the first ball contact.
struct KickResult { double angle=0, clearance=std::numeric_limits<double>::infinity(); bool hit=false; };
inline KickResult evaluateKick(const World& source,int target,int rails,double angle,double speed,double side,double top,double horizon=10) {
    KickResult result;result.angle=angle;
    World w=source;
    auto cue=std::find_if(w.balls.begin(),w.balls.end(),[](const Ball& b){return b.id==0&&!b.sunk;});
    auto object=std::find_if(w.balls.begin(),w.balls.end(),[&](const Ball& b){return b.id==target&&!b.sunk;});
    if(cue==w.balls.end()||object==w.balls.end()||target==0||rails<0||rails>3||w.moving()||!std::isfinite(speed)||speed<=0||!std::isfinite(angle)||!std::isfinite(side)||!std::isfinite(top))return result;
    const V2 goal=object->p;
    w.strike(angle,speed,side,top);
    for(int step=0;step<int(horizon/World::stepSize);++step){
        V2 previous=cue->p;int oldRails=cue->rails;
        const size_t eventCount=w.events.size();w.step();
        // Stop at the first cue-ball/object contact: a carom is not a kick solution.
        for(size_t i=eventCount;i<w.events.size();++i){const auto& e=w.events[i];
            if(e.kind==1&&(e.a==0||e.b==0)){
                result.hit=(e.a==target||e.b==target)&&cue->rails==rails;
                if(result.hit)result.clearance=0;
                return result;
            }
        }
        if(cue->sunk||cue->rails>rails)return result;
        // Never interpolate across a cushion event or a change in height.
        if(cue->rails==rails&&oldRails==rails&&cue->height<1e-5){
            V2 d=cue->p-previous;double denom=d.dot(d);
            double t=denom>1e-18?std::clamp((goal-previous).dot(d)/denom,0.0,1.0):0;
            result.clearance=std::min(result.clearance,std::max(0.0,(previous+d*t-goal).length()-2*w.config.radius));
        }
        if(!w.moving())break;
    }
    return result;
}
inline KickResult searchKick(const World& world,int target,int rails,double speed,double side,double top){
    // Finite angular search. Failure means no solution found at this resolution,
    // never proof that the physical shot is impossible.
    std::vector<KickResult> seeds;
    for(int i=0;i<360;++i){auto r=evaluateKick(world,target,rails,2*pi*i/360,speed,side,top);if(r.hit)return r;seeds.push_back(r);}
    std::sort(seeds.begin(),seeds.end(),[](const KickResult&a,const KickResult&b){return a.clearance<b.clearance;});
    KickResult best=seeds.front();
    for(size_t i=0;i<8;++i){auto local=seeds[i];double delta=pi/180;
        for(int pass=0;pass<7;++pass){
            auto left=evaluateKick(world,target,rails,local.angle-delta,speed,side,top);
            auto right=evaluateKick(world,target,rails,local.angle+delta,speed,side,top);
            if(left.hit)return left;
            if(right.hit)return right;
            if(left.clearance<local.clearance)local=left;
            if(right.clearance<local.clearance)local=right;
            delta*=.5;
        }
        if(local.clearance<best.clearance)best=local;
    }
    return best;
}
}
