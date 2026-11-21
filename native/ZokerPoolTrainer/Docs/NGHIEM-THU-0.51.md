# NGHIỆM THU 0.51 "Thế bí của ngày · Đoán đường bi · Đặt thế cho bạn" — chỉ làm N1

Lõi `PuzzleDaily.h` do phiên đám mây làm (1 133 kiểm). Chưa xác minh trên thiết bị. Mọi ngưỡng là GIẢ ĐỊNH.

| Mục | Kết quả | Ghi chú |
|---|---|---|
| N1 thế bí của ngày | PASS (UI test) | Sảnh › Bài tập › "Thế bí của ngày". Cùng thế theo ngày địa phương (`BLDailyPuzzle`, lật gương khi `mirrored`), 6 cơ, không gợi ý; mỗi cơ chấm ⚪🟡🟢 (`BLDailyGrade`, số đo trượt `BLPuzzleMissMetres`, riêng REACH lấy khoảng gần nhất bi cái–bi 1 trừ 2R); giải xong hoặc hết 6 cơ thì khoá tới ngày mai, mở lại cùng ngày hiện thẻ kết quả, ngày sau thế mới (UI test dùng cờ QA đặt ngày). Thẻ kết quả + nút Khoe: chữ `BLDailyShareText` (không lộ thế) và ảnh 1080×1350 (logo, số thế, dấu chấm, chuỗi ngày; không vẽ thế bi). Lưu theo ngày trong PlayerStore (test 69 kiểm). |
| N1 còn thiếu | CHƯA LÀM | Cập nhật chuỗi ngày bằng thế của ngày (hiện chỉ hiển thị chuỗi sẵn có), đo cục bộ "tỉ lệ giải / số cơ trung bình" (có đếm lần bấm Khoe), sửa `BL_DAILY_EPOCH_DAY` theo ngày phát hành, ảnh thẻ chưa xem bằng mắt. |
| N2 đoán đường bi + Chỉ số Mắt | CHƯA LÀM | |
| N3 đặt thế bí cho bạn | CHƯA LÀM | cần cầu nối ObjC++ gọi `drillQuickFamilies`, màn xếp bi |
| N4 tinh tế (bóng của mình, miệng lỗ, clip 6 s, tờ dán PDF) | CHƯA LÀM | |

accept_local đầy đủ: PASSED_SIMULATOR_UNSIGNED, 9/9 bước PASS, 53 UI test 0 lỗi.
