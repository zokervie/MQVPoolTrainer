# Nhiệm vụ 0.48 — Máy quay: xem lại dễ hiểu, đẹp như teaser, không giật

Chủ dự án yêu cầu 18/11 09:50: góc máy xem lại còn "hàng chế", hay khuất đường bi, không theo được diễn biến cú, khó hình dung, đôi khi giật camera; muốn góc máy đẹp như teaser, như một DOP. Bản thử cho người lạ chuyển sang 0.49.
Làm sau 0.47, nhánh `cho/native-0.48` từ `cho/native-0.47`. Quy tắc chung như `NHIEM-VU-0.45-0.47.md` (mục "Cách chạy nối tiếp"). Phiên đám mây viết lõi C++ bộ lập kế hoạch máy quay + test trên `cho/native-0.48-core`; phiên Mac nối vào SceneKit và giao diện.

## 1. Hiện trạng (VERIFIED, `cho/native-0.47` @ 19984f9)

- 14 góc xem lại (`UI/TC+Replay.swift:98-108`) + đạo diễn tự động 3 cảnh (`UI/ReplayDirector.swift`). Quá nhiều lựa chọn, nhiều góc gần giống nhau.
- **Máy phản ứng sau sự việc, không biết trước:** các góc "Action" đặt camera theo vị trí bi của khung hiện tại và hướng chạy làm mượt 0,12 s (`TC+Replay.swift:305-400`). Bi đổi hướng ở băng/va chạm thì máy quay ngoắt theo (cảm giác giật), trong khi bản ghi xem lại đã có TOÀN BỘ đường đi tương lai.
- **Đổi tốc độ đột ngột:** chậm ×0,48 / ×0,35 bật/tắt tức thì quanh va chạm và lọt lỗ (`ReplayDirector.swift:67-71`, `actionSlowRate`). Mắt đọc thành giật.
- **Khung hình "thở":** `movingFocus` tính lại mỗi khung theo các bi đang chạy; khi số bi chạy vượt 4 thì bỏ khung (toàn bàn) → nhảy khung (`ReplayDirector.swift:220-232`).
- **Không kiểm khuất tầm nhìn:** máy thấp 5–13 cm sau bi (`chase`, `pocket`, `rail`) dễ bị chính bi cái, bi khác, băng che đường bi.
- **Không có bản đồ đường bi khi xem lại:** vệt đường bi (`table.trails`) chỉ dùng ở Coach. Người xem không thấy toàn bộ diễn biến.
- Xuất video: 1920×1080 60 fps theo góc đang chọn (`Export044.swift`); chỉ khung ngang.

## 2. Nguyên tắc quay (DOP)

1. **Lập kế hoạch trên toàn bộ bản ghi** (như dựng phim): biết trước va chạm, lọt lỗ, đường đi → máy đi trước bi (chừa khoảng phía trước), làm mượt hai chiều (không trễ pha).
2. **Mỗi cảnh một việc kể:** chuẩn bị → ra cơ → va chạm → bi chạy → lọt lỗ → toàn cảnh kết quả.
3. **Cắt theo hành động:** cắt ngay tại va chạm/lọt, mỗi cảnh ≥ 1,2 s, không cắt trong 0,3 s trước một khoảnh khắc chính.
4. **Luật 180°:** giữ máy cùng một phía đường bi qua các cảnh để người xem không bị đảo chiều.
5. **Đổi tốc độ có đường cong:** chậm dần vào ×0,35 trong 0,25 s, nhanh dần ra trong 0,35 s (không bật/tắt).
6. **Không để khuất:** chọn góc mà đường nhìn tới bi chính không bị bi khác, băng, đèn che.
7. **Máy thấp chỉ cho khoảnh khắc "anh hùng"** (bi rơi lỗ, cú phá); phần còn lại cao 3/4 để thấy đường bi.

## 3. Bộ góc mới

**Tự động (2):**
- **Đạo diễn** (mặc định khi xem lại và khi xuất): 6 cảnh theo bản ghi
  1. *Mở:* 3/4 cao sau lưng người đánh, 0,8 s, toàn bàn.
  2. *Ra cơ:* qua vai, thấp ~25 cm, đẩy nhẹ (dolly) dọc đường bi cái, chừa khoảng phía trước.
  3. *Va chạm:* chậm ×0,35 có đường cong, đẩy vào nhẹ 5 %.
  4. *Bi chạy:* máy đi song song đường bi mục tiêu từ một bên (cùng phía 180°), cao ~45 cm, thấy cả bi và lỗ.
  5. *Lọt lỗ:* góc thấp lệch 35–45° so với đường bi vào lỗ (không đặt ngay miệng lỗ), bi rơi + tia sáng.
  6. *Kết:* cẩu lên gần trên cao trong 1,2 s, hiện **vệt đường bi** của cả cú (bi cái trắng, bi mục tiêu màu bi), điểm va chạm.
  Không có lọt lỗ: cảnh 5 thay bằng góc theo bi dừng; cú phá: cảnh 3–5 thay bằng toàn bàn cao + chậm lúc bung.
