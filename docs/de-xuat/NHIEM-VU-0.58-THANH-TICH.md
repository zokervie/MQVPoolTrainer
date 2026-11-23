# Giao việc 0.58 — sửa sau nghiệm thu 167/168, thành tích, huy chương, Thách bạn (cho phiên Mac)

Chủ dự án duyệt 23/11 15:47. Nhánh lõi `origin/cho/native-0.58-co-tren-bang` (= `cho/native-0.53-phieu-lo` @ 892f2bc
+ BLCueRailBridgeSolve). Gộp vào `cho/native-0.53-phieu-lo` sau khi xong 0.57. Một mục = một commit, có test.
Thứ tự: P0 → P1 → P2. TestFlight dự kiến ~11/12.

## P0 — lỗi
**L1. Lùi cú nhảy sang chương khác (mục 6, nặng nhất).** Ngăn lùi cú riêng cho mỗi bài/ải; đổi bài, đổi chương, rời
màn = xoá ngăn. Quỹ lùi cú tính theo khoá chương (`BLChapterUndoLeft`). Test UI: tập chương 1 → sang chương 2 → bấm
Lùi cú: không quay về thế của chương 1, quỹ chương 1 không đổi.

**L2. Bi mục tiêu rung khi xem lại (mục 1).** Quay xem lại một cú có bi mục tiêu lăn dài; ghi vị trí bi theo khung,
tìm khung nhảy (nội suy, đổi nguồn mẫu, camera). Sửa gốc, báo số khung lệch > 2 mm trước/sau.

**L3. Sổ lời giải / Đo cục bộ không thoát được (ảnh).** Hai màn được push trong Thế bí; nút quay lại không thấy
(nghi tint tối trên nền tối — INFERRED). Thêm nút "Đóng" rõ ràng, kiểm vuốt cạnh trái để quay lại, kiểm màu chữ nút
trên mọi màn push trong app. Test UI: mở Sổ lời giải → Đóng → về Thế bí → về bàn.

**L4. Cơ trên băng (ảnh 85°/45°).** Dùng `BLCueRailBridgeSolve` (CueClearance.h) thay cho cách giữ điểm chạm rồi dựng
cơ: truyền góc quạt người chơi (`cueElevation`), nhận `top` mới và `elevation`. Bi effect hiện điểm chạm đã dời lên
(chấm vàng + chữ nhỏ "Cơ trên băng"); người chơi kéo quạt lên thì điểm chạm hạ dần. Máy đối thủ không đổi.
**Hạ thành băng gỗ 56 → 40 mm** (tài liệu chủ dự án: mặt gỗ thành băng 38–42 mm tuỳ hãng; mũi cao su 36,3 mm giữ):
`generate_table_mesh.py` (mặt gỗ), `TableScene.cushionPath`, độ cao nút kim cương (0,05615), và `BLRailProfile` trong
CueClearance.h (các điểm sau mũi băng: 38,5 / 39,8 / 40 mm) — CÙNG MỘT COMMIT để hình và va chạm cơ luôn khớp. Sửa kỳ
vọng trong `CueClearanceTests` (bi sát băng, tip +0,55: ~7° thay ~38°). Đo bằng lõi: sát băng → +0,50 R ở 15°; 3 cm →
+0,25 R ở 15°; từ 6 cm giữ điểm chạm. Ảnh trước/sau ở 3 góc, đặc biệt cơ không xuyên băng.

## P1 — thành tích
**T1. Tự sang ải (mục 4).** Đạt 3 sao: thẻ "Lên vòng tiếp ▶" tự chạy sau 3 s (chạm để huỷ) + "Đánh lại lấy điểm cao
hơn". Hết chương: thẻ huy chương (T3) rồi gợi ý chương sau.

**T2. Bản thành tích (mục 2).** Mỗi ải và mỗi chương lưu: sao, % hoàn thiện, số lùi cú, có dùng trợ giúp thanh lực,
chuỗi trúng liên tiếp dài nhất, thời gian hoàn thành (chỉ ghi, không xét danh hiệu), ngày. Giữ lần tốt nhất + lịch sử
các lần (tối đa 20/ải). Màn "Thành tích luyện tập" trong Profile: theo chương, chạm để xem chi tiết.

**T3. Huy chương.** Một huy chương mỗi chương = danh hiệu (`BLTitleIndex`). 6 chất liệu, độ rực tăng dần:
Gỗ (0–1) · Đồng (2–3) · Bạc (4–5) · Vàng (6–7) · Bạch kim (8) · Kim cương (9, ánh sáng động; tắt khi Giảm chuyển động).
Dấu "Tay sạch" = ruy băng. Mặt sau huy chương: đủ số liệu T2. Vẽ bằng code (Core Graphics/SceneKit), không dùng ảnh có
bản quyền. Thẻ khoe (0.54 M5) dùng huy chương này.

**T4. Lưu trữ và số liệu trận (mục 5).** Huy chương chỉ từ Bài tập theo chương. Số liệu trận tách: Máy (theo cấp) ·
Người (cùng máy / Wi-Fi) · Online, kèm một dòng tổng. Đồng bộ iCloud của người chơi (NSUbiquitousKeyValueStore cho hồ
sơ nhỏ; dữ liệu lớn để sau) — bật entitlement khi có tài khoản Apple Developer; chưa có thì chỉ lưu máy. Không máy chủ.

## P2 — Thách bạn (mục 3, vào TestFlight vì không cần máy chủ, không có chữ do người dùng viết)
Nút "Thách bạn" trên thẻ kết quả ải: mã 15 ký tự (cùng định dạng mã thế bí, thêm loại "thách") chứa khoá ải + sao +
số trúng. Dòng chia sẻ: "Zoker Pool · Thách bạn ải <tên> · mình <N>/5 — vượt được không? <mã>". Người nhận dán mã →
chơi đúng ải đó → so kết quả. Mã sai/ải không tồn tại: báo lỗi. Đếm tại máy như 0.55 R5.

Báo cáo `NGHIEM-THU-0.58.md`: mỗi mục PASS / FAIL / NOT RUN, ảnh ở `shots/native/0.58`. Cảm giác: chưa xác minh trên thiết bị.
