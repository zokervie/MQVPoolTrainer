#import "BLOpponent.h"
#include "Opponent.hpp"
using namespace banklab;
// Internal accessors (implemented in BLWorld.mm / BLMatch.mm, not part of the Swift surface).
@interface BLWorld (ZokerCore)
- (const void *)zokerCoreWorld;
@end
@interface BLMatch (ZokerCore)
- (const void *)zokerCoreState;
@end
@implementation BLOpponent {World _world;match::State _state;int _level;std::uint64_t _seed;}
- (instancetype)initWithWorld:(BLWorld *)world match:(BLMatch *)match level:(NSInteger)level seed:(uint64_t)seed {
    if((self=[super init])){
        const World* w=static_cast<const World*>([world zokerCoreWorld]);
        _world=World(w->config);_world.reset(w->balls);
        _state=*static_cast<const match::State*>([match zokerCoreState]);
        _level=static_cast<int>(level);_seed=seed;
    }
    return self;
}
+ (NSArray<NSString *> *)levelNames {
    NSMutableArray *names=[NSMutableArray array];
    for(int i=0;i<ai::kLevels;++i)[names addObject:[NSString stringWithUTF8String:ai::skill(i).name]];
    return names;
}
- (NSDictionary *)plan {
    NSString *option=@"";
    if(!_state.pendingChoice.empty())option=[NSString stringWithUTF8String:ai::chooseOption(_state).c_str()] ?: @"";
    bool placed=false;V2 place{};
    if(_state.ballInHand&&_state.pendingChoice.empty()){
        place=ai::placeCue(_world,_state,_state.currentPlayer);placed=true;
        auto layout=_world.balls;bool found=false;
        for(auto& b:layout)if(b.id==0){b.p=place;b.sunk=false;found=true;}
        if(!found){Ball cue;cue.id=0;cue.p=place;layout.insert(layout.begin(),cue);}
        _world.reset(layout);
    }
    ai::Shot planned=ai::plan(_world,_state,_level,_seed,2.0);   // 0.40b: wall-clock budget (OpponentTests "full table")
    ai::Shot shot=ai::execute(planned,_level,_seed*31+7);
    return @{@"valid":@(shot.valid),@"angle":@(shot.angle),@"speed":@(shot.speed),@"side":@(shot.side),@"top":@(shot.top),
             @"target":@(planned.target),@"pocket":@(planned.pocket),@"safety":@(planned.safety),
             @"placed":@(placed),@"x":@(place.x),@"y":@(place.y),@"chance":@(planned.potChance),@"option":option};
}
@end
