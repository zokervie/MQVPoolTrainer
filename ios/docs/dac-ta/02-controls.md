# Điều khiển (`PoolInput`)

## Màn hình
- **Chỉ màn hình ngang**, hỗ trợ cả hai chiều xoay; bố cục theo góc nhìn người chơi.
- Điều khiển nằm trong safe area (tránh Dynamic Island / tai thỏ).
- `preferredScreenEdgesDeferringSystemGestures` để iOS không cướp thao tác ở mép.
- Tùy chọn đảo bố cục cho người thuận tay trái.
- **Không chữ chú thích** trên màn hình chơi.

## Máy trạng thái
```
NGẮM ──(chạm nhanh vùng khóa)──▶ ĐÃ KHÓA ──(vuốt vượt điểm đặt ngón)──▶ ĐANG CHẠY ──▶ PHẢN HỒI ──▶ NGẮM
  ▲                                  │
  └────(chạm lại vùng khóa)──────────┘
```
Toàn bộ logic trạng thái là struct thuần, có unit test, không phụ thuộc UIKit.

## Trạng thái NGẮM
- Vuốt bất kỳ đâu (ngoài vùng điều khiển) = xoay hướng cơ, độ nhạy thấp. Hai ngón = chế độ tinh.
- **Bi effect** bên phải: tròn, mờ, nhỏ.
  - Chạm → phóng to, nổi khối 3D; kéo ngón trong cùng lần chạm để chọn điểm chạm.
  - Buông → thu nhỏ, mờ lại; còn chấm nhỏ thể hiện điểm đã chọn.
  - Vòng giới hạn (vùng trượt cơ, ~0,5 bán kính bi); kéo quá thì rung nhẹ, dừng ở mép.
  - Chạm đúp → về tâm.

## Khóa mục tiêu
- Vùng **ẩn** ở góc dưới trái, ~1/8 màn hình, cách mép một khoảng nhỏ.
- Chỉ nhận **chạm nhanh rồi nhấc** (< ~0,3 s). Bỏ qua ngón đặt lâu và chạm diện tích lớn (`UITouch.majorRadius`).
- Khóa: rung haptic một nhịp rõ + âm ngắn + cơ đứng yên hẳn / camera khựng nhẹ.
- Chạm lại = mở khóa, kiểu rung khác.
- Hướng dẫn vùng ẩn chỉ hiện **một lần** khi chơi lần đầu.

## Trạng thái ĐÃ KHÓA
- Hướng ngắm và effect khóa; **bi effect ẩn**.
- Cú vuốt phải bắt đầu ngoài vùng khóa.

## Ra cơ bằng cú vuốt
- Đặt ngón bất kỳ đâu → kéo lùi (lấy đà) → đẩy tới.
- **Điểm đặt ngón ban đầu = vạch chạm bi.** Cơ chạm bi khi ngón đẩy tới vượt qua điểm này.
- Nhấc tay trước khi vượt = ngưng cơ. Quãng lấy đà tối thiểu ~1 cm.
- **Lực = tốc độ ngón tại thời điểm vượt vạch**, không phải độ dài vuốt.
- Đo bằng `UIEvent.coalescedTouches(for:)` + `timestamp`; hồi quy tuyến tính vài mẫu quanh vạch để giảm nhiễu.
- Quy đổi sang mm/s theo kích thước vật lý màn hình (màn hiệu chỉnh một lần).
- Tốc độ ngón → tốc độ cơ (0,5–10 m/s): **đường cong cố định, đơn điệu, đơn giản**, chỉnh theo hồ sơ người chơi.
- Lỗi thật (không ngẫu nhiên):
  - Lệch ngang khi đẩy → lệch hướng cơ / xoáy ngang ngoài ý muốn, tỉ lệ với độ lệch.
  - Giảm tốc trước vạch → cú yếu hơn (ngắt cơ).
- Haptic khi cơ chạm bi, cường độ theo lực.
