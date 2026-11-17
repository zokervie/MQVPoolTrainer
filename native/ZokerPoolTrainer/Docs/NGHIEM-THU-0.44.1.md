# Nghiệm thu 0.44.1 "Ấn tượng đầu" (17/11/2026)

Nhánh `cho/native-0.44.1` (từ `origin/cho/native-0.44-mm` @ `442e0a3`). Máy: MacBook, Xcode 26.3, Simulator iOS 26.3.
Không push `ci/*`, không sửa `.github/workflows`, không commit 18 file AppIcon. Đề bài: `plan/de-xuat-zoker:docs/de-xuat/NHIEM-VU-0.44.1.md`.

**Chặn lớn trong phiên:** khoảng 20:45, CoreSimulatorService ngừng trả lời lệnh boot (mọi máy ảo, kể cả sau khi diệt dịch vụ và các
tiến trình SimMetalHost). Mọi kiểm tra cần Simulator sau thời điểm đó là **NOT RUN**. Có thể cần khởi động lại Mac.

## Commit
| Commit | Nội dung |
|---|---|
| `1a4ecaa` | M1: Chơi gần, Cú đầu tiên, đổi tên bàn/cơ, 0.44.1 (25), test camera, `%lld`, 3 vai subagent |
| `02950d1` | M2: tranh trên tường |
| `aa4e65d` | M3: cây cơ |
| `040c832` | M1 bổ sung 1: 60 Hz mặc định, tự về 60 Hz, chẩn đoán ghi tần số lúc đánh |
| `1373bc7` | M1 bổ sung 2: ngôn ngữ theo máy, chẩn đoán mở thẳng, sao chép số đo, nút một dòng, Coach kính mờ |
| `cc598a4` | M4 hướng dẫn mới + M5 intro mới |

