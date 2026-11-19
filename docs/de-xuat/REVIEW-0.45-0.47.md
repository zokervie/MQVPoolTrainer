# Review độc lập 0.44.1 → 0.47 (phiên đám mây)

Phiên Mac: đầu mỗi mốc đọc file này. **LỖI CHẶN** sửa trước khi làm tiếp; **VỪA/NHẸ** sửa trong mốc gần nhất cùng chỗ, ghi vào nghiệm thu.

## 0.44.1 (review sớm M1–M3 + 2 đợt bổ sung, đến 1373bc7) — chưa có lỗi chặn
- M1 (1a4ecaa): Chơi gần, Cú đầu tiên, đổi tên, phiên bản, `%lld`: đạt. 31 bộ C++ PASS trên Linux (g++).
- **VỪA** `UI/L10nDefault0441.swift`: so khớp chỉ theo phần đầu thẻ ngôn ngữ ("zh") nên máy tiếng Trung (`zh-Hans-CN`) không khớp mã `zh-Hans` và rơi về tiếng Việt. Sửa: so cả thẻ đầy đủ không phân biệt hoa thường với từng mã hỗ trợ (`zh-hans` ⊂ `zh-hans-cn`), rồi mới tới phần đầu; thêm ca kiểm vào `Tests/L10nDefaultTests.swift` (zh-Hans-CN → zh-Hans, zh-Hant-TW → vi hoặc en theo quyết định, ja-JP → ja, en-VN → en, vi-VN → vi).
- **NHẸ** `TrainingController.swift` toast "Đã chuyển 60 Hz cho mượt · Switched to 60 Hz for smoothness": hiện cả hai ngôn ngữ một lúc. Dùng L10n (vi + en trong i18n), hiện một ngôn ngữ.

## 0.45 (đến b49c8e3, 17/11 23:50)
- **LỖI CHẶN — thiếu 0.45 M5** (PlayerStore + mã bài ổn định, AppFlow, Prefs, số liệu cục bộ, cờ QA). Mốc này được thêm vào nhiệm vụ lúc ~21:00 (commit 4b43e61); `NGHIEM-THU-0.45.md` không nhắc tới. 0.47 (Bài hôm nay, chuỗi, kỷ lục, thi chương) không làm đúng được nếu thiếu. **Làm 0.45 M5 trên `cho/native-0.45` trước khi sang 0.46** (hoặc ngay đầu `cho/native-0.46` nếu đã tạo), ghi vào NGHIEM-THU-0.45.
- **VỪA** Simulator vẫn treo từ ~20:45 nên ảnh, UI test, perf QA của cả 0.44.1 và 0.45 là NOT RUN. Đề nghị chủ dự án khởi động lại Mac; sau đó chạy lại `accept_local.sh` cho 0.45 trước khi đẩy 0.46.
- **NHẸ** Ghi chú của nghiệm thu: vai trong `.claude/agents/` chỉ nạp khi `claude` mở tại gốc repo. Mở lại phiên tại `~/Developer/ZokerPool/MQVPoolTrainer` (gốc), không ở `native/ZokerPoolTrainer`.
- Đã xem: M0, M1 (một phần, có lý do: SCNView vẫn vẽ tần số cố định), M2 (3.342 → 598 dòng, 6 file ≤ 900), M3 (ZDesign, i18n 646/646), M4 NOT RUN có kế hoạch. Không thấy lỗi chặn khác ở mức đọc nghiệm thu; review mã chi tiết M2 khi có CI.

## CI 158 (ci/native-0.44.1 @ f6f8dac = 94f6f46 + Xcode 26), 18/11 00:29 — FAILED 1 bước
- PASS: assets, portable-regressions, replay-recording, lan-wire-protocol, simulator-build (Xcode 26.3), **screenshots-and-runtime-probes** (gồm đầu dò intro mới) → intro KHÔNG làm treo Simulator; Simulator treo trên Mac là chuyện riêng của máy.
- **LỖI CHẶN** `ui-gesture-tests`: 22 test, 1 hỏng — `testFirstLaunchTutorialFromLobbyAimThenStroke` (`UITests/InteractionTests.swift:386-387`): sau khi ngắm trúng chấm vàng, hướng dẫn chuyển sang `hint-replay` thay vì nhịp 2 `stroke`; chờ cú 40 s hết giờ (`shots=0`). Test này PASS trên Mac sau M4 (21/21) và hỏng sau commit M6 `94f6f46` (các sửa review: "cú ở bất kỳ nhịp nào kết thúc nhịp", tự đóng "Thử lại nhé", …) → nhiều khả năng một sửa ở M6 cho gợi ý theo ngữ cảnh "Xem lại" chen vào giữa nhịp 1 và nhịp 2. Người chơi thật sẽ thấy gợi ý "Xem lại" thay vì "Giữ B, vuốt lùi rồi đẩy tới" ở lần chơi đầu.
  Sửa: gợi ý theo ngữ cảnh không được hiện khi hướng dẫn 2 nhịp chưa xong; nhịp 1 xong phải sang đúng nhịp 2. Sửa trên `cho/native-0.45` (mã hướng dẫn giống 0.44.1), chạy lại test này; phiên đám mây sẽ dựng IPA mới từ nhánh có bản sửa.

