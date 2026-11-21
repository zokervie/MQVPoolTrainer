# NGHIỆM THU 0.49c "Giao diện bàn chơi" — nhánh `cho/native-0.49-xuong-bai`

Thứ tự giao: G8 → G7 → G4 → G3 → G6 → G5 → G2 → G1. Cập nhật lượt 2: thêm G3, G7 (phần Simulator), G1; G5 và G2 vẫn chặn. Chưa xác minh trên thiết bị.

| Mục | Kết quả | Ghi chú |
|---|---|---|
| G8 luật phá 3 bi | PASS (công tắc, mặc định) / NOT RUN (kết quả ván) | Công tắc mặc định tắt, gán vào `BLMatch` mỗi ván; UI test đọc mặc định 0 và `-threeBallBreak049 YES` → 1. Test ván 9 Ball "phá có bi vào vẫn lượt người phá" chưa viết (cần cờ QA ép cú phá). Lõi C++ có test (c41bf0d). Mạng 2 máy: luật theo máy chủ phòng, chưa kiểm. |
| G7 giật 60 Hz | PASS (Simulator, đếm lượt bố cục) / NOT RUN (thiết bị) | Bố cục do cú ra cơ gây ra được gom vào lúc ra cơ; UI test đếm lượt bố cục sau khung đầu của cú: 0 (PASS 3/3 chạy lẻ + 4/4 qua simctl). Trong bộ đầy đủ 1 lần FAIL (1 lượt) khi Simulator đang tải: KHÔNG ổn định 100 %, nguyên nhân chưa tìm ra. Chưa đo 60/120 Hz trên iPad; B2c (vệt chuyển động bi nhanh) CHƯA LÀM. |
| G4 ẩn dải quang phổ | PASS (mặc định tắt, bật lại ở Chẩn đoán) / NOT RUN (xem bằng mắt) | UI test đọc `spectrum=0/1`. Chưa có ảnh vuốt thật. |
| G3 thanh lực | PASS | 28×180 pt (iPad), giữ = phóng ×2,5 quanh ngón tay, nút bật/tắt cạnh Đặt bi; UI test: kích thước, zoom 2,5, bật/tắt, tốc độ bắn khớp ánh xạ lõi ±1 % theo % hiển thị. Lưu ý: test cũ "nửa hành trình = 50 %" đã đổi vì zoom làm hành trình màn hình không còn tuyến tính (đã giải thích trong test). |
| G6 nút Đặt bi 64 pt | PASS | UI test; nhãn trợ năng "Nút đặt bi" (tránh trùng mục menu). |
| G5 giảm chói | PASS trên Simulator (offscreen) / chưa xác minh trên thiết bị | Đo bằng `SCNRenderer`+Metal offscreen (không dùng `scn.snapshot`), 12 bàn × 2 góc (trên cao, xiên), không bi, phòng chuẩn: `Tools/run_table_glare_qa.sh`, nay là bước `table-glare` của accept_local. TRƯỚC: arena-3 (Ice, thân trắng) 8,86 % điểm ảnh ≥ 250 góc xiên, 11 bàn còn lại 0,00 %. SAU: arena-3 0,00 % (TB sáng 116,7 → 114,5), 11 bàn kia không đổi (số y hệt). Sửa: thân bàn sáng (luma > 0,55) co albedo về luma 0,55, nhám 0,9, bỏ kim loại, lớp sơn bóng 0,1. Simulator tối hơn máy thật nên số chưa thay được kiểm trên thiết bị. Không có UI test riêng (thử qua XCUITest không chạy được probe trong runner; kiểm bằng script). |
| G2 khung gỗ + chữ bút lông | PASS (chức năng) / NOT RUN (xem bằng mắt đủ màn) | Petemoss-Regular.ttf + OFL.txt gốc (SIL OFL 1.1, © 2008–2021 The Petemoss Project Authors; đủ glyph tiếng Việt, đã kiểm bằng CoreText) vào `BankLab/Fonts/`, `UIAppFonts`. "Đấu với máy" (3 bước: cấp, luật, race) nay là bảng gỗ đặc, thẻ gỗ cùng cỡ, tiêu đề Petemoss, 6 cấp tên Việt (en: Beginner … AI), cỡ chữ 28/17/13, không tự co. Petemoss cũng dùng cho tiêu đề Menu, tiêu đề mục Tuỳ chỉnh, tên chương. Màn Pháp lý (Tuỳ chỉnh › Pháp lý · giấy phép) ghi công + giấy phép, mở được OFL.txt. UI test: font đăng ký, 6 thẻ cùng cỡ, Pháp lý. CHƯA: ảnh xem được bằng mắt (ảnh chụp XCUITest bị xoay), kiểm VoiceOver/Dynamic Type cỡ lớn nhất, áp khung gỗ cho toàn bộ Menu (mới tiêu đề) và hộp chọn chương (mới tiêu đề). |
| G1 sơ đồ = ảnh bàn game | PASS (hình, cache) / FAIL (lần dựng đầu) | `SCNRenderer` + Metal offscreen dựng được ảnh bàn từ trên (không bi/cơ), cache theo bàn + nỉ; ảnh `build/diag*/` cho thấy 6 miệng lỗ + băng + số nút + vòng đích/lỗ đích + bi kế tiếp + đường lời giải mờ (chỉ sau ≥ 1 lượt). Đo Simulator: lần dựng đầu 190–200 ms (đích 150 ms: CHƯA ĐẠT; lần cold start sau build có thể > 1 s), từ cache 0,015 ms. Nay dựng sẵn khi rảnh 6 s sau khi mở app. Chỉ bàn 9 ft; bàn khác dùng hình phẳng cũ. Chưa có ảnh trước/sau (không còn bản "trước"), chưa chạy trên iPhone SE. |
| X4 đường lời giải "Xem lời giải" trong Coach | CHƯA LÀM | Mới có "sau ≥ 1 lượt". |
| Đầu dò ảnh drill-list | CHƯA LÀM | |
| Huy hiệu | PASS (một huy hiệu) | UI test: vòng không Coach → "Huy hiệu mới" trong kết quả. 3 cú liên tiếp / Vùng nhỏ chỉ có test logic. |
| Cột Bàn thật ở Tiến bộ | PASS (tồn tại) | UI test + ảnh đính kèm; chưa xem ảnh bằng mắt. |
| Bài An toàn (app) | NOT RUN | Máy chấm C++ có test; luồng trong app chưa có test UI (chương 8 khoá). |

