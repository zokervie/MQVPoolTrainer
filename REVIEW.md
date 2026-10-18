# Phản biện kiến trúc — Zoker Pool Trainer

Trả lời bản "Phản biện kỹ thuật & đề xuất hoàn thiện UPGRADE.md". Chưa sửa code, chưa sửa UPGRADE.md. Mọi điểm cần phê duyệt nằm ở mục H.

Ký hiệu nguồn: **[TL]** tài liệu tham khảo · **[KT]** đã kiểm tra thực tế · **[GT]** giả thuyết chưa xác minh.

---

## A. Đồng ý — nên giữ

| Đề xuất | Lý do |
|---|---|
| Một bộ giải theo sự kiện trong runtime; bộ giải bước nhỏ chỉ trong test | Một nguồn sự thật, giữ được tính lặp lại. |
| Tách nghiệm thu toán học và nghiệm thu vật lý | Sai số 1e-9 chỉ chứng minh code đúng công thức, không chứng minh công thức đúng với bàn thật. Đây là sửa đúng cho UPGRADE.md. |
| Tách dữ liệu hiệu chỉnh và dữ liệu kiểm chứng | Không tách thì chỉnh tham số là "học thuộc" vài cú, kết luận vô giá trị. |
| Tách bàn thành Geometry / Physics Profile / Visual Asset / Calibration Profile | Đúng ranh giới; mỗi phần thay đổi vì lý do khác nhau. |
| Mỗi tham số phải có nguồn, phương pháp đo, hoặc đánh dấu "giả định" | Biến giả định thành thứ nhìn thấy được trong dữ liệu. |
| Đồ họa phân hai bậc, không làm công cụ so ảnh | Đúng ưu tiên. |
| 10 bài tập, gợi ý dựa trên lỗi lặp lại, không dùng AI tốn phí | Đủ cho MVP, rẻ, giải thích được. |
| Đo khả năng chuyển giao ra bàn thật | Đây là câu hỏi duy nhất quyết định sản phẩm có giá trị. |
| Ghi rõ giới hạn khi không có Xcode/thiết bị | Cần thiết: code khởi tạo hiện **chưa từng được biên dịch** [KT]. |

---

## B. Phản đối hoặc cần sửa

### B1. Natural Stroke không huấn luyện động tác ra cơ — và không nên giả vờ như vậy
Học vận động có tính **đặc thù**: kỹ năng gắn với đúng cơ, đúng khớp, đúng cảm nhận bản thể [TL: nguyên lý specificity of practice trong học vận động]. Vuốt bằng ngón tay dùng hệ cơ khác hoàn toàn với đẩy cơ bằng cẳng tay–khuỷu–vai. Nên:

- **Không chuyển giao:** độ thẳng cú ra cơ, nhịp tay, giữ cầu tay, ra cơ đúng tâm.
- **Có thể chuyển giao [GT, cần đo ở mục D4]:** ngắm bằng mắt từ góc nhìn ngang cơ; ước lượng lực theo kết quả ("cú này cần lăn 1,5 bàn"); chọn điểm chạm và xoáy; đọc đường đi bi cái; bù throw/squirt; kế hoạch đưa bi.

**Hệ quả kiến trúc:** cú vuốt chỉ cần là một đầu vào **analog, nhất quán, có sai số tự nhiên**. Việc quy đổi tốc độ ngón → tốc độ đầu cơ ngoài đời là không có ý nghĩa vật lý, nên **không đầu tư hiệu chỉnh nó**. Ngôn ngữ chung giữa game và bàn thật là **kết quả** (quãng lăn, thang lực 1–7 theo số chiều dài bàn), không phải m/s của đầu cơ.

Tuyên bố sản phẩm nên là: *"luyện mắt và tư duy, không luyện cánh tay."*

### B2. Manual Stroke Mode: giữ, nhưng đổi vai trò
Nhập hướng/điểm chạm/lực bằng số độc lập là luyện **đọc số**, đi ngược nguyên tắc ngắm bằng cảm giác. Nhưng nó cực kỳ có giá trị ở hai việc khác:

