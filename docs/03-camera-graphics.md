# Góc nhìn, đồ họa, hiệu năng

## Camera
- Góc nhìn thứ nhất sau cơ, cao hơn mặt bàn 15–30 cm (chỉnh được).
- FOV dọc ~40–45°, tự tính theo tỉ lệ màn hình để cảm giác khoảng cách nhất quán, không méo mép.
- Hai chế độ: **đọc thế bi** (đi vòng quanh, nhìn từ trên) và **cúi đánh**.
- Tùy chọn gyroscope xoay nhẹ góc nhìn.

## Đồ họa MVP — chỉ những gì ảnh hưởng tới luyện tập
1. Phối cảnh đúng (FOV, độ cao mắt, tỉ lệ) — quyết định ngắm.
2. Mép bi sắc, khử răng cưa (MSAA) — quyết định cú cắt mỏng.
3. Khung hình đều 60 fps — cảm nhận tốc độ.
4. Bi có số, **bi cái có chấm** — nhìn thấy xoáy và tốc độ quay.
5. Bóng tiếp xúc — khoảng cách bi tới băng, bi tới bi.
6. Kim cương rõ, đúng vị trí — dùng cho công thức.

## Sau Cổng 1 (R7)
PBR (nỉ, cao su, gỗ, kim loại, bi phenolic), ánh sáng dựng sẵn + reflection probe, clearcoat, LOD, nén ASTC, mức chất lượng tự động. Không làm công cụ so ảnh render với ảnh thật.

## Hiệu năng
- Vật lý tính trước cả cú, ngoài main thread; render nội suy quỹ đạo.
- Mức chất lượng theo máy; theo dõi `ProcessInfo.thermalState` (`.serious` → hạ một mức).
- KPI H1–H4 và cấu hình benchmark: UPGRADE.md mục 4.
