# Tiến độ

Đánh dấu `[x]` chỉ khi đã build và chạy test thật trên macOS/thiết bị. Ghi kết quả thật vào mục "Nhật ký". Kế hoạch và KPI: UPGRADE.md. Lập luận: REVIEW.md.

## Trạng thái hiện tại (18/10/2026, bản 0.2)
- Toàn bộ code Swift (PoolPhysics, PoolInput, PoolDrills, App) **chưa từng được biên dịch, chưa chạy test**.
- Bản 0.2 thêm (chưa biên dịch): `TableDefinition`, `CalibrationProfile`, `Provenance`, `RenderMapping` (PoolPhysics); `TouchRecording`, `StrokeConfig` (PoolInput); test tương ứng; CI chạy cả 3 package.
- Đã kiểm tra ngoài Swift: góc 33,7° của quy tắc 30° (Python); file workflow YAML đọc được.
- pooltool: giấy phép Apache-2.0 (trang GitHub); phiên bản và tính năng chưa xác minh.

## R0 — Kiểm toán kỹ thuật
- [ ] R0.1 `swift test` cho PoolPhysics trên macOS; chỉ sửa lỗi biên dịch, không đổi logic; ghi kết quả từng test
- [ ] R0.2 `swift test` cho PoolInput và PoolDrills; như R0.1
- [ ] R0.3 `xcodegen generate`, build app trên simulator, xác nhận chỉ màn hình ngang
- [ ] R0.4 Rà phương trình FreeMotion, CueModel, Collisions so với nguồn trong comment; báo cáo lỗi theo mức độ, mỗi lỗi có test tái hiện
- [ ] R0.5 Một hàm chuyển đổi tọa độ PoolPhysics (z lên, Double) ↔ RealityKit (y lên, Float) + test — **code đã có** (`RenderMapping`, `RenderMappingTests`), chờ chạy test; App chưa dùng nó
- [x] R0.6 Đổi tên khái niệm Manual Stroke → Shot Lab trong docs (chỉ tài liệu, không cần build)

## R1 — Bộ giải nhiều bi + đối chứng
- [ ] R1.1 Xác minh pooltool: đọc mã nguồn, ghi phiên bản/commit, xác nhận cơ chế va chạm đồng thời và bộ giải bậc bốn, ghi vào Nhật ký
- [ ] R1.2 Dựng `Tools/validation/` (Python): chạy pooltool từ file điều kiện ban đầu, xuất quỹ đạo
- [ ] R1.3 Thời điểm va chạm bi–bi chính xác (khoanh nghiệm + Newton/chia đôi)
- [ ] R1.4 Thời điểm va chạm bi–băng
- [ ] R1.5 Sự kiện gần đồng thời: cửa sổ Δt, thứ tự xác định; trạng thái tiếp xúc chống Zeno; giới hạn số sự kiện. Kèm **test độ nhạy thứ tự** (M7): hoán vị thứ tự xử lý trong cùng cửa sổ, đo độ phân tán vị trí dừng ở cụm bi và cú phá; báo cáo kết quả, không chỉ kiểm tra tính lặp lại
- [ ] R1.6 Lỗ: mép, thành, bi rơi
- [ ] R1.6b Bộ giải xuất `CollisionRecord` cho mỗi va chạm (loại, thời điểm, vị trí, tốc độ tương đối pháp tuyến, xung lực, trượt tiếp tuyến, id bi) — đầu vào cho âm thanh và haptic (UPGRADE.md 6.2)
- [ ] R1.7 Bộ test M1–M6 (10.000 cú có seed)
- [ ] R1.8 So sánh với pooltool (P1–P3), báo cáo khác biệt

## R2 — Lát cắt chơi được trên iPhone
- [ ] R2.1 Cảnh RealityKit đúng kích thước, phát lại quỹ đạo, bi có số, bi cái có chấm, bóng tiếp xúc
- [ ] R2.2 Camera thứ nhất, FOV theo tỉ lệ màn hình, chế độ đọc thế bi
- [ ] R2.3 Ngắm bằng vuốt khi chưa khóa; bi effect bên phải
- [ ] R2.4 Vùng khóa ẩn + haptic
- [ ] R2.5 Vuốt ra cơ; ghi chuỗi cảm ứng thô để phát lại (U2)
- [ ] R2.6 Phản hồi sau cú: mức lực, lệch vuốt, phát lại. **Sai số ngắm chỉ tính khi bài tập có mục tiêu cụ thể** (ví dụ bi N vào lỗ X): tính *khoảng* hướng ngắm đạt mục tiêu bằng PoolPhysics, báo khoảng cách từ hướng đã dùng tới khoảng đó (0 nếu nằm trong). Không mặc định có một đường đánh đúng duy nhất; chơi tự do không có mục tiêu thì không báo sai số ngắm
- [ ] R2.7 Đo U1 (độ trễ), U3 (khóa nhầm), H1–H3 trên thiết bị thật
- [ ] R2.8 Tạo package `PoolAudio` (Zoker Acoustic Physics): `AudioEvent` từ `CollisionRecord`, 6 loại (cueTip, ballBall, ballCushion, ballPocketJaw, ballDrop, miscue); test A1
- [ ] R2.9 `AudioScheduler`: lịch phát xác định, chọn biến thể bằng hàm băm, gộp sự kiện, giới hạn giọng, giãn thời gian cho replay; test A2
- [ ] R2.10 `SampleLibrary`: lớp lực × biến thể, trộn chéo lớp, bản ghi giấy phép từng file; bộ mẫu tạm có giấy phép thương mại; test A5
- [ ] R2.11 Engine phát trong App (`AVAudioEngine`, limiter, pan stereo, `AVAudioSession`), cài đặt âm lượng / bật-tắt / không gian / tai nghe; đồng bộ haptic
- [ ] R2.12 Đo A3 (render offline cú phá) và A4 (lệch âm–hình) trên thiết bị thật. **Không** đánh giá chất lượng âm thanh ở bước này

