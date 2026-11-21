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

## Lượt hoàn tất (sau điều tra lệch app ↔ máy chấm)
**Nguyên nhân gốc lệch** (so `engine.settings` với `Config::app` bằng cờ QA `--settings-diff-qa`): cơ đã lưu từ lần chơi trước là Jump (`cueElevationDegrees=45`, `cueType=1`, `experimental3D=1`), nên cú lời giải mẫu trượt 9–10 cm; thêm một nguyên nhân phụ: `beginPuzzle` gọi `loadDrill` một lần và `loadDrill` im lặng bỏ qua khi camera cú chưa về. Sửa: thế bí và bài tập luôn bắt đầu bằng cơ thường (`chooseShotKind(0)`), `beginPuzzle` chờ nạp xong rồi mới mở phiên. Test giải (bắt đầu với cơ Jump đã lưu, `-shotKind017 1`) PASS. Chưa có test C++ vì lệch nằm ở trạng thái app, không ở lõi.

| Mục | Kết quả | Ghi chú |
|---|---|---|
| T4 bậc 3 | PASS (UI test) | đường mẫu chạy một lần (4 s, mờ), khoá cú trong lúc chạy, tốn 2 lượt, lưu `watchedAt` (sao ≤ 1 theo `BLPuzzleSessionStars`). |
| T4 Ra bàn tập + Quay lại | PASS (UI test) | bậc 1 → "Ra bàn tập" mở bài Học của công cụ; vòng đạt → +1 gợi ý (bình 2 → 3) và nút "Quay lại thế bí". |
| T5 sao | PASS (UI test giải bằng lời giải mẫu) / Sổ lời giải PASS (mở được, có mục) | Sổ: cú của bạn cạnh cú mẫu (lệch góc, lệch lực). Chưa vẽ hai đường bi cạnh nhau. |
| T6 ôn 1/3/7 ngày | PASS (UI test) | phần "Thế bí hôm nay" trong danh sách; thế lật gương (`BLPuzzleMirror`), không sao. Chưa nằm trong màn "Bài hôm nay" cũ. |
| T7 kết thúc đẹp | PASS (UI test) | hai thế liền chưa giải → đề nghị thế mở, chưa giải, dễ nhất; nhắc nghỉ 45 phút (có code, chưa có test). |
| T8 đo cục bộ | PASS (UI test mở màn) | số thế giải, lần cạn bình, tỉ lệ ra bàn tập rồi quay lại giải được, thế bỏ nhiều nhất. Chỉ trên máy. |
| Biểu tượng công cụ | PASS (có trên thanh thế bí và danh sách) | SF Symbols. |
| Ảnh bản đồ phòng / màn thế bí / gợi ý bậc 2 | NOT RUN | ảnh chụp XCUITest bị xoay 90° (chưa sửa được: đặt hướng thiết bị không đổi kết quả) |

accept_local đầy đủ cuối lượt: **PASSED_SIMULATOR_UNSIGNED**, 9/9 bước PASS, 53 UI test 0 lỗi. Test thế bí "hai lần trượt" và "gợi ý" từng không ổn định (bấm nút khi QA đang bắn / chưa sẵn sàng); đã sửa tận gốc bằng chờ điều kiện có hạn giờ.
