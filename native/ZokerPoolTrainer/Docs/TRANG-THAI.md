# TRẠNG THÁI DỰ ÁN — đọc file này ĐẦU TIÊN mỗi phiên (cập nhật 16/11/2026)

Cách dùng: phiên mới chỉ cần đọc file này + tin nhắn mới nhất của anh. Cuối phiên cập nhật lại file này, và bản trong Project `claude/zoker-trang-thai.md`.

## 1. Bản và nhánh
| Bản | Nhánh / commit | Trạng thái |
|---|---|---|
| 0.40b | `ci/native-0.40b` @ 1626168 | CI 132 xanh (PASSED_SIMULATOR_UNSIGNED). IPA: artifact `zoker-ipa-candidate-132`. Anh đã nghiệm thu 12/11 23:36 |
| 0.41 (gồm 0.40c) | `cho/native-0.40c` → build `ci/native-0.41` | Anh dặn gộp 0.40c + 10 mục ngày 13/11 vào MỘT lần build. CI 136 @452f1fe: 6/7 cổng PASS, chỉ test UI xem lại hỏng do test cũ chờ đồng hồ âm (xem lại giờ chỉ 1 s). IPA `zoker-ipa-candidate-136` đã gửi anh thử. Test đã sửa ở 0a41f44, đi cùng lần build sau. Cách thử: `Docs/NGHIEM-THU-0.41.md` + `Docs/CHO-0.40c-NGHIEM-THU-12-11.md` |
| 0.42 | `cho/native-0.40c` → build `ci/native-0.42` | Nghiệm thu 0.41 của anh (12 mục + 5 lỗi chen) + vật lý + AI. **CI 140 xanh (04fc26e, 14/11)**, IPA `zoker-ipa-candidate-140` (run 43478261561). Đã gửi anh — chưa xác minh trên thiết bị. Cách thử: `Docs/NGHIEM-THU-0.42.md` |
| 0.43 | `cho/native-0.40c` @ c472534 → build `ci/native-0.43` | Gom mọi yêu cầu (vật lý 0,55R, squirt thực tế, độ sạch bi, U1–U5, intro Golden Break, hiệu chuẩn 28 mốc). **CI 146 xanh 15/11**, IPA `zoker-ipa-candidate-146` (run 43618001054, artifact 14123266035). Đã gửi anh — chưa xác minh trên thiết bị. Cách thử: `Docs/NGHIEM-THU-0.43.md`; hiệu chuẩn: `Docs/HIEU-CHUAN-VAT-LY-0.43.md` |
| 0.44 | `cho/native-0.40c` → build `ci/native-0.44` | 19 mục sau nghiệm thu 0.43 (thân bàn kín + logo, không bỏ cú + lockstep Wi‑Fi, khuôn đúng luật, bọc nỉ góc, bóng băng, camera đối thủ 2 m + 5 góc action, lùi cú giữ góc, 24 ảnh + đèn tranh, Coach, đặt bi sát băng, highlight, intro VFX, bóng sàn, độ dốc theo tư thế, thanh lực, kính phóng 1 hình, xuất video MP4, bao cơ + 10 mẫu, hướng dẫn dắt tay). Cách thử: `Docs/NGHIEM-THU-0.44.md`. **CI 155 xanh 16/11**, IPA `zoker-ipa-candidate-155` (run 43778517723, artifact 14187895713). Đã gửi anh — chưa xác minh trên thiết bị |
| 0.44-MM | `cho/native-0.44-mm` @ (xem git) — nhánh chờ, KHÔNG CI | Anh giao 16/11: giật khi chơi (đã sửa nguyên nhân gốc: bi hiệu ứng vẽ lại 484 ô đọc solver mỗi ô; khung đầu dồn 100 ms → 16,7 ms), highlight máy khách Wi‑Fi, tiếng lọt lỗ theo tốc độ. accept_local đầy đủ trên Mac (Xcode 26.3) @66be507: 6/7 bước PASS, test UI camera FAIL có từ trước (cũng FAIL ở 9eb77f0) — chờ anh quyết; IPA build riêng PASS. Nearby Play (giao diện phòng + nối lại, 51 test logic) đã làm, chưa xác minh trên 2 máy. Chi tiết: `Docs/NGHIEM-THU-0.44-MM.md`. Chưa xác minh trên thiết bị |
| 0.44.1 | `cho/native-0.44.1` — nhánh chờ, KHÔNG CI | "Ấn tượng đầu" (17/11): Chơi gần nối lại, Cú đầu tiên, đổi tên bàn/cơ Z-…, tranh tường 0/51 → 51/51, cơ một lưới + icon 3D, hướng dẫn 2 nhịp không phủ, intro trên bàn + màn khởi động có logo, 60 Hz mặc định + tự hạ, ngôn ngữ theo máy. accept_local: 5 bước PASS, ảnh + UI test NOT RUN (Simulator treo 20:45). IPA 0.44.1 (25) chưa ký. Chi tiết `Docs/NGHIEM-THU-0.44.1.md` |
| 0.45 | `cho/native-0.45` — nhánh chờ | "Xương sống": điều phối theo vai, đo lượt vẽ SceneKit + `setLinkRate` (dải 60–120 sau cờ), tách TrainingController 3.342 → 598 dòng + 6 file, ZDesign, i18n vi+en 646/646. Portable/replay/LAN/build/IPA PASS; UI test, ảnh, perf NOT RUN (Simulator treo). `Docs/NGHIEM-THU-0.45.md` |
| 0.46 | `cho/native-0.46` — nhánh chờ | "Diện mạo mới": Sảnh mới (Tiếp tục + 4 ô, nền bàn thật mờ), HUD gom Đặt/Thêm bi/Bao cơ vào "Bàn" (Camera giữ riêng), menu trận 4 mục, 4 họ bàn × 3 phối, test 3 cỡ WPA (chọn 8/7 ft chưa mở). Portable FAIL chỉ Opponent (phụ thuộc hạn giờ, mã không đổi); UI/ảnh NOT RUN. `Docs/NGHIEM-THU-0.46.md` |
| 0.47 | `cho/native-0.47` — nhánh chờ | "Quay lại mỗi ngày" + 0.45 M5 (PlayerStore/AppFlow/Prefs/số liệu) + Phòng thí nghiệm: kho bài theo chương, thanh lực, Bài hôm nay + chuỗi, Tiến bộ + Kỷ lục, hiệu ứng khi chơi, phản hồi giảm dần, thách bạn bằng mã. Portable/LAN/build/IPA PASS; UI/ảnh/perf NOT RUN (Simulator treo). `Docs/NGHIEM-THU-0.47.md` |
| 0.49b | `cho/native-0.49-xuong-bai` @68ab4e3 — nhánh chờ, KHÔNG CI | "Xưởng bài" Swift: kho bài từ C (9 chương), chấm BLDrillJudge, thế bi xê dịch, thẻ Ra bàn thật, thử thách phụ, mức Đạt theo độ khó (D1/D2 đã duyệt); sửa 2 test UI hỏng CI 163. accept_local PASSED_SIMULATOR_UNSIGNED (35 UI test 0 lỗi). Chưa xác minh trên thiết bị. Chưa làm: đặt bi 64 pt, giảm chói, relayout hoãn, ảnh trước/sau X4. `Docs/NGHIEM-THU-0.49b.md` |
| 0.49c | `cho/native-0.49-xuong-bai` — nhánh chờ, KHÔNG CI | Giao diện: G8 (công tắc phá 3 bi), G4 (ẩn quang phổ), G6 (nút Đặt bi), G3 (thanh lực nhỏ + zoom + bật/tắt), G7 (không còn lượt bố cục giữa khung, Simulator), G1 (sơ đồ trên ảnh bàn game, dựng offscreen; lần đầu 190–200 ms > đích 150). accept_local đầy đủ PASSED_SIMULATOR_UNSIGNED 8/8 (42 UI test). CHẶN: G5 chói (đã sửa + đo offscreen: arena-3 8,86 % → 0 %; chưa xác minh trên máy), G2 CHẶN (tải Petemoss bị từ chối, thiếu OFL.txt). Chưa làm: B2c, Xem lời giải trong Coach, đầu dò drill-list. Chưa xác minh trên thiết bị. `Docs/NGHIEM-THU-0.49c.md` |
| 0.50 | `cho/native-0.49-xuong-bai` (đã gộp `cho/native-0.50-the-bi-core`) | Thế bí: giao diện đủ T1–T8 (bản đồ phòng, màn thế bí, thử lại, gợi ý bậc 1–3, Ra bàn tập + quay lại, Sổ lời giải, ôn 1/3/7 ngày lật gương, kết thúc đẹp, đo cục bộ). Gốc lệch app↔máy chấm: cơ Jump đã lưu (đã sửa). Chưa: ảnh (ảnh XCUITest bị xoay). `Docs/NGHIEM-THU-0.50.md` |
| 0.51 | `cho/native-0.49-xuong-bai` | N1 thế bí của ngày (6 cơ, ⚪🟡🟢, khoá, Khoe, chuỗi ngày), N2 đoán đường bi + Chỉ số Mắt, N3 đặt thế cho bạn (cầu nối `BLDrillQuick.mm`, mã 15 ký tự, kiểm lại ở máy nhận), N4 (bóng đường bi, tờ dán PDF + QR, URL scheme). Chưa: quay chậm/kính lúp, miệng lỗ 0,5 s, clip 6 s. `BL_DAILY_EPOCH_DAY` cần đặt theo ngày phát hành. accept_local 9/9 (56 UI test). `Docs/NGHIEM-THU-0.51.md` |
| 0.52 | `cho/native-0.49-xuong-bai` | B1 gộp lõi bài băng/trô, B2 "Bank 2 băng dài" (vi+en), accept_local 9/9 (56 UI test). Chưa: xem bằng mắt thẻ bank/draw. `Docs/NGHIEM-THU-0.52.md` |
| `feature/zoker-native` | — | Chưa gộp 0.39–0.40c. Chỉ gộp sau khi anh xác nhận trên máy thật |

