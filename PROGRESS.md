# Tiến độ — ZokerPoolTrainer native

Trạng thái ghi theo bằng chứng: CODE_READY (có code) · TESTED_PORTABLE (test C++/JS trên Linux) · TESTED_SIM (CI macOS: build, Simulator, ảnh chụp) · TESTED_DEVICE (người dùng xác nhận trên máy). Không ghi "xong" khi thiếu bằng chứng.

## Mốc hiện tại: G1 nghiệm thu + vật lý 0.14

| Mục | Trạng thái | Bằng chứng |
|---|---|---|
| G0 nhập source `efabf7e` vào repo public, CI macOS miễn phí | TESTED_SIM (build) | 158/158 file khớp SHA-256 manifest; run native-ci đầu tiên: C++ Linux xanh, Swift/C bridge + Simulator + IPA build qua |
| G1 HUD/camera (ChatGPT) — 5 đầu dò UIKit + ảnh | đang chạy CI | `Tools/ci_screenshots.sh` |
| P-1 Throw: ma sát bi–bi theo tốc độ (TP A.14) | TESTED_PORTABLE | `Tests/LiteratureTests.cpp`: max 5,2–5,3° ở ~33° (trước 2,0°) |
| P-2 Squirt (TP A.31) | TESTED_PORTABLE | 2,28° ở 0,5R, ngược phía effect; cả cú phẳng và cú nâng cơ |
| P-3 Tốc độ bi theo điểm chạm (TP A.30) | TESTED_PORTABLE | xoáy dưới 0,5R: năng lượng 0,75× đánh tâm (trước 1,62×) |
| P-4 A1: pháp tuyến va chạm bi–bi đúng lúc chạm | TESTED_PORTABLE | hướng bi mục tiêu cú nhanh khớp chế độ phẳng (trước lệch tới ~1°) |
| Cảm giác lực/âm thanh/hình sau các sửa trên | chưa xác minh trên thiết bị | — |

