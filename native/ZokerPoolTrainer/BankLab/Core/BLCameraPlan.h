// 0.48 M1 "Máy quay": cầu ObjC++ tới banklab::camera::Planner (CameraPlanner.hpp). Toạ độ trả về là SCENE
// (scene.x = bàn.x, scene.y = bàn.z (lên), scene.z = bàn.y). Vector "lên" của máy = +Y scene.
#import <Foundation/Foundation.h>
#import <simd/simd.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, BLCameraStyle) { BLCameraStyleDirector=0, BLCameraStyleLearn=1, BLCameraStyleShooter=2, BLCameraStyleWide34=3,
  BLCameraStyleOverhead=4, BLCameraStyleFollowCue=5, BLCameraStyleRailSide=6, BLCameraStylePocketMeet=7, BLCameraStyleTeaser=8 };
typedef NS_ENUM(NSInteger, BLCameraScene) { BLCameraSceneOpen=0, BLCameraSceneStroke=1, BLCameraSceneImpact=2, BLCameraSceneTravel=3,
  BLCameraScenePot=4, BLCameraSceneSettle=5, BLCameraSceneBreakWide=6, BLCameraSceneWrap=7, BLCameraSceneManual=8 };
@interface BLCameraPlan : NSObject
/// frames: n mẫu, m bi; xs/ys/sunk xếp hàng-trước [frame*m + ball], thứ tự bi = ids. events: [{kind,a,b,time,x,y,impact}] như BLWorld.
/// aimAngle: góc ngắm bi cái (rad, hướng (cos,sin) trong toạ độ bàn). aspect = rộng/cao khung (16/9 hoặc 9/16, hoặc màn hình).
/// lead: giây trước cú đánh (đồng hồ xem lại bắt đầu ở -lead), tail: giây sau khung cuối.
/// Khuyến nghị lead = recommendedLead (3 s) để Đạo diễn đủ 6 cảnh; lead ngắn hơn vẫn hợp lệ (cảnh được gộp).
- (instancetype)initWithFrameCount:(NSInteger)n times:(const double *)times ballCount:(NSInteger)m ids:(const int *)ids
        xs:(const double *)xs ys:(const double *)ys sunk:(const uint8_t *)sunk events:(NSArray<NSDictionary<NSString*,NSNumber*>*> *)events
        aimAngle:(double)aimAngle style:(BLCameraStyle)style aspect:(double)aspect lead:(double)lead tail:(double)tail;
- (instancetype)init NS_UNAVAILABLE;
- (void)poseAt:(double)t eye:(simd_float3 *)eye target:(simd_float3 *)target fov:(float *)fovDegrees; // SCENE coords, FOV dọc (độ)
- (double)rateAt:(double)t;            // hệ số tốc độ phát tại thời điểm bản ghi t (1 = thật; Director/Teaser có đoạn chậm ≥0.35)
- (BLCameraScene)sceneKindAt:(double)t;
- (NSInteger)sceneIndexAt:(double)t;   // đổi giá trị đúng tại điểm cắt
@property (nonatomic, readonly) NSInteger sceneCount;
- (double)sceneStart:(NSInteger)index;
- (double)trailRevealAt:(double)t;     // 0…1: mức hiện vệt đường bi (Learn: tăng dần theo t; Director: 0 cho tới cảnh Wrap rồi 1)
@property (nonatomic, readonly) double bestStillTime;   // khung đẹp nhất cho ảnh thẻ: va chạm đầu hoặc lúc bi rơi
@property (nonatomic, readonly) double wallDuration;    // thời lượng thật khi phát hết (tích phân 1/rate), startTime → endTime
@property (nonatomic, readonly) double peakAngularSpeed; // độ/s, trong một cảnh (không tính điểm cắt)
@property (nonatomic, readonly) double p95AngularSpeed;  // độ/s
@property (nonatomic, readonly) double minVisibleFraction; // tỉ lệ thời gian bi chính nhìn thấy, cảnh tệ nhất
// ---- Thêm (ngoài hợp đồng gốc) ----
/// Đồng hồ bản ghi bắt đầu/dừng phát. Teaser bắt đầu muộn hơn -lead và dừng trước khung cuối + tail
/// (startTime → endTime ≤ 6,5 s thật; thẻ cuối logo 1,5 s do Swift ghép). Kiểu khác: -lead và khung cuối + tail.
@property (nonatomic, readonly) double startTime;
@property (nonatomic, readonly) double endTime;
/// Id bi chính của cảnh tại t (-1 nếu không có) — để vẽ nhấn/nhãn hoặc chẩn đoán.
- (NSInteger)subjectBallAt:(double)t;
/// Thời điểm (bản ghi) của va chạm bi cái đầu tiên / bi lọt chính; NaN nếu không có.
@property (nonatomic, readonly) double contactTime;
@property (nonatomic, readonly) double potTime;
@property (nonatomic, class, readonly) double recommendedLead;
@property (nonatomic, class, readonly) double recommendedTail;
@end
NS_ASSUME_NONNULL_END
