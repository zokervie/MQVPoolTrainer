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
1. **0.44 — CI 155 xanh, chờ anh nghiệm thu (19 mục).** Ảnh chụp CI chưa xem được (tải artifact bị chặn).
2. Từ 0.43 còn mở: intro MP4 1920×1080/1080×1080 có âm (ghép bản quay CI + stem WAV); âm intro là tổng hợp tạm; lỗ theo tốc độ; đo jump clip B.14; mô hình góc băng khi có video. Công cụ luyện (đoán chỗ bi dừng, để thế, so một yếu tố) chưa làm.
3. **0.45 — CHỜ ANH QUYẾT sau nghiệm thu 0.44**: gộp hết 15 đề xuất 12–16/11 (anh dặn 16/11: làm kỹ, tiết kiệm token). Danh sách + thứ tự: `docs/de-xuat/NHIEM-VU-0.45.md` (nhánh `plan/de-xuat-zoker`). Chưa viết mã.
4. Sau 0.44: P1 TestFlight (khi anh có Developer), Z-Assess, "Vì sao trượt", báo cáo tuần; widget/Live Activity, chế độ HLV.

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
- `gh pr view` bị chặn (dùng `gh api`); tải artifact bị chặn (đọc log job).

## 8. Đề xuất công nghệ / quy trình — chờ anh duyệt
1. **Job CI "chỉ biên dịch"** (`workflow_dispatch` trên nhánh `cho/…`, `xcodebuild build` cho Simulator, không chạy test, khoảng 10 phút): bắt lỗi Swift trước khi build đủ 50 phút. Rủi ro thấp, tốn ít phút CI.
2. **Claude Code trên Mac** khi anh có Xcode: biên dịch, Simulator và chụp ảnh so trước/sau tại chỗ.
3. **MetricKit + nhật ký sự kiện cục bộ**: đo độ giật, crash và tính năng được dùng nhiều, không gửi máy chủ.
4. **StoreKit 2 + file `.storekit`**: dựng khung IAP và thử ngay cả khi chưa có tài khoản.
