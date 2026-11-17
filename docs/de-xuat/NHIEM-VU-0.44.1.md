# Nhiệm vụ 0.44.1 — "Ấn tượng đầu"

Giao cho: phiên Claude Code trên Mac. Soạn và review độc lập: phiên đám mây. Chủ dự án chấp thuận ngày 17/11/2026 lúc 10:20.

## 1. Mục tiêu

Người mới mở app lần đầu thấy một intro có hình và có tiếng, vào bàn, được chỉ bằng hình cách ngắm và ra cơ, và đánh vào lỗ cú đầu tiên trong 30 giây. Bản này sửa những gì chủ dự án thấy hỏng trên máy thật ở IPA 156 và những lỗi review độc lập tìm ra.

Phản hồi của chủ dự án (17/11, trên máy thật):
- "Intro không thấy gì… làm lại mới, phải có VFX và SFX sinh động hơn như những game hàng đầu về bida."
- "Hướng dẫn phân bổ không hợp lý, hơi rườm rà… đồ hoạ trực quan, có thể để chữ hướng dẫn, đừng dùng khung đen."
- "Các bức ảnh trên tường không thấy gì."
- "Icon, hình dáng và design của cơ đánh nhìn quá rẻ tiền… cơ khi mờ có khấc tròn ở khớp nối, lộ lỗi design."

## 2. Không làm trong bản này

- Thanh lực, Bài hôm nay, chuỗi ngày, màn tiến bộ (để 0.45).
- Hiệu ứng mới trong lúc chơi thường. Bộ hiệu ứng viết cho intro phải dùng lại được ở 0.45, nhưng bản này chưa bật khi chơi.
- Privacy manifest, entitlements, StoreKit, đổi tên file mang số phiên bản (để sau nghiệm thu).
- Không đổi lõi vật lý, lớp truyền mạng, `LANShotStart`, `.github/workflows`.
- Không thêm thư viện ngoài, không tải tài nguyên từ mạng, không dùng tên hay logo hãng thật.
- Không xoá chức năng đang chạy để giao diện gọn hơn.

## 3. Quy tắc chung

- Nhánh mới `cho/native-0.44.1` tạo từ `origin/cho/native-0.44-mm`. Commit riêng từng mốc. Đẩy lên `origin cho/native-0.44.1`. Không push `ci/*`. Không commit 18 file AppIcon do bước `assets` sinh ra.
- Logic và vật lý: viết test trước. Bộ test C++ mới phải đăng ký ở cả `CMakeLists.txt` (ZOKER_TEST_SUITES) và `Run-All-Checks.command`.
- Mỗi hệ số mới ghi nguồn: đã công bố / đã đo / giả định.
- Mục hình ảnh: chụp ảnh "phòng chuẩn" trước và sau, đưa vào báo cáo.
- Đường dẫn dưới đây tính từ `native/ZokerPoolTrainer/`.
- Làm theo đúng thứ tự mốc. Hết mỗi mốc thì chạy kiểm tra của mốc đó rồi mới sang mốc sau.

## 4. Các mốc

### M1 — Sửa nhỏ, chắc

