# 0.42 — Hiệu chỉnh vật lý bằng video 240 fps (kế hoạch, 13/11/2026)

Anh chốt 13/11 07:56: bản sau dồn sức cho vật lý. Mục tiêu: các hệ số trong `Core/Physics.hpp` chuyển từ "giả định" sang "đã đo trên bàn thật". Có test giữ cửa để lần sửa sau không làm lệch lại.

## 1. Hệ số cần đo và giá trị hiện tại
| Hệ số (`Config`) | Hiện tại | Tài liệu (khoảng) | Nguồn hiện tại | Cú đo |
|---|---|---|---|---|
| `rolling` (cản lăn) | 0,012 | 0,005–0,015 | đã công bố | A |
| `sliding` (ma sát trượt bi–nỉ) | 0,20 | 0,15–0,4, thường 0,2 | đã công bố | B |
| `spinDecay` (giảm xoáy ngang, rad/s²) | lõi 7, app 15 | 5–15 | app: giả định | E |
| `railBounce` / `railGrip` (băng) | 0,82 / app 0,20 | e 0,6–0,9 | giả định | C |
| `ballRestitution` (bi–bi) | 0,94 | 0,92–0,98 | đã công bố | D |
| `ballFriction` μ(v) (throw) | Alciatore TP A.14, app tối thiểu 0,05 | 0,03–0,08 | đã công bố, app chỉnh tay | D |

Lưu ý: app (`Config::app()`) đang dùng `spinDecay=15` và `ballFrictionMin=.05`, khác lõi. Đây là hai chỗ dễ sai nhất, nên đo trước.

## 2. Tính trước: video 240 fps đo được đến đâu
Mô phỏng Monte Carlo, 400 lần mỗi mục, script `Tools/calib_budget.py`.
- Giả định: máy đặt cao 1,5 m, ống 1x, mỗi pixel khoảng 1 mm, bi rộng khoảng 57 px.
- Nhiễu tâm bi 0,6 mm; sai số tỉ lệ 0,5 %.

| Đại lượng | Sai số 1 cú (1σ) | So với cần | Kết luận |
|---|---|---|---|
| Cản lăn μr | ±0,00006 | khoảng 0,01 | Rất dư. Sai số thật nằm ở độ không đều của nỉ, nên phải đo nhiều đường |
| Trượt μs (cú stun 2 m/s, lấy 0,25 s) | ±0,0035 | khoảng 0,2 | Đủ |
| Băng: tỉ lệ tốc độ / góc bật | ±1 % / ±0,5° nếu khớp ≥ 0,2 s sau băng. Chỉ lấy 30 ms thì ±6 % / ±3,4° | | Phải khớp cả đoạn sau băng bằng mô hình, không đo tốc độ tức thời |
| Throw bi–bi | ±0,19° | throw 2–5° | Đủ, lặp 3 lần |
| e bi–bi (cú thẳng stun) | ±0,008 | 0,92–0,98 | Vừa đủ, lặp 5 lần |
| Giảm xoáy (vạch trên bi, nhiễu góc 6°) | ±0,03 rad/s² | 5–15 | Đủ |

Kết luận: 240 fps đủ cho cả 6 hệ số. Điều kiện là máy cố định, mặt máy song song mặt bàn, và phải có khung chuẩn để quy đổi pixel ra mét.

## 3. Cách quay — anh làm ở CLB (khoảng 45 phút)
**Dụng cụ**
- iPhone.
- Chân máy có tay ngang (boom), hoặc kẹp gắn vào khung đèn bàn. Đặt máy cao khoảng 1,5 m so với mặt nỉ, ống kính chúc thẳng xuống, dùng app Thước đo → Mức để cân.
- 1 bút dạ bảng trắng (xoá được) để vẽ vạch lên bi cái.

**Cài máy**
- Camera → Quay chậm (Slo-mo) 240 fps, 1080p.
- Ống 1x, không zoom. Quay ngang máy.
- Chạm giữ màn hình để khoá phơi sáng và lấy nét (AE/AF Lock).
- Bật chế độ máy bay.
- Hướng cú đánh sao cho bi chạy ngang theo khung hình (đỡ méo do màn trập cuộn).

**Khung chuẩn:** đầu mỗi lần đặt máy, để bi đứng yên tại 4 điểm kim cương ở góc khung hình trong 2 giây. Em dùng 4 điểm này để quy đổi pixel ra mét.

**Ghi tên:** đầu mỗi clip đọc to tên, ví dụ "A2, vừa".

| Mã | Cú | Đo gì | Số lần |
|---|---|---|---|
| A | Lăn tự do: đánh nhẹ trên tâm (lăn ngay), dọc bàn, không chạm băng | Cản lăn | 3 lực × 2 |
| B | Stun: đánh tâm, chắc tay, bi trượt rồi chuyển sang lăn | Ma sát trượt | 3 lực × 2 |
| C | Bi lăn vào băng dài ở góc 30°, 45° và 90° | Hệ số bật và độ bám của băng | 3 góc × 2 lực × 2 |
| D | Cắt nửa bi (cú stun) và cú thẳng (cú stun) | Throw và e bi–bi | 3 lực × 3 |
| E | Bi cái có vạch xích đạo, xoáy ngang, đánh chậm | Giảm xoáy | 3 lần |

