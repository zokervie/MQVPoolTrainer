# 0.14 ONLINE — KẾ HOẠCH KỸ THUẬT TÍCH HỢP

**Định hướng:** Cả hai máy mô phỏng local mượt, máy chủ authoritative về room, người chơi hiện tại, luật, thứ tự lệnh, điểm, thắng/thua và snapshot phiên bản. Không mặc định server đã có binary C++ để tự tính physics. Muốn chống gian lận cấp độ cao phải port/host solver xác thực trên server hoặc một mô hình kiểm tra độc lập.

## Protocol JSON version 1 (concept, chưa triển khai)

- `CREATE_ROOM` => `ROOM_CREATED {code, roomId, expiresAt, roomVersion}`; room code 6 chữ số duy nhất theo phiên, rate-limit/IP/device guard. Không coi code là authentication dài hạn.
- `JOIN_ROOM {code, clientNonce}` => `PLAYER_JOINED`; tối đa hai người chơi; token phiên ngắn hạn được lưu an toàn để reconnect.
- `PROPOSE_MATCH {game, ruleSetVersion, raceTo, breakPolicy, tableProfile, physicsVersion}` => `PROPOSAL_CHANGED` làm reset cả hai approvals.
- `ACCEPT_MATCH {proposalVersion}` từ hai bên => `START_MATCH` với break order, initial layout, authoritative game seed.
- `SHOT_REQUEST {roomVersion,turnId,shotIndex,angle,elevation,effectX,effectY,speed,cueType,preStateHash}` chỉ được máy có lượt gửi; server validate range/sequence.
- `SHOT_ACCEPTED {shotId,initialSnapshot,physicsVersion,seed}` rồi người chơi mô phỏng; server phát `SHOT_COMMITTED {finalSnapshot,events,score,turn,postStateHash}` theo chính sách nguồn sự thật đã quyết định, không cho cả hai đồng thời commit.
- `SCORE_UPDATED {rack,winsA,winsB,turnId,remainingBalls,foul,ballInHand}`; optional client HUD, server-owned.
- `RESYNC {lastAcknowledgedVersion}` => `ROOM_SNAPSHOT` đầy đủ cho reconnect. Socket retry/backoff, heartbeat hợp lý.

## Chính sách khi mạng yếu

- Người đang đánh thấy vật lý local ngay; đối phương spectate theo shot sync/timestamps, visual interpolation, có thể tự orbit camera nhưng không được thay thế shot parameters.
- Không đi trực tiếp vị trí từng bi liên tục 60fps qua Internet nếu source engine deterministic; ưu tiên input + authoritative snapshot ở các mốc, kèm checksum/drift detection.
- Nếu drift: máy khách chuyển state bằng authoritative snapshot tại safe boundary, hiện trạng thái đồng bộ, không giả tạo việc đối phương trượt cú.
- Nếu disconnect: pause match, giữ room trong TTL cấu hình, cho reconnect vào đúng vị trí và bảng điểm; tránh ván bị xử thua tự động trước khi có policy được hai bên biết.

## Test hợp đồng

1. 2 thiết bị khác mạng; lobby 6-digit code đúng/sai/hết hạn/nhập lại; phòng đầy.
2. Thương lượng rules: cả hai chấp nhận cùng version; thay đổi bất kỳ config nào => reset approvals.
3. 8-ball/9-ball racks, break, pocket, scratch, foul, ball-in-hand, winner, 3-/10-frame race và score.
4. Reconnect trước/sau shot; mất gói/duplicate/out-of-order events, resync snapshot.
5. 50 test shot sequences & physics version negotiation, incompatible clients reject session.
6. Rate limit / request input bounds / replay attempts / foreign room access / room expiry.

## Chi phí & quyền

Triển khai Cloudflare Durable Objects hoặc nền tảng realtime khác **sau khi xác minh pricing & token**. Ưu tiên free tier có giới hạn, quan sát số room/hours, không lưu video, không lưu voice của người chơi nếu không có yêu cầu. Không hardcode cloud secrets vào repo; sử dụng GitHub/Codemagic secured environment.
