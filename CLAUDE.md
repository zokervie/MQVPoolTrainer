# ZokerPoolTrainer — bản native (sản phẩm chính từ 26/10/2026)

App bida luyện mắt, tư duy và dự đoán đường bi trên iPhone/iPad. UIKit + SceneKit + lõi vật lý C++17 (`native/ZokerPoolTrainer/BankLab/Core`).
Nguồn gốc: repo private `ZokerPoolTrainer-0.11-Native-Jump-Masse…` tại `efabf7e` (bàn giao ChatGPT, `Handoff/`). Bản Swift `feature/zoker-mvp` dừng phát triển, chỉ dùng làm chuẩn đối chiếu vật lý.

## BẮT ĐẦU MỖI PHIÊN (anh dặn 13/11/2026) — đọc đúng 2 thứ, không đọc lan man
1. `native/ZokerPoolTrainer/Docs/TRANG-THAI.md`: bản nào đang ở đâu, việc nào ĐÃ ĐẠT (không làm lại), việc kế tiếp, phát kiến đã duyệt.
2. Tin nhắn mới nhất của anh: yêu cầu mới nhất thắng mọi kế hoạch cũ. Có mâu thuẫn thì hỏi 1 câu.

Chỉ mở `Docs/LICH-SU-QUYET-DINH.md` hoặc các file NGHIEM-THU cũ khi cần tra lý do.

## Tiết kiệm token, làm đúng trọng tâm
- Đọc file theo đoạn (grep → đọc vài chục dòng), không đọc cả file Swift 2.000 dòng. Không in log dài; log CI chỉ lọc `error:|FAIL|REPORT`.
- Mục đã đạt (ghi ✅ trong TRANG-THAI) không sửa lại, trừ khi anh báo lỗi mới về chính mục đó.
- Mỗi việc: nguyên nhân gốc → sửa → test giữ cửa → cập nhật TRANG-THAI. Không viết lại thứ đang chạy tốt chỉ để "đẹp hơn".
- Gom nhiều sửa đổi vào một lần build; chờ CI bằng tác vụ nền, không hỏi thăm liên tục.
- Báo cáo ngắn: làm gì, kết quả, chưa xác minh gì, anh cần quyết gì.
- Cuộc trò chuyện dài thì đề nghị anh mở cuộc mới trong Project (đã tóm tắt dễ sót chi tiết).
- Cuối mỗi phiên: cập nhật `Docs/TRANG-THAI.md` (+ bản trong Project `claude/zoker-trang-thai.md`).

## Nhắc anh (anh dặn: "nhắc khi anh quên")
- Mỗi lần trả lời việc lớn: liệt kê ngắn các mục ĐANG CHỜ ANH trong TRANG-THAI (thiết bị thử, video 240 fps, âm thanh, tài khoản Developer, Game Center, Xcode/Mac).
- Phát kiến tốt đã duyệt mà chưa làm thì nhắc khi tới bản phù hợp; không tự làm khi anh đang bảo "đợi anh chốt".
- Mỗi nhiệm vụ mới: nêu skill sẽ dùng, rủi ro chính, công nghệ đề xuất (bảng trong TRANG-THAI §5).

## Quy tắc
- Vật lý: viết test trước (C++, `Tests/*.cpp`, đăng ký trong `CMakeLists.txt`); mọi hệ số có nguồn: đã công bố / đã đo / giả định.
- Không dùng engine vật lý có sẵn. Không có trợ giúp ngắm khi đánh ở chế độ chính; đường lý tưởng/dự đoán chỉ ở chế độ phân tích.
- Một nhiệm vụ = một nhánh `ci/native-<mã>`; CI xanh mới gộp vào `feature/zoker-native`. Mỗi lần gộp có IPA mới (link cố định `dist-zoker-native`). Nhánh `cho/…` = nhánh chờ, không chạy CI.
- Chỉ đánh dấu xong khi CI macOS chạy thật; phần cần thiết bị ghi "chưa xác minh trên thiết bị". "Hết lỗi" chỉ khi anh xác nhận trên máy thật.
- (Anh dặn 09/11/2026) Hạng mục nào sửa đi sửa lại nhiều lần thì chủ động đề xuất đưa thành tuỳ chỉnh trong Menu → Tuỳ chỉnh.
- (Anh dặn 09/11/2026) Anh không phải chuyên gia: luôn đứng ở góc độ chuyên gia (bida + phần mềm), chủ động góp ý, phản biện và đưa phương án tốt hơn — nói rõ vì sao tốt hơn, anh quyết.
- Không dùng tên/logo thương hiệu thật (dùng tên Z-…); âm thanh chỉ CC0/CC-BY/Sonniss/anh tự thu, không lấy YouTube; không gửi key trong chat.

## CI
`.github/workflows/native-ci.yml`: cổng Linux (g++/clang++, check_suite_lists, Run-All-Checks) → `Tools/run_acceptance.py` trên macOS (Simulator, ảnh + đầu dò G1, XCTest cử chỉ, IPA) → Release `native-*` + nhánh `dist-zoker-native`; ảnh ở `shots/native`. Thêm bộ test C++ mới: đăng ký ở cả `CMakeLists.txt` (ZOKER_TEST_SUITES) và `Run-All-Checks.command`. Đọc thêm `AGENTS.md` (hợp đồng của nhánh council).

## Quy ước "chấp thuận" (anh dặn 09/11/2026 22:54)
Khi anh nói "chấp thuận" = duyệt TOÀN BỘ đề xuất/phát kiến/sửa đổi em vừa nêu, làm luôn. Nếu cần thêm/bớt, anh nói sau chữ "chấp thuận". "Đợi anh chốt" / "khoan build" = không build, chỉ chuẩn bị trên nhánh chờ.

## Cách làm việc (anh dặn 09/11/2026 22:23)
Anh muốn ÍT đợt nghiệm thu: gom thành một bản hoàn chỉnh rồi mới nghiệm thu; sau đó tách tính năng để bán trong app (In-App Purchase). Viết tính năng theo cờ/khối độc lập để sau này khoá/mở theo gói được.
