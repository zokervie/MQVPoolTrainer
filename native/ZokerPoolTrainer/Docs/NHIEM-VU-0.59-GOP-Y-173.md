# Nhiệm vụ 0.59 (phần 4) — Góp ý của anh sau khi chơi IPA 173 (25/11/2026 22:14)

Anh duyệt 25/11 22:25. Làm cùng nhánh 0.59. Mọi mục: "chưa xác minh trên thiết bị" tới khi anh thử máy thật.
Ảnh anh gửi: IMG_7920 (khoá điểm chạm), IMG_7951 (lỗi vách bàn), IMG_7952 (cơ 15°).

## U1. Wi-Fi: đặt bi khó, lượt chuyển chậm
- Triệu chứng (REPORTED): máy bạn được đặt bi phải ấn nhiều lần; lượt tới chậm dù sóng mạnh.
- Giả thuyết (INFERRED): thao tác kéo bi của máy không phải chủ phòng phải chờ gói tin khứ hồi mới được nhận.
- Sửa: máy đang đặt bi xử lý tại chỗ (dự đoán cục bộ), chỉ gửi vị trí cuối + xác nhận qua kênh tin cậy; thêm "chạm một lần để đặt"; ghi thời gian từng gói (gửi → nhận → áp dụng) vào probe để đo, không đoán.
- Nghiệm thu: 2 máy, 20 lần đặt bi liên tiếp, mỗi lần ≤ 1 thao tác; độ trễ chuyển lượt đo được (báo số trung vị và p95).

## U2. Ô phá bi + các kiểu xếp bi + chế độ tập phá (phần dễ; hiệu chuẩn cú phá để 0.60)
- Kẻ vạch trên nỉ (bật/tắt trong Tuỳ chỉnh luật): vạch đầu bàn (head string), ô phá kiểu "2×2 kim cương ở giữa" và kiểu "±1 kim cương quanh trục dọc sau vạch đầu bàn". Ghi rõ đây là các biến thể giải đấu, không phải luật WPA mặc định.
- Xếp bi: 9 bi (bi 9 giữa, hoặc bi 9 trên điểm đặt), 10 bi, 8 bi; khuôn xếp khít (template) hoặc có khe ngẫu nhiên nhỏ.
- Phòng tập "Phá bi": chọn kiểu xếp + ô phá + vị trí bi cái; sau mỗi cú: bi nào vào lỗ nào, số bi chạm băng, số bi qua vạch đầu bàn (luật 3 điểm), bi cái dừng đâu; lưu lịch sử để so.

## U3. Khoá điểm chạm sai khi bi cái còn cách băng (IMG_7920)
- Viết test hình học trước: khoảng hở bi–băng, chiều cao mũi băng, chiều cao mép gỗ, góc nâng cơ → vùng điểm chạm hợp lệ. Chỉ khoá phần thật sự làm đầu cơ/thân cơ chạm băng.
- So kết quả test với `UI/CueClearance.h` hiện tại; sửa phần tính quá chặt.

## U4. Lỗi hình bàn (IMG_7951)
- Mảnh tối thừa ở vách bàn gần chân (chỗ anh khoanh vàng): tìm node/mesh gây ra, bỏ hoặc sửa. Ảnh "phòng chuẩn" trước/sau.
- Chữ "ZOKER" trên vách → logo/chữ Zokervie (gộp B5).

## U5. Cơ
- Góc nâng mặc định 0°; chỉ tự nâng khi bắt buộc (bi sát băng, cơ gác băng). Tìm nguyên nhân 15° hiện tại (IMG_7952, bi giữa bàn).
- Sau mỗi cú dùng cơ Phá hoặc Nhảy: lượt kế của người đó tự trả về Cơ chơi. Cú phá đầu ván tự chọn Cơ phá (người chơi đổi được).
- Tách 3 nút rõ: Chơi · Phá · Nhảy (massé = nâng cao cơ chơi, không cần nút riêng). Lần đầu mở: gợi ý chỉ từng nút. Bỏ cách ẩn chế độ trong một nút.

## U6. Push-out (9 bi, 10 bi)
- Luật đã có (VERIFIED: `Core/MatchRules.hpp` pushOutAvailable; `UI/MatchPlayController.swift` ~747 "Khai Push-out cho cú kế tiếp") nhưng nằm trong bảng chọn ẩn.
- Hiện nút "Push-out" ngay trên HUD ở cú đầu tiên sau cú phá hợp lệ; đối thủ được hỏi rõ "Đánh tiếp / Trả lượt". Hoạt động cả đấu máy và Wi-Fi.

## Không làm trong 0.59
Hiệu chuẩn cú phá, mô hình băng và nhánh Carom → bản 0.60 (xem `Docs/KE-HOACH-HIEU-CHUAN-0.60.md`).
