// Zoker online relay: Cloudflare Worker + one Durable Object per room code.
// Uses the WebSocket Hibernation API, so an idle room costs no duration time.
import { DurableObject } from "cloudflare:workers";
import {
  admit, Close, frameSize, IDLE_ROOM_MS, MAX_FRAME_BYTES, otherRole,
  parseRoomPath, peerNotice, RateLimiter,
} from "./core.js";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response("zoker-relay ok\n", { headers: { "content-type": "text/plain" } });
    }
    const code = parseRoomPath(url.pathname);
    if (!code) return new Response("not found\n", { status: 404 });
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("websocket required\n", { status: 426 });
    }
    return env.ROOMS.get(env.ROOMS.idFromName(code)).fetch(request);
  },
};

export class Room extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.limits = new Map();
  }

  async fetch(request) {
    const url = new URL(request.url);
    const role = url.searchParams.get("role");
    const token = url.searchParams.get("token");
    const version = url.searchParams.get("v");
    const seats = (await this.ctx.storage.get("seats")) ?? { host: null, guest: null };
    const decision = admit({ role, token, version }, seats);

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    if (!decision.ok) {
      // Accept, then close with a reason code the app can show to the player.
      // iOS URLSession does not expose custom close codes, so say it first.
      server.accept();
      server.send(JSON.stringify({ relay: "error", code: decision.close, reason: decision.reason }));
      server.close(decision.close, decision.reason);
      return new Response(null, { status: 101, webSocket: client });
    }
    if (decision.claim) {
      seats[decision.claim] = token;
      await this.ctx.storage.put("seats", seats);
    }
    for (const old of this.ctx.getWebSockets(role)) {
      try { old.close(Close.replaced, "replaced"); } catch {}
    }
    this.ctx.acceptWebSocket(server, [role]);
    server.serializeAttachment({ role });
    await this.ctx.storage.setAlarm(Date.now() + IDLE_ROOM_MS);

    const peerPresent = this.ctx.getWebSockets(otherRole(role)).length > 0;
    server.send(peerNotice(peerPresent));
    if (peerPresent) this.broadcast(otherRole(role), peerNotice(true));
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    const role = ws.deserializeAttachment()?.role;
    if (!role) return;
    if (frameSize(message) > MAX_FRAME_BYTES) { ws.close(Close.tooLarge, "frame"); return; }
    let limiter = this.limits.get(ws);
    if (!limiter) { limiter = new RateLimiter(); this.limits.set(ws, limiter); }
    if (!limiter.allow()) { ws.close(Close.rateLimited, "rate"); return; }
    // Only binary app frames are relayed; text is reserved for relay notices.
    if (typeof message === "string") return;
    this.broadcast(otherRole(role), message);
  }

  async webSocketClose(ws, code, reason) {
    this.limits.delete(ws);
    const role = ws.deserializeAttachment()?.role;
    try { ws.close(code === 1005 ? 1000 : code, reason); } catch {}
    if (role && this.ctx.getWebSockets(role).every((s) => s === ws)) {
      this.broadcast(otherRole(role), peerNotice(false));
    }
    await this.ctx.storage.setAlarm(Date.now() + IDLE_ROOM_MS);
  }

  async webSocketError(ws) {
    await this.webSocketClose(ws, 1011, "error");
  }

  async alarm() {
    if (this.ctx.getWebSockets().length > 0) {
      await this.ctx.storage.setAlarm(Date.now() + IDLE_ROOM_MS);
      return;
    }
    await this.ctx.storage.deleteAll();
  }

  broadcast(role, message) {
    for (const socket of this.ctx.getWebSockets(role)) {
      try { socket.send(message); } catch {}
    }
  }
}
