# Sổ lỗi ZB — Zokervie (lập 27/11/2026)

Sổ DUY NHẤT cho lỗi của app. Lỗi mới chỉ được ghi ở đây, không ghi rải trong NGHIEM-THU/TRANG-THAI.
Bản sao cho chủ dự án xem: Project `claude/zoker-so-loi-zb.md` (cập nhật cùng lúc).

## Luật
- **Mức nặng.** S1: sai cảm giác đánh/luật/âm thanh của cú, hỏng trận, mất dữ liệu. S2: sai thông tin người chơi cần để chơi, che nội dung chính. S3: xấu, khó đọc, gây hiểu nhầm nhẹ. S4: trau chuốt.
- **Trạng thái.** MỞ → ĐÃ SỬA (commit, chờ máy thật) → ĐÓNG. Chỉ ĐÓNG khi đủ hai điều: (1) có test giữ cửa hoặc ảnh chuẩn chạy trong CI, (2) anh ghi "Đạt" trên máy thật.
- **Lỗi trước, tính năng sau.** Còn S1/S2 ở trạng thái MỞ thì không mở việc giao diện/tính năng mới. Phần đọc nguồn và test C++ (vật lý 0.60, Carom) vẫn chạy được.
- **Tuổi lỗi.** MỞ quá 7 ngày tự lên đầu danh sách của bản kế tiếp.
- **Nguồn.** Mỗi dòng ghi video/ảnh + mốc giây, hoặc người báo (anh, em, ChatGPT).
- Nhãn bằng chứng: VERIFIED / REPORTED / INFERRED / UNVERIFIED.

## Đang mở hoặc chờ máy thật

