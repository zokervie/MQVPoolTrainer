# Tham khảo: ShootersPool (thu thập 19/10/2026)

Tài liệu tham khảo **ý tưởng**, không phải nguồn mã. ShootersPool là phần mềm độc quyền của Eveho Ingeniería SL (Windows, mua một lần + Free2Play). Không có mã nguồn công khai → **không sao chép mã, hình, âm thanh, tên bàn/bài tập** của họ. Mọi thứ dưới đây phải viết lại theo kiến trúc và quy tắc của dự án (CLAUDE.md, UPGRADE.md), mỗi tham số vật lý vẫn cần `Provenance`.

Thông tin công khai rất ít số liệu kỹ thuật: trang chủ, FAQ, trang huấn luyện, trang thương hiệu không công bố tham số nỉ/băng/lỗ. Nguồn chi tiết nhất là thông báo cập nhật trên Steam.

## 1. Họ có gì

### Vật lý (theo thông báo cập nhật 2019, 2021)
- Hệ số phục hồi bi–bi **thay đổi theo góc va chạm**.
- Cải thiện vật lý cụm bi (bi cái đâm vào cụm nhiều bi); sửa "va chạm ma" hiếm gặp.
- Giảm độ bật của bi cái khi có xoáy trên.
- **Khuyết tật nỉ**: lệch bi nhiều hơn và sớm hơn ở tốc độ thấp → cú lăn chậm đường dài khó hơn; mỗi loại nỉ có thuộc tính **"độ chính xác lăn"**.
- **Băng biến dạng / đàn hồi** (thử nghiệm 2019, đưa vào online dạng alpha 2021).
- Cú phá 9 bi tán bi thật hơn; xếp bi bằng **template** (tấm xếp mỏng) cho kỹ thuật phá khác.
- Cơ bị băng chặn → tự nâng cơ; xoáy trên tối đa luôn dưới giới hạn miscue; "chalk kick" (tạm tắt).
- Thiết bị mô phỏng theo hãng: bàn Diamond Pro-Am 7/9/10 ft, Rasson, Gabriels, JOY; nỉ Simonis/Strachan (nhiều loại); bi Aramith; cơ Predator, OB, Poison…

### Điều khiển
- Ngắm bằng chuột ngang; **ra cơ bằng kéo lùi – đẩy tới khi giữ phím** (cùng ý tưởng Natural Stroke của ta). Đánh giá chung: chân thật nhưng khó làm quen.
- Chỉnh được **độ nghiêng cơ ban đầu** và **khoảng cách mắt – bi cái ban đầu**.
- Lưu thế bi đang chơi (Ctrl+Z) và đặt lại thế bằng nhấn đúp.
- Chọn lỗ thủ công từ góc nhìn trên; đặt bi tự do chính xác.

### Luyện tập
- Chế độ luyện offline: đặt thế bi bất kỳ, mô phỏng, **phát lại chậm** (ví dụ tái hiện cú của một tay cơ chuyên nghiệp ở giải đấu).
- **Đường theo dõi vật lý**: vẽ đường bi cái theo lực, xoáy và điều kiện bàn/nỉ/bi, theo thời gian thực.
- Bài tập có sẵn theo môn + tự tạo; **menu bài tập hiện mô tả, điểm cao nhất, số lần hoàn thành**.
- Video hướng dẫn của huấn luyện viên đối tác gắn trong phần luyện tập.

### Khác (ngoài phạm vi D1)
Online, xếp hạng ELO, giải đấu, đội, cửa hàng vật phẩm, 12 môn (pool, snooker, carom).

## 2. Đối chiếu với dự án

