# Review độc lập 0.44.1 → 0.47 (phiên đám mây)

Phiên Mac: đầu mỗi mốc đọc file này. **LỖI CHẶN** sửa trước khi làm tiếp; **VỪA/NHẸ** sửa trong mốc gần nhất cùng chỗ, ghi vào nghiệm thu.

## 0.44.1 (review sớm M1–M3 + 2 đợt bổ sung, đến 1373bc7) — chưa có lỗi chặn
- M1 (1a4ecaa): Chơi gần, Cú đầu tiên, đổi tên, phiên bản, `%lld`: đạt. 31 bộ C++ PASS trên Linux (g++).
- **VỪA** `UI/L10nDefault0441.swift`: so khớp chỉ theo phần đầu thẻ ngôn ngữ ("zh") nên máy tiếng Trung (`zh-Hans-CN`) không khớp mã `zh-Hans` và rơi về tiếng Việt. Sửa: so cả thẻ đầy đủ không phân biệt hoa thường với từng mã hỗ trợ (`zh-hans` ⊂ `zh-hans-cn`), rồi mới tới phần đầu; thêm ca kiểm vào `Tests/L10nDefaultTests.swift` (zh-Hans-CN → zh-Hans, zh-Hant-TW → vi hoặc en theo quyết định, ja-JP → ja, en-VN → en, vi-VN → vi).
- **NHẸ** `TrainingController.swift` toast "Đã chuyển 60 Hz cho mượt · Switched to 60 Hz for smoothness": hiện cả hai ngôn ngữ một lúc. Dùng L10n (vi + en trong i18n), hiện một ngôn ngữ.

## 0.45 (đến b49c8e3, 17/11 23:50)
- **LỖI CHẶN — thiếu 0.45 M5** (PlayerStore + mã bài ổn định, AppFlow, Prefs, số liệu cục bộ, cờ QA). Mốc này được thêm vào nhiệm vụ lúc ~21:00 (commit 4b43e61); `NGHIEM-THU-0.45.md` không nhắc tới. 0.47 (Bài hôm nay, chuỗi, kỷ lục, thi chương) không làm đúng được nếu thiếu. **Làm 0.45 M5 trên `cho/native-0.45` trước khi sang 0.46** (hoặc ngay đầu `cho/native-0.46` nếu đã tạo), ghi vào NGHIEM-THU-0.45.
- **VỪA** Simulator vẫn treo từ ~20:45 nên ảnh, UI test, perf QA của cả 0.44.1 và 0.45 là NOT RUN. Đề nghị chủ dự án khởi động lại Mac; sau đó chạy lại `accept_local.sh` cho 0.45 trước khi đẩy 0.46.
- **NHẸ** Ghi chú của nghiệm thu: vai trong `.claude/agents/` chỉ nạp khi `claude` mở tại gốc repo. Mở lại phiên tại `~/Developer/ZokerPool/MQVPoolTrainer` (gốc), không ở `native/ZokerPoolTrainer`.
- Đã xem: M0, M1 (một phần, có lý do: SCNView vẫn vẽ tần số cố định), M2 (3.342 → 598 dòng, 6 file ≤ 900), M3 (ZDesign, i18n 646/646), M4 NOT RUN có kế hoạch. Không thấy lỗi chặn khác ở mức đọc nghiệm thu; review mã chi tiết M2 khi có CI.
