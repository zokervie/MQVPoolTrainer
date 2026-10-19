# Tiến độ

Đánh dấu `[x]` chỉ khi đã build và chạy test thật (CI macOS hoặc thiết bị). Phần chỉ chạy được trên iPhone thật ghi rõ **chưa xác minh trên thiết bị**. Kế hoạch và KPI: UPGRADE.md. Lập luận: REVIEW.md.

## Trạng thái hiện tại (19/10/2026, bản 0.3 — MVP)
- CI (`.github/workflows/ci.yml`, macOS 15, Xcode 16.4, Swift 6.1.2): 4 package build và chạy test; app build cho iOS Simulator; job `validation` chạy đối chứng pooltool và đo hiệu năng bản release.
- App **chưa chạy trên iPhone thật**: chưa kiểm tra hình ảnh, cảm ứng, rung, âm thanh, độ trễ, nhiệt.
- Âm thanh là bộ mẫu tổng hợp tạm; **chưa nghe thử**.
- Chưa đo bàn thật (R4 cần dụng cụ và bàn bida).

## Tuân thủ quy trình (rà soát 19/10/2026)
Từ 19/10 làm lại đúng CLAUDE.md: **mỗi phiên một nhiệm vụ**, theo thứ tự lộ trình, chỉ một agent ghi vào nhánh này tại một thời điểm.
- Đêm 18–19/10 đã làm R0–R5 + âm thanh + phát hành trong một chuỗi phiên liền, nhiều nhiệm vụ mỗi commit → lệch quy tắc "một nhiệm vụ/phiên".
- **R5 làm trước Cổng 1** (UPGRADE.md 5: không qua Cổng 1 thì không làm R5). Giữ code (UPGRADE 2.1: không xóa tính năng đang chạy) nhưng **không tính là xong** cho tới khi qua Cổng 1; không phát triển thêm R5 trước đó.
- Việc phát hành/CI của `main` (dự án 3.1) nằm ngoài phạm vi nhánh này; không sửa `main` từ phiên Zoker nữa.
- Thứ tự tiếp theo: R1.7 → R1.8 (P2, P3 miệng lỗ) → R2 trên thiết bị (U1–U3, H1–H3) → R4 (Cổng 1).

## R0 — Kiểm toán kỹ thuật
- [x] R0.1 `swift test` PoolPhysics trên macOS — run 39141482324: 18/18 test qua
- [x] R0.2 PoolInput 11/11, PoolDrills 2/2 (cùng run)
- [x] R0.3 `xcodegen generate` + build app iOS Simulator thành công. Cấu hình chỉ màn hình ngang đã đặt trong `project.yml`; **chưa quan sát trên thiết bị**
- [x] R0.4 Rà phương trình: phát hiện và sửa dấu xoáy ngang sai trong `CueModel` cũ (test `testSquirtDirectionAndSize`)
- [x] R0.5 `RenderMapping` + test (gốc tâm bàn, giữ chiều tay phải); App dùng hàm này cho mọi tọa độ
- [x] R0.6 Manual Stroke → Shot Lab trong docs

## R1 — Bộ giải nhiều bi + đối chứng
- [x] R1.1 pooltool **0.6.0**, giấy phép Apache-2.0. Mô hình mặc định đọc từ gói đã cài: bi–bi `FrictionalInelastic`, băng `StrongeCompliantLinear/Circular`, lỗ `CanonicalBallPocket`, cơ–bi `InstantaneousPoint`
- [x] R1.2 `Tools/validation/pooltool_compare.py` + `poolsim` (lấy trạng thái sau cú đánh từ pooltool, đưa vào PoolPhysics)
- [x] R1.3 Thời điểm va chạm bi–bi (cô lập nghiệm đa thức + chia đôi)
- [x] R1.4 Thời điểm va chạm bi–băng, bi–mũi băng
- [x] R1.5 Sự kiện đồng thời: cửa sổ 1 ns, thứ tự xác định; ngưỡng tiếp xúc chống Zeno; giới hạn 20.000 sự kiện; test độ nhạy thứ tự M7 (kết quả ở Nhật ký)
- [x] R1.6 Lỗ: mép (điểm), đường bắt giữ. Chưa có mặt vát miệng lỗ, bi bật khỏi lỗ
- [x] R1.6b `CollisionRecord` (loại, thời điểm, vị trí, tốc độ pháp tuyến, xung lực, trượt tiếp tuyến, id bi, lỗ)
- [ ] R1.7 M1–M6 trên **10.000** cú — hiện chạy 300 cú ngẫu nhiên trong CI (đạt); bộ 10.000 cú chưa chạy
- [ ] R1.8 P1–P3: chuyển động và bi–bi **đạt P1** (≤ 5 mm); băng thẳng đạt 66% so Han 2005, chưa đạt so Stronge; miệng lỗ chưa so được (xem Vấn đề mở); **P2 (hướng bi ±0,1°) chưa báo cáo; P3 chưa đạt** (lệch miệng lỗ chưa có giải thích + test tái hiện)

