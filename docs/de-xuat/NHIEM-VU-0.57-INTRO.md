# Giao việc 0.57 — intro 3 giây, đa giác quan (cho phiên Mac)

Chủ dự án duyệt 23/11 (chấp nhận lùi TestFlight vài ngày). Nguồn ý: tài liệu "Đặc tả intro điện ảnh" của chủ dự án;
phiên đám mây đã lọc theo code hiện có (`Intro0441.swift`, `IntroBreak.h`, `PoolAudio.swift`). Làm trên
`cho/native-0.53-phieu-lo`, sau 0.55. Một mục = một commit.

## Giữ nguyên (đã có, không viết lại)
Quay trên bàn chơi thật, cùng SCNView · cú phá 9-ball vật lý thật trong `BLWorld` riêng (`IntroBreak.h`, bi 8 rơi lỗ
đúng 1,000 s sau cú đánh) · chạm là bỏ qua ≤ 0,2 s · Giảm chuyển động / Tiết kiệm pin / nhiệt cao ⇒ logo tĩnh · lần mở
sau chỉ logo ≤ 1,2 s · 60 Hz · không DOF, không bloom, không motion blur.

## Việc
**I1. Rút lần đầu từ 6,0 s còn ≤ 3,2 s.** Mốc thời gian (giây):
- 0,00–0,45 đèn bàn sáng dần, camera thấp sát nỉ sau bi cái, bụi phấn lơ lửng (≤ 50 hạt).
- 0,45–0,95 camera trượt ngang 8 cm; cơ kéo lùi 12 cm, dừng 80 ms, lao tới.
- 0,95 cơ chạm bi: thu hẹp góc nhìn nhẹ (−3°) rồi mở rộng, nâng camera theo bi. Bỏ đoạn quay chậm 0,5 s (hoặc ≤ 0,12 s).
- 0,95–1,95 cụm bi vỡ, camera kiểu cẩu truyền hình; vệt mảnh sau bi nhanh.
- 1,95 bi 8 rơi lỗ (theo `BL_INTRO_FIRST_DROP_TIME`), tia sáng nhỏ ở miệng lỗ (≤ 10 hạt).
- 2,15–3,00 chữ "ZOKER POOL" + câu ngắn ở góc trên trái, không che bàn; camera về góc ngắm.
- 3,00–3,20 chuyển sang sảnh / thế bi đầu.
Tổng hạt cùng lúc ≤ 60. Hằng số thời gian để một chỗ.

**I2. Rung theo nhịp (CoreHaptics).** File `IntroHaptics.swift`: 0,87 (cơ dừng, nhẹ 0,25) · 0,95 (chạm bi, sắc 0,85 /
mạnh 0,9) · 2–3 nhịp nhỏ đúng thời điểm va chạm bi–bi thật lấy từ sự kiện của `BLWorld` (không gõ cứng) · 1,95 (rơi
lỗ, trầm 0,25 / 0,65). Máy không hỗ trợ hoặc người dùng tắt rung: bỏ qua im lặng. Bỏ qua intro ⇒ dừng rung ngay.

**I3. Nhạc tự hạ.** Khi cơ chạm bi, nhạc/âm nền của intro giảm 6 dB (xuống 80 ms, giữ ~1,2 s, hồi 450 ms).

**I4. Tiếng bi tách trái–phải.** Trong `PoolAudio`: pan theo toạ độ x của va chạm (−0,8…+0,8 trên bề ngang bàn), cao
độ lệch ngẫu nhiên ±3 %. Áp dụng cho cả lúc chơi, có công tắc trong Cài đặt âm thanh (mặc định bật). Không rè khi
nhiều va chạm liền nhau (giới hạn số tiếng đồng thời như hiện có).

**I5. Âm thanh.** KHÔNG thêm file âm mới nếu chưa có nguồn hợp lệ (CC0 / CC-BY / Sonniss / chủ dự án tự thu / Suno gói
trả phí). Dùng `PoolCue0`, `PoolBall0–3`, `PoolPocket0`, `IntroRiser/Jingle` sẵn có; tiếng xoay lơ và tiếng lăn có thể
tổng hợp bằng code (nhiễu lọc dải). Nhạc nền lounge: chờ file Suno của chủ dự án; để sẵn chỗ cắm (`IntroBGM` dataset,
không có thì im).

**I6. Không dùng tên thương hiệu thật** trong code, chú thích, chữ hiển thị (bi, nỉ, cơ: tên Z-…).

**I7. Test.** `IntroBreakTests` giữ xanh. UI test: intro lần đầu kết thúc ≤ 3,5 s (đồng hồ thật, có dung sai máy chậm);
chạm ở 0,3 s ⇒ điều khiển được trong ≤ 0,3 s; Giảm chuyển động ⇒ không có 3D. Quay `intro.mp4` mới vào `shots/native`.
Báo PASS / FAIL / NOT RUN. Cảm giác rung, âm thanh, độ mượt: chưa xác minh trên thiết bị.
