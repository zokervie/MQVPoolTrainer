# Nhiệm vụ 0.48b + 0.49 — Intro thương hiệu, VFX cuối trận, hệ leo hạng, bố cục chuyên nghiệp

Chủ dự án yêu cầu 18/11 12:17. Thứ tự: **sửa CI 159 (REVIEW-0.45-0.47.md) → 0.48 máy quay (NHIEM-VU-0.48-MAY-QUAY.md) + 0.48b dưới đây → 0.49 dưới đây → 0.50 bản thử người lạ.**
Kiến trúc và quy trình chung: `docs/de-xuat/KIEN-TRUC-VA-QUY-TRINH.md`. Quy tắc nhánh như các nhiệm vụ trước.

---

## 0.48b — Intro thương hiệu và VFX cuối trận (gộp vào nhánh `cho/native-0.48`)

### B1. Intro 3,5 s (lần đầu) · 1,2 s (từ lần 2) · chạm để bỏ qua
| Thời điểm | Hình | Tiếng |
|---|---|---|
| 0–0,4 s | Đen → đèn bàn bật chớp 2 nhịp, nỉ hiện ra trong vùng sáng | Tiếng tách công tắc + hum đèn |
| 0,4–1,4 s | **Logo PNG lướt ngang màn hình** trái → phải, vệt mờ chuyển động + vệt sáng anamorphic chạy theo | Tiếng gió vút + tiếng cơ chạm bi (mẫu có sẵn) |
| 1,4–2,2 s | Logo phanh lại **ở giữa**, nảy 1,15 → 1,0; bụi phấn vàng bung quanh; vệt ánh kim quét chéo qua logo | **Sonic logo** (Suno, xem B4) + sub-bass |
| 2,2–3,0 s | Khẩu hiệu hiện dần dưới logo: "Luyện mắt · Tính đường · Ra cơ chuẩn" | Đuôi sonic logo |
| 3,0–3,5 s | Logo thu nhỏ bay lên góc, mờ vào Sảnh | — |
- Nền: cảnh bàn thật mờ sâu + hạt bụi trong luồng đèn (dùng lại `ShotFX`, không thêm engine). Logo là **ảnh PNG nền trong suốt** chủ dự án gửi (`BankLab/Assets.xcassets/BrandLogo.imageset`, ≥ 1024 px). Chưa có file: tạm dựng chữ "ZOKER" + chữ Z vector, ghi rõ trong nghiệm thu.
- Giữ dự phòng 2D nếu cảnh chưa sẵn trong 0,5 s, Reduce Motion, Nguồn điện thấp (như 0.44.1).
- Kiểm: đầu dò độ sáng 5 thời điểm; logo ở giữa ±2 % lúc 2,0 s; tổng thời gian ±0,1 s; không khung nào > 33 ms.

### B2. VFX + SFX cuối trận (đấu máy, Chơi gần) và cuối bài
| Kết quả | Hình (≤ 3 s, chạm để qua) | Tiếng |
|---|---|---|
| Thắng trận | Bi quyết định rơi lỗ quay chậm → máy cẩu lên → bụi phấn vàng + logo đóng dấu "THẮNG" → tỉ số đếm lên | Sting thắng (Suno) |
| Thua trận | Đèn dịu, chữ "Gỡ lại?" + nút Đấu lại / Xem lại cú quyết định | Sting nhẹ, không buồn |
| Lên danh hiệu / mở chương | Thẻ danh hiệu xoay 3D, viền ánh kim, sao bay vào | Sting danh hiệu |
| Kỷ lục mới | Số cũ gạch, số mới đập vào | Tiếng "ting" ngắn |
- Ngân sách: "Cảnh 3D" p95 tăng ≤ 0,5 ms; tắt rung/máy rung khi Reduce Motion.

