# Máy chủ chơi online miễn phí (Cloudflare Workers)

Máy chủ này chỉ **ghép hai máy theo mã phòng và chuyển tiếp dữ liệu**. Không lưu tài khoản, không chạy vật lý:
máy tạo phòng tính vật lý và luật cho cả hai (giống chế độ Wi-Fi), nên hai máy không bao giờ lệch kết quả.

## Cài một lần (~5 phút, miễn phí)
1. Tạo tài khoản miễn phí tại https://dash.cloudflare.com (không cần thẻ).
2. Trên máy tính có Node.js 18+:
   ```sh
   cd native/ZokerPoolTrainer/Server/relay
   npx wrangler@4 login      # mở trình duyệt để cho phép
   npx wrangler@4 deploy     # in ra địa chỉ dạng https://zoker-relay.<tên>.workers.dev
   ```
3. Trong app: Menu → Chơi theo luật → **Máy chủ online…** → dán địa chỉ trên (cả hai máy cùng một địa chỉ).
   Hoặc điền sẵn vào `OnlineRelayConfig.defaultURL` trong `BankLab/Network/LocalMatchSession.swift` trước khi build IPA.

## Chơi
- Máy A: Chơi theo luật → “9 Ball · tạo phòng Online” → mã 8 ký tự được sao chép sẵn, gửi cho bạn qua Zalo/Messenger.
- Máy B: “Vào phòng Online bằng mã” → dán mã → Kết nối. Hai máy có thể ở mạng khác nhau (Wi-Fi, 4G).
- Mất mạng/thoát app: trận tạm dừng và tự nối lại khi có mạng; mã phòng giữ được 6 giờ khi không ai kết nối.

## Gói miễn phí đủ dùng không?
Gói Free (Workers + Durable Objects): 100.000 yêu cầu/ngày, WebSocket tính 20 tin nhắn = 1 yêu cầu;
13.000 GB-giây thời gian chạy/ngày (phòng đang có trận ≈ 0,125 GB-giây mỗi giây).
- Một cú (khoảng 20 giây ngắm + 5 giây bi lăn) ≈ 250–300 tin nhắn ≈ 15 yêu cầu → khoảng **6.000 cú/ngày**.
- Thời gian chạy đủ cho khoảng **25–29 giờ trận/ngày** cộng dồn mọi phòng. Phòng trống không tốn (Hibernation).
Vượt hạn mức thì máy chủ từ chối kết nối mới tới 0h UTC hôm sau; không phát sinh tiền ở gói Free.

## Kiểm tra
```sh
node --test test/core.test.js                       # luật ghép phòng (chạy trong Run-All-Checks)
npx wrangler@4 dev --local &  RELAY=ws://127.0.0.1:8787 node test/e2e.mjs   # hai máy giả lập
RELAY=wss://zoker-relay.<tên>.workers.dev node test/e2e.mjs                  # sau khi deploy
```
