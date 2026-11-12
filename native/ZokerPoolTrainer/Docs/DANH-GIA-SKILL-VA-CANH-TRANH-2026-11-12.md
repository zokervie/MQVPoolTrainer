# Đánh giá: skill phù hợp + điểm yếu cần sửa để cạnh tranh (12/11/2026)

Nhãn bằng chứng: VERIFIED (em tự kiểm), REPORTED (nguồn ngoài nói), INFERRED (suy luận).

## 1. Skill phù hợp với ZokerPoolTrainer

| Skill | Dùng vào việc gì | Mức phù hợp |
|---|---|---|
| danh-gia-phan-bien | Khám nghiệm mỗi bản, phản biện đề xuất | Dùng ngay |
| thiet-ke-giao-dien-workflow | Đếm số chạm, tìm điểm ma sát Sảnh/trận/Tuỳ chỉnh (ví dụ trong skill là app thu âm, nhưng quy trình dùng được) | Dùng ngay |
| engineering: testing-strategy, tech-debt, debug, code-review | Chiến lược test, tách file lớn, điều tra giật | Dùng ngay |
| game-trend-skills: evaluating-game-ideas, tracking-game-metrics, launching-on-zero-budget, scanning-game-trends | Đánh giá ý tưởng, chỉ số giữ chân người chơi, ra mắt ít vốn | Dùng khi có TestFlight/người thử |
| deep-research | Nghiên cứu đối thủ, giá, tính năng | Theo đợt |
| cap-nhat-cong-nghe-ma-nguon-mo | Kiểm tra giấy phép thư viện, gói âm thanh CC0 | Khi thêm thư viện/âm thanh |
| dsp-ab-listening | Nghe mù A/B khi thay mẫu âm thanh (mục E) | 0.42 |
| ios-build-preflight | Kiểm tĩnh trước khi build macOS | Cần chỉnh: đang gắn bundle/App Group của Zoker Studio |
| Artifact Design / dataviz / video-making | Bản vẽ giao diện, màn thống kê, video giới thiệu | Theo việc |

Không phù hợp:
- `zoker-studio-dev` và `zoker-ai-council` viết cho Zoker Studio (app thu âm, repo khác, quy trình DEC trên Drive). Riêng khung "Hội đồng AI" có thể dùng lại cho các quyết định lớn.
- Các skill Unity (kể cả `implement-in-app-purchases`) không dùng được vì app viết bằng SceneKit.

Thiếu: chưa có skill riêng cho ZokerPoolTrainer. Đề xuất tạo `zoker-pool-dev`, gom luật dự án và các bài học CI để không lặp lỗi cũ.

## 2. Đối thủ (REPORTED, App Store 11/2026)

| App | Hướng | Giá |
|---|---|---|
| DrillRoom | Camera AI trên bàn thật, báo cáo, bản đồ nhiệt, Apple Watch | $14.99/tháng, $89.99/năm; 4,6★ (258) |
| WPB | 200+ bài, khoá học, tính góc ngắm, đánh giá kỹ năng, bảng xếp hạng tuần | $10.99/tháng, $79.99/năm, $249.99 trọn đời; 4,4★ (252) |
| Dr. Dave Billiards | Thư viện video giảng dạy | $14.99/tháng, $119.99/năm, $249.99 trọn đời |
| Shot Lab | Bài tập, chế độ sinh tồn, thống kê, thăng hạng | Miễn phí |

Kết luận (INFERRED): đối thủ chia làm 3 nhóm: camera trên bàn thật, thư viện bài tập/khoá học, và video giảng dạy. Chưa thấy app nào vừa có mô phỏng vật lý chính xác vừa giải thích "vì sao trượt" theo số liệu. Đây là chỗ Zoker có thể đứng một mình: "phòng mô phỏng bay" cho bida.

## 3. Điểm chưa tốt