## Kết quả từng mốc
| Mốc | Kết quả | Bằng chứng |
|---|---|---|
| M1.1 Chơi gần | **PASS** (logic) · chưa xác minh trên thiết bị | `NearbyLobbyTests` 68 kiểm tra (17 mới: nhận lại P2 khi nối lại/bỏ cuộc/nối lại tay, từ chối P3; câu hỏi không hiện được không ghi `declined`; 2 lần từ chối liên tiếp → "Chủ phòng đã từ chối"). Hook do TrainingController giữ, `leave()` xoá hook, hỏi và "Nhập mã 6 số" present từ view controller trên cùng; `_zt-pool18._udp`; bỏ công tắc "Sẵn sàng" (Bắt đầu sáng khi đã nối). Hai máy thật: NOT RUN |
| M1.2 Cú đầu tiên | **PASS** | `Tests/FirstShotTests.cpp` (đăng ký CMake + Run-All-Checks): 566 kiểm tra, 33 tốc độ 0,8–4,0 m/s × 17 sai số ngắm ±0,8°, bi 1 luôn vào lỗ góc, bi cái không rơi. Thế: thẳng theo đường chéo 45°, bi 1 cách lỗ 0,40 m, bi cái cách bi 1 0,22 m, chạm dưới tâm 15 % (GIẢ ĐỊNH, chọn bằng quét bộ giải) |
| M1.3 Đổi tên bàn/cơ | **PASS** | 24 bàn một tên `Z-…`, bỏ `source` (danh sách cũ ở `Docs/NGUON-MAU-BAN-CO.md`), `id` giữ nguyên; 22 cơ bỏ mã 2 chữ, tên riêng (Ignite, Star, Nordic…; 9 cơ "base" từng mang tên sản phẩm thật cũng đổi). `git grep` trong `BankLab/` không còn tên cũ / `source:"http` |
| M1.4 Số phiên bản | **PASS** | `MARKETING_VERSION 0.44.1`, `CURRENT_PROJECT_VERSION 25` |
| M1.5 Test camera | **PASS** | `testLiveShotKeepsAimViewAndManualZoomAfterBallsStop` khẳng định thiết kế 0.36 (yaw 0 sau bi cái, zoom của cú), cử chỉ chỉ khi bi còn chạy → UI 19/19 rồi 21/21 PASS |
| M1.6 Ba vai subagent | **PASS** | `.claude/agents/giam-khao.md`, `ky-su-giao-dien.md`, `kiem-ke.md` (gốc repo) |
| M1.7 Chuỗi định dạng | **PASS** | 32 chỗ `%d`/`%02d` → `%lld` (15 dòng, đã kiểm kiểu Int); `git grep` không còn `%d` trong Swift |
| M1 bổ sung 1 · 60/120 Hz | **PASS** (Simulator) · chưa xác minh trên thiết bị | Mặc định 60 Hz (đã vậy khi chưa lưu, giữ lựa chọn đã lưu). `BLShouldDropTo60Hz` (C++ test trong PresentationPolicyTests, 42 kịch bản): 120 Hz và > 10 % khung trễ (tối thiểu 20 khung, GIẢ ĐỊNH) → lưu 60 Hz, báo "Đã chuyển 60 Hz cho mượt". Bảng chẩn đoán + perf-qa ghi `frameRate` lúc đánh (perf-qa: `"frameRate":60`). Simulator không chạy 120 Hz nên tự hạ chưa thấy thật |
| M1 bổ sung 2 · ngôn ngữ | **PASS** | `L10nDefault` (11 kiểm tra Foundation trong `run_lan_checks.sh`): ngôn ngữ máy nếu hỗ trợ, không thì `vi`. UI test `testFreshInstallFollowsDeviceLanguageAndCoachIsVietnamese`: cài mới máy tiếng Việt → `lang=vi`, mọi chuỗi trong khung Coach có dấu tiếng Việt; máy tiếng Anh → `en` |
| M1 bổ sung 2 · chẩn đoán | **PASS** (build + UI 20/20) | Tuỳ chỉnh → "Chẩn đoán độ mượt" mở thẳng bảng số đo; Menu → "Sao chép số đo cú vừa đánh" |
| M1 bổ sung 2 · 3 nút | **PASS** (ảnh) | Nút số / Chỉ dẫn·Điểm ngắm / Chấm cú: một dòng, tự co cỡ chữ theo bề rộng (≥ 70 %), "Chấm cú" 60 pt. Ảnh: `Docs/Evidence/0.44.1/M1b-coach-kinh-mo.jpg` |
| M1 bổ sung 2 · khung Coach | **PASS** (ảnh) | `GlassPill` (kính mờ, viền vàng mảnh, chữ trắng đậm), dùng chung với M4 |
| M2 Tranh trên tường | **PASS** | Đầu dò `Tools/run_wall_photo_qa.sh` (51 ảnh / 10 phòng). Trước: **0/51** (cháy 26–59 %, Thi đấu thì tối 0,18). Sau: **51/51** (cháy ≤ 0,01 %, sáng TB 0,45–0,51, tương phản 66–86 % ảnh gốc). Bỏ đèn spot; vật liệu constant + tự sáng 1,5; in chuẩn hoá theo từng ảnh (GIẢ ĐỊNH, chỉnh bằng đầu dò); dải +15 %/−10 %; quầng ấm ≤ 20 % trên khung. Ảnh 10 phòng: `M2-tranh-truoc-sau.jpg` |
| M3 Cây cơ | **PASS** (ảnh + UI 19/19) | Một lưới xoay tròn (`CueModel0441`), texture sinh bằng `Tools/gen_cue_textures.py` (14 bộ, 688 KB, tất định), cull mặt sau + single-layer: cơ mờ ở 5°/42°/70° không còn đĩa/mặt nối; icon 4 phím + bao cơ kết xuất từ 3D @3x. Ảnh: `M3-co-truoc.jpg`, `M3-co-sau.jpg`, `M3-icon-bao-co-*.png` |
| M4 Hướng dẫn mới | **PASS** (Simulator) · cử chỉ ra cơ chưa xác minh trên thiết bị | UI test `testFirstLaunchTutorialFromLobbyAimThenStroke`: Sảnh thật (`--keep-lobby-qa`) → "Tập tự do" → nhịp 1 trong 2 s → kéo ngắm tới < 1° → nhịp 2 → cú → "Vào rồi!"/"Thử lại nhé". Viên chữ ≤ 36 pt, không view phủ kín. Số chạm bắt buộc trước cú đầu: 0 (ngoài nút Sảnh). Bước ra cơ trong test do app bắn (`--tutorial-stroke-qa`): XCUITest không giữ B + vuốt ngón thứ hai được. Toàn bộ UI 21/21 PASS. Ảnh: `M4-nhip1-sau.jpg` |
| M5 Intro mới | **Một phần** (xem dưới) | |
| M6 Nghiệm thu | xem dưới | |

