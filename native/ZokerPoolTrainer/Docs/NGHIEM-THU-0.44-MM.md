# Nghiệm thu 0.44-MM — giật khi chơi, Wi-Fi, highlight máy khách, tiếng lọt lỗ (16/11/2026)

## Nhánh và SHA
- Nhánh: `cho/native-0.44-mm` (đã push, không push `ci/*`, không merge). Gốc: `cho/native-0.40c` @ `9eb77f0`.
- Commit: `7c68e7d` việc 1 · `4103d47` việc 4 · `ffd449d` việc 3 · `103ec3d` sửa chuỗi QA · (commit tài liệu này).
- Máy: MacBook, Xcode 26.3 (17C529), Simulator iPhone 17 Pro Max iOS 26.3. CI dùng Xcode 16.4 — kết quả local chưa thay được CI.
- 18 file AppIcon do bước `assets` sinh ra: KHÔNG commit.

## Việc đã làm — có bằng chứng
### 1. Giật khi chơi, replay mượt — ĐÃ SỬA (đo trên Simulator; chưa xác minh trên thiết bị)
Đo trước bằng đầu dò mới `--perf-qa` (trận 9 bi chơi chung máy, cú phá 7 m/s, rồi xem lại 1×; `-qaSimFPS 60`):
khung đầu của cú THẬT tiến vật lý 100 ms; luồng chính bị chặn 68–75 ms ngay sau cú đánh. Time Profiler:
`SpinPad.draw` (bi hiệu ứng + kính phóng) thử 22×22 = 484 ô, mỗi ô đọc lại 16 bi và settings của solver.
Replay không vẽ lại bi hiệu ứng giữa chừng, khung chậm của nó rơi vào đoạn dạo đầu (bi đứng yên) → mượt.

Sửa (nguyên nhân gốc, không đổi bố cục HUD): tester khoảng hở cơ chụp MỘT lần mỗi lần vẽ (cùng hàm
`BLCueMinimumElevationBalls`, cùng kết quả), áp cho cả kính phóng; khung live đầu tiên tiến tối đa một nhịp.

| Số đo (Simulator, 60 Hz) | Trước | Sau (2 lần) |
|---|---|---|
| Vật lý dồn vào khung đầu khi chơi | 100 ms (bi cái nhảy ~70 cm) | 16,7 / 16,7 ms |
| Commit hệ thống sau cú đánh | 68–75 ms | 30–34 ms |
| Từ lúc đánh đến khung kế | 75–77 ms | 32–42 ms |
| CPU luồng chính mỗi khung khi chơi p50/p95/max | 2,9 / 6,5 / 11,4 ms | 2,3 / 4,3 / 5,8 ms |
| CPU mỗi khung khi xem lại p50/p95/max | 1,7 / 5,9 / 15,3 ms | 1,4 / 4,1–4,9 / 7,7–8,9 ms |
| Mạng + máy đối thủ + đồng hồ (p95) | 0,44 ms | 0,33–0,36 ms |
| Âm thanh mỗi khung (p95) | 0,9 ms | 0,3–0,5 ms |
| Dựng lại HUD khi bi chạy | 0 | 0 |

Giới hạn: Simulator chỉ render 15–20 khung/giây (GPU giả lập), nên KHÔNG đo được độ giật hình ảnh thật.
Công cụ: `bash Tools/run_perf_qa.sh <thư-mục>` + `Tools/perf_judder.py`; trên máy: Menu → "Nhịp hiển thị cú vừa đánh".

### 2. Wi-Fi lockstep
- `run_lan_checks.sh` PASS (1.256 kiểm tra codec/quyền), FramePacer PASS (983), `LockstepTests` (C++) PASS trong portable.
- Đọc mã: bộ giải bước cố định có bộ tích luỹ → máy chủ và máy khách cắt thời gian khác nhau vẫn trùng từng bit (đã có test). Không thấy lỗi đồng bộ.
- 2 Simulator (`--lan-host-qa` / `--lan-join-qa`, `ZOKER_QA_ROOM`): MultipeerConnectivity TÌM THẤY máy kia nhưng không lập
  được phiên (`No signal block found for participant`) — giới hạn MC giữa 2 Simulator trên một Mac. **Cần 2 máy thật.**

