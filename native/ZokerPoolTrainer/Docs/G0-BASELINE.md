# G0 baseline — 24/10/2026 (Việt Nam)

Repository: `zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858` (private).

- Main/base SHA xác minh trực tiếp: `aba66d0f21e0816973ef0c13281fa98855ca3ff6`.
- Tree SHA: `d0fad303831a8c4a257a31e38d688093d2d21b1e`.
- 113 tracked files, 147 tree entries, 588.522 tracked bytes. Không có AGENTS.md trong tree này.
- Lấy toàn bộ bytes bằng GitHub connector có xác thực; kiểm SHA-1 Git blob + kích thước từng file, dựng lại tree và commit chính xác. Git CLI không có credential; snapshot local là shallow, không có toàn bộ lịch sử Git. Không thay thế bằng repo khác.
- Bootstrap gốc không bị sửa, đã clone snapshot local đã xác minh rồi tạo `ZokerPoolTrainer_FULL_SOURCE_AND_HANDOFF_aba66d0f21e0.zip`; ZIP chứa đủ 113 file dưới ProjectSource và toàn bộ Handoff. SOURCE_MANIFEST ghi đường dẫn mirror local; SOURCE_PROVENANCE.json ghi repository private gốc và cách lấy.

## Kiểm thử baseline

Lần Run-All đầu tiên dừng tại missing `ClothAlbedo.dataset/map.png`: repo cố ý không track asset lớn. Sau `python3 Tools/prepare_ci_assets.py`, toàn bộ resource checks, 4 bộ JS và 12 bộ C++ đều pass với `-O2 -Wall -Wextra -Wpedantic -Werror`. Physics suite báo 2.304.486 assertions; Prediction 378 samples; Contact 761 checks. Đây là kiểm tra mô phỏng, không phải đo bàn thật.

Assets được tái tạo bằng numpy 2.3.5, scipy 1.17.0, Pillow 12.3.0, matplotlib 3.10.8. Generator ghi lại materials-manifest; checksum pass chứng minh output hiện tại tự nhất quán, không chứng minh đồng nhất với asset của IPA build 22. Generated assets/manifest không nằm trong patch G1.

## Trạng thái build thực tế

5 GitHub Actions gần nhất trên main đều completed/failure. Run mới nhất 40083592188, job 120841915560, không có step hoặc runner được ghi nhận. Endpoint job log trả 404; annotations chưa đọc được bằng connector. Chưa xác định nguyên nhân, không kết luận billing hay lỗi compiler. Build 22 Codemagic #24 chỉ được xác nhận qua hồ sơ lịch sử, chưa truy vấn trạng thái Codemagic trực tiếp trong phiên này.

Môi trường thực thi: Linux x86_64, Python/Node/GCC; không có swift, clang++, xcodebuild hoặc máy iPhone kết nối. `Verify-on-Mac.command` đã thử và dừng exit 127: `xcodebuild: command not found`. G0 đã audit source/portable regression, gate native/Mac còn mở.

## Hiện trạng chức năng

Native UIKit/SceneKit + BLWorld Objective-C++ + solver C++17, SI units, spin transfer, cushions/pockets, experimental jump/massé, prediction, quaternion Undo/replay, save layouts/history, procedural sound, 20 table looks/12 cues/3 bags và 46 layout được xác nhận từ source. Tham chiếu chi tiết ở FEATURE_MATRIX.csv.

Camera mặc định top, Undo/effect trái và quick-rail có Bài tập là cấu hình baseline đã bị Master Patch mới thay thế. Cơ tránh rail theo envelope, effect động theo rail, random N seed, real sample audio, D01–D10 integration và multiplayer đều chưa có đủ implementation/evidence.

Physics Core, TouchControls.swift, Models.swift và EquipmentLibrary.swift được giữ nguyên bytes trong G1 (11 file được đối chiếu).
