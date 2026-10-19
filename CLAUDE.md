# Zoker Pool Trainer (iOS)

App bida 3D trên iPhone để **luyện mắt, tư duy và khả năng dự đoán đường bi**. Không tuyên bố luyện động tác ra cơ ngoài đời. Không phải game giải trí.

## Ưu tiên (theo thứ tự)
1. Vật lý kiểm chứng được, deterministic.
2. Điều khiển nhất quán: cùng đầu vào → cùng kết quả, không ngẫu nhiên.
3. Ngắm bằng mắt: không tia ngắm, không bi ma, không số độ, không chữ khi đánh.
4. Luyện tập dựa trên dữ liệu: bài tập có mục tiêu cụ thể, phản hồi sau cú, lịch sử.
5. Đồ họa phục vụ việc ngắm trước, đẹp sau. Chỉ màn hình ngang, 60 fps.

## Quyết định đã chốt (chi tiết: UPGRADE.md mục 1)
- **Natural Stroke** là chế độ chính; **Shot Lab** (nhập trực tiếp hướng, điểm chạm, lực) chỉ để phân tích, tái hiện cú và bài tập quyết định.
- Cú vuốt tối ưu cho tính nhất quán; **không** hiệu chỉnh theo tốc độ đầu cơ thật.
- Vật lý MVP: hướng bi mục tiêu, throw, băng theo tốc độ/xoáy, squirt, hình học lỗ. Hoãn swerve, truyền xoáy, massé, nhảy.
- Ba tầng kiểm chứng tách biệt: toán học, đối chứng pooltool, bàn thật. Hai engine giống nhau **không** chứng minh đúng với thực tế.

## Kiến trúc (không đổi khi chưa hỏi)
- Swift 6, iOS 18+, SwiftUI + RealityKit, XcodeGen (`project.yml`). **Không dùng engine vật lý có sẵn.**
- `Packages/PoolPhysics` — Swift thuần (Foundation + simd), không biết gì về UI. Gồm: chuyển động, va chạm, cú đánh, `TableDefinition`/`CalibrationProfile` (có nguồn gốc tham số), `RenderMapping` (hàm đổi tọa độ duy nhất sang RealityKit).
- `Packages/PoolInput` — cảm ứng → kết quả cú vuốt; máy trạng thái; vùng khóa; ghi và phát lại cảm ứng thô (`TouchRecording`).
- `Packages/PoolDrills` — bài tập JSON, điều kiện đạt, chấm điểm, lịch sử (`ShotLog`), phân tích lỗi.
- `Packages/PoolAudio` — Zoker Acoustic Physics: AudioEvent → AudioScheduler → SampleLibrary → OfflineRenderer (Swift thuần).
- `App/` — nơi duy nhất ghép các package: ARView (non-AR), camera, cảm ứng, haptic, AVAudioEngine, lưu lịch sử JSON, Shot Lab.
- `Tools/validation/` — Python: đối chứng pooltool (qua `poolsim`), đo video, độ không chắc chắn, hiệu chỉnh. Không nằm trong app.
- CI: `.github/workflows/ci.yml` — test 4 package, build app (simulator), job `validation`. Lỗi/kết quả hiện thành annotation.

## Tài liệu (chỉ đọc file liên quan đến nhiệm vụ)
- `UPGRADE.md` — quyết định, KPI, lộ trình (nguồn chính)
- `REVIEW.md` — lập luận đằng sau các quyết định
- `docs/01-physics.md` · `docs/02-controls.md` · `docs/03-camera-graphics.md`
- `docs/04-drills.md` · `docs/05-feedback.md` · `docs/06-features.md` · `docs/07-validation.md`
- `docs/08-tham-khao-shooterspool.md` — tham khảo ý tưởng từ ShootersPool (độc quyền: không chép mã/tài nguyên)

## Quy tắc làm việc
- Mỗi phiên **một** nhiệm vụ trong `PROGRESS.md`, rồi dừng. Không tự chuyển nhiệm vụ.
- Chỉ đánh dấu xong khi đã build và chạy test thật trên macOS/thiết bị. Không có môi trường thì ghi "chưa xác minh". Kiểm tra cú pháp không phải build.
- Mọi tham số vật lý có nguồn gốc (`Provenance`): đã công bố / đã đo / giả định.
- Vật lý: viết test trước; ghi giả thiết của từng nghiệm giải tích.
- Chỉ đọc/sửa file liên quan. Không in toàn bộ log, chỉ in lỗi.
- Xong: commit (mô tả ngắn), cập nhật `PROGRESS.md` (Nhật ký + vấn đề mở). Báo cáo tối đa 5 dòng.
