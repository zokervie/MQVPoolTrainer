# Phản biện tổng thể và tối ưu — 24/10/2026

Đánh giá dựa trên code tại aba66d0 và patch G1, không coi release notes là test mới. Hướng đi UIKit/SceneKit + C++ hiện tại đủ để tiếp tục; chưa có dữ liệu GPU/CPU buộc phải thay engine. Ưu tiên đóng các vòng luyện tập/feedback và đo độ đúng trước khi mở rộng online.

| Ưu tiên | Phát hiện từ source | Hệ quả | Đề xuất và cách chứng minh |
|---|---|---|---|
| P0 | Camera/HUD/stroke trước đây rải nhiều bool; expanded effect không nằm trong allowed guard | Có đường bật B/stroke khi đang chỉnh effect; không có auto-return cuối cú | Patch G1 gom clock/guard/layout vào policy nhỏ dùng chung tests; tiếp theo build Swift–C bridge và chạy 5 UIKit probes + 30 tình huống chạm thật |
| P0 | GitHub run thất bại trước khi có step; không đọc được logs/annotations trong phiên này | Không biết nguồn lỗi; chạy lại nhiều lần không cho thêm evidence | Lấy thông báo scheduler/billing thực tế từ trang Actions hoặc runner trước; giữ một Mac build, feature branch/tag cụ thể, artifact có source SHA và probe JSON. Không tự kết luận lỗi code |
| P0 | Swift UIKit chưa có test target; screenshot gate chủ yếu đếm pixel màu nỉ | Ảnh xanh không chứng minh nút bấm đúng, app chưa crash hay camera trở aim | G1 thêm actual-frame/hit-test và runtime return/spectator probes. Tiếp theo XCTest/XCUITest từ sự kiện người dùng, thiết bị nhỏ + 14 Pro Max + iPad |
| P1 | 46 layout sinh từ 15 foundation + 5 lực + 8 cut + 18 bank/kick; góc 18 bài mới vẫn là atan2 trực tiếp tới bi đích cho cả bank và kick | Có bài chưa có góc mẫu có thể làm được; khó phân biệt người chơi sai và bài đặt sai | Dùng generator geometry/reflection hoặc inverse search làm seed, chạy reachability/scoring cho từng ID, giữ solver cuối cùng quyết định. Chỉ công bố bài mẫu khi có trajectory/reference pass; không bịa hệ số bù góc |
| P1 | 20 TableLook có 6 base, 12 CueLook có 3 role presets; bàn giữ cùng SI dimensions/solver profile | 20 lựa chọn thị giác chưa tương đương 20 bàn/cơ được hiệu chuẩn vật lý | Tách appearanceID khỏi physicsProfileID. Trước mắt chọn 1 profile 9ft chuẩn và 1 profile bàn thật của đại ca, đo đường bi và uncertainty. Giữ mọi look đã có |
| P1 | Cue/effect có spherical contact và fixed pivot, nhưng clamp chỉ 0.6/0.7, chưa có rail envelope | Cơ có thể cắt rail hoặc hình/shot không cùng miền khả thi ở thế sát băng | G2 làm pure geometry cho envelope, 20 ca đối xứng; UI/prediction/strike nhận cùng requested/effective input. Mặc định cảnh báo nâng cơ, không tự biến cú thường thành jump |
| P1 | addBall chỉ grid 8×5, chọn ID trống; chưa có random seed/session | Không tái tạo thế luyện ngẫu nhiên hoặc chia sẻ với người tập cùng | Seeded RandomLayout riêng, 1/3/6/9/15 ×100 seeds, bounded placement và snapshot+seed+count; reset và thêm bi có ngữ nghĩa tách biệt |
| P1 | Prediction chạy đồng bộ từ CADisplayLink mỗi ≥0.18s; replay ghi snapshot mỗi display tick, paths riêng 30Hz | Solver prediction có thể chặn UI; số replay frame/memory phụ thuộc nhịp màn hình | Đo signpost CPU/p95 trước. Chuyển prediction sang world riêng với request generation/token để loại kết quả cũ; giới hạn replay theo timestamp, không sửa timestep/ma sát để chữa giật |
| P1 | Audio synth tạo/cache PCM trên worker nhưng AVAudioPlayer(data:) vẫn tạo player ở main cho mỗi impact | Cache chưa loại hết allocation/decode/start latency; rail/pocket đông tiếng dễ xung đột | G3 preload PCM + voice pool, sample hợp lệ/fallback, 12 voices giới hạn theo impulse. Đo trigger-to-output và peak dưới cùng gain; đừng chỉ thay file âm thanh |
| P1 | Asset generator ghi lại manifest; source checkout không có bytes texture/mesh. Lần tái tạo này làm 6 hash manifest thay đổi | Run-All trên clone mới thất bại nếu quên prepare; tự viết manifest rồi check không chứng minh tái tạo đúng artifact cũ | Cache bằng hash generator+deps, pin dependencies, tách expected manifest khỏi generated manifest và công bố generation provenance. G1 không đưa texture/manifest tái tạo vào source patch |
| P2 | ARCHITECTURE/NEXT-ACCEPTANCE cũ nói no elevated/no interpolation, effect trái/manual camera; root và native có 2 Codemagic configs | Agent/build có thể chọn nhầm spec hoặc workflow | G1 sửa precedence, copy Master Patch và sửa mô tả kỹ thuật sai. Giữ root Codemagic làm đường chính; hợp nhất config legacy trong nhánh CI riêng sau khi kiểm kết nối |
| P2 | Chưa có native room/rules/networking; localTurn trong G1 chỉ là UI permission hook | Cờ spectator không tạo thành multiplayer hoặc chống gian lận | Sau G4, làm protocol version/seq/snapshot/hash + table-driven rules trước transport. Host-authoritative chỉ là MVP; không gọi nó server-verified C++ physics |