**1.1 Chơi gần (review độc lập 17/11).** Viết test trước trong `Tests/NearbyLobbyTests.swift`.
- LỖI CHẶN: chủ phòng từ chối chính máy khách khi nối lại. `NearbyLobby.invitation(from:)` (`BankLab/Network/NearbyLobby.swift:94-96`) trả `.rejectBusy` cho mọi lời mời khi phase là `.connected` hoặc `.reconnecting`, nên `BankLab/Network/LocalMatchSession.swift:882-899` gọi `invitationHandler(false, nil)`. Sửa: nhớ tên người đã được nhận; lời mời của người đó khi phase là `.connected`, `.reconnecting` hoặc `.failed(.reconnectTimedOut)` được nhận ngay, không hỏi lại; người lạ vẫn bị từ chối. Test: nhận P2 → linkUp → linkDown → lời mời từ P2 được nhận, từ P3 bị từ chối; sau giveUp rồi manualReconnect vẫn nhận P2.
- LỖI CHẶN: hook `askInvitation` sống lâu hơn màn hình (`BankLab/UI/NearbyLobby044mm.swift:68,82,101`). Đóng sheet khi đang làm chủ phòng thì hook trả `false` và người mời bị ghi vào `declined` (`NearbyLobby.swift:107`). Rời trận bằng menu thường (`leaveMatch()`) không xoá hook, nên phòng Wi‑Fi tạo bằng mã sau đó cũng tự từ chối khách. Sửa: `LocalMatchSession.leave()` xoá `askInvitation`; câu hỏi Nhận/Từ chối hiện được cả khi sheet đã đóng (hook do TrainingController giữ, present từ view controller trên cùng); khi không hiện được câu hỏi thì từ chối lần mời đó nhưng KHÔNG ghi vào `declined`.
- Nút "Nhập mã 6 số" (`NearbyLobby044mm.swift:36`) gọi `joinMatchRoom()`, hàm này present từ TrainingController đang present sheet (`BankLab/UI/MatchPlayController.swift:361`) nên hộp nhập không hiện. Sửa: present từ view controller trên cùng.
- Máy khách không bao giờ thấy "Chủ phòng đã từ chối": `rejectedByHost()` (`NearbyLobby.swift:111`) không ai gọi. Sửa: lời mời bị từ chối 2 lần liên tiếp thì dừng mời, hiện `NearbyFailure.rejected`, cho chọn phòng khác.
- `BankLab/Info.plist`: thêm `_zt-pool18._udp` vào `NSBonjourServices`.
- Bỏ công tắc "Sẵn sàng" nếu nó vẫn chỉ có tác dụng trên một máy (thao tác thừa); nút "Bắt đầu" sáng khi đã nối.

**1.2 Cú mở đầu thẳng, dễ.** Hiện `Drill.startup = 3` (`BankLab/UI/Models.swift:162`) là bài kick 1 băng cấp 2, và "Tập tự do" ở Sảnh chỉ đóng menu nên người mới rơi vào bài đó. Thêm một thế "Cú đầu tiên" và cho `Drill.startup` trỏ vào nó:
- Bi cái, bi mục tiêu và một lỗ góc thẳng hàng (góc cắt dưới 0,5°). Gợi ý khoảng cách: bi cái cách bi mục tiêu 0,20–0,30 m; bi mục tiêu cách lỗ 0,30–0,60 m. Được phép đặt điểm chạm mặc định của thế này hơi dưới tâm để bi cái không lăn theo vào lỗ. Người thi công chọn số cụ thể sao cho test dưới đây qua.
- Test C++ viết trước: quét tốc độ 0,8–4,0 m/s và sai số ngắm ±0,8° với điểm chạm mặc định của thế; ở mọi trường hợp bi mục tiêu vào lỗ và bi cái không rơi lỗ.

**1.3 Đổi tên mẫu bàn và cơ (rủi ro kiểm duyệt: tên sản phẩm thật).** `BankLab/UI/EquipmentLibrary.swift:14-33` có 20 mẫu bàn mang tên sản phẩm thật, mã hãng viết tắt (`Z-Pr`, `Z-Br`, `Z-Di`, `Z-Ra`, `Z-Ol`) và trường `source` chứa link hãng. Sửa:
- Xoá trường `source` khỏi bản phát hành (giữ link trong `Docs/` nếu cần tra cứu).
- Bỏ mã hãng; một dòng tên duy nhất dạng `Z-…`. Tên tạm (chủ dự án sửa sau được): apex → Z-Onyx Pro · arc → Z-Onyx Wave · gc7 → Z-Regent 7 · gc6 → Z-Regent 6 · blackwolf → Z-Night · blackwolfpro → Z-Night Pro · allenton → Z-Manor · glenwood → Z-Lodge · oakland → Z-Oak II · sanibel → Z-Coast · canton → Z-Loft · botanic → Z-Garden · proam → Z-Arena · professional → Z-Arena Classic · smart → Z-Arena Lite · ox → Z-Titan · victory → Z-Vanguard II · acurra → Z-Vector · tournament → Z-Tour Pro · champion → Z-Grand III.
- Giữ nguyên `id` để cài đặt đã lưu không mất. Chữ in trên thân bàn (ví dụ "Z-BR / Crown VII") đổi theo.
- Cơ: bỏ mã hai chữ gợi tên hãng (`Z-Mc`, `Z-Cu`, `Z-Vk`…) trên phím và trong bao cơ; dùng tên riêng ngắn (Ignite, Star, Nordic…).
- Kiểm tra: `git grep` trong `BankLab/` không còn các tên cũ và không còn `source:"http`.

