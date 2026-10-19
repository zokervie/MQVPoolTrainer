# Kế hoạch nâng cấp — bản đã phê duyệt

Cập nhật theo REVIEW.md mục H và các điều kiện bổ sung ngày 18/10/2026; **lập lại ngày 19/10/2026** theo mục tiêu nhanh, chất lượng, ít tốn kém (mục 2, 5; D6–D8). Nhiệm vụ cụ thể nằm trong PROGRESS.md.

## 1. Quyết định đã chốt

| # | Quyết định | Điều kiện kèm theo |
|---|---|---|
| D1 | **Định vị sản phẩm:** luyện mắt, tư duy và khả năng dự đoán đường bi. Không tuyên bố luyện động tác ra cơ ngoài đời. | Mọi mô tả sản phẩm, màn hình giới thiệu, App Store phải theo đúng định vị này. |
| D2 | **Natural Stroke** là chế độ chính. **Manual Stroke đổi thành Shot Lab** (phân tích, tái hiện cú, bài tập quyết định). | Phải đo tính nhất quán của thao tác cảm ứng (KPI U4–U5). Cú vuốt không hiệu chỉnh theo tốc độ đầu cơ thật. |
| D3 | **pooltool** làm đối chứng độc lập. | Giấy phép Apache-2.0 đã thấy trên trang GitHub của dự án (18/10/2026). **Chưa xác minh:** phiên bản cụ thể, cơ chế va chạm đồng thời, bộ giải bậc bốn — phải đọc mã nguồn và ghi số phiên bản/commit trước khi dùng. Khi tham khảo mã: giữ thông báo bản quyền và file NOTICE theo Apache-2.0. |
| D4 | **Phạm vi vật lý MVP:** hướng bi mục tiêu, throw, phản hồi băng (theo tốc độ và xoáy), squirt, hình học lỗ. Cơ cố định gần nằm ngang. | Hoãn swerve, truyền xoáy, massé, nhảy bi cho đến khi có bằng chứng cần thiết. Nhảy bi/massé đã có code (19/10, làm sớm): giữ ở chế độ thử nghiệm, không tính vào cổng, không phát triển thêm. |
| D5 | **Kiểm chứng bằng video 240 fps + máng lăn**, tách tập hiệu chỉnh/kiểm chứng. | Bắt buộc: sửa méo ống kính, kiểm soát sai số phối cảnh, xử lý độ cao tâm bi, báo cáo độ không chắc chắn của phép đo (mục 3.3). |
| D6 | **Một sản phẩm:** Zoker là sản phẩm chính. Bản 3.1 (`main`) đóng băng, chỉ để tham khảo. | Không sửa `main` từ phiên Zoker. |
| D7 | **Hai cổng:** Cổng Beta (tầng 1 + 2 + máy thật) cho phép phát cho người chơi thử; Cổng Chân thật (tầng 3) mới cho phép tuyên bố "vật lý chân thật". | Bản beta luôn ghi "chưa kiểm chứng trên bàn thật". |
| D8 | **Một đường phát hành:** GitHub Actions → IPA → ESign. Codemagic/runner Mac là dự phòng. TestFlight khi có tài khoản Apple Developer. | — |

## 2. Nguyên tắc làm việc
1. Không viết lại từ đầu, không xóa tính năng đang chạy.
2. Không đánh dấu xong khi chưa build và chạy test thật. Không có macOS/Xcode/thiết bị thì ghi rõ "chưa xác minh"; kiểm tra cú pháp không được coi là build thành công.
3. Không dùng thông số chưa có nguồn. Mỗi tham số mang nhãn: đã công bố / đã đo / giả định.
4. Giữ Swift + RealityKit; chỉ đổi công nghệ khi có benchmark.
5. **Quy tắc do máy cưỡng chế, không dựa vào tự giác:** một nhiệm vụ = một nhánh nhỏ, CI xanh mới gộp, một agent ghi, chỉ làm việc thuộc mốc hiện tại (CLAUDE.md).
6. Hai engine cho kết quả giống nhau **không** chứng minh đúng với thực tế. Chỉ dữ liệu bàn thật mới kiểm chứng được vật lý.
7. **Người chơi sớm:** mỗi mốc kết thúc bằng một bản IPA chơi được và một vòng thử ≤ 15 phút. Phản hồi người chơi quyết định việc tiếp theo, không phải danh sách tính năng.
8. **CI tiết kiệm:** commit chỉ sửa tài liệu không chạy macOS; bộ 10.000 cú và đối chứng pooltool chỉ chạy khi vật lý thay đổi; ảnh simulator chỉ khi app thay đổi; IPA chỉ build trên nhánh chính.

