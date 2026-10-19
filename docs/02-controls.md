# Điều khiển (`PoolInput`)

## Vai trò của cú vuốt (quyết định D1, D2)
Cú vuốt là đầu vào **analog, nhất quán, có sai số tự nhiên** — không mô phỏng động tác tay ngoài đời và **không** hiệu chỉnh theo tốc độ đầu cơ thật. Ngôn ngữ chung với bàn thật là kết quả: quãng lăn, thang lực 1–7.

## Hai chế độ, chung một bộ vật lý
| | Natural Stroke (chính) | Shot Lab |
|---|---|---|
| Hướng | Vuốt xoay hướng cơ | Nhập trực tiếp |
| Điểm chạm | Bi effect | Nhập trực tiếp |
| Lực | Tốc độ vuốt | Nhập trực tiếp (thang 1–7 hoặc m/s) |
| Dùng để | Luyện tập | Tái hiện cú, phân tích lỗi, bài tập quyết định đưa bi |
| Trợ giúp | Không có | Không tự căn bi, không tự bù squirt/throw, không tối ưu lực, không hiện quỹ đạo trước cú |

## Màn hình
- Chỉ màn hình ngang, cả hai chiều xoay; điều khiển trong safe area.
- `preferredScreenEdgesDeferringSystemGestures` để iOS không cướp thao tác ở mép.
- Tùy chọn đảo bố cục cho người thuận tay trái. Không chữ khi đánh.

## Máy trạng thái (`InteractionMachine`)
```
NGẮM ──chạm nhanh vùng khóa──▶ ĐÃ KHÓA ──vuốt vượt vạch──▶ ĐANG CHẠY ──▶ PHẢN HỒI ──▶ NGẮM
  ▲                               │
  └──────chạm lại vùng khóa───────┘   (nhấc tay trước vạch = ngưng cơ, vẫn ở ĐÃ KHÓA)
```

## Ngắm (chưa khóa)
- Vuốt bất kỳ đâu = xoay hướng cơ, độ nhạy thấp; hai ngón = chế độ tinh.
- **Bi effect** bên phải, mờ, nhỏ: chạm → phóng to nổi khối, kéo để chọn điểm; buông → thu nhỏ, còn chấm nhỏ; vòng giới hạn trượt cơ, kéo quá thì rung nhẹ; chạm đúp về tâm.

## Khóa (`LockZone`)
- Vùng **ẩn** góc dưới trái ~1/8 màn hình, cách mép một khoảng nhỏ.
- Chỉ nhận chạm nhanh rồi nhấc (< 0,45 s), bỏ qua chạm diện tích lớn (> 70 pt, lòng bàn tay) và ngón di chuyển.
  Bản đầu đặt 30 pt / 0,3 s: ngón cái thật (~30–50 pt) bị loại → không khóa được, không rung (lỗi thử trên máy 19/10).
- Phản hồi không chữ: rung một nhịp rõ + âm ngắn + cơ đứng yên; mở khóa rung kiểu khác.
- Hướng dẫn vùng ẩn: vòng sáng nhấp nháy (không chữ), hiện tới lần khóa đầu tiên.
- Rung: chạm bi effect (tích), chạm vòng giới hạn (nhịp cứng), khóa (hai nhịp), mở khóa (nhịp mềm), kéo lùi đủ đà (tích nhẹ), cơ chạm bi (theo lực). Bộ rung được `prepare()` khi ngón chạm màn hình.
- Bi effect vẽ như bi cái tập: vạch chữ thập, vòng 1 và 2 đầu tẩy, vòng giới hạn 0,5R, dấu đầu tẩy đúng tỉ lệ (Ø13 mm / Ø57,15 mm).
- Giao diện khi chơi: một nút menu mờ (ẩn khi đã khóa/đang chạy cú).

## Ra cơ (`StrokeAnalyzer`, `StrokeMapping`)
- Đã khóa: đặt ngón bất kỳ đâu (ngoài vùng khóa) → kéo lùi ≥ 10 mm → đẩy tới.
- **Điểm đặt ngón = vạch chạm bi.** Lực = tốc độ ngón khi vượt vạch (hồi quy vài mẫu `coalescedTouches`).
- Đổi sang mm theo kích thước vật lý màn hình (màn hiệu chỉnh một lần).
- Tốc độ ngón → tốc độ cơ: đường cong lũy thừa cố định, đơn điệu.
- Lỗi thật, không ngẫu nhiên: lệch ngang → lệch hướng/xoáy ngang; giảm tốc trước vạch → cú yếu.
- Bộ lọc nhiễu duy nhất là hồi quy tuyến tính trên `regressionWindow` mẫu — được ghi trong `StrokeConfig`.

## Ghi và phát lại (`TouchRecording`)
- Mỗi cú lưu mẫu cảm ứng thô (mm), `mmPerPoint`, model máy, `StrokeConfig`.
- `replay()` cho cùng kết quả (KPI U2). Dùng để tách lỗi người chơi / điều khiển / vật lý (REVIEW.md C5).

KPI U1–U5: UPGRADE.md mục 4.

## Cài đặt trong app (bản 0.3)
- `App/Sources/UI/TouchSurface.swift`: một UIView nhận mọi cảm ứng; định tuyến theo trạng thái (`InteractionMachine`).
- Xoay ngắm: 0,0025 rad/điểm khi một ngón; hai ngón giảm độ nhạy khoảng 6 lần.
- Bi effect: vùng chạm bán kính 1,6 × 30 điểm; khi phóng to, điểm chạm = vị trí ngón / 110 điểm, chặn ở 0,5R.
- Cú vuốt: mẫu `coalescedTouches` đổi sang mm theo `mmPerPoint` (màn hiệu chỉnh bằng thẻ ngân hàng), ghi `TouchRecording` mỗi cú.
- **Chưa thử trên thiết bị thật**: các hằng số độ nhạy là giá trị khởi đầu, cần chỉnh khi đo U3–U5.
