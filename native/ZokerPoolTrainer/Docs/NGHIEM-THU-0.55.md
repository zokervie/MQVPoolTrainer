# NGHIỆM THU 0.55 "Đặt thế bí cho bạn — Thử nghiệm" (nhánh cho/native-0.53-phieu-lo)

Chưa xác minh trên thiết bị. R1–R5 sửa cùng một màn (`UserPuzzle051.swift`) nên nằm chung MỘT commit (test PlayerStore viết trước).

accept_local đầy đủ (sau khi gộp `origin/ci/native-0.56`, không xung đột; accept_local vẫn chạy cả UI vì không đặt ZOKER_UI_SHARDED): STATUS FAILED ở ui-gesture-tests, 8/9 bước PASS, 67 UI test với 2 test nhấp nháy: `testFreshInstallLaunchFlowIntroLobbyTutorialTable` (lần chạy riêng đầu cũng đỏ, lần sau PASS 29 s) và `testNoUIKitLayoutPassWhileTheBallsRoll` (PASS khi chạy lại). KHÔNG phải 9/9 sạch; lượt 0.56 trước đó là 9/9. Cần điều tra tính ổn định của hai test này.


**Ổn định (điều tra gốc, không nới tiêu chí/timeout):**
- `testNoUIKitLayoutPassWhileTheBallsRoll`: GỐC = nút ẩn "Đạo diễn" của thanh xem lại được UIKit dựng nhãn muộn (30→56 pt) trên một cập nhật Core Animation ngay giữa cú đầu (dò bằng `--layout-trace-qa`: UIButtonLegacyVisualProvider ← CALayer perform_update_ ← l10n_setText). Sửa: thanh xem lại chỉ nằm trong view khi đang xem lại. Trước: 10/14 (71 %) trên cài mới; sau: 12/12.
- `testFreshInstallLaunchFlowIntroLobbyTutorialTable`: GỐC = chạy lần đầu sau build lạnh, intro (~4,5 s) có thể đã hết trước khi XCUITest kịp tìm (lần đỏ riêng: "intro không hiện đầu tiên"/"Sảnh đè lên intro"). Sửa: cờ QA `--intro-hold-qa` giữ phim ở giây 1 tới khi chạm (test vẫn chạm để bỏ qua); không đổi tiêu chí. Trước: 7/8; sau: 8/8 trên cài mới.

| Mục | Kết quả | Ghi chú |
|---|---|---|
| R1 kết quả kiểm cũ ghi đè thế mới | PASS (đơn vị + UI tất định) | `CheckGate`: mỗi lần kiểm có "vé"; đổi thế (`changed()`) làm vé cũ mất hiệu lực, tác vụ nền chỉ ghi kết quả khi vé còn khớp (cả `receive()`). Khoá kéo bi, bật/tắt kiểu, thêm/bớt bi xám trong lúc kiểm. Test đơn vị trong PlayerStoreTests (vé cũ bị bỏ, chỉ vé mới nhất tính). UI test tất định `testStaleCheckResultNeverEnablesSend` (cờ QA `--user-puzzle-race-qa`: kiểm bị làm chậm 2,5 s và 0,5 s sau có một thay đổi lọt vào): ĐỎ khi bỏ chốt vé (Gửi bật, báo "1 lời giải"), XANH khi có chốt: 5/5 trên cài mới. |
| R2 nhãn Thử nghiệm | PASS (UI test) | Mục menu "Đặt thế bí cho bạn · Thử nghiệm" và nhãn nhỏ "Thử nghiệm" (en "Beta") ở tiêu đề màn. |
| R3 dòng chia sẻ | PASS (UI test) | `Zoker Pool · Thế bí của tôi (Vào lỗ|Chạm bi 1|Giấu bi): XXXXX-XXXXX-XXXXX — bạn giải được không?` (en: `Zoker Pool · My puzzle (…): … — can you solve it?`), không đường ngắm, không lời giải. Dòng được hiện cả dưới mã để người thử thấy nội dung gửi đi. |
| R4 phía người nhận | PASS (UI test) | Nút "Dán" trong ô nhập (chỉ đọc bộ nhớ tạm khi bấm); sau khi kiểm lại hiện thẻ "N lời giải · dễ nhất vào P %" với "Chơi"/"Đóng" rồi mới chơi; mã sai / không giải được giữ thông báo cũ. Nút Dán chưa được test tự động (bộ nhớ tạm của Simulator hỏi quyền). |
| R5 đếm tại máy | PASS (đơn vị + UI) | PlayerStore: mã đã gửi (bấm Gửi), đã nhận và chơi (bấm Chơi), giải được; hiện chữ nhỏ cuối màn; không gửi đi đâu. Test: PlayerStore (95 kiểm) và UI (sau khi gửi: "Mã đã gửi: 1"). |