## Kết quả accept_local đầy đủ (lượt 2, @d1 + docs)
`bash Tools/accept_local.sh`: **PASSED_SIMULATOR_UNSIGNED**, 8/8 bước PASS gồm `unsigned-iphone-build` (IPA không ký); 42 UI test, 0 lỗi. Lần chạy trước cùng mã: 41/42, `testNoUIKitLayoutPassWhileTheBallsRoll` FAIL một lần khi máy tải (1 lượt bố cục giữa khung), không tái hiện lại (lẻ 3/3 + simctl 4/4, rồi bộ đầy đủ PASS): coi là KHÔNG ỔN ĐỊNH, chưa tìm ra nguyên nhân. Chưa xác minh trên thiết bị.

## Kết quả accept_local đầy đủ (lượt 3, có bước `table-glare`)
**PASSED_SIMULATOR_UNSIGNED**, 9/9 bước PASS (assets, portable-regressions, replay-recording, lan-wire-protocol, simulator-build, screenshots-and-runtime-probes, table-glare, ui-gesture-tests 42 test 0 lỗi, unsigned-iphone-build). Chưa xác minh trên thiết bị.

## Lượt 4 (G2 + gộp 0.50 core + lát cắt 0.50)
accept_local đầy đủ @ commit lát cắt 0.50: **PASSED_SIMULATOR_UNSIGNED**, 9/9 bước PASS (gồm table-glare, unsigned-iphone-build), 46 UI test, 0 lỗi. Chưa xác minh trên thiết bị.
