# Nghiệm thu Z-Trainer 0.30

Nhánh `ci/native-0.30`. App giờ hiện đúng **phiên bản 0.30** (trước đây vẫn ghi nhầm 0.19).
Cột **CI** = đã kiểm tra tự động (test C++ trên Linux / Simulator trên Mac). Cột **Máy thật** = anh tick khi thử. Ghi chú ngắn vào cuối dòng nếu chưa đạt.

## Vật lý

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 1 | Effect max, lực vừa, vào băng dài 90° → bật ra ~45° (số đo bàn thật của anh). Trước: ~24° | ✅ 45,3° ở 2 m/s; 44° ở 3 m/s | [ ] |
| 2 | Không effect → bật thẳng về; trái/phải đối xứng | ✅ | [ ] |
| 3 | Effect ngược "ăn" vào bi đích (bánh răng): bi đích xoáy ngược chiều, chạm băng giật ngược lại | ✅ R·ω/v 0,13–0,14 (trước 0,03) | [ ] |
| 4 | Effect thuận: bi đích không giật ngược, góc băng mở rộng | ✅ | [ ] |
| 5 | Kick hệ gương: effect ngược giờ thu góc rõ (−0,7 → −0,9 nút), thuận mở góc (+0,5 → +0,7 nút) | ✅ | [ ] |
| 6 | Zigzag ngược như clip vẫn đúng (4 băng, lệch ≤ 0,3 nút) | ✅ | [ ] |
| 7 | Xoáy ngang tắt nhanh hơn (18 rad/s², trước 11) | ✅ | [ ] |
| 8 | Massé mạnh hơn 20% ở lực tối đa; gậy Đánh không đổi | ✅ ×1,20 | [ ] |
| 9 | Corner‑5 (A = D − T) vẫn trong sai số bàn thường | ✅ lệch 0,3 nút, phân tán ¼ nút | [ ] |

Mọi hệ số mới đều chỉnh tay được trong **Menu → Hiệu chỉnh vật lý** (ma sát băng, truyền xoáy bi–bi, giảm xoáy ngang, hệ số massé). Bản xuất Markdown ghi nguồn từng hệ số.

## Điều khiển

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 10 | Không còn phím B. **Giữ bi effect = khoá hướng**: bi phóng to, chỉnh điểm chạm; ngón khác vuốt cơ trên bàn; buông = ngắm lại | UI test | [ ] |
| 11 | Khi giữ bi effect chỉ còn bi effect + bánh răng; bánh răng vẫn vi chỉnh được | ✅ bố cục 5 cỡ màn | [ ] |
| 12 | 4 icon gậy trên bi effect: Đánh · Jump (45°) · Massé (gậy Đánh 70°) · Break; icon đang chọn sáng lên, gậy trên bàn đổi theo | UI test | [ ] |
| 13 | Độ dốc cơ hình quạt 0–90°, nằm trên bánh răng bên trái bi effect, phóng to khi chạm | ✅ | [ ] |
| 14 | Bao cơ: 3 gậy kèm thương hiệu + "Thư viện gậy…" | UI test | [ ] |
| 15 | Vuốt cơ mịn hơn (ước lượng tốc độ trên cửa sổ dài hơn) | — | [ ] |
| 16 | Cơ không đâm xuyên bi: có bi sau bi cái thì cơ tự nâng lên đủ để vượt qua; điểm chạm thấp bị đẩy lên vùng với tới | ✅ bi cách 10 cm cần ~30°, 60 cm ~4° | [ ] |
| 17 | Tay trái: toàn bộ cụm (quạt, icon, bi effect, cột phím) lật gương | ✅ | [ ] |

## Lùi cú / đặt bi

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 18 | Lùi cú khôi phục đúng gậy, độ dốc, effect và hướng ngắm của cú đó | — | [ ] |
| 19 | Lùi cú được ngay khi bi còn đang lăn (luyện tập) | — | [ ] |
| 20 | Cú mới sau khi đánh: effect về tâm | — | [ ] |
| 21 | Đặt bi: bi cái về đúng chỗ vừa đánh (nếu chỗ đó trống), không thì ô trống gần giữa bàn | UI test | [ ] |

## Còn ở các đợt sau

- **0.31:** camera (về góc ngắm ngay, xem 3D toàn bàn khi mất lượt, zoom từ sát bi tới toàn bàn), bi lăn mượt, sửa mất tiếng, tiếng băng đục và trầm hơn.
- **0.32:** vân nỉ và băng, bi bớt chói, vết nỉ cũ tự nhiên, cảnh nền, thư viện gậy (Z‑Pr, Z‑Fu, ZB‑Pre…), bàn bar‑box.
- **0.33:** online (sửa lỗi chỉ xoay được mà không đánh được, phòng đặt tên + số ván, AirDrop, người xem thấy cú ra cơ), lưu khi xem lại, highlight trận, Coach có đường chỉ dẫn (điểm đến / lộ trình).
- **0.34:** bài tập lý thuyết dạng công thức → đánh số → hình học.

**Cần anh trả lời:** mục 10 của đợt trước ("hơi lệch góc chút") là lệch ở hệ kim cương nào hoặc thế bi nào?
