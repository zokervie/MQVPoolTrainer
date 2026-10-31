// End-to-end check against a running relay (`npx wrangler@4 dev` or a deployed
// URL): RELAY=ws://127.0.0.1:8787 node test/e2e.mjs
// Needs the `ws` package only for Node versions without a global WebSocket.
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";

const base = process.env.RELAY ?? "ws://127.0.0.1:8787";
const WS = globalThis.WebSocket ?? (await import("ws")).default;
const token = () => randomBytes(16).toString("hex");
const code = Array.from(randomBytes(8), (b) => "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"[b % 32]).join("");

function open(role, tok, roomCode = code) {
  const ws = new WS(`${base}/v1/rooms/${roomCode}?role=${role}&token=${tok}&v=1`);
  ws.binaryType = "arraybuffer";
  const inbox = [];
  const waiters = [];
  let closed = null;
  ws.addEventListener("message", (e) => { inbox.push(e.data); waiters.splice(0).forEach((w) => w()); });
  ws.addEventListener("close", (e) => { closed = { code: e.code, reason: e.reason }; waiters.splice(0).forEach((w) => w()); });
  const next = async (pred = () => true, ms = 4000) => {
    const deadline = Date.now() + ms;
    for (;;) {
      const i = inbox.findIndex(pred);
      if (i >= 0) return inbox.splice(i, 1)[0];
      if (closed) throw Object.assign(new Error("closed"), closed);
      if (Date.now() > deadline) throw new Error("timeout");
      await new Promise((r) => { waiters.push(r); setTimeout(r, 100); });
    }
  };
  const ready = new Promise((r, j) => { ws.addEventListener("open", r); ws.addEventListener("error", j); });
  return { ws, next, ready, get closed() { return closed; } };
}
const notice = (present) => (d) => typeof d === "string" && JSON.parse(d).present === present;
const until = async (cond, ms = 4000) => { const t = Date.now(); while (!cond()) { if (Date.now() - t > ms) throw new Error("timeout"); await new Promise((r) => setTimeout(r, 50)); } };

const hostToken = token(), guestToken = token();

// Guest before host: room does not exist.
const early = open("guest", guestToken);
assert.equal(JSON.parse(await early.next((d) => typeof d === "string").catch(() => "{}")).code, 4404);
await until(() => early.closed);
assert.equal(early.closed.code, 4404);

const host = open("host", hostToken); await host.ready;
await host.next(notice(false));
const guest = open("guest", guestToken); await guest.ready;
await guest.next(notice(true));
await host.next(notice(true));

// Binary frames are forwarded unchanged, both directions; latency measured.
const t0 = performance.now();
host.ws.send(new Uint8Array([1, 2, 3]));
const got = new Uint8Array(await guest.next((d) => typeof d !== "string"));
const oneWay = performance.now() - t0;
assert.deepEqual([...got], [1, 2, 3]);
guest.ws.send(new Uint8Array([9]));
assert.deepEqual([...new Uint8Array(await host.next((d) => typeof d !== "string"))], [9]);

// A third device cannot take the guest seat.
const intruder = open("guest", token());
await until(() => intruder.closed);
assert.equal(intruder.closed.code, 4409);

// Guest reconnects with its token: old socket replaced, host told peer present.
const guest2 = open("guest", guestToken); await guest2.ready;
await guest2.next(notice(true));
await until(() => guest.closed);
assert.equal(guest.closed.code, 4410);
host.ws.send(new Uint8Array([7]));
assert.deepEqual([...new Uint8Array(await guest2.next((d) => typeof d !== "string"))], [7]);

// Guest leaves: host is told the peer is gone.
guest2.ws.close(1000, "bye");
await host.next(notice(false));
host.ws.close(1000, "bye");
console.log(`PASS relay e2e (${base}) room ${code}; forward ${oneWay.toFixed(1)} ms`);
process.exit(0);
