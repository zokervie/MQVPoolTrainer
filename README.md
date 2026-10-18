# MQVPoolTrainer

Ứng dụng tập bi-a pool 3D chạy trên trình duyệt (điện thoại, máy tính bảng, máy tính) và cài được như app (PWA).

**Chơi ngay:** https://zokervie.github.io/MQVPoolTrainer/

## Tính năng

- **Đồ hoạ 3D** (Three.js): bàn 9 ft, gỗ, nỉ, nút xà cừ, bi có số, cơ, đèn bàn, đổ bóng. Chuyển **2D ↔ 3D** bất kỳ lúc nào.
- **Vật lý chân thật**: giai đoạn trượt → lăn, xoáy theo/kéo/english (3 trục), va chạm bi-bi có ma sát (throw, truyền xoáy), băng có điểm tiếp xúc cao hơn tâm bi (english làm đổi góc nảy), lệch hướng do english (squirt), massé khi nâng cơ, hàm lỗ và lỗ bắt bi. Tham số theo số liệu của Dr. Dave Alciatore.
- **Điều khiển cảm ứng**:
  - Kéo trên bàn để ngắm; thanh vạch để vi chỉnh (~0,02°/điểm ảnh).
  - Nút **Khoá cơ** giữ nguyên đường cơ.
  - **Lực theo tốc độ đẩy**: tay còn lại kéo xuống (lùi cơ) rồi đẩy lên trên ô lực – đẩy nhanh thì đánh mạnh.
  - Chọn điểm đánh trên bi cái, độ nâng cơ, đổi tay trái/phải.
- **Hỗ trợ ngắm 3 mức**: tắt / cơ bản (tới điểm chạm, bi ma, hướng bi mục tiêu) / đầy đủ (dự đoán bằng chính engine vật lý).
- **Bài tập kèm công thức + sơ đồ trước mỗi bài** (sơ đồ vẽ từ mô phỏng cú mẫu, có nút xem cú mẫu chạy trên bàn):
  - Ngắm: bi thẳng, bi dài, ½ bi, thang ¾–½–¼–⅛, bi ma ngẫu nhiên, bi sát băng, lỗ giữa.
  - Điều bi cái: thang bi dừng, kéo, theo, quy tắc 90°, quy tắc 30°, lag, chạy vị trí 2 bi, line-up, Mighty X.
  - Hệ thống nút số: Gương 1 băng, chia đôi khoảng cách, bank 1 băng, phản chiếu qua góc 2 băng, Corner-5 (đường chuẩn 5-3-2 và tính số nhắm).
  - Vào trận: phá bi 9 bi, dọn bàn 9 bi theo mẫu.
- **Chơi tự do** 8 bi / 9 bi (luật chạm bi nhỏ nhất, bi trong tay khi phạm lỗi).
- Lưu kết quả tập (thành công / chuỗi tốt nhất) trên máy, chơi không cần mạng sau lần mở đầu.

## Ứng dụng iOS (native)

Thư mục [`ios/`](ios/README.md): bản SwiftUI + SceneKit dùng chung engine (kiểm thử khớp từng cú với bản web).
File IPA không ký mới nhất (cài bằng ESign / Sideloadly): **Releases → `ios-latest`** – hướng dẫn trong [`ios/README.md`](ios/README.md). Build bằng Codemagic: `codemagic.yaml`.

## Cấu trúc

| Tệp | Nội dung |
|---|---|
| `src/physics.js` | Engine vật lý (bước thời gian cố định 1/2000 s) |
| `src/table.js` | Kích thước bàn, băng, hàm lỗ, lỗ |
| `src/systems.js` | Hình học bi ma, gương, phản chiếu góc, Corner-5 |
| `src/drills.js` | Thư viện bài tập, công thức, đánh giá kết quả |
| `src/diagram.js` | Sơ đồ SVG của bài tập |
| `src/render.js`, `src/textures.js` | Cảnh 3D |
| `src/main.js` | Vòng lặp, điều khiển, giao diện |
| `test/` | Kiểm thử vật lý và kiểm tra mọi bài tập đều giải được |

Không cần bước build: mở bằng một web server tĩnh bất kỳ, ví dụ `python3 -m http.server 8080` rồi vào `http://localhost:8080`.

Chạy kiểm thử: `npm test` (Node 20+).

## Nguồn tham khảo

- Dr. Dave Alciatore – [các hệ thống nút số](https://drdavepoolinfo.com/FAQ/bank-kick/diamond-systems/), [Corner-5 (Billiards Digest 11/2010)](https://billiards.colostate.edu/bd_articles/2010/nov10.pdf), [thông số vật lý](https://drdavepoolinfo.com/?p=2349).
- Các bài giảng miễn phí trên YouTube (mỗi bài tập có nút tìm video).
- Phong cách sơ đồ tham khảo [PoolShot](https://www.poolshot.org); nội dung bài tập được biên soạn lại, không sao chép từ ứng dụng PoolShot.