## 3. Ba tầng kiểm chứng (tách biệt, báo cáo riêng)

### 3.1 Tầng 1 — Toán học (`swift test` trên Mac)
Chứng minh: code làm đúng công thức đã chọn. **Không** chứng minh công thức đúng với bàn thật.

| KPI | Ngưỡng | Loại |
|---|---|---|
| M1. Khớp nghiệm giải tích (quãng lăn, 5/7, 90°, 30°) dưới đúng giả thiết của từng nghiệm — xem ghi chú M1 | Sai số tương đối ≤ 1e-6 | Bắt buộc |
| M2. Tính lặp lại | Giống từng bit, cùng seed, cùng máy | Bắt buộc |
| M3. Không chồng lấn | < 1e-6 m trên 10.000 cú ngẫu nhiên có seed (gồm phá bi) | Bắt buộc |
| M4. Động năng (tịnh tiến + quay) của toàn bộ bi | Không tăng qua mọi sự kiện **sau khi** cú ra cơ đã kết thúc truyền xung lực. Không áp dụng cho chính sự kiện cơ chạm bi (cơ là nguồn năng lượng ngoài). | Bắt buộc |
| M5. Động lượng cặp bi | Bảo toàn ±1e-9 ngay trước/sau va chạm bi–bi cô lập | Bắt buộc |
| M6. Giới hạn số sự kiện | 0 cú chạm giới hạn trong bộ 10.000 cú | Bắt buộc |
| M7. Độ nhạy với thứ tự xử lý va chạm gần đồng thời | Báo cáo độ phân tán vị trí dừng khi hoán vị thứ tự xử lý trong cùng cửa sổ Δt; ngưỡng đặt sau khi có số liệu R1.5 | Bắt buộc báo cáo |

**Ghi chú M1 — giả thiết của các nghiệm giải tích.** Đây là kiểm tra code đúng công thức trong điều kiện lý tưởng, **không** phải kết quả phổ quát:
- *Quãng lăn* d = v₀²/(2·μr·g): bi lăn thuần túy từ đầu, cản lăn hằng số, không băng.
- *Quy tắc 5/7:* bi trượt không xoáy (stun) trên nỉ, ma sát trượt Coulomb hằng số, chỉ đúng tại thời điểm chuyển sang lăn.
- *Quy tắc 90°:* bi cái trượt không xoáy tại thời điểm va chạm, hai bi cùng khối lượng, va chạm đàn hồi hoàn toàn (e = 1), không ma sát bi–bi; góc 90° là hướng ngay sau va chạm, trước khi ma sát nỉ làm cong đường bi cái.
- *Quy tắc 30°:* bi cái lăn thuần túy tại thời điểm va chạm, va chạm nửa bi (góc cắt 30°), cùng khối lượng, e = 1, không ma sát bi–bi (không throw); 33,7° là góc lệch **cuối** của bi cái sau khi lăn trở lại. Ngoài đời, quy tắc 30° chỉ là xấp xỉ trong một khoảng độ dày va chạm; e < 1, throw và bi chưa lăn hoàn toàn đều làm góc thay đổi [TL: Alciatore].

### 3.2 Tầng 2 — Đối chứng pooltool (Mac, `Tools/validation/`)
Chứng minh: cài đặt của ta nhất quán với một cài đặt độc lập dùng mô hình tương tự. Phát hiện lỗi lập trình. **Không** thay thế tầng 3.

| KPI | Ngưỡng | Loại |
|---|---|---|
| P1. Vị trí dừng, cú không xoáy ngang | ±5 mm trên 200 cú, cùng tham số | Mục tiêu |
| P2. Hướng bi mục tiêu sau va chạm | ±0,1° | Mục tiêu |
| P3. Mọi khác biệt vượt ngưỡng | Có giải thích (khác mô hình hay lỗi) và test tái hiện | Bắt buộc |

