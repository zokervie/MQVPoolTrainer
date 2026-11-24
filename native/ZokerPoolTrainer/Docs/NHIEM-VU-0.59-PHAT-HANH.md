# Nhiệm vụ 0.59 (phần 2) — Điều kiện nộp App Store / TestFlight (phiên Mac)

Chủ dự án duyệt 25/11/2026 ("Chấp thuận"). Nguồn: review Shadow/ChatGPT 25/11, đã kiểm lại tại daceda5 (VERIFIED trong code).
Danh sách tổng: Project `claude/zoker-so-y-tuong-backlog.md` mục H. Làm cùng nhánh 0.59, mỗi mục một commit.
Chưa có tài khoản Apple Developer: mọi thứ cần chữ ký/entitlement chỉ CHUẨN BỊ, không bật.

## R1. PrivacyInfo.xcprivacy (VERIFIED: chưa có file)
Thêm `BankLab/PrivacyInfo.xcprivacy` vào target app (Copy Bundle Resources):
- `NSPrivacyTracking` = false; `NSPrivacyTrackingDomains` = []; `NSPrivacyCollectedDataTypes` = [] (nhà phát triển không thu thập; relay chỉ giữ token ngẫu nhiên của trận).
- `NSPrivacyAccessedAPITypes` theo kiểm kê code (daceda5/7db83ea):
  | Loại API | Chỗ dùng | Lý do |
  |---|---|---|
  | `NSPrivacyAccessedAPICategoryUserDefaults` | 35 file (cài đặt, tiến độ) | `CA92.1` |
  | `NSPrivacyAccessedAPICategoryFileTimestamp` | `ShotArchive.swift` 163/179/221 (ngày sửa file trong thư mục app để dọn bản lưu cũ) | `C617.1` |
  | `NSPrivacyAccessedAPICategorySystemBootTime` | `ProcessInfo.systemUptime` (LocalMatchSession, đo khoảng thời gian trong app) | `35F9.1` |
  Kiểm lại mã lý do trên trang Apple "Describing use of required reason API" trước khi commit (em chưa đối chiếu bản trang mới nhất).
- Không có: disk space, active keyboards → không khai.
- Chốt giữ cửa: `Tools/check_privacy_manifest.py` (chạy trong Run-All-Checks): quét `BankLab` tìm các API cần khai lý do (UserDefaults, creationDate/modificationDate/attributesOfItem/contentModificationDate, systemUptime/mach_absolute_time, volumeAvailableCapacity/systemFreeSize/statfs, activeInputModes); loại nào xuất hiện mà manifest chưa khai → FAIL. Kiểm trong IPA có `PrivacyInfo.xcprivacy`.

## R2. Info.plist
- `ITSAppUsesNonExemptEncryption` = `NO` (app chỉ dùng TLS chuẩn của iOS qua URLSession cho relay). Đây là khai báo xuất khẩu: chủ dự án xác nhận khi điền App Store Connect.
- Giữ 3 chuỗi quyền hiện có (Ảnh chỉ-thêm, Mạng nội bộ, Bạn bè Game Center). Kiểm bản tiếng Anh trong i18n.

## R3. Chính sách quyền riêng tư + hỗ trợ trong app
- Trang đã đăng (25/11, Vercel project `zoker-pool`, nguồn `Docs/web/`): chính sách https://zoker-pool.vercel.app/privacy · hỗ trợ https://zoker-pool.vercel.app/ · email hỗ trợ zokervie@gmail.com (chủ dự án chọn).
- Cài đặt → mục "Pháp lý · giấy phép": thêm hai dòng "Chính sách quyền riêng tư" và "Hỗ trợ" mở URL (`SFSafariViewController`). URL đặt trong một hằng số `LegalLinks` (một chỗ) = hai URL trên.
- Màn Pháp lý: thêm ghi công font "Petemoss — © 2008-2021 The Petemoss Project Authors, SIL Open Font License 1.1" (đúng dòng bản quyền trong OFL.txt) (OFL.txt đã đóng gói). Giữ dòng âm thanh jtroan CC BY 3.0 + các mẫu CC0.

## R4. Tính năng mạng trước người duyệt
- **Online · Game Center** (VERIFIED: không có file entitlements, không có `CODE_SIGN_ENTITLEMENTS`): đưa sau cờ `FeatureFlags.gameCenter`, mặc định TẮT cho tới khi có tài khoản + entitlement + thử 2 máy. Không hiện nút ở sảnh khi tắt.
- **Online bằng mã phòng (relay)**: hiện bắt người dùng DÁN địa chỉ máy chủ (`OnlineRelayConfig`). Người duyệt sẽ không có địa chỉ → tính năng như hỏng. Đưa sau cờ `FeatureFlags.onlineRelay`: chỉ BẬT khi build có địa chỉ relay mặc định (đặt qua build setting, không hard-code trong mã); không có thì ẩn. Ô dán địa chỉ chỉ còn trong Cài đặt → Nâng cao.
- Từ chối Game Center vẫn vào tập được ngay (test UI: cài mới → huỷ Game Center → đánh được cú đầu).

## R5. Bảng tài nguyên phát hành
- `Tools/release_assets.py`: liệt kê mọi file media/font trong `.app` của IPA, đối chiếu với `Docs/TAI-NGUYEN-PHAT-HANH.md` (file → nguồn → giấy phép → dòng ghi công trong app). File không có dòng → FAIL. Chạy sau bước IPA.
- Nguồn đã biết: âm thanh `Tools/AudioSources/ATTRIBUTION.md` (4 CC0 + 1 CC BY 3.0); vân gỗ/nỉ/lưới bàn tự sinh (`Tools/generate_materials.py`, `generate_table_mesh.py`); font Petemoss OFL; logo/biểu tượng Zoker (chủ dự án).
- 24 ảnh tường `ZWall01–24`: chủ dự án xác nhận 25/11 là ảnh của chính anh được làm lại bằng AI (ChatGPT); người khác trong ảnh là nhân vật AI; biển hiệu là thương hiệu Zoker hư cấu. Ghi nguồn: "ảnh chủ dự án, chỉnh bằng AI". Giữ.

## R6. Số phiên bản
- Hiện `MARKETING_VERSION = 0.48`, `CURRENT_PROJECT_VERSION = 29` (pbxproj). Bản TestFlight đầu: `MARKETING_VERSION = 1.0`, build tăng dần mỗi lần tải (lấy từ số run CI). Đồng bộ target UITests không cần.

## R7. Quy trình ký và tải lên (CHUẨN BỊ, CHƯA CHẠY)
- Workflow mới `.github/workflows/testflight.yml`, chỉ `workflow_dispatch` (chạy tay): `xcodebuild archive` → `-exportArchive` (method app-store-connect) → tải lên bằng khoá App Store Connect API trong GitHub Secrets (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`); không in giá trị bí mật.
- Đây là thay đổi CI: tạo file, KHÔNG sửa `native-ci.yml`; bật chạy cần chủ dự án duyệt riêng khi có tài khoản.

## Test giữ cửa
check_privacy_manifest.py PASS; IPA có PrivacyInfo.xcprivacy + Petemoss + OFL; release_assets.py PASS (trừ mục chờ anh xác nhận, ghi rõ); test UI: không có nút Game Center khi cờ tắt; từ chối Game Center vẫn đánh được.

## Báo cáo
Ảnh màn Cài đặt/Pháp lý, nội dung manifest, kết quả hai script, danh sách tài nguyên chưa có nguồn.
