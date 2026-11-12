# 0.40c — nhánh chờ (chưa build), sửa theo nghiệm thu 0.40b ngày 12/11/2026 23:36

Anh dặn: đẩy lên nhánh chờ, **khoan build**. Anh kiểm tra tiếp rồi gộp chung một lần.
- Nhánh: `cho/native-0.40c`. Không phải nhánh `ci/`, nên CI không tự chạy.
- Khi anh chốt, đẩy sang `ci/native-0.40c` để build.

## Kết quả nghiệm thu 0.40b
| # | Mục | Anh báo | Việc đã làm |
|---|---|---|---|
| 1 | Đấu với máy | Có lúc dừng quá 10 s. Cú đánh đều đặn, không tư duy, không điều bi, không đổi lực/effect, không nhảy/massé | Viết lại "đầu óc" của máy (mục bên dưới) |
| 2, 3, 4, 8 | — | Đạt | Giữ nguyên |
| 5 | Bảng điểm | Tên dài và tên ngắn làm bảng lệch | 2 ô tên luôn rộng bằng nhau; ô điểm và ô giữa cố định; bảng rộng cố định (50% màn hình, tối đa 400 pt). Tên dài tự rút gọn: "Nguyễn Văn Anh" → "N.V. ANH", "Máy · Quarter Pro" → "MÁY · QP" |
| 6 | Nỉ và thành băng | Sợi quá nhỏ khi zoom. Băng giả như gối, bóng đổ kỳ cục. Muốn bóng đậm hơn ở miệng lỗ | Xem mục "Hình ảnh" |
| 7 | Đồng hồ cú | Số giây nên nền trong và nằm cạnh tên người đánh, không đặt giữa màn hình | Số giây hiện trên ô tên của người đang đánh, chữ không có nền. Đổi màu vàng ở 10 s, đỏ ở 5 s. Nút "Gia hạn +" nền trong suốt, nằm dưới ô tên người đánh |

## 1. Máy đối thủ: nguyên nhân và cách sửa

**Nguyên nhân máy "dừng quá 10 s"** (đã tìm ra trong code):
- Máy luôn đánh cơ gần như nằm ngang. Gặp lúc bi cái sát băng hoặc sát bi khác, đường cơ cần nâng hơn 30°. App từ chối cú đánh đó, máy tính lại đúng cú cũ, lại bị từ chối…
- Sau 3 lần, đường thoát cũng có thể bị từ chối theo cách tương tự, và bộ đếm lỗi quay về 0. Thế là máy lặp vô hạn.

**Sửa:**
- Máy đo độ nâng cơ cần thiết bằng chính hàm của app (`UI/CueClearance.h`). Đường nào cần nâng quá 30° thì máy loại ngay khi lập kế hoạch, hoặc chọn nhảy/massé.
- Trước khi ra cơ, app đo lại một lần nữa.
- Nếu vẫn bị từ chối: máy tìm hướng gần nhất mà cơ với tới được. Nếu không có hướng nào, ghi là phạm lỗi không chạm bi, giống khi hết giờ. Lượt luôn được chuyển, không bao giờ treo.

**"Tư duy" mới.** Cách làm theo các AI bida từng thắng giải máy tính:
- PickPocket (Đại học Alberta, AAAI 2006): sinh cú theo loại, mô phỏng, lấy mẫu sai số tay, nhìn trước vài cú.
- CueCard (Stanford, vô địch Computer Olympiad 2008, IJCAI 2009): chọn cú chịu được sai số của chính tay mình.

Máy làm 5 bước:
1. **Sinh ý tưởng cú theo loại:** vào thẳng, băng 1 lần (từ Quarter Pro), combo (từ Semi Pro), nhảy vào lỗ (Pro, AI). Khi bị chắn: kick 1–2 băng, nhảy bi thoát (Pro, AI), massé thoát (AI).
2. **Chọn lực và effect cho từng cú:** 5 mức lực (nhẹ → mạnh), effect dọc (kéo, chặn, giữa, theo, theo mạnh), effect ngang ±0,3 R (Pro, AI). Cú kéo tự tăng lực theo khoảng cách bi cái phải đi. Mỗi cú được mô phỏng với đúng thiết lập app sẽ dùng khi đánh: gậy, độ nâng cơ, đầu típ, độ lệch hướng khi nâng cơ.
3. **Điều bi:** chấm điểm thế bi để lại cho cú sau. Pro và AI tính thêm cú sau nữa:
   - 9/10 bi: tính bi kế tiếp sau bi kế tiếp.
   - 8 bi: tính số lựa chọn còn lại.
   - Trừ điểm khi bi cái dừng sát lỗ hoặc sát băng.
4. **Thử bằng chính tay mình** (từ Quarter Pro): đánh thử vài cú tốt nhất 3–6 lần, mỗi lần có sai số tay đúng như cấp đó. Máy chọn cú vào được nhiều nhất và để lại thế bi tốt nhất với tay của nó, không chọn cú chỉ vào khi đánh hoàn hảo.
5. **Phòng thủ khi khó vào:** tìm cú để lại ít cơ hội nhất cho đối thủ.