Ghi số phiên bản/commit pooltool trong mỗi báo cáo.

### 3.3 Tầng 3 — Thực nghiệm bàn thật

**Bước bắt buộc trước khi đo:**
1. **Sửa méo ống kính:** hiệu chỉnh camera bằng bàn cờ in (ước lượng ma trận nội và hệ số méo) cho đúng ống kính, độ phân giải và chế độ quay sẽ dùng. Lưu file hiệu chỉnh kèm dữ liệu.
2. **Phối cảnh và độ cao tâm bi:** tâm bi nằm cao hơn mặt nỉ một bán kính (~28,6 mm). Phép chiếu phối cảnh dựng từ mốc trên mặt nỉ phải hiệu chỉnh sang mặt phẳng z = R (hoặc dựng trực tiếp trên mặt phẳng đó); với camera nghiêng, bỏ qua bước này gây sai lệch hệ thống.
3. **Đo độ không chắc chắn của hệ đo:**
   - Bi đứng yên: độ dao động vị trí tâm qua 240 khung hình.
   - Khoảng cách đã biết: đo lại khoảng cách giữa các mốc kim cương, so với thước.
   - Hướng đã biết: bi lăn dọc một thước thẳng đặt sẵn, so hướng đo được.
   - Kết quả: độ không chắc chắn mở rộng (k = 2) của **góc hướng** và **vị trí**.
4. **Quy tắc tuyên bố đạt KPI:** chỉ tuyên bố đạt một ngưỡng khi độ không chắc chắn đo (k = 2) ≤ 1/3 ngưỡng đó. Ví dụ KPI 0,5° cần hệ đo ≤ ~0,17°. Không đạt điều kiện này thì báo cáo "chưa kiểm chứng được", không báo "đạt".

**Thiết kế dữ liệu:** mỗi thí nghiệm ≥ 20 lần; gán ngẫu nhiên 50% hiệu chỉnh / 50% kiểm chứng **trước khi** xem kết quả; chỉ hiệu chỉnh tham số riêng của bàn (cản lăn, ma sát trượt, băng, ma sát bi–bi); ghi điều kiện nỉ, bi, nhiệt độ, độ ẩm.

**KPI (ngưỡng kỹ thuật ban đầu, chưa phải chuẩn khoa học đã xác nhận; chỉ tính trên tập kiểm chứng):**

| KPI | Ngưỡng | Báo cáo kèm | Loại |
|---|---|---|---|
| T1. Hướng bi mục tiêu | Sai số tuyệt đối **trung vị ≤ 0,5°** và **p90 ≤ 1,0°** | Bias (sai số có dấu) theo nhóm góc cắt 0–15°, 15–30°, 30–45°, 45–60° và nhóm tốc độ chậm/vừa/nhanh | Bắt buộc (Cổng 1) |
| T2. Quãng lăn | Sai số tương đối trung vị ≤ 10% | Theo độ cao máng | Bắt buộc |
| T3. Góc bật băng (bi lăn) | Trung vị ≤ 3° | Theo góc tới và tốc độ | Bắt buộc |
| T4. Tốc độ sau băng | Trung vị ≤ 10% | | Mục tiêu |
| T5. Vị trí dừng bi cái, cú 1 băng lực vừa | Trung vị ≤ 10 cm | | Bắt buộc |
| T6. Hướng sau băng khi có xoáy ngang | Trung vị ≤ 2° | | Mục tiêu |

## 4. KPI trải nghiệm và hiệu năng (thiết bị thật)