1. **Shot Lab (phân tích):** tái hiện chính xác một cú đánh để tách lỗi người chơi khỏi lỗi vật lý (xem C5).
2. **Bài tập quyết định:** "chọn điểm chạm và lực để bi cái về vùng X" — luyện tư duy đưa bi, thứ chuyển giao tốt.

→ Đặt tên **Shot Lab**, không gọi là chế độ luyện tập chính. Natural Stroke là chế độ mặc định.

### B3. Kiểm tra năng lượng "có xét công ngoại lực" là phức tạp không cần thiết
Ma sát nỉ, ma sát bi–bi, va chạm có e ≤ 1 đều chỉ làm **mất** năng lượng. Bất biến đơn giản và đủ mạnh: tổng động năng (tịnh tiến + quay) **không tăng** giữa hai sự kiện bất kỳ và qua mọi va chạm. Vi phạm là có lỗi. Không cần tính công từng lực.

### B4. Tranh luận 10 ms hay 20 ms là sai chỗ
Mô phỏng chạy **một lần** ngay khi ngón tay vượt vạch, ngoài main thread, trước khi hoạt ảnh bắt đầu. Ngưỡng người dùng cảm nhận là độ trễ từ lúc chạm bi đến lúc bi chạy (~100 ms [TL: ngưỡng phản hồi tức thời trong UX]). Vậy KPI bắt buộc là **độ trễ cảm nhận**, còn thời gian mô phỏng chỉ cần nằm gọn trong đó. Xem bảng D4.

### B5. Thử nghiệm bàn thật: 10 lần lặp do người đánh không kiểm soát được biến
Người đánh tay không lặp lại được tốc độ và điểm chạm; phương sai của người lớn hơn sai số mô hình cần đo. 10 lần lặp chỉ đo được tay người đánh.

Giải pháp ở C3: **đo điều kiện ban đầu từ video thay vì kiểm soát chúng**, cộng một máng lăn tự chế cho các cú cần lặp lại.

### B6. Điểm "Training Transfer Score" cần khiêm tốn hơn
Với 8–12 người và không có nhóm đối chứng thật, không thể *chứng minh* hiệu quả. Có thể đo **dấu hiệu** (effect size, khoảng tin cậy). Ngoài ra bản thân bài kiểm tra đầu vào cũng làm người chơi tiến bộ (hiệu ứng luyện tập do kiểm tra). Thiết kế ở C6.

---

## C. Phương án tốt hơn

### C1. Dùng pooltool làm đối chứng thay vì tự viết bộ giải bước nhỏ
**pooltool** (Evan Kiefl, mã nguồn mở, Python) là bộ mô phỏng bida theo sự kiện, dựa trên Leckie & Greenspan, đã xử lý giải đa thức bậc 4 cho thời điểm va chạm, băng, túi [TL]. Lợi ích:
- **Đối chứng độc lập:** chạy cùng điều kiện ban đầu trong pooltool và PoolPhysics, so quỹ đạo. Một đối chứng do người khác viết có giá trị hơn đối chứng tự viết (không chung lỗi tư duy).
- **Tham khảo thuật toán:** xử lý va chạm gần đồng thời, giải nghiệm, các trường hợp biên.
- **Việc cần làm trước:** kiểm tra giấy phép của pooltool trước khi chuyển bất kỳ đoạn mã nào sang Swift; dùng làm công cụ test trên Mac thì không vướng.

Bộ giải bước nhỏ tự viết vẫn giữ ở mức tối thiểu trong test cho các trường hợp pooltool không mô hình hóa giống ta.

