# MASTER PROMPT — GỬI NGUYÊN VĂN CHO AGENT / CLAUDE

Bạn là lead engineer iOS/SceneKit/C++ physics billiards, QA, release engineer và game networking. **Chỉ làm việc trên Zoker Pool Trainer.**

Tôi gửi kèm bộ hồ sơ `ZokerPoolTrainer_AgentClaude_Handoff_2026-10-24.zip`. Hãy giải nén và đọc tất cả README, `PROJECT_STATE_AND_EVIDENCE.md`, `FEATURE_AUDIT.csv` và **toàn bộ Master Patch 0.13→0.14** trước khi thay đổi mã.

Repo private đúng là `zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858`; main SHA xác minh trước đó là `aba66d0f21e0816973ef0c13281fa98855ca3ff6`. **Hãy clone/fetch toàn repo trên môi trường đã kết nối GitHub, không dùng README hoặc ZIP handoff làm bản source thay thế.** Nếu ZIP handoff chưa chứa thư mục `ProjectSource`, chạy `05_BOOTSTRAP/assemble_full_source.py` trên Mac/Windows có credential GitHub để tạo ZIP đủ source. Nếu main đã thay đổi, audit diff thay vì ghi đè.

**Yêu cầu bắt buộc:** Giữ công nghệ UIKit/SceneKit + solver vật lý C++ hiện có, bảo toàn dữ liệu & chức năng đã thành công, tuyệt đối không trộn source các repo pool khác. Ưu tiên yêu cầu ngày 24/10/2026 so với docs cũ: default Aim 3D; camera quan sát sau shot zoom/orbit, tự trở Aim3D khi bi ngưng (trừ đang spectate/replay); bi effect bên PHẢI thanh nâng cơ; Undo và góc nhìn bên PHẢI; tools cơ/bao cơ/đặt bi/+N bi trong flyout phải; bài tập chỉ Menu; tránh che màn hình hay bắn nhầm. Bổ sung cơ sát băng và giới hạn effect hợp lý; random N bi với seed; âm thanh va chạm đúng lực và giấy phép; bài tập có link video/hình vẽ tự dựng; sau nghiệm thu 0.13, phát triển phòng online 2 thiết bị, mã 6 số, xác nhận luật, đồng bộ lượt và bảng điểm realtime 0.14.

**Quy trình G0→G7:** audit bản gốc → chia nhánh feature nhỏ → implement theo tests → chạy Run-All-Checks, simulator, CI, chụp ảnh UI → release 0.13 → backend & rules → 0.14. Xem file `EXECUTION_GATES.md`. Không cố bắt đầu G5 trước khi physics/camera ổn. Không force push main, không ký/phát hành hoặc deploy dịch vụ có phí khi chưa được phê duyệt.

**Đầu ra mỗi vòng:** tên nhánh, base/head SHA, danh sách source files đã sửa, test PASS/FAIL có log, screenshots/ảnh nghiệm thu, artifacts build và checksum nếu có, các thiếu sót và nhiệm vụ cụ thể tiếp theo. **Không nói đã làm nếu chỉ sửa docs**; không gọi Simulator QA là thử trên máy thật. Nếu không có Mac hoặc credential backend, hoàn thành tối đa code/test trong môi trường được phép, báo một lần chính xác blocker và hướng dẫn tối thiểu để cấp quyền.

**BẮT ĐẦU NGAY G0 + G1:** audit Swift HUD/camera state và sửa source có tests. Trước tiên báo current git SHA và trạng thái CI thật.
