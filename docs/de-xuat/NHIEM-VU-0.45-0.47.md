# Nhiệm vụ 0.45 → 0.47 — Xương sống · Diện mạo mới · Quay lại mỗi ngày

Chủ dự án duyệt 17/11/2026 20:03: đổi thứ tự thành xương sống → diện mạo → tính năng; **mục tiêu xong 0.47 trong ngày 18/11**.
Thay cho `NHIEM-VU-0.45.md` cũ (16/11). Viết bởi phiên đám mây; phiên Claude Code trên Mac thi công.

## Cách chạy nối tiếp (đọc trước)

- Làm **sau khi** 0.44.1 đã đẩy `cho/native-0.44.1` với `Docs/NGHIEM-THU-0.44.1.md`.
- Mỗi bản một nhánh, tạo từ nhánh bản trước: `cho/native-0.45` ← `cho/native-0.44.1`; `cho/native-0.46` ← `cho/native-0.45`; `cho/native-0.47` ← `cho/native-0.46`. Xong bản nào đẩy nhánh bản đó rồi làm bản sau ngay, **không chờ review** (phiên đám mây review song song và gửi lỗi vào nhánh `plan/de-xuat-zoker`, file `docs/de-xuat/REVIEW-0.45-0.47.md`; đầu mỗi mốc `git fetch` và đọc file đó, lỗi chặn sửa trước).
- Không push `ci/*`, không sửa `.github/workflows`, không commit 18 file AppIcon, không gộp vào `feature/*`.
- Mỗi mốc: test trước (C++ trong `Tests/*.cpp`, đăng ký ở `CMakeLists.txt` và `Run-All-Checks.command`; Swift/XCTest cho giao diện), commit, chạy kiểm tra của mốc. Cuối mỗi bản chạy `bash Tools/accept_local.sh`, viết `Docs/NGHIEM-THU-0.4x.md` (PASS/FAIL/NOT RUN từng mốc, ảnh trước/sau), cập nhật `Docs/TRANG-THAI.md`.
- Số phiên bản: 0.45 (26), 0.46 (27), 0.47 (28).
- Tính năng mới đặt sau cờ (`FeatureFlags`, mặc định BẬT cho bản thử) để bán theo gói sau này.
- Hết thời gian: ưu tiên giữ đúng thứ tự mốc, giao phần đã PASS, ghi rõ phần dở. Không rút gọn kiểm tra, không đổi tiêu chí để cho qua.
- Mọi chuỗi mới: tiếng Việt + tiếng Anh trong i18n; không chuỗi nào chỉ có một ngôn ngữ.

---

## 0.45 "Xương sống" — mượt thật ở 120 Hz, mã dễ sửa, hệ thiết kế

Không đổi luật chơi, vật lý hay luồng màn hình. Người dùng thấy: mượt hơn, chữ và nút đồng nhất.

### M0 — Điều phối tự động theo vai (làm đầu tiên, ~15 phút)
Phiên chính trên Mac là **người điều phối**: đọc nhiệm vụ, chia mốc, giao việc cho subagent theo bảng, gộp kết quả, chạy kiểm tra, commit. Không tự viết khối mã lớn khi đã có vai phù hợp.
1. Thêm `.claude/agents/ky-su-loi.md`: `model: opus`, `effort: high`. Mô tả: "Kỹ sư lõi. Dùng chủ động cho vòng khung hình/render, tách mã lớn không đổi hành vi, lõi vật lý C++ và mọi lỗi gốc cần đo trước khi sửa."
2. Sửa mô tả 3 vai có sẵn, thêm "Dùng chủ động …": `ky-su-giao-dien` thêm `effort: medium` (màn hình, ZDesign, i18n, XCUITest); `kiem-ke` thêm `effort: low` (đếm, đối chiếu, đọc log, chạy accept_local và trích PASS/FAIL); `giam-khao` giữ opus/high, gọi **cuối mỗi bản** trước khi đẩy nhánh, báo lỗi chặn thì sửa trước khi đẩy.
3. Ghi bảng giao việc vào `CLAUDE.md` của `native/ZokerPoolTrainer` (mục "Điều phối"):

