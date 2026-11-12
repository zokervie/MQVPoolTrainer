# Lịch sử quyết định của anh (chuyển từ CLAUDE.md ngày 13/11/2026 để mỗi phiên đỡ tốn token)

Đọc khi cần tra vì sao một tính năng được làm như vậy. Trạng thái hiện tại: `Docs/TRANG-THAI.md`.

## 0.40 (anh "chấp thuận" toàn bộ đề xuất từ 0.38 tới nay, 11/11/2026 18:02)
- Bàn: kích thước chuẩn WPA + họ kiểu dáng phổ biến 2026, chi tiết trang trí riêng, tên Z- (không chép 100% thương hiệu).
- Âm thanh: ~40 mẫu CC0/CC-BY (Freesound) + Sonniss GDC + mẫu anh tự thu (em soạn kịch bản thu); 3 mức lực × 3–4 biến thể, tiếng lăn liên tục theo tốc độ, lỗ theo loại bàn, break/nhảy/massé/trượt típ, không gian âm theo phòng, giới hạn số tiếng. KHÔNG lấy tiếng YouTube.
- Vật lý mới (test C++ trước): bi văng khỏi bàn, đập mép gỗ, nảy trên sàn theo vật liệu phòng.
- Kỹ thuật: vật lý chạy luồng riêng, bỏ cấp phát mỗi khung; CI đo tỉ lệ khung trễ; bộ so sánh 20 cú mẫu với video thật; "phòng chuẩn" chụp ảnh so trước/sau mỗi bản; cờ tính năng cho gói IAP.
- Trải nghiệm: mẫu đèn "Thi đấu" 520 lux; hướng dẫn tương tác 3 bước lần đầu; bảng tiến bộ hằng tuần; thử thách hằng ngày + bảng xếp hạng Game Center.
- Đo bàn thật: anh quay 5 cú 240 fps ở CLB để hiệu chỉnh hệ số (chờ anh).
- Nghiên cứu tính năng 2026 (Project doc `claude/zoker-nghien-cuu-tinh-nang-2026.md`) — anh duyệt lưu và sẽ làm theo lộ trình: 0.40 khung IAP (cờ + StoreKit 2), bài mỗi ngày + chuỗi ngày, "Giữ mắt", "Vì sao trượt" (phân tích), Z-Exam v1; 0.41 bóng ma + Game Center, giải tuần, thống kê, chia sẻ link/QR, rung+âm, AI coach, mở bán; sau: ảnh bàn → thế bi, Apple Watch, SharePlay, RealityKit, AR.
- (anh dặn 11/11 18:29) Đấu với máy 6 cấp: Beginner · Amateur · Quarter Pro · Semi Pro · Pro · AI; chọn luật (8/9/10 Ball, 15 Rotation, …), race. Máy chọn cú bằng tìm kiếm trên lõi vật lý tất định (ứng viên cú → mô phỏng → chấm điểm vào lỗ + vị trí + phòng thủ), cấp độ = sai số thực thi (góc/lực/xoáy) + độ sâu tính toán (vị trí 0–3 bi, phòng thủ, kick thoát). Viết test C++ trước (tỉ lệ vào theo cấp nằm trong khoảng mục tiêu). Chạy ở luồng riêng.
- (anh dặn 11/11 18:29) Sắp xếp lại giao diện và hạng mục cho hợp lý, dễ dùng.

## 0.39 (anh nghiệm thu 0.38 ngày 11/11 + 7 phát hiện)
Đồng bộ khung hình (bi trôi), chỉ bi đổ bóng (kiểu 0.19) + gậy không đổ bóng bản đồ, gậy mờ khi che hướng ngắm, sợi nỉ 0,6 mm, típ vòm 4,5 mm, nỉ cũ chấm li ti/bi cũ đục, sàn hết sọc, bỏ viền kim loại, Wi‑Fi break được, bảng điểm kiểu TV, cảnh đầu xem lại thấp hơn, Tuỳ chỉnh 5 thẻ, sảnh gọn. Bàn theo thương hiệu thật: KHÔNG chép 100% kiểu dáng/tên (rủi ro kiểu dáng công nghiệp khi bán app) — dùng kích thước chuẩn WPA + họ kiểu dáng phổ biến, tên Z-.

## 0.38 = 0.37 + toàn bộ đề xuất còn lại (anh duyệt hết 09/11/2026 22:21)
Nút số tự hiện khi ngắm chạm băng; chấm độ đều tay; đường chỉ dẫn mờ theo trình độ; góc ngắm mặc định; kích thước/độ trong phím; lưu 3 bố cục; màu/độ dày đường ngắm; độ rõ vân nỉ; đường dự đoán theo độ dốc tự nâng; tự tăng lại chất lượng; xuất video highlight.

## 0.37 (anh duyệt 09/11/2026 21:34 — gộp tất cả)
Sửa: lag (chỉ bi đổ bóng, tự hạ chất lượng), sọc nỉ = phân tầng màu (dithering, nỉ không bóng, vân mờ sớm), sọc viền/yếm (bóng tự đổ), bo góc gỗ; bi bớt chói + bóng mềm; cơ không xuyên băng/bi, dốc tự nâng đồng bộ thanh dốc; kiểm tra va chạm khi bi bay; xem lại 1,5 s trước/sau + 3 cảnh điện ảnh; logo "Zoker Pool / Trainer"; khoá chỉ bằng B (công tắc bi effect khoá trong Tuỳ chỉnh, mặc định tắt).
Thêm: Tuỳ chỉnh độ chói bi + độ đậm bóng; mẫu loại bàn (nhanh/chuẩn/chậm); vạch vùng thực tế trên thanh vật lý; phím tự mờ khi ngắm; dự đoán rồi hiện đường đúng (lệch °); mẫu ánh sáng (Câu lạc bộ/TV/Dịu mắt); Sảnh chính (Luyện tập/Thi đấu/Hồ sơ) + menu trong trận 5 mục + Tuỳ chỉnh 4 thẻ + màu theo chế độ.
