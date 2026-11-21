# NHIỆM VỤ 0.49b — Xưởng bài (phiên Mac, Swift)

Chủ dự án chấp thuận 20/11 11:35: Xưởng bài + 6 mục (thế bi xê dịch, sơ đồ đủ thông tin, mẹo một dòng, lấp thang + tách chương, thẻ "Ra bàn thật", thử thách phụ).

**Nhánh:** `cho/native-0.49-xuong-bai` (từ `cho/native-0.48` @ f596fbe, đã gộp `cho/native-0.48-l10n`). Làm tiếp trên nhánh này. Trước tiên vẫn sửa `testChapterOneLadderAndExam` (lỗi chặn từ CI 159).

## Phiên đám mây đã làm (C/C++, đã chạy trên Linux g++ và clang++)
- `BankLab/UI/DrillCatalog.h` (C, đã thêm vào bridging header): kiểu `BLDrillSpec`, `BLDrillAt/Index/Count`, `BLDrillChapterDrills`, `BLDrillChapterKey` (khoá chương ổn định), `BLDrillLayoutFor` (xê dịch bi cái theo lượt, tất định), **`BLDrillJudge`** (luật chấm duy nhất cho app và máy chấm), `BLDrillStars`, `BLDrillPassPercent/PassMade`, `BLDrillDiamonds` (toạ độ theo nút cho thẻ bàn thật).
- `BankLab/UI/DrillCatalogData.h`: **sinh tự động**, không sửa tay. Nguồn: `Tools/drills/catalog.py` + `Tools/drills/measured.json`.
- `BankLab/Core/DrillCheck.hpp`: máy chấm (mô phỏng Config::app, tìm lời giải mẫu, đo tỉ lệ vào với sai số người chơi).
- `Tests/DrillCatalogTests.cpp` (đăng ký CMake + Run-All-Checks; 811 kiểm, ~27 s): bố cục cũ giữ nguyên từng số, luật chấm khớp `finishShot` ≤ 0.48, mọi bài có lời giải, tỉ lệ đo không trôi, thế bi xê dịch vẫn giải được, thang không dễ ngược.
- `Run-All-Checks.command`: thêm `gen_catalog.py --check`.
- Quy trình thêm/sửa bài: sửa `catalog.py` → `Tools/drills/drill_sweep.sh [key…]` (~10 phút cho cả kho) → commit cả 3 file.

## Việc của phiên Mac
**X1. Nạp kho bài từ C** (sau cờ `FeatureFlags.drillCatalog`, mặc định bật; tắt = danh sách Swift cũ).
- `Drill.all` = 3 công cụ (giữ nguyên) + các bài lấy từ `BLDrillAt(i)`: thế bi, góc, đích, `tipTop`, `kind/rails`. Tiêu đề/ghi chú/hệ số lấy từ bảng chữ theo `key` (X6). `Drill.id` = `key`.
- Chỉ số cũ dùng cho cờ QA và trạng thái đã lưu: giữ thứ tự tra cứu bằng `key`, không bằng chỉ số.
- `Chapters.all` dựng từ `BLDrillChapterDrills`. Bỏ bảng `Chapters.difficulty` (đoán) → `BLDrillStars`.
- **Khoá thi chương:** `examBest` đổi từ `"chapter-n"` sang `BLDrillChapterKey(n)`. Chuyển dữ liệu cũ một lần: `chapter-1` → `straight-speed` + `stop-follow-draw`; `chapter-2` → `straight-speed`; `chapter-3` → `cut`; `chapter-5` → `kick` + `bank`; `chapter-6` → `special`; `chapter-4` bỏ. Có test Swift.
- Nghiệm thu: UI test mở 9 chương, mỗi chương ≥ 2 bài; người chơi cũ giữ sao (khoá bài không đổi).

**X2. Chấm cú bằng `BLDrillJudge`** trong `TC+ShotLoop.finishShot` (thay 3 nhánh if hiện có; thêm loại An toàn). Đổi sự kiện `[kind,a,b]` và bi cuối `[id,x,y,sunk]` sang mảng C. Hết giờ vẫn là không đạt (kiểm trước khi gọi).

**X3. Thế bi xê dịch.** Cú thứ k trong lượt (k = 0…) dùng `BLDrillLayoutFor(spec, k, &L)`: cú đầu đúng bố cục gốc; thi chương, mã thách bạn, Bài hôm nay cú đầu dùng biến thể 0; bài có `jitter = 0` không đổi. Góc ngắm mặc định = `L.angle`. Replay phải lưu biến thể.

