# Nhiệm vụ bản kế tiếp (0.41) — Zoker Pool Trainer

Anh duyệt ngày 12/11/2026. Gồm 3 đề xuất ngày 12/11 cộng phần tối ưu giao diện, âm thanh, logo và intro khi mở app.
Quy tắc chung: mỗi khối có cờ tính năng riêng (để khoá/mở theo gói IAP); phần vật lý thì viết test C++ trước; mục nào cần máy thật thì ghi "chưa xác minh trên thiết bị".

## A. Ba đề xuất đã duyệt 12/11
- **Bàn nhà tôi** (gói Z-Lab)
  - Màn đo 3 bước: (1) đánh bi dọc bàn, bấm giờ đến khi bi dừng; (2) đếm số lần chạm băng; (3) đặt tên rồi lưu hồ sơ bàn.
  - Từ số đo suy ra hệ số lăn và độ nảy băng, kẹp trong khoảng an toàn; test C++ cho phần đổi số đo ra hệ số.
  - Lưu được 3 hồ sơ bàn; chọn bàn trong Tuỳ chỉnh → Vật lý.
- **Cú quyết định — luyện dưới áp lực** (gói Z-Drill, bộ "Áp lực"; cho thử 1 bài miễn phí)
  - Đồng hồ cú 30 s, mỗi ván 1 lần gia hạn; vòng đếm quanh bi chủ, rung nhẹ ở 10 s và 5 s cuối.
  - Luật "phải vào mới qua bài"; trượt thì mất chuỗi trong bài.
  - Tiếng khán giả nền, im dần lúc ra cơ (lấy CC0 hoặc tự thu, không lấy YouTube).
  - Dùng lại bài mỗi ngày và chế độ đấu máy, chỉ thêm lớp luật.
- **Live Activity + widget** (miễn phí; kiểu widget đẹp bán trong Z-Style)
  - Widget màn hình chính và màn khoá: số ngày chuỗi, bài hôm nay, nút mở thẳng vào bài.
  - Live Activity / Dynamic Island khi đấu Wi‑Fi: tỉ số, "Đến lượt bạn", đồng hồ cú.
  - Báo đẩy cho chế độ online để bản sau, vì cần máy chủ.

## B. Intro khi mở app
- Màn khởi động tĩnh (Launch Screen) trùng đúng khung đầu của intro: nền nỉ tối cùng biểu tượng Z, để lúc chuyển không bị chớp.
- Intro dài tối đa 2,5 s, chạm để bỏ qua. Từ lần mở thứ 2 trở đi chỉ còn 0,8 s (hiện logo rồi vào Sảnh).
- Kịch bản intro, dựng thật bằng SceneKit và lõi vật lý (không dùng video):
  - Camera thấp sát mặt nỉ, đèn bàn bật dần.
  - Bi chủ lăn vào, đánh 1 bi vào lỗ góc.
  - Tiếng "cốc" và tiếng rơi lỗ đúng nhịp va chạm.
  - Logo hiện lên cùng lúc bi rơi lỗ.
- Trong lúc intro chạy thì tải sẵn trong nền: biên dịch shader, nạp âm thanh, nạp Sảnh. Như vậy intro không làm mở app chậm thêm.
- Tôn trọng "Giảm chuyển động" của iOS: khi bật thì chỉ làm mờ dần logo, không có cảnh 3D.
- Mở lần đầu: intro xong vào thẳng hướng dẫn tương tác 3 bước (đã duyệt ở 0.40), không vào Sảnh.
- CI đo thời gian từ chạm biểu tượng đến lúc dùng được Sảnh: mục tiêu ≤ 1,5 s trên Simulator, ghi số mỗi bản.

## C. Logo và nhận diện
- Thay chữ "ZOKER POOL · Trainer" đang gõ bằng font hệ thống bằng bộ nhận diện riêng:
  - Biểu tượng chữ Z: nét Z là đường bi chạm băng rồi bật ra (kiểu bank shot).
  - Dấu chấm cuối nét là bi chủ.
- Bộ file vector (PDF/SVG) có 3 dạng:
  - Biểu tượng đứng riêng.
  - Biểu tượng kèm chữ nằm ngang.
  - Một màu (dùng cho yếm bàn, watermark video highlight, widget).
- Icon app iOS 26 có đủ 3 bản: Sáng · Tối · Tint. Mỗi lớp tách riêng để hệ thống tự làm hiệu ứng Liquid Glass.
  - Thử độ rõ ở cỡ 29 pt.
  - Không dùng chữ trong icon.
