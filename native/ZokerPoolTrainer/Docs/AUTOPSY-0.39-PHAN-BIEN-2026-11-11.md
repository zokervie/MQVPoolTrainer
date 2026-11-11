# Phản biện độc lập lỗi giật 0.39 (đối chiếu PR #5, PR #6 của Shadow) — 11/11/2026

Nền: build 120 = `849ead7`; `9e86c9b` chỉ khác tài liệu. PR #5 `ci/native-0.39-shadow-pacing@9de1cc4` (run 121 đỏ vì lỗi kiểu `Int→UInt`, đã sửa; run 122 đang chạy). PR #6 `fix/0.39-live-status-layout@6e2b715` dựa trên PR #5, chưa build. Nhánh này `fix/0.39-judder-candidate` = PR #5 + PR #6 + các sửa dưới đây; **chưa build, chưa thử máy thật**.

Quy ước: **Bằng chứng** = đọc được trong mã/đo được · **Giả thuyết** = hợp lý nhưng chưa đo trên máy · **Đã tái hiện** = chưa có mục nào (không có thiết bị ở đây).

## 1. Cập nhật `statusLabel` 5 Hz khi Menu đóng — ĐỒNG Ý, và nguyên nhân rộng hơn Shadow nêu
- Bằng chứng (mã 849ead7): `tick` đặt `statusLabel.text` mỗi > 0,2 s khi bi lăn, chỉ ở chế độ chơi (xem lại không có). Nhãn nhiều dòng nằm trong ngăn Menu dùng Auto Layout → đổi chữ làm UIKit bố cục lại → `viewDidLayoutSubviews` → `layoutRightHUD()` + `wakeRendering()`. Mỗi lượt như vậy: đặt lại ~25 phím, **vẽ lại bằng CPU** bi effect và phím B (`setNeedsDisplay`), đổi hằng số ràng buộc (có thể gây thêm một lượt bố cục), đọc `UserDefaults` cho từng phím, khởi động lại hoạt ảnh mờ phím, và **gán lại tần số CADisplayLink**.
- Khớp tần số với video (gần lặp hình mỗi ~0,2 s chỉ khi chơi). Vì ngưỡng là `> 0,2 s` nên chu kỳ thật là 12–13 khung ở 60 Hz — khớp việc pha 5 cũng thấp một nửa trong bảng của Shadow.
- Phản biện: PR #6 chỉ chặn một nguồn (nhãn trạng thái). Bất kỳ thay đổi Auto Layout nào khác giữa cú (thông báo nổi, bảng điểm, đồng hồ cú trong trận, nhãn gợi ý) vẫn đi đúng đường đắt đó. **Sửa tận gốc**: `viewDidLayoutSubviews` chỉ dựng lại phím khi đầu vào của bố cục thật sự đổi (kích thước, vùng an toàn, tay thuận, bi effect mở, Menu, số phím, tỉ lệ phím, đang xem lại). Giữ luôn bản chặn của PR #6.
- (12/11, CI 125) Bản đầu bỏ qua dựng phím cả lúc đứng yên → 2 test UI hỏng (chọn cú nhảy, Thêm bi) vì nhiều thứ khác (loại cú, Coach, sửa bi) cũng dựa vào lượt bố cục. Sửa: chỉ bỏ qua khi **bi đang chạy/xem lại** và đầu vào không đổi; lượt bị bỏ được chạy bù khi bàn đứng yên. Lúc đứng yên hành vi y như 0.39.
- Trạng thái: giả thuyết mạnh, chưa tái hiện. Bản này có **công tắc A/B trong cùng một build** (bật lại hành vi cũ) và **bộ đếm lượt bố cục giữa cú** để anh chứng minh/bác bỏ trên máy.

## 2. Tải CPU luồng chính — CHƯA KẾT LUẬN, đã gắn đồng hồ đo
- Đồng ý với Shadow: xem lại mượt không chứng minh quá tải CPU. Trước đây không có số đo nào.
- Thêm đo riêng mỗi khung: vật lý · ghi xem lại/chuyển dữ liệu ObjC→Swift · sự kiện/âm · cập nhật cảnh 3D · cả tick; p50/p95/max và số khung vượt 80 % ngân sách. Xem ở Tuỳ chỉnh → Máy · Âm thanh → Chẩn đoán độ mượt (có nút sao chép).
- Giữ hai giảm tải của PR #5 (hỏi tốc độ lớn nhất bằng một số thay vì dựng 16 từ điển 240 lần/giây; chỉ đọc sự kiện mới) — đúng, không đổi vật lý.
- Chưa tách vật lý sang luồng riêng: chỉ làm nếu số đo trên máy cho thấy vượt ngân sách.

