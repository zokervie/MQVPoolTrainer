# BLUEPRINT TRIỂN KHAI CỤ THỂ (KHÔNG THAY SOURCE TRONG GÓI NÀY)

## G1: HUD + camera — điểm cắt code tối thiểu

1. `TrainingController.swift`: `buildHUD()` đang gắn `spin.leadingAnchor` ngay cạnh `lockButton.trailingAnchor` dưới trái, `retryButton` phía trên B. Sửa `NSLayoutConstraint`, không tạo 2 instance SpinPad/Undo. Đưa **spin sang phải elevation**, Undo vào cụm phải nhưng bảo toàn vị trí nút B độc lập bên trái.
2. `TrainingController.swift`: `buildQuickRail()` còn quickPractice và quickCue/Bag. Đổi thành flyout phải với các thao tác ít sử dụng; **bài tập chỉ còn nút trong Menu**, giữ tính năng `chooseDrill()`.
3. `TrainingController.swift`: `buildHUD()` hiện đặt `table.cameraMode=1` (top); `TableScene.swift` cũng `cameraMode=1`. Thay tiêu chí default Aim3D (`mode=2` trong source hiện tại) và cập nhật nhãn, lưu cấu hình; không thay enum số tùy tiện mà thiếu migration.
4. `TrainingController.swift`: `shoot()` đã lưu `savedAimCamera` và bật `observationCamera`, nhưng `finishShot()` mới kết thúc mô phỏng/chấm điểm, **chưa tự gọi logic trả aim sau trạng thái đứng yên**. Thêm state Settling/camera return queue ở main display loop, không dùng timer nguồn thời gian không xác định. `clearShot()` có `restoreAimCamera` cũ, tránh double-restore.
5. `TrainingController.swift`: gesture `orbitTable`, `pinchTable` sử dụng hai ngón và pinch được phép khi shotActive; `panTable` một ngón thay góc ngắm khi idle. Tách input mode cho `Aiming / Observing / Replay / Spectating`, thêm test chống accidental stroke khi spin expanded/menubar hoặc opponent turn.
6. `TableScene.swift`: `placeCamera` camera top dùng orthographic and `orbit`; overview dùng orbitPitch 3D. Keep physical projection transforms and 3D rendering stable; đảm bảo không làm mất khung khi ball sunk/scratch.
7. Add visual CLI QA flags/scripts/Swift tests: default aim, post-shot, after-stop return, right HUD 3 sizes, camera zoom/top 3D, spectator input disabled.

## G2: cue/cushion clearance + effect dynamic + random balls

1. `TableScene.swift`: `cuePose()`/`showCue()` hiện tính `pivot`, `contact`, shaft axis + radial offset, nhưng chưa chứng minh thân cơ tránh mesh băng khi bi kề rail. Viết pure geometry helpers tính khoảng cách/mesh envelope, **đừng chỉ ẩn cơ khi bị cấn**.
2. `TouchControls.swift:SpinPad` có `maximumOffset` mặc định 0.7 và UI cho vùng tròn. Nâng lên `allowedContactRegion` hoặc per-shot dynamic constraint: cue ball X/Z/rail distance/elevation/cue shaft envelope. UI và native physical shot đều dùng input clamp như nhau.
3. `TrainingController.swift:setElevation` hiện đổi 0.6 experimental / 0.7 normal. Nếu thêm auto elevation, tách `requestedElevation` vs `effectiveElevation`; nếu auto không được mong đợi, chỉ cảnh báo người dùng nâng cơ, tránh làm cú đánh nhảy ngoài ý muốn.
4. `TrainingController.swift:addBall()` hiện chọn ID nhỏ nhất và thử vị trí grid cố định. Tách `generateLegalBallLayout(seed:count:existing:)` thuần hàm: phân bố bàn chơi, cách bi khác >2R+epsilon, cách pocket/jaw, không ghi đè bi trắng, giới hạn 15 id, bounded rejection sampling + deterministic fallback; cảnh báo khi practice/online lock.
5. Unit tests: 100 seed × mỗi count 1,3,6,9,15, scene ball count & no overlaps, 20 cue-rail configurations incl elevations 0°, 20°, 45°, 70°, effect combinations, 2 camera modes, side mirrored.

## Lưu ý 2 giai đoạn

- Không gộp thay đổi vật lý và UI trong 1 commit lớn; thêm test thuần trước, sau đó nối UI.
- Không chỉnh các hệ số restitution/friction để bù shot path/render QA.
- Không xóa save format hoặc mất layouts đã lưu sau nâng cấp; nếu thêm thuộc tính mới `Codable` cần default migration.
- Sau G1–G2 mới tiếp tục âm/giáo trình/online theo Master Patch.
