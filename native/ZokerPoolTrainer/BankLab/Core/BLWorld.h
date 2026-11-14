#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface BLWorld : NSObject
@property(nonatomic,readonly) NSArray<NSDictionary<NSString*,NSNumber*>*> *states;
@property(nonatomic,readonly) NSArray<NSDictionary<NSString*,NSNumber*>*> *rails;
@property(nonatomic,readonly) NSArray<NSDictionary<NSString*,NSNumber*>*> *events;
@property(nonatomic,readonly) NSArray<NSDictionary<NSString*,NSNumber*>*> *presentationStates;
/// 0.43: the same states as 16 doubles per ball (id x y vx vy wx wy spin sunk rails height vertical qx qy qz qw) —
/// one allocation instead of 16 dictionaries; used on the per-frame/per-sample path (BallState.unpack).
@property(nonatomic,readonly) NSData *packedStates;
@property(nonatomic,readonly) NSData *packedPresentationStates;
@property(nonatomic,readonly) BOOL moving;
@property(nonatomic,readonly) double elapsed;
/// Fast scalar query: no per-ball NSDictionary/NSNumber allocation in the replay sampling loop.
@property(nonatomic,readonly) double maximumSpeed;
- (NSArray<NSDictionary<NSString*,NSNumber*>*>*)eventsSince:(NSUInteger)index NS_SWIFT_NAME(events(since:));
@property(nonatomic,copy) NSDictionary<NSString*,NSNumber*> *settings;
- (void)loadLayout:(NSArray<NSDictionary<NSString*,NSNumber*>*>*)layout;
- (void)advance:(double)seconds;
- (void)strikeAngle:(double)angle speed:(double)speed side:(double)side top:(double)top NS_SWIFT_NAME(strike(angle:speed:side:top:));
- (NSArray<NSDictionary<NSString*,NSNumber*>*>*)guideAngle:(double)angle rails:(NSInteger)count NS_SWIFT_NAME(guide(angle:rails:));
- (NSArray<NSDictionary<NSString*,NSNumber*>*>*)predictionAngle:(double)angle speed:(double)speed side:(double)side top:(double)top NS_SWIFT_NAME(prediction(angle:speed:side:top:));
/// Mô phỏng trên bản sao (không đổi world): {events:[…], balls:[…], time, settled}. Dùng cho Coach phản thực tế.
- (NSDictionary*)simulateAngle:(double)angle speed:(double)speed side:(double)side top:(double)top NS_SWIFT_NAME(simulate(angle:speed:side:top:));
- (NSDictionary<NSString*,NSNumber*>*)kickTarget:(NSInteger)target rails:(NSInteger)rails speed:(double)speed side:(double)side top:(double)top NS_SWIFT_NAME(kick(target:rails:speed:side:top:));
- (NSDictionary*)fitCushionSamples:(NSArray*)samples rail:(NSInteger)rail NS_SWIFT_NAME(fitCushion(samples:rail:));
@end
NS_ASSUME_NONNULL_END
