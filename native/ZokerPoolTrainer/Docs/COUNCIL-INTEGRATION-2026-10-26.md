# Hội đồng AI → quyết định dự án — 26/10/2026

Trạng thái: REVIEW_INTEGRATED / IMPLEMENTATION_PENDING. Nhãn COMPLETE của ý kiến hội đồng chỉ nói bài phản biện đã hoàn thành; không đóng gate sản phẩm.

## Cơ sở kiểm chứng
Repo private zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858.
Kiểm tra remote ngày 26/10: main aba66d0f21e0816973ef0c13281fa98855ca3ff6; feature/0.13-hud-camera efabf7e3fb853e50612db3b4d5b54b6edd262791. Không tìm thấy ci/native-xoay-co trong danh sách nhánh trả về. Không merge nhánh chưa xác minh.
Đọc trực tiếp TrainingController:setHold/panTable/configureGestures, PresentationTests.cpp, QA-MATRIX-G1.md. Pan ngắm một ngón, orbit hai ngón, pinch và khóa hold đã có source. Lỗi xoay cơ tái hiện/đã hết: UNVERIFIED, cần native repro và clip/log.
32 ca policy portable và bộ C++/JS là evidence phiên trước; phiên tích hợp phản biện này không chạy lại app hoặc đo bàn thật.

## Quyết định tiếp thu
| Ý kiến | Quyết định | Phần cần chỉnh |
|---|---|---|
| Ưu tiên gesture/UX trước mở rộng nội dung | ACCEPT | G1 vẫn đứng đầu; capture repro, thao tác, state và thiết bị trước sửa |
| Golden Master, 10 ca, đo bàn thật | ACCEPT_WITH_CHANGES | Tách numerical regression khỏi measured reference; 5 bài phẳng cơ bản trước, jump/massé sau |
| Video-to-Data bằng OpenCV | ACCEPT_WITH_CHANGES | Đây là một phương pháp, không phải cách duy nhất; bổ sung thước/điểm dừng/đo vận tốc độc lập |
| Focus Mode/Thi ít che bàn | ACCEPT_WITH_CHANGES | Đã ẩn nhiều HUD khi giữ B; thiết kế phần còn thiếu theo state, giữ đường hủy/thả B/Undo/camera phù hợp |
| B mặc định toggle | DO_NOT_ADOPT_AS_DEFAULT | Giữ hold theo yêu cầu gốc. Toggle chỉ là tùy chọn accessibility sau test, không bật mặc định |
| Merge ci/native-xoay-co, Build 6/7/8 | REBASE_TO_CURRENT_PLAN | Không dùng số build/nhánh cũ làm lệnh; dùng G1/G2/G3/G4, metadata candidate 0.13/23 |
| Sai số <1cm / <1.5cm sau 3 băng | PROVISIONAL_TARGET | Hai ngưỡng chưa nhất quán và chưa có dataset/uncertainty; chưa biến thành lời bảo đảm |
| 100 lần input giống nhau phải giống hệt | ACCEPT_WITH_SCOPE | Cùng binary/platform/config/seed: so hash trạng thái chuẩn hóa và event order. Cross-platform: tolerance công bố + event equivalence |
| Bảo toàn năng lượng/momentum mọi va chạm | CORRECT | Bóng chịu ma sát và xung lực từ bàn/băng: không ép conservation sai. Test hệ cô lập lý tưởng; ở hệ tiêu tán kiểm passivity/công ngoại lực |
| FPS >55, 10 phút | ACCEPT_AS_PROVISIONAL_DEVICE_GATE | Đo frame-time p50/p95/p99, frame >25ms, nhiệt, chế độ đồ họa, tải; average FPS riêng không đủ |
| Hoãn tăng ngôn ngữ/cú đẹp | ACCEPT_FOR_CURRENT_PRIORITY | Không xóa các khả năng đang có; tập trung chất lượng đo và UX |
| HLV AI | ADD_TO_ROADMAP | Xem AI-COACH-SPEC.md; trước online, chỉ sau data/permission ổn định |

## Focus / Practice / Exam
State cần phân biệt: Aiming, Locked, Simulating, Settling, Replay, Editing, Spectating; Practice/Exam là chế độ luyện độc lập với state.
- Aiming: giữ những control thiết yếu, không chèn số/nhãn vào vùng bi/đường ngắm.
- Locked: giữ B với hit area độc lập; thả B hủy cú chưa bắn; HUD phụ ẩn. Không tái sử dụng touch đã bắt đầu trên UI để đánh.
- Simulating: orbit/pinch và Undo vẫn có đường tiếp cận; không tự chặn quyền quan sát vì ẩn toàn bộ UI.
- Exam: tắt hints, prediction và coach trong lượt thử; tổng kết sau lượt, không can thiệp solver hoặc scoring.
Vùng cấm che gồm bi cái, bi đích và hành lang ngắm chiếu lên màn hình, có margin; layout phải kiểm vùng giao nhau và hit-test trên ảnh thực tế. Không coi số pixel toàn màn là tiêu chí đủ; UI cần thiết vẫn nằm ngoài vùng cấm.
Toggle tùy chọn nếu làm: default off; trạng thái armed rõ, explicit cancel, tự disarm sau shot/background/modal/edit/replay/spectator, không giữ qua session; giữ chuẩn hold hiện có.

