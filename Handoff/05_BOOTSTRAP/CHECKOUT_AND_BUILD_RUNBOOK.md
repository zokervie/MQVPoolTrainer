# RUNBOOK — MAC / XCODE / CODEMAGIC / CLAUDE

## Môi trường cần có

- macOS có Xcode tương thích project (CI được ghi nhận Xcode 16.4); iOS simulator và thiết bị thử thật khi cần.
- Git có quyền đọc repo private; không chia sẻ GitHub PAT, cert, provision trong chat hoặc ZIP.
- Python3, clang++ và Node 22 cho `Run-All-Checks.command`. Scripts `prepare_ci_assets.py` có thư viện numpy/scipy/Pillow/matplotlib nếu cần tạo lại asset trong CI.

## Cách dựng đúng snapshot lần đầu

```bash
python3 05_BOOTSTRAP/assemble_full_source.py --mode pinned
```

Script fetch `main`, check out **commit cố định** và xuất ZIP mới chứa `ProjectSource` + `Handoff` + `SOURCE_MANIFEST.json`. Bản pinned là baseline để so diff. Khi cần source mới nhất:

```bash
python3 05_BOOTSTRAP/assemble_full_source.py --mode latest
```

Chú ý `latest` có thể thay đổi nội dung theo thời gian; xem `SOURCE_MANIFEST.json` để biết SHA. Không áp patch blindly trên một main mới hơn.

## Trên Mac Agent sau khi clone

```bash
cd native/ZokerPoolTrainer
bash Run-All-Checks.command
bash Verify-on-Mac.command
bash Build-Unsigned-IPA.command
bash Tools/ci_screenshots.sh
```

Nếu thư viện tạo asset bị thiếu hoặc không có Xcode, ghi rõ lý do trong `BASELINE.md`; không báo 'build thành công' bằng lý thuyết.

## Phương án CI tối ưu chi phí

1. Chỉ lint/test C++/JS/local khi chỉ sửa thuật toán/nhỏ, không chạy 2 Mac CI đồng thời.
2. PR đạt regression rồi mới Xcode simulator + native iPhone compile.
3. Codemagic là đường thay thế khi GitHub Actions bị khóa billing; không đoán hai bên đều chạy được.
4. Chụp ảnh, logs, `swiftlint` nếu có, screenshot tool `Tools/ci_screenshots.sh` trên Simulator.
5. Luôn xuất `IPA_SHA256.txt`, source SHA, version/build, evidence table; phân biệt unsigned/signed.

## Khi Claude làm việc qua Github Agent

- Quy trình một nhánh–một mục tiêu–một PR–một biên bản nghiệm thu.
- G1: `feature/0.13-hud-camera`. G2/G3 mỗi pha một branch mới dựa trên branch đã đạt gate (tùy chiến lược tích hợp/PR), không đè code Agent khác.
- Nếu Mac Agent đã kết nối thì gọi tool thực tế; khi chưa có Computer Use, không nói máy Mac đang được điều khiển.
- Ngay khi tạo full-source ZIP, gửi ZIP đó cho Claude hoặc dẫn Claude vào repo; KHÔNG gửi riêng source .ipa để Claude phải suy ngược.