| KPI | Ngưỡng | Điều kiện đo | Loại |
|---|---|---|---|
| U1. **Độ trễ thao tác → bi chuyển động** | p95 < 100 ms | Quay màn hình bằng camera ngoài 240 fps: từ khung ngón vượt vạch chạm bi đến khung bi bắt đầu dịch chuyển; 50 lần, máy thấp nhất được hỗ trợ | Bắt buộc |
| U2. Phát lại cảm ứng thô → cùng CueStrike | Giống hệt | Tự động | Bắt buộc |
| U3. Khóa nhầm / chạm khóa bị bỏ lỡ | < 1 / 100 cú · < 2% | 5 người × 100 cú, cầm máy tự nhiên | Bắt buộc |
| U4. Độ đều lực "vừa" | Hệ số biến thiên tốc độ cơ của 10 cú ≤ 10% sau 15 phút làm quen | 5 người | Mục tiêu (giả thuyết) |
| U5. Độ thẳng cú vuốt | Báo cáo phân bố lệch ngang | Như U4 | Đo, chưa đặt ngưỡng |
| H1. Thời gian mô phỏng một cú | p95 ≤ 50 ms (bắt buộc), ≤ 10 ms (mục tiêu) | Release build; 1.000 cú phá + 1.000 cú ngẫu nhiên có seed; bỏ 50 cú khởi động; bắt đầu ở thermal `.nominal`; `ContinuousClock`; báo p50/p95/max; ngoại lệ > p99 giữ lại kèm seed | Như cột ngưỡng |
| H2. Thời gian khung hình p99 khi bi chạy | ≤ 16,7 ms | Máy mục tiêu, 10 phút | Bắt buộc |
| H3. Bộ nhớ sau 30 phút | < 400 MB, không tăng dần | Instruments | Bắt buộc |
| H4. Nhiệt 30 phút | Không đạt `.serious` | Máy mục tiêu | Mục tiêu |

Thiết bị: thấp nhất được hỗ trợ (đề xuất iPhone 12 / A14) và máy mục tiêu (iPhone 15 Pro).

## 5. Lộ trình (lập lại 19/10/2026)

Mốc ngắn, mỗi mốc ra một bản chơi được. Hai luồng song song: **Claude** (code, CI) và **người dùng** (thử máy, đo bàn). Mã nhiệm vụ cũ (R0–R7) giữ nguyên trong PROGRESS.md để tra cứu.

| Mốc | Mục tiêu | Việc chính (mã cũ) | Ra | Cổng |
|---|---|---|---|---|
| M0 | Dọn quy trình (19/10) | Quy tắc mới, CI tiết kiệm, đóng băng | — | — |
| M1 | **Beta nội bộ** (~1 tuần) | Xác nhận R2.1–R2.6 trên máy bằng danh sách có/không; app tự ghi H1–H3 (+ nhiệt); R1.8 (P2, P3 miệng lỗ); sửa lỗi chặn | IPA 0.4 | **Cổng Beta:** M1–M6 đạt · P1 đạt · P3 có giải thích + test · không lỗi chặn trên iPhone · H1 p95 ≤ 50 ms trên máy |
| M2 | **Beta 3–5 người chơi** (~1–2 tuần) | Bật 10 bài tập (R5) có nhãn "chưa kiểm chứng bàn thật"; xuất phản hồi + số liệu cú (U3–U5); chỉnh điều khiển theo số liệu. Song song: hiệu chỉnh camera ở nhà (R4.1–R4.3) | IPA 0.5 | — |
| M3 | **Bàn thật** (1 buổi + xử lý) | Máng lăn, thí nghiệm 1–4, hiệu chỉnh, báo cáo (R4.4–R4.6); nạp CalibrationProfile | IPA 0.6 có hồ sơ bàn đo thật | **Cổng Chân thật:** T1, T2, T3, T5 (mục 3.3) |
| M4 | **Phát hành** | TestFlight/ESign rộng; thử nghiệm chuyển giao (R6); U1, A4 đo trên máy | 1.0 | Cổng 2 cũ (R6) |
| Sau | Mở rộng | R7: đồ họa, âm thanh bậc B, swerve/nhảy/massé chính thức, ý tưởng docs/06, docs/08 | — | Theo KPI mục tiêu |

Không qua Cổng Chân thật → quay lại vật lý (R3), vẫn được phát beta với nhãn "chưa kiểm chứng", không tuyên bố "chân thật".

## 6. Zoker Acoustic Physics (module âm thanh)

