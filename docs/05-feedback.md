# Phản hồi sau cú đánh

Trong lúc đánh: chỉ haptic + âm thanh. Mọi số liệu chỉ hiện **sau** cú đánh.

## Luôn hiển thị
- Phát lại, nhiều góc, quay chậm.
- Mức lực (thang 1–7) và quy đổi "bi lăn bao nhiêu chiều dài bàn".
- Độ thẳng cú vuốt (lệch ngang), có ngắt cơ không.

## Sai số ngắm — chỉ khi bài tập có mục tiêu cụ thể
- Không mặc định có một đường đánh đúng duy nhất.
- Với mục tiêu (ví dụ bi 2 vào lỗ góc trên phải), dùng PoolPhysics tìm **khoảng hướng ngắm** đạt mục tiêu với lực và điểm chạm người chơi đã dùng.
- Báo khoảng cách từ hướng đã dùng tới khoảng đó (độ, và mm tại miệng lỗ); bằng 0 nếu nằm trong.
- Báo kèm độ rộng của khoảng (cú dễ hay khó).
- Chơi tự do không có mục tiêu → không báo sai số ngắm.

## Lưu và so sánh
- Lưu mỗi cú (SwiftData): `TouchRecording`, kết quả cú vuốt, `CueStrike`, kết quả.
- Ghost Replay: hiện mờ quỹ đạo cú trước **chỉ ở màn phản hồi**, không bao giờ lúc ngắm.