**X4. Sơ đồ bài (`DrillPreviewView`) và bàn 3D lúc tải bài.** Nền sơ đồ: xem G1 trong `NHIEM-VU-0.49c-GIAO-DIEN.md` (ảnh từ trên cao của chính bàn trong game).
- Vòng đích nét đứt vàng (`goalR > 0`).
- Lỗ đích: vòng sáng quanh lỗ mà lời giải mẫu đưa bi 1 vào (tính một lần bằng `predict` với `solveAngle/Speed/Top`).
- Số nút trên băng: dài 0…8, ngắn 0…4 (cỡ chữ 10, mờ 70 %).
- Bài Đi bi: bi id 2 vẽ vàng nhạt, chữ "2", chú thích "bi kế tiếp" (không phải "bi cản").
- **Đường lời giải mờ:** KHÔNG hiện trên bàn khi đánh ở chế độ chính (CLAUDE.md). Chỉ ở sơ đồ, sau khi đã chơi bài ≥ 1 lượt, hoặc khi bấm "Xem lời giải" trong chế độ Coach.
- Ảnh "phòng chuẩn" trước/sau cho 4 bài: `stop-hold`, `cut-side-30`, `kick3-corner5`, `pos-follow`. Sửa đầu dò ảnh `drill-list` (đang chụp trúng intro).

**X5. Mẹo một dòng + "Xem thêm".** Màn bài: tiêu đề, mục tiêu, sơ đồ, **một dòng mẹo của chương**, nút Bắt đầu. Công thức dài, cách chấm, video chuyển xuống "Xem thêm" (thu gọn). Sổ mẹo dùng mẹo mới (X6).

**X6. Chữ (vi nguồn, en trong `i18n.json`).** Bảng ở mục "Chữ" dưới đây. Bài cũ giữ tiêu đề cũ (khoá không đổi). `check_vi_en.py` phải PASS.

**X7. Thẻ "Ra bàn thật"** (nút trên màn bài).
- Xếp bi theo nút: mỗi bi một dòng `"Bi cái: nút dài 2,3 · nút ngắn 1,1"` (`BLDrillDiamonds`, bàn 9 ft; bàn 7–8 ft ghi "đo theo nút, không theo cm").
- Mục tiêu + mẹo chương + "Đánh 10 cú, ghi số cú đạt".
- Nhập số đạt (0–10, nút +/−), lưu `PlayerStore.realTable[key] = [(ngày, đạt)]`.
- Màn Tiến bộ: mỗi bài hai cột "Trong app / Bàn thật" (10 lần gần nhất).

**X8. Thử thách phụ** (hiện sau khi bài đã Đạt; mỗi cái một huy hiệu nhỏ trên thẻ bài):
- "3 cú liên tiếp" (mọi bài).
- "Vùng nhỏ" (bài có vòng đích: chấm với `goalR × 0,6`; làm bản sao spec rồi gọi `BLDrillJudge`).
- "Không Coach" (đạt lượt không bật Coach).

## Quyết định của chủ dự án (đã chấp thuận 21/11 09:39)
- **D1 · Mức Đạt theo độ khó:** `BLDrillPassPercent` = tỉ lệ đo − 15 điểm, trong khoảng 20–70 %. Thay luật phẳng 70/80/90 của 0.49 L1 cho mức Đạt (Giỏi/Xuất sắc vẫn +10/+20 điểm). Mặc định: dùng.
- **D2 · Chương Bank không chặn chương sau** cho tới khi kiểm lại vật lý băng (xem "Phát hiện"). Mặc định: không chặn.

## Phát hiện từ máy chấm (VERIFIED trên mô phỏng; chưa xác minh trên thiết bị)
1. **Bank 1–3 băng gần như không đạt được:** lời giải mẫu chỉ còn cửa ngắm ~0,05–0,1°; người chơi CLB mô phỏng vào 2–3 %. Bank 3 băng cũ chỉ có lời giải ở 2,8–3,4 m/s. Hoặc bố cục quá khó, hoặc mô hình băng (A1, β 0,30) quá nhạy với góc. Cần một việc vật lý riêng: so độ rộng cửa bank với số liệu đã công bố.
2. **Trô yếu:** bi cái ở 0,69 m chỉ lùi được ~8–12 cm (spinDecay 11 trong Config::app). Bài "Trô · Lùi vào vùng" cũ đo được 8 %; đã dời vòng đích từ (0,17; 0,31) về (0,24; 0,45). Cần so quãng lùi với số liệu của Dr. Dave.
3. "Cắt 15°" khó hơn "Cắt 30°" (48 % so với 55 %) vì bi cái dễ theo vào lỗ. Thang chương 3 xếp theo số đo.
4. Kick dễ hơn tưởng nếu chỉ tính cửa ngắm; đã cho sai số ngắm kick/bank tăng theo số băng (0,6° + 0,3°/băng, GIẢ ĐỊNH).

