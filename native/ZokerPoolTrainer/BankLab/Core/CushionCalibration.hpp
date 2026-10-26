#pragma once
#include "Physics.hpp"
#include <limits>
namespace banklab {
struct CushionSample {int rail;Ball before,after;};
struct CushionFit {double bounce=.82,grip=.16,train=0,validation=0,baseline=0;int trainingCount=0,validationCount=0;};
inline V2 railNormal(int i){return i==0?V2{1,0}:i==1?V2{-1,0}:i==2?V2{0,1}:V2{0,-1};}
inline double cushionError(const CushionSample&s,const Config&c){
 Ball p=s.before;World::cushionResponse(p,c,railNormal(s.rail),s.rail);
 V2 dv=p.v-s.after.v,dw=(p.w-s.after.w)*c.radius;double ds=(p.spin-s.after.spin)*c.radius;
 return (dv.dot(dv)+dw.dot(dw)+ds*ds)/5;
}
inline CushionFit fitCushion(const std::vector<CushionSample>&samples,Config c,int rail){
 CushionFit fit;auto loss=[&](bool holdout){double sum=0;int n=0;for(size_t i=0;i<samples.size();i++)if((i%4==0)==holdout){sum+=cushionError(samples[i],c);n++;}return n?std::sqrt(sum/n):0;};
 fit.baseline=loss(true);c.individualRails=true;double best=std::numeric_limits<double>::infinity();
 double centerE=c.bounce(rail),centerM=c.grip(rail),rangeE=.58,rangeM=.35;
 for(int pass=0;pass<3;pass++){
  double winnerE=centerE,winnerM=centerM;
  for(int a=0;a<=30;a++)for(int b=0;b<=30;b++){
   double e=pass==0?.4+.58*a/30:std::clamp(centerE-rangeE+2*rangeE*a/30,.4,.98);
   double m=pass==0?.35*b/30:std::clamp(centerM-rangeM+2*rangeM*b/30,0.,.35);
   c.railBounce[rail]=e;c.railGrip[rail]=m;double error=loss(false);
   if(error<best){best=error;winnerE=e;winnerM=m;}
  }
  centerE=winnerE;centerM=winnerM;rangeE=pass==0?.03:rangeE/10;rangeM=pass==0?.02:rangeM/10;
 }
 c.railBounce[rail]=centerE;c.railGrip[rail]=centerM;fit.bounce=centerE;fit.grip=centerM;fit.train=loss(false);fit.validation=loss(true);
 for(size_t i=0;i<samples.size();i++)if(i%4==0)fit.validationCount++;else fit.trainingCount++;
 return fit;
}
}
