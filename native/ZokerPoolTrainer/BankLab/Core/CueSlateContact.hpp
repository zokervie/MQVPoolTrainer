#pragma once
// Ported unchanged from ZokerPoolTrainer-0.11 c5c2db3 (build 28, 29/10/2026).
#include "CushionContact3D.hpp"
namespace banklab::cuecontact {
using contact3d::Vec;
struct Launch {
    Vec velocity{},omega{};
    double cueSpeedAfter=0,cueImpulse=0,floorNormal=0,residual=0;
    bool valid=false,restitutionLimited=false;
};
// Research coupled axial cue / grounded sphere / slate impact. The cue has a
// finite effective mass; the contact is allowed to rotate the ball. This is an
// instantaneous rigid-impact approximation, not a measured soft-tip duration.
inline Launch raw(Vec direction,Vec arm,double cueSpeed,double radius,double ballMass,double cueMass,double restitution,double mu){
    Launch out;out.cueSpeedAfter=cueSpeed;
    const double ratio=ballMass/cueMass,inverse=1+2.5*arm.cross(direction).dot(arm.cross(direction))/(radius*radius)+ratio;
    const Vec up{0,0,1},floorArm{0,0,-radius};Vec floorTangent{};
    auto at=[&](Vec r){return out.velocity+out.omega.cross(r);};
    auto apply=[&](Vec r,Vec j){out.velocity=out.velocity+j;out.omega=out.omega+r.cross(j)*(2.5/(radius*radius));};
    for(int i=0;i<768;i++){
        const Vec oldV=out.velocity,oldW=out.omega;const double oldCue=out.cueSpeedAfter;
        double next=std::max(0.,out.cueImpulse+((1+restitution)*cueSpeed-at(arm).dot(direction)-ratio*out.cueImpulse)/inverse);
        apply(arm,direction*(next-out.cueImpulse));out.cueImpulse=next;out.cueSpeedAfter=cueSpeed-ratio*next;
        next=std::max(0.,out.floorNormal-at(floorArm).z);apply(floorArm,up*(next-out.floorNormal));out.floorNormal=next;
        const Vec slip=at(floorArm);const Vec jt=contact3d::disk(floorTangent-Vec{slip.x,slip.y,0}*(1/3.5),mu*out.floorNormal);
        apply(floorArm,jt-floorTangent);floorTangent=jt;
        out.residual=std::max({(out.velocity-oldV).norm(),(out.omega-oldW).norm()*radius,std::abs(out.cueSpeedAfter-oldCue)});
        if(out.residual<1e-11)break;
    }
    out.valid=out.residual<1e-9&&out.velocity.z>=-1e-9&&std::isfinite(out.velocity.norm()+out.omega.norm());
    return out;
}
inline Launch solve(Vec direction,Vec arm,double cueSpeed,double radius,double ballMass,double cueMass,double restitution,double mu){
    if(!std::isfinite(cueSpeed+radius+ballMass+cueMass+restitution+mu+direction.norm()+arm.norm())||cueSpeed<=0||radius<=0||ballMass<=0||cueMass<=0||mu<0||std::abs(direction.norm()-1)>1e-8)return {};
    const double e=std::clamp(restitution,0.,1.);
    auto energy=[&](const Launch& a){return .5*ballMass*a.velocity.dot(a.velocity)+.2*ballMass*radius*radius*a.omega.dot(a.omega)+.5*cueMass*a.cueSpeedAfter*a.cueSpeedAfter;};
    const double limit=.5*cueMass*cueSpeed*cueSpeed+1e-10;
    auto out=raw(direction,arm,cueSpeed,radius,ballMass,cueMass,e,mu);
    if(out.valid&&energy(out)<=limit)return out;
    auto best=raw(direction,arm,cueSpeed,radius,ballMass,cueMass,0,mu);
    if(!best.valid||energy(best)>limit)return {};
    double lo=0,hi=e;
    for(int i=0;i<24;i++){
        const double mid=(lo+hi)/2;auto candidate=raw(direction,arm,cueSpeed,radius,ballMass,cueMass,mid,mu);
        if(candidate.valid&&energy(candidate)<=limit){lo=mid;best=candidate;}else hi=mid;
    }
    best.restitutionLimited=true;return best;
}
}
