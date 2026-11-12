# Kế hoạch tổng hợp sau nghiệm thu 12/11/2026 (0.40b → 0.41)

Nguồn yêu cầu: 8 mục anh gửi 18:17 ngày 12/11, file TXT (phần A–E), và các mục đã chốt ở 0.38–0.40 nhưng chưa làm.

Quy ước trạng thái:
- **0.40b** = đã có trong bản đang build (`ci/native-0.40b`).
- **0.41** = bản kế tiếp.
- **0.42+** = cần anh cung cấp gì đó, hoặc cần hạ tầng mới.

Mục nào cũng phải có ở CI: test C++ (vật lý, luật, máy), test cử chỉ, hoặc ảnh "phòng chuẩn".

## 1. Bảy mục lỗi và hình ảnh anh nêu ngày 12/11

| # | Việc | Nguyên nhân gốc tìm được | Cách sửa | Bản |
|---|---|---|---|---|
| 4 | Đến lượt máy nhưng máy đứng chờ | Máy tính thử mọi cặp bi–lỗ. Mỗi cặp mô phỏng khoảng 150 cú, mỗi cú kéo dài 25 s; bàn 8 bi đủ 15 bi mất hàng phút | Giới hạn 2 s cho mỗi lượt tính. Chỉ xét 4–6 cặp dễ nhất. Dò góc thô rồi chia đôi tìm mép (15 cú thay vì 25). Mỗi cú mô phỏng 12 s. Nâng cơ khi bi chủ sát băng hoặc sát bi. Nếu máy tính quá 10 s thì tự bỏ lượt tính. Thêm test "bàn đầy: tính xong trong ngân sách" và test UI "máy tự phá rồi tiếp tục đánh" | 0.40b |
| 3 | Gậy vẫn che tầm ngắm | Ở góc ngắm thấp, đuôi gậy nằm sau camera. Phép chiếu ra số sai nên điều kiện làm mờ gậy không bao giờ bật | Chỉ xét đoạn gậy nằm trước camera. Đặt độ rõ mặc định 42%, đủ thấy bi đích. Thêm thanh "Độ rõ của gậy khi mờ" (20–80%) trong Tuỳ chỉnh → Ngắm | 0.40b |
| 6a | Bóng bi in xuống sàn nhà | Bàn không đổ bóng (để tránh sọc), nên bóng bi xuyên qua mặt đá xuống sàn | Đặt một tấm chắn vô hình ngay dưới mặt nỉ, chỉ dùng để chặn bóng. Sàn nhận bóng của bàn, mặt nỉ không tự đổ bóng lên mình | 0.40b |
| 6b | Bi rơi lỗ nằm hết dưới đáy | Lòng lỗ sâu 25 cm và tầng nào cũng xếp 7 bi | Lòng lỗ sâu 12 cm (số đo bàn CLB phổ biến, sai số ±2 cm) và có đáy. Bi xếp theo thứ tự rơi: đáy 3 bi, tầng hai 3 bi nằm vào khe tầng dưới, bi thứ 7 trở đi hiện ở miệng lỗ | 0.40b |
| 5 | Đèn báo lượt; bảng tên mảnh hơn; 10 mẫu bảng | — | Bảng cao 30 pt (cũ 44) và không rộng quá 62% màn hình. Đèn lượt sáng và nhịp thở trên bảng tên người đang đánh, dùng được cả khi 2 người chơi chung một máy. 10 mẫu (TV đêm, VS xanh–đỏ, Bạc cổ điển, Tối giản, Neon, Gỗ CLB, Nỉ xanh, Carbon, Hoàng gia, Trắng sáng) chọn bằng ô xem trước trong Tuỳ chỉnh → Hình ảnh → Bảng điểm. Có cờ để sau này bán trong gói Z-Style | 0.40b |
| 2 | Vân nỉ rõ sợi như nỉ 300; ô màu | — | Sợi nổi hơn, khe giữa sợi tối hơn. Nỉ mới rõ sợi; nỉ cũ có lớp xơ phủ lên. Thêm 4 màu theo bảng mẫu (xanh lá, xanh dương, đỏ, đen) và chọn bằng ô vải trong Tuỳ chỉnh → Hình ảnh → Bàn. Tên dùng "Z-Weave 300", không dùng tên thương hiệu. **Phản biện:** độ rõ sợi khi zoom gần còn bị giới hạn ở mức 3 px/sợi để không bị vân sóng (moiré) khi nhìn xa; muốn đạt đúng như ảnh chụp macro thì 0.41 cần thêm tầng ảnh sợi chi tiết | 0.40b + 0.41 |
| 8 | Bóng bi/cơ mềm nhưng rõ, không lem/đứt; thành băng thật hơn | Bóng cơ là 64 mảnh rời, mép không khớp nhau | Bóng cơ thành một dải liền, càng nâng cơ càng rộng và mờ. Bóng bi bớt nhòe (bán kính mềm 4 → 3). Thêm dải bóng chân băng (cao su chìa ra) rộng 1,9 cm. **0.41:** làm lại hình dáng băng (mũi cao su, khe nỉ, mép gỗ) theo ảnh tham chiếu | 0.40b + 0.41 |
| 7 | Chơi tính giờ + Gia hạn | — | Có 4 mẫu: Tắt / Quốc tế 30 s + 1 lần gia hạn 30 s / Luyện thi đấu 45 s + 2 lần / Nhanh 20 s + 1 lần 15 s. Lượt gia hạn tính theo người, mỗi ván. Rung ở 10 s và 5 s. Hết giờ là phạm lỗi, đối thủ có bi trong tay (test luật C++). Chọn mẫu trong Tuỳ chỉnh → Vật lý. **Giả định cần anh duyệt:** cú phá không tính giờ; đồng hồ dừng khi đang chờ chọn push-out | 0.40b |