## CI 159 (ci/native-0.47 @ 19984f9 + Xcode 26), 18/11 — FAILED: ui-gesture-tests TIMEOUT, 7 test hỏng
Các bước khác PASS (gồm ảnh + đầu dò). Test giao diện mới viết khi Simulator Mac treo nên chưa từng chạy; giờ CI chạy thì hỏng:
- **LỖI CHẶN** `testLobbyLanguageFollowsDevice`: máy tiếng Anh vẫn thấy "Tập tự do" trên Sảnh → Sảnh 0.46 chưa qua L10n.
- **LỖI CHẶN** `testDailyCardOnTopOfLobbyStartsTodaysDrill`: "fresh player: no streak yet" sai + hết giờ 80 s → dữ liệu người chơi không được xoá giữa các test (cần cờ QA reset PlayerStore) hoặc thẻ Bài hôm nay không mở bài.
- **LỖI CHẶN** `testChapterOneLadderAndExam`: 5 cú QA không đóng vòng; không thấy alert "Đóng".
- `testChallengeCodeOpensTheSameDrillAndRejectsATypo`: không có nút "Chơi bài này".
- `testProgressScreenWithThirtyDemoDays`, `testArchivedReplayPreservesLiveTableAndRemembersItsCoachChoice`: XCTAssertTrue failed.
- `testLiveShotKeepsAimViewAndManualZoomAfterBallsStop`: hết giờ 40 s (test cũ, đã PASS ở CI 158) → hồi quy do 0.45–0.47.
Việc: khởi động lại Mac để Simulator chạy, chạy từng test trên Mac, sửa đến khi `ui-gesture-tests` PASS. Log: `gh api repos/zokervie/MQVPoolTrainer/actions/runs/44226195520/jobs`.

## CI 160 (ci/native-0.48) — cổng Linux g++ đỏ
- **LỖI CHẶN (đã vá trên ci/native-0.48 @ 0b7ae8f, cần áp lại vào cho/native-0.48):** `-Werror=misleading-indentation` ở `Core/CameraPlanner.hpp` (dòng ~294, ~611, ~744, ~764) và `Tests/CameraPlannerTests.cpp:37`: nhiều lệnh sau if/for/while trên một dòng. Tách thành dòng riêng. Luôn chạy thử `g++ -Wall -Wextra -Werror` trước khi đẩy (clang trên Mac không báo lỗi này).

## CI 161 (ci/native-0.48 @ 0b7ae8f) — cổng Linux PASS; ui-gesture-tests TIMEOUT (chỉ chạy được 5 test)
- **LỖI CHẶN** `testReplayPlannedAnglesAndExportBothFrames` hết 720 s: xuất 2 video trên Simulator CI quá chậm và nuốt hết thời gian của cả nhóm test. Sửa: trong test chỉ xuất đoạn ≤ 1,5 s ở độ phân giải nhỏ (vd 360×640 / 640×360), kiểm kích thước + số khung; việc xuất đầy đủ để cờ QA riêng không chạy trong ui-gesture-tests. Mục tiêu test này ≤ 90 s.
- **LỖI CHẶN** `testIntroPlaysBeforeLobbyAndTapSkips`: "finish ran exactly once" sai → intro gọi `finish` hai lần (chạm bỏ qua + hết giờ cùng chạy). Chặn bằng cờ `finished` một lần; test này PASS ở CI 158 nên là hồi quy 0.45–0.48.
- **LỖI CHẶN** `testChapterOneLadderAndExam`: vẫn hỏng (không thấy alert kết quả sau 10 cú).
- 2 test PASS trước khi hết giờ. Log: `gh api repos/zokervie/MQVPoolTrainer/actions/runs/44318975668/jobs`.

## CI 162 (ci/native-0.48-r2 @ f596fbe + Xcode 26) — 31/32 test PASS
- Mọi bước khác PASS. Còn **LỖI CHẶN** `testChapterOneLadderAndExam`: sau 10 cú QA không có alert kết quả ("ten shots, then the only result: … mode=2"). Kiểm luồng kết thúc bài thi chương 1 (đếm cú QA có cộng vào lượt thi không; alert có bị overlay khác che không). IPA 162 đã gửi chủ dự án thử kèm cảnh báo mục này.

## Chữ Việt + Anh (19/11) — nhánh `cho/native-0.48-l10n` @ 1a70ec2
- Phiên đám mây đã sửa chuỗi và danh mục (13 file, chỉ chuỗi). **Gộp vào `cho/native-0.48` trước khi làm tiếp** (`git merge origin/cho/native-0.48-l10n`), build + chạy UI test (chưa build Swift ở đám mây).
- Còn lại cho phiên Mac ở 0.49: tên 6 cấp máy sang tiếng Việt (Tập sự · Nghiệp dư · CLB · Phong trào · Chuyên nghiệp · Đỉnh cao; en giữ Beginner…); thống nhất "ép phê" (bỏ "effect" trong chuỗi Việt); bỏ số phiên bản trong chuỗi người dùng ("Cũ 0.17", "Điều khiển 0.18 & ghi công", "Bộ giải 0.9"); sửa số cũ "Thư viện 20 bàn · 12 cơ", "Cỡ 8 ft và 7 ft: bản sau"; test `check_resources.py` còn in "Z-Trainer master".
