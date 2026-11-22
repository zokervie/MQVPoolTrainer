# Giao việc 0.53 — sửa sau nghiệm thu 22/11 (cho phiên Mac)

Nhánh nền: `origin/cho/native-0.53-phieu-lo` (= `cho/native-0.49-xuong-bai` @ cfdabf4 + sửa lõi phễu lỗ ffd6d5a).
Làm tiếp trên nhánh đó. Một mục = một commit, kèm test Swift khi có thể. Đóng băng tính năng thứ Năm 26/11.
Thứ tự: P0 → P1 → P2. Hết giờ thì dừng ở cuối nhóm đang làm và báo.

Quy tắc: không trợ giúp ngắm ở chế độ chính; mục hình ảnh có ảnh "phòng chuẩn" trước/sau; phần cảm giác ghi
"chưa xác minh trên thiết bị"; không merge vào feature/zoker-native.

---
## P0 — lỗi

**A1. 10-ball đấu với máy: máy phạm lỗi nhưng người chơi không đặt được bi.**
Lõi đúng: `MatchRules.hpp` dòng ~193 đặt `ballInHand = true` khi phạm lỗi (đã có test). Nghi gốc ở giao diện (INFERRED):
`MatchPlayController.syncMatchControls` (dòng ~570) bật `quickPlace.isEnabled` nhưng KHÔNG gọi `syncPlaceBallButton()`,
nên nút Đặt bi mới (G6, `placeBallButton`) giữ trạng thái tắt cũ. Sửa: gọi `syncPlaceBallButton()` ngay sau dòng đó.
Test UI: 10-ball với máy, ép máy phạm lỗi (cờ QA), nút `PlaceBallButton` phải bật và kéo được bi cái.
Kiểm thêm 8-ball và 9-ball cùng tình huống.

**A2. Vòng nhiệm vụ biến mất khi giữ B.**
VERIFIED: `TC+AimInput.swift` dòng 55 và 65 gọi `table.setTrainingOverlaysHidden(locked)`, hàm này ẩn luôn `targetRoot`
(vòng). Sửa: khi khoá B chỉ ẩn đường dự báo và vệt (guideRoot, trailRoot); vòng (`targetRoot`) và số nút giữ nguyên
khi đang ở Bài tập / Thử thách / Thế bí. Test UI: mở bài có vòng, giữ B, đầu dò `targetRoot` vẫn hiện.

**A3. Chơi qua Wi-Fi.**
1. Bi lăn trước khi gậy chạm: trên máy khách, mô phỏng (lockstep `predictor`) và tiếng cơ (`onAcceptedCommand`) chạy
   ngay khi nhận lệnh, không chờ hoạt cảnh đẩy cơ. Sửa: máy khách chạy hoạt cảnh đẩy cơ như máy chủ, rồi mới bắt đầu
   đồng hồ bi (cùng độ trễ trên cả hai máy).
2. Tiếng bi rơi lỗ hai lần: máy khách có hai đường phát âm (`lockstepTick` phát sự kiện của bộ dự đoán, và
   `matchGuestTick` phát `audioEvents` từ ảnh chụp máy chủ). Khi lockstep chuyển sang ảnh chụp, sự kiện đã phát không
   được đánh dấu đúng (chỉ đánh dấu theo thời gian). Sửa: một nguồn âm duy nhất cho mỗi cú, khoá theo (shotID, loại,
   bi, lỗ); test đơn vị: cú có bi vào lỗ + chuyển sang ảnh chụp giữa chừng → đúng 1 tiếng rơi.
3. Cú ra cơ đôi khi khựng: đo trên 2 Simulator (máy chủ + khách), ghi thời điểm từng khung trong 2 s đầu cú. Báo số
   khung trễ > 25 ms trước/sau. Nếu là relayout giữa cú, hoãn như bài học 0.39d.

---
## P1 — giao diện đã duyệt

**B1. Bố cục nút.** "Xem lại" vào trong mục "Bàn". Nút Đặt bi và nút bật/tắt thanh lực chuyển sang bên phải, cạnh
thanh lực. Hai nút có chữ nhỏ bên dưới: "Đặt bi", "Thanh lực". Không đổi bố cục khi bi đang chạy.

**B2. Gộp cơ: 4 nút → 2 nút.**
- "Cơ chơi" (cueType 0): dựng ≥ 37° tự thành Massé, < 33° trở lại Đánh (vùng đệm). Nhãn đổi "Massé", rung nhẹ.
- "Cơ phá" (cueType 2/1): dựng < 18° = Phá (cueType 2), ≥ 22° = Nhảy (cueType 1). Nhãn "Phá" / "Nhảy", rung nhẹ.
- Ngưỡng 35°/20° là GIẢ ĐỊNH, đặt thành hằng số một chỗ. Dữ liệu cú, bản phát lại, máy đối thủ giữ nguyên.
- Sửa các UI test đang bấm `CueIconJump`, `CueIconMasse`, `CueIconBreak`.

