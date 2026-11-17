# Thử nhanh RealityKit (0.45 M4) — để quyết, không chuyển engine trong 0.45–0.47

Trạng thái: **NOT RUN** (17/11/2026). Nhánh rác `thu/realitykit` chưa dựng.

Lý do: từ 20:45 ngày 17/11, CoreSimulatorService trên Mac này không khởi động được Simulator (mọi máy ảo). Không có Simulator
thì không đo được ms/khung, và đề bài cấm đổi tiêu chí để cho qua. Ba giờ dành cho mốc này được dùng cho các mốc trước (giữ thứ tự).

Việc cần làm khi Simulator chạy lại (hoặc trên máy thật):
1. Nhánh `thu/realitykit` (không đẩy vào nhánh bản): `ARView(cameraMode: .nonAR)` hoặc `RealityView` (iOS 18), bàn 9 ft (hộp + nỉ
   PBR), 16 bi (`ModelEntity` cầu + vật liệu PBR có texture số), 1 đèn spot + IBL.
2. Phát lại cùng dữ liệu cú ghi sẵn (`frames` của một cú phá 9 bi trong SavedShot) bằng cách đặt `transform` mỗi khung.
3. Đo: ms/khung trên luồng chính (CADisplayLink), thời gian GPU (Metal System Trace nếu có), ở 60/120 Hz, Simulator + Mac (Designed for iPad).
4. Ghi: hơn/kém SceneKit ở mức khung, chất lượng hình (ảnh cạnh nhau), công sức chuyển (ước lượng theo số file Rendering/*).

Nhận định trước khi đo (chưa có số, KHÔNG dùng để quyết): SceneKit đã bị Apple đánh dấu deprecated (WWDC25) nhưng vẫn chạy trên iOS 26;
RealityKit có ECS và hiệu năng tốt hơn trên Apple Silicon, nhưng thiếu `SCNSceneRendererDelegate`-kiểu điều khiển từng khung,
shader modifier, và bộ hậu kỳ camera; chuyển sẽ đụng ~12 file Rendering + FramePacer.
