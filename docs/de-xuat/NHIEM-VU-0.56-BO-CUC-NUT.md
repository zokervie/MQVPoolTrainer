# Giao việc 0.56 — cân lại hai cụm nút (cho phiên Mac)

Chủ dự án yêu cầu 22/11 18:17 (ảnh Simulator iPhone 17 Pro). Làm trên `cho/native-0.53-phieu-lo`, sau 0.55.

```
 Cụm trái                         Cụm phải
 ┌──────┐ ┌──────┐                      [Đặt bi]
 │ ━━━━ │ │ ━━━▬ │   rộng = D, cao 2/3 D [Lùi cú]
 │Cơ chơi│ │Cơ phá│                      [Camera]
 └──────┘ └──────┘                      [Bàn]
 ┌──────┐  ╭──────╮            ◢ góc dựng
 │  B   │  │ bi ép│
 │      │  │ phê  │            (không còn công tắc thanh lực)
 └──────┘  ╰──────╯
```

**K1. Cụm phải.** Nút "Đặt bi" thu về đúng cỡ và kiểu của Lùi cú / Camera ngắm / Bàn (biểu tượng + chữ nhỏ), đứng
trên cùng cột: Đặt bi · Lùi cú · Camera ngắm · Bàn. Bỏ nút tròn lớn hiện tại.

**K2. Bỏ công tắc thanh lực** (chủ dự án 22/11 18:21; thay đề xuất cũ). Gộp nhánh lõi
`origin/cho/native-0.56-cuu-luc` (thêm `BLPowerBarRescue`, `BLChapterCleanSealNoHelp` vào `Mastery.h`).
- Màn chơi KHÔNG còn nút bật/tắt thanh lực ở mọi chế độ (Chơi tự do, Đấu, Bài tập, Thử thách, Thế bí). Mặc định đánh
  bằng vuốt B. Ai đã bật thanh lực ở bản cũ: tắt khi cập nhật.
- Cứu nguy: trong Bài tập theo chương, khi `BLPowerBarRescue(chương, số lùi cú đã dùng, makePercent của bài,
  số lượt chấm trượt liên tiếp)` trả 1, hiện một lần thẻ "Bài này khó. Dùng thanh lực trợ giúp? (mất dấu Tay sạch)"
  với hai nút "Dùng" / "Tự đánh tiếp". Chọn Dùng: thanh lực hiện cho bài đó tới khi rời bài; lưu `rescueUsed` theo
  chương; dấu Tay sạch dùng `BLChapterCleanSealNoHelp`. Chọn Tự đánh tiếp: không hỏi lại trong bài đó.
- Cụm phải chỉ còn cột 4 nút (K1) + góc dựng + vùng vuốt; cân lại khoảng cách cho thoáng.
- UI test: công tắc cũ không còn; thẻ cứu nguy hiện đúng điều kiện (cờ QA giả lập chương 2, đã dùng 92 lùi cú).

**K3. Cụm trái.** (chủ dự án làm rõ 18:19)
- Gọi D = đường kính nút bi ép phê.
- Nút B: hình vuông bo góc nhẹ, cạnh = D. B và bi ép phê cùng hàng, cùng đáy.
- "Cơ chơi" nằm ngay trên B, "Cơ phá" nằm ngay trên bi ép phê. Mỗi nút là chữ nhật nằm ngang, cạnh dài = D,
  cao = 2/3 D (tỉ lệ 2:3). Mép trái/phải của mỗi nút thẳng hàng với nút bên dưới; khe dọc = khe ngang giữa B và bi ép phê.
- Bên trong mỗi nút: hình cây cơ nằm ngang (cơ chơi: dài, mảnh; cơ phá: đầu to hơn) chiếm phần trên, dòng chữ nhỏ ở
  dưới ("Cơ chơi" / "Massé", "Cơ phá" / "Nhảy"), tất cả nằm gọn trong khung, không tràn ở cỡ chữ lớn (thu chữ, tối
  thiểu 9 pt).
- Nút đang chọn: viền vàng như hiện tại.

**K4. Ràng buộc.** Không relayout khi bi đang chạy. Kiểm iPhone SE (màn nhỏ), iPhone 17 Pro Max, iPad: không chồng lên
nhau, không đè vùng nỉ giữa bàn hơn hiện tại. Định danh UI test giữ nguyên (`PlaceBallButton`, `CueIcon…`, nút B,
công tắc thanh lực), sửa test vị trí nếu có.

**K5. Ảnh.** Chụp trước/sau ở 3 máy trên, phòng chuẩn, vào `shots/native/0.56`. Báo PASS / FAIL / NOT RUN.
Cảm giác bấm: chưa xác minh trên thiết bị.
