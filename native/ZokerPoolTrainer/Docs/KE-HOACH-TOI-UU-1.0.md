# Kế hoạch tối ưu Zokervie tới bản 1.0 và sau đó (lập 26/11/2026)

Anh giao 26/11 01:02: lập kế hoạch sửa 20 điểm chê và đưa các đề xuất công nghệ vào, tối ưu và đầy đủ.
Căn cứ: `claude/zoker-20-diem-che-va-huong-toi-uu-2026-11-26.md` (Project), code tại 5d7d970 (`cho/native-0.59-loi`), `Docs/KIEM-DINH-APP-REVIEW.md`, `Docs/KE-HOACH-HIEU-CHUAN-0.60.md`, `Docs/NHIEM-VU-0.59-*.md`.
Mọi ngưỡng số trong file này là ĐỀ XUẤT, chờ anh duyệt. Kế hoạch chưa được thi công: chưa mục nào "xong".

## 0. Nguyên tắc
1. Mỗi đợt một mục tiêu. Không mở việc mới khi đợt trước chưa được anh nghiệm thu.
2. Người viết không tự nghiệm thu. Mỗi mục có tiêu chí đo được và bằng chứng (log, ảnh, số).
3. Công nghệ mới phải qua "cổng thử" 2–3 ngày, có tiêu chí đi tiếp hoặc dừng, trước khi vào kế hoạch chính.
4. Game tử tế: không bán lợi thế, không ép chờ, không thu dữ liệu khi không cần, nói thật về độ chính xác.
5. Hai làn chạy song song để không tranh máy: **làn Mac** (Swift, biên dịch, Simulator, CI) và **làn mây** (C++ trên Linux, thiết kế, tài liệu, video, âm thanh).

## 1. Lộ trình

| Đợt | Mục tiêu | Làn Mac | Làn mây | Bắt đầu khi | Xong khi |
|---|---|---|---|---|---|
| 0. Thông đường | Code đêm 25–26/11 biên dịch được | Gộp `work/0.59` (dcee5e7) với `cho/native-0.59-loi` (5d7d970); biên dịch; sửa lỗi cú pháp; CI 174 | — | Anh đẩy bundle `zoker-059-ke-hoach.bundle` | CI xanh `PASSED_SIMULATOR_UNSIGNED`, IPA gửi anh |
| 1. 0.59 "Sửa cho đúng" | Hết lỗi anh đã báo, thương hiệu Zokervie thống nhất | U1–U6, B1–B7, sảnh mới + bao cơ + xem lại theo thiết kế 26/11, nối intro (6 giây lần đầu, 1,5 giây các lần sau, chạm bỏ qua) | Intro C bản chính 1080p60 + bản 1,5 giây; âm thanh thương hiệu v2; ảnh tường mới (cùng anh) | Đợt 0 xong | Anh thử máy thật theo tờ nghiệm thu 0.59, từng mục Đạt/Chưa |
| 2. Nền móng đo được | Biết app hỏng ở đâu mà không cần anh nhìn | MetricKit + "Gửi chẩn đoán"; iCloud cho tiến độ; nén ảnh nỉ; 6 ảnh chuẩn mỗi CI; job CI "chỉ biên dịch" (cần anh cho phép sửa workflow) | Dọn tên file/khoá theo danh sách (không đổi hành vi); tách phần Swift thuần logic để Linux biên dịch | Đợt 1 nghiệm thu | Số đo có trong báo cáo CI; cài lại app không mất sao |
| 3. Phút đầu + người thật | 20–50 người chơi bida dùng thử | Chế độ Đơn giản mặc định; cỡ chữ co giãn và bảng/thẻ riêng cho 5 màn dùng nhiều nhất; TestFlight | Tờ hướng dẫn người thử, bảng hỏi 5 câu, bộ đếm ngày quay lại | Anh có tài khoản Apple Developer | Có số quay lại ngày 1 và ngày 7 của ≥ 20 người + 5 cuộc hỏi chuyện |
| 4. 0.60 "Tin được, học được" | Vật lý có nguồn, máy dạy được người, Carom thử nghiệm | Giao diện Phân tích ván, trang "Về vật lý", phòng tập Carom (nhánh riêng), âm thanh mới | Hiệu chuẩn 4 nguồn; máy đối thủ P0–P4 (mục 3); lõi Carom C++; thẻ kết quả, bóng ma (mục 4). Phần C++ làm song song từ bây giờ | Lõi C++: ngay. Giao diện: sau đợt 1 | Test C++ theo số liệu đã công bố PASS; tự đấu đạt chỉ tiêu mục 3; anh nghiệm thu |
| 5. 1.0 nộp App Store | Qua duyệt, bản đầu không bán gì | Phần còn lại của bảng/thẻ riêng; đổi bundle ID; chạy lại `KIEM-DINH-APP-REVIEW.md` | Mô tả, ảnh chụp từ app thật, video giới thiệu mở bằng intro | Đợt 3 có số liệu, đợt 4 nghiệm thu | Apple duyệt |
| 6. 1.1 trở đi | Doanh thu và công nghệ mới | StoreKit 2: gói trọn đời + gói bài; mở đồ bằng sao | Các cổng thử ở mục 5, mỗi lần một cổng | 1.0 đã lên | Từng cổng có kết luận đi tiếp/dừng |