Lệnh build: `git push -f origin cho/native-0.40c:ci/native-0.41`, rồi chờ CI bằng tác vụ nền. Nếu đỏ, đọc log job macOS bằng `gh api …/jobs/<id>/logs | grep -E "error:|FAIL"`.

## 2. ĐÃ ĐẠT — không làm lại (anh xác nhận trên máy, 12/11)
- ✅ Gậy mờ khi che bi đích, độ rõ chỉnh được (Tuỳ chỉnh → Ngắm).
- ✅ Bóng bi không in xuống sàn; bóng gậy là một dải liền.
- ✅ Bi rơi lỗ xếp tầng theo thứ tự.
- ✅ Giật hình: anh báo "ok" ở mục 8. Chưa có số đo chẩn đoán dán lại; nếu anh báo giật lại thì xin số đo trước khi sửa.
- ✅ Đồng hồ cú + Gia hạn: chức năng đạt. 0.40c chỉ đổi chỗ hiển thị. Hai giả định (cú phá không tính giờ; đồng hồ dừng khi chờ chọn push-out) coi như anh đồng ý vì anh trả lời "ok"; cần xác nhận lại khi rảnh.
- ✅ Ô màu nỉ, nỉ mới/cũ, 10 mẫu bảng điểm, đèn báo lượt: đạt. 0.40c chỉ chỉnh độ cân và kích thước sợi.