### C2. Giới hạn của bộ giải theo sự kiện và cách xử lý trong cùng kiến trúc
| Tình huống | Vấn đề | Cách xử lý |
|---|---|---|
| Bi xếp sát nhau (phá bi) | Nhiều va chạm cùng thời điểm; xử lý tuần tự cho kết quả khác xử lý đồng thời [TL: Leckie & Greenspan] | Gom sự kiện trong cửa sổ Δt nhỏ, xử lý theo thứ tự xác định (thời gian, rồi chỉ số bi). Chấp nhận khác biệt: cú phá không phải trọng tâm luyện tập. |
| Bi tựa băng hoặc tựa bi khác | Va chạm lặp vô hạn với khoảng ngày càng nhỏ (Zeno) | Trạng thái "tiếp xúc" với vận tốc pháp tuyến dưới ngưỡng → bỏ va chạm, triệt thành phần pháp tuyến. |
| Va chạm sượt (tiếp tuyến) | Nghiệm bậc 4 kép, sai số số học | Không dùng công thức Ferrari trực tiếp; khoanh vùng bằng đổi dấu trong khoảng đến sự kiện chuyển trạng thái kế tiếp, rồi Newton + chia đôi. |
| Chuỗi sự kiện bất thường | Vòng lặp không dừng | Giới hạn số sự kiện mỗi cú (ví dụ 20.000). Chạm giới hạn → đánh dấu cú lỗi, ghi seed để tái hiện, **không** âm thầm cắt. |

Mỗi dòng trên phải có test tái hiện bằng seed cố định.

### C3. Quy trình đo bàn thật chỉ với iPhone
**Dụng cụ:** iPhone quay 240 fps, chân máy đặt cao nhìn xuống (hoặc góc chéo cao), máng lăn tự chế (thanh nhôm V hoặc hai thanh gỗ song song, đặt nghiêng ở độ cao cố định), bi cái có chấm đánh dấu để đo vòng quay, thước dây.

**Nguyên tắc chính:** không cần kiểm soát lực. **Đo** vị trí và vận tốc ban đầu trên video, đưa chính các giá trị đó vào mô phỏng, rồi so kết quả. Sai số của người đánh bị loại bỏ khỏi phép so sánh.

**Xử lý video:** 4 điểm mốc đã biết (góc túi, kim cương) → phép chiếu phối cảnh (homography) quy pixel về mét; Vision bám tâm bi. Ở 1080p, mặt bàn 2,54 m ≈ 2,4 mm/pixel — đủ cho góc ~0,3° trên quãng 1 m [GT, cần xác nhận khi làm].

**Bộ thí nghiệm:**
| # | Thí nghiệm | Đo được | Hiệu chỉnh tham số |
|---|---|---|---|
| 1 | Máng lăn, 3 độ cao, bi lăn tự do | Quãng lăn, thời gian dừng | Cản lăn μr |
| 2 | Đánh stun, đo quãng trượt đến khi lăn | Thời gian trượt | Ma sát trượt μs |
| 3 | Máng lăn hướng vào băng ở 3 góc | Góc và tốc độ bật | Phục hồi và ma sát băng |
| 4 | Bi lăn từ máng chạm bi mục tiêu ở nhiều góc cắt | Hướng bi mục tiêu (throw) | Ma sát bi–bi |
| 5 | Cú có xoáy ngang, đánh tay, đo từ video | Quỹ đạo, góc bật | (chỉ kiểm chứng) |

**Chống overfitting:** mỗi thí nghiệm ≥ 20 lần. Gán ngẫu nhiên 50% vào tập hiệu chỉnh, 50% vào tập kiểm chứng *trước khi* xem kết quả. Chỉ hiệu chỉnh tham số riêng của bàn (μr, μs, băng, ma sát bi–bi); giữ các tham số khác theo tài liệu. Báo cáo sai số trên tập kiểm chứng. Ghi lại điều kiện: loại nỉ, độ mới, nhiệt độ/độ ẩm, bi sạch hay bẩn.

### C4. Phạm vi vật lý cho MVP (trả lời câu hỏi III.1–3)
Tiêu chí: hiệu ứng có xuất hiện trong **phần lớn cú đánh luyện tập** và có làm **sai kết quả quá ngưỡng ngắm** (xem D2) không?

