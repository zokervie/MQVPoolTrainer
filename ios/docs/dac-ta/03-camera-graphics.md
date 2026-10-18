# Góc nhìn, đồ họa, hiệu năng

## Camera
- Góc nhìn thứ nhất sau cơ, cao hơn mặt bàn 15–30 cm (chỉnh được).
- FOV dọc ~40–45°, tự tính theo tỉ lệ màn hình (iPhone ~19,5:9, iPad vuông hơn) để cảm giác khoảng cách nhất quán, không méo mép.
- Hai chế độ: **đọc thế bi** (đi vòng quanh bàn, nhìn từ trên) và **cúi đánh**.
- Tùy chọn gyroscope: nghiêng máy xoay nhẹ góc nhìn như cử động đầu.
- Tín hiệu chiều sâu: bóng đổ mềm dưới bi, phản chiếu đèn trên bi, kim cương trên băng rõ và đúng vị trí.

## Đồ họa (MVP: đơn giản; sau MVP: nâng dần)
- PBR: bi clearcoat bóng, nỉ có vân vải, gỗ, đèn treo tập trung trên bàn.
- Ánh sáng phòng **dựng sẵn (baked)** + reflection probe; chỉ bi, cơ, bóng đổ tính thời gian thực.
- Ray tracing phần cứng chỉ bật ở mức Cao.
- Ưu tiên chi tiết phục vụ việc ngắm (bi sắc nét, bóng đổ, kim cương) hơn chi tiết trang trí.

## Hiệu năng
- Mức chất lượng: Cao (iPhone 15 Pro trở lên), Trung bình, Thấp; tự chọn theo máy.
- Giới hạn 60 fps; khi bi đứng yên có thể giảm tần số render để tiết kiệm pin.
- Theo dõi `ProcessInfo.thermalState`: `.serious` → hạ một mức; `.critical` → mức Thấp.
- Vật lý tính trước toàn bộ cú đánh (mô phỏng theo sự kiện), render chỉ nội suy quỹ đạo → không tốn CPU lúc chạy.
- Mục tiêu: chơi 30 phút vẫn 60 fps, máy không quá nóng.
