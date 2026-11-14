# 0.43 — việc đã chốt danh sách, CHỜ GOM (anh dặn 14/11 15:33)

Anh: "lưu lại tất cả việc cần làm trước mắt, chờ anh bổ sung nhiệm vụ và video để làm luôn một thể".
→ KHÔNG code, KHÔNG build cho tới khi anh gửi thêm nhiệm vụ/video và nói "làm" / "chấp thuận".
Nền: `e12c8ca` (= IPA 0.42b, CI 140 xanh). Mọi phát hiện dưới đây đã kiểm trên mã thật (14/11).

## A. Đợt 1 — điểm chạm, nhất quán, độ mượt (không cần video)
| # | Việc | Bằng chứng | Test giữ cửa |
|---|---|---|---|
| A1 | **Một nguồn giới hạn điểm chạm.** Hiện 3 nơi 3 số: `TrainingController.swift:1061` (0,70 / nâng 0,60 / tẩy mềm +0,08), `TableScene.swift:1834` cuePose (0,70/0,60), lõi `Physics.hpp:54` (0,55/0,50/+0,05). Lõi xuất hàm `BLTipMaxOffset(elevated,tip)`; bi effect, cơ 3D, `shotAngle`, AI (`TrainingController.swift:2143`), replay dùng chung. Replay lưu điểm chạm ĐÃ ÁP DỤNG. | Commit bf1051b (0.31) hạ lõi xuống .55, quên giao diện. Hướng đánh lấy từ 0,70, xoáy từ 0,55 → 2 điểm chạm khác nhau trong cùng 1 cú. | C++: giới hạn lõi = giá trị cầu nối trả về; XCTest: `spin.maximumOffset == BLTipMaxOffset` ở cơ thường/nâng/jump/phá/massé |
| A2 | **Hướng bi khi cơ ngang.** `cuePose` xoay hướng đánh quanh tay sau 1,12 m → bi lệch 0,82° VỀ PHÍA effect (0,55R), 1,04° (0,70R). Thực tế squirt ~2,5° phía ngược lại. Trái quyết định 03/11 (cơ ngang = đi đúng đường ngắm). Tách: hình cơ giữ, hướng vận tốc = đường ngắm (+ squirt nếu bật tuỳ chọn A5). | Tính tay; code từ bản bàn giao 3bea7da | Cơ ngang, effect 0,55: hướng bi = đường ngắm ±0,05° |
| A3 | **Độ mượt lúc chơi.** Mỗi 1/240 s khi bi nhanh: `engine.states.map{BallState}` (tới 4 lần/khung, `TrainingController.swift:1579`) + đọc `UserDefaults` mỗi va chạm, trên luồng giao diện; replay không làm → khớp hiện tượng "chơi giật, xem lại mượt". Sửa: lõi C++ tự ghi khung hình, Swift lấy 1 lần khi bi dừng; đọc cài đặt 1 lần/cú. KHÔNG tách luồng mô phỏng (rủi ro cao, không phải chỗ tốn). Xem thêm: SCNView và CADisplayLink là 2 đồng hồ (đo trước khi sửa). | Đọc mã | Ghi `shotProfile` live vs replay; ngưỡng: p95 ≤ 17,5 ms, ≤ 1 khựng > 25 ms/cú |
| A4 | Rút bộ test Opponent 228 s → < 60 s (CI). | Chạy lại 14/11: 337/337 đạt, 228,6 s | Vẫn đủ 337 kiểm tra |
| A5 | **Tuỳ chọn "Squirt thực tế"** (Tuỳ chỉnh, cờ Z-Lab). Mặc định giữ squirt = 0 khi cơ ngang (quyết định 03/11). | Shadow + TP A.31/B.26 | Bật: squirt theo TP A.31 ở mọi độ nâng |
| A6 | Ghi rõ "Thân bar-box · mặt 9 ft" trên thẻ bàn (`EquipmentLibrary.swift:34`). | Đọc mã | — |

**3 câu chờ anh chọn (hỏi 14/11 12:38, chưa trả lời):**
1. Effect quá 0,55R: (a) chặn ở 0,55R [em đề xuất] hay (b) cho tới 0,65R, vùng ngoài = trượt cơ (miscue).
2. Squirt khi cơ ngang: giữ 0 làm mặc định + thêm tuỳ chọn "Squirt thực tế" [em đề xuất].
3. Chấp nhận effect mạnh nhất nhẹ hơn hiện tại (giao diện về đúng 0,55R lõi đang dùng).

