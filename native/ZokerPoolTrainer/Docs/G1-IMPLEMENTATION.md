# G1 — HUD/camera candidate, chưa đóng gate

Branch: `feature/0.13-hud-camera`. Base: `aba66d0f21e0816973ef0c13281fa98855ca3ff6`.
Candidate metadata: 0.13 build 23; bundle `com.maiquocviet.BankLabS` giữ nguyên. Chưa có IPA build 23.

## Code đã triển khai

- Aim3D là mode mặc định trong TableScene và TrainingController; IDs 0/1/2 giữ nguyên. Aim zoom được lưu bằng key mới, không thay schema layout/history.
- Shot bắt đầu chuyển sang Overview3D; giữ camera thủ công trong lúc bi chạy. Sau engine đứng, pocket fall hoàn tất và 0,5 giây ổn định, tween 0,45 giây về Aim3D. Gesture camera đang hoạt động, replay, spectator, editing hoãn trả; input đánh bị chặn trong settle/return. Scratch dùng anchor trước shot cho camera; không tự hồi sinh bi.
- Effect phải elevation; B độc lập trái. View/Undo và một Tools flyout bên phải; Cue/Bag/Place/Add-one được bảo toàn trong flyout. Bài tập chỉ trong Menu. Random N chưa được thực hiện và nút hiện tại ghi đúng là thêm 1 bi.
- BLStrokeAllowed là guard chung để giữ B và shoot; expanded effect/menu/busy/spectator/scratch/editor không thể kích hoạt stroke. Các recognizer phân biệt tap, aim-pan một ngón và orbit/pinch hai ngón.
- Header-only PresentationPolicy.h chứa clock, smoothstep tween, authorization và HUD metrics; Swift nhập qua bridging header, C++ tests gọi đúng production policy. Không đưa UI state vào solver và không đổi hệ số vật lý.
- Giữ Undo snapshots/quaternions, renderer, 46 layout, equipment, procedural audio và persistence. Chỉ cập nhật tài liệu có yêu cầu cũ mâu thuẫn; RELEASE-BUILD22 là hồ sơ lịch sử được giữ nguyên.

## Bằng chứng đã có

32 tình huống portable policy pass: motion/rest/pocket/replay/spectator/edit/gesture, invalid dt, background gap, 30/60/120Hz, cancel/restart, 64 tổ hợp permission, HUD đóng/mở trên 4 safe-area sizes và tween deadline/midpoint. Run-All có 13 bộ C++ sau thêm PresentationPolicy, cùng 4 bộ JS/resource checks. Xem Evidence/G0-G1-2026-10-24.

Các tests này kiểm chứng policy dùng trong production, không chứng minh ClangImporter/Swift compile, SceneKit render hoặc UIKit dispatch. Header đã kiểm cú pháp C11; shell/YAML/plist đã kiểm cấu trúc.

## Gate còn mở

1. Xcode build Simulator/Release và Swift–C bridge typecheck.
2. Chạy Tools/ci_screenshots.sh: 5 probe default/hud/hud-expanded/return/spectator phải tạo JSON mới; thiếu file là fail. G1 probes đã viết, CHƯA CHẠY.
3. Inspect ảnh ở ít nhất iPhone 14 Pro Max + iPhone nhỏ; test chạm thật ≥30 tình huống, gesture trong camera transition, đổi top/orthographic ↔ perspective, scratch/Undo/replay và performance.
4. Chỉ sau đó review/merge và release G4. Không triển khai online G5 trước nghiệm thu offline.

Không đánh dấu G1 hoàn thành bằng 32 policy cases. Đặc biệt projection top↔perspective và hủy tween bằng gesture cần xác nhận trực quan trên Simulator/device.
