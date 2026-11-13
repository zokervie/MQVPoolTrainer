# 0.42 — nghiệm thu 0.41 (13/11/2026 17:45–18:19) + chuẩn hoá vật lý + AI máy

Nhánh: `cho/native-0.40c` → build `ci/native-0.42`. Toàn bộ **chưa xác minh trên thiết bị**.

| # | Mục anh nêu | Đã làm | Cách thử |
|---|---|---|---|
| 1 | 3 phòng mới + dựng lại 10 phòng, chữ "ZOKER POOL" nổi + logo | 10 phòng: Club, Trong nhà, Sân vườn, Cung điện, Hoàng gia, Thi đấu quốc tế, Club cổ điển, **Phòng VIP Zoker**, **Sân thượng đêm**, **Hầm đá**. Mỗi phòng có biển chữ ZOKER POOL khắc nổi mạ vàng + logo Z, đèn hắt | Tuỳ chỉnh → Hình ảnh → Không gian, xoay camera |
| 2 | 15 ảnh làm tranh treo | 4–6 ảnh/phòng (sân thượng/sân vườn trên tường điểm nhấn, sân đấu trên màn hình lớn), mỗi ảnh có đèn tranh | như trên |
| 3 | Bảng tỉ số kiểu truyền hình | Sau mỗi ván: thẻ tỉ số 3,5 s (trượt tên, quét sáng, số nảy, tia lửa, nhạc hiệu tự tổng hợp) rồi ván mới. Hết trận: thẻ người thắng + pháo giấy + 2 nút **Chơi tiếp / Về sảnh** | Đấu với máy race 2 |
| 4 | Máy chơi như pro | Theo nghiên cứu (PickPocket/CueCard): Monte Carlo 10→30→50 lần mô phỏng có nhiễu tay cho ứng viên tốt nhất; thế bi chấm theo 3 cú kế tiếp (1/0,33/0,15); Semi Pro dùng thêm effect ngang; cú phá thử 30 biến thể và giữ cú giữ lượt + bi cái về giữa | Đấu Pro / AI |
| 5 | Thông số cú của đối thủ | Thẻ 3,5 s ở nửa trái: lực trên thang 7 màu + quầng phổ, điểm chạm trên bi effect, loại cơ, độ dốc | Đấu Wi‑Fi / với máy |
| 6 | Camera lượt đối thủ gây chóng mặt | Mặc định "Truyền hình": toàn bàn từ cạnh dài, đứng yên. Tuỳ chọn Trên cao / Theo cơ | Tuỳ chỉnh → Máy·Âm thanh |
| 7 | Gọi lỗ | Cú đi thẳng vào lỗ vẫn tự tính (không cần gọi). Bấm Gọi: camera từ trên, 6 lỗ nhấp nháy quang phổ, chọn xong có dấu ✓ xanh tới hết cú | 8 Ball, bấm Call |
| 8 | Bi còn lại dưới tên (15 bi) | Dải bi nhỏ 10 pt dưới mỗi tên khi đã chia nhóm | 8 Ball sau khi có nhóm |
| 9 | Đặt bi cái | Camera tự chuyển từ trên; kéo ở BẤT KỲ đâu (bi giữ khoảng cách với ngón), hoặc chạm điểm muốn đặt | Lỗi bi cái → Đặt bi |
| 10 | Cơ chạm bi khi xem lại / đối thủ | Đầu cơ tiến tới chạm đúng điểm rồi đánh thẳng theo (follow-through) | Xem lại; Wi‑Fi |
| 11 | Nhạc | Tuỳ chỉnh → ♫ Nhạc của tôi: thêm bài từ app Tệp, phát/tạm dừng/bài tiếp/âm lượng. Nhạc **chỉ giảm đúng dải tần** của tiếng bi (bi/cơ ~2–6 kHz, rơi lỗ ~260 Hz). Nghe cùng **chỉ khi chơi cùng Wi‑Fi** (chủ phòng phát sang máy khách); online không chia sẻ | Wi‑Fi 2 máy |
| 12 | 7 ngôn ngữ, mặc định tiếng Anh | Tuỳ chỉnh → Ngôn ngữ: EN, VI, FIL, ES, ZH, JA, HI. Bản này dịch các màn chính (sảnh, phím, menu, trận, phòng); câu dài/trợ giúp còn tiếng Việt → bản sau dịch đủ ~830 câu. Bản dịch cần người bản xứ duyệt | Đổi ngôn ngữ, mở lại màn |
| + | Mất tiếng khi chuyển app | Quay lại app = khởi động lại âm thanh hoàn toàn (iOS không luôn báo "hết gián đoạn") | Chuyển app 3 lần, đánh bi |
| + | Thanh trạng thái che bi effect | Thành dải 1 dòng mỏng ở giữa đáy màn hình | |
| + | Bi effect / độ dốc phóng to | Chạm bi effect → bản lớn ở giữa nửa trái; chỉnh độ dốc → bản lớn ở giữa nửa phải (tắt được) | |
| + | Thang lực che vùng thao tác | Dời lên khoảng trống bên phải bảng điểm | |
| + | Người 2 không ra cơ được (B tắt) | Gốc: luật đang chờ người 2 **chọn** (nhận bàn/trả lượt sau cú phá yếu, push-out…) nhưng hộp chọn chỉ mở khi chạm dòng trạng thái. Nay hộp chọn tự mở | 9 Ball phá nhẹ |
| + | Cảnh báo 2 lỗi chặn cú đánh | Không còn hộp chặn: nhắc 1 lần khi tới lượt. Đồng hồ cú dừng khi có hộp thoại hoặc B đang tắt (trước đó có thể chạy hết giờ → bị lỗi oan) | |

## Vật lý (chuẩn hoá theo tài liệu — `Docs/NghienCuu/CHUAN-VAT-LY-0.42.md`)
- Throw bi–bi của lõi khớp phương trình TP A-14 đến 0,1° (stun 30°: 4,86° / 3,55° / 1,70° ở 0,45 / 1,34 / 3,13 m/s).
- Giảm xoáy ngang 15 → **11 rad/s²** (pooltool/Colorado). Ma sát bi–bi của app giữ 0,05 vì đo từ clip thật (ưu tiên số đo).
- Mô hình băng Mathavan 2010: số tham chiếu trong tài liệu chưa kiểm được với bài gốc → chưa thay; cần video để chốt.
