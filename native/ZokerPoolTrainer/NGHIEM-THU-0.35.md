# Nghiệm thu Z-Trainer 0.35 — theo "EXPOSE IQ200" (10 điểm) + hệ bài tập mới

Nhánh `ci/native-0.35` · build (điền sau CI) · App hiện phiên bản **0.35**.
Cột **CI** = đã kiểm tra tự động. Cột **Máy thật** = anh tick khi thử; ghi chú ngắn nếu chưa đạt.

## 10 điểm IQ200

| # | Hạng mục | Đã làm | CI | Máy thật |
| --- | --- | --- | --- | --- |
| 1a | Bớt chói | Phơi sáng −1,45 (trước −1,1), phản chiếu môi trường 0,5 (trước 0,72); bi bớt bóng lacquer; nỉ Z-Max xám đậm hơn (#6E767D); cảnh Cung điện / Ngoài trời / Thi đấu giảm đèn 2–3 lần, tường và sàn đá tối hơn | ảnh CI | [ ] |
| 1b | Bóng bi đậm hơn | Bóng tiếp xúc dưới bi đậm hơn (0,88), bóng đèn chính đậm hơn (0,55) | ảnh CI | [ ] |
| 1c | Xoáy khi xem lại slow-motion đúng chiều lăn | Trước: nội suy góc quay theo đường ngắn nhất giữa 2 mẫu 1/30 s. Bi lăn nhanh quay > 180° mỗi mẫu nên trông như quay ngược. Nay tích phân vận tốc góc thật (cùng công thức với lõi vật lý), massé cũng xoay theo xoáy thật | — | [ ] |
| 2 | Mượt, bớt nóng | Bỏ 120 Hz (gấp đôi tải GPU, không hết giật). Cố định 60 Hz khi bi chạy, 15 Hz khi đứng yên. Bỏ lớp SSAO toàn màn hình. Bóng đổ 4 mẫu (trước 8) | — | [ ] |
| 3a | Sọc bẩn cạnh bàn khi xoay | Nguyên nhân: lớp sợi nỉ chiếu theo mặt bàn, lên mặt băng đứng bị kéo thành sọc. Nay chiếu theo hướng bề mặt (mặt đứng dùng mặt phẳng đứng) | — | [ ] |
| 3b | Bàn đa dạng kiểu dáng | Thêm 3 bàn **bar-box** (thân liền tới sàn, cửa bỏ xu, đế), các bàn gỗ cổ điển có **váy bàn, gờ chỉ và trụ góc**. Ngoài ra vẫn có 6 kiểu chân (4 chân, trụ đôi, chữ X, chữ V, chân côn). Tổng 24 bàn | ✅ 24 bàn | [ ] |
| 4 | Hết bi tự về góc ngắm, không cần chạm | Khi bi dừng, nếu đang ở góc khác thì tự về Góc ngắm (cả luyện tập, trước đây chỉ ở trận đấu) | UI test | [ ] |
| 5 | Cơ không xuyên bi, không xuyên bàn | Độ dốc cơ = độ dốc đã chọn (trước: cơ nghiêng theo đường tay sau → điểm đánh cao làm đuôi cơ chúi vào băng/bàn). Đánh thấp với cơ ngang: tự nâng đủ để đuôi 14,7 mm không chạm nỉ. Đầu tẩy dẹt lùi ra r·tanθ khi đánh lệch tâm nên mép đầu tẩy không lún vào bi | kiểm tra tiếp điểm (Simulator) | [ ] |
| 6 | Bài tập mới hoàn toàn | Xem phần dưới | UI/ảnh | [ ] |
| 7 | Nút số, Chỉ dẫn, Bảng chỉ hiện khi bật Coach | 3 phím nhỏ cạnh Coach. **Chỉ dẫn** bấm vòng: Điểm ngắm (đường bi cái tới lần chạm đầu + hướng đầu bi đích) → Cả đường → tắt. **Bảng** ẩn/hiện bảng chỉ dẫn | UI test | [ ] |
| 8 | Cơ đổi màu/dáng theo loại gậy | Trước: mọi gậy dùng chung một bộ vân gỗ/carbon nên trông giống nhau. Nay thân và đuôi nhuộm màu riêng từng gậy, khoen theo màu nhấn; **Jump ngắn 1,04 m**; **Massé màu đỏ rượu riêng** | — | [ ] |
| 9 | Khoá nửa trên bi effect khi chọn Jump | Nửa trên bị che tối và không chọn được (ghi "JUMP · KHOÁ NỬA TRÊN" khi phóng to). Chuyển gậy khác thì mở lại | — | [ ] |
| 10 | Vân nỉ | Sợi thô hơn khoảng 3 lần (sợi 0,6–2,6 mm, dày 0,2–0,5 mm), hiện ở khoảng cách xa hơn, tương phản gấp đôi rưỡi. Kết hợp với giảm chói nên phải thấy được khi zoom gần | — | [ ] |

## Hệ bài tập mới (điểm 6)

Đã xoá toàn bộ bài cũ, cả "Bài học / Nguồn tham khảo". Menu → **Bài tập · 5 cấp · chấm điểm 5 sao**.

| Cấp | Nội dung | Số bài |
| --- | --- | --- |
| 1 · Nền tảng | Stop, cu-lê, trô vào vùng; cắt 30° phải, 45° trái (bi ma); lực 3 cự ly | 8 |
| 2 · Nút số: kick 1 băng | Hệ gương / trung điểm. Có bài không bi cản, bi cản gần, bi cản xa. Bật Coach: app tính sẵn số nút gương | 4 |
| 3 · Nút số: kick 2–3 băng | Gương kép, **Corner-5** (số bi cái − số đích = số ngắm), có bi cản | 5 |
| 4 · Bank và hệ Plus | Bank 1 / 2 / 3 băng, kick 2 băng hệ Plus (vị trí + đích = ngắm), kick 4 băng | 5 |
| 5 · Trick shot | Combo dính, jump qua bi cản, massé vòng bi cản, kick 3 băng thoát cụm | 4 |

- **Một lượt = 5 cú.** Sau mỗi cú, app tự xếp lại thế bi sau 2 giây.
- **Qua bài khi đạt ≥ 3/5.** Sao = số cú đạt; 5 sao cần thêm điểm trung bình ≥ 85. Danh sách hiện sao cao nhất của từng bài và số bài đã qua.
- **Điểm mỗi cú (0–100), app tự chấm trên máy:**
  - Cú đạt = 100. Bài vùng dừng bị trừ theo khoảng cách tới tâm vòng.
  - Cú trượt có điểm gần đúng: bi cái trượt bi 1 bao nhiêu cm, bi 1 lướt cách lỗ bao xa, sai số băng.
  - Bi cái vào lỗ = 0.
- **Coach (nếu bật):** sau mỗi cú báo điểm va băng và một thay đổi nên làm cho cú sau. Cái này tính bằng vật lý của app, không gọi AI trả phí.
- **Hết lượt:** bảng kết quả với 3 lựa chọn "Tập lại lượt mới" / "Bài tiếp theo" / "Đóng".

## Chưa làm / cần anh xác nhận

- Video hướng dẫn kèm từng bài. Bản quyền thuộc tác giả YouTube nên app chỉ được mở link, không nhúng video.
- Mô hình 3D dựng lại hoàn toàn phần mặt băng/bo góc theo từng thương hiệu. Hiện mới khác ở thân, chân và váy bàn, vì phần mặt băng dùng chung một lưới chuẩn WPA.
- **Chưa xác minh trên thiết bị:** độ mượt, nhiệt độ máy, độ chói và vân nỉ (cần anh xem trên máy).