## R3 — Vật lý MVP
- [ ] R3.1 Va chạm cơ–bi theo xung lực, giới hạn trượt cơ (thay `speedRatio` tạm)
- [ ] R3.2 Throw (do cắt và xoáy ngang), ma sát bi–bi phụ thuộc tốc độ
- [ ] R3.3 Squirt
- [ ] R3.4 Băng 3D phụ thuộc tốc độ và xoáy
- [ ] R3.5 Hồ sơ bàn: TableDefinition + CalibrationProfile có schemaVersion, Provenance, validate() — **code đã có từ bản 0.2**, chờ test; còn thiếu: dùng trong App, lưu/đọc file hồ sơ

## R4 — Thực nghiệm bàn thật (Cổng 1)
- [ ] R4.1 Hiệu chỉnh camera (méo ống kính) bằng bàn cờ
- [ ] R4.2 Phép chiếu phối cảnh trên mặt phẳng tâm bi (z = R)
- [ ] R4.3 Đo độ không chắc chắn hệ đo (bi đứng yên, khoảng cách đã biết, hướng đã biết)
- [ ] R4.4 Máng lăn; thí nghiệm 1–4 (REVIEW.md C3), chia 50/50 trước khi xem kết quả
- [ ] R4.5 Hiệu chỉnh tham số bàn trên tập hiệu chỉnh
- [ ] R4.6 Báo cáo T1–T6 trên tập kiểm chứng, kèm bias theo góc cắt và tốc độ

## R5–R7
Xem UPGRADE.md mục 5. Chỉ thêm nhiệm vụ chi tiết sau khi qua Cổng 1.

Đã ghi trước cho R7 — âm thanh bậc B (UPGRADE.md 6.9):
- [ ] R7.A1 Thu mẫu bàn thật: ≥ 5 lớp lực × ≥ 4 biến thể mỗi loại, gắn tốc độ va chạm đo từ video 240 fps
- [ ] R7.A2 Hồ sơ vật liệu âm thanh trong `TableDefinition` (tăng schemaVersion), tinh chỉnh âm sắc
- [ ] R7.A3 HRTF / âm thanh không gian nâng cao cho chế độ tai nghe
- [ ] R7.A4 Nghe thử trên thiết bị thật với người chơi: A6, A7; đo A8

## Nhật ký
(Claude ghi kết quả build/test thật ở đây, mỗi phiên một dòng.)
- 18/10/2026 · R0.1 · **CHƯA XÁC MINH.** Môi trường là Linux x86_64, không có macOS, Xcode hay Swift (`swift: command not found`). Không chạy được `swift test`; 0 test được chạy. Không sửa mã nguồn. Ghi chú: PoolPhysics dùng `import simd` (chỉ có trên nền tảng Apple), nên cài Swift trên Linux cũng không thay thế được bước này. R0.1 phải chạy lại trên máy Mac.
- 18/10/2026 · R0.1 · Thêm `.github/workflows/r0-1-physics-tests.yml` (macos-15, Xcode 16.x, `swift test --package-path Packages/PoolPhysics`). **Chưa kích hoạt:** phiên này không có quyền truy cập repository GitHub (token không hợp lệ, chưa có tên repo). 0 test được chạy. R0.1 vẫn chưa xong.
- 18/10/2026 · Bản 0.2 · Đồng bộ tài liệu theo quyết định D1–D5 (CLAUDE.md, README, docs 01–07; docs/07-roadmap thay bằng docs/07-validation). Thêm code mới (xem Trạng thái). Logic vật lý cũ **không đổi**. Workflow thay bằng `.github/workflows/swift-packages-tests.yml` (ma trận 3 package; job PoolPhysics = R0.1). **Chưa biên dịch, 0 test chạy.**

- 18/10/2026 · Kế hoạch · Thêm Zoker Acoustic Physics vào UPGRADE.md (mục 6, KPI A1–A8) và nhiệm vụ R1.6b, R2.8–R2.12, R7.A1–A4. Không sửa mã nguồn; R0.1 không đổi.

## Vấn đề mở
- `CueModel.speedRatio` (1,4) là giá trị tạm, thay ở R3.1.
- Ngưỡng T1 (0,5° / 1,0°) chỉ tuyên bố được khi độ không chắc chắn hệ đo ≤ ~0,17° (k = 2).
