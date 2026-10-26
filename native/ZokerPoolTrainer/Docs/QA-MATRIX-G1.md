# QA matrix — G0/G1

| Kiểm tra | Trạng thái | Bằng chứng / cách chạy |
|---|---|---|
| Remote SHA/tree + 113 blobs | PASS | SOURCE_PROVENANCE.json, source manifest |
| Baseline resource + 4 JS + 12 C++ | PASS | baseline-run-all.log |
| Candidate resource + 4 JS + 13 C++ | PASS | g1-run-all.log; 32 policy scenarios |
| Production policy C11 ABI syntax | PASS | g1-structure-checks.log |
| Shell/YAML/plist and git diff whitespace | PASS | g1-structure-checks.log |
| Core/Models/Touch/Equipment unchanged | PASS | protected-files.json, 11 files |
| Xcode Simulator compile | BLOCKED | g1-xcode-attempt.log; Linux thiếu xcodebuild |
| UIKit default + actual HUD hit testing | NOT RUN | `--visual-qa --g1-default-qa`, `--g1-hud-qa`, `--g1-hud-qa --spin-detail` |
| Real solver → 0.5s settle → Aim3D | NOT RUN | `--visual-qa --g1-return-qa` |
| Spectator rejects shoot/Undo/Add | NOT RUN | `--visual-qa --g1-spectator-qa` |
| Simulator screenshots/runtime assertions | NOT RUN | `bash Tools/ci_screenshots.sh`; 5 fresh JSON probes required |
| iPhone 14 Pro Max touch/thermal/frame pacing | NOT RUN | 30 real gesture scenarios + timing capture |
| Signed/unsigned IPA 0.13 build 23 | NOT PRODUCED | Build-Unsigned-IPA.command on Mac after previous gates |

## Lệnh tiếp tục trên Mac/CI (không ghi là đã chạy)

```bash
git fetch origin
git switch feature/0.13-hud-camera
git pull --ff-only
cd native/ZokerPoolTrainer
python3 Tools/prepare_ci_assets.py
bash Run-All-Checks.command
bash Verify-on-Mac.command
bash Tools/ci_screenshots.sh
bash Build-Unsigned-IPA.command
```

Các dependency generator đã có trong root codemagic.yaml; dùng workflow root, không chọn nhầm native/ZokerPoolTrainer/codemagic.yaml cũ. GitHub workflow hiện chỉ auto-push main; feature này không tự chạy Xcode. Workflow_dispatch có thể chọn feature branch trên môi trường có quyền. Không chạy đồng thời hai Mac build.

Không coi G1 spectator probe là networking test: localTurn chỉ là cờ quyền offline/QA, chưa có phòng, server, lượt hoặc scoreboard online.
