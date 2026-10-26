# ZOKER POOL TRAINER — MASTER PATCH & WORKFLOW 0.13 → 0.14

**Ngày lập:** 24/10/2026 · **Mục tiêu:** bản vá kế tiếp, tái tổ chức thao tác, camera, vật lý cơ/băng, audio, giáo trình và chế độ hai người chơi trực tuyến.

## 0. Điểm neo dự án được kiểm tra và giới hạn xác minh

- **Repo đúng:** `zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858` (private). Không chuyển source sang `MQVPoolTrainer`, `MQVPoolTrainer-I` hay `Zoker-Pool-Trainer` chỉ vì tên tương tự.
- **Nhánh tham chiếu mới nhất khi kiểm tra:** `main` tại `aba66d0f21e0816973ef0c13281fa98855ca3ff6` (2026-10-24 09:51 UTC; commit cập nhật hồ sơ nghiệm thu).
- **Bản native biên dịch đã được ghi nhận:** `0.12 build 22`, code `2dd1a55e51a55c4e2d0c5d697b79fcdd4df3f1bd`, Codemagic #24 pass Simulator và unsigned iPhone Release theo `Docs/RELEASE-BUILD22.md`. **Đây không đồng nghĩa với nghiệm thu trên iPhone thật.**
- **Kiến trúc:** UIKit/SceneKit (`TrainingController.swift`, `TouchControls.swift`, `TableScene.swift`, `Models.swift`), cầu nối Objective-C++ `BLWorld.mm`, vật lý C++ (`Physics.cpp`, `ElevatedPhysics.cpp`), bài tập hiện có, Codemagic + GitHub Actions.
- **Đã có nhưng cần sửa:** camera orbit/pinch sau shot; nút B bên trái; effect bên trái; quick rail bên phải; Undo ở bên trái; `PoolAudio` tổng hợp PCM theo loại impact/lực; `addBall()` thêm một bi bằng lưới cố định; bài học với link ngoài; bài tập trong Menu và quick rail; cue/elevation và vật lý 3D nghiên cứu.
- **Chưa tìm thấy trong source đã kiểm tra:** cơ chế phòng trận qua mã số, realtime network, điều khiển lượt và bảng tỉ số online.
- **Quy tắc xung đột yêu cầu:** các mục cũ trong `NEXT-ACCEPTANCE-2026-10-24.md` / `NEXT-RELEASE-REQUIREMENTS.md` nói *effect dưới trái gần B* và *giữ camera chỉnh tay sau shot* được **thay thế bởi yêu cầu mới trong tài liệu này**: effect bên phải thanh nâng cơ, Undo bên phải, tự trở về **góc ngắm sát 3D** sau khi mọi bi đã dừng; ngoại lệ hợp lý khi người chơi đang quan sát lượt đối phương hoặc đang replay. Sửa lại hồ sơ cũ để không bị agent đọc nhầm.
- **Không được tuyên bố** đang điều khiển Mac, đã build/đã ký IPA, hoặc đã kiểm chứng bàn thật chỉ vì có tài liệu/CI.

## 1. Mục tiêu sản phẩm & nguyên tắc phản biện

1. **Cảm giác như trên bàn pool thật**: đúng kích thước, đường bi và trạng thái xoáy; cơ không cắt xuyên băng, hình/âm thanh phản hồi đúng sự kiện.
2. **Ít thao tác nhất**: mỗi công cụ xuất hiện đúng tần suất sử dụng và đúng vị trí tay; không để 8–10 icon cố định che bàn trên màn iPhone ngang.
3. **Giữ một source vật lý**: physics C++ là nguồn chân lý cho collision, pocket, spinning, jump và trạng thái bi. SceneKit chỉ trình bày; UI không tự sửa trạng thái vật lý.
4. **Tách chế độ rõ ràng**: `Aiming → StrokeLocked → Simulating → ShotSettling → ReviewReady` và `Spectating/Replay/Editing/Lesson/OnlineLobby`; tránh gesture xuyên chế độ.
5. **Không hi sinh độ đúng để chữa giật**: fixed-step physics, nội suy render; đo frame-time trên máy thật; không thay hệ số ma sát để che lỗi camera/FPS.
6. **Build nhỏ theo giai đoạn**: 0.13 cải thiện offline + giáo trình; 0.14 multiplayer. Không gom 8 chức năng lớn vào một commit không kiểm thử.

## 2. Ma trận yêu cầu và tiêu chí nghiệm thu

