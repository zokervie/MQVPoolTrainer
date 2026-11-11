#include "CushionCalibration.hpp"
#import "BLWorld.h"
#include "Physics.hpp"
#include "KickSearch.hpp"
#include <memory>
using namespace banklab;
@implementation BLWorld { std::unique_ptr<World> _world; }
// App physics profile: Config::app() in Physics.hpp (0.30). History 0.21: Core Config defaults stay at the literature/regression values; the app uses:
//  - rail grip-slip beta .30 and side-spin decay 11 rad/s^2: fitted to clip c-ZBSi9KBfc ("Reverse bank zigzag",
//    rectified track of the 8-ball over 4 cushions), Tests/ReverseZigzagTests.cpp. Single clip = measured, not general.
//  - squirt only with a raised cue (owner decision), break-cue gain 1.4 [design].
- (instancetype)init { if((self=[super init])){_world=std::make_unique<World>(Config::app());}return self; }
- (const void *)zokerCoreWorld { return _world.get(); }   // BLOpponent only (copies it on the main thread)
- (BOOL)moving{return _world->moving();}
- (double)elapsed{return _world->time;}
- (double)maximumSpeed{
    double speed=0;
    for(const auto&b:_world->balls)if(!b.sunk)speed=std::max(speed,b.v.length()+std::abs(b.vertical));
    return speed;
}
- (NSArray*)states{
    NSMutableArray *a=[NSMutableArray array];
    for(const auto&b:_world->balls)[a addObject:@{@"id":@(b.id),@"x":@(b.p.x),@"y":@(b.p.y),@"vx":@(b.v.x),@"vy":@(b.v.y),@"wx":@(b.w.x),@"wy":@(b.w.y),@"spin":@(b.spin),@"sunk":@(b.sunk),@"rails":@(b.rails),@"height":@(b.height),@"vertical":@(b.vertical),@"qx":@(b.rotation.x),@"qy":@(b.rotation.y),@"qz":@(b.rotation.z),@"qw":@(b.rotation.w)}];
    return a;
}
- (NSArray*)presentationStates{
    NSMutableArray *a=[NSMutableArray array];
    for(const auto&b:_world->presentation())[a addObject:@{@"id":@(b.id),@"x":@(b.p.x),@"y":@(b.p.y),@"vx":@(b.v.x),@"vy":@(b.v.y),@"wx":@(b.w.x),@"wy":@(b.w.y),@"spin":@(b.spin),@"sunk":@(b.sunk),@"rails":@(b.rails),@"height":@(b.height),@"vertical":@(b.vertical),@"qx":@(b.rotation.x),@"qy":@(b.rotation.y),@"qz":@(b.rotation.z),@"qw":@(b.rotation.w)}];
    return a;
}
- (NSArray*)rails{
    NSMutableArray*a=[NSMutableArray array];
    for(const auto&s:_world->segments)[a addObject:@{@"ax":@(s.a.x),@"ay":@(s.a.y),@"bx":@(s.b.x),@"by":@(s.b.y),@"id":@(s.rail)}];return a;
}
- (NSArray*)events{return [self eventsSince:0];}
- (NSArray*)eventsSince:(NSUInteger)index{
    NSMutableArray*a=[NSMutableArray array];
    const auto&events=_world->events;
    for(size_t i=std::min(static_cast<size_t>(index),events.size());i<events.size();++i){
        const auto&e=events[i];
        [a addObject:@{@"kind":@(e.kind),@"a":@(e.a),@"b":@(e.b),@"time":@(e.time),@"x":@(e.p.x),@"y":@(e.p.y),@"impact":@(e.impact)}];
    }
    return a;
}
- (NSDictionary*)settings{
    auto&c=_world->config;
    NSMutableDictionary *result=[@{@"experimental3D":@(c.experimental3D),@"cueType":@(c.cueType),@"squirtEnabled":@(c.squirtEnabled),@"cueElevationDegrees":@(c.cueElevationDegrees),@"rolling":@(c.rolling),@"sliding":@(c.sliding),@"railRestitution":@(c.railRestitution),@"railFriction":@(c.railFriction),@"railSpeedSensitivity":@(c.railSpeedSensitivity),@"ballRestitution":@(c.ballRestitution),@"ballFriction":@(c.ballFriction),@"ballFrictionMin":@(c.ballFrictionMin),@"spinDecay":@(c.spinDecay),@"railTangentialRestitution":@(c.railTangentialRestitution),@"tipProfile":@(c.tipProfile),@"squirtRampDegrees":@(c.squirtRampDegrees),@"breakSpeedGain":@(c.breakSpeedGain),@"masseSpeedGain":@(c.masseSpeedGain),@"masseCueRestitution":@(c.masseCueRestitution),@"masseCoupledContact":@(c.masseCoupledContact),@"individualRails":@(c.individualRails),@"coupledCushions":@(c.coupledCushions),@"railNoseHeightMeters":@(c.railNoseHeightMeters())} mutableCopy];
    // Chỉ đọc (hình học bàn) cho UIKit: cơ tránh băng, đánh số nút kim cương.
    result[@"tableWidth"]=@(c.width);result[@"tableLength"]=@(c.length);result[@"ballRadius"]=@(c.radius);result[@"railHeight"]=@(c.railHeight);
    for(int i=0;i<4;i++){result[[NSString stringWithFormat:@"railBounce%d",i]]=@(c.railBounce[i]);result[[NSString stringWithFormat:@"railGrip%d",i]]=@(c.railGrip[i]);}
    return result;
}
- (void)setSettings:(NSDictionary*)v{
    auto&c=_world->config;
    auto get=[&](NSString*k,double old,double lo,double hi){NSNumber*n=v[k];double a=n?n.doubleValue:old;return std::isfinite(a)?std::clamp(a,lo,hi):old;};
    c.individualRails=get(@"individualRails",c.individualRails,0,1)>.5;
    for(int i=0;i<4;i++){c.railBounce[i]=get([NSString stringWithFormat:@"railBounce%d",i],c.railBounce[i],.4,.98);c.railGrip[i]=get([NSString stringWithFormat:@"railGrip%d",i],c.railGrip[i],0,.6);}
    c.coupledCushions=get(@"coupledCushions",c.coupledCushions,0,1)>.5;
    c.experimental3D=get(@"experimental3D",c.experimental3D,0,1)>.5;
    c.cueType=(int)get(@"cueType",c.cueType,0,2);
    c.squirtEnabled=get(@"squirtEnabled",c.squirtEnabled,0,1)>.5;
    c.masseCoupledContact=get(@"masseCoupledContact",c.masseCoupledContact,0,1)>.5;
    c.cueElevationDegrees=get(@"cueElevationDegrees",c.cueElevationDegrees,0,90);
    c.rolling=get(@"rolling",c.rolling,.003,.04);c.sliding=get(@"sliding",c.sliding,.08,.35);
    c.railRestitution=get(@"railRestitution",c.railRestitution,.4,.98);c.railFriction=get(@"railFriction",c.railFriction,0,.6);
    c.railSpeedSensitivity=get(@"railSpeedSensitivity",c.railSpeedSensitivity,0,.08);
    c.ballRestitution=get(@"ballRestitution",c.ballRestitution,.8,1);c.ballFriction=get(@"ballFriction",c.ballFriction,0,.12);c.ballFrictionMin=get(@"ballFrictionMin",c.ballFrictionMin,0,.1);c.spinDecay=get(@"spinDecay",c.spinDecay,1,40);
    c.railTangentialRestitution=get(@"railTangentialRestitution",c.railTangentialRestitution,0,.9);
    c.tipProfile=(int)std::lround(get(@"tipProfile",c.tipProfile,0,2));
    c.squirtRampDegrees=get(@"squirtRampDegrees",c.squirtRampDegrees,0,60);
    c.breakSpeedGain=get(@"breakSpeedGain",c.breakSpeedGain,1,1.8);c.masseSpeedGain=get(@"masseSpeedGain",c.masseSpeedGain,1,1.6);
    c.masseCueRestitution=get(@"masseCueRestitution",c.masseCueRestitution,.1,.9);
}
- (void)loadLayout:(NSArray*)layout{
    std::vector<Ball>b;for(NSDictionary*d in layout){Ball a;a.id=[d[@"id"] intValue];a.p={[d[@"x"] doubleValue],[d[@"y"] doubleValue]};a.sunk=[d[@"sunk"] boolValue];
        Rotation q{[d[@"qx"] doubleValue],[d[@"qy"] doubleValue],[d[@"qz"] doubleValue],d[@"qw"]?[d[@"qw"] doubleValue]:1};
        double norm=std::sqrt(q.x*q.x+q.y*q.y+q.z*q.z+q.w*q.w);
        if(std::isfinite(norm)&&norm>1e-12)a.rotation={q.x/norm,q.y/norm,q.z/norm,q.w/norm};
        b.push_back(a);}_world->reset(b);
    // Core reset intentionally clears dynamics/orientation; layouts restore only appearance.
    for(size_t i=0;i<b.size();++i)_world->balls[i].rotation=b[i].rotation;
}
- (void)advance:(double)s{_world->advance(s);}
- (void)strikeAngle:(double)a speed:(double)s side:(double)x top:(double)y{_world->strike(a,s,x,y);}
- (NSArray*)guideAngle:(double)a rails:(NSInteger)n{
    NSMutableArray*r=[NSMutableArray array];for(const auto&b:_world->balls)if(b.id==0&&!b.sunk){for(auto p:_world->idealGuide(b.p,a,(int)n))[r addObject:@{@"x":@(p.x),@"y":@(p.y)}];break;}return r;
}
- (NSArray*)predictionAngle:(double)a speed:(double)s side:(double)x top:(double)y{
    NSMutableArray*r=[NSMutableArray array];
    for(const auto&p:_world->predict(a,s,x,y)){
        [r addObject:@{@"id":@(p.id),@"time":@(p.time),@"x":@(p.p.x),@"y":@(p.p.y),@"sunk":@(p.sunk),@"height":@(p.height)}];
    }
    return r;
}
- (NSDictionary*)simulateAngle:(double)a speed:(double)s side:(double)x top:(double)y{
    auto o=_world->simulate(a,s,x,y);
    NSMutableArray*events=[NSMutableArray array],*balls=[NSMutableArray array];
    for(const auto&e:o.events)[events addObject:@{@"kind":@(e.kind),@"a":@(e.a),@"b":@(e.b),@"time":@(e.time),@"x":@(e.p.x),@"y":@(e.p.y),@"impact":@(e.impact)}];
    for(const auto&b:o.balls)[balls addObject:@{@"id":@(b.id),@"x":@(b.p.x),@"y":@(b.p.y),@"sunk":@(b.sunk)}];
    return @{@"events":events,@"balls":balls,@"time":@(o.time),@"settled":@(o.settled)};
}
- (NSDictionary*)kickTarget:(NSInteger)target rails:(NSInteger)rails speed:(double)speed side:(double)side top:(double)top {
    auto r=searchKick(*_world,(int)target,(int)rails,speed,side,top);
    return @{@"angle":@(r.angle),@"clearance":@(r.clearance),@"hit":@(r.hit)};
}
- (NSDictionary*)fitCushionSamples:(NSArray*)rows rail:(NSInteger)rail {
    if(rail<0||rail>3||rows.count<8||rows.count>500)return @{@"error":@"Cần 8–500 cú đo cho một băng."};
    std::vector<banklab::CushionSample> samples;
    for(id value in rows){
        if(![value isKindOfClass:[NSDictionary class]])return @{@"error":@"Dữ liệu cú đo không hợp lệ."};
        NSDictionary*d=value;double a[10];NSArray*keys=@[@"vx",@"vy",@"wx",@"wy",@"spin",@"outVx",@"outVy",@"outWx",@"outWy",@"outSpin"];
        for(int i=0;i<10;i++){id n=d[keys[i]];if(![n isKindOfClass:[NSNumber class]]||!std::isfinite([n doubleValue])||std::abs([n doubleValue])>1000)return @{@"error":@"Thiếu trường số hoặc giá trị vượt giới hạn."};a[i]=[n doubleValue];}
        banklab::Ball before,after;before.v={a[0],a[1]};before.w={a[2],a[3]};before.spin=a[4];after.v={a[5],a[6]};after.w={a[7],a[8]};after.spin=a[9];
        if(before.v.dot(banklab::railNormal((int)rail))>=-0.01)return @{@"error":@"Vận tốc đầu phải hướng vào băng được chọn."};
        samples.push_back({(int)rail,before,after});
    }
    auto f=banklab::fitCushion(samples,_world->config,(int)rail);
    return @{@"bounce":@(f.bounce),@"grip":@(f.grip),@"trainRMSE":@(f.train),@"validationRMSE":@(f.validation),@"baselineRMSE":@(f.baseline),@"trainingCount":@(f.trainingCount),@"validationCount":@(f.validationCount)};
}
@end
