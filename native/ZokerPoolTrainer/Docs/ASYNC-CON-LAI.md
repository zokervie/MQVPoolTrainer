# Việc còn lại sau 0.45 M5 (luồng khởi động, Prefs, cờ QA)

Cập nhật 18/11/2026, nhánh `cho/native-0.47`. Dọn dần khi đụng tới file; không sửa hàng loạt chỉ để "sạch".

## 1. `asyncAfter` đã thay bằng lời gọi (AppFlow)

| Trước | Sau |
|---|---|
| `TrainingController.viewDidAppear`: intro xong gọi lại `viewDidAppear(false)`; hướng dẫn `asyncAfter(0.4)`; Game Center `asyncAfter(2.5)` | `AppFlow.begin()`; intro `finish` → `appFlow.done(.intro)` |
| `Lobby046.afterLobbyClosed`: hướng dẫn `asyncAfter(0.4)`, Game Center `asyncAfter(2.5)` | Sảnh đóng → chạy hành động đã chọn → `appFlow.done(.lobby)` → hướng dẫn (nếu chưa xem) → bàn → Game Center |
| `Tutorial044.maybeStartTutorial` chạy từ hẹn giờ | gọi thẳng từ bước `tutorial`; cú đầu xong (`shotFinished`) hoặc `stop()` → `appFlow.done(.tutorial)` |

## 2. `asyncAfter` còn lại (67 chỗ) — phân loại

**A. Chỉ QA (`--*-qa`), không ảnh hưởng người chơi — để nguyên, chuyển dần sang chờ trạng thái khi test flaky:**
`TrainingController.swift` 357, 378–486 (≈ 22 chỗ: --replay-preroll, --coach-card, --cue-look, --wall-photo, --table-family,
--nearby, --retry, --library, --calibration, --ux0…); `PerfQA044mm.swift` (8); `WallPhotoQA0441.swift` (3);
`TableFamilyQA046.swift` (2); `CueLookQA0441.swift` (2); `Intro0441.swift` 397 (ảnh đầu dò intro).

**B. Thời lượng hiển thị (hợp lệ: "hiện X giây rồi ẩn") — giữ:**
`TC+HUD.swift` 589 (toast 3 s); `Highlights044.swift` 93 (chip 15 s); `Broadcast042.swift` 88, 113; `Loupes042.swift` 59;
`Tutorial044.swift` 234 (`hideLater`, gợi ý 6 s); `Intro0441.swift` 40, 328, 329; `Intro043.swift` 343, 344;
`NearbyLobby044mm.swift` 199 (tự đóng thông báo 14 s); `MusicPlayer042.swift` 90, 93; `PoolAudio.swift` 370, 380 (hàng âm).

**C. Nối bước bằng hẹn giờ — nên đổi sang lời gọi/sự kiện (ưu tiên 0.48):**
| File:dòng | Việc | Đề xuất |
|---|---|---|
| `TC+Coach.swift` 300 | lượt 5 cú: xếp lại bi sau 2,2 s | gọi khi bi dừng + camera xem lại xong (`presentationBusy` false) |
| `TC+Coach.swift` 318 | bảng "Qua bài" sau 1,2 s | hiện khi màn trình chiếu cú xong |
| `Tutorial044.swift` 162, 177 | "Thử lại nhé" → xếp lại bi sau 1,4 s, thăm dò 0,5 s × 60 | sự kiện "trình chiếu xong" từ ReplayDirector |
| `TC+HUD.swift` 286 | Menu → "Hướng dẫn chơi" sau 0,3 s | `setMenu(false)` có completion |
| `MatchPlayController.swift` 694, 943, 949, 1154 | lượt máy, highlight, ván mới | máy trạng thái trận (0.48+) |
| `Intro0441.swift` 211 | 3D chưa có khung trong 0,5 s → logo 2D | giữ (đây là hạn chờ an toàn, không nối bước) |
| `Intro043.swift` 73, 383 | intro cũ 0.43 (chỉ `--old-intro-qa`) | xoá cùng Intro043 |
| `TC+AimInput.swift` 145 | giữ mắt 0,25 s | giữ (cử chỉ) |
| `LocalMatchSession.swift` 859 | thử lại kết nối 1 s | giữ (mạng) |

## 3. Prefs — file còn dùng chuỗi khoá trần

Đã chuyển sang `Prefs.*` (file đụng tới ở 0.45 M5): `TrainingController`, `TC+ShotLoop`, `TC+Coach`, `TC+HUD`, `TC+Menu`,
`SettingsController` (Tuỳ chỉnh), `Tutorial044`, `Lobby046`, `Intro0441`, `Models` (`savedShots015`, `lessonStars035`).

Còn chuỗi trần (chuỗi đã có trong `Prefs`, chỉ việc thay):
- `Rendering/TableScene.swift` (17): tune*, ballWear021, clothWear021, legacyCue0441, tableSpace034 — nên thay `TableScene.tune* = Prefs.tune*`
- `UI/MatchPlayController.swift` (9): computerLevel040, lockstep044, playerName0/1, poolAudioEnabled, raceTo029, scoreboardStyle040, shotClock040, spectatorCam042
- `UI/TC+AimInput.swift` (8): aimCameraPitch014, aimCameraZoom013, cuePreset017-…, physics, shotKind017, squirtRealistic043, tuneAimPitch038, tuneAimZoom038
- `UI/EquipmentLibrary.swift` (4): activeBag015, cueBag015.…, tableDefault034, tableLook015
- `UI/Intro043.swift` (4), `UI/TC+Replay.swift` (3), `UI/Tutorial044.swift` (khai báo hằng → đã trỏ Prefs)
- `Audio/PoolAudio.swift` (soundPack041, tuneVolume037), `Audio/MusicPlayer042.swift` (musicVolume042)
- `Network/LocalMatchSession.swift` (lanPeerIdentity018, onlineRelayURL019)
- `Rendering/FramePacer.swift` (tuneFramePacing039), `Rendering/Rooms042.swift` (qaPhoto* — chỉ QA)
- `UI/L10n042.swift` (appLanguage042), `UI/Loupes042.swift`, `UI/Broadcast042.swift`, `UI/OpponentShot042.swift`, `UI/TouchControls.swift`, `UI/PerfQA044mm.swift`

Khoá `hudOffset036-…`/`hudSlot038-…` vẫn dựng trong `TC+HUD.hudOffsetKey/hudSlotKey` (Prefs có hàm tương đương, cùng chuỗi).

## 4. Cờ QA trong bản phát hành (0.45 M5.6)

- CI chụp ảnh + XCTest từ bản **Debug** (`Verify-on-Mac.command`); IPA là **Release** (`Build-Unsigned-IPA.command`).
- Đã bọc: mọi cờ đọc qua `QA.has / QA.anyQA / QA.anyFlag` (`AppFlow047.swift`, `#if DEBUG` → Release luôn "không có cờ"):
  luồng khởi động (`viewDidAppear`/`configureAppFlow`), `makeIntro`, `maybeStartTutorial`, `--tutorial-stroke-qa`,
  `afterLobbyClosed`, `--fresh-player-qa` (PlayerStore). Bản Release biên dịch được (đã build Release cho Simulator).
- Còn 35 chỗ đọc `ProcessInfo.processInfo.arguments` trực tiếp (chủ yếu `TrainingController.swift` 350–490, `L10n042.qa`,
  `AppDelegate` `--fresh-language`/`--old-intro-qa`, `TC+ShotLoop` dòng chẩn đoán QA, các file `*QA*.swift`) → 0.48: thay bằng `QA.*`
  từng khối, mỗi khối build Release + chạy lại ảnh CI.
