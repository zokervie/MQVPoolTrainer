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
- 26/10/2026 · Nhập source native vào `feature/zoker-native` (repo public MQVPoolTrainer), CI `native-ci.yml`. Nhánh `ci/native-vat-ly`: 4 sửa vật lý P-1…P-4 + `LiteratureTests.cpp`; 14/14 bộ C++ qua với -Werror.