| Hiệu ứng | MVP? | Lý do |
|---|---|---|
| Trượt/lăn, cản lăn | Có | Mọi cú đánh. |
| Hướng bi mục tiêu chính xác | Có | Là thứ được luyện ngắm. |
| Throw | Có | Mọi cú cắt; ở cú cắt chậm có thể vài độ [TL: Alciatore] — lớn hơn biên sai số ngắm. |
| Băng phụ thuộc tốc độ và xoáy | Có | Gần như mọi cú đưa bi. |
| Hình học túi (mép, thành) | Có | Quyết định bi có vào hay không. |
| Squirt | Có | Đã cho chọn xoáy ngang thì phải có, nếu không người chơi học sai cách bù. |
| Swerve | Không | Cần góc dốc cơ; MVP cố định cơ gần như nằm ngang. |
| Truyền xoáy sang bi mục tiêu | Không | Ảnh hưởng nhỏ trong cú luyện tập thường. |
| Massé, nhảy bi | Không | Hiếm, đắt. |

### C5. Tách lỗi người chơi / lỗi điều khiển / lỗi vật lý (III.8)
Ghi toàn bộ chuỗi cho mỗi cú: **mẫu cảm ứng thô → StrokeResult → CueStrike → trạng thái bi ban đầu → quỹ đạo**.

- **Lỗi vật lý:** chỉ đo bằng thí nghiệm C3 (điều kiện ban đầu đo từ video, không có người chơi trong vòng lặp).
- **Lỗi điều khiển:** dùng cú vuốt tổng hợp (máy sinh) và phát lại cảm ứng thô đã ghi; cùng đầu vào phải ra cùng CueStrike.
- **Lỗi người chơi:** sau cú đánh, bộ giải tìm hướng/lực *cần thiết* để đạt mục tiêu (tìm kiếm trên chính PoolPhysics), so với hướng/lực người chơi đã dùng → sai số ngắm (độ), sai số lực (mức), lệch vuốt, ngắt cơ.
- **Shot Lab** phát lại đúng CueStrike để xác nhận.

### C6. Đo chuyển giao kỹ năng ở quy mô MVP
- **Bộ kiểm tra bàn thật chuẩn (~20 phút):** 10 cú thẳng xa; 10 cú cắt ~30°; 10 cú lag về băng (đo khoảng cách bằng thước); 10 cú đưa bi cái vào vùng 30 cm. Chấm bằng số, quay video để chấm lại.
- **Thiết kế:** kiểm tra 2 lần trước (cách nhau vài ngày) để đo mức tiến bộ do chính việc kiểm tra → 14 ngày dùng app (ghi số phút) → kiểm tra sau. Người tham gia giữ nguyên lượng tập ngoài đời và ghi nhật ký.
- **Nếu có đủ người:** thiết kế chéo (nửa nhóm dùng app trước, nửa sau).
- **Cỡ mẫu:** 8–12 người là thử nghiệm sơ bộ; báo cáo effect size và khoảng tin cậy, **không** tuyên bố hiệu quả [GT].

---

## D. KPI

Cột "Loại": **BB** = bắt buộc (cổng chặn, không đạt không đi tiếp) · **TƯ** = mục tiêu tối ưu.

### D1. Toán học (máy Mac, `swift test`, release build)
| KPI | Ngưỡng | Loại | Điều kiện đo |
|---|---|---|---|
| Khớp nghiệm giải tích (quãng lăn, 5/7, 90°, 30°=33,7°) | 1e-6 tương đối | BB | Bi đơn, không băng [KT: 33,7° tính kiểm bằng Python] |
| Tính lặp lại | Giống từng bit | BB | 2 lần chạy cùng seed, cùng máy |
| Không chồng lấn | < 1e-6 m | BB | 10.000 cú ngẫu nhiên có seed, gồm phá bi |
| Động năng không tăng | Mọi sự kiện | BB | Cùng bộ 10.000 cú |
| Động lượng cặp bi | Bảo toàn ±1e-9 | BB | Ngay trước/sau va chạm bi–bi cô lập |
| Khớp pooltool | Vị trí dừng ±5 mm | TƯ | 200 cú không xoáy ngang, cùng tham số |
| Không chạm giới hạn sự kiện | 0 cú | BB | Bộ 10.000 cú |

