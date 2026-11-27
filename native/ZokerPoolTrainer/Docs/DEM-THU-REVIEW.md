# Đêm thử — phiếu cho người review độc lập

Người review KHÔNG được biết lỗi nào đã sửa, không đọc Docs/SO-LOI-ZB.md trước khi viết nhận xét. Vai trò: một người chơi bida
khó tính, nói tiếng Việt và tiếng Anh, lần đầu mở app.

## Đầu vào
`build/night/<mốc giờ>/`: `RUN.txt`, `manifest.tsv`, `auto-findings.md`, thư mục từng máy-ngôn ngữ (ảnh `<màn>-t5/t10/t16.png`,
`tour.mp4`, `runtime.log`), `wifi-pair/` (video + ảnh mỗi 3 giây của 2 máy, `host.json`, `guest.json`, `result.txt`).

## Việc phải làm
1. Xem TỪNG ảnh (không đoán theo tên file). Với mỗi ảnh ghi: có lỗi hiển thị không?
2. Cặp vi/en cùng màn: chữ Việt còn sót ở bản en? chữ Anh còn sót ở bản vi? chữ bị cắt, chồng, tràn, nền trong suốt khó đọc, font xấu?
3. Bố cục hai cỡ máy khác nhau: nút ngoài vùng an toàn, lệch, đè nhau.
4. Bàn bida: bi, cơ, camera có che nhau, mất bi cái, cơ xuyên bàn, camera cắt cú đánh?
5. Wi-Fi: đối chiếu ảnh host/guest cùng giây: hai bên có cùng trạng thái, cùng lượt, cùng vị trí bi không? Chữ trạng thái có tự mâu thuẫn không?
6. Đọc `result.txt`, `host.json`, `guest.json`: mục FAIL, số lần âm thanh lặp, góc cơ lệch.
7. Không kết luận về âm thanh hay cảm giác vật lý từ ảnh. Ghi "KHÔNG ĐÁNH GIÁ ĐƯỢC từ ảnh" và để người thật nghe.

## Mẫu ghi mỗi phát hiện
- Mã tạm: NT-<ngày>-<số>
- Mức: S1 (sai luật/vật lý/mạng/mất dữ liệu), S2 (camera/HUD/luồng), S3 (chữ/ngôn ngữ), S4 (thẩm mỹ)
- Máy / ngôn ngữ / màn / giây: ví dụ iPhone 17 Pro · en · drill-list · t10
- Bằng chứng: đường dẫn file ảnh hoặc dòng log
- Mô tả một câu, nhãn VERIFIED (thấy rõ trong ảnh/log) hoặc INFERRED (suy ra)
- Đề xuất sửa (chỉ ghi, KHÔNG sửa code)

## Sau khi viết xong
Đối chiếu với Docs/SO-LOI-ZB.md: phát hiện trùng ZB cũ ghi "TRÙNG ZB-0xx" (nếu lỗi cũ lặp lại sau khi đã ghi ĐÃ SỬA → báo S-mức cao hơn một bậc,
vì đó là hồi quy). Phát hiện mới đưa vào sổ lỗi với trạng thái MỞ.

## Tiêu chí thành công của đợt đầu
Bắt được ≥70% lỗi nhìn thấy trong video nghiệm thu 202 của chủ dự án (chủ dự án chỉnh được ngưỡng).