## Hợp nhất 26/10 tối (nhánh `ci/native-hop-nhat`)
Lấy nền `feature/0.13-council-hardening` @ e86ee7f (repo private, PR #2: XCTest cử chỉ kéo một ngón, đầu dò G1, DeterminismTests 100 lần, cổng Linux GCC+Clang, `check_suite_lists.py`, `run_acceptance.py`, tài liệu hội đồng + AI Coach) và thêm từ nhánh này: vật lý 0.14 (P-1…P-4) + `LiteratureTests.cpp`, `check_gestures.py`, di trú cài đặt μ₀, số build tăng dần, CI phát hành IPA. 15/15 bộ C++ qua với g++ và clang++ (-Werror) trên Linux.

## Hàng chờ (theo thứ tự đề xuất)
1. G2 (ChatGPT blueprint): cơ tránh băng + vùng effect khả thi; xếp bi ngẫu nhiên theo seed.
2. Chế độ Luyện (có trợ giúp, phân tích sau cú) / Chế độ Thi (không trợ giúp) — đường lý tưởng và dự đoán chỉ ở chế độ Luyện hoặc sau cú.
3. Golden shots trên bàn của người dùng: quay video điện thoại 60–240 fps + bàn cờ hiệu chỉnh, 5 tốc độ × 5 điểm chạm, tách tập fit/kiểm; hồ sơ bàn riêng (appearanceID tách physicsProfileID).
4. Âm thanh: preload PCM + voice pool; A/B với bản thu bàn thật (có giấy phép).
5. Kiểm 46 bài tập: góc mẫu bằng tìm ngược trên solver, chỉ công bố bài có quỹ đạo mẫu đạt.
6. Đa ngôn ngữ (7 thứ tiếng), thư viện cú đẹp, tuỳ chọn ẩn bảng đo — yêu cầu 20/10 của người dùng, chuyển từ bản Swift.
7. Online (G5–G7) sau khi bản offline được nghiệm thu.

## Hội đồng AI (26/10, phiên b25bbd31) — đã cân nhắc
Lấy: tách chế độ Luyện/Thi; kiểm chứng bằng video thật; A/B âm thanh với bản thu thật; MVP tách lõi (vật lý + HUD) khỏi phần nâng cao (haptic nâng cao, VR); tài liệu hiệu năng ≥ 60 fps.
Không lấy (lý do):
- Bullet Physics / RK4 + Magnus: engine rigid-body chung sai ở tiếp xúc lăn–trượt của bi; Magnus không đáng kể ở tốc độ bida; dự án đã chốt lõi riêng giải dạng đóng/bước cố định có test.
- "Sai số < 0,5–1 cm, tự hiệu chuẩn từ 5 cú": nhỏ hơn sai số đo video điện thoại và độ lặp lại của chính bàn thật; 5 cú không đủ để tách các hệ số. Mục tiêu đặt theo độ không chắc chắn đo được.
- Tối ưu GA/PSO "cho tới khi đạt": dễ ép số liệu (overfit); chỉ fit tham số có giới hạn trên tập huấn luyện, kiểm trên tập riêng.
- Ngân sách USD 30–250k, hợp đồng WPA, 20 cơ thủ: không phù hợp quy mô hiện tại; thay bằng bàn của người dùng + 3 người chơi khá thử bản beta.
- Ghost ball khi đánh: trái nguyên tắc ngắm bằng mắt; chỉ dùng trong phân tích sau cú.

## Nhật ký
- 03/11/2026 (tối) · Nhánh `ci/native-0.21-vat-ly` — TESTED_PORTABLE (g++/clang++, 22 bộ C++), chờ CI Mac biên dịch Swift; chưa xác minh trên thiết bị:
  - **Băng grip-slip (β):** clip *Reverse bank zigzag* (c-ZBSi9KBfc) được nắn phối cảnh về toạ độ nút (sai số ≤ 0,1 nút) và dò bi 8 qua 4 băng: 3,44 → 2,40 → 2,86 → 3,45 → lỗ giữa. Sau băng 2 bi **đổi chiều dọc bàn**; mô hình băng cứng 0.20 không làm được ở bất kỳ tốc độ/xoáy/ma sát nào. Thêm hệ số hồi phục tiếp tuyến β (Cross, Am. J. Phys. 70, 1093, 2002) vào `CushionContact3D.hpp` (mặc định lõi 0 = kết quả cũ y hệt). Hồ sơ app: β 0,30, giảm xoáy ngang 11 rad/s² (fit 1 clip) → 3,44 / 2,54 / 2,82 / 3,51, lệch ≤ 0,22 nút. `Tests/ReverseZigzagTests.cpp`. Còn mở: cuối cú bi trong clip chậm hơn mô hình 0,48 s.
  - **Squirt theo độ nâng cơ (quyết định chủ dự án):** mọi gậy ra bi đúng hướng ngắm khi cơ ngang; squirt tăng dần theo độ nâng, đủ ở 15° (thiết kế). Thay chính sách theo kiểu cú của 0.20.
  - **Lực:** bỏ kẹp 6 m/s của cú phẳng (mức 28–30 trước đây như nhau). Đánh mức 30 = 8,0 m/s; gậy phá ×1,4 + đầu cứng = 11,9 m/s (cú phá chuyên nghiệp ~11–13 m/s).
  - **Đầu tẩy:** trung tính = vật lý cũ; mềm (Massé) chạm xa tâm hơn 0,08R → tỉ lệ effect ωR/v tối đa 1,75 → 1,95; cứng (Jump/Phá) +6% năng lượng. Mềm KHÔNG tăng xoáy ở cùng điểm chạm (vật lý thật). Giả định, chỉnh được trong *Hiệu chỉnh bàn*.
  - **Massé:** mức 30, 70°/80°: 2,35 / 1,70 m/s, ~340 rad/s, đường cong 45° / 32° trong 1 s (clip D_lf-6KgFTo: ~2 m/s). Hình dạng đường cong so với clip: còn mở. Gậy Jump nằm ngang không nhảy; nâng 45° nhảy 180 mm.
  - **Chỉnh tay:** thêm thanh trượt β, squirt theo độ nâng, hệ số gậy phá, đàn hồi massé; file MD xuất kèm nguồn từng hệ số. Cấu hình đã lưu được nâng cấp (bỏ giá trị cũ của các khoá mới).
- 03/11/2026 · Nhánh `ci/native-0.20-ngam-thang` (sau 0.19) — TESTED_PORTABLE (g++/clang++, 20 bộ C++), chờ CI Mac biên dịch Swift; chưa xác minh trên thiết bị:
  - **Ngắm thẳng (quyết định chủ dự án):** Đánh/Phá tắt squirt → bi đi đúng đường ngắm (lệch 0,0000° thay vì 2,28° ở 0,5R). Jump/Massé giữ squirt TP A.31. Lõi giữ mặc định bật (`Config::squirtEnabled`) để LiteratureTests và replay cũ không đổi; `UI/ShotKindPolicy.h`. Cơ Đánh nâng còn lệch nhỏ do mặt bàn (swerve, 0,23° ở 8°/0,4R) — vật lý thật, giữ.
  - **Massé mạnh hơn, có cơ sở:** kiểu Massé giải đồng thời cơ–bi–mặt bàn (`Core/CueSlateContact.hpp`, chép từ build 28 repo private c5c2db3). 80°/4:30/lực 15: tốc độ bật 0,13 → 0,35 m/s; nâng cơ cao → bi chậm hơn, xoáy mạnh hơn (đúng Dr. Dave); không tạo năng lượng; đối xứng. Hệ số phục hồi cơ 0,35 là GIẢ ĐỊNH, chưa khớp video.
  - **Effect ở băng / zigzag:** test mới xác nhận lõi hiện có: effect thuận mở góc (25,2° → 41,6°), effect ngược thu góc (19,2°) và làm bi chậm hơn (BD 7/2019); chiều xoáy giữ qua băng; cùng xoáy ở hai băng đối diện cho tác dụng ngược nhau (cơ chế zigzag). `Tests/AimMasseRailTests.cpp`.
- 31/10/2026 · Nhánh `ci/native-0.19-workflow` (sau c5505b3) — CODE_READY, chờ CI Mac biên dịch Swift; chưa xác minh trên thiết bị:
  - **Chơi Online miễn phí**: `Server/relay` (Cloudflare Worker + Durable Object, gói Free) chỉ ghép 2 máy theo mã 8 ký tự và chuyển tiếp byte; máy chủ phòng vẫn là nơi duy nhất chạy vật lý/luật (giữ nguyên kiến trúc Wi-Fi, không lệch trạng thái). `LocalMatchSession` thêm transport `.internet` (URLSessionWebSocketTask), ghế có token để nối lại, backoff 2–30 s. Khách: đồng hồ phát trễ thích ứng (`PlayoutClock`, 0,12–0,45 s) + nội suy Hermite theo vận tốc khi bi lăn thẳng (`SnapshotCurve`). TESTED_PORTABLE: 6 test luật relay (node), e2e 2 máy giả lập trên workerd cục bộ (ghép, chuyển tiếp 2 chiều, chặn máy thứ 3, nối lại, báo rời phòng); mô phỏng jitter: số khung đứng hình mỗi cú 2–8 → 0–0,2.
  - **Premium Classic render pass** (chỉ hình ảnh): ánh sáng câu lạc bộ, lớp vân nỉ không lặp, kim cương xà cừ, sơn bóng gỗ/cơ, cơ 64 cạnh; đầu dò camera Premium chờ camera ổn định. Ảnh Simulator CHƯA có.
- 28/10/2026 · Nhánh `ci/native-ux-luc-co-dinh` (0.16, CODE_READY → chờ CI Mac; chưa xác minh trên thiết bị): **Lực cố định** 1–30 (`PowerScale.h`, mỗi nấc ≈ 10% tốc độ bi, 0,5–8 m/s; `PowerScaleTests.cpp`) — đặt bằng − / + trên nút khoá, vuốt cơ chỉ kích hoạt nên cú lặp lại được; chế độ Cảm giác (cũ) chọn ở chữ Lực. HLV nói bằng nấc lực + effect theo vòng ("Lực 15 → 14"), kick không tìm được đường thì thử ±2 nấc. Nút B → ổ khoá + chữ GIỮ/ĐÁNH (hành vi giữ-để-khoá không đổi). Sơ đồ bài tập vẽ bàn nằm ngang lấp khung + mũi tên hướng ngắm; "Done" → "Xong", vùng ngôn ngữ vi. 18/18 bộ C++ qua (g++/clang++).
- 27/10/2026 · Nhánh `ci/native-hoan-thien` (0.15): âm thanh AVAudioEngine phát cả khi gạt im lặng + đầu dò; cơ tránh băng (CueClearance.h, test) — cơ không chui dưới bàn, vùng effect không với tới tô xám và tự kẹp lên; nhảy bi: lực vuốt = tốc độ bi (trước 0,66×), chỉ cơ Phá/Jump làm bi bật, cơ Đánh/Massé chỉ xoáy cong; bố cục: thanh dọc sát mép phải (Dụng cụ, Góc nhìn, Lùi, Xem lại), độ dốc hình cây cơ 0–90° bên phải bi effect; Dụng cụ thi đấu 4 mục (thêm bi từng bi/ngẫu nhiên theo seed); Xem lại + lưu cú + đánh lại cú đã lưu, một ngón xoay góc từ góc 3D ban đầu; bi rơi lỗ giữ đà + trọng lực thật; nút số kim cương 0–8/0–4, ghi chú vị trí khi vào bài, HLV offline sau cú (điểm va băng theo nút, hệ gương 1 băng, phản thực tế bằng World::simulate — test trùng cú thật). 17/17 bộ C++ qua. Chưa xác minh trên thiết bị.
- 27/10/2026 · Nhánh `ci/native-camera-dieu-khien` (B1, B2 — CODE_READY, chờ CI Mac; chưa xác minh trên thiết bị): một ngón kéo ngang = hướng đánh, kéo dọc = độ cao camera ngắm 0,02–1,25 rad, khoá trục mỗi lần kéo (không áp dụng gì trước 6 pt); mắt camera không chui vào băng/gỗ khi bi cái sát băng (tối thiểu 8,6 cm trên khung, 2 cm trên nỉ); sau cú giữ góc ngắm, toàn cảnh là tuỳ chọn trong Menu; XCTest kéo dọc không đổi hướng ngắm.
- 26/10/2026 tối · Hợp nhất council-hardening + vật lý 0.14; CI hợp nhất (cổng Linux 2 trình biên dịch → nghiệm thu Mac bằng run_acceptance.py → phát hành). Lần chạy Mac của bản chép council bị GitHub huỷ do hết máy macOS arm64 (không phải lỗi code); có tuỳ chọn chạy tay trên macos-15-intel.
- 26/10/2026 · Nhập source native vào `feature/zoker-native` (repo public MQVPoolTrainer), CI `native-ci.yml`. Nhánh `ci/native-vat-ly`: 4 sửa vật lý P-1…P-4 + `LiteratureTests.cpp`; 14/14 bộ C++ qua với -Werror.
