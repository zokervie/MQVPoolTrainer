# NHIỆM VỤ 0.50 — "Thế bí": giao diện (phiên Mac)

Chủ dự án chấp thuận 21/11 11:23. Thiết kế: Project doc `claude/zoker-he-thong-the-bi-2026-11-21.md`. Làm SAU 0.49b (X1–X8) và 0.49c (G1–G8).
Nhánh lõi: `cho/native-0.50-the-bi-core` (phiên đám mây). Gộp vào nhánh làm việc của Mac khi bắt đầu mốc này.

## Lõi đã có (C, bridging header thêm `#import "UI/Puzzle.h"`)
- `DrillCatalog.h`: thêm `skill` (12 công cụ `BL_SKILL_*`), `flags` (`BL_DRILL_LEGAL_FIRST`, `BL_DRILL_CLEAN`), loại `BL_DRILL_REACH`, `BLDrillSignature` (đường đi của cú vừa đánh), `BLSkillLesson(skill)` (bài Học cho nút "Ra bàn tập"). Bài 0.49 có `flags = 0` nên luật cũ không đổi.
- `Puzzle.h` + `PuzzleCatalogData.h` (sinh từ `Tools/drills/puzzles.json`): `BLPuzzleSpec` = một `BLDrillSpec` + 1–4 lời giải (`signature`, cú mẫu, `percent`, điểm gợi ý `hintX/Y`). `BLPuzzleIndex/At/Count`, `BLPuzzleRoomCount`, `BLPuzzleSolutionIndex`, `BLPuzzleMirror` (ôn lại = lật gương), `BLPuzzleSameRoute`.
- Bình gợi ý `BLHintJar*` (3 lượt, hồi 1/20 phút, +1 khi đạt bài Học liên quan; giá bậc 1/2/3 = 1/1/2), sao `BLPuzzleStars`, mở phòng `BLRoomOpen` (60 % sao phòng trước, phòng 7 Bank không chặn), `BLPuzzleOfferEasier`.
- Chấm cú thế bí: GỌI `BLDrillJudge(&puzzle.spec, …)` như bài thường, rồi `BLDrillSignature(…)` → `BLPuzzleSolutionIndex` để biết người chơi tìm ra lời giải nào.

## Việc
**T1. Bản đồ 9 phòng** (thay danh sách chương; tab Lộ trình của 0.49 L4). Mỗi phòng: bài Học (kho 0.49b) → thế bí → cửa ải (5 thế bí của phòng, không gợi ý). Ổ khoá theo `BLRoomOpen`; dòng "Còn N sao nữa là mở phòng …". Luôn hiện 2–3 thế bí đang mở để chọn.
**T2. Màn thế bí.** Một dòng yêu cầu theo `style`:
- POT "Đưa bi 1 vào lỗ. Bi cái chạm bi 1 trước." — *Pocket ball 1. Hit ball 1 first.*
- REACH "Chạm bi 1. Bi xám chắn đường thẳng." — *Hit ball 1. The grey ball blocks the straight line.*
- POSITION "Ăn bi 1, bi cái dừng trong vòng." — *Pocket ball 1 and stop the cue ball in the circle.*
- HIDE "Chạm bi 1 rồi giấu nó sau bi xám." — *Hit ball 1, then leave it hidden behind the grey ball.*
Biểu tượng công cụ cần dùng (`spec.skill`); "Đã tìm k/n lời giải" (n = `solutionCount`). Không vẽ đường ngắm (luật chế độ chính).
**T3. Thử lại < 1 giây**: một chạm, bi về chỗ cũ, không hộp thoại. Trượt: một dòng số đo thật (bi 1 cách lỗ bao nhiêu cm / bi cái lệch vòng bao nhiêu cm / chạm bi xám trước). Không bịa "suýt được".
**T4. Thang gợi ý** (nút bóng đèn + số lượt còn, đồng hồ hồi):
- Bậc 1: tên công cụ + nút **"Ra bàn tập"** mở bài `BLSkillLesson(skill)`; học xong một lượt Đạt → `BLHintJarEarn` → nút "Quay lại thế bí" (giữ nguyên thế).
- Bậc 2: chấm điểm `hintX/Y` của lời giải tốt nhất trên bàn (điểm chạm băng đầu hoặc vị trí bi ma) + số nút (`BLDrillDiamonds`).
- Bậc 3: chạy đường bi mẫu một lần (cú `solutions[0]`), mờ, không cho đánh trong lúc chạy.
Ghi `hintLevel`, `hintAt` vào `BLPuzzleProgress`.
**T5. Sao + Sổ lời giải.** `BLPuzzleStars` sau mỗi lần giải; vùng nhỏ = chấm lại với `goalR × 0,6`. Sổ lời giải: mỗi thế bí lưu đường bi của chính người chơi (mẫu xem lại đã có), so cạnh lời giải mẫu (chỉ mở sau khi đã giải).
**T6. Ôn có hẹn**: thế bí đã giải quay lại sau 1/3/7 ngày dưới dạng `BLPuzzleMirror`; nằm trong "Thế bí hôm nay" (thay "Bài hôm nay").
**T7. Kết thúc đẹp**: trượt 2 thế liên tiếp (`BLPuzzleOfferEasier`) → gợi ý một thế vừa sức đang mở. Nhắc nghỉ sau 45 phút chơi liền.
**T8. Đo cục bộ** (không gửi đi): số lần cạn bình gợi ý, tỉ lệ "Ra bàn tập" rồi quay lại giải được, số thế giải mỗi phiên, thế bị bỏ nhiều nhất.

## Nghiệm thu
UI test: mở thế đầu phòng 1, trượt → thử lại < 1 s; dùng gợi ý bậc 1 → sang bài Học → quay lại đúng thế; bình gợi ý trừ đúng; giải → sao đúng; phòng 2 mở khi đủ sao. Ảnh: bản đồ phòng, màn thế bí, gợi ý bậc 2. Báo cáo `NGHIEM-THU-0.50.md`.
