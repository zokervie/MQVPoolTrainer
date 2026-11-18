# Nghiệm thu 0.48 "Máy quay" (18/11/2026)

Nhánh `cho/native-0.48` (từ `cho/native-0.47` @ `19984f9`; không có `origin/cho/native-0.48-core` nên lõi làm ở phiên Mac). 0.48 (29).
Không push `ci/*`, không sửa `.github/workflows`, không commit AppIcon. Đề bài: `plan/de-xuat-zoker:docs/de-xuat/NHIEM-VU-0.48-MAY-QUAY.md`.
Điều phối: M1 vai kỹ sư lõi (opus); M2–M3 phiên chính; review vai giám khảo (opus).

## Mốc
| Mốc | Kết quả | Bằng chứng / chưa làm |
|---|---|---|
| M1 Lõi `CameraPlanner` | **PASS** | `BankLab/Core/CameraPlanner.hpp` + cầu `BLCameraPlan` + `Tests/CameraPlannerTests.cpp` **1.839 kiểm tra PASS**: 5 cú mô phỏng thật (thẳng, cắt 30°, bank, kick, phá 9 bi) + cú rất ngắn × 7 kiểu máy × 16:9/9:16. Tốc độ góc đỉnh ≤ 58,4°/s (giới hạn 90), gia tốc góc ≤ 365°/s² (giới hạn 600), bi chính thấy 100 % (bi khác, băng/gỗ theo `World::buildRails`, khung đèn từ `TableScene.tableFixture()`), mỗi cảnh ≥ 1,2 s, không cắt trong 0,3 s trước khoảnh khắc chính, luật 180°, tốc độ phát liên tục (vào ×0,35 trong 0,25 s, ra 0,35 s), vùng an toàn 8 % (NDC ≤ 0,81). Teaser ≤ 6,4 s. Cổng Linux g++/clang++: chưa chạy (máy không có g++/cmake) — CI sẽ chạy |
| M2 Nối SceneKit | **PASS** (build + XCTest Simulator) · chưa xác minh trên thiết bị | Mọi góc đọc đường máy + đường tốc độ từ `BLCameraPlan`, lập một lần khi mở xem lại; bỏ máy action đặt theo khung hiện tại và chậm bật/tắt. Menu: **Tự động** Đạo diễn · Học; **Chọn tay** Người đánh · Toàn bàn 3/4 · Trên cao · Theo bi cái · Ngang băng · Đón ở lỗ. `replayCamera041` (14 góc) ánh xạ sang góc gần nhất (`replayCamera048`). Vệt đường bi (bi cái trắng, bi mục tiêu màu bi; bi 8 xám) ở cảnh Kết và chế độ Học (hiện dần 10 Hz, điểm băng, bi ma lúc chạm); vệt Coach không bị đụng. Kéo tay trong xem lại: lướt 0,35 s về máy tay |
| M3 Xuất video, teaser | **PASS** (XCTest: 9:16 = 1080×1920, 16:9 = 1920×1080) · Teaser/ảnh thẻ: build PASS, chưa xem bằng mắt | Dựng ngoài màn hình bằng `SCNRenderer` đúng khung đầu ra, máy lập kế hoạch lại cho khung dọc. "Teaser 8 giây" dọc/ngang: phần Teaser ≤ 6,5 s + thẻ cuối 1,5 s (logo Zoker, mã thách bạn gần nhất của 0.47 M6, sting intro tự tổng hợp). "Ảnh thẻ (khung đẹp nhất)": khung va chạm đầu/bi rơi, 1920×1080 có logo. Âm thanh: mỗi tiếng va chạm trộn ở đúng thời điểm video với cao độ/độ dài thật ⇒ đoạn chậm không kéo dài tiếng (như phim) |
| M4 Kiểm | **Một phần** | Test C++ M1 PASS; XCTest `testReplayPlannedAnglesAndExportBothFrames` **PASS** trên Simulator (mở xem lại Đạo diễn, đổi Học → Đón ở lỗ, xuất 9:16 + 16:9); 2 test xem lại cũ PASS. XCTest chỉ dùng 1 cú QA (5 cú mẫu nằm ở test C++). Chẩn đoán thêm "Tốc độ góc máy xem lại vừa rồi p95/max" (đo trên camera đã vẽ, bỏ điểm cắt/tua/kéo tay) — **chờ anh đo trên máy thật**. Ảnh/video mẫu 5 cú × 2 khung lên `shots/native`: **NOT RUN** (cần CI) |