### D2. Thực nghiệm (bàn thật, tập **kiểm chứng** của C3)
Căn cứ ngưỡng: lỗ góc ~114 mm, bi 57 mm → biên sai số khi đưa bi vào tâm lỗ khoảng ±28 mm; ở 1,5 m tương đương ~±1° [GT: tính hình học, bỏ qua hiệu ứng mép lỗ]. Sai số mô hình phải nhỏ hơn nhiều so với biên này thì luyện ngắm mới có ý nghĩa.

| KPI | Ngưỡng ban đầu | Ngưỡng sau xác nhận | Loại |
|---|---|---|---|
| Hướng bi mục tiêu (bi lăn, có throw) | ≤ 0,5° trung vị | ≤ 0,3° | BB |
| Quãng lăn | ≤ 10% | ≤ 5% | BB |
| Góc bật băng (bi lăn) | ≤ 3° | ≤ 2° | BB |
| Tốc độ sau băng | ≤ 10% | ≤ 5% | TƯ |
| Vị trí dừng bi cái, cú 1 băng lực vừa | ≤ 10 cm | ≤ 5 cm | BB (ban đầu) |
| Quỹ đạo có xoáy ngang | ≤ 2° hướng sau băng | ≤ 1° | TƯ |

Ngưỡng "ban đầu" là cổng để đi tiếp; ngưỡng "sau xác nhận" chỉ đặt sau khi có số liệu thật.

### D3. Trải nghiệm (thiết bị thật)
| KPI | Ngưỡng | Loại | Điều kiện đo |
|---|---|---|---|
| Phát lại cảm ứng thô → cùng CueStrike | Giống hệt | BB | Tự động |
| Khóa nhầm | < 1 / 100 cú | BB | 5 người, 100 cú mỗi người, cầm máy tự nhiên |
| Chạm khóa bị bỏ lỡ | < 2% | BB | Như trên |
| Độ trễ từ vượt vạch đến bi chuyển động | < 100 ms | BB | Đo bằng quay video 240 fps màn hình |
| Độ đều lực "vừa" (hệ số biến thiên 10 cú) | ≤ 10% sau 15 phút làm quen | TƯ [GT] | 5 người |
| Người chơi bida đánh giá "cảm giác bi giống thật" | ≥ 4/5 trung bình | TƯ | Phỏng vấn sau TestFlight |

### D4. Hiệu năng (thiết bị thật, release build)
**Thiết bị:** thấp nhất được hỗ trợ (đề xuất iPhone 12/A14) và một máy mục tiêu (iPhone 15 Pro).
**Benchmark:** 1.000 cú phá bi + 1.000 cú ngẫu nhiên có seed; đo bằng `ContinuousClock`; khởi động 50 cú bỏ đi; máy ở `thermalState == .nominal` lúc bắt đầu, cắm sạc tắt; báo p50/p95/max. Ngoại lệ (> p99) không loại bỏ mà ghi seed để điều tra.

| KPI | Ngưỡng | Loại |
|---|---|---|
| Thời gian mô phỏng một cú (p95, máy thấp nhất) | ≤ 50 ms | BB |
| Như trên | ≤ 10 ms | TƯ |
| Thời gian khung hình p99 khi bi chạy | ≤ 16,7 ms | BB |
| 30 phút chơi liên tục, máy mục tiêu | Không đạt `.serious` | TƯ |
| Bộ nhớ ổn định sau 30 phút | < 400 MB, không tăng dần | BB |

---

## E. Kiến trúc

Giữ toàn bộ package hiện có; chỉ thêm ranh giới, không viết lại.

