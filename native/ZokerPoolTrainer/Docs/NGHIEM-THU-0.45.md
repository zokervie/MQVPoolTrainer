# Nghiệm thu 0.45 "Xương sống" (17/11/2026)

Nhánh `cho/native-0.45` (từ `cho/native-0.44.1` @ `94f6f46`). 0.45 (26). Không push `ci/*`, không sửa `.github/workflows`,
không commit AppIcon. Đề bài: `plan/de-xuat-zoker:docs/de-xuat/NHIEM-VU-0.45-0.47.md`. Review đám mây `REVIEW-0.45-0.47.md`: đã đọc
đầu bản, sửa mục VỪA (zh-Hant) và NHẸ (toast 60 Hz một ngôn ngữ).

**Chặn chung:** Simulator trên Mac này không khởi động được từ 20:45 (CoreSimulatorService treo khi boot) ⇒ mọi kiểm tra cần Simulator
(UI test, ảnh, perf QA) là **NOT RUN**.

| Mốc | Kết quả | Bằng chứng |
|---|---|---|
| M0 Điều phối theo vai | **PASS** | `.claude/agents/ky-su-loi.md` (opus/high); 3 vai cũ thêm "dùng chủ động", effort (giao diện medium, kiểm kê low); bảng giao việc trong `native/ZokerPoolTrainer/CLAUDE.md`. Đã dùng thật: M2 do vai kỹ sư lõi (opus), i18n do vai giao diện (sonnet), review do vai giám khảo (opus). Lưu ý: vai chỉ nạp khi phiên mở tại gốc repo có `.claude/agents/` — phiên này giao qua agent chung kèm nội dung file vai |
| M1 Vòng khung hình — đo | **PASS** (mã) · số đo thiết bị: chưa có | Thêm "Lượt vẽ SceneKit (luồng render)" = willRender→didRender vào bảng chẩn đoán (trong khoá, giới hạn 3.600 mẫu). Thời gian GPU thật (`MTLCommandBuffer`) không lấy được qua API công khai của SCNView; ghi chú lại |
| M1 — sửa | **Một phần** | (c) `preferredFrameRateRange` 60–120 cho CADisplayLink qua MỘT hàm `setLinkRate`; theo review đặt sau cờ `tuneFrameRange045` (tắt) vì SCNView vẫn vẽ tần số cố định — lệch nhịp link/view là lỗi 0.39. (a)/(b) chờ số đo máy anh. Lưới an toàn tự về 60 Hz (0.44.1) giữ. perf QA Simulator: **NOT RUN**. Tiêu chí 120 Hz ≤ 2 % thiếu mẫu, Cảnh 3D p95 ≤ 4 ms: **chưa xác minh trên thiết bị** |
| M2 Tách TrainingController | **PASS** (build + so mã) · UI test NOT RUN | 3.342 → 598 dòng + `TC+ShotLoop` 581 · `TC+AimInput` 385 · `TC+HUD` 691 · `TC+Menu` 407 · `TC+Replay` 413 · `TC+Coach` 320 (đều ≤ 900). Di chuyển nguyên khối bằng script, build xanh sau 6 bước; so tập dòng: không thiếu dòng; giám khảo xác nhận không đổi hành vi. Không có `TC+Match` (trận đã ở `MatchPlayController.swift`, 1.851 dòng — ngoài phạm vi, cần anh quyết nếu muốn tách). 2 script kiểm tra đọc mã nguồn (`check_gestures.py`, `check_zupe_integration.py`) cập nhật để đọc cả `TC+*.swift`. So pixel ảnh CI với 0.44.1: **NOT RUN** |
| M3 ZDesign | **PASS** (mã + script) · ảnh NOT RUN | `UI/ZDesign0445.swift`: token màu/chữ (Dynamic Type ≥ 13 pt)/bo góc/khoảng cách/chuyển động; `ZPill`, `ZButton`, `ZToast`, `ZSheet`. Đã thay: khung Coach + 3 nút Coach (0.44.1, cùng quy tắc), toast trạng thái → viên kính mờ, bong bóng hướng dẫn (GlassPill = ZPill) |
| M3 i18n | **PASS** | `Tools/i18n/check_vi_en.py`: 646/646 chuỗi tiếng Việt hiển thị có tiếng Anh (trước: thiếu 320); `I18N_en` 310 → 658 mục. Test XCTest Sảnh theo ngôn ngữ máy (vi/en) đã viết: **NOT RUN** |
| M4 Thử RealityKit | **NOT RUN** | `Docs/THU-REALITYKIT.md` (kế hoạch đo; cần Simulator). Không chuyển engine |

## accept_local
| Bước | Kết quả |
|---|---|
| assets | PASS |
| portable-regressions | PASS (`accept_local.sh --portable`: STATUS PASSED_PORTABLE; lần đầu FAIL vì 2 script đọc nguồn sau khi tách — đã sửa) |
| replay-recording | PASS (ReplayRecording 13, FramePacer 983) |
| lan-wire-protocol | PASS (LAN 1.256, Nearby 68, ngôn ngữ 15) |
| simulator-build | PASS (Verify-on-Mac) |
| screenshots / ui-gesture-tests | NOT RUN (Simulator) |
| unsigned-iphone-build | PASS (sau sửa review) — `dist/ZokerPoolTrainer-0.45-Build26.ipa` 81 MB, SHA-256 `6b51a3dc996118a3…`, chưa ký |

## Review giám khảo 0.45 (opus) — không lỗi chặn; đã sửa
Toast: nền kính mờ nằm dưới view khác sau `bringSubviewToFront` (sửa: đưa lên trước rồi mới hiện) · dải tần số trộn với
`preferredFramesPerSecond` ở 4 chỗ (sửa: một hàm `setLinkRate`) · nguy cơ lệch link/SCNView (dải để sau cờ) · `zh-HK/zh-TW` ra giản
thể (sửa + test, 15 kiểm tra) · `renderPass` không giới hạn (sửa). Còn lại (thấp): `ZToast.style` chưa dùng; KVO `alpha` chưa có tác dụng.

## Cần anh
- Đo trên máy ProMotion: bảng "Nhịp hiển thị cú vừa đánh" ở 120 Hz (có thêm "Lượt vẽ SceneKit"); thử bật `tuneFrameRange045`.
- Quyết: có tách `MatchPlayController.swift` (1.851 dòng) không.
- Simulator: có thể cần khởi động lại Mac để CoreSimulatorService chạy lại.
