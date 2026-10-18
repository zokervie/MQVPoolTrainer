# Bài tập (`PoolDrills`)

## Định dạng
Xem mẫu trong `Drills/`. Tọa độ theo đơn vị kim cương (dài 8, rộng 4).

| Trường | Ý nghĩa |
|---|---|
| `bi` | Danh sách bi: `so` (0 = bi cái), `x`, `y` |
| `danh_dau` | `vi_tri_bi`, `vung_dich` (tròn/chữ nhật), `diem_bang` (cạnh + số kim cương) |
| `huong_dan` | `luc` (thang 1–7), `diem_cham` (`doc`, `ngang` theo bán kính bi, −1…1), `cong_thuc`, `ghi_chu` |
| `dieu_kien_dat` | `bi_N_vao_lo`, `bi_cai_trong_vung_dich`, `bi_cai_cham_bang_N`… |
| `so_lan` | Số lần lặp |
| `lech_ngau_nhien` | Độ lệch vị trí ngẫu nhiên (kim cương) cho cấp độ cao |

## Hiển thị
- Đánh dấu là **nhãn dán trên nỉ** (decal), bật/tắt được, không phải tia ngắm.
- Thẻ hướng dẫn xem trước cú đánh (được phép có chữ ở màn hình này), ẩn khi vào chế độ cúi đánh.

## Thang lực 1–7
Gắn với tốc độ cơ cố định (m/s), hiệu chỉnh được: 1 = 0,8 · 2 = 1,3 · 3 = 2,0 · 4 = 3,0 · 5 = 4,3 · 6 = 6,0 · 7 = 8,0.

## Công thức kim cương
- Thẻ hướng dẫn hiện công thức.
- Sau cú đánh: hiện bi thực tế chạm băng ở kim cương số mấy so với dự đoán.

## Chấm điểm và cấp độ
- Tỉ lệ thành công, khoảng cách tới vùng đích, độ ổn định qua nhiều lần.
- Cấp độ: thu nhỏ vùng đích, tăng khoảng cách, bật `lech_ngau_nhien`.

## Trình chỉnh sửa (sau MVP)
- Nhìn từ trên, kéo thả bi, bám lưới ½ hoặc ¼ kim cương, thêm đánh dấu, nhập/xuất file.

## Nội dung
- Ý tưởng và cách xếp bi phổ biến được tự dựng lại; hướng dẫn viết bằng lời của dự án; tên bài mô tả (không dùng tên chương trình hay nội dung video của người khác).
