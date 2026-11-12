# Sổ đề xuất ZokerPoolTrainer

Nơi gom MỌI đề xuất/phát kiến (đã duyệt, chờ duyệt, đã làm). Nhánh `plan/de-xuat-zoker`. Mỗi ngày em bổ sung mục "Đề xuất ngày …" ở cuối.
Trạng thái: ✅ đã làm · 🟢 anh đã duyệt (chưa làm) · 🟡 chờ anh duyệt.

## 1. Đã làm trong 0.39 (chờ nghiệm thu trên máy)
- ✅ Gốc rễ bi giật: đồng bộ khung hình (SceneKit tự đặt bi theo lưới vsync, ngoại suy 1 khung khi tick trễ); không đổi chất lượng/nhiệt giữa cú (đổi shader = khựng 0,1–0,3 s); biên dịch shader sẵn khi mở app.
- ✅ Bóng: chỉ bi đổ bóng (kiểu 0.19: bản đồ 2048, bán kính 4, 8 mẫu) + lõi bóng tròn; gậy không đổ bóng bản đồ (hết răng cưa); gậy mờ khi che hướng ngắm/bi mục tiêu.
- ✅ Sợi nỉ 0,6 mm có độ dày/sáng/xoắn riêng; típ vòm 4,5 mm; nỉ cũ chấm li ti ở vùng break/xếp bi; bi cũ đục, vết lơ; sàn hết sọc; bỏ viền kim loại.
- ✅ Wi‑Fi/online: làm mới phím khi đổi lượt + đối chiếu quyền đánh 2 lần/giây; bảng điểm kiểu TV.
- ✅ Xem lại: cảnh đầu thấp hơn (26°); Tuỳ chỉnh 5 thẻ (Hình ảnh: Bi·Bàn·Đèn / Ngắm / Phím / Vật lý / Máy·Âm thanh); sảnh gọn.

## 2. Bản 0.40 — 🟢 anh đã chấp thuận
**Bàn**: kích thước chuẩn WPA + họ kiểu dáng phổ biến 2026, trang trí riêng, tên Z- (không chép 100% thương hiệu — rủi ro kiểu dáng công nghiệp khi bán app).

**Âm thanh** (không lấy YouTube — bản quyền + chất lượng nén):
- Nguồn: anh tự thu ở CLB (em soạn kịch bản 15 phút) · Freesound CC0/CC-BY (~40 mẫu) · Sonniss GDC (dùng thương mại).
- 3 mức lực × 3–4 biến thể/loại, âm lượng theo vận tốc va chạm thật, cao độ ±3 %.
- Tiếng bi lăn liên tục theo tốc độ; lỗ theo loại bàn (lưới/máng); break, nhảy chạm đá, massé, trượt típ.
- Bi văng khỏi bàn: đập mép gỗ → rơi → nảy 3–5 lần trên sàn theo vật lý, tiếng theo vật liệu sàn (thảm/gỗ/đá). Cần vật lý mới, test C++ trước.
- Không gian âm: trái/phải theo vị trí, nhỏ dần theo khoảng cách camera, độ vang theo phòng, giới hạn số tiếng.

**Đấu với máy 6 cấp** (anh dặn 11/11 18:29): Beginner · Amateur · Quarter Pro · Semi Pro · Pro · AI.
- Máy thử 50–200 cú ứng viên trên lõi vật lý tất định, chấm: vào lỗ + vị trí bi chủ + an toàn.
- Cấp = tay (sai số góc ±1,5° → ±0,08°, kèm lực/xoáy) + đầu (tính 0–3 bi, phòng thủ, kick 1–2 băng, tách cụm).
- "Tính người": nghĩ lâu cú khó, cấp thấp chọn sai cú; tự gợi ý lên cấp khi thắng 3 ván liên tiếp.
- Chọn luật 8/9/10 Ball, 15 Rotation, race, ai break.
- Test C++ trước: tỉ lệ vào theo cấp trong khoảng mục tiêu, không cú phạm luật, cấp cao thắng cấp thấp. Chạy luồng riêng.

**Giao diện** (anh dặn): Sảnh 3 thẻ —
- Luyện tập: tự do · bài mỗi ngày · bài theo cấp · Giữ mắt · kick/bank.
- Thi đấu: đấu máy · hai người một máy · Wi‑Fi · online · bóng ma.
- Hồ sơ: tiến bộ/thống kê · Z-Exam · cú đã lưu/highlight · tài khoản.
- Chân trang: Tuỳ chỉnh · Hướng dẫn. Menu trong trận 4 mục. Mọi thứ ≤ 2 chạm, mỗi thứ một chỗ.

**Từ nghiên cứu (lộ trình)**: khung IAP (cờ tính năng + StoreKit 2) · bài mỗi ngày + chuỗi ngày · "Giữ mắt" (quiet eye: không đường dẫn, chỉ nhả cú khi giữ cơ yên đủ lâu) · "Vì sao trượt" (phân tích: lệch bao nhiêu độ do throw/squirt) · Z-Exam v1.

