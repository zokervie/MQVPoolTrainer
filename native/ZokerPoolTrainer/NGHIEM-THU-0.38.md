# Nghiệm thu Zoker Pool / Trainer 0.38 — bản gộp (0.37 + toàn bộ đề xuất)

Nhánh `ci/native-0.38` · build **118** (CI xanh, run 42685018610) · IPA: [zoker-ipa-candidate-118](https://github.com/zokervie/MQVPoolTrainer/actions/runs/42685018610/artifacts/13705231390) · App hiện phiên bản **0.38**, tên trên màn hình chính **Zoker Pool**.
Cột **CI** = đã kiểm tra tự động. Cột **Máy thật** = anh tick khi thử.

## Nguyên nhân gốc đã tìm ra

| Lỗi anh thấy ở 0.36 | Nguyên nhân thật | Cách sửa |
| --- | --- | --- |
| Sọc vòng đồng tâm, loang màu, nhấp nháy trên nỉ (có từ trước 0.36) | **Phân tầng màu**: nỉ tối dưới một đèn chỉ hiện được khoảng 28 nấc màu nên lộ thành vành. Nỉ hơi bóng nên vệt sáng trượt theo máy, nhìn thành nhấp nháy. | Hạt nhiễu siêu mịn (dithering), nỉ hết bóng, vân dệt mờ trước ngưỡng giao thoa |
| Răng cưa, sọc ở viền gỗ và yếm bàn | Thân bàn tự đổ bóng lên chính nó (lỗi "shadow acne"). Nẹp vàng 5 mm và khe ghép 1,5 mm nhỏ hơn một điểm ảnh. | Chỉ bi và cơ đổ bóng. Bỏ khe 1,5 mm. Nẹp vàng thành dải 14 mm ở cạnh đứng. |
| Góc gỗ vuông, giả | Mép trên bàn cắt vuông 90° | Mép gỗ bo tròn bán kính 9 mm |
| Lag 30 hình/giây | Bóng đổ 8 mẫu cho mọi vật. Khi kéo ngắm, app hạ xuống 30 hình/giây. | Giữ 60/120 hình/giây khi đang chạm; bóng 4–6 mẫu; tự hạ chất lượng khi tụt hình |
| Cơ xuyên băng | Phần tính cơ tránh băng dùng băng giả định (cao 44 mm) thấp hơn băng vẽ trên màn hình (gỗ 56 mm) | Dùng đúng mặt cắt băng trên màn hình; thanh độ dốc tự nâng theo thời gian thực |
| Bi mục tiêu chạy trước khi bị chạm (video xem lại) | **Vật lý đúng**: test 192 cú nhảy, sai lệch lớn nhất 1,2 mm. Lỗi nằm ở phần xem lại: chỉ ghi 30 hình/giây, cú 6 m/s đi 20 cm giữa hai hình, nên khi chiếu chậm thì bi mục tiêu nhích trước. | Ghi 240 hình/giây khi bi chạy nhanh |

## Hạng mục

| # | Hạng mục | Đã làm | CI | Máy thật |
| --- | --- | --- | --- | --- |
| 1 | Hết lag | Như bảng trên | ảnh | [ ] |
| 2 | Hết sọc, nhấp nháy nỉ | Như bảng trên; CI đo độ dài bậc màu trên nỉ | ảnh + cổng | [ ] |
| 3 | Viền, yếm hết sọc; góc gỗ bo tròn | Như bảng trên | ảnh | [ ] |
| 4 | Bi bớt chói, thấy rõ số; bóng đậm và mịn | Màu bi ×0,68, lớp bóng mỏng và mềm hơn; bóng dưới bi chuyển mịn 12 nấc | — | [ ] |
| 5 | Cơ không xuyên băng, xuyên bi | Mặt cắt băng thật; quạt độ dốc hiện **↑38°** khi tự nâng (vùng đỏ là phần bị ép nâng); khi đánh, vật lý dùng đúng độ dốc đó: bi lệch hướng (squirt) và cong (swerve) tuỳ dốc và lực; trần cú thường nâng lên 45° | test C++ | [ ] |
| 6 | Bi mục tiêu không chạy trước | Test mới AirborneContact (192 cú); xem lại 240 hình/giây | test C++ | [ ] |
| 7 | Xem lại | Bắt đầu 1,5 s trước cú đánh, kết thúc 1,5 s sau khi bi dừng; 3 cảnh chuyển mượt 0,9 s: **toàn bàn → góc thấp theo đường bi cái tới điểm chạm → lỗ bi vào** (không có bi vào lỗ thì là góc ba phần tư theo bi) | UI test | [ ] |
| 8 | Logo | Biểu tượng "Zoker Pool" + "TRAINER" màu vàng; tên app **Zoker Pool** | — | [ ] |
| 9 | Khoá cơ | Mặc định chỉ **B** khoá. Tuỳ chỉnh → Điều khiển → "Chạm bi effect cũng khoá" (mặc định tắt). | UI test | [ ] |

## Tuỳ chỉnh (4 thẻ)

| Thẻ | Nội dung |
| --- | --- |
| Hình ảnh | **Mẫu ánh sáng**: Câu lạc bộ / TV sáng rõ / Dịu mắt · Độ chói bi · **Độ đậm bóng bi** · Độ sáng nỉ · Đèn bàn · Độ nổi kim cương · 60/120 Hz · Độ phân giải |
| Điều khiển | Sắp xếp phím · **Phím tự mờ khi ngắm** (bật) · Chạm bi effect cũng khoá (tắt) · **Dự đoán trước** (tắt) |
| Vật lý | Lực tối đa · **Mẫu loại bàn**: Nỉ mới nhanh / Tiêu chuẩn / Nỉ cũ ẩm chậm · thông số chi tiết có **vạch xanh vùng thực tế** và nhãn ✓ / ⚠︎ |
| Âm thanh | Âm lượng tiếng bi |

**Dự đoán trước** (luyện mắt): bật lên thì khi ngắm không có đường chỉ dẫn. Đánh xong, app vẽ đường bi mục tiêu cần đi tới lỗ và báo "lệch x,x°".

## Sảnh chính và menu

- Mở app thấy **Sảnh** gồm 3 thẻ màu:
  - **Luyện tập** (xanh nỉ): Tự do · Bài tập · Kick
  - **Thi đấu** (cam): Hai người một máy · Wi‑Fi · Online
  - **Hồ sơ** (xanh dương): Nhật ký · Cú đánh/Highlight · Tài khoản
- Dưới cùng: Hướng dẫn · Tuỳ chỉnh · ZUPE Lab.
- Menu trong trận còn 5 mục: **Tiếp tục** (vàng) · Đổi bàn/bi/gậy · Tuỳ chỉnh · Lưu và xem lại · **Về sảnh**.

## Chưa xác minh trên thiết bị

- Độ mượt thực tế, độ chói bi, độ mịn của bóng, sọc nỉ (ảnh CI chụp trên máy ảo không có GPU thật).
- Cảm giác cú đánh có cơ tự nâng: độ lệch và độ cong theo dốc.

## Thêm trong 0.38 (anh duyệt hết)

| # | Hạng mục | Ở đâu | Máy thật |
| --- | --- | --- | --- |
| 10 | **Nút số tự hiện** khi đường ngắm chạm băng (luyện tập) | Tuỳ chỉnh → Điều khiển (mặc định bật) | [ ] |
| 11 | **Chấm độ đều tay**: bấm Tập lại cùng một thế, app báo điểm dừng bi cái chụm ±x cm và chấm 1–5 sao (dưới 3 cm được 5 sao) | Tự hiện sau cú thứ 2 | [ ] |
| 12 | **Đường chỉ dẫn mờ dần** theo tỉ lệ đạt 20 cú bài tập gần nhất (đạt hết thì đường còn khoảng 35 % độ đậm) | Tuỳ chỉnh → Điều khiển | [ ] |
| 13 | **Góc ngắm mặc định**: độ cao, độ gần, FOV; sau mỗi cú camera quay về đúng góc này | Tuỳ chỉnh → Điều khiển | [ ] |
| 14 | **Kích thước và độ đậm của phím** | Tuỳ chỉnh → Điều khiển | [ ] |
| 15 | **Lưu 3 bố cục phím**: nút Lưu 1/2/3 và Dùng 1/2/3 | Tuỳ chỉnh → Điều khiển | [ ] |
| 16 | **Màu đường ngắm** (5 màu) và **độ dày** | Tuỳ chỉnh → Điều khiển | [ ] |
| 17 | **Độ rõ vân nỉ** (0 = mịn hoàn toàn) | Tuỳ chỉnh → Hình ảnh | [ ] |
| 18 | Đường dự đoán "Cả đường" tính theo **độ dốc cơ tự nâng** | Tự động | [ ] |
| 19 | Chất lượng hình **tự tăng lại** sau 20 s máy chạy đủ hình và không nóng | Tự động | [ ] |
| 20 | **Xuất video highlight**: 3 cảnh điện ảnh, 1280 px, 30 hình/giây; quay xong mở bảng chia sẻ (lưu vào Ảnh, gửi…) | Menu → Lưu và xem lại | [ ] |

## Hướng tách bán trong app (sau khi nghiệm thu)

Mỗi tính năng trên là một khối độc lập có công tắc riêng, nên sau này khoá hoặc mở theo gói In-App Purchase được mà không phải viết lại. Gợi ý chia gói để anh quyết sau:
- **Miễn phí**: luyện tự do, 2 người một máy, các bài tập cấp 1–2.
- **Gói Luyện mắt**: Dự đoán trước, Chấm độ đều tay, đường chỉ dẫn theo trình độ, bài tập cấp 3–5.
- **Gói Thi đấu**: Wi‑Fi, Online, Game Center.
- **Gói Studio**: xuất video highlight, mẫu ánh sáng, thư viện bàn/cơ/không gian.