**Gửi file:**
- Trong Ảnh, chọn các clip → Chia sẻ → Tuỳ chọn → bật **Tất cả dữ liệu ảnh** → Lưu vào Tệp → nén zip → gửi.
- Không gửi qua Zalo hay Messenger, vì các app này nén video và hạ xuống 30 fps.
- Ghi kèm loại bàn, loại nỉ (mới hay cũ), nhiệt độ phòng nếu biết (băng bật mạnh hơn khi trời nóng, khoảng 7 % giữa 8 °C và 27 °C).

## 4. Phần em làm (test trước, theo CLAUDE.md)
1. **Trước khi có video:** viết `Tests/VideoCalibrationTests.cpp`.
   - Dùng lõi C++ tạo quỹ đạo với hệ số biết trước, thêm nhiễu như §2.
   - Bộ khớp phải tìm lại đúng hệ số trong ±2σ.
   - Đăng ký test ở cả `CMakeLists.txt` và `Run-All-Checks.command`.
   - Dùng lại `CushionCalibration.hpp`, mở rộng cho dữ liệu chỉ có vị trí (không đo được xoáy sau băng).
2. **Dò bi:** `Tools/video_calib/` dùng OpenCV + SciPy + ffmpeg, đã có sẵn trên máy chủ.
   - Quy đổi phẳng từ 4 điểm kim cương sang toạ độ bàn.
   - Dò tâm bi từng khung hình, tách pha trượt/lăn, khớp từng hệ số.
   - Xuất JSON mẫu vào `Tests/data/`.
3. **Test 20 cú mẫu:** mô phỏng lại từng cú thật từ trạng thái đầu.
   - Vị trí dừng lệch ≤ 1 đường kính bi.
   - Góc bật băng lệch ≤ 1°.
   - Test này giữ cửa cho mọi thay đổi vật lý sau này.
4. Mỗi hệ số mới ghi nguồn là "đã đo — bàn X, nỉ Y, ngày Z". Có thể làm thành mẫu "Bàn của tôi" trong Tuỳ chỉnh (gói Z-Lab).

## 5. Skill và công cụ
- `zoker-pool-dev`: luật dự án, viết test trước, CI.
- `engineering:testing-strategy`: thiết kế test khớp hệ số và test 20 cú.
- `dataviz`: đồ thị quỹ đạo đo so với mô phỏng, gửi anh duyệt.
- `deep-research`: chỉ dùng khi cần đào sâu mô hình băng (Mathavan 2010, Han 2005).
- Đối chiếu: thư viện mã nguồn mở pooltool có sẵn các mô hình Han 2005 / Mathavan 2010 / Alciatore để so kết quả. Chỉ dùng để đọc và so, không nhúng vào app (luật: không dùng engine vật lý có sẵn).

## 6. Rủi ro
- Máy đặt nghiêng: quy đổi phẳng vẫn xử lý được, nhưng phía xa sẽ kém nét. Cần góc nhìn nghiêng không quá 45°.
- Đèn LED nhấp nháy 100 Hz: độ sáng dao động, nhưng dò tâm vẫn ổn.
- Nỉ không đều: đo trên 2–3 đường khác nhau rồi lấy trung bình.
- Mô hình băng hiện tại có thể không khớp được ở mọi góc và lực. Nếu sai số còn lớn hơn 1°, đề xuất nâng cấp lên mô hình Mathavan. Việc này lớn, sẽ hỏi anh trước.

## Nguồn
- Dr. Dave Alciatore, giá trị tham khảo: https://drdavepoolinfo.com/?p=2349
- Mathavan và cs., va chạm băng (e ≈ 0,98 trong mô hình xung, μ ≈ 0,14; giả định băng cứng đúng khi vận tốc pháp tuyến dưới khoảng 2,5 m/s): https://dspace.lboro.ac.uk/2134/15087
- Đo hệ số bật băng không cần camera tốc độ cao (DigiBall; ảnh hưởng nhiệt độ): https://forums.azbilliards.com/posts/8439937/
- Cách thử và so sánh bàn (Dr. Dave; đo cản lăn bằng độ dốc tốc độ xoáy): https://forums.azbilliards.com/threads/how-to-test-and-compare-tables-for-speed-difficulty-and-kick-bank-performance.576136/post-8140716
- pooltool, danh mục mô hình vật lý: https://pooltool.readthedocs.io/en/latest/autoapi/pooltool/physics/index.html
- Ma sát và độ đàn hồi bi–bi (Alciatore 2005): https://billiards.colostate.edu/bd_articles/2005/april05.pdf