| Mã | Mức | Lỗi | Nguồn | Trạng thái | Test giữ cửa |
|---|---|---|---|---|---|
| ZB-003 | S1 | Máy khách Wi-Fi: cơ đổi hướng lúc ra tay (theo hướng ngắm cũ của đối thủ); bi chạy trước khi đầu cơ chạm | Video 202 A 11,9 s, B 12,2 s (anh + ChatGPT #2), VERIFIED khung hình | ĐÃ SỬA ff8b028 | Chưa — cần 2 Simulator (đợt kế) |
| ZB-004 | S1 | Máy khách: tiếng va chạm của cú mình phát lại ~5 s sau, khi đã đổi lượt | Video 202 A 13,5–21,0 s (ChatGPT #1), VERIFIED: dạng sóng trùng 99–100 % | ĐÃ SỬA ff8b028 | Chưa — 2 Simulator |
| ZB-005 | S1 | Máy khách: sau cú vào bi 9, bi cái giật lùi rồi chạy lại "kỳ cục" | Video 202 B 12,8–18,5 s (anh) | ĐÃ SỬA ff8b028 (INFERRED cùng gốc ZB-004: đồng hồ phát lại tụt sau) | Chưa — 2 Simulator |
| ZB-002 | S2 | Máy khách: nút Break sáng suốt trận, cơ ngóc 7–10° ở cú thường | Video 202 A+B | ĐÃ SỬA ff8b028 | Chưa — 2 Simulator |
| ZB-001 | S2 | Máy tiếng Anh còn chữ Việt / câu lai ("ván mới sau seconds lát", "Tạo room", "KẾT THÚC VÁN", "Mã …") | Video 202 + ảnh IMG_7969 | ĐÃ SỬA ff8b028 | ✅ L10nSweepTests (1.416 câu, 0 lọt) + UI test viLeaks=0 |
| ZB-006 | S2 | Góc ngắm thấp: cán cơ thành khối đen lấp nửa màn, che bi cái | Video 202 A 2–11 s, 39–46 s (anh + ChatGPT #5) | ĐÃ SỬA ff8b028 (mắt camera ≥ đường cơ + 7°) | 🟡 test logic MatchCameraPolicy; thiếu ảnh chuẩn |
| ZB-011 | S2 | "Watching opponent · Ball in hand · tap Place ball" — bảo người đang xem bấm đặt bi | Video 202 A 50,4 s (ChatGPT #11) | ĐÃ SỬA ff8b028 | Chưa |
| ZB-018 | S2 | Camera bỏ mất phần kết cú (bi ra khỏi khung) rồi báo Ball in hand | Video 202 A 46,5–50,4 s (ChatGPT #8) | MỞ | — |
| ZB-020 | S2 | Menu con (Nearby play…) nền đen trơn, nút và chữ hệ thống, không theo bộ thiết kế Z | Anh 27/11 + ảnh IMG_7969 | MỞ — làm lại cả hệ menu con, bản riêng | — |
| ZB-023 | S2 | Luật 3 lỗi 9/10 bi: cần kiểm 2 ca (kết thúc ván hợp lệ / lỗi lần 3) trên cả 2 máy | Video 202 B (ChatGPT, UNVERIFIED là lỗi) | MỞ — kiểm chứng | — |
| ZB-024 | S2 | Camera ngắm bị băng che khi bi sát băng | Video 200 (anh 26/11) | ĐÃ SỬA 324e614 | ✅ AimRailSight 27 checks; chờ máy thật |
| ZB-033 | S2 | Giật hình khi chơi trên máy thật | Từ 0.37 | Chưa từng được xác nhận hết | Cần số đo MetricKit (đợt 2 kế hoạch 1.0) |
| ZB-007 | S3 | Cơ mờ thành hình nón xám trong suốt đè lên bi | Video 202 B 0–12 s | MỞ (cùng họ B6 "thân cơ chói khi ngắm sát", IPA 173, từ 25/11) | — |
| ZB-008 | S3 | Dải sáng mờ chạy ngang nửa dưới màn hình ở góc ngắm thấp | Video 202 B 1–4 s | MỞ — chưa rõ nguyên nhân (INFERRED: mặt băng gần) | — |
| ZB-009 | S3 | Thẻ kết thúc ván: pháo giấy đè tỉ số; "NGƯỜI 1" bị cắt mép khi trượt vào | Video 202 B 19–21 s | ĐÃ SỬA ff8b028 | Chưa ảnh chuẩn |
| ZB-010 | S3 | Dòng trạng thái "Your turn · Turn over" tự mâu thuẫn | Video 202 A 37–45 s (ChatGPT #10) | ĐÃ SỬA ff8b028 ("Cú của đối thủ · Hết lượt") | Chưa |
| ZB-012 | S3 | "Đang đồng bộ lượt…" hiện lúc bi đang lăn, đọc như chờ mạng | Video 202 A 12–16 s | ĐÃ SỬA ff8b028 ("Chờ bi dừng…") | Chưa |
| ZB-013 | S3 | Cảnh báo 2 lỗi: sai câu ("more foul loses the game"), dòng dưới bị cắt | Video 202 B 0–4 s | 🟡 câu đã sửa ff8b028; chữ cắt còn MỞ | — |
| ZB-014 | S3 | Tiếng đầu cơ đi trước hình chạm ~0,1 s | Video 202 (ChatGPT #3), UNVERIFIED (clip 30 khung/s) | MỞ — cần đo | — |
| ZB-015 | S3 | Nút Jump che bi ở góc Overview | Video 202 A 17,7–30 s | MỞ | — |
| ZB-016 | S3 | Bảng ép phê đè hàng Play/Break/Jump | Video 202 A 44,5–45,1 s | MỞ | — |
| ZB-017 | S3 | Nút quá mờ khi ngắm, khó phân biệt khoá/dùng được | Video 202 A 2–11 s | MỞ | — |
| ZB-021 | S3 | Góc nâng cơ hiện hai giá trị (0° bảng cú đối thủ, 10° đồng hồ) | Video 202 A 23,1 s | MỞ — kiểm | — |
| ZB-025 | S3 | Phím hiện trên nền đen trước intro | Video 200 | ĐÃ SỬA 324e614 | Ảnh Simulator; chờ máy thật |
| ZB-026 | S3 | Câu đặt bi bị cắt | Video 200 | ĐÃ SỬA 324e614 | Chờ máy thật |
| ZB-027 | S3 | Hai gợi ý cùng lúc (3 nút cơ + chú thích hướng dẫn) | Video 200 | ĐÃ SỬA 324e614 | Chờ máy thật |
| ZB-028 | S3 | Sảnh: chữ bị cắt "Vs computer · 6 leve", hàng dưới bị cắt | Video 200 | MỞ — sảnh mới | — |
| ZB-029 | S3 | Camera xem lại/quan sát bị băng che | Video 200 giây 46 | MỞ | — |
| ZB-031 | S3 | Thân cơ chói khi ngắm sát | IPA 173, ảnh IMG_7921, duyệt 25/11 (B6) | MỞ 2 ngày | — |
| ZB-035 | S3 | Test chập chờn trên CI: chạm intro 1.230 ms; bước chụp màn hình quá giờ | CI 45831722610 | MỞ — chạy lại trên Mac thì PASS | — |
| ZB-019 | S4 | Mốc kim cương khó thấy ở góc tổng quan | Video 202 (ChatGPT #9) | MỞ | — |
| ZB-022 | S4 | Nhãn "B" và "123" không tự giải thích cho người mới | ChatGPT | MỞ | — |
| ZB-030 | S4 | Intro: khung hình letterbox và tiếng chưa xem trên máy | 26/11 | Chờ máy thật | — |
| ZB-032 | S4 | Ảnh tường: làm lại bằng AI, đổi chữ/logo Zokervie (B7) | Duyệt 25/11 | MỞ (việc đã duyệt) | — |
| ZB-034 | — | Cú phá vào ít bi hơn số giải (8/10 bi); lỗ hơi chật, bi nhanh sát băng chật hơn thật 25–50 % | Đo 26/11 (DO-CU-PHA-VA-HE-SO) | MỞ — thuộc vật lý 0.60, sau công tắc | Bench C++ (chạy tay) |

## Đã đóng
(chưa có — đóng khi anh ghi "Đạt" trên máy thật)