| ID | Mức | Tác vụ | Hành vi nghiệm thu bắt buộc |
|---|---|---|---|
| CAM-01 | P0 | Camera quan sát sau cú đánh | Từ góc ngắm 3D chuyển sang toàn bàn mượt; two-finger orbit, pinch zoom hoạt động khi bi lăn; không phát sinh cú đánh. |
| CAM-02 | P0 | Trả lại góc ngắm tự động | Khi **tất cả bi** ngừng và qua khoảng ổn định 0,5 s, camera tween 0,35–0,6 s về góc aim 3D đã lưu; không snap. Nếu chuyển lượt cho đối thủ: giữ spectator, chỉ vào aim khi đến lượt mình. |
| CAM-03 | P0 | Ba mode camera | `Aim 3D` mặc định khi bắt đầu và đến lượt; `Top` cho xoay toàn bàn và zoom; `Overview 3D` orbit yaw/pitch/zoom cho người đang xem. Nút đổi góc dưới phải. |
| HUD-01 | P0 | Bố trí bên phải | Effect (ngay **bên phải** thanh elevation), Undo và View dưới phải. Cue/Cue Bag/Ball Placement nằm trong flyout quanh elevation; không che bi, Menu hoặc vùng shot. |
| HUD-02 | P0 | Menu gọn | Bỏ `Bài tập` khỏi quick rail, tập trung một đầu vào trong Menu. Xóa/ẩn shortcut trùng nhưng giữ chức năng trong nhóm phù hợp; các setting phòng lab nằm trong Nâng cao. |
| RAND-01 | P1 | Thêm N bi ngẫu nhiên | Nút `+ Bi` gần cạnh Menu (hoặc trong popover góc phải); chọn 1–15 hoặc `thêm N`/`đặt lại N`; seed lưu được; không chồng nhau, không nằm trong miệng lỗ, không ghi đè bi cái. |
| CUE-01 | P0 | Cơ bị côn băng | Khi bi cái sát băng, phần thân cơ có thể vượt lên trên đỉnh băng; không cắt mesh hoặc chui qua băng. Điều chỉnh độ nâng tối thiểu có giới hạn bởi hình học; thông báo khi tư thế đánh bất khả thi. |
| CUE-02 | P0 | Giới hạn effect động | Miền điểm chạm hợp lệ theo góc nâng, mép băng và khoảng cách bi cái–băng; pad thể hiện vùng bị khóa và kẹp input; tip 3D, strike và dự báo cùng tọa độ. |
| AUD-01 | P1 | Bộ mẫu thu thật | 4 loại cue–cue ball, ball–ball, ball–rail, pocket và các biến thể mềm/vừa/mạnh; volume, pitch/EQ, stereo theo xung lực/độ lệch, không clipping hoặc spam nhiều tiếng. |
| EDU-01 | P1 | Giáo trình học thật | Trong `Menu → Bài tập`: nhóm, cấp độ, sơ đồ thế bi độc lập, mục tiêu 10 cú/7 đạt, nút `Xếp bi tập ngay`; video chính chủ ngay bên dưới (embed hợp lệ hoặc mở YouTube). |
| EDU-02 | P1 | Tài liệu minh họa | Catalog JSON/CSV: tác giả/video/timestamp/quyền/sơ đồ/thế bi/tọa độ; tạo PDF sơ đồ bản quyền riêng và link tới PDF tác giả, không chép frame/video khi chưa được phép. |
| NET-01 | P2 (0.14) | Ghép 2 máy bằng mã | Chủ phòng tạo **mã số 6 chữ số**, khách nhập từ bất cứ mạng nào; mã hết hạn và rate limit; mỗi phòng tối đa 2 người chơi; reconnect. |
| NET-02 | P2 | Thỏa thuận luật | Hai bên chọn `8-ball`, `9-ball`, `Free Practice/Runout` (sau khi có rule tests), bộ luật, số ván, ai phá/luân phiên phá; cả hai bấm **Đồng ý** trước Start. Có thể đưa 10-ball vào khi rules engine được test. |
| NET-03 | P2 | Trạng thái/tỉ số realtime | Khi một máy đánh, máy kia quan sát 3D tự do nhưng không thể tác động bi; đồng bộ initial snapshot/shot event/checksum/final snapshot/turn/foul/score. HUD: tên, bi mục tiêu, lượt, frame, tỉ số. |
| REG-01 | xuyên suốt | Không hồi quy | Giữ C++ physics, vật liệu nỉ, bóng/băng/lỗ, camera cơ, cue types, undo/replay, save/load, hiệu chuẩn, jump/massé và frame-time đã có. |

### 2.1. Quy tắc HUD hoàn chỉnh cho iPhone 14 Pro Max nằm ngang

