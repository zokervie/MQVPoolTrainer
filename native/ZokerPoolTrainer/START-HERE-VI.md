# Zoker Pool Trainer 0.11 — Native Jump / Massé candidate

Ngày 21/10/2026. Source 0.10 được cập nhật để thử trên bàn thật trong app,
không chỉ trong ZUPE Lab. Đọc Docs/RELEASE-0.11.md và log workflow trước khi cài.

## Thử tính năng

Menu → Cơ 3D · Jump / Massé → bật bộ giải 3D thử nghiệm.
Chọn Playing / Jump / Break để đổi cả mesh 3D và các tham số cơ minh hoạ.
Có preview xoay và thanh góc nâng cơ 0–80°. Jump: 35–60°, điểm gần tâm.
Massé: Playing, 55–75°, ép phê ngang, lực nhẹ; quỹ đạo có thể chỉ hop tùy thông số.
Bóng bi thay đổi theo độ cao; replay và dự báo dùng cùng dữ liệu mô phỏng.

Giữ B để khóa hướng, ngón còn lại kéo xuống rồi đẩy qua mặt phẳng chạm;
buông B hoặc nhấc ngón không tự đánh. Có vi chỉnh mờ ở giữa đáy.
Tắt 3D để về bộ giải 0.9; băng phụ thuộc lực giữ tùy chọn của bản 0.10.

## Build

Mở ZokerPoolTrainer.xcodeproj bằng Xcode; scheme ZokerPoolTrainer.
`bash Build-ZUPE-on-Mac.command` compile Simulator rồi xuất IPA chưa ký.
`bash Run-All-Checks.command` chạy regression (Node/Python/C++).
CI ở .github/workflows/xcode-build.yml; bản source đầy đủ này đã có ảnh
vật liệu và mesh. Bản source trên GitHub bỏ các byte lớn, dùng
Tools/prepare_ci_assets.py tái tạo bằng chính mã gốc để build.

Bản nghiên cứu: chưa hiệu chuẩn thực nghiệm. Không gọi đây là bộ giải jump/massé
chính xác hoặc bản Remastered Complete. Tình trạng build thật xem log đính kèm.