**1.4 Số phiên bản.** `MARKETING_VERSION = 0.44.1`, `CURRENT_PROJECT_VERSION = 25` (`ZokerPoolTrainer.xcodeproj/project.pbxproj:111-112`).

**1.5 Test camera.** Giữ thiết kế 0.36 (camera về sau bi cái khi bi dừng). Sửa `UITests/InteractionTests.swift:295` (`testLiveShotKeepsAimViewAndManualZoomAfterBallsStop`) để khẳng định đúng thiết kế đó và không phụ thuộc thời điểm bi dừng.

**1.6 Ba vai subagent** trong `.claude/agents/` ở gốc repo (chỉ file cấu hình):
- `giam-khao.md`: model opus, effort high, tools Read, Grep, Glob, Bash. Review độc lập một diff, tìm lỗi hành vi và lỗi lần mở app đầu tiên; không sửa file.
- `ky-su-giao-dien.md`: model sonnet. Màn hình, chuỗi dịch, test cử chỉ; không đụng `BankLab/Core`.
- `kiem-ke.md`: model haiku, tools Read, Grep, Glob, Bash. Đếm, đối chiếu danh sách, đọc log; không kết luận, không sửa.

**1.7 Chuỗi định dạng.** iOS 26 ghi lỗi khi `%d` nhận `Int` của Swift. Còn 16 chỗ `String(format:)` dùng `%d` trong `BankLab/`; đổi sang `%lld` (hoặc nội suy chuỗi). Nội dung hiển thị giữ nguyên.

### M2 — Tranh trên tường phải thấy rõ

Nguyên nhân: mỗi ảnh được chiếu bằng một đèn spot thật 260 lumen đặt cách tường 16 cm và cách mép trên ảnh khoảng 20 cm (`BankLab/Rendering/Rooms042.swift:98-102`), trong khi ảnh chỉ tự sáng 6 % (`Rooms042.swift:74`). Ở cự ly đó vùng giữa ảnh cháy trắng.

Sửa:
- Bỏ đèn spot thật của từng ảnh. Ảnh tự sáng ở mức kiểm soát được (vật liệu không phụ thuộc đèn phòng, hoặc emission 0,55–0,70).
- "Đèn tranh" là hiệu ứng vẽ: nhân vào ảnh một dải chuyển dọc nhẹ (trên sáng hơn tối đa 15 %, dưới tối hơn tối đa 10 %) và một quầng ấm mờ trên tường phía trên khung (không đè lên ảnh, độ đậm tối đa 20 %). Giữ thân đèn đồng.
- Đầu dò tự động: với mỗi phòng có ảnh, đo vùng ảnh trong ảnh chụp: điểm ảnh cháy (độ sáng trên 0,95) dưới 2 %; độ sáng trung bình 0,35–0,65; độ tương phản không dưới 60 % của ảnh gốc.
- Ảnh trước/sau của cả 10 phòng trong báo cáo.

### M3 — Cây cơ

Nguyên nhân cơ mờ lộ khớp: `updateCueFade` đặt `cueRoot.opacity` (`BankLab/Rendering/TableScene.swift:2047-2082`) lên một mô hình ghép nhiều phần, nên các mặt bên trong và mặt nối hiện ra. Nguyên nhân icon xấu: `iconImage` vẽ tay ở cỡ 44×12 pt (`BankLab/UI/EquipmentLibrary.swift:84`).

