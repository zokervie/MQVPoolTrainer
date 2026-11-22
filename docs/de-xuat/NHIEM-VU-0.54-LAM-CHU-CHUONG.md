# Giao việc 0.54 — "Làm chủ chương": thang vòng, danh hiệu, quỹ lùi cú (cho phiên Mac)

Chủ dự án duyệt 22/11 (phương án B: lùi TestFlight đầu ~1 tuần để có Chương 1 mới và danh hiệu).
Nhánh lõi: `origin/cho/native-0.54-lam-chu-chuong` (= 0.53 phễu lỗ + 76b7d19). Làm SAU khi xong P0 và P1 của 0.53;
gộp nhánh lõi này vào nhánh 0.53 đang làm. Xung đột có thể có ở `DrillCatalogData.h`, `measured.json`: lấy bản 0.54,
chạy `python3 Tools/drills/gen_catalog.py --check`.

## Lõi đã có (C, đã test trên Linux)
- `DrillCatalog.h`: `BLDrillSpec.tier` (0 = bài thường; 1…3 = cùng thế bi, vòng nhỏ dần; 3 hàng liên tiếp, khoá
  `force-…-1/2/3`). Bài vòng có `rails > 0` và không ăn bi: bi cái phải chạm ĐÚNG số băng (`BLDrillJudge` lo).
- 27 bậc chương 1 (khoá `force-near`, `force-far`, `force-1rail-short`, `force-1rail-long`, `force-2rail`,
  `force-2rail-long`, `force-3rail`, `force-follow`, `force-draw`, mỗi thang 3 vòng). Tỉ lệ đo: 62–80 / 45–66 / 23–52 %.
- `UI/Mastery.h` (đã thêm vào bridging header):
  `BLRoundStars(spec, made, 5)` · `BLChapterPercent(bestStars, n)` · `BLTitleIndex(percent)` (0…9) ·
  `BLTitleLowerPercent(i)` · `BLTierOpen(tier, starsVòngTrước)` · `BLWarmupDone(made)` · `BLChapterUndoBudget(ch)` ·
  `BLChapterUndoLeft(ch, used)` · `BLChapterUndoAllowed` · `BLChapterCleanSeal(percent, used)` ·
  `BLLadderRungs(ch, idx, cap)` · `BLLadderPrevious(index)`.
  Không tự viết lại các luật này trong Swift.

## Việc trên Mac
**M1. Chương 1 mới "Kiểm soát lực".** Màn chương hiện 9 thang (mỗi thang một thẻ có 3 vòng tròn to–vừa–nhỏ, sao tốt
nhất của từng vòng) + thẻ thứ 10 "Bài thi" (5 thế rút ngẫu nhiên từ các vòng đã mở, hạt giống theo lần thi). Các bài
cũ của chương 1 (`first-shot`, `speed-1…3`) giữ ở cuối dưới tiêu đề "Bài cũ" — không xoá, không tính vào %.
Lời mở đầu chương (nguyên văn chủ dự án, sửa chính tả):
> Chúng tôi tin rằng sau khi vượt qua chương này với điểm số càng cao và càng ít dùng quyền trợ giúp, bạn sẽ hoàn
> thiện khả năng kiểm soát lực và xứng đáng với danh hiệu mà game trao tặng.

**M2. Luồng một thang.** Vòng to: 5 cú khởi động phải vào vòng (`BLWarmupDone`), hiện "Khởi động 3/5", chưa tính sao.
Sau đó mỗi lượt chấm = 5 cú, sao = `BLRoundStars`. Vòng kế mở khi vòng trước đạt 3 sao (`BLTierOpen`). Vòng nhiệm vụ
LUÔN hiện, kể cả khi giữ B (đã có ở 0.53 A2). Thanh lực tắt trong chương (0.53 C1). Bài có băng: dòng yêu cầu ghi rõ
"chạm đúng N băng rồi dừng trong vòng"; trượt vì sai số băng thì báo "Sai số băng: M".

**M3. % hoàn thiện và danh hiệu.** % = `BLChapterPercent` trên 27 bậc. Danh hiệu = `BLTitleIndex`. Tên (vi — en):
0 Tay Mơ Có Chí — Keen Rookie · 1 Khách Quen Bàn Số 3 — Table 3 Regular · 2 Triển Vọng — Prospect ·
3 Bậc Thầy Đánh Phủi — Street Master · 4 Trùm Quán Quen — Local Boss · 5 Hung Thần Phố Bida — Terror of Pool Street ·
6 Cáo Già Sa Mạc — Desert Fox · 7 Chuyên Gia — Expert · 8 Bảo Vật Quốc Gia — National Treasure · 9 Thiên Tài — Genius.
Biệt danh chương 1: "Bàn Tay Nhung" — "Velvet Hand". Màn chương hiện danh hiệu hiện tại + "còn N % nữa lên <bậc sau>"
(`BLTitleLowerPercent`). Lên bậc: thẻ chúc mừng một lần, có nút Khoe.

**M4. Quỹ lùi cú.** Mỗi chương đếm số lần "Lùi cú" đã dùng (lưu theo khoá chương). Còn lại = `BLChapterUndoLeft`
(chương 1: không giới hạn, hiện "∞"). Hết quỹ: nút Lùi cú mờ, chơi tiếp bình thường, KHÔNG xoá tiến độ. Trong Cài đặt
chương có "Chơi lại chương từ đầu" (xác nhận hai bước): xoá sao + đặt lại quỹ — đường duy nhất lấy lại dấu "Tay sạch"
(`BLChapterCleanSeal`). Chỉ áp dụng trong Bài tập theo chương; Chơi tự do và Đấu không đổi.

**M5. Thẻ khoe.** Ảnh 1080×1350: tên người chơi · danh hiệu · biệt danh chương · % · dấu "Tay sạch" nếu có · logo
Zoker Pool. Không có đường ngắm hay lời giải. Dùng bảng chia sẻ của iOS. Khung gỗ + font Petemoss như menu.

**M6. Test.** Swift: luồng khởi động → chấm → mở vòng; hết quỹ lùi cú không mất tiến độ; % và danh hiệu khớp C.
UI test: mở chương 1, vào thang đầu, thấy vòng khi giữ B, thẻ danh hiệu hiện đúng với tiến độ giả lập (cờ QA).
`bash Tools/accept_local.sh`. Báo cáo `NGHIEM-THU-0.54.md`: mỗi mục PASS / FAIL / NOT RUN.

## Ghi chú
- Mọi ngưỡng (5 cú khởi động, 3 sao mở vòng, dải %, quỹ 100/70/50/30, cỡ vòng) là quyết định của chủ dự án hoặc
  GIẢ ĐỊNH; sẽ chỉnh theo số liệu TestFlight. Đừng rải số trong Swift: gọi hàm C.
- Chương 2–9 chưa có thang vòng; màn chương của chúng giữ như 0.49b, chỉ thêm quỹ lùi cú (M4) và % theo sao hiện có
  nếu rẻ; nếu không thì để sau.
- Phần cảm giác: "chưa xác minh trên thiết bị".
