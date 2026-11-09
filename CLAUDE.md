# ZokerPoolTrainer — bản native (sản phẩm chính từ 26/10/2026)

App bida luyện mắt, tư duy và dự đoán đường bi trên iPhone/iPad. UIKit + SceneKit + lõi vật lý C++17 (`native/ZokerPoolTrainer/BankLab/Core`).
Nguồn gốc: repo private `ZokerPoolTrainer-0.11-Native-Jump-Masse…` tại `efabf7e` (bàn giao ChatGPT, `Handoff/`). Bản Swift `feature/zoker-mvp` dừng phát triển, chỉ dùng làm chuẩn đối chiếu vật lý.

## Quy tắc
- Vật lý: viết test trước (C++, `Tests/*.cpp`, đăng ký trong `CMakeLists.txt`); mọi hệ số có nguồn: đã công bố / đã đo / giả định.
- Không dùng engine vật lý có sẵn. Không có trợ giúp ngắm khi đánh ở chế độ chính; đường lý tưởng/dự đoán chỉ ở chế độ phân tích.
- Một nhiệm vụ = một nhánh `ci/native-<mã>`; CI xanh mới gộp vào `feature/zoker-native`. Mỗi lần gộp có IPA mới (link cố định `dist-zoker-native`).
- Chỉ đánh dấu xong khi CI macOS chạy thật; phần cần thiết bị ghi "chưa xác minh trên thiết bị".
- Báo cáo ngắn; không in toàn bộ log.
- (Anh dặn 09/11/2026) Hạng mục nào sửa đi sửa lại nhiều lần (ánh sáng, bố cục phím, màu nỉ…) thì chủ động nhắc và đề xuất đưa thành tuỳ chỉnh trong Menu → Tuỳ chỉnh, theo hướng anh muốn; có đề xuất gì cứ nêu để anh tham khảo.
- (Anh dặn 09/11/2026) Anh không phải chuyên gia: luôn đứng ở góc độ chuyên gia (bida + phần mềm), chủ động góp ý, phản biện và đưa phương án tốt hơn dựa trên ý tưởng anh nêu — nói rõ vì sao tốt hơn, anh quyết.

## CI
`.github/workflows/native-ci.yml`: cổng Linux (g++/clang++, check_suite_lists, Run-All-Checks) → `Tools/run_acceptance.py` trên macOS (Simulator, ảnh + đầu dò G1, XCTest cử chỉ, IPA) → Release `native-*` + nhánh `dist-zoker-native`; ảnh ở `shots/native`. Thêm bộ test C++ mới: đăng ký ở cả `CMakeLists.txt` (ZOKER_TEST_SUITES) và `Run-All-Checks.command`. Đọc thêm `AGENTS.md` (hợp đồng của nhánh council).

## Quy ước "chấp thuận" (anh dặn 09/11/2026 22:54)
Khi anh nói "chấp thuận" = duyệt TOÀN BỘ đề xuất/phát kiến/sửa đổi em vừa nêu, làm luôn. Nếu cần thêm/bớt, anh nói sau chữ "chấp thuận".

## Cách làm việc (anh dặn 09/11/2026 22:23)
Anh muốn ÍT đợt nghiệm thu: gom thành một bản hoàn chỉnh rồi mới nghiệm thu; sau đó tách tính năng để bán trong app (In-App Purchase). Viết tính năng theo cờ/khối độc lập để sau này khoá/mở theo gói được.

## 0.38 = 0.37 + toàn bộ đề xuất còn lại (anh duyệt hết 09/11/2026 22:21)
Nút số tự hiện khi ngắm chạm băng; chấm độ đều tay; đường chỉ dẫn mờ theo trình độ; góc ngắm mặc định; kích thước/độ trong phím; lưu 3 bố cục; màu/độ dày đường ngắm; độ rõ vân nỉ; đường dự đoán theo độ dốc tự nâng; tự tăng lại chất lượng; xuất video highlight.

## 0.37 (anh duyệt 09/11/2026 21:34 — gộp tất cả)
Sửa: lag (chỉ bi đổ bóng, tự hạ chất lượng), sọc nỉ = phân tầng màu (dithering, nỉ không bóng, vân mờ sớm), sọc viền/yếm (bóng tự đổ), bo góc gỗ; bi bớt chói + bóng mềm; cơ không xuyên băng/bi, dốc tự nâng đồng bộ thanh dốc; kiểm tra va chạm khi bi bay; xem lại 1,5 s trước/sau + 3 cảnh điện ảnh; logo "Zoker Pool / Trainer"; khoá chỉ bằng B (công tắc bi effect khoá trong Tuỳ chỉnh, mặc định tắt).
Thêm: Tuỳ chỉnh độ chói bi + độ đậm bóng; mẫu loại bàn (nhanh/chuẩn/chậm); vạch vùng thực tế trên thanh vật lý; phím tự mờ khi ngắm; dự đoán rồi hiện đường đúng (lệch °); mẫu ánh sáng (Câu lạc bộ/TV/Dịu mắt); Sảnh chính (Luyện tập/Thi đấu/Hồ sơ) + menu trong trận 5 mục + Tuỳ chỉnh 4 thẻ + màu theo chế độ.
