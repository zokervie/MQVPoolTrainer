# Nguồn và phạm vi áp dụng — BankLab 0.6

0.6: mesh bàn nguyên bản được tạo bằng hình học polygon và triangulation, không lấy asset từ ảnh/game tham khảo. Quaternion tích lũy ở bước vật lý; phép đổi trục render tuân theo tính chất vector trục của phép phản xạ. Không có dữ liệu mới từ bàn thật và chưa có phép so sánh hình ảnh/FPS native với Shooterspool.

## Phạm vi thay đổi 0.5

Giảm chói bằng vật liệu/đèn/exposure, sửa chiều xoay render, thêm nhãn bi và dùng World riêng để dự báo 12 giây. Gia tốc, hệ số vải/băng và các công thức va chạm chưa được thay bằng mô hình thực nghiệm khác. Kiểm thử mới xác nhận công thức trượt/lăn và tính nhất quán dự báo; chưa chứng minh khả năng áp dụng thi đấu. Mục hướng dẫn cũ nói đường gương là lịch sử, không còn là đường mặc định trong 0.5.

Kiểu exposureOffset và cơ chế tone mapping đối chiếu [tài liệu Apple](https://developer.apple.com/documentation/scenekit/scncamera/exposureoffset). Không coi kiểm tra tài liệu API là thay thế build/link hoặc đánh giá hình ảnh trên máy thật.

## Bổ sung PoolShot và đối chiếu đồ họa 0.4

- [PoolShot Software](https://poolshot.org/pages/logiciel-poolshot): trang công khai giới thiệu phần mềm tạo bài trên Windows và tài nguyên hướng dẫn. Đã đọc trang, chưa cài/chạy phần mềm Windows.
- [103 Training Drills](https://poolshot.org/products/fichier-drl-103-training-drills-pour-poolshot-software-niveau-1): tham khảo mô tả nhóm kỹ thuật, mục tiêu và ghi điểm; chưa mua/đọc DRL hoặc sao chép sơ đồ.
- [US Pool](https://poolshot.org/pages/billard-americain): liên kết danh mục gốc trong mục Học, không nhập các bộ bài.
- Thế bi, vùng đích và mục tiêu 7/10 do BankLab đặt riêng. Bốn bài vùng đích và một bài bank một băng mới chấm bằng trạng thái mô phỏng, không nhận diện bàn thật. Nhật ký là thống kê thô, không phải thang trình độ chuẩn hóa.
- [Shooterspool](https://www.shooterspool.net/) và [Virtual Pool 4](https://vponline.celeris.com/vp4offover): nguồn chính chủ để xác định chuẩn tham khảo, không phải phép đo so sánh trực tiếp. Không lấy model, texture, logo hoặc mã nguồn của hai game.

Đồ họa 0.4 viết lại bằng SceneKit: hình học, vật liệu procedural và HUD. Chưa render thử bằng Apple SDK ở đây. Không trình bày ảnh AI như ảnh chạy thật, không tuyên bố đã đạt chất lượng ngang các game trên.

Đối chiếu ngày 15/10/2026. Đã đọc trang hướng dẫn chính thức và tài liệu kỹ thuật; lấy liên kết YouTube từ trang của tác giả. Không khẳng định đã xem/đo từng khung hình video. Không có sự chứng nhận hoặc hợp tác với các tác giả. Không sao chép mã nguồn pooltool, video, hình minh họa hay tài sản Shooter Pool.

## Huấn luyện

- Dr. Dave, [Bank and Kick Shots](https://drdavepoolinfo.com/tutorial/kicks-and-banks/): phân biệt bank/kick và danh mục video. Mục Học liên kết video về hệ nút, kick hai băng và điều chỉnh. Bài 2–4 băng của BankLab là thế bi tự thiết kế, chưa có lời giải chuẩn.
- [Two-to-One](https://drdavepoolinfo.com/faq/bank-kick/two-to-one/): mốc ngắm cần điều chỉnh theo điều kiện. App dùng để hướng dẫn so sánh; chưa triển khai bộ giải hệ nút.
- [Effects](https://drdavepoolinfo.com/faq/bank-kick/effects/): luyện tách lực, xoáy và góc. Bài so sánh trong app giữ nguyên thế bi, thay một yếu tố mỗi lần.
- [Corner-5](https://drdavepoolinfo.com/faq/bank-kick/corner-5/): tài liệu đọc thêm; số thứ tự nút trong app KHÔNG phải thang Corner-5. Chưa có lớp số hay phép tính tương ứng.
- Dr. Dave/Bob Jewett, [bài bank VEPP, tháng 2/2013](https://drdavepoolinfo.com/bd_articles/2013/feb13.pdf): tham khảo ý tưởng thay góc cắt. App hướng dẫn tự đặt bi, không chép sơ đồ; chưa tự chấm bài bank một băng.
- [Testing Kicks and Banks](https://drdavepoolinfo.com/faq/bank-kick/testing/): dùng làm cơ sở yêu cầu kiểm tra bàn trước khi áp dụng hệ ngắm.

Video chính chủ được liên kết từ trang hướng dẫn:
- https://www.youtube.com/watch?v=rcWccgPnoso
- https://www.youtube.com/watch?v=UhIH0BmuSdE
- https://www.youtube.com/watch?v=11iSqkJjWgM

## Vật lý

[pooltool: mô hình va chạm](https://pooltool.readthedocs.io/en/latest/autoapi/pooltool/physics/index.html) phân biệt mô hình xung lực có ma sát 3D rồi giới hạn chuyển động về mặt phẳng với mô hình Mathavan. BankLab 0.3 dùng cách tính xung lực riêng thuộc nhóm gần đúng thứ nhất; KHÔNG triển khai hoặc nhận là mô hình Mathavan đầy đủ.

- Băng: pháp tuyến nghiêng theo độ cao tiếp xúc, cánh tay đòn hướng tâm, ma sát tiếp tuyến giới hạn Coulomb; cập nhật vận tốc góc ba thành phần. Xung lực pháp tuyến đi qua tâm không tự tạo mô-men quay.
- Bi–bi: tính vận tốc trượt tại tiếp điểm gồm đủ ba thành phần xoáy, rồi xung lực ma sát và chuyển xoáy. Loại vận tốc tịnh tiến đứng vì bàn vẫn là mô hình mặt phẳng.
- Vải: trượt chuyển sang lăn; cản lăn riêng; ma sát không chỉ là nhân vận tốc với một hệ số mỗi khung hình.
- Độ cao tiếp xúc băng mặc định 0.4 bán kính trên tâm là tham số giả định, không phải số đo bàn của người dùng. Hệ số đàn hồi là tham số tiếp xúc, không nhất thiết bằng tỷ lệ tốc độ ngang trước/sau nảy khi pháp tuyến nghiêng.

## Chưa được xác nhận

Không có dữ liệu thực nghiệm bàn của anh; chưa xác nhận sai số đường về sau 2–4 băng. Chưa mô phỏng biến dạng cao su theo thời gian, đáp ứng băng theo lực bằng số đo, nhảy, massé/swerve/squirt, rơi lỗ 3D hoặc biến thiên vải. Độ ổn định số và hao năng lượng không chứng minh độ giống bàn thật.

Lịch sử: bản 0.3 giữ đồ họa 0.2 và tập trung giáo trình, dữ liệu đo, sửa tiếp xúc. Bản 0.4 đã viết lại cảnh như mô tả đầu tài liệu, nhưng vẫn chưa có kiểm chứng hình ảnh trên thiết bị hoặc bộ asset được nghệ sĩ 3D hoàn thiện theo chuẩn sản phẩm.

## Quy trình đối chiếu đề xuất

1. Đo quãng đường và thời gian bằng video có chuẩn kích thước trên bàn thật; tránh lỗ/băng khi đo cản lăn.
2. Dùng bài Đo độ lăn ở lực thấp, rồi Đo độ nảy, chỉnh từng thông số. Không suy tất cả tham số từ một cú.
3. Giữ lại một nhóm cú chưa dùng để chỉnh; đối chiếu các góc/lực/ép phê khác nhau và đường nhiều băng.
4. Xuất CSV của cú mô phỏng qua Thế bi. CSV là mẫu trạng thái khoảng 30 Hz, không phải log từng bước 960 Hz; không dùng hai mẫu gần băng để suy chính xác xung lực va chạm. Ghi riêng cấu hình bàn, thế bi, góc và điểm chạm khi so sánh nhiều lần.
5. Chỉ kết luận phạm vi lực/góc nào đủ chính xác sau khi có số đo sai lệch. Hiện chưa có kết quả hiệu chuẩn đó.