### 6.1 Mục tiêu và giới hạn
- Mô phỏng âm thanh bàn bida thật, đặc biệt khác biệt tự nhiên giữa va chạm nhẹ và mạnh, để âm thanh trở thành **tín hiệu cảm nhận tốc độ** bổ sung cho mắt.
- Âm thanh là **phản hồi**, không phải nguồn dữ liệu: không ảnh hưởng vật lý, không làm thay đổi kết quả cú đánh.
- Không tuyên bố chất lượng âm thanh đã kiểm chứng khi chưa nghe thử trên thiết bị thật (A6–A8).

### 6.2 Kiến trúc
```
PoolPhysics (Trajectory + CollisionRecord)
      │  dữ liệu thuần, đã tính trước cả cú
      ▼
AudioEvent          ← ánh xạ thuần, không AVFoundation (testable)
      ▼
AudioScheduler      ← lịch phát xác định: gộp, giới hạn giọng, chọn biến thể, tham số
      ▼
SampleLibrary       ← lớp lực × biến thể × loại va chạm, kèm metadata giấy phép
      ▼
AudioEngine         ← AVAudioEngine: player nodes, EQ, environment node, limiter
```
- **Package mới `Packages/PoolAudio`** (tên sản phẩm: Zoker Acoustic Physics): `AudioEvent`, `AudioScheduler`, ánh xạ tham số, mô tả `SampleLibrary` — Swift thuần, test bằng `swift test`. Phần `AVAudioEngine` nằm trong `App/` (hoặc target riêng phụ thuộc AVFoundation) để package lõi vẫn test được không cần thiết bị.
- **Phụ thuộc vào R1:** bộ giải sự kiện phải xuất `CollisionRecord` cho mỗi va chạm. Đã thêm vào R1 trong PROGRESS.md.

### 6.3 AudioEvent (từ dữ liệu PoolPhysics)
| Trường | Nguồn |
|---|---|
| `kind` | `cueTip`, `ballBall`, `ballCushion`, `ballPocketJaw` (thành/mép lỗ), `ballDrop` (rơi lỗ), `miscue` |
| `time` | Thời điểm sự kiện trong timeline mô phỏng (s, Double) |
| `position` | Vị trí va chạm (vật lý), đổi sang không gian nghe qua `RenderMapping` + vị trí camera |
| `relativeNormalSpeed` | Tốc độ tương đối theo pháp tuyến tại va chạm (m/s) |
| `impulse` | Xung lực pháp tuyến J = m·Δvₙ (N·s) |
| `tangentialSlip` | Tốc độ trượt tiếp tuyến (cho tiếng "xì" của throw, miscue) — khi có |
| `materials` | Cặp vật liệu (phenolic–phenolic, phenolic–cao su băng, phenolic–da/kim loại lỗ, da đầu cơ–phenolic) — khi có, từ hồ sơ âm thanh của bàn |
| `sourceIds` | Chỉ số bi liên quan, để chọn biến thể xác định |

Hồ sơ vật liệu âm thanh sẽ là phần mở rộng của `TableDefinition` (tăng `schemaVersion` khi thêm), kèm `Provenance` như tham số vật lý.

### 6.4 Ánh xạ vật lý → âm thanh (không chỉ tăng âm lượng)
| Đặc tính | Điều khiển bởi | Cách làm |
|---|---|---|
| Lớp lực (sample) | Xung lực | Chọn lớp theo ngưỡng log; **trộn chéo** giữa hai lớp gần nhất để không có bậc thang |
| Âm lượng | Xung lực | Theo dB, đường cong log có giới hạn, hiệu chỉnh từ bản thu |
| Transient | Tốc độ pháp tuyến | Va chạm mạnh: tấn công sắc hơn, ngắn hơn; nhẹ: mềm hơn |
| Âm sắc | Xung lực + vật liệu | Bộ lọc thông thấp mở rộng khi va chạm mạnh (va chạm nhẹ tối hơn); cộng hưởng theo vật liệu |
| Định vị | Vị trí so với camera | Loa: pan stereo + suy giảm nhẹ theo khoảng cách; tai nghe: HRTF qua `AVAudioEnvironmentNode` |

Mọi đường cong là hàm thuần trong `PoolAudio`, đơn điệu theo xung lực, có tham số hiệu chỉnh từ bản thu.

