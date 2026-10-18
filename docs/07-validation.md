# Kiểm chứng

Ba tầng tách biệt, báo cáo riêng. KPI và ngưỡng: UPGRADE.md mục 3–4.

## Tầng 1 — Toán học
`swift test` trên macOS (CI: `.github/workflows/swift-packages-tests.yml`). Chứng minh code đúng công thức, không hơn.

## Tầng 2 — Đối chứng pooltool
- `Tools/validation/` (R1.2): file điều kiện ban đầu chung → chạy PoolPhysics và pooltool → so quỹ đạo.
- Ghi phiên bản/commit pooltool. Giấy phép Apache-2.0 (giữ thông báo bản quyền và NOTICE nếu tham khảo mã).
- Khác biệt vượt ngưỡng phải có giải thích và test tái hiện.
- Khớp pooltool **không** chứng minh đúng với bàn thật.

## Tầng 3 — Bàn thật
**Dụng cụ:** iPhone 240 fps trên chân máy cao, máng lăn tự chế, bi cái có chấm, bàn cờ in, thước.

**Trước khi đo:**
1. Hiệu chỉnh camera (méo ống kính) bằng bàn cờ, đúng chế độ quay sẽ dùng.
2. Phép chiếu phối cảnh trên mặt phẳng tâm bi (z = R), không phải mặt nỉ.
3. Đo độ không chắc chắn hệ đo: bi đứng yên, khoảng cách đã biết, hướng đã biết → giá trị k = 2 cho góc và vị trí.
4. Chỉ tuyên bố đạt ngưỡng khi độ không chắc chắn ≤ 1/3 ngưỡng (0,5° cần ≤ ~0,17°).

**Nguyên tắc:** đo điều kiện ban đầu từ video và đưa vào mô phỏng, không cố kiểm soát lực tay.

**Thí nghiệm:**
| # | Cách làm | Hiệu chỉnh |
|---|---|---|
| 1 | Máng lăn, 3 độ cao, bi lăn tự do | Cản lăn |
| 2 | Cú stun, đo quãng trượt | Ma sát trượt |
| 3 | Máng lăn vào băng, 3 góc | Phục hồi, ma sát băng |
| 4 | Bi lăn chạm bi mục tiêu, nhiều góc cắt | Ma sát bi–bi (throw) |
| 5 | Cú có xoáy ngang, đánh tay | Chỉ kiểm chứng |

**Dữ liệu:** ≥ 20 lần mỗi thí nghiệm; chia ngẫu nhiên 50/50 hiệu chỉnh/kiểm chứng **trước khi** xem kết quả; chỉ chỉnh tham số riêng của bàn; ghi điều kiện nỉ, bi, nhiệt độ, độ ẩm; kết quả lưu thành `CalibrationProfile` với `Provenance.measured`.

## Chuyển giao kỹ năng (R6)
Bộ kiểm tra bàn thật chuẩn ~20 phút; kiểm tra 2 lần trước, 14 ngày dùng app, kiểm tra lại; 8–12 người; báo effect size và khoảng tin cậy, không tuyên bố hiệu quả. Chi tiết: REVIEW.md C6.

## Công cụ (bản 0.3)
- `Tools/validation/pooltool_compare.py`: `make` (cần pooltool) tạo kịch bản và kết quả pooltool; `report` so với `poolsim`. Lấy trạng thái bi **ngay sau cú đánh** từ pooltool rồi đưa vào PoolPhysics, nên so sánh không phụ thuộc mô hình cơ–bi của hai bên. Chạy trong job CI `validation` (macOS).
- `Tools/validation/measure.py`: ma trận chiếu từ ≥ 6 điểm 3D (kim cương trên khung + góc lỗ trên nỉ), phép chiếu mặt phẳng tâm bi z = R, bám bi theo màu, vận tốc đầu, độ không chắc chắn k = 2, quy tắc tuyên bố 1/3, chia 50/50 theo seed, khớp cản lăn và phục hồi băng, xuất `CalibrationProfile` JSON cho app. Hiệu chỉnh méo ống kính cần OpenCV (`camera_calibration_opencv`).
- Kiểm thử: `python -m unittest discover -s Tools/validation` (dữ liệu tổng hợp).
