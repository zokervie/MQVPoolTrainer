# Dữ liệu tham khảo đã kiểm tra (19/10/2026)

Nguồn được ưu tiên theo độ tin cậy: (1) tiêu chuẩn WPA; (2) bài báo có bình duyệt (Mathavan et al., Kim 2024, JOSS); (3) Dr. Dave Alciatore (giáo sư cơ khí, Colorado State — technical proofs + trang hằng số); (4) pooltool (mã nguồn mở, Apache-2.0, giá trị mặc định tự ghi "chưa nghiên cứu kỹ"). Diễn đàn chỉ dùng để tìm nguồn, không lấy số.

Mỗi số đưa vào code phải mang `Provenance.published` kèm nguồn ở đây; khoảng giá trị dùng làm giới hạn hợp lệ trong `TableDefinition`.

## 1. Đối chiếu tham số hiện có

| Tham số (code) | Ta đang dùng | Giá trị công bố | Nguồn | Kết luận |
|---|---|---|---|---|
| `ballRadius` | 0,028575 m | 2¼″ ± 0,005″ (57,15 ± 0,127 mm) | WPA [1] | Khớp |
| `ballMass` | 0,17 kg | 5½–6 oz (156–170 g) | WPA [1] | Khớp (cận trên) |
| `nineFoot` / `eightFoot` | 2,54×1,27 / 2,34×1,17 m | 100×50″ / 92×46″ (+⅛″) | WPA [1][2] | Khớp |
| `cushionHeightRatio` | 0,635 | 63½ % (± 1 %) đường kính bi | WPA [1][2] | Khớp — nâng nhãn lên **đã công bố** |
| `slidingFriction` | 0,2 | 0,15–0,4, điển hình 0,2 | Dr. Dave [3]; Kim 2024: ~0,1 trượt, 0,2–0,4 tĩnh [6] | Khớp |
| `rollingResistance` | 0,01 | 0,005–0,015 | Dr. Dave [3]; Kim 2024: ~10⁻² [6] | Khớp |
| **`spinFriction`** | **0,044 → dω/dt ≈ 37,8 rad/s²** | **5–15 rad/s²** | Dr. Dave [3]; pooltool mặc định u_sp ≈ 0,0127 → ≈ 10,9 rad/s² [5] | **Lệch ~2,5–7 lần**: xoáy ngang tắt quá nhanh → bi effect ngang yếu hơn thật. Harness pooltool đang gán 0,044 cho cả hai bên nên đối chứng không phát hiện. Đề xuất 0,0127 (nằm giữa khoảng) — sửa ở nhiệm vụ riêng có test |
| `ballBallFriction(v)` | 0,118 → ~0,01 theo tốc độ trượt | 0,03–0,08 (điển hình) | Dr. Dave [3]; Kim 2024 [6]; mô hình theo tốc độ: Alciatore TP A.14 | Khớp mô hình TP A.14 (cùng pooltool 0.6) |
| `ballBallRestitution` | 0,94 | 0,92–0,98 | Dr. Dave [3]; Kim 2024 [6] | Khớp |
| **`cushionRestitution`** | 0,8 (chú thích ghi "Mathavan 2010, 0,75–0,85") | Dr. Dave 0,6–0,9 [3]; Mathavan 2010: **0,98** (mô hình băng cứng, đến 2,5 m/s) [4] | **Ghi nguồn sai**: Mathavan không báo 0,75–0,85. Giữ 0,8 nhưng đổi nguồn sang Dr. Dave (khoảng) + nhãn "giả định, đo ở M3" |
| **`cushionFriction`** | 0,2 (chú thích "Mathavan ~0,2") | Mathavan 2010: **0,14** [4]; pooltool 0,2 [5] | **Ghi nguồn sai**. Đổi nguồn sang pooltool; ghi Mathavan 0,14 làm biến thể so sánh |
| `tableRestitution` | 0,5 (giả định) | 0,5–0,7 | Dr. Dave [3] | Nâng nhãn lên đã công bố (khoảng) |
| Thời gian tiếp xúc bi–bi (âm thanh) | ~250 µs ở 1 m/s (giả định) | 250–300 µs | Kim 2024 [6] | Khớp — nâng nhãn |
| Ma sát đầu cơ–bi | — | 0,6 | Dr. Dave [3] | Dùng cho giới hạn miscue |
| Hệ số phục hồi đầu cơ–bi | — | da 0,71–0,75; phenolic 0,81–0,87 | Dr. Dave [3] | Kiểm tra `CueModel` |
| Thời gian tiếp xúc đầu cơ | — | 1–2 ms (0,8–3 ms) | Dr. Dave [7], Jacksonville Project 1998 [8] | Cho haptic/âm thanh cú cơ |
| Đầu tẩy | dấu Ø13 mm | tối đa 14 mm | WPA [2] | Khớp |