- Logo trên yếm bàn (`apronLogo`) đổi sang biểu tượng Z một màu dập chìm, thay cho chữ in.
- Bảng màu thương hiệu (3 màu chính + 2 màu nhấn) đặt thành token chung. Màn Sảnh, Tuỳ chỉnh và bảng điểm cùng lấy màu từ đây (hiện mỗi màn tự đặt màu riêng).
- Kiểm tra tên và logo không trùng thương hiệu bida thật trước khi lên App Store.

## D. Giao diện (tối ưu)
- Một hệ thiết kế chung, thay cho việc mỗi màn tự đặt cỡ chữ và màu:
  - Thang chữ 5 cỡ.
  - Khoảng cách theo lưới 8 pt.
  - Bo góc 3 mức.
  - Phím tối thiểu 44 pt.
  - Hỗ trợ Dynamic Type đến cỡ XL.
- Sảnh:
  - Thẻ "Tiếp tục" nằm trên cùng (bài hoặc ván đang dở).
  - Bên dưới là 3 thẻ Luyện tập · Thi đấu · Hồ sơ.
  - Mỗi thẻ có ảnh xem trước dựng từ bàn thật trong app.
- Trong trận: các phím gom về một cạnh theo tay thuận (thêm lựa chọn tay trái); phím không dùng tới thì tự ẩn khi ngắm (mở rộng tính năng phím tự mờ đã có).
- Chuyển cảnh giữa các màn dài 0,25–0,35 s, kiểu chuyển giống nhau ở mọi nơi; bỏ các chuyển cảnh mặc định lẫn lộn.
- Phản hồi khi chạm: rung nhẹ cho nút, rung vừa khi xác nhận cú, rung đúng nhịp va chạm bi (đã duyệt ở 0.41, gộp chung một bộ quản lý rung).
- Chế độ tối là mặc định; tương phản chữ đạt chuẩn WCAG AA; VoiceOver đọc đúng tên các nút chính.
- iPad: Sảnh 2 cột; trong trận đặt bảng điểm và phím ở cột bên, nhường mặt bàn tối đa.
- "Phòng chuẩn" của CI chụp thêm Sảnh, Tuỳ chỉnh và intro ở 3 cỡ máy (iPhone SE, iPhone Pro Max, iPad) để so trước/sau mỗi bản.

## E. Âm thanh (nối tiếp kế hoạch 0.40)
- Hiện mới có 7 mẫu (4 bi, 1 cơ, 1 băng, 1 lỗ). Ưu tiên bổ sung theo thứ tự:
  - Cơ và băng: 3 mức lực × 3 biến thể.
  - Lỗ: 2 loại (lưới và máng).
  - Tiếng bi lăn chạy liên tục theo tốc độ.
- Tiếng giao diện riêng (bấm nút, mở thẻ, đạt chuỗi, qua bài): ngắn dưới 120 ms, cùng tông với tiếng gỗ/bi để nghe liền mạch, tự soạn hoặc CC0.
- Nhạc nền Sảnh và intro: một chủ đề ngắn, lặp liền mạch, nguồn có giấy phép thương mại hoặc tự sáng tác; khi vào trận thì tự nhỏ dần.
- Trộn âm theo 3 nhóm, mỗi nhóm có thanh chỉnh riêng trong Tuỳ chỉnh → Máy·Âm thanh:
  - Hiệu ứng bàn.
  - Giao diện.
  - Nhạc / khán giả.
- Chuẩn mức âm lượng: đỉnh ≤ −1 dBTP, các nhóm cân nhau; khi đánh liên tục không bị vỡ tiếng.
- Tắt tiếng khi máy ở chế độ im lặng (trừ khi người chơi bật "luôn phát"). Khi có cuộc gọi hoặc app khác phát nhạc thì nhường tiếng đúng cách.
- Đo độ trễ từ va chạm đến lúc nghe tiếng trên máy thật, qua loa máy và qua tai nghe Bluetooth (chưa xác minh trên thiết bị).
- Giữ nguyên quy tắc: không lấy tiếng từ YouTube; mọi mẫu đều ghi vào `manifest.json` + `ATTRIBUTION.md`.

## F. Còn chờ anh
- Quay 5 cú chuẩn ở CLB, 240 fps.
- Thu âm theo kịch bản 15 phút.
- Chọn 1 trong 3 phương án logo Z khi em gửi bản phác.
