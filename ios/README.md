# Pool Trainer – bản iOS (SwiftUI + SceneKit)

Bản native cho iPhone/iPad, cùng engine vật lý và thư viện bài tập với bản web (`src/`). Engine Swift được kiểm thử **khớp từng cú** với engine web (`ios/Tests`, 359 phép kiểm tra chạy trên CI).

## Tính năng
- Bàn 9 ft 3D: vải có lỗ, băng + hàm lỗ, mặt gỗ, nút xà cừ, đèn bàn, bóng đổ, góc nhìn **3D ↔ 2D**.
- Vật lý: trượt → lăn, xoáy 3 trục, throw bi-bi, băng có điểm chạm cao hơn tâm bi, squirt, massé (nâng cơ), hàm lỗ.
- 24 bài tập (ngắm, điều bi cái, hệ thống nút số Gương / Bank / Corner-5, vào trận) kèm **công thức, sơ đồ vẽ từ mô phỏng, cú mẫu chạy trên bàn**.
- Chơi tự do 8 bi / 9 bi (luật chạm bi nhỏ nhất, bi trong tay khi phạm lỗi).
- Điều khiển cảm ứng: kéo để ngắm, vi chỉnh ~0,02°, **khoá cơ**, **lực theo tốc độ vuốt** (hoặc thanh lực), điểm đánh, độ nâng cơ, đổi tay trái/phải.
- Hỗ trợ ngắm 3 mức (tắt / cơ bản / dự đoán vật lý đầy đủ), phát chậm ×5, bảng thông số bi cái (tốc độ, ωR/v, trượt/lăn).
- Âm thanh tổng hợp, rung phản hồi, lưu kết quả tập trên máy.

## Mới trong bản 3.1
- **Hồ sơ bàn các hãng**: WPA, Predator Apex, Diamond Pro-Am (9/8/7 ft, túi chặt), Rasson Victory III / OX, Mr Sung (Acurra, Hero), Brunswick Gold Crown VI, bàn CLB nỉ chậm – và **Bàn tùy chỉnh** để nhập số đo bàn của bạn (miệng lỗ, góc cắt, kệ lỗ, mũi băng, độ nảy băng, độ nhanh nỉ). Chi tiết & nguồn: [`docs/BAN-TAP.md`](docs/BAN-TAP.md).
- **Luyện thật**: tắt đường ngắm, bi ma, số độ, gợi ý; cơ chĩa vào tâm bi, người chơi tự ngắm; ngắm tinh bằng hai ngón.
- **Số liệu sau cú đánh**: tốc độ + **thang lực 1–7**, độ thẳng cú vuốt, ngắt cơ, lệch hướng ngắm, góc cắt, throw, bi mục tiêu lệch bao nhiêu mm ở lỗ, chạm băng ở nút số mấy (so với dự tính), khoảng cách tới vùng đích. **Phát lại chậm** và **bóng ma cú trước**.
- **Phân tích cú vuốt**: lực = tốc độ ngón tại vạch (hồi quy tuyến tính 5 mẫu cuối); tuỳ chọn để vuốt lệch / ngắt cơ ảnh hưởng thật tới cú đánh (không ngẫu nhiên).
- **Bài tập JSON** theo toạ độ kim cương (định dạng trong [`docs/dac-ta/04-drills.md`](docs/dac-ta/04-drills.md)): nhập từ Tệp, chia sẻ qua AirDrop, xuất mọi bài có sẵn sang JSON; số lần lặp, lệch ngẫu nhiên, đánh dấu dán trên nỉ. Bài mẫu trong [`Drills/`](Drills).
- **Thử thách**: ổn định lực (10 cú cùng mức, đo độ lệch chuẩn) và kiểm tra ngắm (10 cú cắt ngẫu nhiên, đo sai số góc, thiên lệch trái/phải).
- **Hiệu năng**: mức đồ hoạ Tự động / Thấp / Trung bình / Cao, tự hạ khi máy nóng (`thermalState`).

## Cài lên iPhone bằng ESign (Apple ID miễn phí)
1. Mỗi lần đẩy code, GitHub Actions build file **PoolTrainer.ipa (không ký)** và đăng ở
   **Releases → `ios-latest`**: `https://github.com/zokervie/MQVPoolTrainer/releases/download/ios-latest/PoolTrainer.ipa`
2. Trên iPhone mở **ESign → Tải về / Import → dán link trên** (hoặc tải file rồi “Mở bằng ESign”).
3. Chọn file → **Ký** bằng chứng chỉ bạn đang dùng → **Cài đặt**.
4. Lần đầu: *Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị* → tin cậy nhà phát triển (nếu được hỏi).

## Build bằng Codemagic
`codemagic.yaml` ở gốc repo có workflow **`ios-unsigned`** (IPA không ký, kèm kiểm thử engine).
1. Đăng nhập https://codemagic.io bằng GitHub → **Add application** → chọn repo `MQVPoolTrainer` → loại dự án *Other / codemagic.yaml*.
2. **Start new build** → nhánh `main` → workflow *iOS – IPA không ký (ESign)*.
3. Xong (~5–8 phút) vào **Artifacts** → tải `PoolTrainer.ipa` (Codemagic cũng gửi email kèm link) → mở bằng ESign như trên.

## Build trên máy Mac
```bash
brew install xcodegen
cd ios && xcodegen generate && open PoolTrainer.xcodeproj      # chạy trên Simulator / iPhone
ios/scripts/build-unsigned-ipa.sh                               # tạo ios/build/PoolTrainer.ipa
```

## Cấu trúc
| Thư mục | Nội dung |
|---|---|
| `PoolTrainer/Core` | Engine (Foundation thuần): hồ sơ bàn, vật lý, hệ thống nút số, bài tập, bài JSON, phân tích cú đánh |
| `PoolTrainer/Scene` | Cảnh SceneKit, texture vẽ bằng Core Graphics |
| `PoolTrainer/App` | Điều phối game, cài đặt/thống kê, âm thanh + rung |
| `PoolTrainer/UI` | SwiftUI: menu, phiếu bài tập, sơ đồ, HUD điều khiển |
| `Tests` | Kiểm thử đối chiếu Swift ↔ JS (`make-fixture.mjs` sinh `fixture.json`), kiểm thử mọi hồ sơ bàn, bài JSON, phân tích cú đánh |
| `Drills` | Bài tập JSON mẫu (đóng gói vào app) |
| `docs` | Hồ sơ bàn (`BAN-TAP.md`), bộ đặc tả thiết kế (`dac-ta/`), đối chiếu tiến độ (`TIEN-DO.md`) |
| `scripts` | Build IPA không ký, chụp màn hình Simulator cho CI |
