# Prompt dùng lặp lại mỗi phiên

Dán nguyên văn vào Claude Code. Giữa các phiên dùng `/clear`.

```
Đọc CLAUDE.md và PROGRESS.md. git fetch; nếu feature/zoker-mvp có commit từ phiên khác trong 30 phút gần nhất thì dừng và báo.
Lấy MỘT nhiệm vụ chưa xong đầu tiên của MỐC HIỆN TẠI trong PROGRESS.md. Chỉ đọc file liên quan.
Làm trên nhánh ci/<mã nhiệm vụ>; đẩy lên để CI macOS chạy thật; chỉ gộp vào feature/zoker-mvp khi CI xanh.
Không làm việc ngoài mốc hiện tại; ý tưởng mới ghi vào "Hàng chờ".
Khi xong: ghi kết quả thật + "Có gì mới" (≤ 5 dòng) vào Nhật ký, báo cáo tối đa 5 dòng
(file sửa, lệnh đã chạy, kết quả, vấn đề còn tồn tại, commit). Dừng lại.
```

## Mẹo
- Nhiệm vụ lớn (bộ giải va chạm, throw, đo cú vuốt): bật plan mode, duyệt kế hoạch trước.
- Model mạnh cho vật lý và xử lý cú vuốt; model rẻ hơn cho giao diện, JSON, code lặp.
- Báo lỗi: chỉ dán đúng dòng lỗi.
- Hỏng: `git reset` về commit trước thay vì sửa nhiều vòng.
- Không có Mac: đẩy lên nhánh `ci/...`, CI `.github/workflows/ci.yml` chạy test trên macOS.
