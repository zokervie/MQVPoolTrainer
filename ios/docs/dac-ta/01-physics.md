# Vật lý (`PoolPhysics`)

## Nguyên tắc
- Xây mô hình từ **phương trình vật lý đã công bố**, không từ quy tắc hình học.
- Quy tắc hình học (90°, 30°, hệ thống kim cương) dùng làm **bài kiểm tra**: mô hình đúng thì chúng tự xuất hiện.
- Nguồn chính: Dr. Dave Alciatore (Colorado State University) — trượt/lăn, throw, squirt, swerve, video tốc độ cao; Mathavan et al. — va chạm băng và bi–bi; W. Marlow, *The Physics of Pocket Billiards*.
- Video quay chậm công khai có thể phân tích từng khung hình để hiệu chỉnh, không cần bàn thật.

## Kích thước (SI)
- Bàn 9 ft: mặt chơi 2,54 × 1,27 m (hỗ trợ 8 ft, 7 ft).
- Bi: đường kính 57,15 mm, ~0,17 kg.
- Mũi băng cao ~63,5% đường kính bi.
- Túi góc ~4,5", túi giữa ~5", có góc miệng túi (tham số).
- Tọa độ bài tập: **đơn vị kim cương** (dài 8, rộng 4, gốc ở góc bàn).

## Trạng thái bi
Vị trí, vận tốc, vận tốc góc 3 trục, trạng thái `sliding | rolling | spinning | stationary | pocketed`.

## Bắt buộc mô phỏng
- Trượt → lăn (ma sát trượt), lăn chậm dần (cản lăn), xoay trục đứng giảm dần.
- Bi–bi có ma sát bề mặt → throw (do cắt và do xoáy ngang), phụ thuộc tốc độ.
- Cơ–bi: điểm chạm, góc dốc cơ → xoáy; squirt theo khối lượng đầu cơ; swerve; (sau: nhảy, massé).
- Băng 3D có chiều cao băng (Mathavan 2010), góc bật phụ thuộc tốc độ và xoáy.
- Túi: vào lỗ, bật mép túi.

## Tham số mặc định (trong `PhysicsParameters`, sẽ hiệu chỉnh)
- Ma sát trượt bi–nỉ ≈ 0,2; cản lăn ≈ 0,01; ma sát quay trục đứng: tham số riêng.
- Ma sát bi–bi ≈ 0,06; phục hồi bi–bi ≈ 0,94.
- Phục hồi băng ≈ 0,75–0,85.
- Lưu theo "hồ sơ bàn" để người chơi chỉnh (nỉ nhanh/chậm, băng cứng/mềm).

## Thuật toán
- Ưu tiên mô phỏng **theo sự kiện**: tính thời điểm sự kiện kế tiếp (va chạm, chuyển trạng thái), nhảy tới đó. Phương án dự phòng: bước cố định ≤ 1 ms.
- `Double` toàn bộ. Cùng đầu vào → cùng kết quả từng bit.
- Xuất quỹ đạo theo thời gian (danh sách sự kiện + trạng thái) để render phát lại.
- Độc lập hoàn toàn với tốc độ khung hình.

## Test bắt buộc
- Quãng lăn đúng theo vận tốc đầu và cản lăn.
- Bi trượt (stun) chạm cắt: góc tách ≈ 90°. Bi lăn chạm nửa bi: bi cái lệch ≈ 30°.
- Throw theo góc cắt và tốc độ trong khoảng thực nghiệm.
- Góc bật băng thay đổi theo tốc độ và xoáy.
- Deterministic: chạy 2 lần, so sánh trạng thái cuối.
