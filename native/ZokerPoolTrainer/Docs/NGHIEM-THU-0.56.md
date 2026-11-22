# NGHIỆM THU 0.56 "Cân lại hai cụm nút" (nhánh cho/native-0.53-phieu-lo, sau 0.54; không có 0.55 trong nhánh này)

Gộp `origin/cho/native-0.56-cuu-luc` (BLPowerBarRescue, BLChapterCleanSealNoHelp trong Mastery.h) không xung đột. Cảm giác bấm: chưa xác minh trên thiết bị. Một commit chung cho K1–K3 vì ba mục đụng cùng bố cục (không tách sạch được).

| Mục | Kết quả | Ghi chú |
|---|---|---|
| K1 cụm phải | PASS (UI test + ảnh) | Đặt bi vào đúng cỡ/kiểu Lùi cú · Camera ngắm · Bàn (biểu tượng + chữ nhỏ), đứng trên cùng cột; nút tròn lớn bỏ. Test: thứ tự trên→dưới, cùng cao/rộng. Id `PlaceBallButton` giữ nguyên. |
| K2 bỏ công tắc thanh lực | PASS (UI test) | Không còn nút bật/tắt ở mọi chế độ, cả "Kiểu ra cơ" trong Cài đặt; mặc định vuốt B, thiết lập cũ bị bỏ qua. Cứu nguy: khi bắt đầu bài trong chương, `BLPowerBarRescue(chương, lùi cú đã dùng, makePercent, số lượt chấm trượt liên tiếp)` = 1 thì hỏi MỘT lần "Dùng / Tự đánh tiếp"; Dùng: thanh lực hiện tới khi rời bài, lưu `chapterRescue` theo chương, dấu Tay sạch dùng `BLChapterCleanSealNoHelp`. Test (cờ QA: chương 2, 92 lùi cú, 3 lượt trượt): thẻ hiện, Dùng bật thanh lực và đếm 1; chương 1 không hỏi. `--power-bar-qa` (Debug) vẫn ép bật thanh để test cử chỉ thanh. Chưa test: "Tự đánh tiếp" không hỏi lại trong bài (có trong code: `rescueAsked`). |
| K3 cụm trái | PASS (C++ + UI test + ảnh) | D = đường kính bi ép phê; B vuông D×D cùng hàng và đáy; "Cơ chơi" ngay trên B, "Cơ phá" ngay trên bi ép phê, mỗi nút D rộng × 2/3 D cao, mép thẳng hàng, khe dọc = khe ngang (`BLHUDLayout`, test PresentationPolicyTests); cây cơ trên + chữ dưới, chữ thu tới tối thiểu 9 pt; nút chọn có viền vàng. |
| K4 ràng buộc | PASS một phần | Không đổi bố cục khi bi chạy (layout vẫn đi qua đường hoãn cũ; test G7 vẫn nằm trong bộ). Ảnh 3 máy không chồng nút. Chưa đo "không đè vùng nỉ hơn trước" bằng số: cụm trái cao hơn khoảng 8 pt trên iPhone. Chữ "Camera ngắm" vẫn tràn nhẹ khung 44 pt (có từ trước). |
| K5 ảnh | PASS | shots/native/0.56/hud-{Zoker_SE3 (iPhone SE 3rd gen), iPhone_17_Pro_Max, iPad_Pro_11-inch__M5_}-{before,after}.png (ảnh ngang đã dựng thẳng). |
