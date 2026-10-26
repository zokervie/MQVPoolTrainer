# Zoker AI Coach — đặc tả bổ sung 26/10/2026

Trạng thái PLANNED, chưa triển khai. Phụ thuộc G1/native input ổn định; không mô tả rule engine như một model học máy. Ưu tiên HLV phân tích offline trước lớp hội thoại/online.

## Mục tiêu
Giúp người tập hiểu kết quả, chọn một thay đổi để thử và theo dõi tiến bộ. Chỉ kết luận điều đo được trong app; không suy thế đứng, cầu tay, độ thẳng cơ ngoài đời từ một cú chạm màn hình. Chưa có measured profile thì ghi phân tích theo mô phỏng, không gọi tối ưu cho bàn thật.

## Data contract ShotRecordV1
schemaVersion, shotID, sourceSHA, solverVersion, profileID/hash/calibrationStatus; preState/postState (positions, velocities, angular velocity, quaternion, sunk), requested/effective inputs (angle/speed/side/top/elevation/cue type), seed, ordered events/time, lesson objective/scoring version, outcome, display timing và confidence/provenance.
Giữ nguyên legacy layouts/practiceHistory; migrate/add riêng, decode có defaults cho field mới; bounded local retention/export/delete. UI không đọc snapshot mutable của solver đang chạy.

## Các lớp triển khai
1. Recorder/FeatureExtractor: capture immutable native snapshots/event log; quyền local/spectator và practice/exam đi cùng record.
2. OfflineCoach: phân tích chạm bi đầu, băng trước/sau, scratch, vùng dừng và độ lệch so mục tiêu. Dùng rule + thống kê, không cần API.
3. CounterfactualRunner: world riêng trên worker, cùng solver/profile/seed; baseline replay phải tái tạo đúng trước khi thử thay đổi. Giới hạn search/time, cancellation và stale result token; không chạy search nặng trong CADisplayLink.
4. Advice: tối đa một chỉnh sửa chính; ví dụ đổi lực giữ góc/effect. Không quy lỗi góc khi mục tiêu/đường chuẩn chưa xác minh; nhiều tổ hợp có thể cho kết quả tương tự.
5. PracticePlanner: adaptive drills theo số mẫu đủ, xu hướng và độ bất định; chưa suy Fargo từ scoring nội bộ.
6. Conversation optional: model chỉ diễn giải structured facts đã xác minh, không trực tiếp chỉnh solver hoặc tạo hệ số. Thiếu model/network thì offline coaching vẫn chạy. Chưa chọn provider/license/cost trong spec này.

## UX
Practice: sau shot hiện thẻ ngắn Kết quả → Có thể thử → Tập lại; overlay đường thực tế/đường thử bật theo nhu cầu, ẩn khi ngắm. Một chạm khôi phục cùng layout, giữ record gốc.
Exam: không hint/prediction/counterfactual trong lượt; đánh giá sau lượt hoặc cuối bài. Lesson mode/scoring không bị coach thay đổi.
Spectator: chỉ xem dữ liệu cho phép; cấm strike/Undo/random đơn phương. Camera quan sát vẫn hoạt động.

## Confidence và kiểm nghiệm
Advice trả về evidenceIDs, model/calibration provenance, confidence level và reason. Numerical repeatability không tương đương real-table accuracy. Sai số nhỏ hơn uncertainty hoặc nhiều nguyên nhân cùng giải thích thì ghi chưa đủ dữ liệu, đề nghị bài đo tách biến.
A/B cùng layout/input; so với replay độc lập. Counterfactual không được mutate world thật; test worker cancel, stale record, missing schema fields, invalid/NaN inputs, scratch/timeout/occlusion, exam/spectator permissions.
Nghiệm thu: record replay đúng và nonmutation; advice trace được tới event/metric; mọi ngưỡng calibrated có measured evidence; latency/UI/memory trên máy thật được báo cáo trước chốt budget. Model không được bịa đã đo spin ngoài đời.
Code files dự kiến: BankLab/Coach/{ShotRecord,ShotRecorder,OfflineCoach,CounterfactualRunner,PracticePlanner,CoachAdvice}.swift; Tests/Coach*, UI post-shot card; không thêm dependency lên core physics.

