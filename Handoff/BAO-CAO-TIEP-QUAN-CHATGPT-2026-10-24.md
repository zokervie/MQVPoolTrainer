# Zoker Pool Trainer — báo cáo tiếp quản, G0/G1 và phản biện

Cập nhật: 2026-10-24T20:51:17+07:00 (Việt Nam). Chủ dự án: Zoker / Mai Quốc Việt.

**Kết luận:** đã lấy đủ source private, khóa baseline, tạo hai ZIP source bằng bootstrap gốc, chạy regression portable và đẩy code G1 lên nhánh riêng. **Chưa đóng G0 native và G1 acceptance:** môi trường hiện tại không có Xcode/Mac/iPhone; Swift/ClangImporter, UI, cảm ứng thật và IPA mới chưa được kiểm chứng. Không merge main.

## 1. Nguồn chuẩn và SHA

| Mục | Giá trị xác minh |
|---|---|
| Repository | https://github.com/zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858 (private) |
| Main/base SHA | `aba66d0f21e0816973ef0c13281fa98855ca3ff6` |
| Base tree | `d0fad303831a8c4a257a31e38d688093d2d21b1e` |
| Nhánh triển khai | `feature/0.13-hud-camera` |
| Head SHA đã đẩy | `efabf7e3fb853e50612db3b4d5b54b6edd262791` |
| Head tree | `3aea4ea1cb5cd7fdfd0376772e523817c206ccee` |
| Draft PR | https://github.com/zokervie/ZokerPoolTrainer-0.11-Native-Jump-Masse-2026-10-21-0858/pull/1 |
| Baseline files | 113 tracked blobs, 147 tree entries, 588.522 bytes |
| Candidate files | 131 tracked files; 31 file thay đổi so với baseline |
| Candidate build metadata | 0.13 / build 23; `com.maiquocviet.BankLabS` |
| Main sau triển khai | Vẫn `aba66d0f21e0816973ef0c13281fa98855ca3ff6` |

Đã đọc README_FIRST_VI, AGENT_START_HERE, trạng thái, FEATURE_AUDIT và toàn bộ Master Patch 0.13–0.14. Master Patch mới được copy vào source và đặt ưu tiên cao hơn tài liệu bố trí effect trái cũ.

Git CLI không có credential clone, nên lấy recursive tree và đủ bytes của tất cả blob qua kết nối GitHub đã xác thực. Mọi file được kiểm kích thước + Git blob SHA; tree và commit cũng được dựng lại khớp chính xác. Snapshot local là shallow; ZIP chứa toàn bộ tracked source, không chứa toàn bộ lịch sử Git. Công cụ bootstrap trong gói được giữ nguyên và chạy với local mirror đã xác minh, nên SOURCE_MANIFEST ghi đường dẫn local mirror; SOURCE_PROVENANCE ghi canonical GitHub URL.

## 2. Hai bản ZIP hoàn chỉnh

Các archive có `ProjectSource/`, `Handoff/`, `SOURCE_MANIFEST.json`, `INTERNAL_SHA256SUMS.txt`. Đã kiểm CRC và SHA-256 của từng file ProjectSource với manifest.

- `ZokerPoolTrainer_FULL_SOURCE_AND_HANDOFF_aba66d0f21e0.zip`: 113 file source tại `aba66d0f21e0816973ef0c13281fa98855ca3ff6`, 962,501 bytes.
  SHA-256: `48ffc93282b107e50ed094747487f84cd58eecdab77dffe6e79c84668a4131b7`.

- `ZokerPoolTrainer_FULL_SOURCE_AND_HANDOFF_efabf7e3fb85.zip`: 131 file source tại `efabf7e3fb853e50612db3b4d5b54b6edd262791`, 1,009,779 bytes.
  SHA-256: `3b951bd89f7a98640027201859c25cd216b949f4dd28f1e32fdef55a16441ae3`.