### 6.5 Lịch phát, replay và phá bi
- Quỹ đạo đã tính trước → lên lịch toàn bộ cú trước khi bi chạy, phát bằng `AVAudioTime` theo thời gian máy (look-ahead), không phụ thuộc khung hình.
- **Tính xác định:** chọn biến thể bằng hàm băm của (id cú, chỉ số sự kiện, id bi), không dùng ngẫu nhiên lúc chạy. Cùng cú → cùng lịch phát.
- **Phá bi / va chạm dày:** gộp sự kiện cùng loại gần nhau trong cửa sổ vài ms; giới hạn số giọng đồng thời, bỏ giọng yếu nhất khi vượt; limiter trên master. Mục tiêu: không vỡ tiếng, không tràn.
- **Replay:** dùng lại đúng lịch phát. Phát chậm: giãn thời điểm theo tốc độ phát, không đổi cao độ; dưới một tốc độ nhất định chỉ phát va chạm mạnh. Tua: dừng toàn bộ giọng, lên lịch lại từ vị trí mới.
- Đồng bộ với haptic: dùng chung `AudioEvent` cho Core Haptics.

### 6.6 Cài đặt người dùng
Âm lượng hiệu ứng · bật/tắt âm thanh · bật/tắt âm thanh không gian · chế độ tai nghe (HRTF) / loa (stereo) · tôn trọng công tắc im lặng và phiên âm thanh của hệ thống (`AVAudioSession` category phù hợp, không ngắt nhạc người dùng khi không cần).

### 6.7 Mẫu âm thanh và giấy phép
- **Ưu tiên tự thu** trên bàn thật (sở hữu toàn quyền): ≥ 5 lớp lực × ≥ 4 biến thể cho mỗi loại va chạm, micro đặt cố định, ghi tốc độ va chạm đo từ video 240 fps để gắn lớp lực bằng số liệu thật.
- Nguồn ngoài: chỉ dùng mẫu có giấy phép cho phép thương mại; mỗi file có bản ghi giấy phép (nguồn, giấy phép, ngày tải, bằng chứng) trong `SampleLibrary`, giống `Provenance`.
- R2 dùng bộ mẫu tạm có giấy phép thương mại rõ ràng hoặc mẫu tự tạo; ghi rõ là tạm.

### 6.8 KPI âm thanh
| KPI | Ngưỡng | Điều kiện đo | Loại |
|---|---|---|---|
| A1. Ánh xạ đơn điệu | Âm lượng, độ sáng âm sắc, lớp lực không giảm khi xung lực tăng | Unit test quét xung lực | Bắt buộc |
| A2. Lịch phát xác định | Cùng cú → cùng danh sách (thời điểm, sample, tham số) | Unit test, 1.000 cú có seed | Bắt buộc |
| A3. Không tràn khi phá bi | Đỉnh master ≤ −1 dBFS, số giọng ≤ giới hạn | Render offline 1.000 cú phá | Bắt buộc |
| A4. Lệch âm thanh–hình ảnh | ≤ ±10 ms trung vị | Camera 240 fps quay màn hình + thu âm, 50 cú | Bắt buộc |
| A5. Giấy phép | 100% sample có bản ghi giấy phép thương mại | Kiểm tra tự động trong test | Bắt buộc |
| A6. Phân biệt lực bằng tai | Người chơi xếp đúng thứ tự 3 mức lực chỉ bằng âm thanh ≥ 80% | 5 người chơi bida, thiết bị thật, tai nghe và loa | Mục tiêu (bậc B) |
| A7. Độ giống thật | Đánh giá ≥ 4/5; A/B mù với bản thu bàn thật | 5 người chơi bida | Mục tiêu (bậc B) |
| A8. Tài nguyên | Bộ mẫu ≤ 30 MB; không gây vượt H2 | Instruments trên máy thấp nhất | Bắt buộc (bậc B) |

### 6.9 Phân bậc
- **Bậc A (R2):** `PoolAudio` (AudioEvent, ánh xạ, AudioScheduler, mô tả SampleLibrary), engine phát cơ bản, cài đặt, bộ mẫu tạm, A1–A5.
- **Bậc B (R7):** thu mẫu bàn thật, tinh chỉnh âm sắc theo vật liệu, HRTF và âm thanh không gian nâng cao, A6–A8.
