# Zoker Pool Trainer 0.12 — hồ sơ nghiệm thu tiếp theo
Ngày chốt yêu cầu: 24/10/2026 (Việt Nam).
Mốc đã build: IPA build 21, Codemagic run #19, commit 45d919e.
Trạng thái cập nhật: source build 22 đã sửa tại commit 2dd1a55 và Codemagic #24 đã build thành công. Xem RELEASE-BUILD22.md để biết chính xác phần đã triển khai/kiểm tra. Các checkbox là tiêu chí nghiệm thu trên máy thật/bàn thật; không tự đánh dấu hoàn thành chỉ vì CI qua.

> Ưu tiên hiện tại: MASTER-PATCH-0.13-0.14.md. G1 mới là candidate có code và portable tests; mọi checkbox UI/máy thật bên dưới vẫn chờ nghiệm thu.

## 1. Giao diện ngang và thao tác
- [ ] Bi effect ngay bên phải thanh nâng cơ; B độc lập bên trái. Mở rộng effect phải chặn B/stroke và không chồng vùng chạm.
- [ ] Cụm phải: elevation/effect, Góc nhìn/Lùi cú; cơ/bao cơ/đặt bi trong flyout Dụng cụ. Bài tập chỉ nằm trong Menu.
- [ ] Duy trì nút Đánh lại/Undo ngoài menu; phục hồi đúng vị trí và hướng xoay bi trước cú đánh.
- [ ] Kiểm tra safe area, màn hình ngang, tầm với ngón tay và trạng thái mở rộng bi effect. Tránh việc mở effect làm mất công cụ quan sát cú đánh.

## 2. Camera quan sát SAU KHI RA CƠ
- [ ] Có góc toàn bàn/zoom out để khảo sát đầy đủ đường chạy sau khi đánh.
- [ ] Khi bi đang lăn: xoay trục bằng hai ngón, pinch zoom, chuyển góc trên cao/toàn cảnh/ngắm mà không cần chờ bi dừng.
- [ ] Không xoay/zoom camera bằng thao tác một ngón dành cho ngắm/đánh; không phát sinh cú đánh ngoài ý muốn.
- [ ] Chuyển từ ngắm sang quan sát mượt, không giật góc hay tự bám bi làm mất đường chạy.
- [ ] Giữ góc chỉnh tay khi bi lăn. Sau tất cả bi dừng, pocket animation xong và ổn định 0,5 giây: tween về Aim3D; tôn trọng replay/spectator và gesture đang hoạt động.
- [ ] Có nút khôi phục toàn cảnh/góc ngắm; chuyển về góc chuẩn bị cú tiếp theo mượt.
- [ ] Nghiệm thu trong roll dài, bank/kick 1/2/3 băng, jump, rơi lỗ và replay.

## 3. Kích thước và đồ họa
- [ ] Rà đồng nhất kích thước bi, mesh, bóng đổ, điểm chạm cơ, lỗ và băng trong cùng hệ mét.
- [ ] Cấu hình hiện có: mặt chơi 1,27 × 2,54 m và bi 57,15 mm; xác minh mesh và camera thay vì sửa hằng số đúng để bù phối cảnh.
- [ ] Đo riêng miệng lỗ góc và lỗ giữa theo profile bàn; hình hiển thị khớp hình va chạm/capture.
- [ ] Nỉ có vân sợi mịn, normal/roughness và hướng sợi vừa phải; tăng chi tiết khi zoom gần, tránh sọc lặp và moiré.
- [ ] Giữ tùy chọn màu nỉ và màu mặc định từng mẫu bàn.
- [ ] Chấm bi tròn đều, bám đúng bề mặt bi khi xoay; bi có chất liệu và phản sáng hợp lý.
- [ ] Bóng râm bi lăn đậm vừa, mềm mịn, chi tiết; khi jump bóng tách theo độ cao.
- [ ] Bi rơi lỗ có chuyển động xuống/sâu và che khuất hợp lý; trạng thái vào lỗ do native solver quyết định.
- [ ] Duy trì thư viện mẫu bàn/cơ, tên thương hiệu/mẫu và nút kim cương đúng vị trí theo kích thước mặt chơi.