Carom là nhánh riêng nên không chặn bản nộp 1.0. Nếu sai số hệ kim cương > 0,5 nút thì ghi nhãn thử nghiệm (đã chốt 25/11).

## 2. Hai mươi điểm chê → việc cụ thể

| # | Điểm chê | Việc làm | Đợt | Làn | Nghiệm thu (đề xuất) |
|---|---|---|---|---|---|
| 1 | 61 hộp thoại hệ thống làm menu | Bộ thành phần `ZSheet` (bảng trượt) + `ZCard` + `ZSegment` theo màu thương hiệu; thay theo thứ tự: Bao cơ, Bàn, menu trận, Xem lại, Tuỳ chỉnh | 3 → 5 | Mac | Đếm `UIAlertController(` còn ≤ 15 (chỉ xác nhận/lỗi); ảnh trước–sau 5 màn |
| 2 | 137 cỡ chữ cố định, 30 nhãn trợ năng | Hệ 5 bậc chữ co giãn trong `ZDesign`; nhãn trợ năng cho mọi nút HUD và sảnh | 3 | Mac | 5 màn chính đọc được ở cỡ chữ lớn nhất của máy, không cắt chữ (ảnh); VoiceOver đi hết sảnh |
| 3 | Sảnh lộ mã, tên sai, tràn, trống | Đã sửa 2 lỗi (5d7d970). Code sảnh theo thiết kế 26/11 | 1 | Mac | Đủ mọi lối vào của sảnh cũ (đối chiếu `TC+Menu.swift`); không nút nào bị cắt ở iPhone SE và iPad |
| 4 | Ra cơ khó với người mới | Chế độ Đơn giản: kéo–thả một ngón, ẩn nâng cơ/xoáy ngang; mở dần theo chương; chế độ hiện tại đổi tên "Đầy đủ" | 3 | Mac | Người mới đánh vào cú đầu ≤ 30 giây, đo trên 5 người thử |
| 5 | Bao cơ, Xem lại trùng và nhiều chạm | Bảng Bao cơ 3 thẻ; nút vàng Xem lại (đã có code); Tuỳ chỉnh › Xem lại: Điện ảnh / Nhanh / Tắt, chạm = tua 2× | 1 | Mac | Đổi cơ ≤ 2 chạm; xem lại 1 chạm; UI test mới |
| 6 | Chưa có người chơi thật | TestFlight 20–50 người (nhóm quán, nhóm Facebook); bộ đếm ngày mở app lưu trên máy; nút Gửi số liệu | 3 | anh + mây | Quay lại ngày 7: ≥ 15 % mở rộng; 4–15 % sửa rồi đo lại; < 4 % sau hai vòng: xem lại định vị |
| 7 | Phạm vi nở nhanh hơn nghiệm thu | Nguyên tắc 1 ở mục 0; ý tưởng mới ghi vào `zoker-so-y-tuong-backlog.md`, không vào đợt đang chạy | ngay | anh + em | Mỗi đợt đóng bằng tờ nghiệm thu trước khi mở đợt sau |
| 8 | Không đo được lỗi của người lạ | MetricKit (treo, giật, crash) lưu trên máy; màn "Gửi chẩn đoán" người chơi tự bấm | 2 | Mac | Báo cáo mẫu từ máy anh; nhãn quyền riêng tư vẫn "không thu dữ liệu" nếu chỉ gửi khi người chơi bấm (kiểm lại với `KIEM-DINH`) |
| 9 | Tiến độ không đồng bộ | Gom `PlayerStore` thành một tệp có số phiên bản; đồng bộ iCloud key-value (≤ 1 MB); xung đột: lấy sao cao hơn, chuỗi dài hơn | 2 | Mac | Xoá app, cài lại, cùng Apple ID: sao và chuỗi còn (thử trên máy thật) |
| 10 | Chưa có đường doanh thu | 1.0 không bán. 1.1: gói trọn đời + gói bài (Z-Drill, Z-Lab), có Khôi phục giao dịch; bàn/cơ/phòng mở bằng sao | 6 | Mac | Thử bằng tệp `.storekit`; `ios-build-preflight` PASS |
| 11 | Viết Swift không biên dịch; anh là nút cổ chai | Job CI "chỉ biên dịch" ~10 phút; toolchain Swift trên Linux cho tệp thuần logic; vai giám khảo độc lập đọc diff trước khi báo anh | 2 | Mac + mây | Lỗi cú pháp bị bắt trước CI đủ; mỗi bản có biên bản giám khảo |
| 12 | Code khó bảo trì | Đổi tên ~60 tệp mang số phiên bản; tách `MatchPlayController` (2.037 dòng) và `TableScene` (2.487 dòng) theo chức năng; gom cờ QA | 2 | mây chuẩn bị danh sách, Mac thi công | Không đổi hành vi: toàn bộ test hiện có PASS trước và sau; không tệp nào > 1.200 dòng |
| 13 | Ảnh nỉ 35 MB + 13 MB PNG thô | Nén ASTC, có mipmap; 2048² cho iPhone, 4096² cho iPad Pro | 2 | Mac | Bộ nhớ đỉnh giảm (số MetricKit trước–sau); ảnh chuẩn không khác nhìn thấy được |
| 14 | Hệ số vật lý còn "giả định" | `KE-HOACH-HIEU-CHUAN-0.60.md`: bảng hệ số có nguồn, test theo số đã công bố, bộ cú giữ riêng, đối chiếu chéo, trang "Về vật lý" | 4 | mây | Bộ cú giữ riêng trong sai số đã ghi; mỗi hệ số có nhãn nguồn |
| 15 | Wi-Fi chập chờn; Online ẩn | U1: đặt bi cục bộ, chạm để đặt, đo độ trễ. Online chỉ mở khi có máy chủ ổn định và khai báo với Apple | 1 (U1) | Mac | 2 máy thật: 20 lượt đặt bi không trượt; độ trễ hiển thị |
| 16 | Vòng CI ~50 phút | Biên dịch tăng dần trên Mac; tách test nhanh (mỗi commit) và chậm (trước IPA) | 2 | Mac | Vòng phản hồi lỗi cú pháp < 10 phút |
| 17 | Cả game 7 mẫu âm | Bảng thu: bi–bi, băng, lỗ, cơ × 3 mức lực × 4 biến thể; tiếng lăn theo tốc độ; vang theo phòng. Anh thu hoặc chọn gói CC0; em viết bộ chọn mẫu theo lực | 4 | anh + Mac | Nghe mù A/B (kỹ năng `dsp-ab-listening`): bản mới được chọn ≥ 8/10 lần |
| 18 | Chưa có chữ ký âm thanh | Hai tiếng "cộc" + ba nốt chuông (mục 6) dùng ở intro, qua bài, thắng ván, video xuất | 1 | mây + Mac | Anh duyệt bằng tai; cùng một tệp nguồn ở mọi chỗ |
| 19 | Cơ loá, mesh thừa, ảnh tường cũ, hình cơ vạch trắng | B6, U4, B7; hình cơ thật trên thẻ Bao cơ | 1 | Mac + anh | Ảnh phòng chuẩn trước–sau từng mục |
| 20 | Lỗi hình ảnh chỉ thấy bằng mắt anh | 6 góc chụp cố định mỗi CI, so điểm ảnh với ảnh gốc, lệch quá ngưỡng thì báo | 2 | Mac | Cố ý đổi màu nỉ → CI báo; đổi không liên quan → không báo |

