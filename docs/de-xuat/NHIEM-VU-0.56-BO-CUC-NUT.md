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
 │      │  │ phê  │            ▭▭▭▭ thanh lực [≡]
 └──────┘  ╰──────╯
```

**K1. Cụm phải.** Nút "Đặt bi" thu về đúng cỡ và kiểu của Lùi cú / Camera ngắm / Bàn (biểu tượng + chữ nhỏ), đứng
trên cùng cột: Đặt bi · Lùi cú · Camera ngắm · Bàn. Bỏ nút tròn lớn hiện tại.

**K2. Công tắc thanh lực.** Thành biểu tượng nhỏ (≡ ba thanh trượt, ~28 pt, vùng chạm ≥ 44 pt) ở đầu trái thanh lực.
Bật: vàng. Tắt: thanh lực ẩn, biểu tượng vẫn ở chỗ cũ (mờ). Trong Bài tập / Thử thách / Thế bí vẫn ẩn hẳn (0.53 C1).
(Đề xuất của phiên đám mây — chủ dự án chưa nói chỗ; nếu anh muốn khác thì sửa sau.)

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
