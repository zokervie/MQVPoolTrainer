# Kiểm định trước khi nộp App Store — "một game tử tế" (lập 25/11/2026)

Anh dặn 25/11 22:31: kiểm cẩn thận để vượt duyệt Apple theo cách đúng, game phải tử tế.
Căn cứ: App Review Guidelines (developer.apple.com/app-store/review/guidelines, đọc 25/11/2026). Trạng thái tại cfbcc89; mọi ô "đạt" phải có bằng chứng (file/commit/ảnh) trước khi nộp. Không phải tư vấn pháp lý.

| # | Yêu cầu (mục) | Zokervie hiện tại | Việc phải làm | Ai |
|---|---|---|---|---|
| 1 | App hoàn chỉnh, URL chạy, IAP thấy và mua được (2.1) | URL chính sách/hỗ trợ đã đăng; IAP chưa có StoreKit | Bản nộp đầu KHÔNG bán gì (hoặc IAP làm xong, có Khôi phục giao dịch). Không có nút nào bấm vào mà không chạy. Ghi chú cho người duyệt: đường vào nhanh (cú đầu → xem lại → xuất highlight) | Mac + em |
| 2 | Mô tả, ảnh chụp, thông tin quyền riêng tư đúng sự thật (2.3) | chưa viết | Ảnh chụp từ app thật; không viết "chuẩn 100% như bàn thật"; câu về vật lý phải có bảng nguồn + sai số (trang "Về vật lý") | em |
| 3 | Không có tính năng ẩn, "ngủ", không khai báo (2.5.19) | 25/11: Release build không còn lối vào Online/Game Center/máy chủ relay (`ReleaseGate.online`, Debug + cờ ZOKER_ONLINE vẫn có); FeatureFlags hiện tại đều BẬT (không ngủ) | RỦI RO: code bị ẩn sau cờ có thể bị coi là tính năng ngủ. Bản nộp: bỏ khỏi bản build (không chỉ ẩn nút) phần chưa dùng, hoặc khai rõ trong Notes for Review. Không bật tính năng từ xa sau khi duyệt | Mac |
| 4 | Đủ giá trị, không phải bản sao (4.1, 4.2) | Lõi vật lý riêng, bài tập, thế bí, đấu máy | Đạt. Không dùng tên/logo/icon hãng khác (luật "Z-…" đã có); đổi hết chữ ZOKER cũ sang Zokervie | Mac |
| 5 | Nội dung người dùng tạo: lọc, báo cáo, chặn, liên hệ (1.2) | "Đặt thế bí cho bạn" gửi mã riêng giữa bạn bè; chưa có phòng công khai | Mã riêng: ổn (không có kênh công khai). Phòng tự soạn công khai (sau này) BẮT BUỘC có lọc + báo cáo + chặn + email liên hệ trước khi mở | sau |
| 6 | Chính sách quyền riêng tư trong App Store Connect và trong app (5.1.1) | 25/11: PrivacyInfo.xcprivacy (CA92.1, C617.1, 35F9.1, không theo dõi, không thu dữ liệu) + link Chính sách / Hỗ trợ trong Cài đặt → Pháp lý (R1, R3 xong ở code, chưa biên dịch) | Làm R1, R3; nhãn quyền riêng tư App Store khai đúng: hiện không thu dữ liệu cá nhân, không theo dõi | Mac + anh |
| 7 | Xoá tài khoản trong app (5.1.1(v)) | Không có tài khoản riêng | Không áp dụng tới khi có tài khoản online; lúc đó phải có nút xoá tài khoản | sau |
| 8 | Sở hữu trí tuệ (5.2) | Ảnh tường (ảnh anh làm lại + nhân vật AI), âm thanh CC0/tự tổng hợp, font OFL | Bảng tài nguyên ↔ IPA ↔ ghi công (R5); không chép hình/bảng từ tài liệu "phi thương mại"; nhắc tên người thật giọng trung tính, không ngụ ý bảo trợ | Mac + em |
| 9 | Mua nội dung số phải dùng IAP; không mở khoá bằng mã/QR (3.1.1) | Mã "Thách bạn"/thế bí chỉ chia sẻ bài miễn phí | Không bao giờ dùng mã/QR để mở khoá nội dung trả phí; gói Z- chỉ bán qua IAP | luật |
| 10 | Game Center: không spam, không lộ Player ID (4.5.3, 4.5.5) | Ẩn sau cờ (xem #3) | Khi bật: không hiện Player ID, không gửi lời mời hàng loạt | sau |
| 11 | Xếp hạng tuổi trả lời trung thực; dữ liệu trẻ em (1.3, 2.3.6) | Không cờ bạc, không bạo lực; bida có quán bar trong ảnh tường | Khai trung thực (rượu xuất hiện trong ảnh nền? kiểm 24 ảnh); không vào mục Trẻ em | anh + em |
| 12 | AI bên thứ ba: phải báo rõ và xin phép trước khi gửi dữ liệu cá nhân (5.1.2(i)) | Chưa có AI online trong app | Nếu sau này có AI huấn luyện viên online: hỏi đồng ý từng lần; ưu tiên AI chạy trên máy | sau |
| 13 | Mã hoá xuất khẩu | 25/11: ITSAppUsesNonExemptEncryption = NO trong Info.plist (R2) | Khai NO (chỉ dùng mã hoá chuẩn của hệ thống) | Mac |

| 14 | Không phát hành bản "beta/thử nghiệm" (2.2) | 25/11: nhãn "Thử nghiệm" ở Đặt thế bí ẩn trong Release; Phòng thử vật lý chỉ hiện khi bật Phòng thí nghiệm | Cân nhắc gỡ hẳn "ZUPE · Thử nghiệm" khỏi bản nộp | Mac |
| 15 | Tên hiển thị + số bản | 25/11: CFBundleDisplayName Zokervie, MARKETING_VERSION 1.0 (R6); bundle ID đổi sau (cần sửa 1 dòng kiểm trong workflow CI, chờ anh cho phép) | | anh |

## Nguyên tắc "tử tế" (ngoài luật Apple, anh đặt ra)
- Không bán chỉ số hay lợi thế; gậy thưởng chỉ khác hình (đã chốt 24/11).
- Không ép quảng cáo, không thông báo dụ dỗ, không đếm ngược giả tạo, không làm khó việc huỷ gói.
- Không thu dữ liệu khi không cần; mọi số liệu luyện tập nằm trên máy người chơi.
- Nói thật về độ chính xác vật lý: có trang nguồn + sai số; chỗ chưa chắc ghi "thử nghiệm".
- Ghi công đầy đủ: font, âm thanh, số liệu tham khảo, công cụ AI dùng cho ảnh/hiệu ứng.

## Trước mỗi lần nộp
Chạy lại bảng này, cập nhật cột trạng thái kèm bằng chứng; người kiểm không phải người viết code của mục đó.