## 3. Máy đối thủ: giỏi hơn và dạy được

| Bước | Việc | Nghiệm thu (đề xuất) |
|---|---|---|
| P0 | `AiBench`: tự đấu có hạt giống cố định, đo tỉ lệ vào, lỗi, thời gian nghĩ | Chạy trên Linux CI; thời gian quyết định 95 % ≤ 3 giây (trên iPhone: chưa xác minh) |
| P1 | Sổ cú phá tính sẵn cho 8/9/10 bi × cấp (vị trí bi cái, lực, điểm chạm); theo break box của U2 | Cấp 5, 9 bi: phá có bi vào 58–75 %, phạm lỗi ≤ 5 % (theo số giải thật trong `zoker-ai-bida-pro-0.42.md`) |
| P2 | Thủ, cú hai chiều và push-out tính theo kỳ vọng thay cho ngưỡng cứng và "accept" | Bản mới thắng bản cũ cùng cấp ≥ 55 % trên 1.000 ván |
| P3 | Lỗi giống người: sai số tăng theo độ khó (cắt mỏng, cú dài, bi dính băng, nâng cơ); mỗi cấp một tính cách (bảng dưới) | Cấp trên thắng cấp ngay dưới 60–70 %; người thử đoán đúng "cấp nào mạnh hơn" |
| P4 | **Phân tích ván**: sau trận, mỗi cú của người chơi được so với 3 phương án máy đã tính (kèm % và một dòng lý do) | Giải thích khớp số liệu máy tính 20/20 cú mẫu; anh nghiệm thu |
| P5 | Mạng nhỏ chấm thế bi, học từ tự đấu (tuỳ chọn) | Chỉ giữ nếu thắng cách cũ ≥ 55 % và không làm chậm quá 3 giây |

