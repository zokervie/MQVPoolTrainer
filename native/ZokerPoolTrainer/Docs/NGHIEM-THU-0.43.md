# 0.43 — gom MỌI yêu cầu để anh nghiệm thu một lần (anh chốt 14/11 16:10)

Nền: `e12c8ca` (0.42b, CI 140 xanh). Nhánh chờ `cho/native-0.40c` → build `ci/native-0.43`.
Nguồn yêu cầu: TXT tổng (danh sách nghiệm thu 0.41 + "Update 0.41" + "Update 0.40"), 6 ảnh chụp 0.42b,
TXT intro "THE GOLDEN BREAK", `VIEC-CHO-0.43.md` (phản biện Shadow + dữ liệu Dr. Dave), gói 23 clip + 2 PDF.

## Quyết định của anh (14/11 16:10)
1. KHÔNG làm miscue → điểm chạm chặn ở giới hạn lõi (0,55R cơ ngang / 0,50R cơ nâng; tẩy mềm +0,05, cứng −0,05).
2. Squirt: theo đề xuất, "miễn vật lý chân thực" → sửa hướng bi cơ ngang (hết lệch sai phía) + tuỳ chọn "Squirt thực tế" theo TP A.31.
3. Đồng ý effect mạnh nhất nhẹ đi (đúng thực tế 0,55R).

## A. Vật lý & nhất quán
| # | Việc | Trạng thái |
|---|---|---|
| A1 | Một nguồn giới hạn điểm chạm (lõi → bi effect, cơ 3D, hướng đánh, AI, xem lại) | |
| A2 | Cơ ngang: bi đi đúng đường ngắm (hết lệch 0,8° về phía effect) | |
| A3 | Độ mượt lúc chơi = lúc xem lại (bớt chuyển trạng thái C++→Swift mỗi 1/240 s, đọc cài đặt 1 lần/cú) | |
| A4 | Test Opponent 228 s → < 60 s | |
| A5 | Tuỳ chọn "Squirt thực tế" | |
| A6 | Thẻ bàn bar-box ghi "mặt 9 ft" | |
| B1–B6 | Chuẩn hoá theo TP Dr. Dave + đo clip (băng, lỗ theo tốc độ, throw, jump/massé) — xem `VIEC-CHO-0.43.md` | |

## U. Lỗi thấy trong ảnh 0.42b (yêu cầu cũ chưa đạt)
| # | Ảnh | Yêu cầu gốc | Việc |
|---|---|---|---|
| U1 | IMG_7734 | 0.40 #3 "chỉ zoom khỏi vị trí ban đầu, không double" | Kính phóng bi effect đang hiện HAI bản → còn một bản |
| U2 | IMG_7736/7737 | 0.40 #1 "nỉ mềm như sợi, không giống nylon khi zoom" | Nỉ + băng khi zoom gần hiện ô đan to như rổ → sợi mịn, nhiễu sợi, giảm biên độ vân |
| U3 | IMG_7752 | 0.40 #5 "không hiển thị lộ liễu che màn hình, realtime & sync với phím ảo, thanh lực nằm ngang dưới bi effect, có công tắc" | Bỏ thẻ lớn "Shot by…"; thông số đối thủ hiện trên CHÍNH bi effect + thanh lực ngang dưới nó |
| U4 | IMG_7734/7752 | — | Nhãn tràn: "Boar d", "Camera · toàn cảnh" |
| U5 | logo đính kèm | 0.40 #11 thay logo | Icon app + logo trong phòng/intro = logo Z + bi 9 mới |

## I. Intro "THE GOLDEN BREAK" (TXT intro)
- Dựng TRONG APP bằng SceneKit (vật lý thật, logo gốc ghép phẳng, không để AI vẽ lại chữ): bản đủ 5,5 s (lần mở đầu) + bản ngắn ~1 s (các lần sau), chạm để bỏ qua, tôn trọng tắt tiếng.
- Âm: tổng hợp tại chỗ (ghi rõ "âm tổng hợp tạm"), thay bằng tiếng anh tự thu khi có.
- MP4 1920×1080 + 1080×1080: quay từ Simulator trên CI (chưa phải render điện ảnh); stem WAV xuất từ bộ tổng hợp.

## Hồi quy cần giữ (đã đạt ở 0.41/0.42 — kiểm lại khi nghiệm thu)
0.41: phá đầu Wi‑Fi, nút B lượt đối thủ, mượt khi đấu, gậy Break nằm ngang, thấy cơ đối thủ thục, thang lực 7 màu + vệt sương + số, vắng mặt/tắt màn hình (30 s/lượt, 1 phút 30 thua), menu khung gỗ, đầu tẩy Break/Jump, xem lại ±1 s + góc Action, không gian.
0.42: 10 phòng + biển ZOKER POOL, tranh treo, bảng tỉ số truyền hình, máy chơi, camera lượt đối thủ, gọi lỗ, dải bi dưới tên, đặt bi cái, cơ chạm bi khi xem lại, nhạc, 7 ngôn ngữ, âm thanh khi chuyển app.
0.41 (Update 0.40): khuôn xếp bi đúng luật, cơ đánh nhảy tối đa nửa bi/45°, massé gậy đánh 60%, phím R luật nhấp nháy, bi dưới tên nổi khối chỉ ở 8 Ball, cơ xem lại có gia tốc.

## Kết quả
(điền khi xong)
