# ZokerPoolTrainer native — ghi chú cho phiên Claude Code trên Mac

Quy tắc chung: xem `CLAUDE.md` ở gốc repo và `Docs/TRANG-THAI.md`.

## Điều phối (0.45 M0)
Phiên chính trên Mac là **người điều phối**: đọc nhiệm vụ, chia mốc, giao việc cho subagent theo bảng, gộp kết quả, chạy kiểm tra,
commit. Không tự viết khối mã lớn khi đã có vai phù hợp. Vai ở `.claude/agents/` (gốc repo).

| Việc | Vai |
|---|---|
| 0.45 M1 vòng khung hình, M2 tách TrainingController, 0.46 M3 hình học bàn + test 3 cỡ | ky-su-loi |
| 0.45 M3 ZDesign + i18n, 0.46 M1–M2 Sảnh/HUD/menu, 0.47 M1–M4 phần Swift | ky-su-giao-dien |
| Kiểm kê sau mỗi mốc, đọc log accept_local | kiem-ke |
| Review cuối mỗi bản | giam-khao |

Không đặt `CLAUDE_CODE_EFFORT_LEVEL` trong môi trường (biến này đè effort của từng vai).
Lưu ý: vai chỉ được nạp khi phiên Claude Code mở tại gốc repo chứa `.claude/agents/`; nếu không thấy vai, giao cho agent
chung kèm nội dung file vai.
