# Đối chiếu bộ đặc tả (`docs/dac-ta/`) với bản iOS hiện tại

✅ đã có · 🟡 có một phần / làm khác · ⬜ chưa làm

## Vật lý (01-physics)
- ✅ Trượt → lăn, cản lăn, xoay trục đứng giảm dần; bi–bi có ma sát (throw do cắt và do xoáy ngang); squirt; massé (nâng cơ); băng có chiều cao mũi băng; túi + hàm lỗ (bật mép túi).
- ✅ Bàn 9/8/7 ft, miệng lỗ, góc cắt, kệ lỗ, mũi băng, hồi phục băng, nỉ nhanh/chậm – lưu theo **hồ sơ bàn** (`TableSpecs.swift`).
- ✅ Deterministic: cùng đầu vào → cùng kết quả (kiểm thử đối chiếu với engine web khớp tới 1e-6 m, và phát lại cú đánh).
- ✅ Quy tắc 90° / 30°, quãng lăn v² = 2μgd tự xuất hiện (kiểm thử).
- 🟡 Mô phỏng **bước cố định 0,5 ms** (phương án dự phòng trong đặc tả) thay vì theo sự kiện. Đủ chính xác cho luyện tập, chạy ~1 ms/khung.
- ⬜ Swerve theo khối lượng đầu cơ, nhảy bi; mô hình băng Mathavan 2010 đầy đủ.

## Điều khiển (02-controls)
- ✅ Chỉ màn hình ngang, đổi tay trái/phải, điều khiển trong safe area.
- ✅ Vuốt để ngắm; **hai ngón = ngắm tinh**; vi chỉnh ‹ ›.
- ✅ Khoá cơ (nút rõ ràng thay cho vùng ẩn – dễ dùng hơn khi mới tập) + rung.
- ✅ Ra cơ bằng cú vuốt: kéo lùi rồi đẩy; **lực = tốc độ ngón tại vạch** (hồi quy 5 mẫu cuối); đo lệch ngang & ngắt cơ; tuỳ chọn để lỗi này ảnh hưởng thật (không ngẫu nhiên).
- 🟡 Bi effect: bàn chọn điểm đánh luôn hiện (đặc tả: thu nhỏ/ẩn khi khoá).

## Camera & đồ hoạ (03)
- ✅ Góc nhìn sau cơ (độ cao/khoảng cách chỉnh bằng kéo dọc/hai ngón), chế độ nhìn từ trên (2D), toàn cảnh khi bi chạy.
- ✅ PBR bi bóng, nỉ mờ, gỗ / khung sơn theo hãng, đèn bàn, bóng đổ mềm, nút kim cương.
- ✅ Mức chất lượng Thấp/Trung bình/Cao/Tự động, hạ mức khi `thermalState` nghiêm trọng.
- ⬜ RealityKit (đang dùng SceneKit, chạy từ iOS 16), gyroscope, ray tracing.

## Bài tập (04)
- ✅ Định dạng JSON theo kim cương: `bi`, `danh_dau` (vị trí bi, vùng đích, điểm băng), `huong_dan` (lực 1–7, điểm chạm, công thức, ghi chú), `dieu_kien_dat`, `so_lan`, `lech_ngau_nhien`. Nhập/xuất, chia sẻ.
- ✅ Thang lực 1–7: 0,8 · 1,3 · 2,0 · 3,0 · 4,3 · 6,0 · 8,0 m/s (tốc độ bi cái).
- ✅ 24 bài có sẵn + 3 bài mẫu JSON; đánh dấu dạng decal trên nỉ.
- ⬜ Trình soạn bài kéo-thả (hiện soạn bằng JSON).

## Phản hồi (05)
- ✅ Số liệu chỉ hiện SAU cú: tốc độ & mức 1–7, "lăn bao nhiêu chiều dài bàn", lệch hướng ngắm, lệch mm tại lỗ, độ thẳng cú vuốt, ngắt cơ, throw thực tế, nút chạm băng so với dự tính.
- ✅ Phát lại chậm.
- 🟡 Lưu thống kê theo bài (UserDefaults), chưa có lịch sử từng cú (SwiftData).

## Tính năng mở rộng (06)
- ✅ 1 Bóng ma cú trước · ✅ 3 Thử thách ổn định lực · ✅ 4 Kiểm tra ngắm (thiên lệch trái/phải) · ✅ 5 Hồ sơ bàn · ✅ 9 Chia sẻ bài JSON · ✅ 14 Luật 8/9 bi (chơi tự do).
- ⬜ 2 Đánh lại đúng cú (có thể dùng "Làm lại" + bài JSON) · 6 Pre-shot routine · 7 Nhật ký tập theo tuần · 8 Tạo bài từ ảnh (Vision) · 10 Hiệu chỉnh camera 240 fps · 11 AR · 12 Cảm biến cơ.