- **Học** (cho người muốn hiểu cú): nhìn từ trên cao hoặc 3/4 cao cố định, vệt đường bi vẽ dần theo thời gian, đánh dấu điểm va chạm/băng, hình bi ma tại lúc chạm, tua kéo thanh thời gian, tốc độ 0,25×–1×.

**Chọn tay (6):** Người đánh · Toàn bàn 3/4 · Trên cao · Theo bi cái (cao 35 cm, sau 1 m, nhìn trước) · Ngang băng (máy chạy song song) · Đón ở lỗ.
Bỏ: Cẩu quay, Action Mix (thay bằng Đạo diễn), Chéo 45°, Đón đầu, Trên đầu theo bi, Xoay va chạm. Giá trị đã lưu `replayCamera041` ánh xạ sang góc gần nhất (không mất cài đặt).

**Teaser / xuất video:**
- Chọn khung **16:9** hoặc **9:16** (dọc cho TikTok/Reels/Shorts); máy tự bố cục lại cho khung dọc (cảnh 4 và 6 khác nhau giữa hai khung).
- Bản "Teaser 8 s": cảnh Đạo diễn rút gọn + nhạc/âm đồng bộ + thẻ cuối logo Zoker và mã thách bạn (0.47 M6).
- Ảnh thẻ (1 khung đẹp nhất: lúc va chạm hoặc bi rơi) để chia sẻ nhanh.

## 4. Mốc

### M1 — Lõi bộ lập kế hoạch (C++, phiên đám mây làm trước trên `cho/native-0.48-core`)
`CameraPlanner`: vào = bản ghi (vị trí bi theo thời gian + sự kiện), hình học bàn, tỉ lệ khung; ra = danh sách cảnh (thời điểm, kiểu), đường máy (mắt, điểm nhìn, FOV theo thời gian, đã làm mượt hai chiều), đường cong tốc độ phát.
Test (chạy trên Linux, dùng các cú ghi sẵn: thẳng, cắt 30°, bank, kick, phá):
- Tốc độ góc của máy ≤ 90°/s, gia tốc góc không có đỉnh > 600°/s² (không giật); vị trí mắt liên tục (trừ đúng điểm cắt).
- Bi chính nhìn thấy (tia mắt → bi không bị bi khác, băng, đèn che) ≥ 95 % thời gian mỗi cảnh.
- Mỗi cảnh ≥ 1,2 s; không cắt trong 0,3 s trước khoảnh khắc chính; luật 180° giữ qua các cảnh liên tiếp.
- Đường tốc độ liên tục, đạo hàm bị chặn (không bật/tắt).
- Khung 9:16 và 16:9: bi chính luôn trong vùng an toàn (cách mép ≥ 8 %).

### M2 — Nối vào SceneKit (phiên Mac)
- `ReplayDirector` và các góc "Action" đọc đường máy từ `CameraPlanner` (lập một lần khi mở xem lại); bỏ đặt camera theo khung hiện tại.
- Vệt đường bi trong xem lại (dùng `table.trails`), hiện dần theo thời gian ở chế độ Học và ở cảnh Kết của Đạo diễn.
- Menu góc máy còn 2 tự động + 6 chọn tay; ánh xạ cài đặt cũ.

### M3 — Xuất video và teaser
- Khung 16:9 / 9:16; "Teaser 8 s"; ảnh thẻ; logo + thẻ cuối.
- Âm thanh xuất khớp tốc độ phát (đoạn chậm thì âm không bị kéo dài sai: giữ tiếng va chạm ở tốc độ thật, như phim).

### M4 — Kiểm
- Test C++ M1 PASS; XCTest mở xem lại 5 cú mẫu, đổi góc, xuất 2 khung.
- Đo độ mượt máy quay trên máy thật (chủ dự án): bảng chẩn đoán thêm "tốc độ góc máy p95/max" cho lần xem lại vừa rồi.
- Ảnh/video mẫu 5 cú × 2 khung đẩy lên `shots/native` để chủ dự án duyệt mắt (tiêu chí cuối cùng là mắt người xem).
