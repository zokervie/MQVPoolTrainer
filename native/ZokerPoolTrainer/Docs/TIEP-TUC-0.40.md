# Điểm dừng để tiếp tục (cập nhật 12/11/2026 04:15)

Nhánh làm việc: `fix/0.39-judder-candidate` → đẩy lên `ci/native-0.40` (run 43099934072) để build một lần.

## Trạng thái
- 0.39d chống giật: CI 128 (`ci/native-0.39d@8d2dea0`) **PASSED_SIMULATOR_UNSIGNED**; bước cuối chỉ hỏng vì GitHub lỗi tải artifact (404), IPA ứng viên 128 có. Chưa thử máy thật.
- Rà mã live/replay xong (`/home/claude/research_notes/Bi giật live so với replay/code_audit.md`); báo cáo `/home/claude/reports/Bi giật live so với replay.md`.
- Sửa thêm theo rà mã (trong 0.40): bi rơi lỗ bắt đầu từ vị trí đang hiện; máy khách Wi‑Fi không dựng lại phím khi xem cú của chủ.
- Đấu với máy: `Core/Opponent.hpp` + `Tests/OpponentTests.cpp` (đăng ký CMake + Run-All-Checks, ~80 s). Tỉ lệ vào trên 16 thế 1 bi: 2/4/6/6/12/13 (Beginner→AI). Hệ số tay là GIẢ ĐỊNH, chỉnh theo người thật.
- Cầu `BLOpponent` (.h/.mm, pbxproj, bridging header); Swift: `MatchPlayController.swift` cuối file (openComputerMatch → cấp → luật → race; driveComputerTurn mỗi tick; máy đi lượt bằng applyMatchCommand player 1). Sảnh → Thi đấu → "Đấu với máy · 6 cấp".

## Còn lại
1. Nếu CI 0.40 đỏ: đọc log job macOS (`gh api .../jobs/<id>/logs | grep "error:"`), sửa, đẩy lại `ci/native-0.40`.
2. Xanh: điền NGHIEM-THU-0.40.md, gửi anh IPA + cách thử (giật: Chẩn đoán độ mượt → Sao chép số đo; Đấu với máy: thử 2 cấp đầu và cuối).
3. Chưa làm: Menu trong trận 4 mục; host bỏ dựng snapshot/JSON mỗi tick trước throttle 0,1 s (rà mã mục 7); âm thanh mới; bàn WPA; bi văng xuống sàn; khung IAP/StoreKit 2; bài mỗi ngày; Z-Exam.

## Tiêu chí nghiệm thu giật: Docs/AUTOPSY-0.39-PHAN-BIEN-2026-11-11.md
