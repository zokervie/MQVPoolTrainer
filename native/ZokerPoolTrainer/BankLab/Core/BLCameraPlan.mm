#import "BLCameraPlan.h"
#include "CameraPlanner.hpp"
#include <memory>
namespace bc=banklab::camera;
static simd_float3 BLSceneVector(bc::V3 p){return simd_make_float3(static_cast<float>(p.x),static_cast<float>(p.z),static_cast<float>(p.y));}
@implementation BLCameraPlan { std::unique_ptr<bc::Planner> _plan; }
- (instancetype)initWithFrameCount:(NSInteger)n times:(const double *)times ballCount:(NSInteger)m ids:(const int *)ids
        xs:(const double *)xs ys:(const double *)ys sunk:(const uint8_t *)sunk events:(NSArray<NSDictionary<NSString*,NSNumber*>*> *)events
        aimAngle:(double)aimAngle style:(BLCameraStyle)style aspect:(double)aspect lead:(double)lead tail:(double)tail {
    if((self=[super init])){
        bc::Recording r;
        const std::size_t frames=static_cast<std::size_t>(std::max<NSInteger>(0,n)),balls=static_cast<std::size_t>(std::max<NSInteger>(0,m));
        const bool ok=frames>0&&balls>0&&times&&ids&&xs&&ys&&sunk;
        if(ok){
            r.m=static_cast<int>(balls);
            r.times.assign(times,times+frames);r.ids.assign(ids,ids+balls);
            r.xs.assign(xs,xs+frames*balls);r.ys.assign(ys,ys+frames*balls);r.sunk.assign(sunk,sunk+frames*balls);
        }
        for(NSDictionary<NSString*,NSNumber*> *e in events){
            bc::RecEvent ev;ev.kind=e[@"kind"].intValue;ev.a=e[@"a"].intValue;ev.b=e[@"b"].intValue;ev.time=e[@"time"].doubleValue;
            ev.x=e[@"x"].doubleValue;ev.y=e[@"y"].doubleValue;ev.impact=e[@"impact"].doubleValue;r.events.push_back(ev);
        }
        _plan=std::make_unique<bc::Planner>(std::move(r),aimAngle,static_cast<bc::Style>(std::clamp<NSInteger>(style,0,8)),aspect,lead,tail);
    }
    return self;
}
- (void)poseAt:(double)t eye:(simd_float3 *)eye target:(simd_float3 *)target fov:(float *)fovDegrees {
    const bc::Pose p=_plan->pose(t);
    if(eye)*eye=BLSceneVector(p.eye);
    if(target)*target=BLSceneVector(p.target);
    if(fovDegrees)*fovDegrees=static_cast<float>(p.fov);
}
- (double)rateAt:(double)t{return _plan->rate(t);}
- (BLCameraScene)sceneKindAt:(double)t{return static_cast<BLCameraScene>(static_cast<int>(_plan->sceneKind(t)));}
- (NSInteger)sceneIndexAt:(double)t{return _plan->sceneIndex(t);}
- (NSInteger)sceneCount{return static_cast<NSInteger>(_plan->sceneList().size());}
- (double)sceneStart:(NSInteger)index{
    const auto& s=_plan->sceneList();
    if(s.empty())return _plan->startTime();
    return s[static_cast<std::size_t>(std::clamp<NSInteger>(index,0,static_cast<NSInteger>(s.size())-1))].t0;
}
- (double)trailRevealAt:(double)t{return _plan->trailReveal(t);}
- (double)bestStillTime{return _plan->bestStill;}
- (double)wallDuration{return _plan->wallDuration;}
- (double)peakAngularSpeed{return _plan->peakAngular;}
- (double)p95AngularSpeed{return _plan->p95Angular;}
- (double)minVisibleFraction{return _plan->minVisible;}
- (double)startTime{return _plan->startTime();}
- (double)endTime{return _plan->endTime();}
- (NSInteger)subjectBallAt:(double)t{return _plan->subjectBall(t);}
- (double)contactTime{return _plan->contactTime;}
- (double)potTime{return _plan->potTime;}
+ (double)recommendedLead{return bc::Planner::recommendedLead;}
+ (double)recommendedTail{return bc::Planner::recommendedTail;}
@end
