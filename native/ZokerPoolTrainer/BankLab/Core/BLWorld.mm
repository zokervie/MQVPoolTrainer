#include "CushionCalibration.hpp"
#import "BLWorld.h"
#include "Physics.hpp"
#include "KickSearch.hpp"
#include <memory>
using namespace banklab;
@implementation BLWorld { std::unique_ptr<World> _world; }
- (instancetype)init { if((self=[super init])){_world=std::make_unique<World>();_world->config.coupledCushions=true;}return self; }
- (BOOL)moving{return _world->moving();}
- (double)elapsed{return _world->time;}
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
- (NSArray*)events{
    NSMutableArray*a=[NSMutableArray array];
    for(const auto&e:_world->events)[a addObject:@{@"kind":@(e.kind),@"a":@(e.a),@"b":@(e.b),@"time":@(e.time),@"x":@(e.p.x),@"y":@(e.p.y),@"impact":@(e.impact)}];return a;
}
- (NSDictionary*)settings{
    auto&c=_world->config;
    NSMutableDictionary *result=[@{@"experimental3D":@(c.experimental3D),@"cueType":@(c.cueType),@"cueElevationDegrees":@(c.cueElevationDegrees),@"rolling":@(c.rolling),@"sliding":@(c.sliding),@"railRestitution":@(c.railRestitution),@"railFriction":@(c.railFriction),@"railSpeedSensitivity":@(c.railSpeedSensitivity),@"ballRestitution":@(c.ballRestitution),@"ballFriction":@(c.ballFriction),@"spinDecay":@(c.spinDecay),@"individualRails":@(c.individualRails),@"coupledCushions":@(c.coupledCushions),@"railNoseHeightMeters":@(c.railNoseHeightMeters())} mutableCopy];
    for(int i=0;i<4;i++){result[[NSString stringWithFormat:@"railBounce%d",i]]=@(c.railBounce[i]);result[[NSString stringWithFormat:@"railGrip%d",i]]=@(c.railGrip[i]);}
    return result;
}
- (void)setSettings:(NSDictionary*)v{
    auto&c=_world->config;
    auto get=[&](NSString*k,double old,double lo,double hi){NSNumber*n=v[k];double a=n?n.doubleValue:old;return std::isfinite(a)?std::clamp(a,lo,hi):old;};
    c.individualRails=get(@"individualRails",c.individualRails,0,1)>.5;
    for(int i=0;i<4;i++){c.railBounce[i]=get([NSString stringWithFormat:@"railBounce%d",i],c.railBounce[i],.4,.98);c.railGrip[i]=get([NSString stringWithFormat:@"railGrip%d",i],c.railGrip[i],0,.35);}
    c.coupledCushions=get(@"coupledCushions",c.coupledCushions,0,1)>.5;
    c.experimental3D=get(@"experimental3D",c.experimental3D,0,1)>.5;
    c.cueType=(int)get(@"cueType",c.cueType,0,2);
    c.cueElevationDegrees=get(@"cueElevationDegrees",c.cueElevationDegrees,0,80);
    c.rolling=get(@"rolling",c.rolling,.003,.04);c.sliding=get(@"sliding",c.sliding,.08,.35);
    c.railRestitution=get(@"railRestitution",c.railRestitution,.4,.98);c.railFriction=get(@"railFriction",c.railFriction,0,.35);
    c.railSpeedSensitivity=get(@"railSpeedSensitivity",c.railSpeedSensitivity,0,.08);
    c.ballRestitution=get(@"ballRestitution",c.ballRestitution,.8,1);c.ballFriction=get(@"ballFriction",c.ballFriction,0,.12);c.spinDecay=get(@"spinDecay",c.spinDecay,1,20);
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