| Cấp | Tính cách | Dấu hiệu người chơi thấy |
|---|---|---|
| 1 | Tay mơ | Hay quá lực, không tính bi sau, né cú băng |
| 2 | Khách quen | Chắc cú ngắn, hỏng cú dài và cắt mỏng |
| 3 | Triển vọng | Biết đẩy/kéo bi cái, thủ đơn giản, chạy 2–3 bi |
| 4 | Bán chuyên | Tính trước hai cú, xoáy ngang khi cần, kick một băng |
| 5 | Chuyên | Phá theo sổ, thủ có tính toán, thỉnh thoảng dọn bàn |
| 6 | Thầy | Gần như không trượt, luôn giải thích cú đánh |

Không ghi "tương đương hạng X" trong app khi chưa đo với người thật.

## 4. Ba vòng giữ chân (lành mạnh)

| Vòng | Đã có | Thiếu | Đợt |
|---|---|---|---|
| Suýt được → đánh lại | Lùi cú, chấm đạt/chưa | Một dòng "lệch bao nhiêu, sửa gì" từ số liệu lõi; đánh lại ≤ 2 giây; chỉ số tay nghề hiện sau buổi | 4 |
| Đề chung mỗi ngày | Thế bí của ngày, chuỗi ngày, Bài hôm nay | Thẻ kết quả để chia sẻ; ngày nghỉ không mất chuỗi (không bán cứu chuỗi) | 4 |
| Người quen | Thách bạn bằng mã | Bóng ma (bản ghi của bạn hoặc của mình hôm qua); bảng nhóm quán không cần máy chủ (đổi mã) | 4 → 6 |

Không làm: bắt chờ hồi lượt, hộp may rủi, thông báo dồn dập, đếm ngược giả.

## 5. Công nghệ mới: mỗi thứ một cổng thử

