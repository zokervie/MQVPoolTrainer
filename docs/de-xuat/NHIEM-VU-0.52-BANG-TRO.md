# Giao việc 0.52 — bài băng, bài trô (cho phiên Mac)

Nhánh lõi: `origin/cho/native-0.52-bai-bang-tro` (dựa trên `cho/native-0.50-the-bi-core` @ 0daf1ba). Gộp SAU khi đã gộp 0.50.

## Đã có trong nhánh (phiên đám mây, test C++ qua trên Linux)
- `draw-zone`, `pos-draw`: bi cái gần lại 0,42 m, vùng lùi 0,30 m sau điểm chạm. Đo lại: 40 % / 41 % (trước 24 / 20).
- `bank1`, `bank2`, `bank3`: thế mới, bi cái thẳng sau bi mục tiêu 28–48 cm. Đo lại: 31 / 18 / 17 % (trước 3 / 2 / 2).
- `bank3` giờ là **bank 2 băng dài** (rails = 2). Chủ dự án duyệt 22/11.
- `Tests/DrawIdentityTests.cpp`, `Tests/CushionReferenceTests.cpp` (đã đăng ký CMake + Run-All-Checks).
- Mô hình băng mới `Config::cushionModel = 1` — MẶC ĐỊNH TẮT. Không bật, không thêm nút.

## Việc trên Mac
**B1. Gộp** `origin/cho/native-0.52-bai-bang-tro` vào nhánh đang làm (sau 0.50). Xung đột có thể có ở `DrillCatalogData.h`, `measured.json`: lấy bản của 0.52 rồi chạy `python3 Tools/drills/gen_catalog.py --check`.

**B2. Đổi chữ bài bank3** (id `bank3` giữ nguyên, tiến độ theo id nên không mất):
- Tiêu đề: `Bank 2 băng dài` — en: `Long 2-rail bank`
- Ghi chú: `Bi 1 chạm băng phải, sang băng trái rồi về lỗ giữa phải.` — en: `Ball 1 hits the right rail, crosses to the left rail and comes back into the right side pocket.`
- Chỗ cần sửa: tiêu đề/ghi chú của drill cũ `bank3` trong `Models.swift` (hoặc ghi đè trong `DrillCatalog049.swift` nếu dễ hơn), khoá trong `I18N_en.dataset/i18n.json`, `rails: 2`. Link video giữ.

**B3. Kiểm** `bash Tools/accept_local.sh`; mở chương Bank và chương Dừng – theo – lùi trên Simulator: thế bi khớp hình, sơ đồ bài vẽ đúng đường 2 băng.

Báo cáo: mỗi mục PASS / FAIL / NOT RUN. Phần cảm giác đánh: "chưa xác minh trên thiết bị".
