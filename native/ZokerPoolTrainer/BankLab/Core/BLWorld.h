#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface BLWorld : NSObject
@property(nonatomic,readonly) NSArray<NSDictionary<NSString*,NSNumber*>*> *states;
@property(nonatomic,readonly) NSArray<NSDictionary<NSString*,NSNumber*>*> *rails;
@property(nonatomic,readonly) NSArray<NSDictionary<NSString*,NSNumber*>*> *events;
@property(nonatomic,readonly) NSArray<NSDictionary<NSString*,NSNumber*>*> *presentationStates;
@property(nonatomic,readonly) BOOL moving;
@property(nonatomic,readonly) double elapsed;
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