| Ý tưởng | Trạng thái ở ta | Hướng xử lý | Ràng buộc |
|---|---|---|---|
| e bi–bi theo góc/tốc độ | e hằng | Ứng viên R3 nâng cao. Chỉ thêm khi có nguồn công bố hoặc số đo R4 | Provenance; không đổi trước Cổng 1 |
| Vật lý cụm bi | Đã sửa tách chồng lấn (R1.7 đạt); M7 cú phá nhạy thứ tự | Giữ hướng "giải đồng thời theo nhóm" trong Vấn đề mở | M2–M6 phải vẫn đạt |
| Khuyết tật nỉ / "độ chính xác lăn" | Không có | Nếu làm: lệch **xác định** theo seed của bàn (không ngẫu nhiên lúc chạy), mặc định tắt | CLAUDE.md ưu tiên 2: không ngẫu nhiên |
| Băng biến dạng | Băng Han 2005 (đã khớp pooltool từng va chạm) | Han hay Stronge chỉ chọn bằng số đo R4 | UPGRADE 2.6 |
| Xếp bi bằng template | Tam giác khe 1 µm / 0,2 mm | Thêm khe "template" vào bộ R1.7 khi làm cú phá | — |
| Cơ bị băng chặn → nâng cơ | Có giới hạn miscue | Ứng viên R2/Shot Lab: tính độ nghiêng tối thiểu từ hình học băng/bi | — |
| Độ nghiêng cơ, khoảng cách mắt chỉnh được | Camera thứ nhất cố định FOV | Thêm vào cài đặt camera (R2.2) | Chỉ hiển thị, không đổi vật lý |
| Lưu / đặt lại thế bi | "Làm lại" + bài JSON | Thêm nút lưu thế hiện tại thành bài JSON | Dùng PoolDrills có sẵn |
| Phát lại chậm, tái hiện cú | Có replay + `TouchRecording` | Đủ; thêm camera tự do khi phát lại | — |
| Đường theo dõi vật lý | **Cố ý không có** khi đánh | Chỉ trong Shot Lab (phân tích), không bao giờ ở Natural Stroke | CLAUDE.md ưu tiên 3 |
| Menu bài: điểm cao nhất, số lần | Có thống kê theo bài | Hiển thị ở danh sách bài (R5) | R5 chỉ tính sau Cổng 1 |
| Thiết bị theo hãng | Hồ sơ bàn chỉnh tay (giả định) | Giữ; tham số hãng chỉ nhập khi có nguồn | Provenance |
| Online, ELO, cửa hàng | Không | Không làm | D1 định vị |

## 3. Đề xuất đưa vào PROGRESS (theo thứ tự lộ trình, không vượt cổng)
1. **R2.2** — cài đặt độ nghiêng cơ ban đầu và khoảng cách camera (chỉ hiển thị).
2. **R2 / Shot Lab** — lưu thế bi hiện tại thành bài JSON; đặt lại thế.
3. **R1.7 mở rộng** — thêm kiểu xếp "template" vào bộ 10.000 cú.
4. **Sau R4 (Cổng 1)** — xét e theo góc/tốc độ và khuyết tật nỉ xác định, chỉ khi số đo bàn thật cho thấy cần.
5. **R5 (sau Cổng 1)** — danh sách bài hiện điểm cao nhất và số lần hoàn thành.

## Nguồn
- Trang chủ: https://www.shooterspool.net/
- Luyện tập: https://www.shooterspool.net/training-billiards-tool.php
- FAQ: https://www.shooterspool.net/faq-frequenly-asked-questions.php
- Thương hiệu: https://www.shooterspool.net/billiard-brands-in-shooterspool.php
- Thông báo cập nhật (Steam, 06/08/2019 và 19/10/2021): https://steamcommunity.com/groups/shooterspool/announcements
- ModDB: https://www.moddb.com/games/shooterspool-billiards-simulation
- Mô tả điều khiển: https://shooterspool-billiards-simulation.en.download.it/
- Giấy phép độc quyền: https://alternativeto.net/software/shooterspool
- Hiệu ứng nỉ (Dr. Dave, không có số liệu định lượng): https://drdavepoolinfo.com/faq/table/cloth-effects/