## 3. ĐANG CHỜ ANH — nhắc anh khi trả lời việc lớn
1. Thử 0.42 trên máy khi có IPA (`Docs/NGHIEM-THU-0.42.md`). Âm thanh: dùng gói đang có, CHỈ đổi khi anh gửi gói mới — KHÔNG hỏi lại (anh chốt 13/11 23:56).
   - Gửi dòng giấy phép của 4 file 655755, 432592, 607424, 655629 (rzSHI đã có: CC BY 4.0) để ghi công đúng trước khi bán.
2. Trả lời 3 câu ở bản đánh giá ngày 12/11 (`Docs/DANH-GIA-SKILL-VA-CANH-TRANH-2026-11-12.md`):
   - (a) ĐÃ CHỐT 13/11 07:56: bản sau dồn sức cho vật lý (P0).
   - (b) HOÃN (13/11 23:56): Apple Developer 99 USD/năm → chỉ mở khi bản chơi hoàn chỉnh; giờ ưu tiên sửa lỗi nhỏ. Không nhắc TestFlight/Game Center cho tới lúc đó.
   - (c) Skill `zoker-pool-dev`: đã lưu.
3. **Thử 0.44 trên máy khi CI xanh** (`Docs/NGHIEM-THU-0.44.md`; 0.43 = IPA 146). Quay video bàn POOL từ trên xuống (240 fps, 3 góc tới × 2 tốc độ, ~15 phút) để chốt mô hình góc bật băng (chênh lớn nhất còn lại: bi lăn 45° app ~39° vs mô hình ~47°).
4. Âm thanh: anh tự gửi gói mới khi có (không nhắc).
5. Game Center: làm cùng TestFlight sau khi anh có tài khoản Developer. PR #4 đã đóng (0.41 chứa toàn bộ); gộp 0.41 vào `feature/zoker-native` khi anh xác nhận trên máy.
6. Khi về gần máy Mac có Xcode: chuyển phần code sang Claude Code chạy trên Mac (biên dịch và chạy Simulator tại chỗ, không chờ CI 50 phút).

