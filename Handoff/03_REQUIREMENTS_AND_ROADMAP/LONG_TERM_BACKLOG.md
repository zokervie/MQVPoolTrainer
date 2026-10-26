# BACKLOG TOÀN CẢNH — NGOÀI 0.13/0.14

Danh mục này gom mục tiêu lâu dài đã thảo luận; **không ghi là đã hoàn thành** nếu không có test & ảnh QA.

## Đồ họa & thiết bị

- Ưu tiên bàn, bi, băng, lỗ, cơ có kết cấu chân thực, PBR, bóng đổ mềm, vân nỉ không sọc/moire và nhìn gần không vỡ.
- Mẫu bàn/cơ tham khảo thương hiệu: giữ số lượng model đang có, kiểm tra chất lượng mesh/texture/UV đúng vật lý, không chỉ đổi màu/nhãn. Thương hiệu phải tránh mạo nhận sản phẩm được hãng chứng nhận.
- Lực/đường lăn/spin/rotating stripe/number/spot, bi trắng và bi mục tiêu rõ, bóng phải xoay thật theo trạng thái physical quaternion.
- Bàn có chân, băng có mép/nỉ, miệng lỗ và bóng rơi có độ sâu, đường đi đúng native solver.
- SceneKit nên được đo GPU/frame pacing thực tế trước khi quyết định chuyển sang Metal/RealityKit; không thay engine một cách cảm tính.

## Vật lý & luyện tập

- Coupled ball-ball/ball-rail, continuous impacts, throw/gearing, multi-rail side spin, elevation, jump/massé, squirt/swerve, cue-table collision, rack/legal fouls.
- Calibration từ bàn thật với profile bàn/băng/nỉ và video có chuẩn kích thước; benchmark nhiều tốc độ/góc/xoáy; báo sai số thống kê theo miền.
- Thư viện bài tập bank/kick 1–4 băng, diamond, plus, midpoint, control/position, break, safety/runout, progressive exams, replay/record/export.
- Lịch luyện, lịch sử tỷ lệ thành công, leaderboard online **sau** khi có cơ chế scoring công bằng.

## Trải nghiệm & sản phẩm thương mại

- One-handed adaptive HUD trên nhiều thiết bị, left-handed option, preset controls, camera lock/spectate, haptic tùy chỉnh.
- Local practice offline không yêu cầu server/đăng nhập. Online 2 thiết bị thì có số ván, đổi lượt, luật, reconnect, chặn gian lận cơ bản.
- Quản trị tài nguyên thương hiệu, audio, video, mã nguồn và license trước khi đưa lên App Store.
- Chi phí thấp: local physics, backend theo lượng dùng, không hardcode token, giới hạn request/room/retention.