ZIP là source snapshot, không phải IPA. Texture/mesh/icon lớn được sinh lại bằng `Tools/prepare_ci_assets.py`; chúng không được Git track trong baseline. Candidate ZIP có thêm audit, Master Patch, feature matrix, log kiểm thử và QA plan trong `ProjectSource/native/ZokerPoolTrainer/Docs/`.

## 3. Những gì thực sự đã có

| Nhóm | Xác nhận từ source/test | Giới hạn |
|---|---|---|
| Kiến trúc | UIKit/SceneKit + BLWorld Objective-C++ + native C++17, single authoritative solver | Không có Swift/Xcode compile mới trong phiên này |
| Vật lý | Spin transfer, băng, lỗ, fixed-step, prediction, elevated/jump/massé optional | Tests mô phỏng đã pass; chưa hiệu chuẩn bằng số đo bàn thật |
| Hình ảnh | PBR/material generators, bi quay quaternion, shadow, pocket fall, 20 table looks | 20 looks dùng 6 base styles; chưa phải 20 profile vật lý đo độc lập |
| Trang bị | 12 cue looks, 3 bao cơ, 3 vai trò cơ | Cue presets còn mang tính minh họa |
| Thao tác | B hold + pull/push stroke, Undo/restoration quaternion, replay, đặt bi | G1 thêm guard; dispatch/hit areas UIKit chờ chạy |
| Luyện tập | 46 layout theo source: 15 foundation + 5 lực + 8 cut + 18 bank/kick; goals/history/CSV | Chưa kiểm chứng khả thi/góc mẫu/scoring cho toàn bộ 46 bài |
| Lưu dữ liệu | layouts, practiceHistory, equipment/cloth settings | Format cũ được giữ nguyên |
| Âm thanh | Procedural PCM từ physics event, cache worker, giới hạn 12 voices | Chưa có sample pack thật được cấp phép; allocation player còn ở main |

Đã đối chiếu 30 dòng FEATURE_AUDIT thành FEATURE_MATRIX.csv, giữ cột trạng thái lịch sử và thêm trạng thái hiện tại, code/test evidence, remaining gate và mapping sang ID Master Patch (một số CAM/CUE ID giữa hai tài liệu có nghĩa khác nhau).

## 4. G1 đã sửa gì

| Master ID | Thay đổi code | Bằng chứng đang có | Chưa đủ để đóng |
|---|---|---|---|
| CAM-01 | Mọi shot chuyển Overview3D; orbit/pinch trong lúc bi lăn | Source + policy regression | Visual/gesture on Simulator/device |
| CAM-02 | Chờ engine đứng, pocket fall xong và rest 0,5s; smoothstep 0,45s về Aim3D | Production policy clock/tween tests, 30/60/120Hz, replay/spectator/gesture exceptions | Swift bridge, actual camera pose/projection, scratch/Undo/replay UI |
| CAM-03 | Default Aim3D mode 2 ở scene + controller; lưu aim zoom | Source; startup probe đã viết | Probe chưa chạy |
| HUD-01 | Effect phải elevation; View/Undo phải; B trái; tool flyout cho cơ/bao/đặt/thêm 1 bi | Production layout model trên 4 safe-area sizes; guard 64 tổ hợp permission | Actual Auto Layout/hit-test, touch reach |
| HUD-02 | Bài tập chỉ trong Menu; bỏ quickPractice, giữ chức năng chọn bài | Source và hướng dẫn trong app được cập nhật | Inspect ảnh + thao tác thật |
| REG-01 | Giữ Core/Touch/Models/Equipment; giữ snapshot/persistence; không thay hệ số vật lý | 11 protected files byte-identical + các bộ hồi quy cũ pass | Native build và toàn trình device QA |

PresentationPolicy.h là policy C nhỏ, header-only, được Swift nhập qua bridging header; tests C++ gọi trực tiếp cùng code production. Không có renderer/physics thứ hai. localTurn chỉ là hook quyền cho offline/QA; chưa có multiplayer.

