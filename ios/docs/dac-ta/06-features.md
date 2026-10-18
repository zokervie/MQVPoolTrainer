# Tính năng mở rộng (sau MVP)

Chỉ làm khi đã thêm vào `PROGRESS.md`. Xếp theo giá trị luyện tập.

## Ưu tiên cao
1. **Bóng ma cú đánh trước (ghost replay)**: sau cú đánh, có thể bật hiển thị mờ quỹ đạo của cú trước để so sánh lực và hướng. Chỉ hiện ở màn phản hồi, không lúc ngắm.
2. **Chế độ "đánh lại đúng cú này"**: đặt bàn y hệt, người chơi đánh lại đến khi ổn định.
3. **Thử thách độ ổn định lực**: đánh 10 cú cùng mức lực, đo độ phân tán của tốc độ cơ.
4. **Bài kiểm tra ngắm thuần**: bàn chỉ có 1 bi mục tiêu ở vị trí ngẫu nhiên, chấm sai số góc, thống kê thiên lệch trái/phải của người chơi.
5. **Hồ sơ bàn**: lưu nhiều bộ tham số (CLB A nỉ nhanh, nhà nỉ chậm…), đổi nhanh trước khi tập.

## Ưu tiên trung bình
6. **Thói quen trước cú đánh (pre-shot routine)**: tùy chọn yêu cầu đi vòng quanh bàn / dừng đúng thời gian trước khi được khóa.
7. **Nhật ký tập**: thời gian tập, bài đã làm, biểu đồ tiến bộ theo tuần.
8. **Tạo bài tập từ ảnh**: chụp bàn thật hoặc ảnh chụp màn hình video, Vision nhận diện vị trí bi → bài tập.
9. **Chia sẻ bài tập**: xuất/nhập file JSON qua AirDrop, tin nhắn.

## Về sau
10. **Hiệu chỉnh bằng camera 240 fps**: quay cú đánh thật, bám bi bằng Vision, tự chỉnh tham số bàn.
11. **Chế độ AR**: chiếu đánh dấu bài tập lên bàn thật qua ARKit để tập đúng bài đó ngoài đời.
12. **Cảm biến cơ thật**: Core Motion / cảm biến Bluetooth gắn cơ để đo cú đánh thật.
13. **Nhảy bi, massé.**
14. Luật 8-ball, 9-ball để chơi thử với AI dùng chung lõi vật lý.
