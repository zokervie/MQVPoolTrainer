import test from "node:test";
import assert from "node:assert/strict";
import { PROTOCOL_VERSION,
  admit, Close, CODE_ALPHABET, CODE_PATTERN, MAX_FRAME_BYTES, parseRoomPath,
  peerNotice, RateLimiter, frameSize,
} from "../src/core.js";

const A = "0123456789abcdef0123456789abcdef";
const B = "fedcba9876543210fedcba9876543210";

test("room codes: 8 symbols, no ambiguous characters, case-insensitive path", () => {
  assert.equal(CODE_ALPHABET.length, 32);
  for (const bad of "01IO") assert.ok(!CODE_ALPHABET.includes(bad));
  assert.equal(parseRoomPath("/v1/rooms/ab23cd45"), "AB23CD45");
  assert.equal(parseRoomPath("/v1/rooms/AB23CD4O"), null);
  assert.equal(parseRoomPath("/v1/rooms/AB23CD4"), null);
  assert.equal(parseRoomPath("/v1/rooms/AB23CD45/x"), null);
  assert.ok(CODE_PATTERN.test("Z9Z9Z9Z9"));
});

test("host creates the room; guest cannot join a room that was never created", () => {
  const empty = { host: null, guest: null };
  assert.deepEqual(admit({ role: "guest", token: A, version: String(PROTOCOL_VERSION) }, empty).close, Close.roomNotFound);
  const host = admit({ role: "host", token: A, version: String(PROTOCOL_VERSION) }, empty);
  assert.equal(host.ok, true);
  assert.equal(host.claim, "host");
});

test("one guest seat; the same token reconnects, another token is rejected", () => {
  const seats = { host: A, guest: null };
  assert.equal(admit({ role: "guest", token: B, version: PROTOCOL_VERSION }, seats).claim, "guest");
  seats.guest = B;
  const again = admit({ role: "guest", token: B, version: PROTOCOL_VERSION }, seats);
  assert.equal(again.ok, true);
  assert.equal(again.replace, true);
  const third = admit({ role: "guest", token: A, version: PROTOCOL_VERSION }, seats);
  assert.equal(third.ok, false);
  assert.equal(third.close, Close.seatTaken);
  assert.equal(admit({ role: "host", token: B, version: PROTOCOL_VERSION }, seats).close, Close.seatTaken);
  assert.equal(admit({ role: "host", token: A, version: PROTOCOL_VERSION }, seats).replace, true);
});

test("bad role, token or version are refused", () => {
  const seats = { host: A, guest: null };
  assert.equal(admit({ role: "spectator", token: B, version: PROTOCOL_VERSION }, seats).close, Close.badRequest);
  assert.equal(admit({ role: "guest", token: "short", version: PROTOCOL_VERSION }, seats).close, Close.badRequest);
  assert.equal(admit({ role: "guest", token: B, version: PROTOCOL_VERSION + 1 }, seats).close, Close.versionMismatch);
});

test("rate limiter allows a burst, then the sustained rate", () => {
  const limiter = new RateLimiter(60, 120, 0);
  let allowed = 0;
  for (let i = 0; i < 200; i++) if (limiter.allow(0)) allowed++;
  assert.equal(allowed, 120);
  assert.equal(limiter.allow(1000 / 60), true);
  assert.equal(limiter.allow(1000 / 60), false);
});

test("frame size and notices", () => {
  assert.equal(frameSize(new Uint8Array(MAX_FRAME_BYTES)), MAX_FRAME_BYTES);
  assert.equal(frameSize("ab"), 2);
  assert.deepEqual(JSON.parse(peerNotice(true)), { relay: "peer", present: true });
});

test("relay protocol = the app's LANEnvelope.protocolVersion (ZB-036)", async () => {
  const { readFileSync } = await import("node:fs");
  const swift = readFileSync(new URL("../../../BankLab/Network/MatchWire.swift", import.meta.url), "utf8");
  const m = swift.match(/static let protocolVersion = (\d+)/);
  assert.ok(m, "protocolVersion not found in MatchWire.swift");
  assert.equal(Number(m[1]), PROTOCOL_VERSION);
});
