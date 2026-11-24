# Nhiệm vụ 0.59 — Thang 5 sao, bộ 5 thế, góc ngắm lệch, lùi cú theo tỉ lệ, hồ sơ (phần Swift, phiên Mac)

Chủ dự án duyệt 24/11/2026 ("CHẤP THUẬN hết"). Thiết kế đầy đủ: Project `claude/zoker-he-thong-bai-tap-va-ho-so-2026-11-24.md`.
Lõi C đã làm ở nhánh `cho/native-0.59-loi` (phiên đám mây, test trước): `BankLab/UI/Mastery059.h`, `BankLab/Core/PoseCheck.hpp`,
`Tools/drills/pose_pick.{cpp,sh}`, `BankLab/UI/DrillPoseData.h` (sinh tự động), `Tests/Mastery059Tests.cpp` (đã đăng ký CMake + Run-All-Checks),
`Mastery059.h` đã thêm vào bridging header. Luật chỉ nằm trong C; Swift chỉ gọi và lưu.

Làm trên nhánh mới từ `cho/native-0.59-loi` (đã gồm 0.58c). Mỗi mục một commit. Không đổi luật trong Swift.

## S1. Chấm sao (thay BLRoundStars 0–3)
- `Ladder054.swift`: lượt chấm dài `BLRoundShots(chapter)` cú (5 ở chương 1–4, 10 từ chương 5). Đếm lùi cú TRONG lượt; sao = `BLRoundStars5(chapter, made, undoInRound)`.
- Mở vòng kế: `BLTierOpen5`. Khởi động: `BLWarmupMadeFor(chapter)` (0 = không khởi động). Từ chương 7 chỉ cho 1 lần lùi cú mỗi lượt (`BLRoundUndoLimit`).
- % chương: `BLChapterPercent5` (thay `BLChapterPercent`). Danh hiệu vẫn theo `BLTitleIndex` trên % mới.
- Hiển thị sao: một hàm 5 ô duy nhất. Lỗi cũ: `Drill.starText` 5 ô vẽ giá trị 0–3 → 5/5 cú hiện ★★★☆☆ (Ladder054.swift ~dòng 107). Rà mọi chỗ gọi `starText`/`starText3` cho đúng thang.
- `PlayerStore.recordLadderRound`: lưu sao 0–5 và `made`; bỏ ánh xạ `s==3 ? 5 : …`.

## S2. Thẻ kết quả vòng
- Dòng đầu: "Vòng N · ★★★★★" (đúng số sao). Dòng 2: "5/5 cú vào vòng". Dòng 3: "Chương +x % (tổng y %)".
- KHÔNG in danh hiệu chương trên thẻ vòng (nó đọc như lời chê). Danh hiệu chỉ ở trang chương, hồ sơ, và khi LÊN bậc danh hiệu (chúc mừng).
- Chưa đủ 3 sao: "Cần N cú vào vòng để mở vòng kế" với `BLMadeForStars5(chapter, 3)`.
- Giữ tự lên vòng 1,5 s + "Ở lại" của 0.58c.

## S3. Chuyển dữ liệu cũ (một lần, có cờ đã chuyển)
- Mỗi vòng: sao mới = `BLStarsMigrate058(chapter, saoCũ, madeTốtNhất)`; `madeTốtNhất` lấy từ lịch sử lượt (recordRound/achievements); không có thì -1. Không ai mất tiến độ. Test Swift: 3 → 4 khi không có made; 3 với made 5 → 5.

## S4. Quỹ lùi cú theo tỉ lệ
- Thay `BLChapterUndoBudget(chapter)` bằng `BLChapterUndoFund(chapter, rungs, BLRoundShots(chapter))`, `rungs` = số vòng của chương (`BLLadderRungs`). Chương 1 vẫn không giới hạn; chương 2–5 với 27 vòng × 5 cú ra đúng 100/70/50/30.
- Hiện "Còn N lần lùi cú" ở trang chương. Hết quỹ không mất tiến độ. Cứu thanh lực (`BLPowerBarRescue`) giữ nguyên, đọc "còn lại" từ quỹ mới.

## S5. Góc ngắm ban đầu lệch
- Khi nạp mỗi cú (chương ≥ 2): góc cơ = góc lời giải của thế đó + `BLStartAimOffsetDeg(key, chapter, round, shot)` độ (dấu ±). Chương 1 = 0.
- Chương ≥ 5: điểm chạm đầu cơ về giữa bi (`BLStartTipCentred`). Chương ≥ 7: camera mở ở góc đứng (`BLStartCameraStanding`).
- Thi chương, mã thách bạn: dùng CÙNG công thức (tất định) để mọi người như nhau.

## S6. Bộ 5 thế
- Cú thứ `shot` của lượt `round`: thế = `BLRoundPose(key, round, shot)`; bố cục = `BLDrillPoseFor(spec, pose, &L)` (thay `BLDrillLayoutFor(spec, variant, …)` trong vòng chấm). Lượt 10 cú chơi bộ hai lần, mỗi nửa xáo riêng.
- Bài không có bộ (chương 1, bài chưa chọn được) tự trả bố cục gốc: không cần nhánh riêng.
- `round` = số lượt chấm đã chơi của vòng (lưu theo id vòng).

## S7. Hồ sơ (nền 0.58 đã có thành tích + bộ đếm trận)
- Ba khối: Luyện tập (tổng sao, % từng chương, tủ huân chương) · Thi đấu (đấu máy theo từng cấp, Wi-Fi, online; mỗi mục số trận, thắng/thua, tỉ lệ thắng, chuỗi thắng dài nhất, số ván dọn bàn; lọc 8/9/10/15 bi) · (Chỉ số tay nghề: để 1.1, không làm).
- Pass & play KHÔNG tính vào thành tích (bỏ ghi `recordMatch` cho chế độ này).
- Chạm huân chương: số sao, thời gian hoàn thành, số lượt thử, số lần lùi cú, "Tay sạch", ngày đạt, chuỗi trúng dài nhất; mỗi bậc màu + biểu tượng riêng (SF Symbols, không logo thật).
- Lưu kèm mỗi huân chương thông số các cú của lượt đạt (góc, lực, điểm chạm, thế, lượt): để sau này máy chủ chạy lại xác nhận. Chỉ lưu, chưa gửi đi.

## Test giữ cửa
- C++: `Mastery059Tests` (đã có) chạy trong Run-All-Checks.
- Swift/UI: vòng chương 1, đánh 5/5 → thẻ hiện 5 sao và không có danh hiệu "Tay Mơ"; chương 3 có lùi cú trong lượt → tối đa 4 sao; cú đầu chương 3 góc cơ lệch ≥ 1,5° so với lời giải; hai lượt liên tiếp thứ tự thế khác nhau; chuyển dữ liệu cũ.
- Sửa `testChapterOneLadderAndExam` theo thẻ mới (không nới lỏng).

## Không làm ở 0.59
Thang vòng chương 4–9, chương mới (Ép phê, Safety, Jump, Massé), phòng tự soạn, Chỉ số tay nghề, Game Center.

## Báo cáo
Ảnh thẻ kết quả trước/sau, ảnh hồ sơ, PASS/FAIL/NOT RUN từng mục, phần chưa xác minh trên thiết bị.