```
Packages/
  PoolPhysics/        (giữ) Swift thuần
    Model/            Ball, CueStrike, PhysicsParameters (đã có)
    Table/            TableDefinition schema (mới, xem dưới)
    Motion/           FreeMotion (đã có)
    Collisions/       bi–bi, bi–băng, túi
    Solver/           EventScheduler, root-finding, Simulation.run → Trajectory
  PoolInput/          (giữ) cảm ứng → CueStrike; ghi mẫu thô để phát lại
  PoolDrills/         (giữ, mở rộng) bài tập, chấm điểm, lịch sử, phân tích lỗi
App/                  RealityKit, camera, haptic, SwiftData, Shot Lab
Tools/                (mới, chỉ chạy trên Mac)
  validation/         Python: pooltool đối chứng, xử lý video, so sánh, báo cáo
```

Ranh giới: PoolPhysics không biết gì về UI; PoolInput không biết vật lý ngoài kiểu `CueStrike`; App là nơi duy nhất ghép chúng. Tools không nằm trong app.

**Schema bàn (phác thảo, chưa viết code):**
```swift
struct TableDefinition: Codable {
    var schemaVersion: Int                  // tăng khi đổi cấu trúc; có hàm migrate
    var id: String                          // "zoker-9ft-v1"
    var geometry: TableGeometry             // SI: mét
    var physics: PhysicsProfile             // tham số mặc định
    var visualAssetName: String             // tham chiếu tài nguyên trong App
}
struct CalibrationProfile: Codable {        // lưu riêng, gắn với một bàn thật
    var schemaVersion: Int
    var tableId: String
    var measuredAt: Date
    var overrides: [ParameterKey: Measured<Double>]
}
struct Measured<T: Codable>: Codable {
    var value: T
    var provenance: Provenance
}
enum Provenance: Codable {
    case published(source: String)                  // "Mathavan et al. 2010, Table 2"
    case measured(method: String, samples: Int, residual: Double)
    case assumed(note: String)                       // hiển thị cảnh báo trong Shot Lab
}
// Mỗi struct có `func validate() throws`: dương, trong khoảng vật lý hợp lý, đơn vị SI.
```

---

## F. Lộ trình (theo giá trị luyện tập, rủi ro, phụ thuộc)

| # | Bước | Ra được gì | Cổng |
|---|---|---|---|
| R0 | Kiểm toán: build, test, sửa lỗi biên dịch | Nền chạy được | D1 các test hiện có xanh |
| R1 | Bộ giải nhiều bi: va chạm bi–bi, băng đơn giản, túi; đối chứng pooltool | Mô phỏng một bàn đầy đủ | D1 toàn bộ BB |
| R2 | **Lát cắt chơi được trên iPhone:** camera, ngắm, effect, khóa, vuốt, render đơn giản, phản hồi | Thử nội bộ sớm | D3 BB, D4 BB |
| R3 | Throw, squirt, băng phụ thuộc tốc độ/xoáy, túi chi tiết | Vật lý MVP | D1 BB vẫn xanh |
| R4 | Bộ đo bàn thật (C3), hiệu chỉnh và kiểm chứng | Bằng chứng mô hình đúng | **Cổng 1: D2 ngưỡng ban đầu** |
| R5 | 10 bài tập, lịch sử, phân tích lỗi, Shot Lab | Sản phẩm luyện tập | — |
| R6 | TestFlight + thử nghiệm chuyển giao (C6) | Bằng chứng giá trị | **Cổng 2: có dấu hiệu tiến bộ trên bàn thật** |
| R7 | Đồ họa nâng cao, swerve, các mục docs/06 | Hoàn thiện | D4 TƯ |

Lý do đặt R2 trước R3: giao diện là rủi ro lớn nhất về trải nghiệm và rẻ để thử sớm; vật lý nâng cao cắm vào sau không làm đổi giao diện.

---

## G. MVP (bản nhỏ nhất lên iPhone thử với người thật)
Kết thúc R5, trước đồ họa nâng cao:
- Một bàn Zoker 9 ft, chỉ iPhone, màn hình ngang.
- Vật lý theo C4.
- Natural Stroke: ngắm không trợ giúp, bi effect, khóa rung, vuốt ra cơ.
- Phản hồi sau cú: sai số ngắm, mức lực, lệch vuốt, phát lại.
- 10 bài tập + lịch sử + một màn Shot Lab.
- Đồ họa đơn giản nhưng đủ các yếu tố ở dưới.

