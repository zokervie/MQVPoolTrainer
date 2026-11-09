# Nghiệm thu Z-Trainer 0.36 — IQ200 vòng 2 (5 điểm) + Menu → Tuỳ chỉnh

Nhánh `ci/native-0.36` · **build 112** · run 42556252282 ✅ xanh toàn bộ (Linux g++/clang++, Mac Simulator, ảnh + đầu dò, XCTest cử chỉ, IPA). App hiện phiên bản **0.36**.

IPA: https://github.com/zokervie/MQVPoolTrainer/actions/runs/42556252282/artifacts/13647836742 (đăng nhập GitHub để tải)
Cột **CI** = đã kiểm tra tự động. Cột **Máy thật** = anh tick khi thử, ghi chú ngắn nếu chưa đạt.

## Lỗi gốc tìm ra trong lúc làm (quan trọng)

**Nỉ trắng, mất màu từ 0.35b.** Lệnh tô màu lên ảnh vân nỉ bị ghi đè kiểu "copy": toàn bộ vân thành một mảng xám phẳng, không còn màu đã chọn. Vì thế hai lần trước chỉnh độ sáng đều không ăn thua.

- Đã sửa gốc: nỉ giữ màu và vân thật.
- Ảnh CI: nỉ bàn mặc định từ 181/255 (be trắng) xuống khoảng 88/255 (xanh đúng màu).

## 5 điểm IQ200 vòng 2

| # | Hạng mục | Đã làm | CI | Máy thật |
| --- | --- | --- | --- | --- |
| 1a | Bi bớt sáng, bớt chói | Bi nhám hơn, lớp bóng mỏng hơn, sáng ×0,80; phơi sáng chung −2,0 (trước −1,45); đèn bàn dịu hơn | ảnh | [ ] |
| 1b | Bóng bi đậm, rõ, mềm | Bi đổ bóng thật từ đèn bàn (trước chỉ ở chế độ cao), bóng mềm 6–8 mẫu; bóng tiếp xúc dưới bi đậm và rộng hơn, viền mờ dần | — | [ ] |
| 1c | Hết sọc kim loại cạnh ngoài | Bỏ hẳn các nẹp kim loại mảnh 12 mm và 4 mm (mảnh dưới 1 điểm ảnh nên luôn răng cưa); viền còn lại chuyển satin mờ | — | [ ] |
| 2a | Bi dừng thì camera tự về Góc ngắm | Trước chỉ chạy khi đang ở một số góc camera; nay mọi góc (trừ xem lại, xem trộm, đặt bi), chuyển 0,2 s | UI test | [ ] |
| 2b | Điểm ngắm realtime | Tính giải tích mỗi khung hình (bi ma, đường bi cái, hướng bi đích, đường tiếp tuyến). Không còn mô phỏng trễ 0,3 s | — | [ ] |
| 2c | Tách 2 chế độ chỉ dẫn | **Điểm ngắm** = tới điểm chạm + vòng bi ma + hướng bi đích. **Cả đường** = mô phỏng cả quá trình lăn | — | [ ] |
| 2d | Đổi "Bảng" thành **Board** | ✅ | UI test | [ ] |
| 3 | Vân nỉ thấy sợi, nỉ tối hơn | Thêm lớp dệt trơn bước sợi 2,2 mm (theo mẫu Dragon Gold), tự mờ khi xa để không nhấp nháy; nỉ = 80 % độ sáng màu gốc (xem lỗi gốc ở trên) | ảnh | [ ] |
| 4 | Menu → **Tuỳ chỉnh** | Xem bảng dưới | — | [ ] |
| 5a | Phím phải sát lề phải (iPhone) | Trả lại 35 % vùng an toàn ngang | ảnh | [ ] |
| 5b | Cụm trái | Hàng ngang 4 loại gậy (Đánh, Jump, Massé, Break); dưới là **B** vuông (khoá giữ như cũ) và bi Effect tròn bên cạnh; iPad có kích thước riêng | ảnh + UI test + test C++ 36 kịch bản | [ ] |

## Menu → Tuỳ chỉnh

| Nhóm | Nội dung |
| --- | --- |
| Ánh sáng | Bi, Bàn (nỉ), Đèn, Độ nổi kim cương (nút số) |
| Lực và vật lý | Lực đánh tối đa; nút mở thông số vật lý |
| Bố cục phím | **Sắp xếp phím**: kéo thả từng phím rồi lưu; khôi phục mặc định |
| Độ mượt | 60 / 120 Hz; độ phân giải 3D 100 / 85 / 70 % (70 % mát máy) |

Có nút **Khôi phục tất cả**. Thay đổi áp dụng khi thả tay khỏi thanh trượt.

## Chưa xác minh trên thiết bị

- Độ chói của bi, độ đậm và mềm của bóng, màu và vân nỉ (ảnh CI chụp trên máy ảo không có GPU thật).
- Độ mượt 120 Hz, nhiệt độ máy, độ trễ của điểm ngắm.

## Chờ anh quyết trước build 0.37 (em không tự build)

**Tuỳ chỉnh thêm**
- Độ đậm bóng bi
- Độ rõ vân nỉ
- Góc ngắm mặc định (cao, gần, FOV)
- Kích thước và độ trong của phím

**Phát kiến**
- Dự đoán rồi mới hiện đường đúng, báo lệch bao nhiêu độ
- Mẫu ánh sáng: Câu lạc bộ / TV / Dịu mắt
- Nút số tự hiện khi đường ngắm chạm băng

**Khác**
- Đường chỉ dẫn mờ dần theo trình độ
- Chấm độ đều tay (độ chụm điểm dừng)
- Phím tự mờ khi ngắm
- Lưu nhiều bố cục
- Bộ thông số theo loại bàn
- Màu và độ dày đường ngắm
