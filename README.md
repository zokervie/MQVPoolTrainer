# Zoker Pool Trainer (iOS) — bản 0.2

App bida 3D trên iPhone để **luyện mắt, tư duy và khả năng dự đoán đường bi**, áp dụng ra bàn thật. Không tuyên bố luyện động tác ra cơ.

> **Trạng thái:** toàn bộ code Swift **chưa từng được biên dịch hay chạy test**. Nhiệm vụ đầu tiên là R0.1 trong `PROGRESS.md`.

## Những gì đã chốt
- **Vật lý:** tự viết, từ phương trình đã công bố; một bộ giải theo sự kiện; tính trước cả cú. MVP gồm hướng bi mục tiêu, throw, băng theo tốc độ/xoáy, squirt, hình học lỗ.
- **Điều khiển (Natural Stroke):** chỉ màn hình ngang, không tia ngắm, không chữ.
  - Chưa khóa: vuốt = xoay hướng ngắm; bi effect mờ bên phải, chạm để phóng to chọn điểm chạm.
  - Chạm nhanh vùng ẩn góc dưới trái = khóa, rung xác nhận, bi effect ẩn.
  - Đã khóa: vuốt bất kỳ đâu, kéo lùi rồi đẩy tới; điểm đặt ngón = vạch chạm bi; lực = tốc độ ngón tại vạch.
  - Vuốt lệch và ngắt cơ ảnh hưởng thật; không ngẫu nhiên; mọi cú được ghi để phát lại.
- **Shot Lab:** nhập trực tiếp hướng, điểm chạm, lực — để phân tích và bài tập quyết định, không phải chế độ luyện chính.
- **Luyện tập:** bài tập có mục tiêu cụ thể; số liệu chỉ hiện sau cú; sai số ngắm tính theo khoảng hướng đạt mục tiêu.
- **Kiểm chứng ba tầng:** toán học → đối chứng pooltool → bàn thật (video 240 fps, máng lăn, chia tập hiệu chỉnh/kiểm chứng, báo độ không chắc chắn của phép đo).
- **Đồ họa:** MVP chỉ làm những gì giúp ngắm (phối cảnh, mép bi sắc, 60 fps, bi cái có chấm, bóng tiếp xúc, kim cương); đồ họa đẹp sau Cổng 1.

## Cấu trúc
```
CLAUDE.md        Quy tắc cho Claude Code (đọc mỗi phiên)
UPGRADE.md       Quyết định, KPI, lộ trình — nguồn chính
REVIEW.md        Lập luận đằng sau các quyết định
PROGRESS.md      Danh sách nhiệm vụ + nhật ký kết quả thật
PROMPT.md        Prompt dán lặp lại mỗi phiên
docs/            01 vật lý · 02 điều khiển · 03 camera/đồ họa · 04 bài tập · 05 phản hồi · 06 tính năng · 07 kiểm chứng
Packages/
  PoolPhysics/   Chuyển động, va chạm, cú đánh, TableDefinition, CalibrationProfile, RenderMapping + test
  PoolInput/     Máy trạng thái, vùng khóa, phân tích cú vuốt, TouchRecording + test
  PoolDrills/    Bài tập JSON, thang lực + test
App/Sources/     Khung SwiftUI + RealityKit màn hình ngang
Drills/          3 bài tập mẫu
.github/workflows/swift-packages-tests.yml   CI chạy test cả 3 package trên macOS
project.yml      Cấu hình XcodeGen
```

## Bắt đầu
**Có Mac:** cài Xcode 16+, Claude Code, XcodeGen (`brew install xcodegen`) → giải nén → `git init` → mở Claude Code trong thư mục → dán prompt trong `PROMPT.md`.

**Không có Mac:** đẩy thư mục lên một repo GitHub → CI tự chạy test trên macOS (repo công khai: miễn phí; riêng tư: tính phí phút macOS) → xem log trong tab Actions.
