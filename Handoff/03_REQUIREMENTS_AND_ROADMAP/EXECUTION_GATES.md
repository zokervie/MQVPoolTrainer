# LỘ TRÌNH THỰC THI VÀ GATE PHÊ DUYỆT

| Gate | Phạm vi | Deliverable | Chỉ được đóng khi |
|---|---|---|---|
| G0 | Audit base SHA / source tree / test suite / license / CI / test on Mac | `BASELINE.md`, `FEATURE_MATRIX.csv`, baseline logs | Có bằng chứng chạy test; lỗi thiếu môi trường được đánh dấu rõ |
| G1 | HUD phải + camera Aim3D, xoay/zoom/trả auto | Branch/PR 0.13-hud-camera, video chụp UI, regression | Chuyển về Aim3D khi dừng; không ghost stroke; B/Undo/spin không chồng hit area |
| G2 | Cơ côn băng + effect động + N random bi | Branch/PR cue-random, geometry tests, seed tests | Cơ không xuyên băng, prediction/strike/show cue đồng nhất; random không chồng lỗ/bi |
| G3 | Sound samples & giáo trình video/PDF | PR audio-learning, asset license manifest, lesson JSON schema | Mỗi âm có license; 10 bài có mục tiêu + sơ đồ + source + cách học; khả năng mở video thực tế |
| G4 | Release offline 0.13 | Xcode/Codemagic artifact signed/unsigned rõ ràng, release notes | Test, screenshot, cấu trúc IPA, checksums; iPhone test còn thiếu phải nêu rõ |
| G5 | Realtime rooms/rules backend | PR server+client protocol, room/rules tests | Mã phòng, 2 người, xác nhận luật, bí mật được bảo vệ, backend cost cap |
| G6 | Turn sync, score, spectator, reconnect | 0.14 candidate, 2 devices QA, logs | 50 shots đối chiếu không drift không xử lý; reconnect/timeout/foul tests |
| G7 | Release 0.14 và rollback | Final build, release report, cost monitoring | Chỉ ký phát hành khi user đã có phương án phân phối và nghiệm thu thực tế |

## Bảo vệ code cũ

- Không đưa vật lý/renderer trùng lặp từ MQVPoolTrainer vào repo chính.
- Solver native điều khiển trạng thái bi; networking đồng bộ sự kiện/snapshot/rule, KHÔNG sử dụng SceneKit physics như nguồn chân lý.
- Tests: `Run-All-Checks.command`, Simulator, native QA, image QA, real device.
- Chỉ build tốn phí khi PR đạt test rẻ hoặc cần thử trên máy; tránh GitHub Actions + Codemagic build trùng.
- Trước commit: kiểm tra credentials, license, pbxproj và resources để tránh IPA rỗng/quá nhỏ.