## Bảng đo (sai số người chơi GIẢ ĐỊNH: ngắm σ 0,3°, lực 6 %, điểm chạm 0,06 R; * = không quét, giá trị giả định)
| Chương | Bài | Vào | Sao | Đạt (D1) |
|---|---|---|---|---|
| 1 | `first-shot` | 100 % | 1 | 7/10 |
| 1 | `speed-1` | 57 % | 3 | 5/10 |
| 1 | `speed-2` | 59 % | 3 | 5/10 |
| 1 | `speed-3` | 58 % | 3 | 5/10 |
| 2 | `stop-hold` | 68 % | 2 | 6/10 |
| 2 | `follow-zone` | 52 % | 3 | 4/10 |
| 2 | `draw-zone` | 24 % | 5 | 2/10 |
| 3 | `cut-side-30` | 75 % | 2 | 6/10 |
| 3 | `cut-30-r` | 55 % | 3 | 4/10 |
| 3 | `cut-15-r` | 48 % | 3 | 4/10 |
| 3 | `cut-45-l` | 34 % | 4 | 2/10 |
| 3 | `cut-60-r` | 34 % | 4 | 2/10 |
| 4 | `cue-path-30` | 57 % | 3 | 5/10 |
| 4 | `cue-path-90` | 51 % | 3 | 4/10 |
| 4 | `cue-path-2rail` | 20 % | 5 | 2/10 |
| 5 | `pos-stop` | 54 % | 3 | 4/10 |
| 5 | `pos-follow` | 52 % | 3 | 4/10 |
| 5 | `pos-draw` | 20 % | 5 | 2/10 |
| 6 | `kick1-mirror-a` | 99 % | 1 | 7/10 |
| 6 | `kick1-blocker` | 91 % | 1 | 7/10 |
| 6 | `kick1-mirror-b` | 83 % | 2 | 7/10 |
| 6 | `kick1-blocker-far` | 71 % | 2 | 6/10 |
| 6 | `kick2-plus` | 72 % | 2 | 6/10 |
| 6 | `kick2-double-mirror` | 70 % | 2 | 6/10 |
| 6 | `kick2-blocker` | 70 % | 2 | 6/10 |
| 6 | `kick3-blocker-high` | 59 % | 3 | 5/10 |
| 6 | `kick3-corner5` | 58 % | 3 | 5/10 |
| 6 | `kick3-blocker-mid` | 56 % | 3 | 5/10 |
| 6 | `kick4` | 14 % | 5 | 2/10 |
| 7 | `bank-cross-side` | 28 % | 4 | 2/10 |
| 7 | `bank1` | 3 % | 5 | 2/10 |
| 7 | `bank2` | 2 % | 5 | 2/10 |
| 7 | `bank3` | 2 % | 5 | 2/10 |
| 8 | `safe-behind` | 87 % | 1 | 7/10 |
| 8 | `safe-tuck` | 78 % | 2 | 7/10 |
| 9 | `trick-combo` | 100 % | 1 | 7/10 |
| 9 | `trick-jump` | 35 %* | 4 | 2/10 |
| 9 | `trick-kick3-cluster` | 21 % | 5 | 2/10 |
| 9 | `trick-masse` | 15 %* | 5 | 2/10 |
| 9 | `trick-reverse-zigzag` | 15 %* | 5 | 2/10 |

## Chữ (vi nguồn · en)
**Chương** (tiêu đề · mẹo một dòng · dòng thêm):
1. Cú thẳng và lực · Lực là quãng lăn · Gấp đôi quãng: lực chỉ cần ×1,4 — *Straight shots and pace · Pace is distance · Twice the distance needs only 1.4× the pace*
2. Dừng – theo – lùi · Trên tâm theo, dưới tâm lùi · Bi cái càng xa, xoáy dưới càng hao — *Stop, follow, draw · Hit high to follow, low to draw · The farther the cue ball travels, the more draw it loses*
3. Ngắm cắt · Nửa bi = 30° · Đánh chậm: cắt mỏng hơn một chút — *Cut shots · Half-ball hit = 30° cut · At slow pace, cut a little thinner*
4. Đường bi cái · Bi trượt đi 90°, bi lăn lệch 30° · Đánh chắc tay hơn, bi cái gần 90° hơn — *Cue-ball path · Stun goes 90°, roll goes 30° · Hit firmer and the cue ball stays closer to 90°*
5. Đi bi · Ăn bi này, nghĩ bi sau · Chừa một góc cắt nhẹ, đừng thẳng tuyệt đối — *Position play · Pot this ball, plan the next · Leave a slight angle, not dead straight*
6. Kick băng · Gương và số nút · Corner-5: số bi cái − số đích = số ngắm — *Kick shots · Mirror and diamonds · Corner-5: cue number − target number = aim number*
7. Bank · Góc vào bằng góc ra · Bank mạnh về ngắn hơn, bank nhẹ về dài hơn — *Bank shots · Angle in equals angle out · Hard banks come up short, soft banks run long*
8. An toàn · Chạm nhẹ, giấu bi · Chạm bi 1 trước, không bi nào vào lỗ — *Safety play · Touch lightly, hide the ball · Hit ball 1 first and pocket nothing*
9. Kỹ thuật đặc biệt · Dựng cơ: bi bay hoặc cong · (giữ dòng cũ) — *Special shots · Raise the cue: jump or curve*

