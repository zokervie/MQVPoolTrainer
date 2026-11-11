# Nghiệm thu Zoker Pool / Trainer 0.39

Nhánh `ci/native-0.39` · build: (điền khi CI xanh). Cột **Máy thật** = anh tick khi thử.

## Đã đạt ở 0.38 (anh xác nhận 11/11)
Mượt khi kéo ngắm · nỉ hết sọc · cơ tự nâng không xuyên băng/bi.

## Sửa trong 0.39

| # | Anh thấy | Nguyên nhân thật | Cách sửa | Máy thật |
|---|---|---|---|---|
| 1 | Bi chạy giật, không trôi | Vật lý chạy theo đồng hồ của app, SceneKit vẽ theo đồng hồ riêng; hai nhịp lệch nhau nên có khung vẽ 2 bước, có khung 0 bước | Bộ đồng bộ khung hình: SceneKit tự đặt bi đúng thời điểm vẽ (nội suy giữa 2 mẫu). Công tắc trong Tuỳ chỉnh → Máy | ☐ |
| 2a | Bóng cơ răng cưa | Cây cơ mảnh nằm trong bản đồ bóng → răng cưa | Cơ không đổ bóng vào bản đồ; chỉ còn bóng chiếu mềm (Gauss) | ☐ |
| 2b | Bóng bi không tròn, không mềm | Bóng bản đồ ít mẫu, cả bàn/sàn cùng đổ bóng | Học bản 0.19 (anh khen): chỉ bi đổ bóng, bản đồ 2048, bán kính 4, 8 mẫu + lõi bóng tròn 2 lớp Gauss dưới bi | ☐ |
| 2c | Bi chủ sát băng, gậy che hướng ngắm | — | Gậy mờ còn ~28 % khi trên màn hình nó che đường ngắm/bi mục tiêu; góc nhìn thấy rõ thì giữ nguyên | ☐ |
| 3 | Sợi nỉ to, phẳng, giả | Bước sợi 2,2 mm (thật ~0,55 mm), sợi đều tăm tắp | Bước 0,6 mm, mỗi sợi dày/sáng khác nhau, xoắn sợi, khe tối giữa sợi | ☐ |
| 4 | Đầu típ dày, phẳng | Típ 8 mm trụ phẳng | Típ 4,5 mm, vòm bán kính 9,5 mm (giữa "dime" và "nickel"); tính lại điểm chạm | ☐ |
| 5a | Nỉ cũ máy móc | Vệt thẳng kẻ tới lỗ | Chấm li ti dày ở vùng break và chỗ xếp bi, vệt mờ uốn lượn, chấm ngẫu nhiên, dấu tam giác xếp bi | ☐ |
| 5b | Bi cũ phải đục, có vết lơ | — | Bi cũ: hết lớp bóng, đục, hơi ngả vàng, vết lơ xanh, xước nhỏ | ☐ |
| 5c | Sàn nhấp nháy sọc | Sàn tự đổ bóng lên chính nó + phân tầng màu | Sàn/tường không đổ bóng; hạt nhiễu siêu mịn trên mọi mặt lớn | ☐ |
| 6 | Viền kim loại quanh bàn | — | Bỏ kim loại trên thân bàn: viền, nẹp chân dùng cùng chất liệu thân bàn | ☐ |
| 7a | Wi‑Fi/online: không break được, phím 2 bên tắt | Lượt chuyển sang máy anh qua mạng nhưng phím chỉ cập nhật ở chỗ khác | Mọi lần đổi lượt làm mới toàn bộ phím + 2 lần/giây đối chiếu quyền đánh thật | ☐ |
| 7b | Bảng điểm đơn điệu | — | Bảng kiểu truyền hình: thẻ tên xanh/đỏ, ô điểm vàng chữ số đậm, viền sáng cho người đang đánh | ☐ |
| 8 | Xem lại: cảnh đầu quá cao, đèn che | Góc 41° | Hạ còn 26°, gần hơn, vẫn thấy cả bàn | ☐ |
| 9 | Tuỳ chỉnh rối | Xếp theo kỹ thuật | 5 thẻ theo việc anh nghĩ: Hình ảnh (Bi · Bàn · Đèn) · Ngắm · Phím · Vật lý · Máy/Âm thanh | ☐ |
| 10 | Sảnh hơi rối | — | Tuỳ chỉnh lên đầu chân trang; đổi tên mục cho rõ | ☐ |

Còn chờ: xuất video highlight (anh thử lại sau khi Wi‑Fi chạy được).
Chưa xác minh trên thiết bị: toàn bộ cột "Máy thật".