### B2b. Khói màu khi bi lọt lỗ (chủ dự án yêu cầu 19/11 16:00 — "mịn màng, hơi khói, màu màu")
- Thay tia sáng hiện tại bằng **khói mềm theo màu bi**: `SCNParticleSystem` một lần bung ở miệng lỗ, ảnh hạt là chấm tròn mờ dần (gradient tròn, tự tạo bằng mã), không dùng ảnh ngoài.
- Thông số khởi điểm (đã thử trên bản phác hoạ 19/11; chủ dự án chỉnh được trong Tuỳ chỉnh → Hiệu ứng): 30–50 hạt; sống 0,8–1,4 s (mặc định 1,1 s); cỡ 2 cm → 5–8 cm; bay lên 1–3 cm/s, toả ngang nhẹ, giảm tốc dần, xoay chậm; độ mờ 0 → 35 % → 0 theo đường sin; màu = màu bi pha 35–65 % trắng (bi đen: xám khói); trộn kiểu alpha (không cộng sáng), không chịu ánh sáng.
- Thêm vòng sáng mảnh nở ra ở mép lỗ 0,45 s, màu kem nhạt.
- Lực lọt mạnh → nhiều hạt hơn (tỉ lệ theo tốc độ bi lúc vào lỗ, kẹp 20–60).
- Dùng chung một bộ hạt có sẵn (pool 6 hệ), không tạo mới mỗi lần; ngân sách "Cảnh 3D" p95 tăng ≤ 0,5 ms.

### B2c. Nhoè chuyển động cho bi nhanh (giật cảm nhận ở 60 Hz)
Số đo 19/11 (IPA 162, 60 Hz): 0/461 khung thiếu, khung đều 16,7 ms → máy không rơi khung; bi 4 m/s nhảy ~6–7 cm mỗi khung nên mắt thấy "bước". Vẽ 2–3 bóng mờ của bi tại các vị trí con giữa hai khung (lấy từ mẫu vật lý 960 Hz), độ mờ theo tốc độ, chỉ khi bi > 1,5 m/s. Không dùng motion blur hậu kỳ của SceneKit. Kiểm: ảnh chụp bi 4 m/s có vệt; "Cảnh 3D" p95 tăng ≤ 0,3 ms. Đồng thời đo lại 120 Hz (sau 0.45 M1) — nếu ≤ 2 % khung thiếu thì bật 120 Hz mặc định cho máy ProMotion.
- Bỏ 10 lượt bố cục UIKit giữa cú (phải là 0).

### B3. Âm thanh: lớp và mức
- Mỗi lớp một file trong `Resources/Brand/` (sonic-logo, win, lose, rank-up, record, lobby-loop). Mix −16 LUFS, đỉnh ≤ −1 dBFS (như 0.44.1).
- Nhạc nền Sảnh mặc định **tắt**, bật trong Tuỳ chỉnh (người chơi bida hay nghe nhạc riêng).

### B4. Prompt Suno (chủ dự án tạo, gói **Pro/Premier** để có quyền thương mại; cắt đoạn đẹp nhất)
1. *Sonic logo (2–3 s):* `sonic logo, premium sports brand, single crisp billiard ball click into deep sub-bass hit, rising shimmering synth swell resolving to a bright major chord, cinematic, confident, clean ending, no vocals, 3 seconds`
2. *Sting thắng (3 s):* `victory sting, cinematic hybrid orchestra with punchy drums, triumphant brass hit, golden shimmer tail, energetic but classy, no vocals, 3 seconds`
3. *Sting thua (2 s):* `gentle comeback sting, warm electric piano and soft pad, hopeful, encouraging, not sad, no vocals, 2 seconds`
4. *Sting danh hiệu (3 s):* `level up sting, sparkling synth arpeggio rising into a bold chord with chime accents, rewarding, premium game UI, no vocals, 3 seconds`
5. *Nhạc Sảnh (60–90 s, vòng lặp):* `chill lounge hip hop instrumental for a classy billiards club at night, smooth Rhodes, upright bass, soft vinyl texture, 84 BPM, seamless loop, no vocals`
Gửi file WAV/MP3 vào repo (`Resources/Brand/`), ghi trong `Docs/AM-THANH-NGUON.md`: tên prompt, ngày tạo, gói Suno lúc tạo.

