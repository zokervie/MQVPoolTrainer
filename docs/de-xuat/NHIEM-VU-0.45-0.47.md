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

**Chia việc (17/11 20:10):** phiên đám mây viết sẵn phần lõi C++ + test của 0.47 (ánh xạ thanh lực, chọn Bài hôm nay, chuỗi ngày + đóng băng, sao độ khó, kỷ lục) trên nhánh `cho/native-0.47-core`, chỉ thêm file mới trong `BankLab/Core/` và `Tests/` cộng dòng đăng ký bộ test. Khi bắt đầu 0.47: `git merge origin/cho/native-0.47-core` (xung đột chỉ có thể ở danh sách bộ test trong `CMakeLists.txt`/`Run-All-Checks.command`: giữ cả hai). Phiên Mac chỉ làm phần Swift + nối dây. Nếu nhánh đó chưa có thì tự viết lõi theo mô tả dưới.

Logic thuần (chọn bài, tính chuỗi, sao, kỷ lục) viết C++ + test; Swift chỉ vẽ. Lưu cục bộ (UserDefaults/JSON trong Application Support), không mạng.

### M1 — Thanh lực cho người mới (cờ `powerBar`, mặc định bật cho người mới)
- Thanh dọc bên phải: kéo xuống để nạp lực, thả để đánh; ánh xạ lực qua `PowerScale.h` hiện có (giữ trần lực của Tuỳ chỉnh). Vuốt cơ (B) vẫn dùng được; Tuỳ chỉnh có công tắc chọn kiểu.
- Hướng dẫn 0.44.1: nhịp 2 đổi sang thanh lực khi cờ bật (dữ liệu nhịp, không viết lại).
- Kiểm: test C++ ánh xạ đơn điệu, 0 → lực tối thiểu, 100 % → trần; XCTest kéo thanh → cú được đánh với lực đúng ±2 %.

### M2 — Bài hôm nay + chuỗi ngày
- Thẻ "Bài hôm nay" ở đầu Sảnh (trên "Tiếp tục"): 3 bài/ngày chọn theo hạt giống ngày + trình độ (từ kết quả 7 ngày gần nhất), 5–8 phút.
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

---

## Sau 0.47 (không làm trong đợt này)
Bản thử cho người lạ 0.48: privacy manifest, `ITSAppUsesNonExemptEncryption`, entitlements, ẩn online, rà toàn bộ i18n, vật lý "Theo tài liệu" — cần tài khoản Apple Developer để lên TestFlight.

## Mặc định khi không ai trả lời
- Tên 4 họ bàn và phối màu: theo trên. Thanh lực: bật cho người mới (chưa đánh ≥ 50 cú), người cũ giữ vuốt.
- Nếu M1 của 0.45 không đạt tiêu chí 120 Hz trên Simulator/Mac: vẫn giao, giữ 60 Hz mặc định, ghi rõ.
- Nếu tách `TrainingController` làm vỡ test mà không sửa được trong 1 giờ: hoàn lại bước đó, giao phần đã tách sạch.