**Bài mới** (tiêu đề · ghi chú):
- `cut-15-r` Cắt phải 15° vào lỗ góc · Cắt dày: bi cái dễ theo vào lỗ, đánh hơi dưới tâm. — *15° cut, corner pocket · A thick cut: the cue ball likes to follow in, so hit slightly below centre.*
- `cut-side-30` Cắt 30° vào lỗ giữa · Lỗ giữa hẹp hơn: ngắm vào giữa miệng lỗ. — *30° cut into the side pocket · The side pocket is tighter: aim at the middle of the opening.*
- `cut-60-r` Cắt mỏng 60° vào lỗ góc · Chạm rất mỏng: bi ma gần như cạnh bi 1. — *Thin 60° cut, corner pocket · A very thin hit: the ghost ball sits almost beside ball 1.*
- `cue-path-30` Quy tắc 30° · Bi lăn · Đánh trên tâm, lực vừa: bi cái lệch khoảng 30° rồi dừng trong vòng. — *30° rule · Rolling ball · Hit above centre at medium pace: the cue ball veers about 30° and stops in the circle.*
- `cue-path-90` Quy tắc 90° · Bi trượt · Cùng thế bi. Đánh chắc tay hơn để bi cái còn trượt khi chạm: nó đi theo đường 90°. — *90° rule · Stun · Same layout. Hit firmer so the cue ball is still sliding at contact: it leaves on the 90° line.*
- `cue-path-2rail` Cắt 45° · Bi cái 2 băng · Bi 1 vào lỗ, bi cái chạm 2 băng rồi dừng trong vòng. — *45° cut · Two rails · Pot ball 1; the cue ball takes two rails and stops in the circle.*
- `pos-stop` Đi bi · Dừng lấy góc · Ăn bi 1, bi cái dừng trong vòng: từ đó bi 2 có góc dễ vào lỗ giữa trái. — *Position · Stop for the angle · Pot ball 1 and stop in the circle: ball 2 then has an easy angle into the left side pocket.*
- `pos-follow` Đi bi · Theo lấy góc · Ăn bi 1, theo tới vòng: bi 2 cắt vào lỗ góc trên phải. — *Position · Follow for the angle · Pot ball 1 and follow into the circle: ball 2 is a cut into the top-right corner.*
- `pos-draw` Đi bi · Lùi lấy góc · Ăn bi 1, lùi về vòng: bi 2 gần thẳng vào lỗ góc dưới trái. — *Position · Draw for the angle · Pot ball 1 and draw back to the circle: ball 2 is almost straight into the bottom-left corner.*
- `bank-cross-side` Bank chéo vào lỗ giữa · Bi 1 chạm băng phải rồi chéo sang lỗ giữa trái. — *Cross-side bank · Ball 1 hits the right rail and crosses into the left side pocket.*
- `safe-behind` An toàn · Giấu sau bi cản · Chạm bi 1 trước, không bi nào vào lỗ; cuối cú, bi 2 chắn giữa bi cái và bi 1. — *Safety · Hide behind the blocker · Hit ball 1 first and pocket nothing; at the end, ball 2 sits between the cue ball and ball 1.*
- `safe-tuck` An toàn · Đẩy bi 1 ra sau · Như trên, bi cản ở phía xa. — *Safety · Tuck ball 1 away · Same goal, with the blocker farther away.*

**Thẻ bàn thật:** "Ra bàn thật" · "Xếp bi theo nút (bàn 9 ft)" · "Bi cái: nút dài %@ · nút ngắn %@" · "Đánh 10 cú, ghi số cú đạt" · "Lưu" — *Try it on a real table · Set the balls by the diamonds (9 ft table) · Cue ball: long rail %@ · short rail %@ · Shoot 10, enter how many you made · Save*. Nút dài đếm từ băng ngắn phía dưới màn hình (0) lên trên (8); nút ngắn từ trái (0) sang phải (4).
**Thử thách phụ:** "3 cú liên tiếp" · "Vùng nhỏ" · "Không Coach" — *Three in a row · Small target · No Coach*.

## Thứ tự làm và nghiệm thu
X1 → X2 → X3 (một commit mỗi mục, test Swift kèm) → X6 → X4 → X5 → X7 → X8. `bash Tools/accept_local.sh` sau X3 và cuối cùng. Báo cáo `NGHIEM-THU-0.49b.md`: mỗi mục PASS / FAIL / NOT RUN, ảnh trước/sau X4, phần chưa xác minh trên thiết bị.
