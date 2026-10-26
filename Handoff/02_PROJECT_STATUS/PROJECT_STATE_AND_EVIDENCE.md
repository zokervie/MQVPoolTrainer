# DỰ ÁN ZOKER POOL TRAINER — BẢN ĐỒ HIỆN TRẠNG VÀ CHỨNG CỨ

**Mốc audit:** 24/10/2026; `main=aba66d0f21e0816973ef0c13281fa98855ca3ff6`.

## 1. Repo và tính toàn vẹn

Repository **private**: `zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858`. Kiểm tra GitHub thấy 113 tracked blobs / 147 tree entries / 588.522 bytes tracked. Repo khác như MQVPoolTrainer, MQVPoolTrainer-I, Zoker-Pool-Trainer là các nguồn cũ hoặc đối chứng và **không được chọn tự động làm nguồn chính**. Trước khi code, Agent `git fetch` kiểm tra HEAD mới nhất và so với mốc khóa, đồng thời `git status`, `git log`, `git diff`.

## 2. Những gì đã được ghi nhận đã có trong source / build

- UIKit + SceneKit native iOS, Objective-C++ bridge BLWorld + solver physics C++17 hệ SI, mô phỏng vận tốc tịnh tiến và vận tốc góc, ma sát nỉ, va bi, va băng, pocket capture, mô phỏng dự báo và replay; source nằm dưới `native/ZokerPoolTrainer/BankLab`.
- TableScene dựng hình 3D bàn/bi/cơ, vật liệu nỉ/walnut/rail với công cụ tái tạo asset, bóng đổ, vân nỉ, spot bi và một thư viện mẫu bàn/cơ được mô tả là **tham khảo đồ họa**, không được xác nhận nhà sản xuất.
- Jump/massé 3D thử nghiệm có vị trí/độ cao bi, va chạm mặt bàn, ảnh hưởng xoáy; bộ giải gốc 2D còn có thể sử dụng. Cơ có các nhóm Playing/Jump/Break; ba loại cấu hình vật lý minh họa, không phải hiệu chuẩn đúng hiệu năng từng thương hiệu.
- Quick rail phải với camera/cơ/bao cơ/**bài tập**; effect ở trái cạnh B; Undo bên trái phía trên B; camera có orbit 2 ngón và pinch cả khi bi lăn; **chưa** auto-return đúng yêu cầu mới.
- Bài tập native: hồ sơ build 21 mô tả 46 layout trong các nhóm kick/bank/kiểm soát/đo; Models.swift có lesson, sơ đồ tự vẽ và link một số video, không coi là đã chép số liệu các video.
- `PoolAudio` phát âm PCM tự tổng hợp theo event, 4 loại (cue-ball, ball-ball, cushion, pocket), phân theo impact/pan; chưa có bộ sample ghi âm được cấp phép chuyên nghiệp.
- `addBall()` thêm một bi vào lưới đặt cố định, chưa có random N theo seed và tùy chọn số lượng.
- Run-All-Checks.command chạy resource, Research/ZUPE JS và các test C++ (Physics, Prediction, Practice, Contact, Elevated, KickSearch, Calibration, Cushion3D, SpinTransfer...). Xcode/CI via Codemagic + GitHub Actions.
- `RELEASE-BUILD22.md` ghi nhận Codemagic #24: simulator + unsigned iPhone Release **biên dịch thành công**, ảnh QA qua visibility gates. SHA-256 unsigned IPA `eb8dc207b5b94aecb325bc86701b61f80517ec5b902e989cd89eddbc3b109d70` (kiểm tra lại artifact trước khi phát).

## 3. Chưa hoàn thành hoặc chưa đủ chứng cứ

- Yêu cầu mới đưa effect sang **phải** thanh nâng cơ, Undo/view cùng cụm phải, bỏ bài tập khỏi quick bar, cam Aim3D mặc định + trở về Aim3D tự động sau bóng dừng.
- Cơ sát băng có xử lý clearance hình học chính xác, cảnh báo bất khả thi, giới hạn effect phụ thuộc khoảng cách rail/độ nâng.
- Âm va bi/cơ/băng/lỗ từ mẫu âm tự thu hoặc giấy phép rõ ràng, mixing/realtime theo lực/góc và đa thiết bị.
- Nút thêm N bi mục tiêu ngẫu nhiên hợp lệ, có seed/tạo lại, không vi phạm hình học/lỗ/bóng.
- Giáo trình video in-place, metadata bản quyền/timestamp, chuẩn hóa source/bài/sơ đồ và chấm điểm chính xác theo từng bài.
- Multiplayer online hai máy khác mạng bằng mã phòng, điều đình rule, turn authority, scoreboard realtime, reconnect.
- Real-device test cảm ứng đa chạm, 60fps bền, rung/độ trễ, nhiệt/battery, các loại iPhone/iPad.
- Hiệu chuẩn vật lý với video có thước, nhiều lực/xoáy/góc trên bàn thật; mô phỏng số không chứng minh độ chính xác khi thi đấu.
- Signed IPA và phân phối App Store/TestFlight; **không suy diễn từ unsigned build**.

## 4. Các khác biệt tài liệu cũ và yêu cầu mới (đã được ưu tiên hóa)

| Cũ | Mới do người dùng chốt 24/10 | Agent phải làm |
|---|---|---|
| Effect cạnh B dưới trái | Effect **bên phải** thanh nâng cơ | Sửa layout source, camera/hit target; sửa docs cũ |
| Retry ở trái trên B | Undo/Lùi cú sang phải | Không đổi chức năng khôi phục snapshot |
| Lưu view người dùng sau shot | **Tự về Aim3D khi tất cả bi ngừng** | Tôn trọng Replay/Spectator online |
| Start ở góc top mặc định | Start ở Aim3D | Bảo toàn góc top có thể xoay |
| Bài tập trong quick rail + Menu | Bài tập trong Menu duy nhất | Thư viện và video ở màn riêng |
| `addBall` ở lưới | N bi ngẫu nhiên, có seed | Không trùng / không trong lỗ |
| Audio synth-only | Audio sample thật có license + fallback synth | Native events làm nguồn điều khiển |

## 5. Đường dẫn chứng cứ trong repo

- `native/ZokerPoolTrainer/BankLab/UI/TrainingController.swift` — HUD, quick rail, effect, Undo, camera/shot states, audio dispatch, addBall.
- `native/ZokerPoolTrainer/BankLab/UI/TouchControls.swift` — SpinPad, StrokePad, ElevationPad.
- `native/ZokerPoolTrainer/BankLab/Rendering/TableScene.swift` — camera, cue geometry, render/material.
- `native/ZokerPoolTrainer/BankLab/UI/Models.swift` — Drill/Lesson/preview.
- `native/ZokerPoolTrainer/BankLab/Core/Physics.cpp`, `ElevatedPhysics.cpp`, `BLWorld.mm` — simulation and event source.
- `native/ZokerPoolTrainer/Tests/` — regression suites.
- `native/ZokerPoolTrainer/Docs/RELEASE-BUILD22.md` — implemented and Codemagic run #24.
- `native/ZokerPoolTrainer/Docs/NEXT-ACCEPTANCE-2026-10-24.md` — older acceptance; partly superseded by new master spec.
- `.github/workflows/xcode-build.yml`, `codemagic.yaml`, `native/ZokerPoolTrainer/codemagic.yaml` — build workflow configuration.

## 6. Hành động đầu tiên Agent phải báo

`repo URL; current main SHA; checked-out feature branch; source manifest counts; baseline test PASS/FAIL; optional GitHub Actions billing status; Codemagic status; exact G1 edit plan; whether Mac/iPhone device is actually connected.`

Cấm chuyển trạng thái thành 'done' chỉ từ markdown. Không tự cài đặt IPA lên thiết bị, không công khai repo, không upload source private ra trang thứ ba không được cấp quyền, không đưa signing secrets vào hồ sơ.
