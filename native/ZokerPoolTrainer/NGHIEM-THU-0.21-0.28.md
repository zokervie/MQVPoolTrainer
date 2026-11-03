# Nghiệm thu Z-Trainer 0.21 → 0.29

Nhánh `ci/native-0.21-vat-ly`. Cột **CI** = đã được kiểm tra tự động (test C++ trên Linux / Simulator trên Mac). Cột **Máy thật** = bạn tick khi thử trên iPhone/iPad. Ghi chú ngắn vào cuối mỗi dòng nếu chưa đạt rồi gửi lại file này.

## Vật lý (0.21)

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 1 | Cơ nằm ngang: mọi gậy ra bi đúng hướng ngắm dù effect xa tâm | ✅ lệch 0,0000° | [ ] |
| 2 | Nâng cơ: bi bắt đầu lệch theo effect, đủ ở 15° | ✅ | [ ] |
| 3 | Lực mức 28–30 khác nhau rõ (trước đây bị kẹp 6 m/s) | ✅ 8,0 m/s ở mức 30 | [ ] |
| 4 | Gậy Break mạnh hơn rõ (mức 30 ≈ 11,9 m/s) | ✅ | [ ] |
| 5 | Xoáy ngang tắt nhanh hơn, không xoáy lâu vô lý | ✅ 11 rad/s² | [ ] |
| 6 | Massé mạnh, cong rõ (70–80°, lực tối đa ≈ 1,7–2,4 m/s) | ✅ | [ ] |
| 7 | Massé tự bật khi gậy Đánh nâng ≥ 60° | ✅ | [ ] |
| 8 | Gậy Jump nằm ngang không nhảy; nâng 45° nhảy | ✅ 180 mm | [ ] |
| 9 | Zigzag ngược như clip (bi đích đổi chiều sau băng 2) | ✅ lệch ≤ 0,22 nút | [ ] |
| 10 | Hệ kim cương corner‑5 (A = D − T) đúng với lực vừa + ~1,5 tip thuận | ✅ lệch 0,0, phân tán ¼ nút | [ ] |
| 11 | Effect ngược ở lực vừa: góc bật có thu lại không? (điểm còn mở) | ⚠️ mô hình thu rất ít | [ ] ghi số đo |

**Bài đo cho mục 11** (bàn thật, lực vừa, kick 1 băng từ cách băng 1,5 nút): ghi bi về ở nút số mấy với không effect / thuận 1 tip / ngược 1 tip.

## Đồ hoạ (0.23)

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 12 | Nỉ hết lem: vân mịn ~1 mm, không còn sọc chéo dài | ảnh CI | [ ] |
| 13 | Bi hết chói nửa trên, đốm sáng nhỏ gắt | ảnh CI | [ ] |
| 14 | Thư viện → Nỉ mới / cũ (vệt lăn, vết chấm, bụi phấn) | — | [ ] |
| 15 | Thư viện → Bi mới / cũ | — | [ ] |
| — | Bàn cũ / mới, chi tiết bàn như hình mẫu | chưa làm | |

## Âm thanh (0.24)

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 16 | Không còn lúc mất tiếng cả ván | đầu dò âm thanh | [ ] |
| — | Bộ tiếng mới (rơi lỗ, băng, cơ) | chờ bạn tải file mẫu | |

## Giao diện (0.22)

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 17 | Cột phím phải, trên → dưới: Xem lại · Lùi cú · Đặt bi · Thêm bi · Bao cơ · Camera | ✅ 5 cỡ màn | [ ] iPhone [ ] iPad |
| 18 | Bi effect to (76 pt / iPad 100), thanh nâng cơ bên trái, bánh xe ngang bên dưới | ✅ | [ ] |
| 19 | Thanh nâng cơ và bánh xe phóng to khi chạm | — | [ ] |
| 20 | Menu + Coach góc trên trái, B góc dưới trái | ✅ | [ ] |
| 21 | Tay trái: Thư viện → Tay trái / tay phải, mọi thứ lật gương | ✅ | [ ] |
| 22 | Camera: giữ = toàn cảnh, buông = về ngắm ngay; chạm nhanh = đổi | — | [ ] |
| 23 | Đặt bi: bi cái vào ô trống gần giữa bàn, không chồng bi | ✅ | [ ] |
| 24 | Thêm bi: Thêm từng bi / số lượng – bố trí | UI test | [ ] |
| 25 | Bao cơ: Gậy Đánh / Jump / Break (thương hiệu) | UI test | [ ] |

## Menu, xem lại, lùi cú (0.25)

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 26 | Menu chỉ 7 mục: Chế độ chơi · Hướng dẫn · Bài tập · Lưu trữ · Thư viện · Nhật ký · Hiệu chỉnh vật lý | — | [ ] |
| 27 | Lùi cú: chạm = lùi 1; giữ = Lùi / Tiến / Về đầu / Tới mới nhất (chỉ luyện tập) | — | [ ] |
| 28 | Xem lại → Highlight phiên (top 5) + Lưu highlight; Tự lưu mọi cú | — | [ ] |
| 29 | Hiệu chỉnh vật lý: thanh trượt + xuất Markdown có nguồn từng hệ số | — | [ ] |

## Luật (0.26)

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 30 | 8/10-ball: bi đi thẳng vào lỗ được tính, không cần gọi | ✅ 464 kiểm tra | [ ] |
| 31 | Băng / combo / kiss không gọi = ăn may, không tính | ✅ | [ ] |
| 32 | Phím Call: toàn cảnh, chạm bi rồi chạm lỗ | — | [ ] |

## Online (0.27) và xếp bi (0.28)

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 33 | Wi‑Fi mã phòng, không tài khoản | có từ 0.19 | [ ] |
| 34 | Game Center: đăng nhập, bạn bè, mời / ghép trận | cần bật Game Center (bên dưới) | [ ] |
| 35 | Cảnh xếp bi đầu ván ~3,4 s, chạm để bỏ qua | — | [ ] |

## Trải nghiệm thi đấu (0.29)

| # | Hạng mục | CI | Máy thật |
| --- | --- | --- | --- |
| 36 | Bi dừng → được đánh tiếp gần như ngay (trước: chờ tới ~5 s khi bi còn xoáy tại chỗ) | ✅ 0 s, cú kéo không đổi | [ ] |
| 37 | Zoom góc ngắm: bi cái luôn ở tâm màn hình, trượt trên một trục | — | [ ] |
| 38 | Xem đối thủ: xoay quanh tâm bàn cố định | — | [ ] |
| 39 | Đến lượt mình: tự về góc ngắm sẵn sàng ra cơ | — | [ ] |
| 40 | Thiết lập tên + race to N trước trận; bảng điểm kiểu truyền hình; ván mới tự xếp | ✅ logic race | [ ] |

**Bật Game Center (việc của chủ tài khoản Apple Developer):** developer.apple.com → Identifiers → App ID của Z-Trainer → bật *Game Center*; App Store Connect → app → *Game Center* bật; ký lại IPA bằng profile có Game Center. Tài khoản Apple miễn phí không dùng được Game Center; khi đó Wi‑Fi và Online mã phòng vẫn chơi bình thường.
