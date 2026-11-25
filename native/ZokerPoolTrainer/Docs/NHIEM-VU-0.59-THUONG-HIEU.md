# Nhiệm vụ 0.59 (phần 3) — Thương hiệu Zokervie, icon, intro, độ chói cơ (phiên Mac)

Chủ dự án duyệt 25/11/2026: đổi thương hiệu sang **Zokervie**, logo v1 (chữ Z = hai thanh vàng + cây cơ, bi ngà trong khuyết tròn), intro do app tự dựng (không đóng gói video AI), sửa độ chói cơ, làm lại 24 tranh tường (không chặn ra mắt).
Làm cùng nhánh 0.59, mỗi mục một commit. Mọi mục: "chưa xác minh trên thiết bị" cho tới khi anh thử máy thật.

## Tài sản (đã có trong `Docs/brand/`)
| File | Dùng cho |
|---|---|
| `zokervie-logo-flat.svg` | bản phẳng chuẩn (logo, intro khung cuối, in) |
| `zokervie-logo-metal.svg` | bản kim loại (màn lớn, web) |
| `zokervie-logo-flat-transparent.svg` | nền trong suốt (đặt lên cảnh 3D, thẻ khoe) |
| `zokervie-icon-small.svg` | icon cỡ nhỏ: bi to hơn, cơ dày hơn (29–60 pt) |
| `zokervie-icon-1024.png`, `zokervie-icon-small-1024.png` | nguồn AppIcon, không kênh alpha |

Màu: vàng `#D9A441`, ngà `#F7EFDC`, xanh than `#0B1220`. Hình học: hệ toạ độ 1000×1000, bi tâm (244,724) sau dịch `translate(22 22)`, mọi nét chéo 45°.
Chữ ZOKERVIE: **Montserrat SemiBold** (SIL OFL 1.1, github.com/JulietaUla/Montserrat), in hoa, kern rộng (~0,18 em). Đóng gói kèm `OFL.txt`, thêm ghi công ở màn Pháp lý. Petemoss chỉ cho tiêu đề trang trí trong game, không dùng trong logo.

## B1. Tên
- `CFBundleDisplayName` = `Zokervie` (tên dưới icon; "Zokervie Billiards" quá dài cho màn hình chính).
- Tên App Store dự kiến: `Zokervie Billiards`, phụ đề `Pool · Snooker · Carom Trainer` (đặt ở App Store Connect, không trong code).
- **Bundle ID: CHƯA ĐỔI.** Hiện `com.maiquocviet.BankLabS` (có họ tên thật). Đề xuất `com.zokervie.billiards`, chờ chủ dự án duyệt; chỉ đổi khi duyệt, vì sau khi tạo bản ghi App Store thì không đổi được.
- `PRODUCT_NAME`/tên target giữ nguyên (đổi gây vỡ đường dẫn test, không lợi gì cho người dùng).

## B2. Icon app
- Thay toàn bộ `AppIcon.appiconset`: cỡ ≥ 76 pt (152/167/1024 px) từ `zokervie-icon-1024.png`; cỡ ≤ 60 pt từ `zokervie-icon-small.svg` (xuất bằng `rsvg-convert`, rồi `-alpha off`).
- Lưu ý: thư mục `MQV-058c` trên Mac đang có 18 file AppIcon sửa dở chưa commit (VERIFIED 25/11). Hỏi anh trước khi bỏ.
- Chốt kiểm: script kiểm mọi PNG trong AppIcon không có alpha và đúng kích thước khai trong `Contents.json`.

## B3. Màn khởi động
- `LaunchLogo0441` → logo phẳng nền trong suốt; `LaunchBackground0441` = `#0B1220`.
- Vị trí và cỡ logo ở màn khởi động phải trùng khung đầu của intro (không nhảy hình khi chuyển).

