# NHIỆM VỤ 0.49c — Giao diện bàn chơi + sơ đồ bài + Đấu với máy (phiên Mac)

Chủ dự án chấp thuận 21/11 09:39: D1 (mức Đạt theo độ khó) và D2 (chương Bank không chặn) của 0.49b, cùng 4 việc mới G1–G4 dưới đây. G5–G7 là phản hồi máy thật IPA 163 (20/11). Làm trên `cho/native-0.49-xuong-bai`, sau X1–X3 của 0.49b. Mỗi việc một commit + test; ảnh phòng chuẩn trước/sau cho G1, G2, G3, G5.

## G1. Sơ đồ bài = ảnh nhìn từ trên cao của chính bàn trong game (thay X4 phần vẽ bàn)
- Hiện trạng (ảnh chủ dự án): hình chữ nhật xanh phẳng, lỗ là chấm đen, không thấy miệng lỗ và mép băng.
- Làm: chụp bàn đang dùng từ camera thẳng đứng (SCNRenderer offscreen, không đèn bóng gắt, không bi), cache theo họ bàn + màu nỉ + cỡ bàn; vẽ lên đó: bi (đúng màu, có viền), vòng đích, lỗ đích, số nút, đường gợi ý (theo luật X4).
- Tỷ lệ đúng bàn thật (cỡ 7/8/9 ft); lỗ và mũi băng phải nhìn rõ ở cỡ thẻ trên iPhone SE.
- Nghiệm thu: ảnh `drill-detail` mới thấy rõ 6 miệng lỗ + băng; thời gian mở màn bài ≤ 150 ms lần đầu, ≤ 30 ms khi đã cache (đo trên Simulator CI).

## G2. Menu và "Đấu với máy": khung gỗ đặc, chữ thư pháp cho tiêu đề
- Hiện trạng: tấm kính mờ trong suốt, cỡ chữ mỗi dòng khác nhau (do tự co chữ cho vừa), tên cấp tiếng Anh.
- Khung: tấm gỗ đặc (vân gỗ tối, viền chạm nổi, bóng đổ nhẹ), KHÔNG trong suốt; mỗi mục một "thẻ gỗ" cùng kích thước.
- Chữ: **tiêu đề** (tên màn, tên cấp) dùng nét bút lông kiểu "bút lửa" — chữ khắc cháy trên gỗ: màu nâu cháy, mép sáng ấm. Font đề xuất: **Petemoss** (nét bút lông, có tiếng Việt, OFL 1.1 — dùng thương mại được, phải kèm OFL.txt và ghi ở màn Pháp lý). Phương án dự phòng: Playwrite VN (OFL, mẫu chữ viết tay tiểu học Việt Nam). Không dùng font "thư pháp Việt" thương mại không rõ giấy phép.
- **Nội dung** (mô tả, dòng phụ) giữ chữ không chân (SF) để dễ đọc. Thang chữ cố định 3 cỡ: tiêu đề 28, dòng chính 17, dòng phụ 13. **Bỏ tự co chữ**; dòng dài thì xuống 2 dòng.
- Tên cấp tiếng Việt (đề xuất 18/11, nay áp dụng): Tập sự · Nghiệp dư · CLB · Phong trào · Chuyên nghiệp · Đỉnh cao; dòng phụ là mô tả ngắn hiện có. Tiếng Anh giữ Beginner … AI.
- Áp dụng cho: Menu, Đấu với máy, hộp chọn chương. Kiểm VoiceOver và Dynamic Type (cỡ lớn nhất không tràn khung).

## G3. Thanh lực: nhỏ lại, dời chỗ, bật/tắt ngay trên màn
- Vị trí: thanh dọc nhỏ (≈ 28 × 180 pt trên iPad, tỉ lệ theo màn) ở chỗ chủ dự án đánh dấu: giữa thước góc nâng cơ và cột nút phải.
- **Chạm giữ để phóng to** (như quả bi chọn điểm chạm): phóng to ×2,5 quanh ngón tay để chỉnh mịn; thả là đánh (giữ đúng luật đánh hiện có của thanh lực).
- Nút nhỏ bật/tắt thanh lực trong cụm phím trái (cạnh nút đặt bi/điểm chạm); tắt = chỉ đánh bằng vuốt (kiểu riêng của Zoker). Lưu lựa chọn; cũng có trong Tuỳ chỉnh.
- Nghiệm thu: UI test bật/tắt, phóng to khi giữ, lực đánh ra khớp % hiển thị (± 1 %).

## G4. Ẩn dải quang phổ khi vuốt
- Bỏ dải màu chạy ngang đáy màn khi vuốt. Chỉ còn: % lực hiện ở cuối điểm vuốt (đã có) và trên thanh lực (nếu bật).
- Giữ dải trong Tuỳ chỉnh › Chẩn đoán (tắt mặc định) nếu cần cho kiểm thử.

## G5. Bàn màu sáng bị chói (IPA 163)
- Giảm độ bóng/specular sơn bóng màu sáng; trần độ sáng (tone mapping/exposure) theo họ bàn. Đo: điểm ảnh cháy (≥ 250) trên vùng bàn ≤ 2 % ở ảnh phòng chuẩn.

## G6. Nút "Đặt bi" ra ngoài cụm (IPA 163)
- Nút riêng 64 pt ở mép trái, trên hàng Đánh/Jump/Massé/Break; chỉ sáng khi được đặt bi; chạm để kéo bi, chạm lại để xong.

## G7. Giật ở 60 Hz (IPA 163)
- Về 0 lượt bố cục UIKit giữa cú (đang 2) và bỏ tick 29,7 ms; làm B2c (nhoè chuyển động bi nhanh). Đo lại 60 Hz và 120 Hz trên iPad.

## G8. Luật phá 9 Ball (chủ dự án báo 21/11 09:40)
- Lỗi: phá chạm bi 1, có bi vào, vẫn tới lượt máy. Nguyên nhân: app bật luật phá 3 bi (WPA Regulation 16, tuỳ chọn giải đấu).
- Phiên đám mây đã sửa lõi cầu nối (`c41bf0d` trên `cho/native-0.49-xuong-bai`): `BLMatch.threeBallBreak` mặc định **tắt**.
- Việc Mac: công tắc "Luật phá 3 bi (giải đấu)" trong Tuỳ chỉnh (mặc định tắt, lưu lựa chọn, gán vào `BLMatch` mỗi ván). Khi bật mà phá chưa đạt: hiện dòng giải thích rõ "Phá chưa đạt luật 3 bi: cần 3 bi vào lỗ hoặc qua vạch đầu bàn — đối thủ được chọn". UI test: ván 9 Ball, phá có bi vào → vẫn lượt người phá.

## Thứ tự
G8 → G7 → G4 → G3 → G6 → G5 → G2 → G1. Báo cáo `NGHIEM-THU-0.49c.md` (PASS/FAIL/NOT RUN từng mục, ảnh, phần chưa xác minh trên thiết bị).
