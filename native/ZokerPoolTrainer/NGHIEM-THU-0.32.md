# Nghiệm thu Z-Trainer 0.32 — bộ chuẩn 2: kick, bank, massé, jump, trick shot

Nhánh `ci/native-0.32` · build 112 (run 88) · CI xanh: Linux g++/clang++ (63 bài chuẩn), Mac Simulator, 17/17 UI test, IPA. Tổng **63 bài chuẩn** chạy trong CI mỗi lần build: 20 bài vật lý cơ bản (`PublishedBenchmarkTests`, xem 0.31) + 43 bài hệ thống (`SystemsBenchmarkTests`). Nguồn: Alciatore (TP + video tốc độ cao), Bob Jewett (Billiards Digest), Corner‑5 / Diamond system, Coriolis (massé), thông số bi/bàn công bố.

| Nhóm | Bài | Kết quả 0.32 |
| --- | --- | --- |
| Kick 1 băng | không effect ~ gương (38,6° với vào 45°); effect thuận mở +14°; effect ngược không mở rộng (ma sát băng bão hoà — thuận mạnh hơn ngược, đúng TP); đánh mạnh ngắn hơn 9,6°; bổ mở hơn kéo | 8/8 |
| Kick 2 băng | qua góc bàn: bi về song song (177,7°), thuận/ngược vẫn về sạch | 3/3 |
| Kick 3 băng | Corner‑5 A = D − T: lệch bàn +2,1, phân tán 2,4 đơn vị; mạnh → ngắn; thêm effect thuận → dài | 4/4 |
| Kick 4 băng | 4 m/s đi đủ 5 băng; giữ tốc độ mỗi băng ≥ 0,46 | 2/2 |
| Bank 1 băng | chậm: gương 45,1°; **bank mạnh đi ngắn** (−10,9°); cắt 25° vẫn bank | 4/4 |
| Bank 2–4 băng | bi đích đi đủ 2/3/4 băng | 3/3 |
| Massé | hướng cuối khớp công thức Coriolis (sai < 0,01°) ở 30°/60°/75°, trái/phải; dốc hơn → cong hơn; trái/phải cong ngược nhau | 8/8 |
| Jump | cơ nằm ngang không nhảy; 45° 4 m/s bay 102 mm; nhảy qua bi chắn 25 cm; **bi cái đang bay đè lên bi đích → bi đích nảy lên 15 mm** (mới sửa) | 4/4 |
| Trick / xoáy | combo dính: bi trước bị throw 2,1°/4,6°/4,2° (15/30/45°); bánh răng: thuận giữ chiều xoáy, ngược đảo chiều; swerve trái/phải; kéo lê 0,8 m vẫn về 0,9 m | 7/7 |

**Sửa vật lý trong 0.32:** bi bị đè xuống mặt bàn bởi bi khác nảy theo hệ số đàn hồi mặt đá (0,5) — trước đây bị "dính" xuống, nên cú jump bi cái đè bi đích không làm bi đích bay.

**Phát hiện có căn cứ (không sửa):** effect ngược ở góc 45° tác dụng ít hơn effect thuận vì tiếp xúc băng đã trượt sẵn khi không effect (ma sát bão hoà). Ở góc dốc hơn (gần vuông góc băng) effect ngược mới thu góc rõ.

| # | Trên máy thật | Máy thật |
| --- | --- | --- |
| 1 | Kick 1–4 băng, bank 1–4 băng có / không effect | [ ] |
| 2 | Massé các mức dốc, jump qua bi, jump đè bi đích | [ ] |
| 3 | Combo dính, kéo lê, swerve | [ ] |
