#pragma once
#include <cmath>
#include <algorithm>
namespace banklab::contact3d {
// SI axes XY on cloth, +Z up. Impulses below are per unit ball mass (m/s).
struct Vec {
 double x=0,y=0,z=0;
 Vec operator+(Vec b)const{return{x+b.x,y+b.y,z+b.z};}
 Vec operator-(Vec b)const{return{x-b.x,y-b.y,z-b.z};}
 Vec operator*(double a)const{return{x*a,y*a,z*a};}
 double dot(Vec b)const{return x*b.x+y*b.y+z*b.z;}
 Vec cross(Vec b)const{return{y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x};}
 double norm()const{return std::sqrt(dot(*this));}
};
inline Vec disk(Vec j,double limit){const double a=j.norm();return a>limit&&a>0?j*(limit/a):j;}
struct Result {Vec velocity,omega,railTangent,slateTangent;double railNormal=0,slateNormal=0,residual=0;int iterations=0;bool converged=true,passivityLimited=false;double effectiveRestitution=0;};
inline Result solveRaw(Vec v,Vec w,Vec normal,double radius,double restitution,double muRail,double muSlate,bool grounded){
 Result out;out.velocity=v;out.omega=w;out.effectiveRestitution=std::clamp(restitution,0.,1.);
 const double length=normal.norm();if(length<1e-12||radius<=0){out.converged=false;return out;}
 normal=normal*(1/length);const Vec arm=normal*(-radius),floorArm{0,0,-radius},up{0,0,1};
 const double approach=(v+w.cross(arm)).dot(normal);if(approach>=0)return out;
 const double target=-std::clamp(restitution,0.,1.)*approach;
 auto apply=[&](Vec r,Vec impulse){out.velocity=out.velocity+impulse;out.omega=out.omega+r.cross(impulse)*(2.5/(radius*radius));};
 auto at=[&](Vec r){return out.velocity+out.omega.cross(r);};
 if(!grounded){
  out.railNormal=target-approach;apply(arm,normal*out.railNormal);
  Vec u=at(arm);out.railTangent=disk((u-normal*u.dot(normal))*(-1/3.5),std::max(0.,muRail)*out.railNormal);apply(arm,out.railTangent);return out;
 }
 // Coupled unilateral rail/slate constraints. Accumulated tangential impulses
 // are projected onto circular Coulomb cones, not independent axis clamps.
 // Inelastic slate constraint here: this is not a landing/restitution event.
 const double invT=3.5;
 for(int i=0;i<512;i++){
  const Vec oldV=out.velocity,oldW=out.omega;
  double next=std::max(0.,out.railNormal+target-at(arm).dot(normal));
  apply(arm,normal*(next-out.railNormal));out.railNormal=next;
  Vec u=at(arm),jt=disk(out.railTangent-(u-normal*u.dot(normal))*(1/invT),std::max(0.,muRail)*next);
  apply(arm,jt-out.railTangent);out.railTangent=jt;
  next=std::max(0.,out.slateNormal-at(floorArm).z);
  apply(floorArm,up*(next-out.slateNormal));out.slateNormal=next;
  u=at(floorArm);jt=disk(out.slateTangent-Vec{u.x,u.y,0}*(1/invT),std::max(0.,muSlate)*next);
  apply(floorArm,jt-out.slateTangent);out.slateTangent=jt;
  out.residual=std::max((out.velocity-oldV).norm(),(out.omega-oldW).norm()*radius);out.iterations=i+1;
  if(out.residual<1e-11)break;
 }
 out.converged=out.residual<1e-9;
 return out;
}
inline Result solve(Vec v,Vec w,Vec normal,double radius,double restitution,double muRail,double muSlate,bool grounded){
 auto out=solveRaw(v,w,normal,radius,restitution,muRail,muSlate,grounded);
 auto kinetic=[&](const Result&a){return .5*a.velocity.dot(a.velocity)+.2*radius*radius*a.omega.dot(a.omega);};
 const double before=.5*v.dot(v)+.2*radius*radius*w.dot(w),limit=before+1e-11*std::max(1.,before);
 if(grounded&&kinetic(out)>limit){
    // Newton restitution with simultaneous frictional contacts is not always
    // passive. Re-solve the constraints at an admissible restitution target;
    // never scale the resulting velocities or violate the Coulomb disks.
    double lo=0,hi=std::clamp(restitution,0.,1.);Result best=solveRaw(v,w,normal,radius,0,muRail,muSlate,true);
    for(int i=0;i<28;i++){double mid=(lo+hi)/2;auto candidate=solveRaw(v,w,normal,radius,mid,muRail,muSlate,true);
        if(candidate.converged&&kinetic(candidate)<=limit){lo=mid;best=candidate;}else hi=mid;}
    out=best;out.passivityLimited=true;out.effectiveRestitution=lo;
 }
 return out;
}

}