| Việc | Vai |
|---|---|
| 0.45 M1 vòng khung hình, M2 tách TrainingController, 0.46 M3 hình học bàn + test 3 cỡ | ky-su-loi |
| 0.45 M3 ZDesign + i18n, 0.46 M1–M2 Sảnh/HUD/menu, 0.47 M1–M4 phần Swift | ky-su-giao-dien |
| Kiểm kê sau mỗi mốc, đọc log accept_local | kiem-ke |
| Review cuối mỗi bản | giam-khao |

4. Không đặt `CLAUDE_CODE_EFFORT_LEVEL` trong môi trường (biến này đè effort của từng vai).

### M1 — Vòng khung hình (đo trước, sửa sau)
Số đo trên iPhone của chủ dự án (IPA 156, 17/11):

| | 60 Hz | 120 Hz |
|---|---|---|
| Khung thiếu mẫu | 0/386 | 160–202 / 479–557 (33–36 %) |
| "Cảnh 3D" p95 / max | 0,18 / 3,8 ms | 18–25 / 29–33 ms |
| "Sự kiện/âm" max | 0,17 ms | 18–25 ms |

Gấp đôi tần số mà cảnh 3D chậm ~100 lần ⇒ nhiều khả năng luồng chính **chờ khoá của SceneKit** (render thread đang giữ `SCNTransaction`/scene lock khi GPU bận), không phải tốn tính toán. Hiện có hai đồng hồ: `CADisplayLink` → `TrainingController.tick` (`UI/TrainingController.swift:1583`) và vòng của `SCNView` (`scn.preferredFramesPerSecond`, `FramePacer` là `SCNSceneRendererDelegate`).
1. Đo trước khi sửa: thêm vào `ShotProfile` thời gian GPU mỗi khung (`MTLCommandBuffer.gpuEndTime-gpuStartTime` qua `scn.commandQueue`/`SCNSceneRenderer` nếu lấy được, không thì `renderer(_:didRenderScene:atTime:)` − `willRender`), và thời gian chờ khoá (bọc riêng đoạn ghi vào node). Ghi kết quả vào nghiệm thu.
2. Hướng sửa (chọn theo số đo, ghi lý do):
   a. Mọi ghi vào cây node trong khi bi chạy đi qua MỘT chỗ: `renderer(_:updateAtTime:)` trên render thread (FramePacer đã ở đó); `tick` chỉ chạy logic + đẩy mẫu vào hàng đợi khoá-tự-do. Không gọi `SCNTransaction.flush()` trong khung.
   b. Nếu GPU là giới hạn: ở 120 Hz tự hạ `contentScaleFactor`/tắt MSAA theo ngân sách GPU đo được.
   c. Dùng `preferredFrameRateRange(min:60,max:120,preferred:120)` cho cả `CADisplayLink` và `SCNView`.
3. Giữ cơ chế tự về 60 Hz của 0.44.1 làm lưới an toàn.
4. Kiểm: `Tools/run_perf_qa.sh` trên Simulator không xấu hơn 0.44.1; trên Mac Intel ghi số. **Tiêu chí thiết bị (chủ dự án đo):** 120 Hz ≤ 2 % khung thiếu mẫu, "Cảnh 3D" p95 ≤ 4 ms. Trước khi chủ dự án đo: ghi "chưa xác minh trên thiết bị".

### M2 — Tách `TrainingController` (3.287 dòng) — không đổi hành vi
- Tách thành các phần có ranh giới rõ, mỗi file ≤ 900 dòng: `ShotLoop` (tick, frameStep, pacing, đo), `AimInput` (cử chỉ ngắm/ra cơ), `HUDController` (phím, nhãn, fade, bố cục), `MatchCoordinator` (Wi‑Fi/Nearby/máy đối thủ/đồng hồ cú), `MenuRouter` (menu, sheet, Tuỳ chỉnh). `TrainingController` chỉ còn lắp ráp.
- Cách làm an toàn: di chuyển nguyên khối (extension sang file mới trước, rồi mới thành lớp riêng nếu cần), mỗi bước build + chạy toàn bộ XCTest + C++; không sửa logic trong cùng commit di chuyển.
- Kiểm: toàn bộ test cũ PASS không sửa nội dung kiểm; ảnh chụp CI giống 0.44.1 (so pixel, sai khác ≤ 0,5 % ngoài vùng chữ động).