## 3. FramePacer — ĐỒNG Ý với PR #5; bản 0.39 của em có lỗi thiết kế
- Bằng chứng: bản 0.39 làm tròn pha về lưới khung trong cửa sổ ±0,35 và ngoại suy tới 2,0, dựa trên giả định **chưa kiểm chứng** rằng thời điểm SceneKit gọi lại trùng đầu khung. Nếu giả định lệch (hoặc rung > 0,35 khung, dễ xảy ra ở 120 Hz = 2,9 ms) thì vị trí nhảy giữa "mẫu mới nhất" và "ngoại suy"; ngoại suy qua va chạm làm bi lấn vào băng/bi rồi giật lại.
- PR #5: giữ 8 mẫu, lấy mẫu liên tục chậm đúng 1 khung, không ngoại suy, đứng yên và đếm khi thiếu mẫu. Em kiểm bằng suy luận cả hai cách hiểu về đồng hồ SceneKit: thời điểm cần luôn nằm giữa hai mẫu đã có → đúng với cả hai thứ tự gọi lại. Đánh đổi: hình trễ thêm ~1 khung (17 ms ở 60 Hz) so với âm thanh — chấp nhận được.
- Sửa thêm 1 lỗi của PR #5: độ trễ lấy từ `link.targetTimestamp-link.timestamp` trong lúc link đang chạy 30 Hz (nghỉ) → có thể thành 33 ms cho cả đoạn xem lại. Đổi thành `1/tần số đã chọn`.
- Bỏ các lệnh gán lặp mỗi khung (`preferredFramesPerSecond`, `isPlaying`, `rendersContinuously`, `setNeedsDisplay`) — chỉ gán khi đổi.

## 4. Xoay bi: live dùng slerp đường ngắn nhất — ĐỒNG Ý, đã sửa
- Bằng chứng: bi lăn 5 m/s quay 167°/khung (60 Hz), cú break ~270°/khung. Slerp đường ngắn nhất đi ngược chiều; khi pha lấy mẫu rung 0,1 khung thì chấm/vân lệch tới ~36° → "vân bi lắc". Đây là lắc **hình xoay**, không phải tâm bi đứng–nhảy (mục 1, 3).
- Sửa: một quy tắc chung trong FramePacer cho cả chơi và xem lại — đi theo vận tốc góc đã ghi, rải phần dư nhỏ ở cuối; tự lùi về slerp khi vận tốc góc không giải thích được hai mẫu (xem lại quay chậm, va chạm giữa khoảng). Có test.

## 5. A/B — đã chuẩn bị công cụ, chờ anh chạy
- Trong Chẩn đoán độ mượt: "A/B: bật lại trạng thái 5 Hz cũ" và "A/B: xem lại 1× không quay chậm". Cùng build, cùng cú, cùng góc máy.

## 6. (23:20) Gốc rễ thứ hai tìm thêm — chỉ có khi chơi, không có khi xem lại
- Bằng chứng (TableScene.update): mọi lần cập nhật cảnh NGOÀI nhịp vẽ (refresh() khi chạm phím/xoay camera/đổi bi effect, bảng điểm, lượt) đều gọi `pacer.clear()` giữa lúc bi lăn → khung sau nhảy tới mẫu mới nhất rồi đứng chờ đủ lịch sử = một cú nhảy + một khung lặp. Xem lại không gọi refresh() giữa chừng nên không bị.
- Sửa: khi bi đang chạy (cú thật, xem lại, máy khách mạng), bộ đồng bộ "sở hữu" vị trí/hướng bi; cập nhật ngoài nhịp chỉ đổi bóng/độ mờ, không xoá lịch sử, không ghi đè vị trí.
- Độ trễ hiển thị 1,5 khung (25 ms ở 60 Hz) thay vì 1 khung: luồng chính trễ tới nửa khung vẫn không lặp hình.
- Chẩn đoán thêm: chênh lệch đồng hồ SceneKit so với hiện tại (Apple không công bố `time` là gì).

## Không đổi
Ma sát, độ nảy, bước 1/960 s, kết quả cú, chất lượng hình ảnh. Một nguồn trạng thái vật lý duy nhất (vẫn ở luồng chính).

## Tiêu chí nghiệm thu trên máy thật (60 Hz, máy nguội rồi máy ấm)
1. Lăn thẳng chậm, lăn thẳng nhanh, break, 3 băng có xoáy, nhảy, vào lỗ: mắt không thấy đứng–nhảy; quay màn hình rồi so khung không còn nhịp lặp ~0,2 s.
2. Chẩn đoán: "dựng lại phím giữa cú" = 0; "khung thiếu mẫu" ≤ 1 %; render p95 ≤ 18 ms; cả tick p95 ≤ 8 ms.
3. A/B: bật trạng thái 5 Hz cũ → nhịp giật trở lại và "dựng lại phím" > 0 (xác nhận nguyên nhân); tắt → hết.
4. Chấm/vân bi không quay ngược hay lắc ở cú mạnh.
5. Hồi quy: Lùi cú khi bi đang chạy, đặt lại thế bi, xem lại (tua/dừng), âm va chạm, Wi‑Fi/online, đổi tay thuận, mở bi effect, Menu — phím vẫn đúng chỗ.
Chỉ ghi "hết giật" sau khi anh xác nhận.