Sửa:
- Mô hình cơ mới là MỘT lưới xoay tròn từ biên dạng, không có mặt bên trong: đầu cơ 12,75 mm, ferrule 25 mm, ngọn thuôn đều tới khớp 21 mm, cán 31 mm, vòng khớp kim loại, phần quấn tay, đuôi cao su. Dài 1,47 m (cơ jump 1,044 m như mô hình khoảng hở đang giả định; không đổi lõi).
- Vật liệu: gỗ có lớp sơn bóng (clear coat), vân gỗ và hoa văn khảm sinh bằng script trong `Tools/` (không dùng ảnh ngoài), vòng kim loại, quấn tay có vân. 10 mẫu hiện có giữ màu và hoa văn riêng.
- Cơ mờ chỉ vẽ một lớp: loại mặt sau, `transparencyMode = .singleLayer` hoặc kỹ thuật ghi chiều sâu trước. Ảnh kiểm ở góc ngắm với độ dốc 5°, 42°, 70°: không còn đĩa tròn hay mặt nối.
- Icon trên bốn phím cơ và trong bao cơ kết xuất từ chính mô hình 3D (SCNRenderer ngoài màn hình, @3x, lưu đệm), phông trong suốt. Bỏ hình vẽ tay.
- Ảnh trước/sau: cơ rõ, cơ mờ, bốn phím cơ.

### M4 — Hướng dẫn mới

Hiện tại (`BankLab/UI/Tutorial044.swift`): 15 màn, lớp phủ tối 62 %, khung chữ nền gần đen rộng tới 340 pt, bắt đổi điểm chạm và độ dốc cơ trước khi được đánh cú đầu. Ngoài ra `maybeStartTutorial()` chỉ gọi một lần trong `viewDidAppear` (`BankLab/UI/TrainingController.swift:600`) rồi hẹn 1–6,2 s; lúc đó Sảnh đang phủ toàn màn hình nên `startTutorial()` thoát ở `view.window != nil` (`Tutorial044.swift:143`).

Thiết kế mới:
- Không phủ tối toàn màn hình. Không khung đen. Chú thích là chữ trắng 17 pt đậm trên một viên nền kính mờ (blur) mỏng, viền vàng mảnh, cao tối đa 36 pt, tối đa 6 từ.
- Dạy bằng hình: bàn tay mờ diễn lại cử chỉ, lặp cho tới khi người chơi làm theo. Phím cần bấm chỉ có vòng vàng nhấp nháy.
- Không chặn thao tác; không có nút "Tiếp".
- Lần đầu chỉ có hai nhịp trên thế "Cú đầu tiên":
  1. "Kéo để ngắm vào chấm vàng": hướng ngắm ban đầu cố ý lệch 12–18°; hiện điểm ngắm của Coach trên bi mục tiêu; bàn tay kéo ngang trên bàn. Xong khi hướng ngắm cách đường vào lỗ dưới 1°. Điểm ngắm này chỉ hiện trong hai nhịp hướng dẫn, không hiện khi chơi thường.
  2. "Giữ B, vuốt lùi rồi đẩy tới": một ngón giữ B, ngón kia vuốt trên bàn. Xong khi có cú đánh.
- Vào lỗ: chữ "Vào rồi!" kèm tiếng lọt lỗ và rung. Trượt: "Thử lại nhé" và tự đưa bi về chỗ cũ.
- Sau đó là gợi ý theo ngữ cảnh, mỗi gợi ý chỉ hiện một lần, tối đa một gợi ý mỗi cú, tự tắt sau 6 giây: "Xem lại cú này" (sau cú đầu), "Đánh lại từ đây" (sau lần trượt đầu), "Kéo để chọn điểm chạm" (sau 3 cú), "Kéo để nâng đuôi cơ" (khi bi sát băng hoặc vào bài jump, massé).
- Menu → "Hướng dẫn chơi" mở danh sách các gợi ý để xem lại từng cái. Tuỳ chỉnh có công tắc tắt gợi ý.
- Tự bắt đầu khi người chơi vào bàn lần đầu sau khi Sảnh đóng. Chỉ ghi "đã xem" khi người chơi đánh xong cú đầu.
- Dạng dữ liệu: mỗi nhịp là một bản ghi (cử chỉ, chữ, điều kiện xong) để 0.45 đổi nhịp ra cơ sang thanh lực mà không viết lại.