---

## 0.49 — Hệ leo hạng và bố cục chuyên nghiệp

### L1. Luật thành thạo 70–80–90 (thay 3/5 và 7/10 của 0.47)
- Mỗi lượt bài = 10 cú. **≥ 70 % = Đạt (1 sao) → mở bài kế.** ≥ 80 % = Giỏi (2 sao). ≥ 90 % = Xuất sắc (3 sao).
- **Thi chương: ≥ 80 %** để mở chương sau; đi kèm "Trùm chương" = đấu máy cấp tương ứng (chương n ↔ máy cấp n), thắng mới nhận danh hiệu chương.
- Trượt 3 lần liền ở 50–69 %: mở **bài tách nhỏ** (biến thể dễ hơn: bi gần hơn, góc nhỏ hơn) để không bỏ cuộc; đạt bài tách nhỏ thì quay lại bài chính.
- Lõi C++ + test (sửa `Chapters.h`): ngưỡng, mở khoá, tách nhỏ; dữ liệu cũ (sao 0.47) giữ, quy đổi.

### L2. Lặp lại có hẹn (giữ kỹ năng)
- Bài đã Đạt quay lại "Ôn lại" theo hộp Leitner: Đạt sau 1 ngày · Giỏi sau 3 · Xuất sắc sau 7 · ôn đạt lần 2 thì giãn gấp đôi; ôn < 70 % về hộp đầu.
- Bài hôm nay = 1 bài mới + 1 bài ôn + 1 bài xen kẽ (`BLDailyPickMixed`).

### L3. Tự tôn → chinh phục
- **Danh hiệu** theo chương: Tập sự → Thợ cơ → Tay CLB → Cao thủ phong trào → Bán chuyên → Bậc thầy. Hiện trên Hồ sơ, Sảnh, thẻ chia sẻ.
- **Huy hiệu thành thạo**: cả chương 3 sao → "Bậc thầy cú cắt", "Bậc thầy băng"…
- **Kỷ lục cá nhân** mỗi bài; "Tuần này bạn giỏi hơn tuần trước ở X".
- **Thẻ chia sẻ**: danh hiệu + mã thách bạn (0.47 M6) — khoe được.
- Không ép: không bán lượt, không đồng hồ chờ, không thông báo dồn.

### L4. Bố cục ứng dụng (thay Sảnh 0.46)
Điều hướng 4 mục, thanh dọc bên trái (iPhone ngang) / thanh dưới (iPad dọc):
| Mục | Nội dung |
|---|---|
| **Hôm nay** | Thẻ lớn Bài hôm nay (3 bài, chuỗi ngày), Tiếp tục, Ôn lại |
| **Lộ trình** | Bản đồ 6 chương dạng đường đi; mỗi nút = bài (khoá / 1–3 sao), cuối chương = Trùm; Sổ mẹo |
| **Đấu** | Đấu với máy (6 ô ngang — bản canvas 18/11), Chơi gần, Thách bạn (nhập mã) |
| **Hồ sơ** | Danh hiệu, Tiến bộ (biểu đồ), huy hiệu, Bộ sưu tập (bàn, cơ, phòng), Highlight |
Bánh răng Tuỳ chỉnh góc phải trên. Bàn 3D mờ làm nền mọi màn.
- **HUD trong bàn: 3 vùng cố định.** Trái: bộ cơ + nút B. Phải: thanh lực + 3 nút (Xem lại · Lùi cú · Bàn). Trên giữa: mục tiêu bài ("4/10 · cần 7"). Coach, Đặt bi, Thêm bi vào nút Bàn. Không gì khác.
- Cỡ chữ: một thang ZDesign (13 / 15 / 17 / 22 / 28), không tự co chữ trừ nút; mọi bảng chọn dùng ô ngang hoặc lưới, không danh sách dài phải cuộn.
- Kiểm: đếm chạm tới 5 việc chính không tăng; XCTest đi qua 4 mục; ảnh iPhone + iPad.