Mục 1 ("cảm giác chân thật, hưng phấn") là các việc đã chốt từ trước nhưng chưa làm, xem phần 3.

## 2. File TXT (A–E)

### A. Ba đề xuất đã duyệt
- **Bàn nhà tôi (gói Z-Lab) — 0.41.** Màn đo 3 bước: đánh dọc bàn bấm giờ, đếm số lần chạm băng, đặt tên. Từ số đo suy ra hệ số lăn và độ nảy băng, kẹp trong khoảng an toàn. Viết test C++ trước cho phần đổi số đo ra hệ số. Lưu 3 hồ sơ bàn.
- **Cú quyết định — luyện dưới áp lực (Z-Drill) — 0.41.** Dùng lại đồng hồ cú của 0.40b, thêm vòng đếm quanh bi chủ và luật "phải vào mới qua bài". Tiếng khán giả cần mẫu CC0 hoặc anh tự thu.
- **Widget + Live Activity — 0.42.** **Phản biện:** phần này cần một target "app extension" mới, App Group và ký bằng tài khoản Apple trả phí. Bản IPA hiện tại không ký, nên không thử được trên máy nếu anh cài bằng chứng chỉ miễn phí. Em đề nghị làm khi anh đã có tài khoản Developer.

### B. Intro — 0.41
- Dựng bằng SceneKit và lõi vật lý, dài tối đa 2,5 s, chạm để bỏ qua; từ lần mở thứ 2 chỉ còn 0,8 s.
- Launch Screen trùng khung đầu của intro để không bị chớp.
- Trong lúc intro chạy thì biên dịch sẵn shader và nạp âm thanh.
- Khi bật "Giảm chuyển động" của iOS thì chỉ làm mờ dần logo.
- CI đo thời gian từ mở app đến lúc dùng được Sảnh, mục tiêu ≤ 1,5 s.

### C. Logo và nhận diện — 0.41
- Biểu tượng Z vẽ bằng vector: nét Z là đường bi chạm băng rồi bật ra, dấu chấm cuối là bi chủ. Có 3 dạng: đứng riêng, kèm chữ nằm ngang, một màu.
- Icon iOS 26 đủ 3 bản Sáng / Tối / Tint.
- Logo trên yếm bàn đổi sang chữ Z dập chìm.
- 5 màu thương hiệu thành token dùng chung.
- **Phản biện:** em dựng được bản vector chuẩn, nhưng việc kiểm tra trùng thương hiệu trước khi lên App Store phải do anh (hoặc luật sư) tra cứu USPTO/WIPO; em chỉ chuẩn bị danh sách cần tra.