## Đo bàn thật: quy trình
1. Chọn một bàn, đo bed/ball/pocket; ghi nỉ/băng/điều kiện/ngày, FPS thực, vị trí camera và độ phơi sáng. Quay slow motion nếu thiết bị hỗ trợ và kiểm frame timestamps.
2. Hiệu chỉnh méo lens và phối cảnh bằng mốc có tọa độ mét; khóa camera. Đánh giá sai số tracking bằng các mốc kiểm độc lập.
3. Track tâm bi và event, flag occlusion/ID swap/motion blur; low-confidence samples phải review/loại, không nội suy thành bằng chứng.
4. Homography mặt bàn cho chuyển động phẳng. Tâm bi cao hơn bed gây parallax cần mô hình/correction; jump/massé cần kiểm height/3D hoặc camera bổ sung, không suy quỹ đạo 3D từ một phép chiếu phẳng.
5. Đồng bộ thời gian; lưu position/velocity với uncertainty. Spin không được suy chắc chắn chỉ từ tâm bi; cần marker/orientation nếu muốn đo xoáy.
6. Fit từng nhóm tham số với bài riêng (rolling/sliding, restitution, rail tangential response), giữ dữ liệu holdout khác để nghiệm thu; không fit và chấm cùng bộ.
7. Lưu raw video, annotations, calibration metadata, hashes, parameter profile/version và report. Pooltool dùng differential testing, không làm ground truth thực nghiệm.

## Dataset và tiêu chí
V1: straight roll tốc độ thấp/vừa, stop/follow/draw có marker nếu đo spin, va bi thẳng/cắt đối xứng, 1 rail, 2 rails, 3 rails, gần miệng lỗ; tối thiểu 10 cấu hình chuẩn có repeat. Bắt đầu 5 bài dễ đo, mỗi cấu hình ít nhất 5 lần. Jump/massé chỉ bổ sung khi phép đo 3D đủ tin cậy.
Metrics: path RMSE/max lateral deviation, outgoing direction, stop distance, event timing/order, pocket success, năng lượng; báo median/p95 theo loại cú và tốc độ, không chỉ endpoint.
Mục tiêu 1cm cơ bản và 1.5cm/3 băng chỉ là mục tiêu nghiên cứu PROVISIONAL. Trước freeze gate: đo repeatability và uncertainty nhỏ hơn ngưỡng đủ để phân biệt; nếu chưa đủ, công bố giới hạn, không nới ngưỡng để tự pass. Chuẩn mục tiêu góc 0.5° tại 1.5m giữ như yêu cầu riêng; không đồng nhất sai số góc và sai số điểm dừng.

## Test và evidence
- Numerical: 100 repeats/10 cases, same-build hash, mirrored cases, event ordering; timestep convergence h/h2/h4, CPU/compiler/platform metadata. Không yêu cầu hash giống khi chủ động đổi timestep.
- Physical invariants: nonpenetration, finite state, passive impacts, Coulomb bound, symmetry và prediction/live agreement. Động lượng của hệ bi không bảo toàn khi có lực bàn/băng.
- UIKit: tap/pan/pinch/drag, entering/leaving hold, expanded spin, modal/background, Undo/replay/scratch, safe areas; 30 tình huống đã định nghĩa cần kết quả thực. XCUITest drag có API chính thức; không mặc nhiên coi test 1 gesture là evidence multi-touch giữ B + stroke đồng thời trên máy thật.
- Device: iPhone 14 Pro Max và iPad M1, 10 phút, long roll/break/jump/prediction/HUD; frame-time và thermal context. Trạng thái hiện tại NOT_RUN.

## Thứ tự gate và nơi sửa
1. G1: TrainingController/TouchControls/TableScene + XCUITest target/probes. Đóng native compile và touch trước.
2. G2: cue-rail envelope + contact clamp + seeded random, pure geometry tests.
3. CAL-01 (G2/G3, parallel về kế hoạch): Tools/Calibration, Tests/MeasuredFixtures, versioned calibration profiles; dataset 5→10 ca.
4. COACH-01: ShotRecord + offline diagnostics/counterfactual + journal, sau G1 và dựa trên CAL confidence.
5. G3/G4: lesson reachability, samples có quyền, device profiling, release candidate.
6. G5–G7: online sau offline nghiệm thu; không đổi kiến trúc solver để đẩy nhanh demo.
Không có gate nào được đóng bởi tài liệu này.

## Nguồn kỹ thuật chính thức
- OpenCV calibration/distortion: https://docs.opencv.org/4.13.0/d9/d0c/group__calib3d.html
- OpenCV homography (planar assumptions): https://docs.opencv.org/4.0.0/d9/dab/tutorial_homography.html
- Apple XCUICoordinate gestures: https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate
Đây là cơ sở thiết kế; chưa có pipeline OpenCV hoặc XCUITest mới được triển khai trong lần cập nhật này.

