# Nghiệm thu 0.46 "Diện mạo mới" (17–18/11/2026)

Nhánh `cho/native-0.46` (từ `cho/native-0.45` @ `b49c8e3`). 0.46 (27). Không push `ci/*`, không sửa `.github/workflows`, không
commit AppIcon. Đề bài: `plan/de-xuat-zoker:docs/de-xuat/NHIEM-VU-0.45-0.47.md` (phần 0.46). Điều phối: M1–M2 vai giao diện (sonnet),
M3 vai kỹ sư lõi (opus), review vai giám khảo (opus).

**Chặn chung:** Simulator không khởi động được (CoreSimulatorService treo khi boot từ 17/11 20:45) ⇒ UI test, ảnh iPhone/iPad, đầu
dò ảnh bàn: **NOT RUN**. Mọi giao diện mới: chưa xác minh trên thiết bị.

| Mốc | Kết quả | Bằng chứng |
|---|---|---|
| M1 Sảnh mới | **PASS** (build-for-testing) · UI test NOT RUN | `BankLab/UI/Lobby046.swift`: thẻ "Tiếp tục" (bài/trận gần nhất, lần đầu "Cú đầu tiên", đang có trận "Trận đang chơi") đứng đầu; 4 ô Tập tự do · Bài tập · Đấu (máy / Chơi gần / Wi‑Fi / Online) · Thư viện bàn‑cơ; các mục cũ (nhật ký, cú đã lưu, tài khoản, Tuỳ chỉnh, Hướng dẫn, Phòng thử) thành chip. `.overFullScreen` trên nền mờ của bàn 3D thật (không scene thứ hai); khi Sảnh đóng gọi hướng dẫn + Game Center (viewDidAppear không chạy lại). Mở app → Sảnh → 1 chạm "Tiếp tục"/"Tập tự do" → bàn (≤ 2 chạm). Test `testLobbyContinueReachesTableInTwoTaps` đã viết |
| M2 HUD + menu | **PASS** (build) · UI test NOT RUN · **lệch đề có chủ đích** | Cột phải: Xem lại · Lùi cú/Call · Camera · **Bàn** (UIMenu: Đặt bi · Thêm bi · Bao cơ). Đề bảo gom cả Camera vào "Bàn", nhưng làm vậy thì đổi camera 1 → 2 chạm và mất "giữ để nhìn lướt" — trái tiêu chí "không việc nào tăng" ⇒ giữ Camera phím riêng. Bộ chọn cơ chỉ còn icon 3D. Menu trong trận: Tiếp tục · Đổi bàn‑bi‑gậy · Tuỳ chỉnh · Về sảnh (+ "Thêm…" giữ các mục còn lại — không xoá chức năng). "Sao chép số đo" → Tuỳ chỉnh → Máy |
| M2 (phần thêm sau) Phòng thí nghiệm + ngôn ngữ | **PASS** (build) · NOT RUN trên Simulator · **làm trên `cho/native-0.47` @ `26ef784`** | Tuỳ chỉnh → Máy → "Phòng thí nghiệm" (mặc định TẮT) gom chẩn đoán/A-B, ZUPE Lab, thông số vật lý, bộ âm; tắt thì ẩn ở mọi menu. Bộ chọn ngôn ngữ chỉ Việt/Anh; 5 ngôn ngữ dịch máy chỉ khi bật Lab (người đã chọn vẫn giữ) |
| M3 Bàn dựng lại | **Một phần** | 4 họ tham số hoá (Z-Arena chân hộp + ốp kim loại · Z-Heritage chân tiện + gờ chạm · Z-Loft khung chữ A ống thép · Z-Club hai trụ) × 3 phối = 12, dựng bằng mã; id cũ ánh xạ sang họ gần nhất (khoá băm, không còn tên sản phẩm thật); thư viện là lưới ảnh kết xuất 3D. Test C++ 3 cỡ WPA (`TableSizeTests` 55 kiểm tra) **PASS**. Chọn 8/7 ft **chưa mở**: `BLWorld` chưa nhận kích thước, lưới mặt/khung/kim cương/tâm lỗ chỉ có 9 ft — mở nửa vời sẽ lệch hình và vật lý (danh sách việc còn thiếu dưới). Đầu dò ảnh 4 họ (cháy < 2 %): đã viết, **NOT RUN** |

## Trước / sau — chức năng đổi chỗ (M2)
| Chức năng | Trước | Sau |
|---|---|---|
| Đặt bi / Thêm bi / Bao cơ | 3 phím riêng | Nút "Bàn" → mục tương ứng |
| Camera (chạm đổi góc, giữ nhìn lướt) | Phím Camera | Giữ nguyên phím Camera |
| Xem lại · Lùi cú · Call | Cột phím | Giữ nguyên |
| Tập tự do · Bài tập · Kick | Thẻ Luyện tập | Ô Tập tự do, ô Bài tập |
| Đấu máy / hai người / Wi‑Fi / Online | Thẻ Thi đấu | Ô Đấu |
| Nhật ký · Cú đã lưu · Tài khoản · Tuỳ chỉnh · Hướng dẫn · Phòng thử | Thẻ Hồ sơ + footer | Chip cuối Sảnh |
| Thư viện bàn‑cơ | Menu trận | Ô Sảnh + Menu trận "Đổi bàn‑bi‑gậy" |
| Lưu cú, xuất MP4, nỉ, màu nỉ, không gian, tay trái, hình ảnh, âm thanh, hướng dẫn | Menu trận | Menu trận → Thêm… |
| Sao chép số đo cú | Menu trận | Tuỳ chỉnh → Máy |