Các probe UIKit mới: default, hud, hud-expanded, return, spectator. Screenshot script xóa evidence cũ và yêu cầu đủ 5 JSON PASS mới. Các probe đã được viết nhưng **chưa chạy**.

## 5. Chức năng còn thiếu / các file cần làm tiếp

| Gate | Còn thiếu hoặc chưa được chứng minh | File/module cần sửa |
|---|---|---|
| G1 | Compile Swift/C bridge; runtime camera/gesture/Auto Layout; ảnh 2 cỡ iPhone + iPad; 30 tình huống chạm thật | UI/TrainingController.swift, Rendering/TableScene.swift, UI/PresentationPolicy.h, Tools/ci_screenshots.sh |
| G2 | Cue shaft tránh rail; effect clamp động cùng prediction/strike; không tự gây jump ngoài ý muốn | Rendering/TableScene.swift:cuePose/showCue, UI/TouchControls.swift, UI/TrainingController.swift; thêm pure geometry + tests |
| G2 | Random N 1–15 theo seed, không chồng bi/lỗ, replayable snapshot | Thêm Practice/RandomRackGenerator.swift và tests; thay addBall grid bằng workflow thêm/đặt lại/xáo lại |
| G3 | Real samples có provenance/license, voice preloading, mixing/latency | Thêm Audio/PoolSoundEngine.swift, Assets/Audio manifest; nối physics events |
| G3 | Tích hợp D01–D10, xác minh đường/góc/pass từng bài và metadata video | UI/Models.swift, lesson catalogue versioned, geometry/reachability/scoring tests |
| G4 | Simulator/IPA/new checksum, real-device touch/FPS/thermal | Xcode project, root Codemagic/GitHub workflow, QA evidence |
| G5–G7 | Phòng 6 số, luật 8/9-ball, authority/seq/snapshot/hash, scoreboard, reconnect, 2 máy | Network/RoomClient, RulesEngine, SnapshotCodec + backend; chưa triển khai trong đợt này |

## 6. Kiểm thử và CI thực tế

| Kiểm tra | Kết quả |
|---|---|
| Baseline Run-All lần đầu | FAIL do repo thiếu generated texture; log giữ nguyên |
| Tạo assets bằng generator sẵn có | PASS; numpy 2.3.5, scipy 1.17.0, Pillow 12.3.0, matplotlib 3.10.8 |
| Baseline resource/JS/C++ sau prepare | PASS: 4 JS suites + 12 C++ suites; Physics 2.304.486 assertions, Prediction 378 samples, Contact 761 checks |
| Candidate resource/JS/C++ | PASS: 4 JS + 13 C++, gồm 32 G1 policy scenarios |
| C11 syntax của header, shell, YAML, plist, metadata | PASS |
| 11 protected files byte comparison | PASS |
| Verify-on-Mac.command | BLOCKED / exit 127: `xcodebuild: command not found` |
| 5 UIKit probes + screenshot QA | NOT RUN |
| Physical iPhone/iPad test | NOT RUN |
| IPA 0.13 build 23 | NOT PRODUCED |

Log nằm trong `Docs/Evidence/G0-G1-2026-10-24/`. Resource checksum pass trên output tái tạo hiện tại; generator có ghi lại manifest, vì vậy không coi đó là chứng minh asset giống byte với IPA 22. Generated assets/manifest không được đưa vào patch.

GitHub Actions trên main: 5 run gần nhất failure, run mới nhất 40083592188 / job 120841915560 không có step hoặc runner được ghi nhận. Log endpoint trả 404; không đọc được annotations bằng connector. Chưa xác định lý do; **không kết luận billing hay lỗi compile**. Candidate feature branch hiện có 0 Actions run vì workflow auto-push chỉ nhắm main; draft PR không đồng nghĩa CI đã chạy. Codemagic #24 là evidence lịch sử trong RELEASE-BUILD22, chưa truy vấn live trong phiên này.

## 7. Phản biện và tối ưu đề nghị

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

## 8. File đã thay đổi trong commit G1

