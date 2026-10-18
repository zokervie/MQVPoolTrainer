# Hồ sơ bàn tập (các hãng)

Chọn trong app: **Menu → Bàn → Đổi bàn** (hoặc Cài đặt → Bàn tập). Mã nguồn: `PoolTrainer/Core/TableSpecs.swift`.

Mỗi hồ sơ gồm: kích thước mặt chơi, miệng lỗ góc / giữa, góc cắt miệng lỗ, độ sâu kệ lỗ, chiều cao mũi băng, loại băng + hệ số hồi phục/ma sát, loại nỉ + ma sát trượt / cản lăn / giảm xoáy ngang, màu khung.

- **Hình học (kích thước, miệng lỗ)**: theo thông số hãng hoặc WPA đã công bố – cột "Nguồn".
- **Hệ số nỉ/băng**: là **ước lượng** theo loại nỉ / cao su (Dr. Dave Alciatore: μ trượt 0,15–0,4; cản lăn 0,005–0,015). Hãy chỉnh trong **Bàn tùy chỉnh** cho khớp bàn bạn tập.
- Thông số chưa công bố (góc cắt, kệ lỗ) dùng giá trị WPA: góc 142°/104°, kệ lỗ góc 1,5″, lỗ giữa 0,1875″, mũi băng 63,5% đường kính bi.

| Hãng | Mẫu | Mặt chơi | Lỗ góc | Lỗ giữa | Băng | Nỉ | Nguồn |
|---|---|---|---|---|---|---|---|
| MQV | Bàn chuẩn 9 ft (mặc định) | 100×50″ | 4,65″ (118 mm) | 5,2″ (132 mm) | K66 (ước lượng) | Nỉ thi đấu | Hình học gốc bản web (kiểm thử đối chiếu) |
| WPA | Tiêu chuẩn thi đấu 9 ft | 100×50″ | 4,5″ | 5″ | K66 (ước lượng) | Simonis 860 | [WPA equipment specs](https://www.poolroom.com/tournament-table-equipment-specifications/) |
| Predator | Apex 9ft Professional | 100×50″ | **4,25″ (108 mm)** | **4,92″ (125 mm)** | K55 Pro Speed (hard-bonded) | Arcadia Reserve | [predatorcues.com](https://predatorcues.com/pages/predator-apex-9ft-professional-table) |
| Diamond | Pro-Am 9 ft | 100×50″ | 4,5″ | 5″ | – | Simonis 860 | [diamondbilliards.com](https://diamondbilliards.com/products/diamond-pro-am-pool-table) · lỗ: [AZB](https://forums.azbilliards.com/threads/anybody-out-there-with-a-diamond-table-that-has-tighter-pockets-than-pro-cut.473033/) |
| Diamond | Pro-Am 9 ft – túi chặt | 100×50″ | 4¼″ | 4¾″ | – | Simonis 760 | số đo người dùng (AZB) |
| Diamond | Pro-Am 8 ft | 90×45″ | 4,5″ | 5″ | – | Simonis 860 | diamondbilliards.com |
| Diamond | Pro-Am 7 ft (bar box) | 80×40″ | 4,5″ | 5″ | – | Simonis 860 | diamondbilliards.com |
| Rasson | Victory III 9 ft / 8 ft | 100×50″ / 90×45″ | 4,5″ | 5″ | Klematch P59 | Simonis 860 | [gameroomgorilla.com](https://gameroomgorilla.com/shop/rasson-victory-ii-plus-pool-table) |
| Rasson | OX 9 ft | 100×50″ | **4″** | 5″ | MAX K55 | – | email Rasson trích trên [AZB](https://forums.azbilliards.com/threads/rasson-ox-table.541822/), [billiardfactory](https://billiardfactory.com/rasson-ox-ii-pool-table) |
| Mr Sung | Acurra 9 ft (Rasson Mr-Sung series) | 100×50″ | 4,5″* | 5″* | – | – | [rasson.cn](https://rasson.cn/acurra-mr-sung) |
| Mr Sung | Hero 9 ft (by Rasson) | 100×50″ | 4,5″* | 5″* | – | – | [thailandpooltables.com](https://www.thailandpooltables.com/en/rasson-hero-black-pool-table-9ft-drop-pockets.html) |
| Brunswick | Gold Crown VI Tournament | 100×50″ | 4,5–4,625″ | 5–5,125″ | SuperSpeed | Simonis 860 (tuỳ chọn) | [pooltables.com](https://pooltables.com/products/brunswick-gold-crown-vi-9-tournament-matte-black) |
| CLB | Bàn quán 9 ft – nỉ chậm | 100×50″ | 4,75″ | 5,25″ | K66 cũ | Nỉ len thường | mô phỏng để so sánh cảm giác |

\* Rasson/Mr Sung chỉ đăng bảng thông số dạng ảnh, không có chữ – app dùng chuẩn WPA. Nếu bạn có số đo thật (thước đo miệng lỗ giữa hai mũi băng), nhập ở **Bàn tùy chỉnh**.

## Đo bàn thật để nhập "Bàn tùy chỉnh"
1. **Miệng lỗ**: đo khoảng cách giữa hai mũi băng ở miệng lỗ (WPA: góc 4,5–4,625″, giữa 5–5,125″).
2. **Kệ lỗ**: từ đường nối hai mũi băng tới mép rơi của lỗ.
3. **Độ nảy băng** (kiểm tra WPA): đặt bi ở điểm đầu bàn, đánh tâm qua điểm chân bàn, lực chắc – bi phải đi 4–4,5 chiều dài bàn. Đi ít hơn → hạ "Hồi phục băng".
4. **Độ nhanh nỉ**: đẩy bi lăn nhẹ hết một chiều dài bàn; nếu ngoài đời bi lăn xa hơn trong app → giảm "Cản lăn".

## Kiểm thử
`ios/Tests/main.swift` chạy với **mọi** hồ sơ bàn: bi thẳng vào lỗ góc, bi chạy sát băng vào lỗ, phá 15 bi không văng khỏi bàn, mọi bài tập dựng được và bi nằm trong bàn (bàn 7/8 ft tự quy đổi theo kim cương).
