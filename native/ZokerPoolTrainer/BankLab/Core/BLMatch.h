#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Host-authoritative virtual WPA 8/9/10-ball adjudication. Rotation15 is a named practice variant.
@interface BLMatch : NSObject
- (instancetype)initWithRule:(NSString *)rule NS_SWIFT_NAME(init(rule:));
@property(nonatomic,readonly) NSDictionary<NSString *,id> *state;
- (void)resetWithBreaker:(NSInteger)breaker NS_SWIFT_NAME(reset(breaker:));
- (NSArray<NSDictionary<NSString *,NSNumber *> *> *)rackWithSeed:(uint64_t)seed NS_SWIFT_NAME(rack(seed:));
- (void)setCalledBall:(NSInteger)ball pocket:(NSInteger)pocket safety:(BOOL)safety pushOut:(BOOL)pushOut NS_SWIFT_NAME(setCall(ball:pocket:safety:pushOut:));
- (NSDictionary<NSString *,id> *)completeShotWithBefore:(NSArray *)before after:(NSArray *)after events:(NSArray *)events headCrossed:(NSArray<NSNumber *> *)headCrossed NS_SWIFT_NAME(complete(before:after:events:headCrossed:));
- (NSDictionary<NSString *,id> *)resolveChoice:(NSString *)choice NS_SWIFT_NAME(resolve(choice:));
@end
NS_ASSUME_NONNULL_END