- **Bên trái:** nút **B** khóa cầu tay (một tay); vi chỉnh góc ngắm có thể nằm đáy giữa; không còn effect/Undo chen cạnh B.
- **Phải, trên:** nút `Menu` nhỏ; cạnh hoặc dưới Menu là `+ Bi` dạng compact; khi chọn mở panel `Thêm N / Đặt lại N / Xáo lại`, có cảnh báo reset bài tập hoặc ván online.
- **Phải, dưới:** cụm thao tác ưu tiên `Góc nhìn` (gần tay), `Bi effect` (sát **phải** của thanh nâng cơ), `Lùi cú`; thanh `Góc nâng / Jump` không bị che. Dùng constraint theo safe area, có layout compact mở dọc/ngang tùy chiều cao hữu dụng.
- **Thiết bị nhỏ:** ưu tiên 44×44 pt hit target; effect thu nhỏ và bung overlay *vào vùng trống*, không chèn lên bàn; nếu thiếu diện tích, dùng popover một lần nhấn cho `Cơ`, `Bao cơ`, `Đặt bi`, `Ngẫu nhiên`; không cố nhồi toàn bộ thành cột icon.
- **Tần suất:** `B`, stroke, effect, camera, elevation, Undo luôn gần; `Cơ/Bao/Đặt bi` ít dùng hơn => flyout; `Bài tập/Hiệu chỉnh/Sources` trong Menu; `Reset`/`Đánh thử kỹ thuật` trong Practice/Advanced. Không xóa tính năng đã có mà không tìm vị trí thay thế.
- **Ngăn ghost touch:** khi spin expand thì stroke không được kích hoạt, hướng aim/gesture hai ngón không bắn; khi online spectator mọi input bắn/phá/đặt bi bị disabled nhưng camera vẫn hoạt động.

### 2.2. Camera & state machine

- Bắt đầu lần đầu ở `cameraMode=Aim3D` (không mặc định top). Lưu `preShotAimTransform` gồm eye/target/orbit/zoom/FOV/aim direction/shot layout trước khi đánh.
- `shoot` thành công ⇒ `Simulating`, tự chọn `Overview3D` framing toàn bàn, transition easing. Camera **không ép bám cue ball** hay nhảy sau các impact.
- Khi bi chạy: two-finger pan = orbit; pinch = dolly/zoom; top xoay quanh tâm bàn; overview xoay trục 3D; có reset framing. Nếu gesture thủ công, cho phép tự do quan sát đến khi hết lượt.
- Khi `engine.moving == false` và không còn pocket animation thiết yếu; ổn định 0,5 s ⇒ transition về `Aim3D` cho người sắp đánh (local turn), bất kể đã xoay trong lúc xem; tôn trọng ngoại lệ `spectating` hoặc `replay`.
- Nếu người chơi bật `Khóa góc xem` trong phần tùy chọn nâng cao, chỉ ảnh hưởng chế độ xem thủ công/replay; **mặc định bắt buộc tự trả aim** theo quyết định mới. Không dùng flag camera cũ khiến không trở lại.
- Camera trong replay chỉ thay transform và dựa trên snapshot đã lưu. Không sửa trạng thái engine; không gắn gesture 1 ngón với shoot.
- Test: cú nhẹ 15 s, phá 15 bi, bank/kick 1–3 băng, jump/masse, pocket, scratch, Undo khi đang chạy; xoay+pinch liên tục; góc ngắm phục hồi không bị mất khi bi cái vào lỗ (ball-in-hand sau foul).

### 2.3. Tương tác cơ chạm băng & giới hạn điểm effect

- Một mô hình hình học duy nhất cho cue axis, tip contact, rear-hand pivot và chính chiếc băng. Với bi cái cách rail dưới ngưỡng vật lý, kiểm tra **đường thẳng/mesh thân cơ với envelope mặt băng**; lấy góc nâng nhỏ nhất đủ thông qua, không tự tạo jump trái ý muốn.
- Nếu không thể đánh ở góc hiện tại, hiện ghost/outline cue bị rào và gợi ý tăng elevation/chuyển góc/đặt lại bi; không xuyên mesh.
- Giới hạn tối đa offset tip do: tránh miscue (tự chọn ngưỡng hợp lý dưới khoảng 70% R), góc nâng, bề mặt có thể tới, không gian ray bên dưới, và độ sâu tip. Nêu rõ **mô hình xấp xỉ, không phải luật miscue vạn năng**.
- Màu pad: hợp lệ sáng, cấm mờ/gạch; khi người dùng kéo vào cấm → clamp có feedback nhẹ; `aim`, `prediction`, `strike` phải dùng giá trị đã clamp và test bằng snapshot.
- Nếu cho auto elevation, lưu tách `userElevation` và `effectiveElevation` để UI luôn hiển thị góc thực tế; tránh gameplay dùng 0° nhưng render 20°.

### 2.4. Âm thanh vật lý

- Giữ event IDs native: rail, ball-to-ball, pocket, cue (kiểm lại enum event C++); lấy `impulse`, `relativeSpeed`, `contact location`, `type` làm input, **không** dựa vào góc màn hình hay âm lượng micro.
- Chọn sample bằng phân loại lực tối thiểu 3 mức, 2–4 biến thể cho mỗi loại; `gain = smooth mapping` theo xung lực có range compressor nhẹ, pitch variation nhỏ; âm không loop và không phóng đại cú nhẹ.
- Có stereo pan theo vị trí bàn, gain âm lỗ góc/giữa khác nhau khi có dữ liệu; rail có damping/timbre khác ball-ball; cue break mạnh hơn cue shot thường; xét thời gian gộp các impact đồng thời.
- Cache/decode **trước** khi đánh; playback pool ≤12 voices với priority voice stealing; tránh lag main; audio session tôn trọng nhạc thiết bị, âm lượng mute, tai nghe và haptic.
- Ghi license cho từng file tại `Assets/Audio/ATTRIBUTION.md`; không tải rip YouTube. Nguồn tham khảo được phép: Freesound `bsumusictech/62331` CC0 (va bi), `jtroan/241373` CC BY 3.0 (rơi lỗ, cần ghi công). Nếu sample thiếu quyền rõ ràng, giữ synthetic fallback hoặc tự thu bằng điện thoại.
- Test perceptual: ít nhất 12 tình huống; người nghe A/B dưới cùng gain; không clipping peak/không có 0,15 s trigger delay; audio offline và online dựa cùng event timeline.

