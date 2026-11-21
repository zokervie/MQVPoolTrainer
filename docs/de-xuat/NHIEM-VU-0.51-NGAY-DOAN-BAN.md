# NHIỆM VỤ 0.51 — Thế bí của ngày · Đoán đường bi · Đặt thế bí cho bạn (phiên Mac)

Chủ dự án chấp thuận 21/11 22:50. Làm SAU 0.50 (T1–T8). Lõi: `BankLab/UI/PuzzleDaily.h` trên `cho/native-0.50-the-bi-core` (đã nhập bridging header; test `PuzzleDaily` 1 133 kiểm). Không cần máy chủ. Mọi ngưỡng là GIẢ ĐỊNH.
Mục tiêu: thứ để người KHÔNG chơi bida nhìn 3 giây là hiểu và muốn thử; thứ để khoe mà không lộ lời giải.

## N1. Thế bí của ngày (thẻ đầu màn Hôm nay)
- `day = BLDayIndex(unix, utcOffset)`; `BLDailyPuzzle(day, &mirrored)` → thế (dùng `BLPuzzleMirror` khi `mirrored`); số thế `BLDailyNumber(day)`. Mở cho mọi người, không phụ thuộc phòng đã mở. **Trước khi phát hành sửa `BL_DAILY_EPOCH_DAY` thành ngày phát hành.**
- Tối đa `BL_DAILY_MAX_TRIES` (6) cơ; không gợi ý trong thế của ngày; giải xong hoặc hết cơ thì khoá tới ngày mai (vẫn cho xem lại và vào luyện thế đó ở chế độ thường).
- Sau mỗi cơ: `BLDailyGrade(solved, BLDrillFirstContact(…), miss)`; `miss` = `BLPuzzleMissMetres(…)`, riêng thế REACH lấy khoảng gần nhất bi cái–bi 1 trừ 2R từ mẫu xem lại. Hiện dãy chấm ⚪🟡🟢.
- Xong: thẻ kết quả + nút **Khoe** → `BLDailyShareText` (chữ) và một ảnh thẻ 1080×1350 (logo, "Zoker #N · k/6", dãy chấm, chuỗi ngày; KHÔNG vẽ thế bi). Chuỗi ngày: dùng `BLStreak` sẵn có.
- Đo cục bộ: tỉ lệ giải, số cơ trung bình, số lần bấm Khoe.

## N2. Đoán đường bi (nút trên màn Hôm nay; mỗi lượt ~10 giây, một tay)
- Lượt thứ n: `BLPredictTask(n, &solution, &pace)` → bày thế, vẽ mũi tên hướng đánh + lực + điểm chạm của cú `solutions[solution]` (tốc độ × `pace`). Người chơi chạm chỗ nghĩ **bi cái dừng** (kéo để chỉnh, có kính lúp), bấm "Chốt".
- App đánh cú đó bằng engine thật, quay chậm 0,5× đoạn cuối, hiện vòng đoán và điểm thật, "lệch N cm", điểm `BLPredictScore(err)`.
- Chỉ số Mắt: `R = BLEyeUpdate(R, BLPredictTaskRating(signature, speed × pace), score / 100)`; bắt đầu `BL_EYE_START`. Hiện to ở Hồ sơ và thẻ khoe ("Mắt 1 042"). Giải thế bí (≤ 3 cơ = 1, không = 0) cũng cập nhật bằng `BLPuzzleTaskRating(percent)`.
- 5 lượt mỗi ngày tính điểm; chơi thêm thì không đổi chỉ số (tránh cày).
- Đây là chế độ phân tích: được vẽ cú cho sẵn; KHÔNG đưa đường dự đoán vào chế độ đánh chính.

## N3. Đặt thế bí cho bạn
- Màn xếp bi (dùng lại đặt bi tự do): bi cái, bi 1, 0–2 bi xám; chọn kiểu POT / REACH / HIDE.
- "Kiểm thế": cầu nối ObjC++ gọi `banklab::drillQuickFamilies(spec)` ở luồng nền (~1 100 cú, vài giây; hiện vòng chờ). Rỗng → "Chưa tìm thấy lời giải, dời một bi". Có → hiện "k lời giải, dễ nhất vào N %".
- "Gửi": `BLUserPuzzleEncode` → mã 15 ký tự hiện dạng `XXXXX-XXXXX-XXXXX` + dòng chia sẻ `Thế bí của tôi: <mã>`. Nhận: ô nhập mã → `BLUserPuzzleDecode` → kiểm lại bằng `drillQuickFamilies` trên máy nhận → chơi như thế bí thường (không tính sao phòng).
- Người nhận giải xong: nút "Thách lại" tạo dòng `Tôi giải mã <mã> trong k cơ`.

## N4. Tinh tế
- **Bóng của chính mình:** giữa hai lần thử một thế bí, vẽ mờ đường bi của lần thử trước (chỉ khi chưa nhấc cơ; tắt được). Không vẽ đường lý tưởng.
- **Miệng lỗ:** khi bi 1 dừng trong 3 cm quanh miệng lỗ hoặc rơi với tốc độ < 0,3 m/s, quay chậm 0,5 s cuối (chỉ ở thế bí và bài tập, không ở trận).
- **Clip 6 giây** của lời giải (đạo diễn máy quay 0.48, khung 9:16) có số thế / mã thế ở góc.
- **Tờ dán quán bida:** màn "In tờ thế bí" xuất PDF A5: logo, "Thế bí của ngày", mã QR mở app (URL scheme `zokerpool://daily`).

## Nghiệm thu
UI test: thế của ngày khoá sau 6 cơ và mở lại khi đổi ngày (cờ QA đặt ngày); dòng khoe đúng mẫu; lượt đoán cho điểm và đổi chỉ số; mã gửi–nhận khôi phục đúng thế; thế vô nghiệm bị từ chối. Báo cáo `NGHIEM-THU-0.51.md`. Chưa xác minh trên thiết bị cho tới khi chủ dự án thử.