## Những tối ưu đáng làm sớm

1. Một mẫu ShotRecord versioned (snapshot trước/sau, inputs đã clamp, physics profile/version, seed, event log, timestamps) phục vụ Undo/replay/CSV/online sau này; migration giữ nguyên layouts/practiceHistory.
2. Golden shot catalogue: các test số có expected event/path và phạm vi sai số; tách synthetic recovery khỏi dữ liệu bàn thật. Lấy bàn thật của đại ca làm mục tiêu hiệu chuẩn đầu tiên để giảm công thu thập.
3. Tách chi phí CI: resource/C++/JS rẻ trước, một lượt Mac simulator + probe, unsigned IPA sau. Chỉ giữ binary artifact có manifest SHA; không lưu IPA vào Git.
4. Một trang nghiệm thu cho mỗi build: yêu cầu → file/function → test/log → ảnh/clip → thiết bị → kết luận. Cho phép trạng thái CODE_READY/TESTED_PORTABLE/TESTED_SIM/TESTED_DEVICE thay vì chỉ Done.

## Thứ tự triển khai đề nghị

- Đợt hiện tại: đóng Swift/Xcode + UIKit G1, sửa lỗi thực tế nếu có; tránh gộp physics vào HUD PR.
- G2: cue clearance + effect reachability, sau đó seeded random; giữ test riêng để sai hình không bị chữa bằng restitution/friction.
- G3: xác minh từng layout và cải thiện hướng dẫn/scoring, audio voice pool + sample provenance. Giá trị luyện tập quan trọng hơn tăng thêm số preset.
- G4: đo touch/FPS/nhiệt trên iPhone 14 Pro Max, build 0.13 và nghiệm thu.
- G5–G7: online/rules/turn authority sau khi offline đáng tin cậy; hạ tầng và chi phí chỉ chốt bằng thông số chính thức tại thời điểm triển khai, chưa deploy dịch vụ trong đợt này.

Ba rủi ro lớn còn lại: Swift/UI chưa compile ở phiên này; chưa đo bàn thật/device; chất lượng bài tập chưa được kiểm chứng trên toàn catalog. Không đánh đổi ba việc này để báo tỷ lệ hoàn thành cao.
