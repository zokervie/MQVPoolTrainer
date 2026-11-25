# Kế hoạch hiệu chuẩn vật lý không cần quay bàn + nhánh Carom (bản 0.60)

Anh duyệt 25/11/2026 22:25: hiệu chuẩn bằng số liệu đã công bố, tìm "mẫu số chung" (bàn chuẩn), không chỉnh theo một bàn cụ thể. Sau nghiệm thu 0.59, bản 0.60 có nhánh Carom riêng (phòng tập riêng).

## Bốn nguồn đối chiếu
| # | Nguồn | Dùng để | Ghi chú quyền |
|---|---|---|---|
| 1 | Số đo đã công bố: Dr. Dave Alciatore (Colorado State) — e bi–bi ≈ 0,94, μ bi–bi ≈ 0,06, μ trượt bi–nỉ ≈ 0,2; bảng góc bật băng theo góc tới (đo cùng Bob Jewett, 2009); Mathavan và cộng sự 2010 (mô hình băng); Marlow (Physics of Pocket Billiards) | đặt hệ số + test "đáp án" | chỉ dùng con số (dữ kiện), không chép tài liệu (tài liệu ghi phi thương mại) |
| 2 | Pooltool (E. Kiefl, JOSS 2024, Apache-2.0) | chạy cùng bộ cú, so đường bi | chỉ để đối chiếu offline, không nhúng vào app |
| 3 | Hệ kim cương của dân chơi: Carom (Plus, Corner-5, Maxi…), Pool (gương, đá băng, 30°/90°) | kiểm mô hình băng qua 1–3 băng | dữ kiện kinh nghiệm phổ biến |
| 4 | Người thử TestFlight nhập kết quả bài "ra bàn thật" | thống kê độ lệch giữa các bàn | sau TestFlight |

## Quy trình (test trước, phiên mây)
1. Lập bảng hệ số: mỗi dòng ghi nguồn (đã công bố / đo / giả định) + khoảng tin cậy.
2. Test C++ cho từng bảng đáp án (góc bật băng theo góc tới, 30°/90°, ném bi theo độ cắt và tốc độ). Đăng ký ở CMakeLists ZOKER_TEST_SUITES + Run-All-Checks.
3. Bộ cú chấm riêng (không dùng để chỉnh) để tránh "học thuộc đáp án".
4. Chỉnh mô hình băng (Mathavan đang TẮT sau công tắc) cho tới khi sai số trong ngưỡng; báo trước/sau bằng số.
5. Đối chiếu chéo với Pooltool trên cùng bộ cú.
6. Hiệu chuẩn cú phá 9/10/8 bi: giả lập hàng nghìn cú mỗi kiểu xếp/ô phá, thống kê bi vào lỗ, so với các mô tả đã công bố (vd. phá cắt từ ô phá với bi 9 trên điểm đặt hay đưa bi 1 vào lỗ giữa).

## Nhánh Carom (0.60)
- Bàn carom 10 ft không lỗ, nỉ nhanh, 3 bi (trắng, vàng, đỏ); luật 3 băng trước, sau đó libre/1 băng.
- Phòng tập riêng: bài theo hệ kim cương (Plus, Corner-5) có chấm điểm; đấu máy; tách hồ sơ thành tích.
- Điều kiện vào bản: test hệ kim cương đạt (sai số ≤ 0,5 kim cương ở các cú chuẩn), nếu không đạt thì giữ nhãn "Thử nghiệm".

## Nguyên tắc
Không nói "đã chuẩn" khi chưa có số; mọi kết luận kèm bảng sai số. Bàn ngoài đời mỗi hãng khác nhau: app mô phỏng bàn chuẩn, có thể thêm vài kiểu bàn (nỉ nhanh/chậm) sau.
