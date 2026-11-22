# Giao việc 0.55 — "Đặt thế bí cho bạn": giữ trong TestFlight, nhãn Thử nghiệm (cho phiên Mac)

Chủ dự án quyết 22/11: giữ N3 trong bản TestFlight đầu để đo người thử có gửi mã cho nhau không. Review (phiên đám
mây, đọc `UserPuzzle051.swift`, `BLDrillQuick.mm`, `PuzzleDaily.h`): lõi mã đúng (15 ký tự, 10 bit kiểm, làm tròn
không tạo bi chạm), máy nhận kiểm lại lời giải trước khi cho chơi, không có chữ tự do của người dùng trong mã (không
cần kiểm duyệt). Cần sửa 5 điểm nhỏ, làm trên nhánh `cho/native-0.53-phieu-lo`:

**R1. Kết quả kiểm cũ ghi đè thế mới (lỗi).** `check()` chạy nền; nếu người chơi kéo bi trong lúc đó, `changed()` xoá
`checked`, nhưng khi tác vụ nền xong nó lại gán `checked` của thế CŨ và bật nút Gửi → mã gửi đi không khớp thế đang
thấy. Sửa: số thế hệ (tăng trong `changed()`, tác vụ nền chỉ ghi kết quả nếu số còn khớp) và khoá kéo bi khi đang kiểm.
Áp dụng tương tự cho `receive()`. Test đơn vị/UI: kiểm → đổi thế ngay → nút Gửi vẫn tắt.

**R2. Nhãn "Thử nghiệm".** Mục menu và tiêu đề màn hình có nhãn nhỏ "Thử nghiệm" (en "Beta").

**R3. Dòng chia sẻ.** Hiện chỉ "Thế bí của tôi: <mã>". Đổi thành:
`Zoker Pool · Thế bí của tôi (<Vào lỗ | Chạm bi 1 | Giấu bi>): XXXXX-XXXXX-XXXXX — bạn giải được không?`
(en: `Zoker Pool · My puzzle (<Pot | Reach ball 1 | Hide>): … — can you solve it?`). Không kèm đường ngắm hay lời giải.

**R4. Phía người nhận.** Nút "Dán" lấy mã từ bộ nhớ tạm (chỉ khi người dùng bấm). Sau khi kiểm xong, trước khi chơi
hiện "N lời giải · dễ nhất vào P %". Mã sai hoặc không giải được: giữ thông báo hiện có.

**R5. Đếm tại máy.** Lưu trong PlayerStore: số mã đã gửi (bấm Gửi), số mã đã nhận và chơi, số mã giải được. Hiện ba số
này ở cuối màn "Đặt thế bí cho bạn" (chữ nhỏ). Không gửi đi đâu; để người thử chụp màn hình báo lại.

Báo cáo: mỗi mục PASS / FAIL / NOT RUN trong `NGHIEM-THU-0.53.md` (mục mới "0.55"). Chưa xác minh trên thiết bị.