## R2 — Lát cắt chơi được trên iPhone
Code xong, build qua; **chưa xác minh trên thiết bị** cho mọi mục:
- [ ] R2.1 Cảnh 3D (ARView non-AR): bàn đúng kích thước, bi có số, bi cái có chấm, bóng tiếp xúc, kim cương, cơ
- [ ] R2.2 Camera thứ nhất (FOV theo tỉ lệ), chế độ nhìn từ trên
- [ ] R2.3 Ngắm bằng vuốt, bi effect
- [ ] R2.4 Vùng khóa ẩn + rung
- [ ] R2.5 Vuốt ra cơ, ghi `TouchRecording` mỗi cú
- [ ] R2.6 Phản hồi sau cú: lực, quãng lăn, độ thẳng vuốt, ngắt cơ, khoảng ngắm theo mục tiêu bài tập
- [ ] R2.7 Đo U1, U3, H1–H3 trên thiết bị
- [x] R2.8 `PoolAudio`: AudioEvent từ CollisionRecord, 6 loại; A1 qua
- [x] R2.9 `AudioScheduler` xác định, gộp sự kiện, giới hạn giọng, giãn thời gian replay; A2 qua
- [x] R2.10 `SampleLibrary` + bản ghi giấy phép; bộ mẫu tổng hợp tạm (sở hữu dự án); A5 qua
- [ ] R2.11 Phát bằng AVAudioEngine (dựng sẵn buffer cả cú, phát theo đồng hồ máy), cài đặt âm thanh — build qua, **chưa nghe thử**
- [ ] R2.12 A3 qua (render offline cú phá, đỉnh ≤ −1 dBFS); A4 (lệch âm–hình) chưa đo trên thiết bị

## R3 — Vật lý MVP
- [x] R3.1 Cơ–bi theo xung lực, trượt cơ > 0,5R (thay `speedRatio`)
- [x] R3.2 Throw, ma sát bi–bi phụ thuộc tốc độ (Alciatore TP A.14)
- [x] R3.3 Squirt (Alciatore TP A.31)
- [x] R3.4 Băng phụ thuộc tốc độ và xoáy — mô hình **đơn giản hóa** (pháp tuyến nghiêng theo độ cao mũi băng), khác Mathavan/Stronge
- [x] R3.5 TableDefinition + CalibrationProfile, dùng trong app (TableStore), lưu/đọc JSON

## R4 — Thực nghiệm bàn thật (Cổng 1)
Công cụ đã có và kiểm thử trên dữ liệu tổng hợp (7/7 test Python); **chưa có dữ liệu thật**:
- [ ] R4.1 Hiệu chỉnh méo ống kính — hàm OpenCV có sẵn, chưa chạy
- [ ] R4.2 Phép chiếu mặt phẳng tâm bi z = R — công cụ xong và kiểm thử tổng hợp; chờ dữ liệu
- [ ] R4.3 Độ không chắc chắn hệ đo — công cụ xong; chờ dữ liệu
- [ ] R4.4 Máng lăn, thí nghiệm 1–4 — cần làm trên bàn thật
- [ ] R4.5 Hiệu chỉnh — hàm khớp cản lăn, phục hồi băng; xuất CalibrationProfile cho app
- [ ] R4.6 Báo cáo T1–T6

## R5 — Luyện tập
> ⚠ Làm trước Cổng 1 — code và test giữ nguyên, **chưa tính vào lộ trình** (xem Tuân thủ quy trình).

- [x] 10 bài tập; test khả thi: mỗi bài có khoảng ngắm đạt trong mô hình (Nhật ký)
- [x] Điều kiện đạt, chấm điểm, lịch sử (`ShotLog`), phân tích lỗi bằng quy tắc, Shot Lab — package test qua; giao diện build qua, chưa thử trên thiết bị
- [x] Hồ sơ bàn chỉnh tay (nguồn gốc ghi "giả định")

## R6–R7
Chưa bắt đầu. Âm thanh bậc B: R7.A1–A4 (UPGRADE.md 6.9).