## 2. Hình học lỗ (cho M1.2 — R1.8 miệng lỗ)

| Thông số WPA [1][2] | Lỗ góc | Lỗ giữa |
|---|---|---|
| Miệng (giữa hai mũi băng) | 4,5–4,625″ (114,3–117,5 mm) | 5–5,125″ (127–130,2 mm) |
| Góc cắt ngang của mặt hàm (so với băng) | 142° (± 1°) | 104° (± 1°) |
| Góc nghiêng dọc mặt hàm (back draft) | 12–15° | 12–15° |
| Kệ lỗ (từ mũi băng đến mép rơi) | 1–2¼″ (25–57 mm) | 0–⅜″ (0–9,5 mm) |
| Lớp mặt hàm (facing) | 1/16–¼″, ưu tiên ≤ ⅛″ | như lỗ góc |

Mô hình hiện tại: miệng 45°, mũi hàm là điểm, đường bắt giữ — **chưa có** góc mặt hàm 142°/104° và kệ lỗ. Đưa hai thông số này vào sẽ cho cùng hình học với thực tế và gần pooltool hơn.

Kiểm chứng định tính (Jewett, đo bằng 4 bi xếp thẳng, 50% vào lỗ [9]): bi mạnh làm **lỗ hiệu dụng hẹp hơn**; ở góc tới ~6°, cú nhẹ có độ mở ~gấp đôi cú mạnh; ở 30–45° cú mạnh rộng hơn ~¼″. Có thể viết test: độ rộng hiệu dụng mô phỏng phải giảm theo tốc độ ở góc nhỏ.

Mục tiêu hiệu dụng của lỗ ≈ 3″ cho cú chậm vào lỗ đầy đủ (Alciatore TP A.13 [10]) → sai số góc cho phép Δθ = 2·atan((p/2)/d): 14,3° ở 1 ft, 4,8° ở 3 ft, 2,4° ở 6 ft. Dùng để kiểm tra độ khó bài tập (khoảng ngắm đạt).

## 3. Băng

- WPA kiểm tra độ nảy: đánh giữa bi, cơ ngang, lực chắc, từ điểm đầu qua điểm cuối → bi đi được **4–4½ chiều dài bàn** không nảy lên [1][2]. "Lực chắc" không ghi tốc độ → chỉ dùng như kiểm tra thô: với tốc độ "fast" của Dr. Dave (1,9–3,2 m/s [11]), mô phỏng phải ra 4–4,5 chiều dài.
- Mathavan 2010 [4]: mô hình băng cứng hợp lệ tới tốc độ pháp tuyến ~2,5 m/s; trên ngưỡng đó cần băng biến dạng → ghi giới hạn trong `docs/01-physics.md`.
- Bề rộng phần băng bọc nỉ 1⅞–2″ [1].

## 4. Tốc độ bi cái điển hình (Dr. Dave [11])

| Kiểu cú | m/s |
|---|---|
| Chạm nhẹ | < 0,45 |
| Chậm | 0,45–0,89 |
| Vừa | 0,89–1,9 |
| Nhanh | 1,9–3,2 |
| Mạnh | 3,2–4,5 |
| Phá mạnh | 11–13 (cực mạnh ~16) |