### M3 — Hệ thiết kế `ZDesign`
- Một file token: màu (nền, viên mờ, chữ chính/phụ, vàng nhấn `LobbyController.gold`, đỏ/xanh trạng thái), cỡ chữ (Dynamic Type, tối thiểu 13 pt trên iPhone), bo góc, khoảng cách, thời gian chuyển động.
- Thành phần dùng chung: `ZPill` (viên mờ `UIVisualEffectView` thay mọi khung nền đen), `ZButton` (một dòng, `adjustsFontSizeToFitWidth`, tối thiểu 0,7, không ngắt giữa từ), `ZSheet`, `ZToast`.
- Thay dần ở các chỗ đã có lỗi: khung Coach, hàng nút Coach (Nút số / Điểm ngắm / Chấm cú), toast trạng thái, bong bóng hướng dẫn. Không vẽ lại màn hình nào ở bản này (đó là 0.46).
- i18n: script kiểm mọi chuỗi hiển thị có đủ vi + en (`Tools/i18n`); test XCTest mở app với máy tiếng Việt, cài mới → không có chuỗi tiếng Anh trên khung Coach/Sảnh; máy tiếng Anh → ngược lại.
- Kiểm: ảnh chụp các chỗ đã thay, trước/sau; script i18n PASS.

### M4 — Thử nhanh RealityKit (tối đa 3 giờ, chỉ để quyết)
- Nhánh rác `thu/realitykit` (không đẩy vào nhánh bản): dựng bàn 9 ft + 16 bi + đèn + nỉ bằng RealityKit, chạy cùng dữ liệu cú ghi sẵn, đo ms/khung trên Simulator và Mac.
- Ghi `Docs/THU-REALITYKIT.md`: hơn/kém SceneKit ở mức khung, chất lượng hình, công sức chuyển. **Không chuyển engine trong 0.45–0.47.**

### M5 — Dữ liệu người chơi, luồng khởi động, số liệu cục bộ (thêm 17/11 20:45 sau kiểm tra kiến trúc)
Kiểm tra kiến trúc (VERIFIED trên `cho/native-0.44.1`): tiến bộ của người chơi chỉ là một từ điển sao `lessonStars035` gắn theo **tiêu đề tiếng Việt** (`UI/Models.swift`), không có lịch sử lượt tập; 81 khoá UserDefaults rải rác; 56 chỗ `DispatchQueue.main.asyncAfter` dùng hẹn giờ để nối các bước (đúng loại lỗi làm intro/hướng dẫn hỏng); 50 cờ QA trong bản phát hành. 0.47 không xây được vòng hằng ngày trên nền này.
1. `PlayerStore` (một file JSON có `schemaVersion` trong Application Support, ghi nguyên tử, đọc lỗi thì giữ bản sao `.bak`): lượt tập (mã bài ổn định, thời điểm, ngày địa phương, vào/trượt, sao, thời gian), chuỗi ngày (`BLStreak`), cấp độ, kỷ lục. Một nơi duy nhất ghi; giao diện chỉ đọc.
2. **Mã bài ổn định**: mỗi `Drill` có `id` chuỗi không đổi (ví dụ `cut-30-l2`); chuyển `lessonStars035` theo tiêu đề sang id một lần khi mở app (test chuyển đổi: dữ liệu cũ vẫn còn đủ sao).
3. `AppFlow`: máy trạng thái khởi động `intro → sảnh → (hướng dẫn nếu chưa xong) → bàn`; mỗi bước báo xong bằng lời gọi, không hẹn giờ. Thay các `asyncAfter` của luồng khởi động và hướng dẫn; các chỗ còn lại ghi danh sách để dọn dần.
4. `Prefs`: gom mọi khoá UserDefaults vào một enum (giữ nguyên chuỗi khoá để không mất cài đặt).
5. Số liệu cục bộ (không mạng): số ngày mở app, số phiên, số cú, số bài xong, ngày cài. Tuỳ chỉnh → Máy → "Sao chép số liệu sử dụng" để người thử tự gửi. Đây là cách đo D1/D7 cho bản thử.
6. Cờ QA: nếu ảnh CI chụp từ bản Debug thì bọc mọi nhánh `--*-qa` bằng `#if DEBUG`; nếu không, ghi lại và để 0.48 (không sửa workflow).
- Kiểm: test Swift cho PlayerStore (ghi/đọc, file hỏng → khôi phục `.bak`, chuyển dữ liệu sao cũ), XCTest khởi động đi qua `AppFlow` (cài mới → intro → sảnh → hướng dẫn → bàn) trên máy tiếng Việt.