## Nhật ký
- 18/10/2026 · R0.1 · Linux, không có Swift → chưa xác minh (lịch sử).
- 18/10/2026 · Bản 0.2 · Đồng bộ tài liệu theo D1–D5.
- 18/10/2026 · Kế hoạch · Thêm Zoker Acoustic Physics (UPGRADE.md mục 6).
- 18/10/2026 · CI · Repo `zokervie/MQVPoolTrainer`, nhánh `feature/zoker-mvp`. Run 39141482324: PoolPhysics 18/18, PoolInput 11/11, PoolDrills 2/2, app build OK (Xcode 16.4, Swift 6.1.2). → R0.1–R0.3.
- 18/10/2026 · R1/R3 · Bộ giải sự kiện, băng, lỗ, throw, squirt: run 39142053378 — PoolPhysics 33/33 (gồm 300 cú ngẫu nhiên: không chồng lấn > 1 µm, động năng không tăng, lặp lại từng bit).
- 18/10/2026 · Âm thanh · PoolAudio 8/8 (A1, A2, A3 offline, A5).
- 18/10/2026 · Bài tập · Test khả thi phát hiện thang lực cũ quá mạnh (mức 3 = 2,0 m/s cho bi lăn ~7 chiều dài bàn) và 4 bài thiết kế sai hình học → đổi thang lực theo quãng lăn, thiết kế lại bài 01, 04, 06, 07.
- 19/10/2026 · Đối chứng pooltool 0.6.0 (bàn 7 ft mặc định, cùng tham số): chuyển động tự do 35 cú trung vị 0,0 mm (100% ≤ 5 mm); có bi–bi 70 cú trung vị 14,7 mm, p90 20,9 mm (0% ≤ 5 mm); có băng 61 cú trung vị 3,1 mm, p90 220 mm, max 1,29 m. Biến thể tắt ma sát bi–bi: bi–bi xấu hơn (trung vị 49 mm) → throw đúng hướng, khác biệt còn lại nằm ở chi tiết mô hình ma sát.
- 19/10/2026 · Chống Zeno · Cú phá từng chạm giới hạn 20.000 sự kiện (5/30, rồi 157/200 khi thử e = 0). Nguyên nhân: va chạm lặp tại cùng thời điểm do vận tốc tương đối ≈ 0 sai số làm tròn. Sửa bằng ngưỡng tiếp xúc. Run 39148501922: PoolPhysics 34/34; **H1 bench release trên CI macOS: 200 cú phá p50 10,2 ms, p95 18,8 ms, max 31 ms, trung vị 136 sự kiện, 0 cú chạm giới hạn** (chưa đo trên iPhone).
- 19/10/2026 · M7 · Cú phá (16 bi, xếp sát): đảo thứ tự xử lý va chạm đồng thời làm vị trí cuối lệch trung bình 0,58 m, tối đa 1,25 m. Cú phá hỗn loạn với thứ tự; không ảnh hưởng bài tập (không có bi xếp sát).
- 19/10/2026 · Xác minh độ chân thật (run 39154969173, xanh toàn bộ):
  - **Đối chiếu tài liệu Alciatore** (`LiteratureTests`, 9 test, PoolPhysics 43/43): throw do cắt tối đa 5,23° ở cắt 35° (tài liệu ~5°, gần nửa bi); cắt ≤15° không phụ thuộc tốc độ; cắt lớn giảm theo tốc độ; bi lăn throw ít hơn stun; throw do xoáy tối đa 5,11° ở 0,25R (≈50% xoáy tối đa); quy tắc 30° nằm trong 27–34°; quãng trượt stun đúng 12v²/(49μg); squirt 2,28° ở 0,5R.
  - **pooltool, nguyên nhân gốc lệch bi–bi 15 mm:** harness đặt ma sát hằng 0,05 trong khi pooltool dùng ma sát Alciatore. Sửa harness → bi–bi trung vị 1,1 mm, p90 2,0 mm, 100% ≤ 5 mm (**đạt P1**).
  - **Băng:** tách cú chạm băng thẳng (cushion) khỏi cú chạm mũi lỗ/rơi lỗ (jaw). pooltool đổi sang mô hình Han 2005 (cùng họ với mô hình của ta): băng thẳng trung vị 0,0 mm, 66% ≤ 5 mm (so Stronge mặc định: 18,3 mm, 6%) → chênh lệch chính là do **chọn mô hình**, không phải lỗi cài đặt. Đổi chiều cao mũi băng 0,64 → 0,635·2R làm trung vị 0 → 14 mm: tham số rất nhạy, phải đo trên bàn thật.
  - **Âm thanh** (`SpectrumTests`): phát hiện tiếng bi–bi mạnh gần như không sáng hơn tiếng nhẹ (trọng tâm phổ 2841 → 3268 Hz, ×1,15). Sửa: phổ kích thích theo thời gian tiếp xúc Hertz (~250 µs ở 1 m/s, ∝ v^−1/5, giả định) → 2051 → 2901 Hz (×1,41). PoolAudio 10/10. File WAV nghe thử trên nhánh `shots/zoker/audio`.
  - **Hình ảnh** (ảnh simulator): sửa camera bị kéo theo bi cái khi cú đang chạy (giờ đứng yên ở chỗ ngắm); tên lỗ có dấu; thêm thân bàn và sàn (lần đầu bị z-fighting làm nỉ loang nâu — đã sửa); nút phản hồi không xuống dòng; ảnh CI xoay đúng chiều; phát cú chậm ×0,35 chỉ trong autotest để chụp được giữa cú.

