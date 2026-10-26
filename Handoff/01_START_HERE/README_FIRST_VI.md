# ZOKER POOL TRAINER — COMPLETE AGENT / CLAUDE HANDOFF

**Cập nhật: 24/10/2026. Chủ dự án: Zoker. Chỉ áp dụng cho dự án game/ứng dụng pool trainer, tuyệt đối không trộn Zoker Studio, Zoker Auto Vox hay Davinci Auto Edit.**

## Đọc đầu tiên

1. `02_PROJECT_STATUS/PROJECT_STATE_AND_EVIDENCE.md` — nguồn gốc repo, thông tin hoàn thành và giới hạn nghiệm thu.
2. `02_PROJECT_STATUS/FEATURE_AUDIT.csv` — danh mục chi tiết chức năng, trạng thái, chứng cứ và việc cần làm.
3. `03_REQUIREMENTS_AND_ROADMAP/ZokerPoolTrainer_0.13_0.14_Master_Patch_Workflow_2026-10-24.md` — hợp đồng yêu cầu v0.13/v0.14 có ưu tiên cao khi tài liệu cũ mâu thuẫn.
4. `04_AGENT_PROMPTS/AGENT_START_HERE.md` — lệnh chính để Agent + Claude thực hiện.
5. `05_BOOTSTRAP/assemble_full_source.py` — tự lấy toàn bộ source được Git track tại đúng commit và đóng gói **trọn source + hồ sơ** thành một ZIP tự chứa.
6. `06_REFERENCE_DOCUMENTS` & `07_RESEARCH_AND_TRAINING` — báo cáo các bản trước, giáo trình và sơ đồ.

## Tình trạng của ZIP này — không suy đoán

**Gói ZIP tải từ ChatGPT là gói TIẾP QUẢN (handoff/bootstrap), chưa chứa bytes của toàn bộ GitHub source.** GitHub repository là PRIVATE và container tạo ZIP không có kết nối mạng trực tiếp để clone. Việc ghi source 'đã được kiểm tra' không đồng nghĩa 'đã nhúng source'. Mục `05_BOOTSTRAP` có lệnh tải về đúng repo, kiểm tra HEAD rồi tạo file `ZokerPoolTrainer_FULL_SOURCE_AND_HANDOFF_<SHA>.zip` chứa toàn bộ 113 file đã được Git theo dõi ở mốc đã kiểm tra, và kèm toàn bộ bộ tài liệu này. Đưa ZIP hoàn chỉnh đó cho Claude nếu Claude chưa được kết nối GitHub.

Nếu Claude/Agent có quyền đọc repo ngay, **có thể gửi gói tiếp quản này + GitHub repo**, yêu cầu Agent tự clone/fetch. Không cần ghép code thủ công.

## Source of truth / tránh repo nhầm

- Repository (private): `https://github.com/zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858`
- Reference branch: `main`
- Verified HEAD: `aba66d0f21e0816973ef0c13281fa98855ca3ff6`
- Verified Git-tracked blobs: `113` (all 147 entries include directory tree nodes), bytes recorded in Git tree approx `588522`.
- Native app entrypoint: `native/ZokerPoolTrainer/ZokerPoolTrainer.xcodeproj`
- Baseline release: `0.12 (build 22)`; source build `2dd1a55e51a55c4e2d0c5d697b79fcdd4df3f1bd`; final main HEAD later documentation & small fixes.
- Bundle identifier: `com.maiquocviet.BankLabS`.
- Codemagic build #24 evidence: `https://codemagic.io/app/6ad8240a50a68ff0a344a214/build/6adc7d5e4a72334e32e4ab8b`

## Dành cho người quản lý dự án

- Không đánh dấu hoàn thành chỉ vì tài liệu này đề xuất tính năng.
- Cần phân biệt file IPA unsigned, file IPA signed và source.
- Ghi ngày/commit/PR/build/test/checksum cho từng gate; giữ nhánh `main` không bị ghi đè.
- Giữ tính năng đã có và đặc biệt giữ solver native C++ làm nguồn trạng thái bóng duy nhất.
- Phương án cơ bản: bản 0.13 nâng cấp trải nghiệm luyện tập offline trước; bản 0.14 bổ sung multiplayer realtime.

## Tạo ZIP chứa trọn source (trên Mac/Windows có Internet và quyền GitHub)

Mac: nhấp đúp `05_BOOTSTRAP/BUILD_FULL_HANDOFF_MAC.command`, hoặc chạy `python3 05_BOOTSTRAP/assemble_full_source.py` trong Terminal.

Windows: chạy `powershell -ExecutionPolicy Bypass -File .\05_BOOTSTRAP\BUILD_FULL_HANDOFF_WINDOWS.ps1`, hoặc `py -3 05_BOOTSTRAP\assemble_full_source.py`.

Mặc định: đóng băng đúng commit đã xác minh. Để dùng main tại thời điểm agent chạy: `python3 05_BOOTSTRAP/assemble_full_source.py --mode latest` và yêu cầu audit diff.

**Không cần gửi mật khẩu/token trong chat.** `git clone` sử dụng Git credential manager / SSH / auth sẵn trên máy. Nếu báo không có quyền, người dùng cấp quyền trên GitHub trong môi trường Agent rồi chạy lại.