Số chạm 5 việc chính (trước → sau): đánh cú = · xem lại 1 → 1 · lùi cú 1 → 1 · đổi cơ 1 → 1 · đổi camera 1 → 1. (Đặt bi / thêm bi / bao cơ: 1 → 2 — không thuộc 5 việc chính, do gom vào "Bàn" theo đề.)

## Ánh xạ bàn cũ → họ/phối (M3)
| Mới | Id cũ |
|---|---|
| arena-1 Graphite (mặc định) | zmax, ox, acurra, tournament |
| arena-2 Tour Blue | apex, blackwolf, blackwolfpro, smart |
| arena-3 Ice | arc, victory |
| heritage-1 Walnut | allenton, gc6, champion |
| heritage-2 Wine · heritage-3 Teal | glenwood · gc7 |
| loft-1 Maple · loft-2 Ash · loft-3 Sage | canton · sanibel · botanic |
| club-1 Green | professional, oakland, zbaroak |
| club-2 Blue · club-3 Red | proam, zbarpro · zbar |

Còn thiếu để mở 8/7 ft: setter cỡ bàn cho `BLWorld` → `Config` + dựng lại băng/lỗ; lưới bed/deck/trim theo cỡ; kim cương + tâm lỗ
theo cỡ; khung/chân/camera theo cỡ; test cú thẳng/phản xạ qua `BLWorld`.

Lưu ý cho anh: ốp góc kim loại của Z-Arena làm theo đề, nhưng 0.39 anh từng dặn "thân bàn không có kim loại sáng" — cần xem ảnh để chốt.

## Cổng chạy được (không cần Simulator)
| Bước | Kết quả |
|---|---|
| assets | PASS |
| portable-regressions | **FAIL** — chỉ `OpponentTests`: "Pro leaves clearly better position than the Amateur" (Pro 0,313–0,314 so với Amateur 0,273). Phân loại: phụ thuộc hạn giờ thật (`Deadline`, `<chrono>`) của bộ lập kế hoạch AI: Core và test **không đổi** từ 0.45 (cùng mã đã PASS lúc 22:35), lần chạy này máy tải 2,6–3,5. Không đổi tiêu chí; cần chạy lại trên máy rảnh / CI. 32 bộ còn lại PASS (gồm TableSize 55) |
| replay-recording | PASS (ReplayRecording 13, FramePacer 983) |
| lan-wire-protocol | PASS |
| simulator-build / build-for-testing | PASS (sau sửa review) |
| i18n vi+en | PASS (664/664) |
| screenshots / ui-gesture-tests / đầu dò bàn | NOT RUN (Simulator) |
| unsigned-iphone-build | PASS — `dist/ZokerPoolTrainer-0.46-Build27.ipa` 81 MB, SHA-256 `298f9fb07b874bd9…` (dựng ở `ba796fc`, TRƯỚC các sửa review; bản sau sửa đã build Simulator PASS) |

## Review giám khảo 0.46 (opus) — không lỗi chặn build; đã sửa
| Mức | Phát hiện | Xử lý |
|---|---|---|
| Cao | Chân Z-Heritage lơ lửng 6,5 cm (lệnh dựng đoạn côn nằm sau `//`) | Sửa; tăng phiên bản icon `046b` để bỏ icon cũ trong Caches |
| TB | "Tiếp tục" bỏ qua điều kiện bận (đang cú/xem lại) | Thêm guard; `startComputerMatch` không cấu hình dở khi `startMatch` thoát |
| TB | Sảnh `.overFullScreen` không dừng bàn phía sau (máy đối thủ có thể đánh sau Sảnh) | **Chưa sửa** — cần xác minh bằng XCTest `--computer-qa` khi có Simulator |
| Thấp | VoiceOver/XCUITest chạm được HUD sau Sảnh | `accessibilityViewIsModal` |
| Thấp | "Hủy đặt bi" trong menu Bàn không theo trạng thái khoá | Theo `quickPlace.isEnabled` |
| Thấp | Xác nhận "đã sao chép" bị Tuỳ chỉnh che; icon 12 bàn dựng trên luồng chính lần đầu; helper UITest chạm giữa bàn | Chưa sửa (ghi lại) |

## Lỗi chặn CI 158 (review 18/11 00:29) — đã sửa
`testFirstLaunchTutorialFromLobbyAimThenStroke` hỏng trên CI 158: thấy `hint-replay` thay vì nhịp 2. Nguyên nhân: cờ QA tự bắn cú 1,5 s
sau khi nhịp 2 hiện; runner chậm thấy trạng thái đã sang `potted`/`hint-replay` giữa hai lần hỏi (người chơi thật không tự bắn nên
vẫn thấy nhịp 2). Sửa (`6a21e7a` trên 0.45, cherry-pick sang 0.46 `bc04ca5`, 0.47 `27ad021`): gợi ý theo ngữ cảnh không bao giờ hiện
khi hướng dẫn 2 nhịp chưa xong; app ghi lịch sử trạng thái (`tutLog`); test kiểm thứ tự `aim → stroke → potted/retry` và không có
gợi ý giữa nhịp 1 và nhịp 2. Build-for-testing PASS cả 3 nhánh. Chạy test trên Mac: **không tin cậy** — Simulator tự lên lại lúc
~02:30 nhưng quá tải (1 lần chạy 70 phút, kẹt ở bước ngắm), rồi treo khi cài app. ⇒ **NOT RUN** đúng nghĩa; cần CI hoặc Mac khởi
động lại. `accept_local.sh` đầy đủ cho 0.45: **NOT RUN** vì cùng lý do.