### 3. Highlight cho máy khách Wi-Fi — ĐÃ LÀM, chưa xác minh (cần 2 máy)
Máy khách lấy mẫu chính lần chạy lockstep của nó (240/60/30 Hz như máy chủ), chấm bằng cùng `scoreHighlight` khi máy chủ
xác nhận bi dừng; cú bị lệch (fallback) thì bỏ. Hết trận máy khách cũng hiện chip Highlight. Không thêm dữ liệu mạng.

### 4. Tiếng bi lọt lỗ theo tốc độ — ĐÃ LÀM
`BLPocketSoundForSpeed` (C++ test trước, 5 kịch bản PASS): mức tiếng rơi tăng theo tốc độ, bão hoà 6 m/s; từ 1,2 m/s thêm tiếng
va thành lỗ (mẫu PoolRail0 CC0 có sẵn), đầy ở 4,5 m/s; áp cho cả xuất video. Hệ số: GIẢ ĐỊNH, chưa đo. Không thêm nguồn âm.

### Thêm
- Lỗi chuỗi định dạng QA (`%d` với Swift Int) ghi lỗi ở MỖI khung trên iOS 26 khi `--visual-qa` → đổi `%lld`.

## 5. accept_local.sh bản đầy đủ (@103ec3d)
| Bước | Kết quả |
|---|---|
| assets | PASS |
| portable-regressions | PASS |
| replay-recording | PASS |
| lan-wire-protocol | PASS |
| simulator-build | PASS |
| screenshots-and-runtime-probes | PASS (47 ảnh: `native/ZokerPoolTrainer/build/screenshots`) |
| ui-gesture-tests | FAIL — 18/19 PASS; `testLiveShotKeepsAimViewAndManualZoomAfterBallsStop` |
| unsigned-iphone-build | NOT RUN trong script (dừng ở bước trước). Chạy riêng `Build-Unsigned-IPA.command` @103ec3d: BUILD SUCCEEDED, `dist/ZokerPoolTrainer-0.39-Build24.ipa` 82,7 MB, SHA-256 `0a9f78d8ccfb167d…`, CHƯA KÝ (không cài thẳng được) |

Phân loại FAIL: **có từ trước, không do 0.44-MM** — cùng test, cùng giá trị (-1,83597 vs 1,887333) trên `9eb77f0` (trước mọi sửa
đổi); CI 155 (Xcode 16.4) xanh. Cơ chế đã thấy: trên máy này cú QA 3 m/s dừng TRƯỚC khi XCUITest kịp chụm + kéo, nên cú kéo là kéo
ngắm khi bàn đứng yên; sau đó app ngắm bi kế (`resetShotInputsAndAim`) và trả camera về sau bi cái (`restoreAimCamera`, thiết kế
0.36). Thử 5 m/s: 1 lần bi còn chạy lúc quan sát nhưng góc sau vẫn đổi, 1 lần bi đã dừng → CHƯA chứng minh được là lỗi app hay
chỉ do thời gian; đã hoàn lại thay đổi, không sửa test khi chưa có bằng chứng.

## Rủi ro
- Số đo là Simulator (CPU Mac); iPhone chậm hơn → mức chặn trước sửa có thể lớn hơn, sau sửa chưa đo trên máy.
- Khung đầu vẫn dài ~60–70 ms thời gian thực (vật lý chỉ tiến 16,7 ms nên bi không nhảy; có thể thấy bi "khựng" rất ngắn lúc đánh).
- Hệ số tiếng lọt lỗ là giả định. Highlight máy khách chưa chạy thật.

## Việc chưa làm
- Nearby Play (bổ sung của anh) — làm sau mục này, phạm vi: giao diện phòng + nối lại trên MultipeerConnectivity/LANShotStart hiện có.
- Giảm tiếp 30 ms commit còn lại sau cú đánh (cần profile trên máy thật).

## Việc cần anh
- Cài IPA lên máy, đánh vài cú mạnh: còn khựng lúc cơ chạm bi không? Gửi "Sao chép số đo" ở Menu → "Nhịp hiển thị cú vừa đánh".
- 2 máy thật để thử Wi-Fi lockstep + highlight máy khách.
- Quyết test UI camera: giữ thiết kế 0.36 (camera về sau bi cái sau khi bi dừng) hay giữ góc quan sát? Em đề xuất giữ 0.36 và sửa test.
