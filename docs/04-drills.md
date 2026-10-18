# Bài tập (`PoolDrills`)

## Mỗi bài phải có
Mục tiêu kỹ năng · điều kiện ban đầu · **mục tiêu cụ thể của cú** · cách tính điểm · tiêu chí thành công · số lần lặp · lưu dữ liệu từng cú · phát lại · thống kê tiến bộ.

## Định dạng JSON
Mẫu trong `Drills/`. Tọa độ theo đơn vị kim cương (dài 8, rộng 4).

| Trường | Ý nghĩa |
|---|---|
| `bi` | `so` (0 = bi cái), `x`, `y` |
| `danh_dau` | `vi_tri_bi`, `vung_dich` (tâm + `ban_kinh`), `diem_bang` (`canh` + `kim_cuong`) |
| `huong_dan` | `luc` (1–7), `diem_cham` (`doc`, `ngang`, −1…1), `cong_thuc`, `ghi_chu` |
| `dieu_kien_dat` | `bi_N_vao_lo`, `bi_cai_trong_vung_dich`… — đây chính là **mục tiêu** dùng để tính sai số ngắm |
| `so_lan`, `lech_ngau_nhien` | Số lần; độ lệch vị trí ngẫu nhiên cho cấp độ cao |

## Hiển thị
- Đánh dấu là nhãn dán trên nỉ, bật/tắt được.
- Thẻ hướng dẫn chỉ ở màn xem trước; ẩn khi cúi đánh.

## Thang lực 1–7
Gắn với tốc độ cơ (m/s), hiệu chỉnh được: 0,5 · 0,75 · 1,05 · 1,4 · 1,9 · 2,6 · 4,0 — chọn theo quãng lăn của bi cái (mức 1 ≈ 0,5, mức 2 ≈ 1, mức 3 ≈ 2, mức 4 ≈ 3,5 chiều dài bàn). Mô tả cho người chơi bằng kết quả, không bằng m/s.

## Bộ bài đầu tiên
10 bài chất lượng cao (ngắm, lực, đưa bi, băng, xoáy) trước; thêm dần theo phản hồi. Bài quyết định (chọn điểm chạm + lực) chạy trong Shot Lab. Ý tưởng phổ biến được tự dựng lại, hướng dẫn viết bằng lời của dự án.

## Gợi ý bài tập
Dựa trên lỗi lặp lại trong lịch sử (lệch trái/phải, lực không đều, ngắt cơ), bằng quy tắc đơn giản — không dùng mô hình AI.