Kiểm tra:
- Test giao diện mở app đi qua Sảnh như người dùng thật (thêm một cờ QA giữ Sảnh, vì hiện mọi cờ QA đều bỏ Sảnh): chọn "Tập tự do" → thấy nhịp 1 trong 2 giây → kéo ngắm → thấy nhịp 2 → ra cơ → thấy "Vào rồi!" hoặc "Thử lại nhé".
- Số lần bấm bắt buộc trước cú đầu: 0. Không có view nào phủ kín màn hình trong lúc hướng dẫn.

### M5 — Intro mới

Nguyên nhân intro cũ không thấy: `IntroOverlay` được gắn thẳng vào cửa sổ (`BankLab/AppDelegate.swift:15`), rồi `viewDidAppear` mở Sảnh ngay bằng `present(.fullScreen)` (`TrainingController.swift:594-607`), nên Sảnh nằm đè lên intro. Thêm nữa, phiên Mac đã báo ảnh `--intro-qa` trên Simulator iOS 26.3 đen hoàn toàn dù không có Sảnh: phải tìm nguyên nhân bằng cách chụp khung ở nhiều thời điểm trước khi viết mã mới, và ghi kết quả vào báo cáo. Intro cũ dùng camera HDR với bloom, làm mờ chuyển động, độ sâu trường ảnh, viền màu (`BankLab/UI/Intro043.swift:126-134`); đây là nghi vấn, chưa chứng minh.

Thiết kế mới: cảnh phim dựng ngay trên bàn chơi thật (cùng `SCNView` và cùng đường kết xuất với lúc chơi, nên chỗ nào chơi được thì intro hiện được).
- Trình tự khởi động: intro chạy xong hoặc bị bỏ qua rồi mới mở Sảnh. Trong lúc intro, giao diện chơi ẩn.
- Cú phá là vật lý thật: một cú phá 9 bi được chọn sẵn bằng công cụ, lưu thành tài nguyên phát lại; có bi rơi lỗ góc trong khoảng 1,8–3,2 s sau cú phá. Test C++ viết trước: mô phỏng lại từ trạng thái đầu phải ra đúng sự kiện lọt lỗ đã lưu (bi, lỗ, thời điểm lệch dưới 1 ms).
- Dựng 6,0 giây cho lần đầu:
  - 0,0–0,6 s: đèn phòng bật dần, camera trượt thấp dọc băng về phía khối bi.
  - 0,6–1,6 s: cơ kéo lùi; tiếng gió dâng.
  - 1,6 s: phá bi. Chớp sáng 2 khung, vòng sóng trên nỉ, bụi phấn ở đầu cơ, camera rung tắt dần trong 0,25 s, quay chậm 0,25× trong 0,5 s, vệt sáng ngắn sau các bi nhanh hơn 3 m/s.
  - 2,2–3,6 s: camera bám bi sắp rơi; bi rơi lỗ có tiếng rơi và tiếng chạm hàm lỗ, tia vàng bật lên từ lỗ.
  - 3,6–5,2 s: camera kéo lên nhìn từ trên; hạt vàng tụ lại thành logo Z và chữ "ZOKER POOL", có vệt sáng quét qua. Phần logo là lớp 2D (Core Animation) đặt trên cảnh 3D.
  - 5,2–6,0 s: logo mờ dần, mở Sảnh.