## M5 — nguyên nhân màn hình đen của intro cũ (đo trước khi viết mã mới)
Ảnh màn hình thật (simctl) intro cũ `--old-intro-qa`, độ sáng trung bình:

| Thời điểm sau khởi chạy | 0,5 s | 1 s | 2 s | 3 s | 4,5 s | 6 s | 10 s | 16 s |
|---|---|---|---|---|---|---|---|---|
| Hậu kỳ bật (HDR, bloom, DOF, motion blur, viền màu) | 0,001 | 0,000 | 0,000 | 0,000 | 0,000 | 0,000 | 0,031 | 0,346 |
| Hậu kỳ tắt (`-oldIntroNoPost YES`) | 0,001 | 0,000 | 0,000 | 0,000 | 0,000 | — | — | — |

Kết luận: **không phải hậu kỳ** (tắt hết vẫn đen). Lần mở sau khi cài, cả app chưa đưa khung nào ra màn hình trong khoảng 10 s
(dựng scene, biên dịch shader nguội), `UILaunchScreen` để trống nên hệ thống hiện màn hình đen; intro cũ chạy theo đồng hồ
`asyncAfter` tính từ lúc khởi chạy (5,55 s) nên đã kết thúc trước khi khung đầu tiên lên màn hình. Thêm nữa `viewDidAppear` mở
Sảnh toàn màn hình ngay, đè lên intro. Trên máy thật thời gian khởi động nguội ngắn hơn nhưng cùng cơ chế: chưa xác minh trên thiết bị.

Sửa: `UILaunchScreen` có logo trên nền tối (không bao giờ đen khi khởi động); intro mới quay ngay trên bàn chơi (cùng `SCNView`),
đồng hồ intro dừng khi luồng chính bị khựng (> 0,1 s), Sảnh chỉ mở sau khi intro xong/bỏ qua.

| Hạng mục M5 | Kết quả |
|---|---|
| Cú phá thật + test C++ viết trước | **PASS** — `Tools/find_intro_break.cpp` → `BankLab/UI/IntroBreak.h`; `Tests/IntroBreakTests.cpp`: tái mô phỏng ra đúng sự kiện lọt lỗ (bi 8, lỗ góc 5, 1,000 s, lệch < 1 ms), tất định, bi cái không rơi, rơi ở 2,975 s trên dòng thời gian intro |
| Âm thanh | **PASS** — `Tools/gen_intro_audio.py`: lớp tổng hợp riêng từng file (gió, trầm, nhạc hiệu) + mẫu thật trong app chồng nhiều cao độ; bản đầy đủ −16,00 LUFS, đỉnh −2,13 dBFS; bản ngắn −16,00 LUFS, đỉnh −3,55 dBFS. Nghe thật: chưa xác minh trên thiết bị |
| ShotFX, logo 2D, dự phòng, chạm bỏ qua | Đã viết, build PASS; chạy thật: xem dòng dưới |
| Đầu dò `--intro-qa` (0,5 · 1 · 2 · 3 · 4,5 s) | **FAIL ở lần chạy được duy nhất** (trước khi sửa lớp bật đèn): 0,5 s = 0,031 (dưới 0,08); 1 s 0,354 · 2 s 0,405 · 3 s 0,443 · 4,5 s 0,323 (đạt). Sau đó sửa: đèn bật từ 50 %, đồng hồ chống khựng, ghi summary lúc kết thúc → **NOT RUN** (Simulator treo) |
| Crash âm thanh | Tìm thấy và sửa: `AVAudioPlayerNode.play(at:)` ném ngoại lệ ObjC → app thoát. Bản sửa build PASS, chạy lại **NOT RUN** |
| UI test intro → biến mất → Sảnh | Đã viết `testIntroPlaysBeforeLobbyAndTapSkips`; **NOT RUN** |
| Khung ≤ 33 ms trong intro | **NOT RUN** |

