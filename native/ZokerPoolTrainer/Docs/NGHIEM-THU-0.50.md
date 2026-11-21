# NGHIỆM THU 0.50 "Thế bí" — lát cắt giao diện (nhánh `cho/native-0.49-xuong-bai`, đã gộp `cho/native-0.50-the-bi-core`)

Lõi C (Puzzle.h, 50 thế, 979 kiểm) do phiên đám mây làm; gộp sạch, build + `check_suite_lists` (39 bộ) PASS. Phần Swift dưới đây là LÁT CẮT, chưa phải đủ T1–T8. Chưa xác minh trên thiết bị.

| Mục | Kết quả | Ghi chú |
|---|---|---|
| T1 bản đồ phòng | PASS (UI test) | Danh sách phòng theo `BLRoomOpen`: phòng 1 mở, phòng sau khoá + "Còn N sao nữa là mở phòng k"; sao theo thế. Chưa có "luôn hiện 2–3 thế mở", chưa thay danh sách chương, chưa có cửa ải. Mục vào: Sảnh › Bài tập › "Thế bí · 9 phòng". |
| T2 màn thế bí | PASS một phần | Một dòng yêu cầu theo kiểu thế (POT/REACH/POSITION/HIDE), tên công cụ, "Đã tìm k/n". Không vẽ đường ngắm. Chưa có biểu tượng công cụ. |
| T3 thử lại < 1 s | PASS (UI test) | Một chạm, không hộp thoại, đo trong app < 1 000 ms (thực tế < 1 ms ở khâu nạp). Trượt: một dòng số đo thật lấy từ `lessonShotScore` (ví dụ "bi 1 lướt cách lỗ 46 cm"). |
| T4 thang gợi ý | PASS bậc 1–2 (UI test bình trừ 1) / CHƯA LÀM bậc 3, "Ra bàn tập" + quay lại | Bình `BLHintJar` lưu trong PlayerStore (test 59 kiểm). Bậc 1 nêu tên công cụ; bậc 2 chấm điểm gợi ý + số nút. |
| T5 sao + Sổ lời giải | NOT RUN (sao) / CHƯA LÀM (Sổ) | Code `BLPuzzleSessionStars` + lưu sao có. KHÔNG kiểm được trong app: cú theo lời giải mẫu trong app trượt 10 cm (QA cờ `--puzzle-solve-qa`), tức app và máy chấm lệch ở thế bí p-1-01 — cần điều tra (nghi: góc/độ xoáy thực tế vs `Config::app`). Test giải đã gỡ để không báo PASS giả. |
| T6 ôn 1/3/7 ngày, T7 kết thúc đẹp, T8 đo cục bộ | CHƯA LÀM | (T8: PlayerStore đã có `puzzleTries`, `hintsEmptied`, chưa có màn xem.) |

Ảnh bản đồ phòng / màn thế bí / gợi ý bậc 2: NOT RUN.

accept_local đầy đủ: PASSED_SIMULATOR_UNSIGNED, 9/9 bước PASS, 46 UI test 0 lỗi (gồm 2 test thế bí mới).