## B. Đợt 2a — chuẩn hoá theo số liệu Dr. Dave (không cần video)
| # | Việc | Nguồn | Ghi chú |
|---|---|---|---|
| B1 | Test đi băng: điểm bi qua băng đối diện, 6 góc ngắm, so bàn "đúng hệ thống" (9' Olhausen, 7' Valley) | TP B.28 | Sai số mục tiêu ≤ 0,3 kim cương. Số liệu bàn "băng ngắn" → hồ sơ bàn (tên Z-…) |
| B2 | Mô hình lỗ phụ thuộc tốc độ: bi nhanh chạm má có thể bật ra. Hiện bắt bi = tâm lọt vòng 6,6 cm (góc)/5,8 cm (giữa), không theo tốc độ (`Physics.cpp:181`). Bi bay đã đúng (chỉ bắt khi tiếp đất, `ElevatedPhysics.cpp:207`). | TP 3.5–3.8, B.15 | Test: kích thước lỗ hiệu dụng theo góc, chậm/nhanh |
| B3 | Squirt/điểm xoay cơ cho A5 | TP A.31, B.1, B.19, B.26 | |
| B4 | Throw mở rộng (đủ loại cú) | TP B.3, A.17, B.25, B.31 | Kiểm nghi vấn ma sát sàn 0,05 (Shadow) |
| B5 | Đã khớp, giữ nguyên: giảm xoáy 11 rad/s² (Dr. Dave đo ~10), ma sát lăn 0,012 (đo 0,010) | TP B.2 | Không đổi |
| B6 | Độ nảy băng app 0,82 vs đo DigiBall 0,73–0,77 (đánh thẳng chậm, 1 bàn, nóng +7%) | AZB 05/2026 | Chưa kết luận; chờ clip A.117/A.118/B.15 |

## C. Đợt 2b — đo từ video anh gửi (CHỜ ANH)
Anh tải ở https://drdavepoolinfo.com/high-speed-video/ — bản gốc mp4 chất lượng cao nhất, không cắt/nén, gửi vào chat. Chỉ dùng để đo, không đưa vào app. Clip đã làm chậm, không ghi fps → đo đại lượng tỉ lệ (góc, tỉ số tốc độ/xoáy, throw, độ cong); thước = kim cương + cỡ bi. Công cụ: ffmpeg + OpenCV (đã có trong máy làm việc).

| Ưu tiên | Clip | Đo |
|---|---|---|
| 1 Băng | 6.2, 6.3, 6.4, 6.5 | góc bật + xoáy sau băng, 4 kiểu xoáy |
| | A.117, A.118, B.15 | đi thẳng vào băng: độ nảy, mất xoáy |
| | A.68, A.69, A.70, A.71 | góc tới lớn, thuận/nghịch, chậm/nhanh |
| | B.25 | tốc độ + xoáy → góc bật |
| 2 Throw | A.82, A.83, A.84, B.30 | throw theo effect/tốc độ |
| 3 Jump/massé | 7.23, 7.24, A.126, B.14, A.127 | độ cao, tầm bay, tiếp đất, độ cong |
| 4 Lỗ | 3.6, 3.8 | chạm má lọt/bật |

Tài liệu anh tải giúp (cần đăng nhập/không mở được từ máy làm việc):
1. Mathavan, "Application of high-speed imaging to determine the dynamics of billiards" — PDF đính kèm AZB: https://forums.azbilliards.com/attachments/application_of_high-speed_imaging_to_determine_the-pdf.691242/
2. Mathavan 2010, "Ball behaviour under cushion impacts.pdf" — https://dspace.lboro.ac.uk/2134/15087

Video CLB của anh: KHÔNG dùng để hiệu chuẩn chuẩn (bàn chưa chắc chuẩn) → sau này làm "hồ sơ bàn CLB" riêng.

## D. Đợt 3 — trải nghiệm & công cụ luyện (sau A–C)
- D (đoán trước chỗ bi cái dừng, đánh xong đối chiếu) — đúng lõi "luyện dự đoán", ưu tiên cao.
- A (vào bi + để thế cú sau), B (so sánh đổi MỘT yếu tố) — tận dụng mô phỏng sẵn có.
- Sau cú: "Tập lại – Phân tích – Tiếp tục"; khoá ngắm có rung nhẹ.
- Chưa làm: tách luồng mô phỏng, tách TrainingController đồng loạt, AI có phong cách, "khoảng dung sai" (chưa có số đo).

## E. Nghiệm thu (khi build)
- Toán (CI): A1/A2 test, toàn bộ test cũ giữ kết quả, B1–B4.
- Video: throw ≤ 0,5°, góc bật băng ≤ 2°, quãng lăn ≤ 5%.
- Cảm giác (anh, máy thật): live p95 ≤ 17,5 ms; chơi và xem lại mượt như nhau; điểm chạm khớp xoáy.

Nguồn phản biện: review Shadow/ChatGPT 14/11 + kiểm chứng của em (chat 14/11 12:38).