---

## 0.46 "Diện mạo mới" — Sảnh, HUD, menu, bàn dựng lại

Dùng `ZDesign` của 0.45. Không đổi vật lý (trừ kích thước bàn ở M3, có test).

### M1 — Sảnh mới
- Thẻ lớn **"Tiếp tục"** (bài/trận gần nhất, một chạm vào bàn) đứng đầu; dưới là 4 ô: Tập tự do · Bài tập · Đấu (máy / Chơi gần / Wi‑Fi) · Thư viện bàn‑cơ.
- Nền là bàn 3D thật phía sau, mờ nhẹ (dùng scene sẵn có, không tạo scene thứ hai).
- Tối đa 2 chạm từ mở app tới đánh cú đầu.
- Kiểm: XCTest mở app → Sảnh → "Tiếp tục" → bàn; ảnh iPhone + iPad.

### M2 — HUD trong trận và menu
- Phím bên phải giữ chức năng hiện có, vẽ lại bằng `ZButton` (biểu tượng SF Symbols + nhãn ngắn), nhóm theo tần suất: Xem lại · Lùi cú luôn hiện; Đặt bi · Thêm bi · Bao cơ · Camera gom vào một nút "Bàn".
- Bộ chọn cơ (Đánh/Jump/Massé/Break) dùng icon 3D của 0.44.1 M3, không còn nhãn mã.
- Menu trong trận còn 4 mục: Tiếp tục · Đổi bàn‑bi‑gậy · Tuỳ chỉnh · Về sảnh. Mục "Sao chép số đo cú vừa đánh" chuyển vào Tuỳ chỉnh → Máy (đã mở thẳng ở 0.44.1).
- Không xoá chức năng đang chạy; chỉ đổi chỗ. Bảng "trước/sau" mọi chức năng trong nghiệm thu.
- **Phòng thí nghiệm** (Tuỳ chỉnh → Máy, công tắc mặc định TẮT): gom thanh vật lý, ZUPE Lab, A/B, FPS/chẩn đoán, chọn engine âm. Tắt thì ẩn khỏi mọi menu. Người chơi thường không thấy công cụ kỹ sư.
- Ngôn ngữ hiển thị trong bộ chọn: chỉ Tiếng Việt và English; 5 ngôn ngữ dịch máy chỉ hiện khi bật Phòng thí nghiệm (đến khi có người dịch).
- Kiểm: XCTest cử chỉ cũ PASS (cập nhật định danh nếu đổi chỗ); đếm số chạm cho 5 việc chính (đánh cú, xem lại, lùi cú, đổi cơ, đổi camera) — không việc nào tăng.

### M3 — Bàn dựng lại theo họ kiểu dáng
- Kích thước WPA mặt chơi: **9 ft 2,54 × 1,27 m · 8 ft 2,34 × 1,17 m · 7 ft 1,98 × 0,99 m**; miệng lỗ góc 11,4–11,7 cm, lỗ giữa 12,7–13,0 cm (WPA Equipment Specifications). `Core/Physics.hpp:24` đã có `width,length`: thêm test C++ rằng 3 cỡ đều cho cú thẳng vào lỗ góc và băng phản xạ đúng; bàn mặc định vẫn 9 ft.
- Thay 20 mẫu chắp vá bằng **4 họ tham số hoá** (tên tạm, chủ dự án đổi được): 
  - **Z-Arena** — bàn thi đấu: chân hộp vuông, khung phẳng đen mờ, ốp kim loại.
  - **Z-Heritage** — cổ điển: chân tiện tròn, gỗ óc chó, viền chạm đơn giản.
  - **Z-Loft** — hiện đại: chân chữ A/ống thép, gỗ sáng, cạnh bo.
  - **Z-Club** — quán: chân trụ đôi, gỗ sẫm, nỉ xanh.
  Mỗi họ: hình chân, khung, ốp góc, chất gỗ/kim loại, màu nỉ mặc định là tham số; mỗi họ 3 phối màu ⇒ 12 lựa chọn. Hình học dựng bằng mã (không tải mô hình ngoài). Giữ `id` cũ ánh xạ sang họ gần nhất để cài đặt đã lưu không mất.