Dùng để: kiểm tra thang lực 1–7 phủ đúng dải; bộ 10.000 cú phải có cú phá 11–13 m/s (tốc độ bi, không phải tốc độ cơ).

## 5. Squirt (đẩy bi cái do đánh lệch tâm)

- Đầu cơ lệch 9/16″: cần gỗ 13 mm lệch ~2¼″ tại băng; cần low-deflection (Predator Z) ~1⅝″, ít hơn ~40%. Loại đầu tẩy, độ cứng, chiều cao đầu tẩy ảnh hưởng rất ít; **khối lượng đầu cần là yếu tố chính** [12].
- → Tham số squirt nên gắn với "loại cần" (thường / low-deflection), không với đầu tẩy. Hàng chờ M2: lựa chọn cần trong cài đặt.

## 6. Còn thiếu (chưa có nguồn định lượng tốt)

- Âm thanh va chạm (phổ, mức âm theo tốc độ): không tìm thấy dữ liệu đo công bố → vẫn phải tự thu (UPGRADE 6.7).
- Ma sát xoay theo loại nỉ cụ thể (Simonis 860/760…): chỉ có mô tả định tính (Dr. Dave: nỉ trơn giữ xoáy lâu hơn, bi cong muộn hơn [13]).
- Hình học miệng lỗ của từng hãng: hãng không công bố → dùng khoảng WPA.

## Nguồn
1. Thông số bàn chuẩn WPA (bản đăng lại): https://www.cuesportsindia.com/equipments/3/pool-table
2. Thông số thiết bị giải đấu (WPA, gồm bi và cơ): https://www.poolroom.com/tournament-table-equipment-specifications/
3. Dr. Dave Alciatore, hằng số vật lý thiết bị bida: https://drdavepoolinfo.com/?p=2349
4. Mathavan, Jackson, Parkin (2010), *A theoretical analysis of billiard ball dynamics under cushion impacts*, Proc. IMechE Part C 224(9):1863–1873: https://journals.sagepub.com/doi/10.1243/09544062JMES1964 (bản lưu: https://dspace.lboro.ac.uk/2134/15087)
5. pooltool `BallParams` (giá trị mặc định): https://pooltool.readthedocs.io/en/latest/_modules/pooltool/objects/ball/params.html · Kiefl (2024), JOSS 9(101):7301: https://joss.theoj.org/papers/10.21105/joss.07301
6. Kim (2024), *Collision of two spinning billiard balls and the role of table*, arXiv:2402.13258: https://arxiv.org/pdf/2402.13258v1
7. Dr. Dave, thời gian tiếp xúc đầu cơ: https://drdavepoolinfo.com/faq/cue-tip/contact-time/
8. Jacksonville Project (1998): https://drdavepoolinfo.com/?p=2672
9. Jewett (2013), kích thước lỗ hiệu dụng: https://billiards.colostate.edu/bd_articles/jewett_may_2013_pocket_size_part1.pdf
10. Alciatore, TP A.13: https://billiards.colostate.edu/technical_proofs/new/TP_A-13.pdf
11. Dr. Dave, tốc độ bi cái: https://drdavepoolinfo.com/?p=2486
12. Alciatore, thử squirt theo đầu tẩy/cần (Billiards Digest 06/2014): https://billiards.colostate.edu/bd_articles/2014/june14.pdf
13. Dr. Dave, ảnh hưởng của nỉ: https://drdavepoolinfo.com/faq/table/cloth-effects/
14. Danh mục tài liệu vật lý bida (Coriolis, Marlow, Han 2005, Leckie & Greenspan, Mathavan, Cross 2008): https://www.engr.colostate.edu/~dga/pool/physics/
15. Mathavan et al. (2014), *Numerical simulations of the frictional collisions of solid balls on a rough surface*, Sports Engineering 17:227–237: https://link.springer.com/article/10.1007/s12283-014-0158-y