## M6 — accept_local.sh (lần chạy 20261117T144137Z, trên `cc598a4`)
| Bước | Kết quả |
|---|---|
| assets | PASS |
| portable-regressions | PASS (gồm FirstShot 566, IntroBreak, PresentationPolicy 42) |
| replay-recording | PASS (FramePacer 983) |
| lan-wire-protocol | PASS (LAN 1.256, Nearby 68, ngôn ngữ 11) |
| simulator-build | PASS |
| screenshots-and-runtime-probes | **NOT RUN / BLOCKED**: Simulator không khởi động được (CoreSimulatorService treo khi boot); đã dừng bước này sau khi log trống |
| ui-gesture-tests | **NOT RUN** trong script (Simulator). Trước khi Simulator treo: 21/21 PASS (sau M4); test intro M5 chưa chạy |
| unsigned-iphone-build | Chạy riêng `Build-Unsigned-IPA.command` sau các sửa của review: **BUILD SUCCEEDED**, `dist/ZokerPoolTrainer-0.44.1-Build25.ipa` 84,2 MB, SHA-256 `38c552807b8e4368…`, chưa ký |

Tổng: **chưa đủ PASS** (2 bước cần Simulator bị chặn). Không đổi tiêu chí.

## Review độc lập (vai giam-khao, opus) — đã sửa
| Mức | Phát hiện | Xử lý |
|---|---|---|
| Cao | Sheet đăng nhập Game Center bật trong intro → `openLobby()` thoát im, không Sảnh, không hướng dẫn | Đăng nhập Game Center chỉ sau khi đã ở bàn (sau intro + Sảnh); `lobbyShown` chỉ đặt khi Sảnh thật sự hiện |
| TB | Đánh khi đang ở nhịp 1 làm hướng dẫn hỏng | Cú ở bất kỳ nhịp nào cũng kết thúc nhịp như nhịp 2 |
| TB | "Thử lại nhé" kẹt khi xem lại tự động lâu | Chờ tới ~30 s rồi tắt sạch |
| TB | Khách báo "Chủ phòng đã từ chối" khi chủ chưa hề hỏi | Chỉ đếm với phòng chọn từ danh sách Nearby (phòng nhập mã không đếm) |
| TB | Hộp Nhận/Từ chối chết còn trên màn hình | Tự đóng sau 14 s (phiên bỏ sau 15 s) |
| Thấp | Chạm lúc intro mờ dần rơi xuống cử chỉ bàn | Tắt tương tác `scn` trong intro |
| Thấp | Ngôn ngữ mặc định tính lại mỗi lần dịch chữ | Tính một lần mỗi lần mở app |
| Thấp | Đua luồng `renderedFrames` | Đọc/ghi trong khoá |
| Thấp | Layout giữa intro có thể hiện lại vài phím | **Chưa sửa** (cần xác minh khi có Simulator) |

Sau khi sửa: build PASS, LAN/Nearby PASS; UI test **NOT RUN** (Simulator).

## Cần máy thật / cần anh
- Cài IPA: xem intro lần đầu (sau khi cài) và lần sau; nghe tiếng; chạm bỏ qua.
- Hướng dẫn: giữ B + vuốt thật trên máy.
- 120 Hz: một cú trễ > 10 % khung có tự về 60 Hz và báo một dòng không.
- 2 máy: Chơi gần (nối lại sau rớt, từ chối).
- Ảnh tường có người thật: cần văn bản đồng ý hoặc thay ảnh trước khi phát hành (việc của anh).
- Còn chờ từ trước: video 240 fps, giấy phép 4 file âm thanh, tài khoản Developer.