| # | Công nghệ | Cổng thử (2–3 ngày) | Đi tiếp khi | Rủi ro, ghi chú |
|---|---|---|---|---|
| 1 | Huấn luyện viên tiếng Việt chạy trên máy (Foundation Models, iOS 27) | 20 cú trượt mẫu → câu giải thích từ số liệu lõi | ≥ 18/20 câu đúng số liệu, trễ < 2 giây | Máy đời cũ dùng câu mẫu cố định. Nếu dùng máy chủ của Apple: phải hỏi đồng ý (5.1.2(i)). Máy nào chạy được: chưa xác minh |
| 2 | Camera quét bàn thật → thế bi | 30 ảnh anh chụp từ trên xuống ở quán | Vị trí bi lệch trung vị ≤ 3 cm; có bước sửa tay | Ánh sáng quán, bi che nhau. Xin quyền camera, không gửi ảnh đi đâu |
| 3 | Âm thanh và rung sinh từ vật lý | Tổng hợp tiếng va chạm thời gian thực trong `AVAudioEngine` | CPU < 5 % trên iPhone đời cũ; nghe mù thắng mẫu thu ≥ 6/10 | Không cấp phát bộ nhớ trong luồng âm thanh |
| 4 | Apple Watch / AirPods đo động tác | 50 cú ở bàn thật, đối chiếu video | Phát hiện ngẩng đầu đúng ≥ 80 % | Cần target Watch riêng; độ chính xác chưa ai thử |
| 5 | Thực tế tăng cường | Bàn tỉ lệ thật đặt trong phòng | Giữ 60 khung/giây, bàn không trôi | Làm sau cùng; chiếu lên bàn thật là bước xa hơn |

Thứ tự đề nghị: 1 (gắn với Phân tích ván) → 3 (thế mạnh của anh) → 2 → 4 → 5.

## 6. Intro và âm thanh thương hiệu
- Hình: kịch bản C "Cú đánh hai băng", 6 giây. Dòng chữ: ZOKERVIE lớn + BILLIARDS nhỏ bên dưới (đề xuất 26/11, chờ anh duyệt trên ảnh thử). Bản 1,5 giây cho các lần mở sau.
- Lỗi phải sửa trước bản chính: khung nhoè sau chớp sáng (đã sửa trong kịch bản v3, chưa render lại cả đoạn), thanh vàng trên nhạt, tiếng không tự ghép (đã sửa đường dẫn).
- Âm thanh: không chèn bản nhạc nền riêng dưới 6 giây intro. Thay vào đó cho chính hiệu ứng thành giai điệu: hai tiếng chạm băng lên đúng nốt La và Rê, nối vào ba nốt chuông Rê–La–Rê; nền trầm giữ La rồi giải về Rê. Năm nốt này là chữ ký âm thanh.
- Nhạc nền chỉ ở sảnh: vào nhẹ sau intro, cùng giọng Rê, người chơi tắt được.
- Mốc thời gian để anh tự thu thay tiếng tổng hợp: thúc bi 0,90 · chuyển cảnh 1,30 · băng một 2,40 · băng hai 3,20 · dồn 3,45 · chốt 3,95 · ba thanh 4,00 / 4,15 / 4,30 · chuông 4,75 / 4,91 / 5,07 (giây).

## 7. Đo và mốc dừng
- Mỗi đợt: tờ nghiệm thu có cột Đạt / Chưa / Chưa thử, kèm bằng chứng.
- Số theo dõi: thời gian tới cú vào đầu tiên; quay lại ngày 1 và 7; số buổi mỗi tuần; tỉ lệ bấm Xem lại; treo/giật từ MetricKit.
- Mốc dừng ở điểm 6 (bảng mục 2). Với 50 người, sai số quanh mốc 15 % khoảng ±10 điểm, nên phải kèm hỏi chuyện 5–10 người.

## 8. Quyết định cần anh
1. Duyệt thứ tự 6 đợt và hai làn ở mục 1.
2. Cho phép thêm job CI "chỉ biên dịch" và sửa dòng kiểm bundle ID trong workflow (hai thay đổi CI, em không tự làm).
3. Thời điểm mở tài khoản Apple Developer: đợt 3 cần nó.
4. Dòng chữ intro: ZOKERVIE + BILLIARDS nhỏ, hay chỉ ZOKERVIE.
5. Các ngưỡng nghiệm thu ở mục 2, 3, 5: giữ hay chỉnh.
