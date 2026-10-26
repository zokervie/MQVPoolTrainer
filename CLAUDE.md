# ZokerPoolTrainer — bản native (sản phẩm chính từ 26/10/2026)

App bida luyện mắt, tư duy và dự đoán đường bi trên iPhone/iPad. UIKit + SceneKit + lõi vật lý C++17 (`native/ZokerPoolTrainer/BankLab/Core`).
Nguồn gốc: repo private `ZokerPoolTrainer-0.11-Native-Jump-Masse…` tại `efabf7e` (bàn giao ChatGPT, `Handoff/`). Bản Swift `feature/zoker-mvp` dừng phát triển, chỉ dùng làm chuẩn đối chiếu vật lý.

## Quy tắc
- Vật lý: viết test trước (C++, `Tests/*.cpp`, đăng ký trong `CMakeLists.txt`); mọi hệ số có nguồn: đã công bố / đã đo / giả định.
- Không dùng engine vật lý có sẵn. Không có trợ giúp ngắm khi đánh ở chế độ chính; đường lý tưởng/dự đoán chỉ ở chế độ phân tích.
- Một nhiệm vụ = một nhánh `ci/native-<mã>`; CI xanh mới gộp vào `feature/zoker-native`. Mỗi lần gộp có IPA mới (link cố định `dist-zoker-native`).
- Chỉ đánh dấu xong khi CI macOS chạy thật; phần cần thiết bị ghi "chưa xác minh trên thiết bị".
- Báo cáo ngắn; không in toàn bộ log.

## CI
`.github/workflows/native-ci.yml`: cổng Linux (g++/clang++, check_suite_lists, Run-All-Checks) → `Tools/run_acceptance.py` trên macOS (Simulator, ảnh + đầu dò G1, XCTest cử chỉ, IPA) → Release `native-*` + nhánh `dist-zoker-native`; ảnh ở `shots/native`. Thêm bộ test C++ mới: đăng ký ở cả `CMakeLists.txt` (ZOKER_TEST_SUITES) và `Run-All-Checks.command`. Đọc thêm `AGENTS.md` (hợp đồng của nhánh council).