| # | Vấn đề | Bằng chứng | Mức |
|---|---|---|---|
| 1 | Giật hình chưa xác nhận đã hết trên máy thật, sau nhiều vòng sửa | Lịch sử 0.37–0.40b | Cao |
| 2 | Hệ số vật lý và hệ số tay của máy vẫn là giả định, chưa đo bàn thật | CLAUDE.md, Opponent.hpp | Cao (vì lời hứa "chuyển được ra bàn thật") |
| 3 | Chưa có vòng luyện tập: đánh giá trình độ → lộ trình → báo cáo tiến bộ. Đối thủ đều có | VERIFIED (code) | Cao |
| 4 | Công sức dồn nhiều cho trang trí (10 bảng điểm, màu nỉ, intro) trước khi có vòng luyện tập | Kế hoạch 0.40–0.41 | Vừa |
| 5 | Chưa lên TestFlight: không có người thử thật, không thử được IAP, Game Center, widget | IPA chưa ký | Cao |
| 6 | Không có số đo giữ chân người chơi, nên không biết tính năng nào được dùng | VERIFIED | Vừa |
| 7 | File điều khiển quá lớn; mỗi vòng CI khoảng 50 phút; test UI hay chập chờn | CI 125–131 | Vừa |
| 8 | Chưa có chế độ cho HLV: giao bài, xem kết quả học viên, chia sẻ thế bi | VERIFIED | Vừa |

## 4. Đề xuất theo thứ tự ưu tiên

**P0 — Thật trước, đẹp sau**
- Nghiệm thu giật trên máy (đã có công cụ đo).
- Quay 5 cú 240 fps → hiệu chỉnh hệ số. Thêm bộ test "20 cú mẫu so với video".
- Lợi ích: lời hứa cốt lõi đứng được. Chi phí: 1 buổi quay của anh + khoảng 1 bản của em.

**P1 — Lên TestFlight**
- Tài khoản Developer $99/năm. Lợi ích: 10–20 người thử thật, thử được IAP sandbox, Game Center, widget.
- Rủi ro thấp, hoàn tác được.

**P2 — Vòng luyện tập (thay cho phần lớn trang trí trong 0.41)**
- **Z-Assess:** bài đánh giá 12 phút → hồ sơ 6 trục: ngắm thẳng, cắt mỏng, lực, xoáy/vị trí, kick, phòng thủ.
- **Lộ trình tự sinh:** bài tập nhắm vào trục yếu nhất; bài mỗi ngày và chuỗi ngày dựa trên lộ trình này.
- **"Vì sao trượt":** tách sai số thành góc ngắm / độ bám (throw) / lệch bi chủ (squirt) / cong (swerve), có số liệu. Đối thủ không làm được vì họ không có mô phỏng.
- **Báo cáo tuần:** bản đồ nhiệt lỗ, tỉ lệ theo góc cắt, xu hướng.

**P3 — Chế độ HLV (gói bán riêng)**
- Soạn thế bi, chia sẻ bằng link/QR, giao bài cho học viên, xem bảng kết quả, xuất sơ đồ cú.

**P4 — Cầu nối bàn thật**
- "Bàn nhà tôi" (đã duyệt).
- Chụp ảnh bàn → dựng thế bi (Vision, chạy trên máy, không cần máy chủ).
- Máy đối thủ: gắn 6 cấp vào thang điểm Z-Rating kiểu Elo, hiệu chỉnh bằng ván thật.

**Hạ ưu tiên:** intro 2,5 s, thêm kiểu bảng điểm, sợi nỉ macro → để sau P2, bán trong gói Z-Style.

**Kỹ thuật (song song):**
- Tách `TrainingController` theo chức năng.
- Đo trên máy bằng MetricKit + nhật ký sự kiện cục bộ (không gửi máy chủ, không dữ liệu cá nhân).
- Rút ngắn CI: tách test UI chậm, cache bản build.

**Giá (để anh cân nhắc):** đối thủ khoảng $80–90/năm. Zoker nên rẻ hơn ở thị trường Việt Nam, có gói trọn đời, và bán gói theo nhu cầu: Z-Lab, Z-Drill, Z-Coach, Z-Style.

## 5. Điều có thể làm đổi kết luận
- Video 240 fps cho thấy vật lý lệch nhiều → P0 kéo dài.
- Người thử TestFlight thích phần đấu máy/trận hơn phần luyện → đẩy P3 lên, P2 xuống.

## Nguồn
- [DrillRoom: AI Pool Trainer](https://apps.apple.com/app/id1539827505)
- [WPB: Pool Training & Drills](https://apps.apple.com/app/id1591274006)
- [Dr. Dave Billiards](https://apps.apple.com/us/app/-/id6758872346)
- [Shot Lab: Billiards](https://apps.apple.com/app/id6759288094)