**Kỹ thuật & chất lượng**: vật lý chạy luồng riêng, bỏ cấp phát mỗi khung · CI đo tỉ lệ khung trễ · bộ so 20 cú mẫu với video thật · "phòng chuẩn" chụp ảnh so trước/sau mỗi bản · mẫu đèn "Thi đấu" 520 lux · hướng dẫn tương tác 3 bước lần đầu · bảng tiến bộ hằng tuần · thử thách hằng ngày + bảng xếp hạng Game Center.

**Chờ anh**: quay 5 cú chuẩn 240 fps ở CLB (hiệu chỉnh hệ số) · thu âm theo kịch bản · thử xuất highlight khi chơi Wi‑Fi.

## 3. Bản 0.41 và sau — 🟢 (theo báo cáo nghiên cứu)
- 0.41: thách đấu bóng ma + Game Center Challenges/Activities · giải tuần theo trình độ · thống kê tán xạ/bản đồ nhiệt · chia sẻ thế bi bằng link/QR · rung + âm đồng bộ va chạm · AI coach trên máy (Foundation Models, có bộ câu soạn sẵn dự phòng tiếng Việt) · mở bán.
- Sau: chụp ảnh bàn thật → dựng thế bi · Apple Watch đo nhịp ra cơ (800 Hz) · SharePlay · App Clip · lớp ngăn cách để chuyển RealityKit · AR trên bàn thật (cuối cùng).

## 4. Gói bán trong app (đề xuất, USD)
Miễn phí (vòng luyện chính, không quảng cáo ép) · Z-Lab Phân tích 4,99–7,99 · Z-Drill mỗi gói 2,99–4,99 (có Carom 3 băng) · Z-Stats & Exam 4,99–9,99 · Z-Coach AI 2,99–4,99 · Z-Cam 4,99–9,99 · Z-Style 0,99–1,99/món · Z-Pro trọn đời 39,99–59,99. Thuê bao chỉ cho phần có chi phí máy chủ.

## 5. Nguồn
- `nghien-cuu-tinh-nang-2026.md` (báo cáo tổng hợp) + ghi chú: `competitors.md`, `apple_tech.md`, `training_engagement.md`.

## Đề xuất hằng ngày
(Mỗi ngày em thêm 3 ý mới ở đây, kèm lý do và mức ưu tiên.)

### Đề xuất ngày 12/11/2026
Tình hình: CI `ci/native-0.40` xanh (11/11, đấu với máy 6 cấp + OpponentTests). Chủ đề tìm hiểu: đối thủ app luyện bida dùng AI/camera trên bàn thật ([DrillRoom – AZBilliards](https://azbilliards.com/?p=197467), [DrillRoom – App Store](https://apps.apple.com/ru/app/id1539827505)) và các cách bán mới của App Store 2026 ([Apple Newsroom 06/2026](https://www.apple.com/ie/newsroom/2026/06/apple-expands-app-store-capabilities-to-help-developers-grow-and-reach-new-users/)).

1. 🟡 **"Bàn nhà tôi" — người chơi tự hiệu chỉnh tốc độ nỉ/băng**
   - Vì sao: đối thủ đang đi theo hướng "luyện trên bàn thật"; cách rẻ nhất để app sát bàn của từng người là cho họ đo bàn mình: đánh bi từ băng đầu, đếm số lần chạm băng/thời gian lăn (bấm giờ trong app) → suy ra hệ số lăn và độ nảy băng, lưu thành hồ sơ bàn. Khác bộ "5 cú 240 fps" (hiệu chỉnh gốc của app); đây là hiệu chỉnh của người dùng, chặn trong khoảng an toàn đã test.
   - Công sức: vừa (màn đo 3 bước + test C++ ánh xạ số đo → hệ số). Bản: 0.41. Gói: Z-Lab Phân tích.
2. 🟡 **"Cú quyết định" — luyện dưới áp lực**
   - Vì sao: tâm lý thi đấu là chỗ người chơi phong trào hụt nhiều nhất; tập trong điều kiện có áp lực (đồng hồ cú 30 s + 1 lần gia hạn như giải chuyên nghiệp, tiếng khán giả nhỏ dần, "phải vào mới qua bài", mất chuỗi nếu trượt) chuyển sang bàn thật tốt hơn tập thả lỏng. Dùng lại bài mỗi ngày + đấu máy, chỉ thêm lớp luật và âm thanh (nguồn CC0/tự thu, không YouTube).
   - Công sức: nhỏ. Bản: 0.41. Gói: Z-Drill (bộ "Áp lực"), bản thử 1 bài miễn phí.
3. 🟡 **Live Activity + widget: "Đến lượt bạn" và chuỗi ngày**
   - Vì sao: khi đấu Wi‑Fi/online hay chờ bài mỗi ngày, Live Activity trên màn khoá/Dynamic Island (ActivityKit) báo tỉ số, lượt đánh, giờ bài mới mà không cần mở app; widget đếm chuỗi ngày giữ người chơi quay lại — rẻ hơn mọi quảng cáo. Không cần máy chủ cho chế độ Wi‑Fi cục bộ.
   - Công sức: vừa (widget extension + ActivityKit; push cho online để sau). Bản: 0.41 (widget), sau (push online). Gói: miễn phí (giữ chân), kiểu widget đẹp bán trong Z-Style.

Còn chờ anh: quay 5 cú 240 fps ở CLB · thu âm theo kịch bản 15 phút.