- Từ lần mở thứ hai: chỉ phần logo 2D, tối đa 1,2 giây.
- Chạm bất kỳ đâu là bỏ qua trong 0,2 giây; tiếng tắt theo; hàm kết thúc chỉ được gọi đúng một lần.
- Dự phòng: nếu cảnh 3D chưa sẵn sàng sau 0,5 s, hoặc máy bật Giảm chuyển động hay Chế độ nguồn điện thấp, chỉ chạy phần logo 2D. Không bao giờ để màn hình đen.
- Không dùng bloom, làm mờ chuyển động, độ sâu trường ảnh trong intro, trừ khi đã chứng minh chạy đúng trên Simulator iOS 26.3 và trên CI.
- Bộ hiệu ứng (`ShotFX`): chớp và vòng sóng, bụi phấn, vệt bi, tia lọt lỗ, rung camera. Mỗi hiệu ứng bật tắt riêng, dùng lại được ở 0.45.
- Âm thanh: lớp thật lấy từ mẫu đã có trong app (`PoolBall0…3`, `PoolCue0`, `PoolRail0`, `PoolPocket0`), chồng nhiều cao độ cho tiếng phá. Lớp tổng hợp (gió dâng, tiếng trầm lúc va, nhạc hiệu logo) do một script trong `Tools/` sinh ra file WAV. Mỗi lớp là một file riêng để sau này thay bằng tiếng chủ dự án tự thu mà không sửa mã. Mức âm của bản trộn: −16 ±1 LUFS, đỉnh không quá −1 dBFS; script tự đo và in ra. Tắt tiếng khi app tắt âm.
- Giữ khoá cài đặt `introEnabled043` để lựa chọn của người dùng không mất.

Kiểm tra:
- Test giao diện mở app bình thường (không cờ bỏ Sảnh): intro hiện và bấm được → intro biến mất → Sảnh mới hiện.
- Đầu dò `--intro-qa`: chụp tại 0,5 · 1,0 · 2,0 · 3,0 · 4,5 s; mỗi ảnh có độ sáng trung bình từ 0,08 trở lên và ít nhất 15 % điểm ảnh sáng hơn 0,10. Chạy trên Simulator iOS 26.3 của Mac.
- Không khung nào dài quá 33 ms trong intro theo `Tools/run_perf_qa.sh` (số đo Simulator; trên máy thật ghi "chưa xác minh trên thiết bị").

### M6 — Nghiệm thu và báo cáo

- Chạy `bash Tools/accept_local.sh`. Giao vai `giam-khao` đọc toàn bộ diff trước khi báo xong; sửa các phát hiện mức cao.
- Viết `Docs/NGHIEM-THU-0.44.1.md`: từng mốc PASS / FAIL / NOT RUN kèm bằng chứng, ảnh trước/sau, nguyên nhân màn hình đen của intro cũ trên iOS 26.3, những gì cần máy thật. Cập nhật `Docs/TRANG-THAI.md`.
- Đẩy `origin cho/native-0.44.1` rồi báo lại. Phiên đám mây sẽ review độc lập và đẩy CI.

## 5. Ràng buộc kỹ thuật

- iOS tối thiểu 16.0; iPhone và iPad, màn ngang. Phải chạy đúng khi dựng bằng Xcode 26 (bản nộp App Store bắt buộc dùng Xcode 26) và bằng Xcode 16.4 của CI hiện tại.
- 60 khung/giây khi chơi; intro và hướng dẫn không được làm chậm cú đánh (đo bằng `Tools/run_perf_qa.sh`).
- Không đổi bố cục giao diện khi bi đang chạy.
- VoiceOver: chú thích hướng dẫn được đọc; intro có nhãn "Bỏ qua".
- Chữ cho người dùng: tiếng Việt và tiếng Anh đầy đủ cho mọi chuỗi mới.

## 6. Câu hỏi mở và mặc định dùng khi không ai trả lời

| Câu hỏi | Mặc định |
|---|---|
| Intro lần đầu dài bao nhiêu | Tối đa 6,0 s, bỏ qua được từ giây 0 |
| Tên mới của 20 mẫu bàn | Danh sách tạm ở mục 1.3 |
| Ảnh tường có người thật trong bản phát hành | Bản thử giữ nguyên; trước khi phát hành cần văn bản đồng ý hoặc thay ảnh (việc của chủ dự án) |
| Hết giờ mà chưa xong M5 | Giao M1–M4 trước, báo rõ M5 còn dở; không rút gọn kiểm tra |
