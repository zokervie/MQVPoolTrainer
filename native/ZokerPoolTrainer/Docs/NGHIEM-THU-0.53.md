# NGHIỆM THU 0.53 "Sửa sau nghiệm thu 22/11"

accept_local đầy đủ: PASSED_SIMULATOR_UNSIGNED, 9/9 bước, 60 UI test 0 lỗi. Mọi phần cảm giác: chưa xác minh trên thiết bị.

| Mục | Kết quả | Ghi chú |
|---|---|---|
| Lõi phễu lỗ (ffd6d5a) | có sẵn | Chạm mép lỗ rồi vào = tính. |
| A1 nút Đặt bi sau lỗi của máy | PASS một phần | Thêm `syncPlaceBallButton()` vào `syncMatchControls`; test UI 8/9/10-ball (cờ `--match-foul-qa=`) PASS. NHƯNG test không đỏ khi tắt dòng sửa (nút được bật lại bởi `updateControls`), nên chưa chứng minh tái hiện lỗi gốc; sửa theo chẩn đoán đặc tả. Chung một commit với A2. |
| A2 vòng nhiệm vụ khi giữ B | PASS | `setTrainingOverlaysHidden(_, holding:)`: giữ B chỉ ẩn dự báo và vệt. Test UI `--hold-ring-qa` đỏ trước sửa (ringHidden=1), xanh sau. |
| A3.1 bi lăn trước gậy (Wi-Fi) | NOT RUN | Đổi chờ 0,1 s theo gậy cho mọi đường (kể cả khi mất gói aim) theo chẩn đoán; không thử được 2 máy. |
| A3.2 tiếng rơi lỗ hai lần | PASS (đơn vị) | `PocketSoundLedger`, test trong LANWireTests (1 tiếng/cú, chuyển nguồn giữa chừng). Nối vào cả hai đường âm. Chưa nghe trên 2 máy. |
| A3.3 đo khung khựng 2 Simulator | NOT RUN | Chưa đo. |
| B1 bố cục nút | MỘT PHẦN | Đặt bi + công tắc thanh lực sang phải cạnh thanh lực, có chữ nhỏ "Đặt bi" / "Thanh lực" (test UI PASS). CHƯA làm: chuyển "Xem lại" vào mục Bàn (đụng ~10 UI test và gợi ý hướng dẫn). |
| B2 gộp cơ 2 nút | PASS (logic + UI) | `BLCueMergedKind` (37°/33°, 22°/18°, giả định ở một chỗ) có test C++; 2 nút Cơ chơi/Cơ phá; rung nhẹ; máy đối thủ giữ nguyên. Chưa thử cảm giác kéo độ dốc. |
| B3 gọi lỗ gọn | NOT DONE | Chỉ có phần lõi từ ffd6d5a. Chưa làm: một chạm, sương trắng, mũi tên, dòng trạng thái. |
| B4 số kim cương | NOT DONE | |
| B5 khuông xếp bi một khối | NOT DONE | |
| B6 bàn bên + logo | MỘT PHẦN | Logo hạ xuống 0,85–0,95 m (phòng lớn 2,5 m): chưa có ảnh kiểm khung hình/va chạm đồ đạc nên NOT RUN về thị giác. Bàn bên chưa làm. |
| C1 luyện lực bằng vuốt | PASS | Bài tập/Thử thách/Thế bí: không thanh lực, không công tắc, vòng nhiệm vụ luôn bật (test UI). |
| C2 rà soát đồ hoạ | NOT DONE | |

Lý do dừng: các mục B3–B5, B6 (bàn bên) và C2 là việc dựng 3D/thị giác cần vòng lặp ảnh trước/sau; phần còn lại cần chủ dự án chọn thứ tự.
