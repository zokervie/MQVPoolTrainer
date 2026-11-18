# Kiến trúc và quy trình — ZokerPoolTrainer (chuẩn từ 18/11/2026)

## 1. Kiến trúc app: 5 tầng, phụ thuộc một chiều (trên dùng dưới, dưới không biết trên)

| Tầng | Ở đâu | Chứa | Quy tắc |
|---|---|---|---|
| 1 Lõi | `BankLab/Core/*.hpp/.cpp`, `BankLab/UI/*.h` (C thuần) | Vật lý, luật, máy đối thủ, Bài hôm nay, chương, thách bạn, lập kế hoạch máy quay | C++17/C, tất định, **test trước** trên Linux; không UIKit/SceneKit |
| 2 Cầu | `BLWorld.mm`, `BLMatch.mm`, `BLOpponent.mm`, bridging header | Gọi lõi từ Swift | Mỏng, không logic |
| 3 Miền | `PlayerStore`, `AppFlow`, `Prefs`, tiến độ, số liệu | Dữ liệu người chơi, máy trạng thái khởi động | Một nơi ghi; giao diện chỉ đọc |
| 4 Hiển thị | `UI/` theo màn (Hôm nay, Lộ trình, Đấu, Hồ sơ, Bàn/HUD), `ZDesign` | Màn hình, cử chỉ | Chỉ dùng thành phần ZDesign; mọi chuỗi qua L10n (vi + en) |
| 5 Dựng hình | `Rendering/` (`TableScene`, `ShotFX`, phòng, máy quay) | SceneKit | Ghi cây node chỉ ở một chỗ mỗi khung; ngân sách khung đo được |

Ngưỡng: file ≤ 900 dòng; không `asyncAfter` để nối bước (dùng AppFlow); cờ QA trong `#if DEBUG`; không thư viện ngoài nếu chưa duyệt.

## 2. Quy trình một bản (DISCOVER → … → RELEASE)

| Bước | Ai (model) | Ra gì | Cổng qua |
|---|---|---|---|
| Ý tưởng, nghiên cứu, nhiệm vụ | Phiên đám mây (Opus; Fable cho quyết định lớn) | `docs/de-xuat/NHIEM-VU-*.md` có tiêu chí đo được | Chủ dự án "chấp thuận" |
| Thiết kế hình (khi có màn mới) | Phiên đám mây | Canvas Design | Chủ dự án duyệt mắt |
| Lõi C++ | Phiên đám mây hoặc vai `ky-su-loi` (Opus/high) | `Tests/*.cpp` PASS g++ + clang++ | Cổng Linux |
| Swift, giao diện | Phiên Mac (Sonnet) + vai `ky-su-giao-dien` | Mã + XCTest | `accept_local.sh` PASS trên Mac (Simulator phải chạy) |
| Review | Vai `giam-khao` (Opus) cuối bản + phiên đám mây | `REVIEW-*.md` | Không còn LỖI CHẶN |
| Dựng IPA | CI Xcode 26 (`ci/native-*`) | IPA + ảnh | 8/8 bước PASS |
| Nghiệm thu thiết bị | Chủ dự án | Kết quả theo danh sách thử | "Đạt" từng mục |
| Gộp, phát hành | Phiên đám mây khi được duyệt riêng | `feature/zoker-native` | Duyệt riêng |

## 3. Tiết kiệm hạn mức
- Không hẹn giờ tự kiểm tra; chủ dự án nhắn thì phiên đám mây mới đọc CI.
- Mỗi bản mở **một phiên đám mây mới**, đọc `claude/zoker-trang-thai.md` + file nhiệm vụ; không kéo cuộc chat dài.
- Phiên Mac: Sonnet + `/effort medium`; `/goal` ≤ 60 lượt mỗi bản; Opus chỉ ở vai lõi và giám khảo.
- Fable: chỉ cho định hướng lớn hoặc review trước phát hành, chủ dự án bật bằng `/model`.

## 4. Định nghĩa "xong"
Chỉ nói "xong" khi: tiêu chí trong nhiệm vụ PASS có bằng chứng (log, ảnh, số đo) **và** CI xanh; phần cần thiết bị ghi "chưa xác minh trên thiết bị" tới khi chủ dự án xác nhận.