### D. Giao diện — 0.41
- Hệ thiết kế chung: thang chữ 5 cỡ, lưới 8 pt, bo góc 3 mức, phím tối thiểu 44 pt, Dynamic Type đến XL.
- Sảnh có thẻ "Tiếp tục" ở trên cùng.
- Trong trận: phím gom về một cạnh theo tay thuận.
- Chuyển cảnh 0,3 s, cùng một kiểu ở mọi nơi.
- Một bộ quản lý rung chung.
- Chuẩn WCAG AA; VoiceOver đọc đúng tên các nút chính.
- iPad: Sảnh 2 cột.
- CI chụp ảnh ở 3 cỡ máy để so trước/sau.

### E. Âm thanh — 0.41 (phần tự tổng hợp được) / 0.42 (phần cần mẫu thật)
- **Em tự làm được (0.41):** tiếng giao diện tự tổng hợp, ngắn dưới 120 ms (CC0 vì do em tạo). Trộn âm 3 nhóm, mỗi nhóm có thanh chỉnh riêng. Đỉnh ≤ −1 dBTP. Tắt khi máy ở chế độ im lặng; nhường tiếng khi có cuộc gọi.
- **Cần anh (0.42):** mẫu thật cho cơ/băng 3 mức × 3 biến thể, 2 loại lỗ, tiếng lăn. Môi trường của em không tải được file âm thanh từ mạng, nên anh tải gói CC0 rồi gửi em, hoặc thu theo kịch bản em soạn. Nhạc nền cũng vậy, cần nguồn có giấy phép thương mại.

## 3. Các việc đã chốt từ trước mà chưa làm (mục 1 "chân thật, hưng phấn")
- **0.41:**
  - Bi văng khỏi bàn, đập mép gỗ, nảy trên sàn (test C++ trước).
  - Bàn kích thước WPA và các họ kiểu dáng Z-.
  - Mẫu đèn "Thi đấu" 520 lux.
  - Hướng dẫn 3 bước lần đầu.
  - Bài tập mỗi ngày + chuỗi ngày.
  - "Giữ mắt", "Vì sao trượt", Z-Exam v1.
  - Khung IAP (cờ tính năng + StoreKit 2).
  - Menu trong trận còn 4 mục.
  - Máy chủ trận (host) bỏ việc dựng snapshot mỗi tick khi chưa cần gửi.
- **0.41 (cảm giác):** rung đúng nhịp va chạm; camera hơi rung khi phá bi mạnh; xem lại tự động các cú "đẹp" (vào bi ăn 3 băng, thoát kick).
- **Chờ anh:** quay 5 cú 240 fps ở CLB, thu âm, gộp PR #4, bật Game Center.

## 4. Không lặp lỗi cũ
1. Mỗi lỗi có test giữ cửa: máy tự đánh (test UI), bàn đầy tính trong ngân sách (C++), hết giờ là phạm lỗi (C++), cú nhảy/kéo/camera chờ cử chỉ ổn định (UI).
2. Phần chống giật vẫn giữ nguyên: không đổi bố cục khi bi chạy, bộ đồng bộ khung giữ quyền vị trí bi.
3. Ảnh "phòng chuẩn" so trước/sau cho các mục hình ảnh (nỉ, bóng, lỗ, bảng điểm).
4. Chỉ gọi là "xong" khi anh xác nhận trên máy thật.

## 5. Hạng mục hay phải sửa → đưa vào Tuỳ chỉnh (theo dặn 09/11)
Mỗi hạng mục dưới đây đã có điều khiển riêng trong Tuỳ chỉnh:
- Độ rõ của gậy khi mờ.
- Màu nỉ (ô vải) và tình trạng nỉ mới/cũ.
- Kiểu bảng điểm.
- Đồng hồ cú.
