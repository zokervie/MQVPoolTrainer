# Nhiệm vụ bản 0.45 — Zoker Pool Trainer

> **ĐÃ THAY** bằng `NHIEM-VU-0.45-0.47.md` (chủ dự án duyệt thứ tự mới 17/11 20:03).

Trạng thái: **CHỜ ANH QUYẾT sau khi nghiệm thu 0.44** (anh dặn 16/11/2026: gộp hết 15 đề xuất 12–16/11 vào một bản, làm kỹ, tiết kiệm token). Chưa viết mã, chưa build.
Chi tiết từng đề xuất: `DE-XUAT.md` (mục "Đề xuất ngày …"). Bảng quyết định: tài liệu "Tổng hợp đề xuất để giao việc & nghiệm thu một lần".

Quy tắc: mỗi mục có cờ tính năng riêng; logic viết bằng C++ trong lõi + test (chạy được trên Linux, đỡ vòng CI); Swift chỉ lớp giao diện mỏng; một lần build `ci/native-0.45`.

## Thứ tự làm
0. Hạ tầng: khung cờ tính năng · job CI "chỉ biên dịch" ~10 phút (chờ anh duyệt).
A. Dữ liệu cú: #13 Z-Difficulty · #14 Mốc + ghi chú replay · #8 Sổ trận thật + Z-Rating.
B. Vòng luyện: bài mỗi ngày + chuỗi ngày (đã duyệt) + #6 Đóng băng chuỗi · #2 Cú quyết định · #4 Hệ thống ngắm · #7 Giáo án 4 tuần · #15 Bài song sinh.
C. Cảm giác bàn: #1 Bàn nhà tôi · #12 Mắt thuận.
D. Năm mục trước đây xếp "để sau" (anh muốn gộp hết) — làm bản chạy trên máy, không cần tài khoản Developer:
   - #3 Widget chuỗi ngày + Live Activity (extension build không ký trên Simulator; ký thật khi có Developer).
   - #10 Dùng thử 7 ngày (StoreKit 2 + file `.storekit`, chưa bán thật).
   - #11 Lớp của tôi: giao bài/nhận kết quả qua link/QR + file; CloudKit để khi có Developer.
   - #5 Đo cú phá bằng micro, #9 Soi tư thế (Vision): làm + test với tín hiệu/video giả; "chưa xác minh trên bàn thật".

## Nghiệm thu
Theo mục "Tiêu chí nghiệm thu một lần" của tài liệu tổng hợp; sẽ chép thành `Docs/NGHIEM-THU-0.45.md` khi build.