## 4. Vật lý truyền xoáy và băng liên tiếp
- [ ] Ball-ball: tính trượt tương đối tại tiếp xúc, xung lực pháp tuyến/tiếp tuyến giới hạn Coulomb và mô-men lên cả hai bi.
- [ ] Không áp quy tắc luôn truyền xoáy ngược: kiểm tra cut-induced spin, gearing ngoài, thiếu/thừa gearing và tác động follow/draw.
- [ ] Ball-rail: dùng vận tốc tại mũi băng gồm vận tốc tịnh tiến và xoáy 3D; cập nhật cả vận tốc và spin sau mỗi va chạm.
- [ ] Truyền trạng thái sau băng thứ nhất sang băng đối diện/tiếp theo; góc hẹp/rộng sinh từ trạng thái hiện tại, độ nảy và ma sát từng băng.
- [ ] Dùng ảnh đường vàng IMG_7353.jpeg làm ca cần đối chiếu, không coi nét vẽ là bộ số liệu đo.
- [ ] Kiểm tra bảo toàn/tiêu hao năng lượng, đối xứng trái/phải, không xuyên băng và đồng nhất dự báo với mô phỏng thật.
- [ ] Lưu thông số bàn/nỉ/băng và dữ liệu đo thực nghiệm. Chưa có số đo thì ghi mô phỏng ước lượng, chưa được gọi hiệu chuẩn bàn thật.

## 5. Cơ và bi effect
- [ ] Một cơ sở tọa độ cho marker effect, điểm chạm mặt cầu, đầu cơ, hướng đánh và camera.
- [ ] Thay điểm effect phải làm đầu cơ/cây cơ ngoài cảnh di chuyển tương ứng quanh trục/điểm tựa tay sau đã chốt.
- [ ] Kiểm tra center, trái/phải, trên/dưới và phối hợp 2 chiều ở góc ngắm, góc cao, toàn cảnh; không đảo dấu khi xoay camera.
- [ ] Kết hợp elevation/jump angle với effect mà không lệch marker so với tip.

## 6. Mượt, âm thanh và bài tập
- [ ] Đo frame time trên iPhone 14 Pro Max, kiểm tra bi lăn chậm/dài và sau impact. Tối ưu render/nội suy, giữ nguyên kết quả vật lý fixed step.
- [ ] Âm thanh phân biệt chạm cơ/bi/băng/lỗ, thay cường độ theo va chạm và vị trí. Dùng âm tự tạo hoặc được cấp phép.
- [ ] Thư viện bank/kick 1/2/3 băng chia cấp độ, có thế bi, mục tiêu, hướng dẫn, công thức/hình học và routine luyện.
- [ ] Phân biệt phản xạ hình học lý tưởng với dự báo động lực học; không khẳng định công thức kim cương chính xác trên mọi bàn.

## 7. Chuỗi nghiệm thu và bàn giao
1. Hoàn thiện các thay đổi source, ghi từng mục đã sửa và giới hạn còn lại.
2. Chạy hồi quy physics/geometry/presentation/resource; thêm ca gear effect và hai băng.
3. Build Simulator và Release iPhone trên Codemagic.
4. Xem ảnh QA: camera sau shot, bố trí effect phải elevation/Menu phải, các điểm chạm cơ, nỉ cận cảnh, bi/lỗ, bài tập.
5. Thử cảm ứng, camera, FPS và nhiệt trên iPhone thật; không dùng ảnh Simulator thay bước này.
6. Kiểm tra bundle com.maiquocviet.BankLabS, version/build, cấu trúc IPA và SHA-256.
7. Bàn giao IPA trong ZIP dễ tải trên iPhone; nêu rõ trạng thái ký. ZIP không thay thế ký app.

## Bằng chứng và giới hạn
- Ảnh người dùng: IMG_7352.png, IMG_7353.jpeg, IMG_7354.png.
- Checklist kỹ thuật bổ sung: NEXT-RELEASE-REQUIREMENTS.md.
- Một workflow chạy trên commit chỉ thay MD là kiểm tra baseline, không xác nhận các yêu cầu chưa được sửa trong source.