**B3. Gọi lỗ gọn hơn.**
- Lõi đã sửa (ffd6d5a): chạm mép lỗ rồi vào = tính. Không bao giờ bắt buộc gọi lỗ; cú đi thẳng vào lỗ tự tính.
  Dòng trạng thái: "Tự động: bi vào thẳng hoặc chạm mép lỗ được tính · băng/combo: bấm Gọi lỗ".
- Thao tác: một chạm vào lỗ là xong. Bi được gọi mặc định = bi đích hợp lệ (9/10-ball: bi số nhỏ nhất; 8-ball: bi
  thuộc nhóm gần đường ngắm nhất). Muốn gọi bi khác (combo) thì chạm bi đó trước. Không bắt chuyển camera trên cao;
  nếu chạm không trúng lỗ ở góc thấp thì mới mở camera trên cao.
- Hình: bỏ vòng nhấp nháy cầu vồng. Lỗ chọn được hiện lớp sương trắng mờ (alpha ~0,25), không che miệng lỗ. Sau khi
  gọi: chỉ một mũi tên mảnh trắng nhấp nhô nhẹ chỉ xuống lỗ (biên độ ~2 cm, 1,2 s). File: `PocketMarkers042.swift`.

**B4. Số nút kim cương mọc từ chính nút kim cương.**
Hiện tại số nằm ngoài mép gỗ (x = ±0,79), cao 7,5 cm, 4,5 cm — từ góc người đánh khó thấy bên xa, khó gắn với nút nào.
Sửa: mỗi số là một bong bóng nhỏ đặt ngay trên nút kim cương, nối với nút bằng một sợi chỉ mảnh dọc xuống; nút kim
cương được tô sáng nhẹ khi số bật. Cỡ số giữ ổn định trên màn hình (~14 pt) theo khoảng cách camera. Số phía gần
camera tự mờ đi nếu che bi. Ảnh so sánh từ camera ngắm thấp: trước/sau.

**B5. Khuông xếp bi một khối.**
Hiện là 3 hộp gỗ chồng ở góc (`playRackIntro`, `rackFrameEdges`). Làm lại: một khối liền đùn từ đường viền tam giác
(và hình thoi 9-ball), góc ngoài bo tròn ~2,5 cm, góc trong bo nhỏ, dày 1,8 cm, cao 2,4 cm, cạnh trên vát, vân gỗ chạy
dọc từng cạnh. Kích thước trong giữ đúng `rackFrameEdges` (test hiện có).

**B6. Bàn bên cạnh và logo phòng.**
- Bàn bên (`neighbourTable`, `TableScene.swift` ~1058–1088): dời xa, mép băng cách mép băng bàn chính ≥ 1,6 m (không
  đâm tường); làm bàn hoàn chỉnh: băng có mũi, 6 lỗ, chân; nỉ xanh dương đậm, tối hơn bàn chính.
- Logo "ZOKER POOL" (`brandWall`): hạ xuống để thấy được khi ngắm. Đặt tâm ở khoảng 0,8–0,95 m trên mặt bàn (mắt người
  đứng), thay cho 1,3–2,2 m hiện tại; riêng phòng thi đấu lớn (5,1 m) hạ xuống ~2,5 m. Kiểm: logo nằm trong khung hình
  camera ngắm thấp mặc định ở mỗi phòng.

---
## P2 — bài tập và rà soát

**C1. Luyện lực bằng vuốt.** Trong Bài tập, Thử thách, Thế bí: tắt thanh lực (không hiện nút bật), luôn bật vòng nhiệm
vụ. Thanh lực chỉ còn trong Chơi tự do và Đấu. Phiên đám mây sẽ thêm bài "Căn lực" vòng nhỏ dần vào kho bài (C
`catalog.py`); Mac chỉ cần không chặn bài mới.

**C2. Rà soát đồ hoạ.** Chụp mỗi phòng từ 3 góc (ngắm thấp, đứng, trên cao), liệt kê chỗ dở (vật trôi nổi, cắt
xuyên, mất bóng, chữ sai), sửa cái rẻ, báo phần còn lại trong `NGHIEM-THU-0.53.md`.

Báo cáo cuối: mỗi mục PASS / FAIL / NOT RUN, ảnh trước/sau ở `shots/native`.