- Thư viện bàn: lưới ảnh kết xuất sẵn từ 3D (giống icon cơ 0.44.1).
- Kiểm: ảnh 4 họ × 1 phối trong "phòng chuẩn"; đầu dò: không điểm ảnh cháy > 2 %; test C++ 3 cỡ PASS; không còn tên sản phẩm thật.

---

## 0.47 "Quay lại mỗi ngày" — vòng luyện tập

**Chia việc (17/11 20:10, cập nhật 21:30):** phiên đám mây đã viết sẵn lõi C++ + test của 0.47 — `UI/DailyLoop.h` (thanh lực, ngày địa phương, chuỗi + đóng băng, cấp độ, Bài hôm nay xen kẽ loại, sao, kỷ lục) và `UI/Challenge.h` (mức phản hồi M5, mã thách bạn M6); thêm hai dòng `#import` vào bridging header khi nối dây trên nhánh `cho/native-0.47-core`, chỉ thêm file mới trong `BankLab/Core/` và `Tests/` cộng dòng đăng ký bộ test. Khi bắt đầu 0.47: `git merge origin/cho/native-0.47-core` (xung đột chỉ có thể ở danh sách bộ test trong `CMakeLists.txt`/`Run-All-Checks.command`: giữ cả hai). Phiên Mac chỉ làm phần Swift + nối dây. Nếu nhánh đó chưa có thì tự viết lõi theo mô tả dưới.

Logic thuần (chọn bài, tính chuỗi, sao, kỷ lục) viết C++ + test; Swift chỉ vẽ. Lưu cục bộ (UserDefaults/JSON trong Application Support), không mạng.

### M0 — Kho bài theo chương: dễ → khó, mỗi chương một mẹo dễ nhớ (thêm 17/11 22:40, chủ dự án yêu cầu)
Mục tiêu: người chơi luôn biết "mình đang học gì, mẹo là gì, còn bao xa". Mỗi chương = **1 mẹo** của chuyên gia (câu ngắn dễ thuộc) + **thang 3 bài** dễ → khó + **thi chương**. Bài hiện có (30) được xếp vào chương; thêm bài mới ở chương 3–4.

| Chương | Mẹo (câu nhớ) | Nguồn mẹo | Thang bài (dễ → khó) | Thước đo (chỉ ở màn "Học" và khi xem lại, không hiện khi đánh) |
|---|---|---|---|---|
| 1 Cú thẳng | "Thẳng – dừng – theo – lùi" | Bài stop/theo/lùi của Kinister và Dr. Dave | Cú đầu tiên → Stop · Giữ bi cái → Cu-lê → Trô | Vòng đích bi cái (bán kính 1 bi) |
| 2 Lực | "Lực là quãng lăn" | Thang Lực 1–30 của app | Lực 1/3 → 2/3 → 3/3 (đã có) | Thước quãng lăn, vạch dừng |
| 3 Ngắm cắt | "Nửa bi = 30°" (đầy 0° · ¾ ≈ 14,5° · ½ = 30° · ¼ ≈ 48,6°) | Ngắm theo phần bi (hình học, sin góc = 1 − phần chồng) | **Mới:** cắt ¾ → ½ → ¼, rồi cắt 30°/45° vào lỗ góc (đã có) | Thước góc cắt; hình bi ma ở lần xem lại |
| 4 Đường bi cái | "Bi đứng đi vuông 90° · bi lăn lệch 30° · trô gấp 3 lần góc" | Quy tắc 90° và 30° (Dr. Dave, "cử chỉ chữ V"); hệ trisect cho trô | **Mới:** 90° né bi cản → 30° tránh lỗ → trô chéo | Đường tiếp tuyến; chữ V 30°; tia trô ×3 |
| 5 Băng | "Gương và số nút" | Gương 1 băng; Corner-5 (đã có) | Kick 1 băng → 2 băng → 3 băng; Bank 1→3 | Số nút trên băng (đã có, bật Coach) |
| 6 Kỹ thuật đặc biệt | "Cơ dựng – bi bay/cong" | Đã có trong app | Combo → Jump → Massé → Zigzag | — |