## 4. Việc kế tiếp — theo thứ tự, yêu cầu mới nhất của anh luôn đứng đầu
0. **0.44-MM xong tới điểm nghiệm thu** (`cho/native-0.44-mm`). Chờ anh: (a) test UI camera — em đề xuất giữ thiết kế 0.36 (camera về sau bi cái khi bi dừng) và sửa test; (b) thử trên máy: còn khựng lúc đánh không, 2 máy cho Nearby/Wi‑Fi + highlight máy khách; (c) intro/tutorial chụp đen trên Simulator — xem trên máy. Sau đó mới build `ci/`.
1. **0.44 — CI 155 xanh, chờ anh nghiệm thu (19 mục).** Ảnh chụp CI chưa xem được (tải artifact bị chặn).
2. Từ 0.43 còn mở: intro MP4 1920×1080/1080×1080 có âm (ghép bản quay CI + stem WAV); âm intro là tổng hợp tạm; lỗ theo tốc độ; đo jump clip B.14; mô hình góc băng khi có video. Công cụ luyện (đoán chỗ bi dừng, để thế, so một yếu tố) chưa làm.
3. Sau 0.44: P1 TestFlight (khi anh có Developer), Z-Assess, "Vì sao trượt", báo cáo tuần; widget/Live Activity, chế độ HLV.

## 5. Skill · rủi ro · công nghệ cho các việc tới
| Việc | Skill dùng | Rủi ro chính | Công nghệ đề xuất |
|---|---|---|---|
| Build/sửa Swift | `zoker-pool-dev`, `engineering:debug` | Không có trình biên dịch Swift ở cloud, mỗi lỗi nhỏ tốn 1 vòng CI 50 phút | Job CI "chỉ biên dịch" ~10 phút (xem §8) |
| Máy đối thủ | `zoker-pool-dev`, `engineering:testing-strategy` | Hệ số tay là giả định, chưa so với người thật; bàn đầy tốn thời gian tính | Đo tỉ lệ vào của người chơi thật (nhật ký trên máy) để chỉnh |
| Hiệu chỉnh vật lý | `zoker-pool-dev`, `deep-research` | Video thiếu tốc độ khung hoặc góc quay xấu thì đo sai | Dò bi trong video bằng Vision/OpenCV; test C++ so quỹ đạo |
| Vòng luyện tập P2 | `thiet-ke-giao-dien-workflow`, `dataviz`, `game-trend-skills:tracking-game-metrics` | Thêm màn mới làm rối Sảnh | Swift Charts cho báo cáo; lưu dữ liệu cục bộ |
| IAP / TestFlight | `ios-build-preflight` (phải sửa mã app, nhóm app cho Zoker Pool), `game-trend-skills:launching-on-zero-budget` | Cần tài khoản trả phí; chính sách App Store về gói thuê bao | StoreKit 2, file `.storekit` để thử khi chưa có tài khoản |
| Âm thanh | `dsp-ab-listening`, `cap-nhat-cong-nghe-ma-nguon-mo` | Giấy phép mẫu; độ trễ âm qua Bluetooth | AVAudioEngine; mức âm theo LUFS |
| Logo / giao diện | `thiet-ke-giao-dien-workflow`, kiểu artifact Design | Trùng thương hiệu: anh phải tự tra USPTO/WIPO | Icon iOS 26 (Sáng/Tối/Tint) |
| Ảnh bàn → thế bi | `cap-nhat-cong-nghe-ma-nguon-mo` | Ánh sáng CLB, bi bị che | Vision trên máy (không cần máy chủ) |
| Widget / Live Activity | `zoker-pool-dev` | Cần target extension + App Group + ký trả phí | ActivityKit, WidgetKit |