- `.github/workflows/xcode-build.yml`
- `README.md`
- `codemagic.yaml`
- `native/ZokerPoolTrainer/BankLab/BankLab-Bridging-Header.h`
- `native/ZokerPoolTrainer/BankLab/Rendering/TableScene.swift`
- `native/ZokerPoolTrainer/BankLab/UI/PresentationPolicy.h`
- `native/ZokerPoolTrainer/BankLab/UI/TrainingController.swift`
- `native/ZokerPoolTrainer/Docs/ARCHITECTURE.md`
- `native/ZokerPoolTrainer/Docs/EXTERNAL-ASSETS-INVENTORY.md`
- `native/ZokerPoolTrainer/Docs/Evidence/G0-G1-2026-10-24/SOURCE_PROVENANCE.json`
- `native/ZokerPoolTrainer/Docs/Evidence/G0-G1-2026-10-24/baseline-assets.log`
- `native/ZokerPoolTrainer/Docs/Evidence/G0-G1-2026-10-24/baseline-run-all-initial.log`
- `native/ZokerPoolTrainer/Docs/Evidence/G0-G1-2026-10-24/baseline-run-all.log`
- `native/ZokerPoolTrainer/Docs/Evidence/G0-G1-2026-10-24/g1-policy.log`
- `native/ZokerPoolTrainer/Docs/Evidence/G0-G1-2026-10-24/g1-run-all.log`
- `native/ZokerPoolTrainer/Docs/Evidence/G0-G1-2026-10-24/g1-structure-checks.log`
- `native/ZokerPoolTrainer/Docs/Evidence/G0-G1-2026-10-24/g1-xcode-attempt.log`
- `native/ZokerPoolTrainer/Docs/Evidence/G0-G1-2026-10-24/protected-files.json`
- `native/ZokerPoolTrainer/Docs/FEATURE_MATRIX.csv`
- `native/ZokerPoolTrainer/Docs/G0-BASELINE.md`
- `native/ZokerPoolTrainer/Docs/G1-IMPLEMENTATION.md`
- `native/ZokerPoolTrainer/Docs/MASTER-PATCH-0.13-0.14.md`
- `native/ZokerPoolTrainer/Docs/NEXT-ACCEPTANCE-2026-10-24.md`
- `native/ZokerPoolTrainer/Docs/NEXT-RELEASE-REQUIREMENTS.md`
- `native/ZokerPoolTrainer/Docs/OBJECTIVE-REVIEW.md`
- `native/ZokerPoolTrainer/Docs/QA-MATRIX-G1.md`
- `native/ZokerPoolTrainer/Run-All-Checks.command`
- `native/ZokerPoolTrainer/START-HERE-VI.md`
- `native/ZokerPoolTrainer/Tests/PresentationPolicyTests.cpp`
- `native/ZokerPoolTrainer/Tools/ci_screenshots.sh`
- `native/ZokerPoolTrainer/ZokerPoolTrainer.xcodeproj/project.pbxproj`

## 9. Tiến độ và bước kế tiếp

G0: source/provenance/feature audit/portable baseline đã có bằng chứng; Mac/native gate mở. G1: code candidate + portable tests đã đẩy và có draft PR; Swift/UIKit/device gate mở. G2–G7 chưa bắt đầu implementation trong đợt này. Không báo phần trăm hoặc “hoàn tất” khi thiếu evidence.

Bước tiếp theo cụ thể là dùng môi trường Mac/Xcode đã kết nối để checkout đúng head trên feature branch; chạy prepare assets → Run-All → Verify-on-Mac → ci_screenshots → inspect 5 JSON mới + ảnh → thử chạm thật. Sau khi qua mới build unsigned IPA 0.13/23 và ghi checksum; không chạy GitHub/Codemagic trùng nhau. Xem QA-MATRIX-G1.md để có lệnh và acceptance chi tiết.

Không có máy Mac hoặc iPhone được điều khiển trong phiên này. Chưa phát hành/ký app hoặc triển khai dịch vụ có phí.
