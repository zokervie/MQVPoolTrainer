# LỊCH SỬ PHÁT HÀNH VÀ NHỮNG GÌ KHÔNG ĐƯỢC LÀM MẤT

## 0.9 / 0.10: gốc native + nhánh nghiên cứu

- Native UIKit/SceneKit/Objective-C++/C++ physics độc lập.
- Video/bài tập tham khảo PoolShot, Dr. Dave; mô hình hiệu chuẩn chưa được đo trên bàn thật.
- 0.10 bổ sung Lab nghiên cứu ZUPE chạy offline qua WKWebView, không thay source solver native.

## 0.11 (21/10/2026): jump / massé experimental candidate

Hồ sơ `RELEASE-0.11.md`: solver 3D tùy chọn, chuyển động theo chiều cao, bóng tiếp xúc mặt bàn, thay đổi đồ họa jump/replay/quaternion, cue physics presets, input giữ B. Chưa nghiệm thu thực tế. File `VALIDATION-0.11.txt` ghi nhận các test đã qua nhưng **ở thời điểm tạo tài liệu đó chưa compile native Swift/Xcode**; không nhầm với kết quả build 22 sau này.

## 0.12 / build 20: bố trí luyện tập và nỉ/bàn

Hồ sơ `RELEASE-BUILD20.md`: Retry ngoại giao diện ở bên trái, giữ snapshot trước shot, quick rail phải, material/diamond/spot/shadow improvements; record Codemagic run được nêu là thành công. Phiên bản 0.12 build 20 unsigned IPA từng được ghi 55,744,849 bytes, không nên so trực tiếp với các bản mới mà chưa mở cấu trúc bên trong.

## 0.12 / build 21: giáo trình và audio synth

Hồ sơ `RELEASE-BUILD21.md`: mô tả 46 layout nhóm bài tập, màn giáo trình, sơ đồ, năm tint nỉ, camera orbit/zoom và synthesized native event audio. **Riêng hồ sơ này ghi Codemagic pending; không được suy nó đã chạy thành công chỉ nhờ tiêu đề 'release'.**

## 0.12 / build 22: baseline đã ghi nhận build thành công

Hồ sơ `RELEASE-BUILD22.md`: sửa cue pose theo effect + nâng cơ; âm synth preload; nỉ chi tiết hơn; pocket fall không thu nhỏ bi; camera quan sát; physics SpinTransfer regressions. Codemagic #24, nguồn build SHA `2dd1a55e51a55c4e2d0c5d697b79fcdd4df3f1bd`, ghi Simulator và unsigned iPhone Release compile pass, screenshot gates pass. Main HEAD ngày 24/10 `aba66d0f21e0816973ef0c13281fa98855ca3ff6` có thêm sửa/docs. Thiếu chứng cứ hiệu năng trên iPhone thật và đo bàn thật.

## Invariants bắt buộc

- Giữ app ID `com.maiquocviet.BankLabS` và version/build increments chính xác.
- SI m, s, rad trong solver; bi R=0.028575m, mặt chơi 1.27 × 2.54 m cho bàn 9ft chuẩn.
- Không sửa hệ số vật lý để bù lỗi hình/camera. Build 22 vẫn là mô hình giả định chưa được hiệu chuẩn bàn thật.
- Bảo toàn dữ liệu đã lưu (`layouts`, `practiceHistory`, cấu hình nỉ/cơ) khi nâng cấp schema; migration nếu đổi định dạng.
- Snapshot Undo/restoration gồm vị trí, xoay bi và trạng thái lượt; replay không mutate solver thật.
- `showCue`, `shotAngle`, `engine.strike` và prediction cùng coordinate basis; tests center/left/right/up/down/elevation.
- Phân biệt native physics vs Web Lab research và offline simulation vs online authoritative match.