Luật lên bậc (theo cách Billiard University): mỗi bài 5 lượt, **đạt ≥ 3/5 thì mở bài kế**; thi chương = 10 cú không trợ giúp, đạt ≥ 7/10 thì mở chương sau và được 1 món đồ (cơ/bàn/phòng). Người chơi cũ có sao sẵn được mở tương ứng (không bắt học lại).
- Thẻ mẹo: lần đầu vào chương hiện **một** thẻ mẹo (hình động 3–5 s trên bàn thật + câu nhớ ≤ 8 từ); sau đó thẻ nằm trong "Sổ mẹo" để xem lại. Không chữ dài.
- Dữ liệu: mỗi bài có `id` ổn định, `chapter`, `rung` (1–3), `category` (dùng cho `BLDailyPickMixed`), `stars`. Bài hôm nay chỉ chọn trong các chương đã mở.
- Bài mới chương 3–4: **phiên đám mây viết thế bi + test C++ quét (như `FirstShotTests`) trên `cho/native-0.47-core`** để chắc mỗi bài làm được bằng đúng mẹo của chương; phiên Mac chỉ nối dữ liệu và màn hình.
- Kiểm: XCTest đi hết chương 1 bằng cú bắn QA; test C++ mọi bài mới; ảnh thẻ mẹo và màn chương.
- Đo sơ bộ trên vật lý của app (phiên đám mây, 17/11 22:55, `Config::app()`, cắt ½ bi, bi cái cách 0,5 m): bi lăn lệch **33–34°** so với hướng ngắm ở 1–3 m/s → quy tắc 30° của Dr. Dave đúng trên app. Nhưng ngắm đúng "bi ma" ở cắt 30° và 48,6° thường **trượt** vì độ "ném" (throw) của app lớn hơn tài liệu (code ghi 3,6° so với 1,7° ở 3 m/s). Hệ quả: mẹo chương 3 phải kèm câu "cắt mỏng hơn một chút khi đánh chậm"; bài mới chương 3 được dựng bằng cách quét góc ngắm tìm khung vào lỗ (sao = `BLStarsFromMargin`). Phiên đám mây làm tiếp phần này.

### M1 — Thanh lực cho người mới (cờ `powerBar`, mặc định bật cho người mới)
- Thanh dọc bên phải: kéo xuống để nạp lực, thả để đánh; ánh xạ lực qua `PowerScale.h` hiện có (giữ trần lực của Tuỳ chỉnh). Vuốt cơ (B) vẫn dùng được; Tuỳ chỉnh có công tắc chọn kiểu.
- Hướng dẫn 0.44.1: nhịp 2 đổi sang thanh lực khi cờ bật (dữ liệu nhịp, không viết lại).
- Kiểm: test C++ ánh xạ đơn điệu, 0 → lực tối thiểu, 100 % → trần; XCTest kéo thanh → cú được đánh với lực đúng ±2 %.

### M2 — Bài hôm nay + chuỗi ngày
- Thẻ "Bài hôm nay" ở đầu Sảnh (trên "Tiếp tục"): 3 bài/ngày chọn theo hạt giống ngày + trình độ (từ kết quả 7 ngày gần nhất), 5–8 phút.
- Dùng `BLDailyPickMixed` (lõi đã có ở `cho/native-0.47-core`) với loại bài (cắt, băng, đi bi, kick…): mỗi ngày xen kẽ các loại khác nhau — luyện xen kẽ giữ kỹ năng tốt hơn luyện khối.
- Chuỗi ngày: hoàn thành ≥ 1 bài trong ngày (theo giờ địa phương) +1; **đóng băng chuỗi** 1 lần/tuần tự động dùng khi lỡ 1 ngày.
- Kiểm: test C++ chuỗi qua đổi múi giờ, nửa đêm, lỡ 1 ngày (dùng đóng băng), lỡ 2 ngày (về 0), đổi giờ máy lùi (không cộng chuỗi).