## 6. Phát kiến đã duyệt — chưa làm (nhắc khi tới bản phù hợp)
- Bàn nhà tôi (Z-Lab) · Cú quyết định (Z-Drill) · Widget + Live Activity · Intro 2,5 s / 0,8 s · Logo Z (đường bi chạm băng) · Hệ thiết kế giao diện + Sảnh có thẻ "Tiếp tục".
- Bi văng khỏi bàn, nảy trên sàn · Bàn WPA + các họ kiểu dáng Z- · Đèn "Thi đấu" 520 lux · Hướng dẫn 3 bước · Bài mỗi ngày + chuỗi ngày · "Giữ mắt" · "Vì sao trượt" · Z-Exam.
- Khung IAP (cờ tính năng + StoreKit 2) · Menu trong trận còn 4 mục · Máy chủ trận bỏ dựng snapshot mỗi tick.
- Rung đúng nhịp va chạm · Camera rung khi phá bi mạnh · Tự xem lại cú đẹp.
- Gói bán: Z-Lab, Z-Drill, Z-Style (bảng điểm, màu nỉ), Z-Coach (HLV). Đối thủ bán khoảng $80–90/năm.

## 7. Bài học — không lặp lại
- (0.44) Không kiểm lại quyền ở mỗi lần đồng bộ rồi huỷ thao tác người chơi ĐANG làm: cấp quyền một lần lúc bắt đầu, chỉ huỷ khi mất lượt thật; vướng tạm thì xếp hàng, không bỏ im lặng. Không so số phiên bản tuyệt đối cho lệnh người chơi (dùng kỷ nguyên trạng thái).
- Không đổi bố cục giao diện khi bi đang chạy; bộ đồng bộ khung giữ quyền vị trí bi.
- Mọi tìm kiếm của máy phải kiểm tra hạn giờ giữa từng lần mô phỏng; runner Mac chậm hơn Linux khoảng 1,5 lần.
- Cú máy đánh phải qua đúng kiểm tra của app (độ nâng cơ, `LANShot.isValid`), nếu không sẽ lặp vô hạn (lỗi "máy chờ" ở 0.40b).
- Test UI chờ trạng thái ổn định rồi mới đọc; thao tác kéo có thử lại.
- Swift: ép kiểu rõ (`CGFloat(x)`). Đẩy lên cùng nhánh `ci/` là huỷ run đang chạy, nên tài liệu chỉ đẩy lên nhánh làm việc.
- (0.44) Swift: `x:Float=-0.3` bị đọc thành toán tử `=-` → luôn viết `= -0.3`; không đặt tên thuộc tính `next` trong lớp UIView/UIResponder. Bước IPA giờ in mọi dòng `error:`.
- (0.44-MM) Chạy 2 Simulator trên cùng Mac: MultipeerConnectivity tìm thấy nhau nhưng không lập phiên — LAN 2 máy phải thử trên thiết bị thật. Simulator render chỉ 15–20 khung/giây: đo CPU/luồng chính được, độ giật hình thì không.
- Push nhánh `cho/…` ngay sau mỗi commit; không push `ci/*` khi anh chưa cho.
- `gh pr view` bị chặn (dùng `gh api`); tải artifact bị chặn (đọc log job).

## 8. Đề xuất công nghệ / quy trình — chờ anh duyệt
1. **Job CI "chỉ biên dịch"** (`workflow_dispatch` trên nhánh `cho/…`, `xcodebuild build` cho Simulator, không chạy test, khoảng 10 phút): bắt lỗi Swift trước khi build đủ 50 phút. Rủi ro thấp, tốn ít phút CI.
2. **Claude Code trên Mac** khi anh có Xcode: biên dịch, Simulator và chụp ảnh so trước/sau tại chỗ.
3. **MetricKit + nhật ký sự kiện cục bộ**: đo độ giật, crash và tính năng được dùng nhiều, không gửi máy chủ.
4. **StoreKit 2 + file `.storekit`**: dựng khung IAP và thử ngay cả khi chưa có tài khoản.