**Tìm khe vào lỗ chính xác hơn.** Khe vào lỗ thật chỉ rộng khoảng 0,2–0,5°. Bản cũ dò thưa (mỗi 0,6–0,7°) nên hay bỏ sót khe. Bản mới dò từ tâm ra hai bên rồi chia đôi để tìm đúng mép khe.

**Nhịp đánh giống người.** Máy không còn đánh ngay sau một khoảng chờ cố định:
- Máy xoay cơ dần về hướng ngắm, hiện đúng gậy, độ nâng và điểm chạm, kéo cơ thử 2 lần rồi mới đánh.
- Thời gian suy nghĩ thay đổi theo cú: cú dễ 0,6 s, cú khó, cú thủ, nhảy hay massé tới 3,5 s.
- Thanh trạng thái ghi máy đang làm gì, ví dụ "Máy: kick băng thoát bi", "Máy: nhảy bi thoát bi 1".
- Hết lượt máy, gậy, độ nâng và effect của anh được trả lại đúng như trước.

**Bảng 6 cấp:**

| Cấp | Sai tay (góc) | Điều bi | Lực/effect | Đánh thử với tay mình | Đặc biệt |
|---|---|---|---|---|---|
| Beginner | 0,65° | không | lực ngẫu nhiên, đánh giữa bi | — | tin bi ma |
| Amateur | 0,47° | không, chỉ lo vào | 2 lực, theo | — | |
| Quarter Pro | 0,33° | 1 cú | 3 lực, kéo/giữa/theo | 3 lần | thủ, kick, băng |
| Semi Pro | 0,24° | 1 cú | 4 lực, 5 mức effect dọc | 4 lần | + combo |
| Pro | 0,17° | 2 cú | 5 lực, + effect ngang | 5 lần | + nhảy bi |
| AI | 0,08° | 2 cú | 5 lực, + effect ngang | 6 lần | + massé |

Các hệ số tay là **giả định**, sẽ chỉnh khi đánh với người thật.

**Test C++** (`Tests/OpponentTests.cpp`, 337 kiểm tra, khoảng 140 s, chạy trên Linux):
- Tỉ lệ vào trên 16 thế 1 bi, từ Beginner đến AI: 3 / 6 / 7 / 7 / 14 / 14.
- Bi cái sát bi khác ở phía sau: cả 6 cấp đều trả về cú mà app chấp nhận được. Đây là test giữ cho lỗi "máy chờ" không quay lại.
- Bàn đầy: mọi cú app đều chấp nhận, và máy tính xong trong hạn giờ.
- Pro dùng 5 mức lực và 4 mức effect dọc trên 14 thế 2 bi, có dùng effect ngang. Thế bi Pro để lại tốt hơn Amateur khoảng 19%.
- Cú nhảy (gậy nhảy, cơ nâng 34°) qua bi chắn chạm đúng bi mục tiêu trước. Khi bị chắn, Pro và AI đều chọn nhảy và chạm đúng bi.
- Mọi cú đều qua kiểm tra hợp lệ của app (`LANShot.isValid`).

## 2. Hình ảnh
- **Sợi nỉ:**
  - Mặc định mỗi sợi 1,0 mm (nỉ thật 0,55–0,7 mm, nhìn trên điện thoại quá mịn).
  - Vân hiện từ khoảng 2,2 điểm ảnh mỗi sợi (trước là khoảng 3).
  - Thêm thanh **"Độ thô sợi nỉ khi zoom gần"** (0,6–1,6 mm) trong Tuỳ chỉnh → Hình ảnh → Bàn. Đây là lần thứ 3 anh góp ý về vân nỉ nên em đưa thành tuỳ chỉnh.
- **Thành băng:**
  - Mặt cắt băng làm lại. Mũi cao su bo nhỏ khoảng 3 mm, mặt trên phẳng và dốc khoảng 7° lên tới gờ gỗ, mặt dưới lõm vào rồi chạm hẳn mặt bàn.
  - Bản cũ phồng 19 mm như gối và hở 7 mm dưới đáy, nên lộ một vệt sáng dưới mũi băng.
- **Bóng chân băng:**
  - Bóng chạy theo đúng đường mũi băng, kể cả hai má lỗ.
  - Dưới mũi băng (phần bị che) tối hẳn, rồi nhạt dần trong 2,6 cm ra mặt nỉ.
  - Càng gần miệng lỗ bóng càng đậm, tối đa gần gấp đôi, để nhìn từ xa vẫn thấy rõ độ rộng miệng lỗ.
  - Bóng mới thay cho 6 dải bóng cũ (dải cũ dừng trước má lỗ).

## Chưa xác minh
- Phần Swift (máy ngắm trên màn hình, bảng điểm, đồng hồ, băng, nỉ) **chưa biên dịch**: môi trường của em không có trình biên dịch Swift cho iOS. Lần build tới mới kiểm tra.
- Toàn bộ **chưa xác minh trên thiết bị**.
