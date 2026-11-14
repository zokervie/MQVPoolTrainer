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

1. 🟢 **"Bàn nhà tôi" — người chơi tự hiệu chỉnh tốc độ nỉ/băng**
   - Vì sao: đối thủ đang đi theo hướng "luyện trên bàn thật"; cách rẻ nhất để app sát bàn của từng người là cho họ đo bàn mình: đánh bi từ băng đầu, đếm số lần chạm băng/thời gian lăn (bấm giờ trong app) → suy ra hệ số lăn và độ nảy băng, lưu thành hồ sơ bàn. Khác bộ "5 cú 240 fps" (hiệu chỉnh gốc của app); đây là hiệu chỉnh của người dùng, chặn trong khoảng an toàn đã test.
   - Công sức: vừa (màn đo 3 bước + test C++ ánh xạ số đo → hệ số). Bản: 0.41. Gói: Z-Lab Phân tích.
2. 🟢 **"Cú quyết định" — luyện dưới áp lực**
   - Vì sao: tâm lý thi đấu là chỗ người chơi phong trào hụt nhiều nhất; tập trong điều kiện có áp lực (đồng hồ cú 30 s + 1 lần gia hạn như giải chuyên nghiệp, tiếng khán giả nhỏ dần, "phải vào mới qua bài", mất chuỗi nếu trượt) chuyển sang bàn thật tốt hơn tập thả lỏng. Dùng lại bài mỗi ngày + đấu máy, chỉ thêm lớp luật và âm thanh (nguồn CC0/tự thu, không YouTube).
   - Công sức: nhỏ. Bản: 0.41. Gói: Z-Drill (bộ "Áp lực"), bản thử 1 bài miễn phí.
3. 🟢 **Live Activity + widget: "Đến lượt bạn" và chuỗi ngày**
   - Vì sao: khi đấu Wi‑Fi/online hay chờ bài mỗi ngày, Live Activity trên màn khoá/Dynamic Island (ActivityKit) báo tỉ số, lượt đánh, giờ bài mới mà không cần mở app; widget đếm chuỗi ngày giữ người chơi quay lại — rẻ hơn mọi quảng cáo. Không cần máy chủ cho chế độ Wi‑Fi cục bộ.
   - Công sức: vừa (widget extension + ActivityKit; push cho online để sau). Bản: 0.41 (widget), sau (push online). Gói: miễn phí (giữ chân), kiểu widget đẹp bán trong Z-Style.

Còn chờ anh: quay 5 cú 240 fps ở CLB · thu âm theo kịch bản 15 phút.

→ Anh duyệt cả 3 ngày 12/11/2026, kèm tối ưu giao diện · âm thanh · logo · intro. Danh sách việc: `docs/de-xuat/NHIEM-VU-0.41.md`.

