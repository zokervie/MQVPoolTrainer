#import <Foundation/Foundation.h>
#import "BLWorld.h"
#import "BLMatch.h"
NS_ASSUME_NONNULL_BEGIN
/// 0.40 Đấu với máy: one planning job for the computer player (Core/Opponent.hpp, tested in OpponentTests.cpp).
/// Create it on the main thread (copies the table and the referee state), call -plan on any thread.
@interface BLOpponent : NSObject
- (instancetype)initWithWorld:(BLWorld *)world match:(BLMatch *)match level:(NSInteger)level seed:(uint64_t)seed NS_SWIFT_NAME(init(world:match:level:seed:));
/// Keys: valid, angle, speed, side, top, target, pocket, safety, placed, x, y, chance, option (NSString, may be "").
- (NSDictionary<NSString *,id> *)plan;
+ (NSArray<NSString *> *)levelNames;
@end
NS_ASSUME_NONNULL_END
