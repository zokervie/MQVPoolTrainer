# NGHIỆM THU 0.52 "Bài băng, bài trô"

Chưa xác minh trên thiết bị (cảm giác đánh).

| Mục | Kết quả | Ghi chú |
|---|---|---|
| B1 gộp `origin/cho/native-0.52-bai-bang-tro` | PASS | Gộp không xung đột; `gen_catalog.py --check` báo dữ liệu bài/thế đã khớp. Mô hình băng mới `cushionModel = 1` giữ MẶC ĐỊNH TẮT, không thêm nút. |
| B2 chữ bài bank3 | PASS | Tiêu đề "Bank 2 băng dài" (en "Long 2-rail bank"), ghi chú "Bi 1 chạm băng phải, sang băng trái rồi về lỗ giữa phải." (en tương ứng), `rails: 2`, id `bank3` giữ nguyên nên tiến độ không mất, link video giữ (khoá theo tên mới). check_vi_en PASS. |
| B3 accept_local | PASS | PASSED_SIMULATOR_UNSIGNED, 9/9 bước, 56 UI test 0 lỗi (lần chạy thứ hai; lần đầu 1 lỗi do test thế bí ngày đọc đầu dò quá sớm, đã sửa test, không phải lỗi app). `testNoUIKitLayoutPassWhileTheBallsRoll` nhấp nháy một lần (midShotLayout=1) rồi qua khi chạy lại và trong lần đầy đủ cuối: để mắt. |
| Mở chương Bank / Dừng–theo–lùi, so ảnh với sơ đồ | NOT RUN (xem bằng mắt) | Bước ảnh chụp của accept_local PASS nhưng em chưa mở từng thẻ bank/draw trên Simulator để so sơ đồ 2 băng với hình; cần anh hoặc lượt sau. |