### Đề xuất ngày 13/11/2026
Tình hình: nhánh `ci/native-0.41` — CI 133 đỏ (đầu dò âm thanh chỉ thấy 7 mẫu), CI 134 (đầu dò đếm 27 mẫu) đang chạy lúc viết. 0.40c ở nhánh chờ, chưa build. Chủ đề tìm hiểu: các app bida mới ra năm 2026 trên App Store — "Bricole" (luyện 3 băng, 8 hệ thống ngắm có tên, 64 bài, sao đồng/bạc/vàng, câu đố mỗi ngày có "đóng băng chuỗi", có tiếng Việt — ra 02/07/2026) ([Bricole – App Store](https://apps.apple.com/app/id6782375615), [mwm.ai](https://mwm.ai/apps/bricole/6782375615)) và "CueMetrics" (sổ luyện tập, đo tốc độ phá bằng micro điện thoại, AI coach) ([CueMetrics – App Store](https://apps.apple.com/pl/app/cuemetrics/id6761289108), [mwm.ai](https://mwm.ai/apps/cuemetrics/6761289108)). Lưu ý: đã có đối thủ 3 băng nói tiếng Việt → gói Carom của mình cần ra sớm hơn hoặc khác biệt bằng vật lý thật.

1. 🟡 **"Học hệ thống ngắm" — bài theo hệ thống có tên, chấm sao đồng/bạc/vàng**
   - Vì sao: người chơi phong trào học bằng "hệ thống" (độ dày ½–¼–¾, bi ma, hệ kim cương cho kick 1–2 băng, hệ 3 băng cho carom) chứ không học bằng góc độ. Bricole chứng minh mô hình này bán được. Mình hơn họ ở chỗ có lõi vật lý thật: bước 1 xem hệ thống trên chế độ phân tích (có đường), bước 2 đánh không đường, app chấm sai số so với hệ thống và cho biết khi nào hệ thống "nói dối" (do throw/xoáy/tốc độ — nối với "Vì sao trượt"). Sao đồng/bạc/vàng theo tỉ lệ vào trong 10 cú.
   - Công sức: vừa (dữ liệu bài + màn chấm sao; test C++ kiểm tra công thức kim cương khớp lõi vật lý trong sai số cho phép). Bản: sau 0.41 (0.42). Gói: Z-Drill "Hệ thống" (pool) + "Hệ 3 băng" (carom), 1 hệ miễn phí.
2. 🟡 **"Đo cú phá bằng micro" trên bàn thật → nối vào thang lực trong app**
   - Vì sao: CueMetrics đã có (Break Dojo). Vật lý đơn giản: micro bắt 2 tiếng va (đầu cơ chạm bi chủ, bi chủ chạm bi đầu dàn), khoảng cách đã biết (vạch phá → điểm đặt bi) ÷ thời gian = tốc độ km/h (chỉnh hãm lăn trên nỉ). Người chơi thấy "phá thật 28 km/h = mức lực 6/7 trong app", giúp thang lực 7 màu có nghĩa thực tế, và dữ liệu đưa vào bảng tiến bộ. Chạy trên máy, không máy chủ, không ghi âm lưu lại (chỉ phân tích, nói rõ quyền micro).
   - Công sức: vừa (AVAudioEngine bắt đỉnh âm + lọc ồn CLB; test C++ hàm thời gian → tốc độ với tín hiệu giả). Bản: sau (0.42), trước "Apple Watch đo nhịp ra cơ" vì không cần thêm thiết bị. Gói: Z-Lab Phân tích (bản thử 3 lần đo miễn phí).
3. 🟡 **"Đóng băng chuỗi" — giữ chuỗi ngày mà không ép tiền**
   - Vì sao: chuỗi ngày (đã duyệt) dễ làm người chơi bỏ app khi mất chuỗi dài vì một ngày bận; "đóng băng chuỗi" (Bricole, Duolingo dùng) giảm tỉ lệ bỏ. Cách làm lành mạnh: kiếm được 1 thẻ đóng băng mỗi 7 ngày liên tục (tối đa giữ 2), Z-Pro có thêm 2 thẻ/tháng; không bán lẻ thẻ (tránh cảm giác "trả tiền để khỏi mất") — phù hợp định hướng không quảng cáo ép.
   - Công sức: nhỏ (đếm ngày theo lịch máy + múi giờ, hiển thị trên widget chuỗi ngày đã duyệt). Bản: 0.41 (đi cùng widget chuỗi ngày). Gói: miễn phí; thêm thẻ trong Z-Pro.

Còn chờ anh: quay 5 cú 240 fps ở CLB · thu âm theo kịch bản 15 phút.

### Đề xuất ngày 14/11/2026
Tình hình: nhánh `ci/native-0.42` — CI 140 xanh (lần chạy thứ 3, commit `04fc26e` sửa chụp ảnh simctl); CI 141 chạy tay cùng commit: 2 cổng Linux xanh, job Mac bị huỷ (không phải lỗi mã). Chủ đề tìm hiểu: các app "sổ luyện tập" bida trên App Store 2026 — "Pool & Billiards Self-Trainer" (30 bài có sơ đồ, tự lên/xuống cấp theo ngưỡng đạt, giáo án dựng sẵn, buổi tập có hướng dẫn, ghi trận thật kèm thay đổi điểm xếp hạng; thuê bao Pro 8,99 USD/tháng – 49,99 USD/năm, chỉ mở rộng lịch sử quá 30 ngày) ([App Store](https://apps.apple.com/us/app/id6748546651)) và "Shot Lab: Billiards" (bài + chế độ sinh tồn, điểm kỹ năng, miễn phí kèm quảng cáo) ([App Store](https://apps.apple.com/app/id6759288094)). Cả hai chấm điểm bằng tay, không camera/AI. Công nghệ: Vision nhận dạng tư thế cơ thể trên máy ([Apple WWDC20 – Detect Body and Hand Pose with Vision](https://developer.apple.com/wwdc20/10653)).

1. 🟡 **"Giáo án 4 tuần tự điều chỉnh"**
   - Vì sao: hiện mình có bài mỗi ngày + bài theo cấp, nhưng chưa có "lộ trình" — người chơi phong trào không biết hôm nay nên tập gì. Đối thủ bán được thuê bao chủ yếu nhờ giáo án + tự lên/xuống cấp. Mình làm tốt hơn vì app tự chấm (không phải bấm tay): mỗi buổi 20–30 phút gồm khởi động (đường thẳng/dừng bi) → bài trọng tâm tuần (cắt mỏng, kéo/đẩy, kick) → 1 bài "Cú quyết định"; bài nâng cấp khi đạt ≥ 70 % hai buổi liên tiếp, hạ cấp khi < 40 %. 3 giáo án sẵn: Người mới · Vào lỗ chắc · Chạy bi 9 Ball.
   - Công sức: vừa (dữ liệu giáo án JSON + bộ điều chỉnh cấp; test C++/XCTest cho luật lên/xuống cấp). Bản: 0.42. Gói: 1 giáo án miễn phí; còn lại trong Z-Drill (mỗi giáo án một gói) hoặc Z-Pro.
2. 🟡 **"Sổ trận thật" + điểm Z-Rating**
   - Vì sao: người chơi muốn biết luyện trong app có giúp thắng ngoài CLB không. Cho ghi nhanh trận thật (luật, race, tỉ số, đối thủ tự đặt tên + mức tự khai) → tính Z-Rating kiểu Elo trên máy, vẽ cạnh biểu đồ kết quả bài tập ("tuần tập cắt mỏng 80 % → rating +12"). Không dùng tên/hệ điểm thương mại thật (đặt tên Z-Rating). Dữ liệu chỉ trên máy/iCloud, không máy chủ.
   - Công sức: nhỏ–vừa (màn nhập 1 trang ≤ 3 chạm, công thức Elo có test, biểu đồ Swift Charts). Bản: 0.42. Gói: ghi trận miễn phí; biểu đồ tương quan luyện ↔ kết quả + lịch sử dài trong Z-Stats & Exam.
3. 🟡 **"Soi tư thế ra cơ" bằng camera iPhone (Vision body pose)**
   - Vì sao: lỗi gốc của người chơi phong trào là cơ không thẳng — khuỷu tay rơi, vai/đầu nhấc khi ra cơ — và hai đối thủ trên đều không có. Đặt iPhone trên giá phía sau hoặc bên hông, Vision (chạy trên máy, không gửi video đi) bắt vai–khuỷu–cổ tay–đầu mỗi khung, đo: độ rơi khuỷu (cm), dao động đầu, nhịp lùi/đẩy (tempo), độ dừng sau cú. Bổ sung cho "Apple Watch đo nhịp ra cơ" (đã duyệt, cần thêm thiết bị) — đây chỉ cần điện thoại. Nối với "Giữ mắt": cho điểm "giữ yên" trên bàn thật.
   - Công sức: lớn (thu video + Vision 30–60 fps, lọc nhiễu khớp, hiệu chỉnh tỉ lệ cm theo chiều dài cơ; test với video mẫu tự quay — không dùng video YouTube). Bản: sau (sau "Đo cú phá bằng micro"). Gói: Z-Cam (bản thử 3 lần soi miễn phí).

Còn chờ anh: quay 5 cú 240 fps ở CLB · thử xuất highlight khi chơi Wi‑Fi.
