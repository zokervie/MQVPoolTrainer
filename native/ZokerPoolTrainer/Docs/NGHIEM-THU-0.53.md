# NGHIỆM THU 0.53 "Sửa sau nghiệm thu 22/11"

accept_local đầy đủ (lần cuối): STATUS FAILED ở ui-gesture-tests, 8/9 bước PASS, 61 UI test với 2 lỗi nhấp nháy: `testNoUIKitLayoutPassWhileTheBallsRoll` (đã nhấp nháy ở các lượt trước) và `testReplayIncludesActualPreparationBeforeNativeShotClock` (không thấy cảnh sau khi mở). Chạy lại riêng: cả hai PASS. KHÔNG phải 9/9 sạch; lần accept_local trước (A1–C1) là 9/9 với 60 test. Cần điều tra tính ổn định trong bộ đầy đủ.

| Mục | Kết quả | Ghi chú |
|---|---|---|
| Lõi phễu lỗ (ffd6d5a) | có sẵn | Chạm mép lỗ rồi vào = tính. |
| A1 nút Đặt bi sau lỗi của máy | INFERRED | Thêm `syncPlaceBallButton()` trong `syncMatchControls` (gốc nghi: `quickPlace` đổi mà nút không đồng bộ). Test UI 8/9/10-ball (cờ `--match-foul-qa=`, mô phỏng máy→người) xanh nhưng KHÔNG đỏ khi tắt dòng sửa (nút được bật lại bởi chu kỳ `updateControls`), nên không tái hiện được lỗi gốc: sửa theo chẩn đoán đặc tả. |
| A2 vòng nhiệm vụ khi giữ B | PASS | `setTrainingOverlaysHidden(_, holding:)`: giữ B chỉ ẩn dự báo và vệt. Test UI `--hold-ring-qa` đỏ trước sửa (ringHidden=1), xanh sau. |
| A3.1 bi lăn trước gậy (Wi-Fi) | NOT RUN | Đổi chờ 0,1 s theo gậy cho mọi đường (kể cả khi mất gói aim) theo chẩn đoán; không thử được 2 máy. |
| A3.2 tiếng rơi lỗ hai lần | PASS (đơn vị) | `PocketSoundLedger`, test trong LANWireTests (1 tiếng/cú, chuyển nguồn giữa chừng). Nối vào cả hai đường âm. Chưa nghe trên 2 máy. |
| A3.3 đo khung khựng 2 Simulator | NOT RUN | Chưa đo. |
| B1 bố cục nút | PASS | Đặt bi + công tắc thanh lực sang phải cạnh thanh lực, chữ nhỏ "Đặt bi"/"Thanh lực". "Xem lại" đã vào mục Bàn (kèm submenu Lưu cú / Thư viện); cột phím còn Lùi cú · Camera · Bàn; 5 UI test replay sửa theo (helper `tapReplay`/`openReplaySubmenu`), gợi ý hướng dẫn trỏ vào Bàn. |
| B2 gộp cơ 2 nút | PASS (logic + UI) | `BLCueMergedKind` (37°/33°, 22°/18°, giả định ở một chỗ) có test C++; 2 nút Cơ chơi/Cơ phá; rung nhẹ; máy đối thủ giữ nguyên. Chưa thử cảm giác kéo độ dốc. |
| B3 gọi lỗ gọn | PASS (logic) · ảnh NOT RUN trước/sau | Một chạm: bi gọi mặc định = bi đích hợp lệ (9/10-ball bi thấp nhất; 8-ball bi nhóm gần đường ngắm nhất), không đổi camera; chạm bi khác để đổi; chỉ khi chạm trượt cả lỗ lẫn bi mới mở camera trên cao. Lỗ có sương trắng mờ (alpha 0,25, không che miệng), sau gọi một mũi tên mảnh nhấp nhô 2 cm/1,2 s. Test UI `--call-qa` PASS. Ảnh: shots/native/0.53/after/call-*.png (không có ảnh "trước": cầu vồng đã thay trong cùng commit). |
| B4 số kim cương | PASS | Bong bóng ngay trên từng kim cương + sợi chỉ + kim cương sáng nhẹ; cỡ ~14 pt theo khoảng cách camera, mờ khi sát camera. Ảnh trước/sau: shots/native/0.53/{before,after}/diamonds-{play,corner,side}.png. |
| B5 khuông xếp bi | PASS (ảnh) | Một khối SCNShape từ `rackFrameEdges` (không đổi), bo 2,5 cm/4 mm, dày 1,8 cm, cao 2,4 cm, vát. Hạn chế: vân gỗ một hướng cho cả khối. Ảnh: shots/native/0.53/{before,after}/rack-*.png. |
| B6 bàn bên + logo | PASS (ảnh) | Bàn bên đầy đủ (nỉ xanh dương đậm, băng gỗ + mũi, 6 lỗ, chân), dời ra ±3,13 m (rail-rail ≥ 1,6 m, cách tường ~2 cm). Logo hạ 0,85–0,95 m (phòng lớn 2,5 m). Ảnh: after/neighbour-wide.png, after/logo-wall*.png. Lưu ý: camera ngắm mặc định nhìn gần như thẳng xuống nỉ, logo nằm sau lưng người đánh (z −4,6) nên không bao giờ vào khung camera ngắm; nó thấy ở góc đứng/toàn bàn. Ảnh "trước" của logo không có (đã hạ ở commit trước). |
| C1 luyện lực bằng vuốt | PASS | Bài tập/Thử thách/Thế bí: không thanh lực, không công tắc, vòng nhiệm vụ luôn bật (test UI). |
| C2 rà soát đồ hoạ | PASS một phần | 10 phòng × 3 góc (shots/native/0.53/after/room*-{play,standing,top}.png, montage-rooms-standing.png). Đã sửa rẻ: phòng Home cháy sáng (hạ đèn, before/after room1-standing). Còn lại (chưa sửa): Home vẫn sáng gắt bên trái; Sân vườn nền phẳng, cây trôi trên sàn gỗ; Thi đấu quốc tế thanh màu xanh/vàng là tấm phẳng, khán giả là hình khối; Sân thượng đêm toà nhà mặt phẳng; chưa kiểm bóng tiếp đất bàn ở từng phòng. |

Lý do dừng: các mục B3–B5, B6 (bàn bên) và C2 là việc dựng 3D/thị giác cần vòng lặp ảnh trước/sau; phần còn lại cần chủ dự án chọn thứ tự.
