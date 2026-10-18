# Prompt dùng lặp lại mỗi phiên

Dán nguyên văn vào Claude Code. Giữa các phiên dùng `/clear`.

```
Đọc CLAUDE.md và PROGRESS.md.
Chọn MỘT nhiệm vụ chưa xong đầu tiên trong PROGRESS.md. Chỉ đọc file docs và mã nguồn liên quan.
Làm theo đúng quy tắc trong CLAUDE.md và KPI trong UPGRADE.md.
Chỉ đánh dấu xong khi đã build và chạy test thật; nếu không có môi trường, ghi "chưa xác minh".
Khi xong: ghi kết quả thật vào Nhật ký, commit nếu đạt, báo cáo tối đa 5 dòng
(file sửa, lệnh đã chạy, kết quả, vấn đề còn tồn tại, commit).
Dừng lại, không làm nhiệm vụ tiếp theo.
```

## Mẹo
- Nhiệm vụ lớn (bộ giải va chạm, throw, đo cú vuốt): bật plan mode, duyệt kế hoạch trước.
- Model mạnh cho vật lý và xử lý cú vuốt; model rẻ hơn cho giao diện, JSON, code lặp.
- Báo lỗi: chỉ dán đúng dòng lỗi.
- Hỏng: `git reset` về commit trước thay vì sửa nhiều vòng.
- Không có Mac: đẩy lên GitHub, CI `.github/workflows/swift-packages-tests.yml` chạy test trên macOS.
