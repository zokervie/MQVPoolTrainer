# Nghiệm thu Z-Trainer 0.31 — hiệu chuẩn theo số liệu đã công bố

Nhánh `ci/native-0.31`. Bộ kiểm tra `Tests/PublishedBenchmarkTests.cpp` chạy 20 bài chuẩn lấy từ số liệu đo trên bàn thật đã công bố (Alciatore: *Physical properties*, TP A.4, A.5, A.14, 4.1, A.30; Mathavan 2010; pooltool). Mỗi lần build CI chạy lại toàn bộ.

| # | Bài chuẩn (nguồn) | Khoảng công bố | Z‑Trainer 0.31 |
| --- | --- | --- | --- |
| B01 | Stun thẳng: tốc độ bi đích / bi cái (e bi–bi 0,92–0,98) | 0,96–0,99 | 0,969 |
| B02 | Stop shot: bi cái đứng lại | ≤ 0,08 m/s | 0,059 |
| B03 | Luật 90°: stun cắt 30° (trừ e và throw) | 80–90° | 81,5° |
| B04 | Luật 30°: bi lăn, half‑ball | 27–34,5° | 33,9° |
| B05 | Throw do cắt, chậm, half‑ball | 3,5–6,5° | 4,9° |
| B06 | Throw giảm khi đánh mạnh (tỉ lệ nhanh/chậm) | 0,2–0,9 | 0,68 |
| B07 | Bi lăn throw ít hơn stun (tỉ lệ) | 0,3–0,95 | 0,43 |
| B08 | Effect "ăn khớp" (gearing) triệt throw | ≤ 0,6° | 0,00° |
| B09 | Trượt → lăn: μ trượt suy ra | 0,15–0,4 | 0,20 |
| B10 | Tốc độ lăn = 5/7 tốc độ stun | 0,69–0,74 | 0,714 |
| B11 | Ma sát lăn suy ra | 0,005–0,015 | 0,012 |
| B12 | Xoáy ngang giảm (rad/s²) | 5–15 | 15 |
| B13 | Kéo bi 0,5R, 3 m/s, bi đích cách 0,3 m: bi cái về | 0,2–2 m | 0,86 m |
| B14 | Bổ thẳng: bi cái giữ ~2/7 tốc độ | 0,22–0,34 | 0,28 |
| B15 | Băng: tốc độ bật / tốc độ vào | 0,6–0,9 | 0,83 |
| B16 | Gậy phá lực max: tốc độ bi cái | 10–13,5 m/s | 11,9 |
| B17 | Giới hạn trượt cơ (điểm chạm) | 0,5–0,6R | 0,55R |
| B18 | Effect tối đa R·ω/v | 0,6–1,25 | ✅ |
| B19 | Ma sát bi–bi ở trượt 1 m/s | 0,03–0,08 | 0,073 |
| B20 | Ma sát bi–bi ở trượt 4 m/s | 0,03–0,08 | 0,051 |

**Đã đổi so với 0.30** (vì nằm ngoài số liệu công bố):
- Ma sát băng 0,45 → **0,20** (công bố 0,14–0,2). Effect max vào băng 90° giờ bật ~25° thay vì ~45°. Mức 0,45 (≈ 40°) vẫn chọn được trong *Hiệu chỉnh vật lý* nếu anh thấy bàn mình như vậy.
- Đầu cơ tối đa 0,70R → **0,55R** (giới hạn trượt cơ ~0,5R; tẩy mềm +0,05R).
- Xoáy ngang giảm 18 → **15 rad/s²** (đầu trên khoảng công bố).
- Cú phá: va chạm bi–bi giải theo thời gian, nhóm chạm cùng lúc giải đồng thời → kết quả không phụ thuộc thứ tự, cú phá thẳng tâm đối xứng (trước lệch tới 1,2 m).

**Giữ nguyên, có căn cứ khác:** β băng 0,30 (khớp clip zigzag ngược, 4 băng ≤ 0,3 nút); hệ corner‑5 vẫn trong sai số bàn thường (lệch 0,2 nút).

| # | Trên máy thật | Máy thật |
| --- | --- | --- |
| 1 | Effect vào băng, kick, zigzag ngược: cảm giác so với bàn thật | [ ] |
| 2 | Kéo, bổ, stop, luật 30°/90° nhìn đúng | [ ] |
| 3 | Cú phá tản bi tự nhiên, không lệch một bên | [ ] |
