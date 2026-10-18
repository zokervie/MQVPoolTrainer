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

## Đã có trong code (chưa biên dịch)
- `FreeMotion`: chuyển động dạng đóng, chuyển trạng thái.
- `BallBallCollision`: va chạm lý tưởng (chưa throw).
- `CueModel`: cơ nằm ngang, `speedRatio` tạm (thay ở R3.1).
- `TableDefinition`, `CalibrationProfile`, `Provenance`, `RenderMapping`.
- Test: quãng lăn, 5/7, 90°, 30° (33,7°), lặp lại, kim cương, schema, tọa độ.

KPI tầng 1 (M1–M7): UPGRADE.md mục 3.1.