## Lệch đề / cần anh quyết
- **Lead xem lại:** Đạo diễn đủ 6 cảnh cần ~3 s trước cú (`BLCameraPlan.recommendedLead`); app vẫn giữ 1 s như anh dặn 0.41 ⇒ Đạo diễn gộp còn 4 cảnh (Mở+Ra cơ gộp). Tăng lead cho Đạo diễn? (đổi thì `testReplayIncludesActualPreparationBeforeNativeShotClock` phải sửa theo).
- Cảnh Mở dài 1,25 s (đề 0,8 s) vì luật cảnh ≥ 1,2 s thắng.
- Cú lọt rất nhanh (< ~0,55 s sau va chạm) không đủ chỗ cho 6 cảnh ≥ 1,2 s ⇒ planner gộp cảnh (mâu thuẫn hình học thật).
- Menu 8 góc cao hơn màn iPhone ngang ⇒ phải cuộn để thấy 3 góc cuối.

## Review giám khảo (opus) — 11 phát hiện, đã sửa 9
Cao: khung 9:16 lập theo 16:9 (sửa), xem lại xoá vệt Coach (sửa), Ảnh thẻ hỏng khi mở từ thanh xem lại (sửa). TB: snapshot thiếu flush (sửa),
teaser bị cắt khi người xem đặt 0,5× (sửa: xuất luôn 1×), kéo tay giật (sửa: lướt), số đo góc tính nhầm điểm cắt (sửa), vệt Học dựng lại
30 Hz (sửa: 10 Hz). Thấp: xuất khi xem lại không mở (sửa), test để lại góc đã chọn (sửa: `--replay-angle-reset-qa`, kiểm kích thước file).
Chưa sửa: biến cũ không dùng (`replayCamera`, `action*`, `directCamera`, `ReplayDirector.Plan`), vệt `.line` 1 px mảnh trên video 1080p.

## accept_local (bản `568ba7f`)
| Bước | Kết quả |
|---|---|
| assets · portable-regressions (37 bộ C++ gồm CameraPlanner) · replay-recording · lan-wire-protocol · simulator-build | PASS |
| i18n vi+en | PASS (753 chuỗi, thiếu 0) |
| screenshots-and-runtime-probes | **TIMEOUT** — app chết liên tục khi khởi động `AVAudioEngine` (`PoolAudio.init`: RPC timeout / exception). Nguyên nhân: `coreaudiod` của Mac hỏng (`afplay` báo `AudioQueueStart failed (35)`), không phải mã 0.48 |
| ui-gesture-tests (đầy đủ) · unsigned IPA | NOT RUN (dừng sau bước ảnh) |

## CI đám mây trên 0.47 (lần 159, `ci/native-0.47` @ `852dd26`, phiên đám mây đẩy)
Cổng Linux g++/clang++ PASS; Mac: assets → screenshots PASS; ui-gesture-tests **TIMEOUT** với 18 PASS (gồm `testFirstLaunchTutorialFromLobbyAimThenStroke`
— lỗi chặn CI 158 đã hết) và 7 FAIL: `testChapterOneLadderAndExam` (không ra kết quả sau 5 cú), `testDailyCardOnTopOfLobbyStartsTodaysDrill`
(thẻ không có "Bắt đầu chuỗi ngày"), `testLobbyLanguageFollowsDevice` (Sảnh en vẫn "Tập tự do"), `testChallengeCodeOpensTheSameDrillAndRejectsATypo`
(không thấy "Chơi bài này"), `testProgressScreenWithThirtyDemoDays` (app không lên), `testArchivedReplayPreservesLiveTableAndRemembersItsCoachChoice`,
`testLiveShotKeepsAimViewAndManualZoomAfterBallsStop`. 0.48 thừa hưởng — cần sửa trước khi gộp (việc kế tiếp).

## Cần anh
- Chạy `! sudo killall coreaudiod` (âm thanh Mac tự khởi động lại) để em chạy lại `accept_local.sh` cho 0.48 và soát 7 test hỏng của 0.47.
- Quyết lead xem lại 1 s hay ~3 s cho Đạo diễn.
- Đo trên máy thật: Xem lại → Tuỳ chỉnh → chẩn đoán "Tốc độ góc máy" (p95/max); xem bằng mắt Teaser 9:16 và ảnh thẻ.
- Còn chờ từ trước: video 240 fps, giấy phép 4 file âm thanh, tài khoản Developer.
