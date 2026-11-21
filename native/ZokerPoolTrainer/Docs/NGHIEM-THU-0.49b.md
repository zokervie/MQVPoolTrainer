# NGHIỆM THU 0.49b "Xưởng bài" (phần Swift) — nhánh `cho/native-0.49-xuong-bai`

Chạy trên Mac (Xcode 26.3, Simulator iPhone 17 Pro), `bash Tools/accept_local.sh` @68ab4e3: **PASSED_SIMULATOR_UNSIGNED** — 8/8 bước PASS
(assets, portable-regressions, replay-recording, lan-wire-protocol, simulator-build, screenshots-and-runtime-probes, ui-gesture-tests 35 test 0 lỗi, unsigned-iphone-build).
Chưa xác minh trên thiết bị. Chưa có CI macOS cho các commit này (nhánh `cho/`, không chạy CI).

| Mục | Kết quả | Ghi chú |
|---|---|---|
| 0a `testChapterOneLadderAndExam` | PASS | Nguyên nhân gốc: `loadDrill` bỏ qua âm thầm khi camera cú chưa về (`presentationBusy`), thi chương kẹt ở "cú 2/10". Nay chờ bàn rảnh (0,25 s/lần). Tái hiện cục bộ bằng nghỉ 0,3 s rồi PASS sau sửa. Tiêu chí test không đổi. |
| 0b `testFreshInstallLaunch…` | PASS | Đọc `flow` một lần gặp "launching" (CI) hoặc intro đã hết (nhanh). Nay chờ `flowLog` có hạn giờ và kiểm "intro" đứng đầu. |
| X1 kho bài từ C | PASS | Cờ `FeatureFlags.drillCatalog` (mặc định bật). 9 chương, mỗi chương ≥ 2 bài (UI test). Chỉ số bài cũ giữ nguyên, khoá thi `BLDrillChapterKey`, chuyển dữ liệu `chapter-n` một lần (PlayerStoreTests, 56 kiểm). Sao khó = `BLDrillStars`. |
| X2 chấm bằng `BLDrillJudge` | PASS (một phần) | Thang chương 1 + thi chương + bài kiểm tuần chạy qua máy chấm mới. Bài An toàn đã nối nhưng chưa có test UI riêng (NOT RUN). |
| X3 thế bi xê dịch | PASS | Cú 0 = bố cục gốc; cú 1+ lệch 0..0,03 m (UI test). Thi chương dùng biến thể theo lần xuất hiện. `SavedShot.variant` ghi biến thể. |
| X4 sơ đồ | PARTIAL | Có: vòng đích nét đứt vàng, vòng sáng lỗ đích (mô phỏng lời giải mẫu), số nút 0…8 / 0…4 (10 pt, 70 %), bi 2 "bi kế tiếp" ở bài Đi bi. KHÔNG có: vẽ đường lời giải mờ (nên chưa vi phạm CLAUDE.md), ảnh trước/sau 4 bài (NOT RUN), sửa đầu dò ảnh `drill-list` (NOT RUN). Bàn 3D khi chơi chế độ chính không hiện đường/vòng đích. |
| X5 mẹo một dòng + Xem thêm | PASS | UI test: một dòng mẹo, công thức/cách chấm gập sau "Xem thêm". Sổ mẹo dùng mẹo mới. |
| X6 chữ vi/en | PASS | `check_vi_en.py`: 0 thiếu (957 mục). |
| X7 Ra bàn thật | PASS (UI) / NOT RUN (Tiến bộ) | UI test: thẻ liệt kê bi theo nút, +/−, lưu, hiện lần trước. Cột "Trong app / Bàn thật" ở Tiến bộ đã code, chưa có ảnh/test (NOT RUN). |
| X8 thử thách phụ | PASS (logic) | PlayerStoreTests: huy hiệu, chuỗi liên tiếp. Huy hiệu trên thẻ bài/danh sách chưa kiểm bằng UI test (NOT RUN). |
| D1 mức Đạt theo độ khó | Đã dùng | `BLDrillPassMade`: qua bài khi đạt ≥ mức đó (first-shot 4/5…). Sao: qua → 3–4, trượt → ≤ 2. |
| D2 Bank không chặn | Đã dùng | Chương Bank có `blocking=false`. |
| Nút "Đặt bi" 64 pt | CHƯA LÀM | |
| Giảm chói bàn sáng | CHƯA LÀM | |
| Relayout UIKit hoãn tới khi bi dừng | CHƯA LÀM | |

## Chưa xác minh / lưu ý
- Mọi thứ chưa thử trên thiết bị. Hình vẽ sơ đồ (vòng lỗ đích, số nút) chưa được xem bằng mắt.
- Môi trường mới cần `python3 Tools/prepare_ci_assets.py` trước khi build Debug (thiếu PC_* thì app chết lúc khởi động; accept_local tự chạy).
- Mã thách bạn cho 12 bài mới: số bài nối thêm vào cuối bảng, mã cũ không đổi.
