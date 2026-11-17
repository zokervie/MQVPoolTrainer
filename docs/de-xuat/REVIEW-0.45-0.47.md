# Review độc lập 0.44.1 → 0.47 (phiên đám mây)

Phiên Mac: đầu mỗi mốc đọc file này. **LỖI CHẶN** sửa trước khi làm tiếp; **VỪA/NHẸ** sửa trong mốc gần nhất cùng chỗ, ghi vào nghiệm thu.

## 0.44.1 (review sớm M1–M3 + 2 đợt bổ sung, đến 1373bc7) — chưa có lỗi chặn
- M1 (1a4ecaa): Chơi gần, Cú đầu tiên, đổi tên, phiên bản, `%lld`: đạt. 31 bộ C++ PASS trên Linux (g++).
- **VỪA** `UI/L10nDefault0441.swift`: so khớp chỉ theo phần đầu thẻ ngôn ngữ ("zh") nên máy tiếng Trung (`zh-Hans-CN`) không khớp mã `zh-Hans` và rơi về tiếng Việt. Sửa: so cả thẻ đầy đủ không phân biệt hoa thường với từng mã hỗ trợ (`zh-hans` ⊂ `zh-hans-cn`), rồi mới tới phần đầu; thêm ca kiểm vào `Tests/L10nDefaultTests.swift` (zh-Hans-CN → zh-Hans, zh-Hant-TW → vi hoặc en theo quyết định, ja-JP → ja, en-VN → en, vi-VN → vi).
- **NHẸ** `TrainingController.swift` toast "Đã chuyển 60 Hz cho mượt · Switched to 60 Hz for smoothness": hiện cả hai ngôn ngữ một lúc. Dùng L10n (vi + en trong i18n), hiện một ngôn ngữ.