- 19/10/2026 · Thành phẩm · `codemagic.yaml`: `zoker-ipa-unsigned` (không cần tài khoản Apple trả phí) và `zoker-testflight` (ký tự động, TestFlight). Thêm icon, phiên bản 0.3.0, mã gói `com.zokervie.pooltrainer`. Script build IPA chạy thật trên GitHub Actions (run 39180486858): Release arm64, IPA chưa ký 868 KB. **Chưa chạy trên Codemagic, chưa cài thử lên iPhone.**

- 19/10/2026 · Workflow · Phân phối IPA chuyển sang GitHub Release cố định `zoker-latest` (tag dời theo commit, số build = số lần chạy, kiểm chứng mã băm sau khi đăng); IPA chỉ build khi test qua; ghim Xcode 16.4; action Node 24; Codemagic chạy tay. Run 39206625671: xanh, `zoker-latest` = 7d7e8d9, build 21. Tên hiển thị đổi thành "Zoker Trainer". Cũng sửa `ios.yml` trên `main` (run 39206525954 xanh, `ios-latest` = 3df3b4f, build 14).

- 19/10/2026 · Đối chứng băng từng va chạm (run 39214085792): 246 lần chạm băng thẳng của pooltool Han 2005, đưa đúng trạng thái trước va chạm vào `CushionCollision.resolve` → vận tốc và xoáy sau va chạm **khớp tuyệt đối** (|Δv| 0,000 mm/s, |Δω| 0,0000 rad/s). Công thức băng đã được xác minh; phần lệch còn lại ở nhóm "băng" đến từ hình học: 19/246 lần chạm của pooltool nằm ở đoạn băng xiên sát miệng lỗ, nơi bàn của ta không có đoạn băng thẳng.
- 19/10/2026 · Phát hành · Repo bật Release bất biến → không dời tag/sửa Release được nữa. Đổi sang: mỗi build một Release `zoker-v<phiên bản>-b<build>` (giữ 10) + link cố định qua nhánh `dist-zoker`. Run 39217870570 xanh (b27). Thêm `Tools/mac/setup-runner.sh` + workflow `device.yml` (build bằng Xcode trên Mac của người dùng, cài thẳng iPhone) — **chưa chạy thử, chờ cài runner trên Mac**.

## Vấn đề mở
- **Băng:** công thức trùng Han 2005 (đã so từng va chạm). Phần lệch còn lại do hình học đoạn băng gần miệng lỗ khác pooltool — gộp với vấn đề miệng lỗ bên dưới. Chọn Han hay Stronge chỉ quyết bằng số đo bàn thật (R4).
- **Miệng lỗ (jaw):** hình học lỗ hai engine khác hẳn (ta: đường bắt + đoạn mũi; pooltool: băng cong + lỗ tròn) → so jaw chưa có ý nghĩa (trung vị ~100 mm, 9–12 bi vào lỗ ở một bên). Cần dựng cùng hình học lỗ trước khi so.
- **Chiều cao mũi băng** nhạy cao (0,5% đổi trung vị 0 → 14 mm): ưu tiên đo ở R4.
- **M7 cú phá:** độ nhạy thứ tự lớn; nếu cần cú phá ổn định hơn, xem xét giải đồng thời theo nhóm.
- Hằng số điều khiển (độ nhạy ngắm, đường cong vuốt, vùng chạm) là giả định, chỉnh khi đo U3–U5.
- Ngưỡng tiếp xúc chống Zeno (0,1 mm/s, 0,1 µm, khe 10 µm) là giả định kỹ thuật.
- Ngưỡng T1 (0,5° / 1,0°) chỉ tuyên bố được khi độ không chắc chắn hệ đo ≤ ~0,17° (k = 2).
- Lịch sử lưu JSON thay vì SwiftData (đơn giản, ổn định với Swift 6); đổi sau nếu cần đồng bộ iCloud.
