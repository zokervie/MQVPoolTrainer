# Hiệu chuẩn vật lý 0.43 — đối chiếu số đo thật (14/11/2026)

Nguyên tắc: số ĐO trên bàn thật > số công bố từ mô hình > giả định. Không chỉnh hệ số để khớp một nguồn nếu làm lệch
nguồn đo khác tốt hơn. Mọi kiểm tra chạy trong CI: `Tests/PublishedBenchmarkTests.cpp` (26 mục), `CueTipTests`,
`SystemsBenchmarkTests`, `ReverseZigzagTests` (clip bàn thật của anh), `DiamondSystemTests`, `OpponentTests`.

## 1. Nguồn đã dùng
| Nguồn | Loại | Dùng cho |
|---|---|---|
| Mathavan, Jackson & Parkin 2009 (Am. J. Phys. 77) — camera tốc độ cao nhìn thẳng xuống, 120–1000 fps | **Đo** (bàn snooker) | lăn, trượt, nảy băng (31 cú), 5 va chạm xiên |
| Mathavan 2010 (IMechE C) | Mô hình lý thuyết (e 0,98, μ băng 0,14) | góc bật theo góc tới (Fig. 6–8) — tham khảo |
| Dr. Dave TP A.14, A.31, B.2, 3.5–3.8, B.17, B.28 | Đo + tính | throw, squirt, giảm xoáy (đo ~10 rad/s²), lỗ, giới hạn điểm chạm, đi băng 5 bàn |
| 23 clip HSV Dr. Dave (320×240, phát chậm, nhiều clip quay nghiêng/cận) | Hình | kiểm tra định tính |
| Clip zigzag bàn thật của anh (04/11) | **Đo** (bàn pool) | ma sát băng .20, β .30 |
| DigiBall (AZB 05/2026) | Đo gián tiếp (bàn pool) | độ nảy băng ~0,73–0,77 (cận dưới) |

## 2. Kết quả đối chiếu (app hiện tại)
| Đại lượng | Đo thật | App 0.43 | Kết luận |
|---|---|---|---|
| Giảm tốc khi lăn | 0,124–0,126 m/s² [M09] | 0,118 | Khớp (−5 %) |
| Ma sát trượt bi–nỉ | 0,178–0,245 [M09] | 0,20 | Khớp |
| Nảy băng, bi lăn đi thẳng vào | 0,91–0,94 (0,4–1,5 m/s), 0,84 (3 m/s) [M09, băng snooker] | ≈ 0,85 mọi tốc độ | Trong ±12 %. Băng pool đo thấp hơn (DigiBall 0,73–0,77) → **giữ 0,82**, app nằm giữa hai nguồn pool/snooker |
| 5 va chạm xiên, tốc độ sau khi hết trượt | Bảng I [M09] | sai lớn nhất 9,9 % | Khớp (lý thuyết của chính bài báo sai 2–12 %) |
| Giảm xoáy ngang | ~10 rad/s² [TP B.2] | 11 | Khớp |
| Squirt 0,55R, cơ ngang | 1,5–4,5° tuỳ ngọn [TP A.31] | 2,4° khi bật "Squirt thực tế" | Khớp |
| Giới hạn điểm chạm | ~0,5R [TP B.17] | 0,55R (một nguồn cho mọi phần) | Khớp, đã hết lệch 0,70R ở giao diện |

## 2b. Đã đổi: độ sạch bi (anh chấp thuận 14/11 17:19)
Ma sát sàn 0,05 (fit clip reverse zigzag) làm cú NHANH truyền xoáy sang bi đích gấp 3–4 lần tài liệu (3 m/s, effect 45 %:
11 % so với 2,5 %; TP A.27: tối đa 35,7 % và chỉ ở cú chậm–vừa). Clip của anh là thật nhưng nhiều khả năng là bi bẩn/dính
phấn ("cling", TP A.17: ma sát tăng ≥ 2 lần). Nay: **Thường** = TP A.14 (mặc định), **Bẩn/dính phấn** = sàn 0,05 (vẫn tái
hiện clip, test giữ cửa RailEnglish), **Sạch** = ×0,8. Mốc mới B27–B28 (TP A.27). Bi phá cụm khít (frozen rack) là hệ hỗn
loạn: chênh do thứ tự trong lõi chỉ 0,005 mm ở giây đầu; test kiểm ở 1 s, 6 s chỉ báo cáo (≤ 15 cm).

## 3. Đã thử nhưng KHÔNG đổi (và vì sao)
- **Độ nảy băng theo tốc độ (Mathavan: e 0,91 − 0,035·v)**: khớp tốc độ bật thẳng, nhưng làm góc bật xiên hẹp thêm ~2° (bài
  kiểm tra K1a ra ngoài khoảng); hạ ma sát băng để bù thì clip zigzag bàn thật của anh lệch quá 0,3 kim cương. Số Mathavan là băng snooker; số pool (DigiBall) lại thấp
  hơn app. Không có đủ bằng chứng pool để đổi → giữ.
- **Mô hình băng Mathavan 2010**: theo Fig. 6, bi lăn tới 45° bật ra ~47° (rộng hơn gương); app bật hẹp hơn (~39°).
  Đây là chênh lệch lớn nhất còn lại nhưng (a) đó là mô hình lý thuyết với băng snooker, (b) clip bàn thật của anh và các
  hệ kim cương (DiamondSystem) đang khớp với app. Cần số đo góc bật của băng pool để quyết → xem mục 5.

## 4. Clip HSV — quan sát định tính (góc tới ~26° so với pháp tuyến, tốc độ không biết)
| Clip | Kiểu xoáy | Video: góc bật ngay → sau | App (1 m/s) ngay → 0,3 s |
|---|---|---|---|
| 6.5 | stun | ~13° → ~14° | 19° → 26° |
| 6.4 | lăn tự nhiên | ~26° | 20° → 27° |
| 6.2 | xoáy trên mạnh | ~27° → 34° (mở rộng) | 21° → 33° |
| 6.3 | xoáy dưới | ~18° → 25° | 17° → 15° |
Phối cảnh camera nghiêng và độ phân giải 320×240 làm sai số vài độ; xu hướng xoáy trên mở rộng góc khớp app. Bi stun
trong video bật hẹp hơn app khá rõ — ghi nhận, chưa sửa (một clip, không rõ tốc độ).

## 5. Việc còn lại để chính xác hơn nữa
1. Đo góc bật băng POOL có tốc độ: quay từ trên xuống (iPhone slo-mo 240 fps, chân máy 1,5 m) 3 góc tới (25°, 45°, 65°)
   × 2 tốc độ × stun/lăn — khoảng 15 phút. Với dữ liệu này mới chốt được mô hình băng Mathavan cho pool.
2. Lỗ theo tốc độ (TP 3.5–3.8): hiện bắt bi theo vòng tròn cố định; má lỗ có va chạm thật nên bi chạm má vẫn có thể bật
   ra, nhưng chưa có "rung lỗ" theo tốc độ ở đáy lỗ. Chưa đổi vì TP 3.x là tính hình học, không phải đo.
3. Jump: clip B.14 có bảng thước và ghi 1000 fps — đo được độ cao nhảy khi có thời gian.
