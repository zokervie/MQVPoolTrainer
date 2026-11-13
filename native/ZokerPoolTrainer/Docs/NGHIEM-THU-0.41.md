# 0.41 = 0.40c + 10 mục anh gửi 13/11/2026 00:34 (một lần build)

Nhánh: `cho/native-0.40c` → build `ci/native-0.41`. Toàn bộ mục dưới đây **chưa xác minh trên thiết bị**.

## Cách thử theo từng mục của anh
| # | Mục | Nguyên nhân gốc / thiết kế | Cách thử |
|---|---|---|---|
| 1 | Cú phá đầu không đánh được (Wi‑Fi/online) | Cú vuốt đầu tiên của ván chỉ dùng để tắt hoạt cảnh xếp bi, rồi bị bỏ đi | Vào trận Wi‑Fi, vuốt phá ngay: bi phải chạy |
| 1 | Đến lượt mà nút B ẩn, không đánh được | Chủ phòng gửi trạng thái cuối cú khi camera còn đang lắng (máy kia hiểu là bi còn chạy). Lúc camera lắng xong thì không gửi lại, nên máy kia chờ mãi | Đánh qua lại 10 lượt giữa 2 máy: lượt nào cũng có B |
| 2 | Đấu Wi‑Fi/với máy không mượt bằng lúc tập | Chủ phòng dựng toàn bộ trạng thái trận (JSON, 128 sự kiện) ở MỌI khung hình rồi bỏ gần hết. Giờ chỉ dựng khi gửi. Wi‑Fi/Game Center gửi 20 lần/giây (trước là 10) nên bi trên máy khách mượt hơn | So độ mượt cùng một cú khi tập và khi đấu |
| 2 | Gậy Break mặc định bị dốc | Độ nâng cơ bị ép qua băng ở cú trước bị lưu vào gậy Break | Chọn Break: cơ phải nằm ngang |
| 3 | Không thấy cơ của đối thủ | Thêm gói "tư thế cơ" (~15 lần/giây, chỉ để hiển thị, không ảnh hưởng ván): góc, điểm chạm, độ nâng, kéo cơ, loại gậy. Máy kia làm mượt rồi vẽ | Một máy ngắm và kéo cơ thử, máy kia thấy cơ xoay và thục theo |
| 4 | Thang lực 7 màu | Thang tím (nhẹ) → chàm → lam → lục → vàng → cam → đỏ (mạnh), màu chuyển mượt. Có vạch và số m/s theo thời gian thực. Vệt vuốt mờ sương nhuộm theo tốc độ. Hết cú hiện quầng phổ màu và số lực ở điểm cuối vuốt rồi tắt | Giữ B rồi vuốt. Tắt/mở trong Tuỳ chỉnh → Ngắm |
| 5 | Đối thủ tắt màn hình/chuyển app | (a) Màn hình không tự khoá khi đang đấu. (b) Kéo Trung tâm điều khiển hay có cuộc gọi đến không còn làm rớt phòng. (c) Rời app dưới 25 s vẫn giữ phòng. (d) Chủ phòng vẫn đánh lượt của mình khi khách vắng. Khách vắng quá 30 s ở lượt của khách thì bị lỗi (chủ có bi trong tay). (e) Vắng tổng cộng quá 1 phút 30 s thì thua trận. Khách mà chủ phòng vắng thì chờ, quá 1 phút 30 s được xử thắng | Tắt màn hình máy khách 1 phút ở lượt chủ, rồi ở lượt khách |
| 6 | Menu khung gỗ, tông trầm | Menu trong trận và Tuỳ chỉnh nằm trong khung gỗ 10 pt. Mỗi thẻ có tông riêng: rừng thông, xanh đêm, nâu, tím than, đỏ rượu, xám đá | Mở Menu và Tuỳ chỉnh, chuyển qua các thẻ |
| 7 | Đầu tẩy Break/Jump | Break: trắng sữa trong. Jump: đen bóng. Đầu cứng, bo phẳng hơn, không còn màu xanh lơ | Chọn từng gậy, zoom vào đầu tẩy |
| 8 | Xem lại | Bắt đầu 1 s trước khi chạm bi, kết thúc 1 s sau khi bi dừng. Thêm 5 góc: Action bám bi cái, Action bám bi mục tiêu, Đón bi ở lỗ, Cẩu quay quanh bàn, **Action Mix** (tự cắt cảnh theo va chạm và cú vào lỗ). Góc chọn được nhớ lại | Xem lại → nút góc máy → thử từng góc |
| 9 | Không gian | Dựng lại CLB mặc định: thảm hoa văn, ốp gỗ óc chó cao ngang hông với nẹp đồng, tường vải, tranh sơ đồ bida có đèn rọi, giá cơ 8 cây, bàn tính điểm hạt, quầy bar có kệ sáng, ghế quầy, 2 bàn bên có đèn riêng, đèn âm trần, sương xa. Các vật trang trí được gộp thành một khối nên không nặng thêm | Tuỳ chỉnh → Hình ảnh → Không gian → Club, quay camera nhìn quanh |
| 10 | Gói âm thanh | Giữ bộ 0.17 theo ý anh; khung 3 mức lực + tiếng phá sẵn sàng cho tiếng anh tự thu | Không cần thử |

## Gói âm thanh (mục 10)
Anh chốt 13/11 08:22: tạm giữ bộ 0.17, bản sau dùng tiếng anh tự thu (`HUONG-DAN-THU-AM.md`). Khung chọn bộ âm thanh theo mức lực đã có sẵn trong code, chỉ cần thêm file.

## Giả định cần anh duyệt
- Luật vắng mặt: anh đã chốt 30 s/lượt, 1 phút 30 s thua (13/11 07:21).
- Thời gian giữ phòng khi rời app: 25 s (giới hạn iOS cho app chạy nền khoảng 30 s).