**Yếu tố đồ họa ảnh hưởng trực tiếp đến luyện tập (làm trong MVP):**
1. Phối cảnh đúng: FOV, độ cao mắt, tỉ lệ — quyết định ngắm.
2. Mép bi sắc, khử răng cưa (MSAA) — quyết định cú cắt mỏng.
3. Khung hình đều 60 fps — quyết định cảm nhận tốc độ.
4. Bi có số, bi cái có chấm — **thấy được xoáy** và tốc độ quay.
5. Bóng tiếp xúc — cảm nhận khoảng cách bi tới băng, bi tới bi.
6. Kim cương rõ — dùng cho công thức.

Không ảnh hưởng (để sau): vân gỗ, phòng, phản chiếu phức tạp, sợi nỉ, kim loại.

**20% tính năng tạo 80% giá trị (III.10):** hướng bi mục tiêu chính xác + throw, ngắm không trợ giúp từ góc nhìn đúng, vuốt nhất quán, phản hồi sai số sau mỗi cú, bài tập lặp lại có lịch sử.

---

## H. Quyết định cần phê duyệt (5)

1. **Tuyên bố sản phẩm và vai trò cú vuốt:** app luyện mắt và tư duy, không luyện động tác tay. Cú vuốt tối ưu cho tính nhất quán; không hiệu chỉnh theo tốc độ đầu cơ thật.
2. **Manual Stroke → Shot Lab:** công cụ phân tích và bài tập quyết định, không phải chế độ luyện tập chính.
3. **Dùng pooltool làm đối chứng** (kiểm tra giấy phép trước khi tham khảo mã) thay vì tự viết bộ giải bước nhỏ đầy đủ.
4. **Phạm vi vật lý MVP theo C4:** có throw, squirt, băng, túi; hoãn swerve, truyền xoáy, massé, nhảy. Cơ cố định gần nằm ngang.
5. **Phương pháp kiểm chứng:** đo điều kiện ban đầu từ video 240 fps + máng lăn tự chế; chia 50/50 hiệu chỉnh/kiểm chứng; không cần thiết bị đo tốc độ cơ.

---

## I. Phân loại nguồn

**[TL] Tài liệu tham khảo**
- D. Alciatore — *The Illustrated Principles of Pool and Billiards* và loạt "Technical Proofs" (lăn/trượt, quy tắc 30°/90°, throw, squirt).
- S. Mathavan, M. Jackson, R. Parkin (2010) — phân tích va chạm băng, Proc. IMechE Part P.
- W. Han (2005) — động lực học bi carom và băng, J. Mechanical Science and Technology.
- W. Leckie, M. Greenspan (2006) — "An Event-Based Pool Physics Simulator", Advances in Computer Games.
- W. Marlow — *The Physics of Pocket Billiards*.
- pooltool (E. Kiefl) — bộ mô phỏng mã nguồn mở theo sự kiện.
- Nguyên lý đặc thù trong học vận động (specificity of practice) — tài liệu khoa học vận động nói chung.

**[KT] Đã kiểm tra thực tế**
- Góc lệch 33,7° của quy tắc 30° với mô hình hiện tại: tính kiểm bằng Python.
- Code Swift khởi tạo: **chưa biên dịch, chưa chạy test.**

**[GT] Giả thuyết chưa xác minh**
- Mức chuyển giao kỹ năng ngắm/lực từ app ra bàn thật.
- Độ chính xác đo góc ~0,3° từ video 1080p.
- Ngưỡng ±1° ở 1,5 m (hình học đơn giản hóa).
- Các ngưỡng hiệu năng, độ đều lực, tỉ lệ khóa nhầm.
- Chi tiết thuật toán và giấy phép của pooltool cần đọc trực tiếp trước khi dùng.