### M3 — Sao độ khó, màn tiến bộ, "Kỷ lục mới"
- Mỗi bài có sao 1–5 tính từ biên sai số góc (dùng chung hàm của máy đối thủ). Kết quả bài: sao đạt, thời gian, tỉ lệ vào.
- Màn "Tiến bộ" (Swift Charts): tỉ lệ vào theo ngày, 7/30 ngày; chuỗi; số bài.
- "Kỷ lục mới": khi phá kỷ lục cá nhân của một bài → hiệu ứng ngắn (≤ 1,5 s, chạm để bỏ qua).
- Kiểm: test C++ kỷ lục chỉ báo khi thật sự hơn; ảnh màn Tiến bộ với dữ liệu giả 30 ngày.

### M4 — Hiệu ứng khi chơi
- Dùng lại `ShotFX` của intro 0.44.1: bi lọt lỗ có tia sáng nhỏ ở miệng lỗ, rung nhẹ (haptic) theo lực, camera rung rất nhẹ khi phá bi mạnh (tắt được, tắt khi Reduce Motion).
- Ngân sách: không làm "Cảnh 3D" p95 tăng quá 0,5 ms (đo bằng `run_perf_qa.sh`).
- Kiểm: perf QA trước/sau; ảnh khoảnh khắc lọt lỗ.

### M5 — Phản hồi giảm dần (cái làm app "hữu dụng" chứ không chỉ vui)
Nghiên cứu học vận động: phản hồi kết quả sau MỌI lượt giúp làm tốt lúc tập nhưng giữ kỹ năng kém hơn (giả thuyết "dẫn dắt"), trừ với việc khó; luyện xen kẽ giữ tốt hơn luyện khối.
- Cấp 1–2 hoặc bài 4–5 sao: sau mỗi cú trượt hiện đầy đủ "lệch bao nhiêu, vì sao" (như nay).
- Cấp 3–5 với bài 1–3 sao: chỉ hiện vào/trượt; chi tiết gộp sau 5 cú ("trung bình lệch trái 0,6°"). Người chơi bấm "Xem chi tiết" vẫn xem được (không giấu).
- Mỗi tuần một "Bài kiểm không trợ giúp" 10 cú, không phản hồi giữa chừng, kết quả cuối mới hiện; đây là số "tiến bộ thật" trên màn Tiến bộ.
- Logic chọn mức phản hồi viết C++ + test (bảng cấp × sao → mức).

### M6 — Thách bạn bằng mã (nếu còn thời gian; không cần máy chủ)
- Sau một bài: "Thách bạn" tạo mã 8 ký tự (mã bài + hạt giống + điểm), chia sẻ qua bảng chia sẻ iOS kèm ảnh thẻ kết quả.
- Bạn nhập mã (hoặc mở liên kết `zoker://` khi có) → chơi đúng bài đó → hai điểm hiện cạnh nhau.
- Lý do: trong ba nhu cầu làm game cuốn (năng lực, tự chủ, gắn kết), app hiện chưa có gì cho "gắn kết".
- Kiểm: test C++ mã hoá/giải mã, mã sai bị từ chối; XCTest nhập mã → đúng bài.

---

## Sau 0.47 (không làm trong đợt này)
Bản thử cho người lạ 0.48: privacy manifest, `ITSAppUsesNonExemptEncryption`, entitlements, ẩn online, rà toàn bộ i18n, vật lý "Theo tài liệu" — cần tài khoản Apple Developer để lên TestFlight.

## Mặc định khi không ai trả lời
- Tên 4 họ bàn và phối màu: theo trên. Thanh lực: bật cho người mới (chưa đánh ≥ 50 cú), người cũ giữ vuốt.
- Nếu M1 của 0.45 không đạt tiêu chí 120 Hz trên Simulator/Mac: vẫn giao, giữ 60 Hz mặc định, ghi rõ.
- Nếu tách `TrainingController` làm vỡ test mà không sửa được trong 1 giờ: hoàn lại bước đó, giao phần đã tách sạch.