### 2.5. Bi ngẫu nhiên / runout

- `+ Bi` có 3 tác vụ khác nhau: `Thêm N bi đích` vào bàn hiện tại, `Tạo thế dọn N bi` xóa bi đích cũ và sinh lại, `Đổi thế ngẫu nhiên` với cùng N. Không đụng bi cái trừ khi người dùng chọn đặt lại.
- Sử dụng `seed` deterministically; IDs không trùng (1...15), no overlap ≥ 2R + margin; giới hạn cách băng và bi trong profile, tránh miệng lỗ/điểm không đặt được.
- Random với giới hạn attempts, có backoff hoặc sampling; không treo UI nếu không xếp đủ N. Không tự cho bi xuất hiện trên đường đang chuyển động. Trước khi random trong lesson/online: xác nhận rời chế độ/bỏ lượt phù hợp.
- Lưu snapshot, seed, count, ball IDs để Replay/Undo/online checksum và cùng tái tạo được; tách level/difficulty (dễ: tản; vừa: cụm nhỏ; khó: sát băng) sau v1.

### 2.6. Giáo trình & video — nguồn đã đối chiếu

**Nguồn chính:** [Dr. Dave drills](https://drdavepoolinfo.com/faq/drill/), [cue-ball drills](https://drdavepoolinfo.com/faq/cue-ball-control/drills/), [bank/kick](https://drdavepoolinfo.com/tutorial/kicks-and-banks/), [two-to-one](https://drdavepoolinfo.com/faq/bank-kick/two-to-one/), [Plus System](https://drdavepoolinfo.com/faq/bank-kick/plus/), [VEPP resources](https://drdavebilliards.com/videos/vepp/resources/), [Pool Table Kick/Bank Test Shots PDF](https://drdavepoolinfo.com/resource_files/kick_and_bank_test_shots.pdf), [Billiard University videos](https://billiarduniversity.org/resources/videos/).

**Đã có YouTube URL trong source repo:**
- `https://www.youtube.com/watch?v=rcWccgPnoso` — hệ 2:1 / kick một băng (phải kiểm tra availability/owner/khả năng nhúng tại thời điểm build).
- `https://www.youtube.com/watch?v=UhIH0BmuSdE` — kick hai băng (như trên).
- `https://www.youtube.com/watch?v=11iSqkJjWgM` — ảnh hưởng lực/xoáy (như trên).

**Bộ giáo án bản quyền riêng đề xuất:**

| ID | Nhóm & mức | Sơ đồ game tự dựng | Nhiệm vụ chấm điểm | Tham khảo |
|---|---|---|---|---|
| D01 | Stop · cơ bản | Bi cái và bi 1 thẳng hướng góc | 10 cú, tối thiểu 7 cú bi cái dừng trong vòng 1R quanh điểm chạm | Dr. Dave cue-ball drills |
| D02 | Follow/Draw · cơ bản | Cùng thế D01, vùng đích tiến/lùi | 7/10 vào vùng đặt trước, bi mục tiêu vào lỗ | Dr. Dave cue-ball drills |
| D03 | Speed ladder · cơ bản | Một bi cái, 5 vạch vùng dừng | 3/5 ở mỗi cự ly, không scratch | Dr. Dave drill library |
| D04 | Cut + position · trung bình | Bi 1 cắt 30° và 45°, hai vùng đích | Bi 1 vào lỗ và bi cái nằm vùng đích, 7/10 | Dr. Dave aiming and stroke |
| D05 | Kick 1 rail · trung bình | Bi cái 1 bên, bi mục tiêu lệch; một băng | Chạm đúng bi sau đúng 1 băng, 7/10; thử hệ gương và 2:1 | Dr. Dave two-to-one |
| D06 | Kick 2 rail · khó | Bi cái một đầu; đích sau vật cản | Chạm đúng bi sau 2 băng; 7/10 | Dr. Dave bank/kick tutorial / Plus |
| D07 | Bank 1 rail · trung bình | Bi 1 hướng băng đối diện rồi về góc | Bi 1 vào lỗ qua đúng 1 băng; 7/10 | Dr. Dave bank/kick tutorial |
| D08 | Kick 3 rail · khó | Bi cái qua 3 băng tiếp cận bi 1 | Chạm bi đúng sau 3 băng; 7/10, so Corner-5 như ước lượng | Dr. Dave Corner-5 |
| D09 | Runout 3/6/9/15 · mọi mức | Random seed cố định, không chồng bi | Hoàn tất dọn N bi, thống kê số cú/lỗi/seed | Kỹ năng ứng dụng do Zoker thiết kế |
| D10 | Safety · nâng cao | Che bi cái sau blockers có vùng đích | Giữ bi cái trong vùng an toàn, tránh đường ngắm trực tiếp | Dr. Dave training/20 safeties |

**Hướng biên tập:** mỗi lesson có `id`, family, difficulty, `balls[{id,x,y}]` mét theo mặt chơi, `cueAngle`, force/side/top gợi ý, `target`, rail count, pass/fail, video author/title/url/start_seconds/rights, source page, PDF URL (nếu có). Xếp thứ tự Hình 2D → Bài đọc/giải thích → Video/YouTube → nút `Tập ngay` → ghi điểm. Video chính chủ hiển thị bằng YouTube embed hợp lệ với referer và không che player hoặc mở app YouTube khi không cho embed; **không lấy video gốc, ảnh frame, thumbnail để đóng vào IPA** nếu không đủ quyền. Sơ đồ và PDF phải được dựng từ tọa độ của dự án.

## 3. Multiplayer 0.14: kiến trúc & luật

**Phạm vi đợt 1:** iPhone/iPad hai máy qua Internet (Wi-Fi/4G/5G), ghép bằng 6 chữ số; 8-ball, 9-ball, Runout tự do; giới hạn 2 người; không chat/voice/tiền cược ở bản đầu.

**Đề xuất hạ tầng:** Cloudflare Worker + Durable Object một phòng/một đối tượng; WebSocket + hibernation. Lý do: một chủ thể phòng kiểm soát lượt, số ván, trạng thái và replay; giảm lỗi ngang hàng/nat và ít phát đi khung hình. Workers Free/DO SQLite free tier hiện có giới hạn, phải xác minh chi phí và quyền truy cập trước khi deploy; demo có thể dùng Supabase Realtime miễn phí nhưng giới hạn anti-cheat và sequencing. **Không nhúng API secret vào IPA.**

**Giao thức tối thiểu:**
1. `CREATE_ROOM` → server tạo room code 6 số CSPRNG, expire 15 phút nếu chưa ghép, opaque join token; host là ghế A.
2. `JOIN_ROOM {code}` → rate limit theo IP/device, tối đa ghế B; cả hai thấy tên/online/latency.
3. `PROPOSE_RULES {game, rulesetVersion, raceTo, breakPolicy, tableProfile, physicsVersion}`; sửa đổi = huỷ đồng ý cũ; mỗi máy `ACCEPT_RULES` đối với cùng config hash.
4. `START_MATCH {seed, startSnapshot, serverTurn}`; server xác nhận phase và version; UI online vô hiệu hóa `Add Balls/Undo` trừ hai bên đồng thuận.
5. Client lượt đánh gửi `SHOT_COMMAND {seq, angle, speed, side, top, elevation, cueType, preStateHash}`; kiểm tra turn, tính hợp lệ, range/miscue, anti-replay; authoritative host/server cấp sự kiện kết thúc. Replay video là client render sự kiện, không stream 60 FPS.
6. `SHOT_RESULT {seq, eventLog, finalState, foul, pocketed, nextTurn, score, checksum}`; đối chiếu checksum; nếu sai, đồng bộ server snapshot và hiển thị thông báo ngắn.
7. `PING/PONG`, disconnect 30–90 s, reconnect token; pause, forfeit, leave, rematch; room/code auto-delete; audit event logs không giữ PII thừa.

**Lưu ý quan trọng:** nếu Worker không chạy mô phỏng C++ đồng nhất, giải pháp MVP có thể dùng **host-authoritative** (host xử lý shot, server kiểm tra turn+message, guest nhận snapshots); công khai đây là giới hạn chống gian lận. Bản thương mại nên chuyển solver sang máy chủ/WebAssembly hoặc kiểm chứng độc lập từ replay determinism. Không để hai máy tự tiến vật lý rồi mặc nhiên tin rằng chúng luôn giống nhau.

**Rules engine tách UI**: table-driven `8BALL`, `9BALL`, `RUNOUT`; theo dõi turn, break, foul, scratch, ball-in-hand, legal first contact, pocketed balls, win frame; cấu hình WPA hoặc house rule **ghi đúng tên, không nhầm**; push-out, three-foul, call-shot chỉ bật ở ruleset đã kiểm thử. `raceTo` hoặc `bestOf` (không đồng thời); scoreboard cập nhật theo server state và không trễ đáng kể so với shot completed. Chế độ spectating cho orbit/zoom nhưng cấm đánh, đặt bi, Undo đơn phương.

**Bằng chứng online:** ma trận hai thiết bị trên Wi-Fi khác nhau và 4G, host/guest đổi vai, disconnect 5/30/90s, mất gói/latency 150–300ms, shot/pot/foul/rack restart, đôi bên đổi luật, code trùng/hết hạn, join người thứ ba, revoke room, luật race-to 3 và race-to 5, 50 shots liên tiếp không lệch state/hash.

## 4. Bản đồ source & module dự kiến

| Thành phần | File hiện tại → hướng sửa |
|---|---|
| HUD/Camera state, shot update, Undo, lessons | `BankLab/UI/TrainingController.swift`: chia thành `CameraCoordinator`, `ShotLifecycle`, `HUDLayout`, `PracticeLaunch`; ưu tiên refactor nhỏ giữ backwards compatibility. |
| Spin/elevation/touch | `BankLab/UI/TouchControls.swift`: valid contact area, dynamic clamp, safe-area/right-side anchor, gesture priority. |
| SceneKit cue/băng/camera | `BankLab/Rendering/TableScene.swift`: top/overview free-orbit, cue rail clearance, animation/tween và solver-derived basis. |
| Bài tập/dữ liệu | `BankLab/UI/Models.swift`: chuyển hard-coded lesson metadata thành nguồn JSON versioned; bổ sung progress/pass.
| Physics native | `BankLab/Core/Physics.*`, `ElevatedPhysics.cpp`, `BLWorld.mm`: chỉ sửa khi test chứng minh lệch cue–physics/collision; thêm physics event fields nếu thiếu, không rewrite.
| Audio | `BankLab/Audio/PoolSoundEngine.swift` + `Assets/Audio/` (thay lớp `PoolAudio` inline; synthetic fallback).
| Random placement | `BankLab/Practice/RandomRackGenerator.swift`: seed, validation, persistence.
| Multiplayer | `BankLab/Network/{RoomClient,MatchState,RulesEngine,SnapshotCodec}.swift`, `server/worker/` Cloudflare worker + DO (sau phase offline).
| Workflows | `.github/workflows/xcode-build.yml`, `codemagic.yaml`, `Tools/ci_screenshots.sh`, tests native/physics/net; cập nhật số version/workflow name từ 0.11/0.12 cũ.
| Hồ sơ | `Docs/NEXT-ACCEPTANCE-2026-10-24.md`, `Docs/NEXT-RELEASE-REQUIREMENTS.md`, `Docs/RELEASE-0.13.md`, `Docs/RELEASE-0.14.md`, `Docs/EXTERNAL-ASSETS-LICENSES.md`, `Docs/QA-MATRIX.md`.

## 5. Triển khai theo đợt, gate và bằng chứng

| Phase | Nhánh/PR | Việc | Gate tối thiểu |
|---|---|---|---|
| G0 Audit | từ `main` tại SHA đã nêu | Đóng băng baseline, map chức năng & yêu cầu cũ/mới, kiểm tra git tree và workflow, ghi tests hiện có; **chưa chỉnh logic** | Báo cáo `BASELINE.md`, diff dự kiến, test baseline pass hoặc lỗi được phân loại rõ. |
| G1 Controls + camera (0.13-a) | `feature/0.13-hud-camera` | UI right cluster, aim default, auto-return, spectator camera, no ghost taps, safe areas | 30 tình huống gesture + ảnh iPhone ngang + Simulator, Undo/replay không regress. |
| G2 Cue + random (0.13-b) | `feature/0.13-cue-random` | rail-overlap cue, dynamic effect, random N seed | Unit-test geometry 20 cases, random 1/3/6/9/15 over 100 seeds each, invariants preserved. |
| G3 Audio + teaching (0.13-c) | `feature/0.13-audio-learning` | license/PCM, 10 giáo trình gốc, video/PDF, menu cleanup | audio A/B, copyright manifest, all lesson configs valid, no dead links or broken layout. |
| G4 Release 0.13 | review & merge riêng | Build unsigned IPA/QA/screenshots, so version, tests; nghiệm thu iPhone thực | Pass all native tests, simulator + device, log frame-time/thermal, SHA-256 IPA, nêu unsigned/signed. |
| G5 Online foundations (0.14-a) | `feature/0.14-rooms-rules` | Server room, code, protocol, rules engine, manual integration | Tests room/rules/security, 2 simulators in 2 networks hoặc network emulator, không có key lộ. |
| G6 Online 0.14 | `feature/0.14-live-match` | State sync/turn/score/reconnect/spectator/rematch | ≥50 shot sequences không drift, 8/9-ball core rule tests, 2 máy thật khác mạng. |
| G7 Release 0.14 | review & merge | Signed distribution theo quyết định user, runtime metrics, rollback | IPA provenance, regression full, server cost dashboard, recovery plan. |

**Chính sách build tiết kiệm:** commit/document-only → lint/test nhẹ Linux; chạm Swift/C++/assets → physics + Simulator; chỉ Codemagic full unsigned IPA trên tag/`workflow_dispatch` hoặc PR đã đạt QA. Nếu GitHub Actions bị billing block, dùng Codemagic như đường build chính; chỉ gọi backup khi chính chưa chạy, không build trùng nhau. Secret/signing chỉ trong secure env, không ghi trực tiếp repo. Các lệnh build dưới đây chỉ chạy **trên Mac CI có Xcode**, không phải trong ChatGPT thuần văn bản.

## 6. Lệnh local/CI tham chiếu (không tự nhận đã chạy)

```bash
# Lấy source từ đúng repo và tạo nhánh G1, sau khi quyền GitHub được cấu hình
REPO='zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858'
git clone "https://github.com/$REPO.git"
cd ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858
git fetch origin --prune
git checkout main
git pull --ff-only origin main
git rev-parse HEAD          # đối chiếu với SHA tham chiếu; nếu đã thay đổi, audit lại
git checkout -b feature/0.13-hud-camera
cd native/ZokerPoolTrainer
bash Run-All-Checks.command
bash Verify-on-Mac.command
# Chỉ CI/Mac signing environment phù hợp:
bash Build-Unsigned-IPA.command
bash Tools/ci_screenshots.sh
```

**Không force-push `main`, không merge khi lỗi, không ghi `PASS` không có artifact/log, không cung cấp IPA dưới 1MB như bản đầy đủ nếu chưa đối chiếu cấu trúc và resources.** Phân biệt `unsigned IPA` để tải source/build test với IPA đã ký cài máy. So version/bundle `com.maiquocviet.BankLabS`, Build number tăng đơn điệu, SHA-256 và ZIP integrity.

## 7. MASTER PROMPT — giao nguyên văn cho agent/workflow

```text
VAI TRÒ: Senior iOS/SceneKit + C++ billiards physics + HCI designer + audio engineer + realtime multiplayer architect + QA release engineer.

DỰ ÁN DUY NHẤT: repo private zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858. Không nhầm với các repo Zoker Auto Vox, Studio, Zoker-Pool-Trainer, MQVPoolTrainer-I hoặc dự án khác.

ĐIỂM NEO THAM CHIẾU: main commit aba66d0f21e0816973ef0c13281fa98855ca3ff6; source build 0.12/22 ghi nhận compile từ 2dd1a55e51a55c4e2d0c5d697b79fcdd4df3f1bd. TỰ FETCH main mới nhất ở thời điểm chạy, so SHA, diff, status; nếu đã có commit mới, cập nhật baseline theo thực tế và bảo toàn thay đổi hợp lệ. Không ghi đè source đang làm.

NGUỒN YÊU CẦU: Đọc trọn vẹn tài liệu ZokerPoolTrainer_0.13_0.14_Master_Patch_Workflow_2026-10-24.md, Docs/RELEASE-BUILD22.md, Docs/NEXT-ACCEPTANCE-2026-10-24.md, Docs/NEXT-RELEASE-REQUIREMENTS.md, ARCHITECTURE.md, các UI/physics Tests và CI. Tài liệu master ngày 24/10 này có ưu tiên cao hơn yêu cầu cũ khi chúng mâu thuẫn.

THỰC HIỆN KHÔNG HỎI LẠI CÁC VIỆC ĐÃ RÕ:
1) Audit repo và lập FEATURE_MATRIX trước/sau. Chạy baseline tests; ghi commit SHA, file ảnh hưởng, sự khác biệt docs và code. Không gọi tài liệu là implementation.
2) Trên nhánh feature/0.13-hud-camera, thực thi CAM-01/02/03 và HUD-01/02: default camera Aim3D; tự bật overview sau shot; orbit + pinch tự do lúc bi lăn; sau khi toàn bộ bi dừng >0.5s trả smooth về aim khi đến lượt local; spectating/replay không ép trả; dời bi effect sang PHẢI của thanh elevation; Undo và View bên PHẢI; Cue/Bag/Place/Random trong flyout phải; Exercise CHỈ trong Menu. Ưu tiên safe area iPhone landscape, nút ≥44pt, không đụng gesture stroke.
3) Viết/kiểm tra geometry CUE-01/02, random N deterministic RAND-01. Cơ sát băng phải đi đúng hình học trên mặt băng, không xuyên; tip/effect/elevation cùng solver; input ngoài miền chạm hợp lệ phải bị clamp/hướng dẫn. Thêm bi không trùng/không lỗ/không va bi. Đừng sửa hệ số physics nếu không chứng minh cần.
4) AUD-01: chuyển audio tổng hợp thành audio engine sample-based có synthetic fallback. Lấy sample CC0/CC-BY hợp lệ hoặc thu/tạo mới; ghi license + attribution; tuyệt đối không rip YouTube hay mượn âm từ repo không có license. Kết nối sound với impulse/vị trí/kind của event native và chống clip/delay.
5) EDU-01/02: sắp lại Menu→Bài tập, lập catalog dữ liệu versioned 10 giáo trình theo bảng, phối hợp nguồn Dr. Dave/BU và các video URL đã được lưu trong repo; chủ động mở/check owner, availability, embed-allowed, timestamp; sơ đồ 2D/PDF là của Zoker tự dựng bằng tọa độ, không cắt ảnh/video của tác giả. Chấm điểm tự động và lưu tiến bộ.
6) Chia nhỏ PR theo G1/G2/G3, chạy đầy đủ Run-All-Checks, Simulator build, UI screenshot gates, rồi Codemagic unsigned IPA 0.13; gắn release notes, logs, QA matrix, SHA-256. Trình bày rõ bước nghiệm thu máy thật còn chờ nếu chưa chạy được. Không merge main trước khi đạt gate; không tạo PR trùng lặp.
7) Sau khi 0.13 được nghiệm thu, bắt đầu 0.14 qua feature/0.14-rooms-rules & feature/0.14-live-match: tạo phòng mã 6 số, 2 máy qua Internet; room expires/rate limit/reconnect; hai bên thỏa thuận game/rule/race rồi cùng accept; 8/9-ball, runout đầu tiên; lượt & scoreboard realtime; người chờ được orbit nhưng không bắn; authoritative sequencing, snapshots/checksum, logs, disconnect tests. Ưu tiên hạ tầng có free tier và cấu hình phí trần; tuyệt đối không hardcode API secrets. Nếu chưa có quyền cloud/credential thì dựng backend bằng mã nguồn + local mock/integration tests và nêu chính xác việc cần cấp quyền, không bịa deploy.
8) Bảo toàn toàn bộ physics/pocket/graphics/gear/jump/masse, preset bàn/cơ, Undo/replay và data; thêm regression tests. Mỗi tính năng cần chứng cứ test/screenshot hoặc file output, không chỉ checkbox.

BÁO CÁO MỖI GATE: (a) repo/branch/base/head SHA, (b) danh sách file thay đổi, (c) đã hoàn thành/chưa xong + lý do, (d) commands/test outputs PASS/FAIL, (e) link PR/build/artifact và IPA SHA-256 nếu có, (f) 3 rủi ro còn lại, (g) bước tiếp theo có thể thực thi. Không nói đang điều khiển Mac nếu chưa thực sự có Agent Mac và quyền tương ứng.
```

## 8. Nghiệm thu cuối cùng / Definition of Done

- Camera: 3 góc, Aim3D mặc định, tự trả sau cú đánh local, spectator 3D orbit trong lượt đối phương; không nhấp giật hoặc bắn nhầm; gesture 2 ngón và Undo/replay bình thường.
- HUD: một tay B trái, góc phải gọn, effect phải elevation, Undo phải; 100% hit area không che nhau trên iPhone 14 Pro Max và một thiết bị ngang nhỏ hơn.
- Cơ/băng: 20 cảnh côn băng/elevation/effect, hình và solver trùng nhau; đường ray không bị đâm xuyên. Bi random 100 seeds×5 mức không trùng.
- Âm: 4 class sound, 3 mức lực, license manifest; không nổ peak và test chủ quan có báo cáo.
- Học: ≥10 giáo trình có sơ đồ, giải thích, mục tiêu, điểm, nguồn; video mở được trong app hoặc YouTube theo quyền; PDF schematic không dùng tài sản trái phép.
- Online: hai mạng khác nhau, room code, đồng ý luật, score realtime và reconnect; 50 shot sync sequences không mismatch chưa được xử lý; 8/9-ball rules đủ test.
- Engineering: C++ unit and research tests pass, iOS simulator + unsigned IPA compile, screenshots, signed test trên thiết bị (nếu khả dụng), FPS/frame-time/thermal và git SHA được đối chiếu.
- Bàn giao: source/PR theo feature, release notes, test logs, screenshot, chứng cứ đo trên máy thật, artifact IPA/ZIP đúng bản & SHA-256; liệt kê hạn chế đo bàn thật, quyền video/audio và backend billing.

## 9. Liên kết kiểm chứng

- Repo & code: `https://github.com/zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858`
- Poolians chính chủ (chỉ làm tham chiếu thao tác; không sao chép UI/asset): https://poolians.com/web.php/faq/show/faq_3d_control
- Dr. Dave drills: https://drdavepoolinfo.com/faq/drill/
- Dr. Dave cue-ball control: https://drdavepoolinfo.com/faq/cue-ball-control/drills/
- Dr. Dave bank/kick: https://drdavepoolinfo.com/tutorial/kicks-and-banks/
- Billiard University videos: https://billiarduniversity.org/resources/videos/
- Dr. Dave VEPP handouts: https://drdavebilliards.com/videos/vepp/resources/
- Pool test shot PDF: https://drdavepoolinfo.com/resource_files/kick_and_bank_test_shots.pdf
- Freesound CC0 ball: https://freesound.org/people/bsumusictech/sounds/62331/
- Freesound CC-BY pocket: https://freesound.org/people/jtroan/sounds/241373/
- YouTube embed help: https://support.google.com/youtube/answer/171780
- Supabase Realtime limits: https://supabase.com/docs/guides/realtime/limits
- Cloudflare Durable Objects pricing: https://developers.cloudflare.com/durable-objects/platform/pricing/
