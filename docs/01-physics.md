# Vật lý (`PoolPhysics`)

## Nguyên tắc
- Mô hình xây từ **phương trình đã công bố**; quy tắc hình học (90°, 30°, kim cương) chỉ dùng làm kiểm tra, kèm đúng giả thiết của chúng (UPGRADE.md, ghi chú M1).
- Nguồn: Alciatore (lăn/trượt, throw, squirt, quy tắc 30°/90°); Mathavan et al. 2010 và Han 2005 (băng); Leckie & Greenspan 2006 (mô phỏng theo sự kiện); Marlow.
- **Một bộ giải trong runtime: theo sự kiện.** Bộ giải bước nhỏ chỉ có trong test.
- Tính trước toàn bộ cú đánh ngoài main thread; render chỉ phát lại quỹ đạo.

## Đơn vị và hệ tọa độ
- SI, `Double`. Gốc ở một góc mặt chơi; x theo chiều dài, y theo chiều rộng, z lên; tâm bi ở z = R.
- Bài tập dùng **đơn vị kim cương** (dài 8, rộng 4) — `TableSpec.meters(fromDiamonds:)`.
- Sang RealityKit **chỉ** qua `RenderMapping` (gốc ở tâm bàn, y lên, Float).

## Bàn và tham số
- `TableDefinition`: `schemaVersion`, `geometry` (`TableSpec`), `physics` (`PhysicsParameters`), `physicsProvenance` (mỗi tham số một `Provenance`), `visualAssetName`. Có `validate()`.
- Bàn mặc định `zoker9ft`: kích thước theo chuẩn WPA, thiết kế riêng, không theo hãng nào.
- `CalibrationProfile`: lưu riêng, gắn `tableId`, ghi điều kiện đo; `applied(to:)` thay giá trị và nguồn gốc.

## Phạm vi MVP (quyết định D4)
| Có | Hoãn |
|---|---|
| Trượt/lăn, cản lăn, xoay trục đứng | Swerve (cơ cố định gần nằm ngang) |
| Va chạm bi–bi + **throw** (do cắt, do xoáy ngang; ma sát phụ thuộc tốc độ) | Truyền xoáy sang bi mục tiêu |
| Cơ–bi theo xung lực, giới hạn trượt cơ, **squirt** | Massé, nhảy bi |
| Băng 3D phụ thuộc tốc độ và xoáy | |
| Hình học lỗ: mép, thành, bi rơi | |

## Bộ giải theo sự kiện — yêu cầu
- Thời điểm va chạm: khoanh nghiệm bằng đổi dấu trong khoảng đến sự kiện chuyển trạng thái kế tiếp, rồi Newton + chia đôi. Không dùng công thức Ferrari trực tiếp.
- Sự kiện gần đồng thời: cửa sổ Δt, thứ tự xác định (thời gian, rồi chỉ số bi). **Đo độ nhạy thứ tự** (M7).
- Trạng thái tiếp xúc chống va chạm lặp vô hạn (Zeno).
- Giới hạn số sự kiện mỗi cú; chạm giới hạn → đánh dấu lỗi, ghi seed, không âm thầm cắt.

## Đã cài đặt (bản 0.3)
| Thành phần | File | Ghi chú |
|---|---|---|
| Chuyển động tự do dạng đóng | `Motion.swift` | trượt → lăn → xoay → dừng; `acceleration()` cho đa thức vị trí |
| Tìm nghiệm đa thức | `Polynomial.swift` | cô lập bằng điểm tới hạn + chia đôi, xử lý nghiệm kép (va chạm sượt) |
| Bộ giải theo sự kiện | `Simulation.swift` | bi–bi, băng, mũi băng, lỗ, biên an toàn; cửa sổ đồng thời 1 ns, thứ tự xác định; giới hạn 20.000 sự kiện |
| Bi–bi có throw | `Collisions.swift` | xung lực + ma sát μ(v) = μ₀·(r + (1−r)e^(−cv)) (Alciatore TP A.14) |
| Băng và mũi băng | `Collisions.swift` | xung lực với pháp tuyến nghiêng theo độ cao mũi băng; **đơn giản hóa**, chưa phải Mathavan 2010 đầy đủ |
| Hình học lỗ | `TableGeometry.swift` | miệng lỗ góc 45°, khe lỗ giữa, mũi băng là điểm; bi rơi khi tâm qua đường bắt giữ. Chưa có mặt vát miệng lỗ và bi bật ra khỏi lỗ |
| Cơ–bi | `CueStrike.swift` | xung lực, squirt (Alciatore TP A.31), trượt cơ > 0,5R; cơ nằm ngang |
| Bản ghi va chạm | `CollisionRecord` | loại, thời điểm, vị trí, tốc độ pháp tuyến, xung lực, trượt tiếp tuyến, lỗ |
| Quỹ đạo | `Trajectory` | nội suy chính xác giữa các sự kiện |
| Khoảng ngắm | `AimWindow.swift` | quét góc + chia đôi biên |
| Công cụ dòng lệnh | `Sources/poolsim` | chạy kịch bản JSON cho đối chứng pooltool |

Chống Zeno (`CollisionThresholds`): lại gần chậm hơn 0,1 mm/s coi là tiếp xúc tựa — chỉ xử lý khi lấn quá 0,1 µm, rồi tách 10 µm và triệt vận tốc lấn vào. Dự đoán sự kiện lưu theo thời gian tuyệt đối, chỉ tính lại cho bi vừa thay đổi.

Sửa lỗi khi rà phương trình (R0.4): dấu xoáy ngang trong `CueModel` cũ bị ngược (đánh bên phải phải cho ω_z > 0, quay ngược chiều kim đồng hồ nhìn từ trên).

Test: `SolverTests.swift` (M2–M7, throw, squirt, băng, xoáy ngang, lỗ, khoảng ngắm), `MotionTests.swift` (M1), `TableDefinitionTests.swift`.
