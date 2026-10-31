// Pure relay rules: no Cloudflare APIs, so they run under `node --test`.
// The relay never reads game data. It only pairs one host and one guest per
// room code and forwards their bounded binary frames to each other.

export const PROTOCOL_VERSION = 1;
// Same bound as LANEnvelope.maximumBytes in the app.
export const MAX_FRAME_BYTES = 131072;
// 8 symbols, no 0/O/1/I: 32^8 ≈ 1.1e12 codes, read aloud without ambiguity.
export const CODE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
export const CODE_PATTERN = /^[2-9A-HJ-NP-Z]{8}$/;
export const TOKEN_PATTERN = /^[0-9a-f]{32}$/;
// A room with nobody connected is forgotten after this long.
export const IDLE_ROOM_MS = 6 * 60 * 60 * 1000;

export const Close = Object.freeze({
  badRequest: 4400,
  roomNotFound: 4404,
  seatTaken: 4409,
  replaced: 4410,
  versionMismatch: 4426,
  rateLimited: 4429,
  tooLarge: 4413,
});

export function parseRoomPath(pathname) {
  const match = /^\/v1\/rooms\/([^/]+)$/.exec(pathname);
  if (!match) return null;
  const code = match[1].toUpperCase();
  return CODE_PATTERN.test(code) ? code : null;
}

/**
 * Decide whether a socket may take a seat.
 * seats: { host: token|null, guest: token|null } as stored in the room.
 * Returns { ok, close?, reason?, claim? (role to store), replace? }.
 */
export function admit({ role, token, version }, seats) {
  if (role !== "host" && role !== "guest") return reject(Close.badRequest, "role");
  if (typeof token !== "string" || !TOKEN_PATTERN.test(token)) return reject(Close.badRequest, "token");
  if (String(version) !== String(PROTOCOL_VERSION)) return reject(Close.versionMismatch, "version");
  const current = seats?.[role] ?? null;
  if (role === "guest" && !seats?.host) return reject(Close.roomNotFound, "room");
  if (current === null) return { ok: true, claim: role, replace: false };
  if (current === token) return { ok: true, claim: null, replace: true };
  return reject(Close.seatTaken, role === "guest" ? "full" : "host");
}

function reject(close, reason) {
  return { ok: false, close, reason };
}

export function otherRole(role) {
  return role === "host" ? "guest" : "host";
}

/** Token bucket: sustained `rate` frames/s, bursts up to `burst`. */
export class RateLimiter {
  constructor(rate = 60, burst = 120, now = Date.now()) {
    this.rate = rate;
    this.burst = burst;
    this.tokens = burst;
    this.last = now;
  }
  allow(now = Date.now()) {
    this.tokens = Math.min(this.burst, this.tokens + ((now - this.last) / 1000) * this.rate);
    this.last = now;
    if (this.tokens < 1) return false;
    this.tokens -= 1;
    return true;
  }
}

export function frameSize(message) {
  if (typeof message === "string") return new TextEncoder().encode(message).length;
  return message?.byteLength ?? 0;
}

/** Control frames the relay itself sends (text). App data is always binary. */
export function peerNotice(present) {
  return JSON.stringify({ relay: "peer", present: Boolean(present) });
}