## B4. Intro mới (thay lớp logo của `Intro0441`), tổng ≤ 3,2 s, chạm để bỏ qua
Bản mẫu nhịp: video Gemini anh gửi 25/11 (10 s, chỉ để tham khảo, KHÔNG đóng gói vào app). Mốc thời gian đặt ở MỘT chỗ (`IntroTiming057`).
| Mốc | Hình | Tiếng / rung |
|---|---|---|
| 0,00–0,60 | Cảnh 3D: bi cái lăn chậm trên nỉ tối, ánh đèn hẹp | gió nhẹ |
| 0,60 | Cơ chạm bi | tiếng "cạch" + rung nhẹ (IntroHaptics) |
| 0,60–1,00 | Tóe tia vàng từ điểm chạm, máy quay lùi | — |
| 1,00–2,20 | Lớp 2D: các mảnh vàng (hình bình hành nhỏ) bay về, ráp thành hai thanh + cây cơ theo đúng hình học SVG; bi lăn về khuyết tròn | tiếng mảnh kim loại khớp |
| 2,20 | Logo khép hoàn chỉnh, một vệt sáng quét trái → phải | tiếng trầm ấm + rung đậm |
| 2,40–3,00 | Chữ ZOKERVIE hiện dần (Montserrat, không phải chữ AI vẽ) | — |
| 3,00–3,20 | Mờ vào bàn chơi | nhạc tự hạ như 0.57 |
- Logo dựng từ path vector (CAShapeLayer hoặc SCNShape) theo đúng toạ độ SVG; không dùng ảnh raster cho khung cuối.
- Âm thanh: dùng/biến tấu IntroBoom/IntroJingle/IntroRiser hiện có (đã kiểm nguồn trong `Tools/AudioSources/ATTRIBUTION.md`); KHÔNG lấy tiếng từ video Gemini. Đỉnh ≤ −1 dBFS.
- Lần mở thứ 2 trở đi: bản ngắn ≤ 1,2 s (chỉ logo khép + chữ).
- Giữ các khoá probe intro hiện có (introDone/Mode/Film/Wall/SkipMs) để test UI không vỡ.
- Ảnh trước/sau: 4 khung (0,6 / 1,5 / 2,2 / 3,0 s) trên iPhone và iPad.

## B5. Thay chữ và logo cũ trong app
| Chỗ | Hiện tại (VERIFIED tại 3c64d06) | Đổi thành |
|---|---|---|
| `Lobby046.swift:89` | "ZOKER POOL" | logo + "ZOKERVIE" |
| `TC+HUD.swift:192` | "ZOKER POOL · Trainer" | "ZOKERVIE" |
| `Mastery054.swift:72` | thẻ khoe "ZOKER POOL" | logo nhỏ + "ZOKERVIE" |
| `Intro043.swift:364,367` | "ZOKER POOL" | "ZOKERVIE" (hoặc bỏ nếu Intro043 không còn dùng) |
| `TableScene.swift:1518–1537` (`apronLogo`, `brandPlate`) | chữ "ZOKER" nghiêng | biểu tượng Z mới (path) |
| `Rooms042.swift:22–30` (`zLogo`, `brandWall`) | Z cũ trên tường | biểu tượng Z mới |
| i18n vi/en | các chuỗi "Zoker Pool" | "Zokervie" |
- Tên gói Z-Lab, Z-Drill, Z-Coach, Z-Style, Z-Pro: giữ nguyên.
- Màn Pháp lý: thêm Montserrat (OFL) + dòng "Hình ảnh thương hiệu © Zokervie".

## B6. Độ chói cơ (anh báo ở IPA 173, ảnh IMG_7921)
Nguyên nhân (INFERRED, đọc code `TableScene.swift` ~1281): thân cơ `maple` nền trắng + vân gỗ sáng, roughness 0,42, sát camera dưới đèn → cháy trắng; vệt sọc do ảnh vân bị kéo dài không có mipmap.
- Hạ albedo thân cơ về ~0,70 (nhân màu), roughness ~0,55.
- Bật mipmap + lọc dị hướng (anisotropic) cho ảnh vân gỗ cơ.
- Đoạn cơ trong ~25 cm sát camera mờ dần (alpha theo khoảng cách tới camera).
- Gộp vào thanh "Độ chói bi" thành "Độ chói bi + cơ" (một giá trị, nhân cả hai).
- Bắt buộc ảnh "phòng chuẩn" trước/sau ở đúng góc camera của IMG_7921.

## B7. 24 tranh tường (đợt sau, không chặn 0.59)
Làm lại chữ và logo trên ảnh theo Zokervie; giữ nguồn ảnh như đã xác nhận. Lên kế hoạch riêng.

## Không làm trong nhiệm vụ này
Trang web/chính sách (phiên mây đổi trên Vercel), đăng ký nhãn hiệu (anh), bundle ID (chờ duyệt).

## Nghiệm thu
Theo `Run-All-Checks.command` + test UI intro hiện có; báo PASS/FAIL/NOT RUN từng mục B1–B6; ảnh trước/sau B4, B6; IPA gửi anh. Code do phiên Mac viết sẽ được phiên mây review độc lập (không tự nghiệm thu).
