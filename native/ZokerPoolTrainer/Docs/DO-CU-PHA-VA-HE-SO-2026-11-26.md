# Đo cú phá và bảng hệ số vật lý — 26/11/2026 (chỉ đo, CHƯA đổi gì)

Bước đầu của làn mây trong kế hoạch 0.60 (`KE-HOACH-HIEU-CHUAN-0.60.md`). Không đổi một hệ số nào, không ảnh hưởng bản 0.59 đang nghiệm thu.
Công cụ: `Tools/bench_break.cpp` (chạy tay, KHÔNG nằm trong CI). Lõi C++ giống commit 5e54102.

## 1. Cách đo
- Thế bi: `Rules(...).rack(seed)` của chính game (8 bi tam giác, 9 bi hình thoi bi 9 ở điểm đặt, 10 bi tam giác).
- Bi cái sau vạch đầu bàn (y = −0,90 m), 7 vị trí ngang: 0, ±15, ±30, ±45 cm.
- Tốc độ bi cái 7 / 9 / 11 m/s (phá mạnh của dân chuyên khoảng 11–13 m/s). Điểm chạm: kéo nhẹ / giữa / đẩy nhẹ. Đánh thẳng vào bi đầu.
- Cấu hình như app: băng mô hình ghép (coupledCushions), gậy phá, tắt squirt, spinDecay 11.
- Ba bộ: (a) tay hoàn hảo; (b) sai số ngắm 0,3°; (c) sai số 0,3° + khe xếp bi ±1 mm. Mỗi bộ 504 cú mỗi thể loại.

## 2. Kết quả

| Thể loại | Có bi vào khi phá | Bi vào trung bình | Bi cái rơi lỗ | Số giải thật (nguồn: claude/zoker-ai-bida-pro-0.42.md) |
|---|---|---|---|---|
| 8 bi | 5–12 % | 0,05–0,13 | 3–11 % | (không có số giải; người chơi khá thường vào bi khi phá đa số lần) |
| 9 bi | 36–47 % | 0,42–0,57 | 6–8 % | phá có bi vào 58–75 % (WPC 2025, Derby City 2024) |
| 10 bi | 6–16 % | 0,06–0,18 | 6–12 % | có bi vào 62 %, trung bình 1,0 bi, lỗi khi phá ~5 % (Ohio Open 2021) |

Nhận xét (đã đo):
- Cú phá của game **vào quá ít bi**, nặng nhất ở 8 và 10 bi (thấp hơn số giải 4–10 lần). 9 bi gần hơn nhưng vẫn thiếu.
- Xếp bi khít hoàn hảo + đánh trúng tâm cho kết quả gần như đối xứng, lặp lại y hệt; thêm khe xếp bi 1 mm thì tăng nhẹ (8 bi 5→12 %, 10 bi 8→16 %).
- Bi cái rơi lỗ 7–12 % khi có sai số ngắm: hơi cao so với ~5 % của giải 10 bi.
- Mọi cú đều đưa ≥ 4 bi chạm băng (luật phá hợp lệ): phần này ổn.

## 3. Nguyên nhân có thể (SUY LUẬN, chưa kiểm)
1. **Vùng bắt bi ở lỗ góc** là vòng tròn cố định (bán kính 66 mm, tâm lệch 35 mm ra ngoài góc; lỗ giữa 58 mm), chưa theo hình học miệng lỗ thật — tài liệu 0.43 đã ghi là còn thiếu "lỗ theo tốc độ". Lỗ quá "khó" sẽ giảm mạnh bi vào khi phá.
2. **Truyền năng lượng trong cụm bi**: va chạm nhiều bi cùng lúc với hệ số hồi phục 0,94 và ma sát bi–bi; nếu cụm "nuốt" năng lượng thì bi cánh đi chậm, không tới lỗ.
3. **Thế xếp bi**: khe 0,001 mm là hoàn hảo hơn mọi khuôn thật.
4. Cách đo: chỉ đánh thẳng bi đầu; dân chuyên 8 và 10 bi thường phá từ cạnh, cắt nhẹ bi đầu. Bước sau sẽ đo thêm kiểu này.

## 4. Bảng hệ số đang dùng (Core/Physics.hpp)

| Hệ số | Giá trị | Nguồn theo ghi chú trong code |
|---|---|---|
| Ma sát trượt bi–nỉ | 0,20 | đã công bố (Alciatore) |
| Ma sát lăn | 0,012 (preset Tiêu chuẩn) | đã công bố, khoảng 0,005–0,015 |
| Hồi phục bi–bi | 0,94 | đã công bố (Alciatore) |
| Ma sát bi–bi μ(v) | 0,00995 + 0,108·e^(−1,088·v) | đã công bố (TP A.14, dữ liệu Marlow) |
| Giảm xoáy | 7 (lõi) / 11 (preset app) | lõi: đo ~10 rad/s² theo tài liệu 0.43; preset app: giả định |
| Băng (mô hình đơn) | hồi phục 0,82, ma sát 0,16 | chưa rõ nguồn trong code (cần tra) |
| Băng (mô hình ghép, app dùng) | e 0,89, ma sát 0,17 | hiệu chỉnh 0.43 theo bảng góc bật (xem HIEU-CHUAN-VAT-LY-0.43.md) |
| Chiều cao mũi băng | 0,27 R trên tâm | theo quy cách bàn (WPA) |
| Khối lượng cơ, đầu cơ | 0,54 / 0,31 / 0,56 kg; 7–12 g | giả định |
| Đầu cơ (mềm/vừa/cứng) | hệ số tốc độ 0,971 / 1 / 1,063 | giả định |
| Mặt đá bàn | hồi phục 0,50, ma sát 0,20 | giả định |
| Vùng bắt bi lỗ | 66 mm góc / 58 mm giữa | chưa rõ nguồn (cần tra) |

## 5. Đề xuất (CHƯA làm, chờ anh duyệt)
1. Trước khi đổi gì: đo thêm (a) cú phá cạnh 8/10 bi cắt nhẹ bi đầu, (b) cùng bộ cú trên Pooltool để so — nếu Pooltool cũng vào ít thì vấn đề ở cách đo, không ở game.
2. Nếu xác nhận lỗi ở lỗ: làm hình học miệng lỗ theo quy cách WPA (miệng góc 4,5–4,625 inch) thay vòng tròn cố định, có test riêng.
3. Mọi thay đổi ra bản riêng sau khi anh nghiệm thu 0.59, kèm bảng số trước–sau như trên.
