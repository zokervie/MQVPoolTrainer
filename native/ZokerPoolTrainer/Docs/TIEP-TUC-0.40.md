# Điểm dừng để tiếp tục (lưu 11/11/2026 23:12, hết hạn mức tới 03:40)

Nhánh làm việc: `fix/0.39-judder-candidate` (PR #5 + PR #6 của Shadow + sửa của em). Chưa build native.

## Đã xong trên nhánh
- Chống giật: HUD chỉ dựng lại khi bố cục đổi; bỏ gán lặp tần số/isPlaying mỗi khung; pacer đệm 8 mẫu, trễ 1 khung theo tần số đã chọn; xoay bi theo vận tốc góc (test trong Tests/FramePacerTests.swift).
- Chẩn đoán độ mượt (Tuỳ chỉnh → Máy · Âm thanh): CPU từng khâu, số lượt bố cục/dựng lại phím giữa cú, đồng hồ SceneKit − hiện tại, 2 công tắc A/B, sao chép số đo.
- `BankLab/Core/Opponent.hpp` (đấu với máy 6 cấp) — BẢN NHÁP, CHƯA có test, CHƯA nối vào app/Xcode.

## Việc còn lại theo thứ tự (anh dặn "gom luôn để build" 23:08)
1. Tests/OpponentTests.cpp (đăng ký CMakeLists.txt + Run-All-Checks.command): luôn ra cú hợp lệ; tỉ lệ vào theo cấp tăng dần; cấp cao thắng cấp thấp; tất định theo seed. Sửa Opponent.hpp tới khi xanh (`python3 Tools/run_acceptance.py --portable`).
2. Cầu ObjC `BLOpponent` (Core/BLOpponent.h/.mm, thêm vào project.pbxproj + bridging header) → Swift: chế độ "Đấu với máy" trong Thi đấu (chọn cấp, luật, race), máy đi lượt ở luồng nền, dùng chung đường `routeMatchShot`/Rules.
3. Sảnh: thêm "Đấu với máy"; Menu trong trận 4 mục.
4. Báo cáo nghiên cứu "Bi giật live so với replay": ghi chú ở /home/claude/research_notes/Bi giật live so với replay/ (2/3 xong; phần rà mã dừng giữa chừng vì hết hạn mức) → viết báo cáo.
5. Âm thanh mới, bàn WPA, bi văng xuống sàn, khung IAP: phần lớn, làm sau khi bản này xanh (cần mẫu âm/ảnh tham khảo).
6. Đẩy nhánh lên `ci/native-0.40` để CI build một lần; điền phiếu NGHIEM-THU-0.40.md; gửi IPA.

## Tiêu chí nghiệm thu giật (xem Docs/AUTOPSY-0.39-PHAN-BIEN-2026-11-11.md)
