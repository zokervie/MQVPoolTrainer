#import "BLMatch.h"
#include "MatchRules.hpp"
#include <memory>
using namespace banklab;
namespace {
NSString *text(const std::string& s){return [NSString stringWithUTF8String:s.c_str()] ?: @"";}
NSDictionary *dictionary(const match::State& s){
    NSMutableArray *options=[NSMutableArray array];for(const auto& option:s.choiceOptions)[options addObject:text(option)];
    return @{@"rule":text(match::name(s.rule)),@"currentPlayer":@(s.currentPlayer),@"winner":@(s.winner),
        @"breakShot":@(s.breakShot),@"ballInHand":@(s.ballInHand),@"headStringOnly":@(s.headStringOnly),
        @"groups":@[@(s.groups[0]),@(s.groups[1])],@"scores":@[@(s.scores[0]),@(s.scores[1])],
        @"fouls":@[@(s.fouls[0]),@(s.fouls[1])],@"twoFoulWarning":@[@(s.twoFoulWarning[0]),@(s.twoFoulWarning[1])],
        @"pushOutAvailable":@(s.pushOutAvailable),@"pendingChoice":text(s.pendingChoice),@"choiceOptions":options,
        @"canShoot":@(s.canShoot()),@"requiresCall":@(s.requiresCall()),@"reason":text(s.reason),@"shotCount":@(s.shotCount)};
}
NSDictionary *dictionary(const match::Action& a){
    NSMutableArray *spots=[NSMutableArray array];for(int id:a.spotBalls)[spots addObject:@(id)];
    return @{@"state":dictionary(a.state),@"accepted":@(a.accepted),@"spotBalls":spots,@"rerack":@(a.rerack),
        @"foul":@(a.foul),@"shooter":@(a.shooter),@"reason":text(a.reason)};
}
std::vector<Ball> balls(NSArray *array){
    std::vector<Ball> result;for(id value in array){if(![value isKindOfClass:[NSDictionary class]])continue;
        NSDictionary *d=value;Ball b;b.id=[d[@"id"] intValue];b.p={[d[@"x"] doubleValue],[d[@"y"] doubleValue]};b.sunk=[d[@"sunk"] boolValue];result.push_back(b);}
    return result;
}
}
@implementation BLMatch {std::unique_ptr<match::Rules> _rules;match::Call _call;}
- (instancetype)init {return [self initWithRule:@"nineBall"];}
- (instancetype)initWithRule:(NSString *)rule {if((self=[super init])){_rules=std::make_unique<match::Rules>(match::discipline(rule.UTF8String ?: "nineBall"));}return self;}
- (NSDictionary *)state {return dictionary(_rules->state);}
- (void)resetWithBreaker:(NSInteger)breaker {_rules->reset(static_cast<int>(breaker));_call={};}
- (NSArray *)rackWithSeed:(uint64_t)seed {NSMutableArray *result=[NSMutableArray array];for(const auto& b:_rules->rack(seed))
    [result addObject:@{@"id":@(b.id),@"x":@(b.p.x),@"y":@(b.p.y),@"sunk":@NO}];return result;}
- (void)setCalledBall:(NSInteger)ball pocket:(NSInteger)pocket safety:(BOOL)safety pushOut:(BOOL)pushOut {
    _call={static_cast<int>(ball),static_cast<int>(pocket),static_cast<bool>(safety),static_cast<bool>(pushOut)};
}
- (NSDictionary *)completeShotWithBefore:(NSArray *)before after:(NSArray *)after events:(NSArray *)events headCrossed:(NSArray *)headCrossed {
    match::Evidence e;e.before=balls(before);e.after=balls(after);e.call=_call;
    for(id value in events){if(![value isKindOfClass:[NSDictionary class]])continue;NSDictionary*d=value;
        Event event{[d[@"kind"] intValue],[d[@"a"] intValue],[d[@"b"] intValue],[d[@"time"] doubleValue],{[d[@"x"] doubleValue],[d[@"y"] doubleValue]},[d[@"impact"] doubleValue]};e.events.push_back(event);}
    for(NSNumber *id in headCrossed){const int n=id.intValue;if(n>0&&n<=15)e.headCrossed.insert(n);}
    auto result=_rules->complete(e);if(result.accepted)_call={};return dictionary(result);
}
- (NSDictionary *)resolveChoice:(NSString *)choice {return dictionary(_rules->resolve(choice.UTF8String ?: ""));}
@end
