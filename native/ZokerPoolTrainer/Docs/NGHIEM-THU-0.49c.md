# NGHIỆM THU 0.49c "Giao diện bàn chơi" — nhánh `cho/native-0.49-xuong-bai`

Thứ tự giao: G8 → G7 → G4 → G3 → G6 → G5 → G2 → G1. Làm được G8, G4, G6; còn lại CHƯA LÀM (hết sức trong phiên). Chưa xác minh trên thiết bị.

| Mục | Kết quả | Ghi chú |
|---|---|---|
| G8 luật phá 3 bi | PASS (công tắc) / NOT RUN (UI ván 9 Ball) | Công tắc "Luật phá 3 bi (giải đấu)" trong Tuỳ chỉnh, mặc định tắt, gán vào `BLMatch` mỗi ván (`Prefs.threeBallBreak`, khoá cố định, PrefsTests). Dòng giải thích đúng câu của đặc tả. Lõi C++ đã có test (c41bf0d). Test UI "phá có bi vào vẫn lượt người phá" chưa viết: cần cờ QA ép cú phá có bi vào. Khi hai máy chơi qua mạng, công tắc của máy chủ phòng quyết định luật (chưa kiểm). |
| G7 giật 60 Hz | CHƯA LÀM | |
| G4 ẩn dải quang phổ | PASS (xây + không hồi quy) / NOT RUN (kiểm bằng mắt) | Dải màu, vệt sương và vòng quang phổ chỉ hiện khi bật "Hiện dải quang phổ lực khi vuốt (chẩn đoán)"; số lực cuối vuốt giữ nguyên. Chưa có test UI/ảnh kiểm "không còn dải". |
| G3 thanh lực nhỏ + bật/tắt | CHƯA LÀM | |
| G6 nút Đặt bi 64 pt | PASS | UI test: nút ngoài menu, ≥ 64 pt, chạm vào/ra chế độ kéo bi. Mờ khi luật không cho đặt bi (logic, chưa test UI). Vị trí "mép trái, trên hàng loại cơ" theo `f.cues`, chưa xem ảnh. |
| G5 giảm chói | CHƯA LÀM | |
| G2 khung gỗ + chữ bút lông | CHƯA LÀM | cần font Petemoss (OFL) + OFL.txt + màn Pháp lý |
| G1 sơ đồ = ảnh bàn 3D | CHƯA LÀM | |

## Kết quả accept_local (@a29cbed)
7/8 bước PASS; `ui-gesture-tests` 35/36: `testPlaceCueBallAtCentreAndCancelRestoresLayout` FAIL vì nút "Đặt bi" mới trùng nhãn với mục menu (test chọn theo nhãn). Đã sửa (nhãn trợ năng "Nút đặt bi") và chạy lại riêng test đó + test nút mới: PASS. Chưa chạy lại toàn bộ accept_local sau sửa (NOT RUN, đã chạy lẻ 2 test). Bước IPA không ký chưa chạy ở lượt này (accept dừng sau bước UI).
