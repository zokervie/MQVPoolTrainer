# Pool Trainer iOS — Bộ khởi tạo dự án

Game bida 3D trên iPhone để luyện tập áp dụng ra bàn thật.

## Tóm tắt định hướng
- **Mục tiêu:** luyện tập, không phải giải trí. Vật lý sát thực tế và lặp lại được là ưu tiên số một.
- **Vật lý:** tự viết (không dùng engine có sẵn), dựa trên phương trình đã công bố (Alciatore, Mathavan, Marlow). Quy tắc hình học trong bài tập/video (90°, 30°, kim cương) dùng làm bài kiểm tra. Mô phỏng theo sự kiện, tính trước cả cú đánh.
- **Cách chơi:** chỉ màn hình ngang, không tia ngắm, không chữ.
  - Vuốt khi chưa khóa = xoay hướng ngắm.
  - Bi effect mờ bên phải: chạm để phóng to và chọn điểm chạm, buông để thu nhỏ.
  - Chạm nhanh vùng ẩn góc dưới trái (~1/8 màn hình) = khóa, có rung xác nhận; bi effect ẩn đi.
  - Đã khóa: vuốt bất kỳ đâu, kéo lùi rồi đẩy tới; điểm đặt ngón = vạch chạm bi; lực = tốc độ ngón tại vạch. Vuốt lệch hay ngắt cơ đều ảnh hưởng thật, không có ngẫu nhiên.
- **Luyện tập:** bài tập JSON theo tọa độ kim cương, đánh dấu như nhãn dán trên nỉ, thang lực 1–7, số liệu chỉ hiện sau cú đánh.
- **Đồ họa & hiệu năng:** RealityKit, ánh sáng dựng sẵn + reflection probe, chỉ bi/cơ/bóng tính thời gian thực, mức chất lượng theo máy, 60 fps, tự hạ chất lượng khi máy nóng.
- **Tính năng mở rộng:** xem `docs/06-features.md`.

## Cấu trúc
```
CLAUDE.md          Quy tắc cho Claude Code (đọc mỗi phiên, giữ ngắn)
PROGRESS.md        Danh sách việc, Claude tự cập nhật
PROMPT.md          Prompt dán lặp lại mỗi phiên
docs/              Đặc tả chi tiết theo chủ đề
Packages/
  PoolPhysics/     Lõi vật lý Swift thuần + test
  PoolInput/       Ngắm, khóa, phân tích cú vuốt + test
  PoolDrills/      Bài tập JSON + test
App/Sources/       App SwiftUI + RealityKit (khung)
Drills/            Bài tập mẫu
project.yml        Cấu hình XcodeGen
```

## Bắt đầu (trên máy Mac)
1. Cài Xcode 16+, Claude Code, XcodeGen (`brew install xcodegen`).
2. Giải nén thư mục, `cd pool-trainer`, `git init`.
3. Mở Claude Code trong thư mục, dán prompt trong `PROMPT.md`.
4. Lặp lại: `/clear` → dán prompt → kiểm tra kết quả.

Code khởi tạo được viết sẵn nhưng **chưa qua biên dịch**; nhiệm vụ đầu tiên trong `PROGRESS.md` là chạy test và sửa lỗi nếu có.
