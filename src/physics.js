// Engine vật lý bi-a: mô hình trượt/lăn trên vải, xoáy 3 trục, va chạm bi-bi có ma sát (throw, truyền xoáy),
// va chạm băng có điểm tiếp xúc cao hơn tâm bi (english đổi góc nảy), lỗ bắt bi.
// Tham số tham khảo: Dr. Dave Alciatore – "approximate values for pool equipment physical properties".

import { R, CUSHIONS, POCKETS, CUSHION_H, L, W } from './table.js';

export const G = 9.81;
export const PHYS = {
  muSlide: 0.2,        // ma sát trượt bi-vải (0.15–0.4)
  muRoll: 0.011,       // cản lăn (0.005–0.015)
  spinDecel: 10,       // giảm tốc xoáy ngang quanh trục đứng (rad/s²)
  eBall: 0.95,         // hệ số hồi phục bi-bi (0.92–0.98)
  muBall: 0.06,        // ma sát bi-bi (0.03–0.08) → hiện tượng "throw"
  eCushion: 0.86,      // hồi phục băng ở tốc độ thấp (0.6–0.9)
  muCushion: 0.2,      // ma sát bi-băng
  dt: 1 / 2000,
};

const I = 0.4 * R * R; // mômen quán tính / khối lượng (m = 1)
const SIN_T = (CUSHION_H - R) / R;
const COS_T = Math.sqrt(1 - SIN_T * SIN_T);

// ---- vector 3D tối giản ----
const cross = (a, b) => ({ x: a.y * b.z - a.z * b.y, y: a.z * b.x - a.x * b.z, z: a.x * b.y - a.y * b.x });
const dot = (a, b) => a.x * b.x + a.y * b.y + a.z * b.z;

export class Ball {
  constructor(id, x, z) {
    this.id = id;            // 0 = bi cái, 1..15
    this.x = x; this.z = z;
    this.vx = 0; this.vz = 0;
    this.w = { x: 0, y: 0, z: 0 };
    this.pocketed = false;
    this.pocket = null;
    // quaternion hiển thị (x,y,z,w)
    this.q = [0, 0, 0, 1];
  }
  get moving() {
    return !this.pocketed && (this.vx * this.vx + this.vz * this.vz > 1e-8 || Math.abs(this.w.x) + Math.abs(this.w.y) + Math.abs(this.w.z) > 1e-3);
  }
  clone() {
    const b = new Ball(this.id, this.x, this.z);
    b.vx = this.vx; b.vz = this.vz; b.w = { ...this.w }; b.pocketed = this.pocketed; b.pocket = this.pocket;
    b.q = [...this.q];
    return b;
  }
}

export class Simulation {
  constructor(balls = []) {
    this.balls = balls;
    this.time = 0;
    this.events = [];
    this.trace = null; // {ids:Set, pts:Map<id, [x,z][]>} – dùng cho dự đoán đường đi
    this.trackRotation = true;
  }

  clone() {
    const s = new Simulation(this.balls.map((b) => b.clone()));
    s.trackRotation = false;
    return s;
  }

  get moving() { return this.balls.some((b) => b.moving); }

  ball(id) { return this.balls.find((b) => b.id === id); }

  /**
   * Cú đánh. dir: góc (rad) hướng cơ trên mặt bàn; speed: tốc độ bi cái (m/s);
   * a: điểm đánh ngang (-1..1 theo R, + = phải), b: điểm đánh dọc (+ = trên/theo, − = dưới/kéo);
   * elev: góc nâng cơ (rad); squirt: hệ số lệch hướng do english.
   */
  strike(ballId, dir, speed, a = 0, b = 0, elev = 0, squirt = 0.02) {
    const cb = this.ball(ballId);
    const off = Math.hypot(a, b);
    if (off > 0.6) { a *= 0.6 / off; b *= 0.6 / off; }
    // hướng cơ 3D (chúc xuống theo elev)
    const ce = Math.cos(elev), se = Math.sin(elev);
    const d = { x: Math.cos(dir) * ce, y: -se, z: Math.sin(dir) * ce };
    // trục phụ: ngang (bên phải người đánh) và "lên" vuông góc với hướng cơ
    const side = { x: -Math.sin(dir), y: 0, z: Math.cos(dir) };
    const up = cross(side, d); // vuông góc d, hướng lên
    const k = Math.sqrt(Math.max(0, 1 - a * a - b * b));
    const r = {
      x: R * (-d.x * k + side.x * a + up.x * b),
      y: R * (-d.y * k + side.y * a + up.y * b),
      z: R * (-d.z * k + side.z * a + up.z * b),
    };
    const J = { x: d.x * speed, y: d.y * speed, z: d.z * speed };
    const tq = cross(r, J);
    // lệch hướng (squirt): bi cái đi lệch ngược phía english
    const sq = -squirt * a;
    const vx = J.x, vz = J.z;
    cb.vx = vx * Math.cos(sq) - vz * Math.sin(sq);
    cb.vz = vx * Math.sin(sq) + vz * Math.cos(sq);
    cb.w = { x: tq.x / I, y: tq.y / I, z: tq.z / I };
    this.events.push({ type: 'strike', t: this.time, ball: ballId });
  }

  step(dt = PHYS.dt) {
    const { muSlide, muRoll, spinDecel } = PHYS;
    for (const bl of this.balls) {
      if (bl.pocketed) continue;
      const w = bl.w;
      // vận tốc điểm tiếp xúc với vải
      const ux = bl.vx + R * w.z, uz = bl.vz - R * w.x;
      const um = Math.hypot(ux, uz);
      if (um > 1e-4) {
        const lim = 3.5 * muSlide * G * dt;
        if (um <= lim) {
          bl.vx -= (2 / 7) * ux; bl.vz -= (2 / 7) * uz;
          w.x = bl.vz / R; w.z = -bl.vx / R;
        } else {
          const fx = (-muSlide * G * ux) / um, fz = (-muSlide * G * uz) / um;
          bl.vx += fx * dt; bl.vz += fz * dt;
          w.x += (-fz * 2.5 / R) * dt; w.z += (fx * 2.5 / R) * dt;
        }
      } else {
        const s = Math.hypot(bl.vx, bl.vz);
        if (s > 0) {
          const ns = s - muRoll * G * dt;
          if (ns <= 0) { bl.vx = 0; bl.vz = 0; } else { bl.vx *= ns / s; bl.vz *= ns / s; }
        }
        w.x = bl.vz / R; w.z = -bl.vx / R;
      }
      // xoáy quanh trục đứng
      if (w.y !== 0) {
        const dw = spinDecel * dt;
        w.y = Math.abs(w.y) <= dw ? 0 : w.y - Math.sign(w.y) * dw;
      }
      bl.x += bl.vx * dt; bl.z += bl.vz * dt;
      if (this.trackRotation) integrateQuat(bl.q, w, dt);
    }
    this.collideBalls();
    this.collideCushions();
    this.checkPockets();
    this.time += dt;
    if (this.trace) {
      this.traceCounter = (this.traceCounter || 0) + 1;
      if (this.traceCounter % 10 === 0) for (const id of this.trace.ids) {
        const b = this.ball(id);
        if (b && !b.pocketed) this.trace.pts.get(id).push([b.x, b.z]);
      }
    }
  }

  collideBalls() {
    const bs = this.balls, n = bs.length, D = 2 * R, D2 = D * D;
    for (let i = 0; i < n; i++) {
      const A = bs[i];
      if (A.pocketed) continue;
      for (let j = i + 1; j < n; j++) {
        const B = bs[j];
        if (B.pocketed) continue;
        const dx = B.x - A.x, dz = B.z - A.z;
        const d2 = dx * dx + dz * dz;
        if (d2 >= D2 || d2 === 0) continue;
        const d = Math.sqrt(d2);
        const nx = dx / d, nz = dz / d;
        // tách chồng lấn
        const pen = (D - d) / 2;
        A.x -= nx * pen; A.z -= nz * pen; B.x += nx * pen; B.z += nz * pen;
        const approach = (A.vx - B.vx) * nx + (A.vz - B.vz) * nz;
        if (approach <= 0) continue;
        this.resolveBallBall(A, B, nx, nz);
      }
    }
  }

  resolveBallBall(A, B, nx, nz) {
    const n = { x: nx, y: 0, z: nz };
    const rA = { x: R * nx, y: 0, z: R * nz };
    const rB = { x: -R * nx, y: 0, z: -R * nz };
    const cA = cross(A.w, rA), cB = cross(B.w, rB);
    const vrel = { x: A.vx + cA.x - B.vx - cB.x, y: cA.y - cB.y, z: A.vz + cA.z - B.vz - cB.z };
    const vn = (A.vx - B.vx) * nx + (A.vz - B.vz) * nz;
    const Jn = ((1 + PHYS.eBall) * vn) / 2;
    A.vx -= Jn * nx; A.vz -= Jn * nz; B.vx += Jn * nx; B.vz += Jn * nz;
    // ma sát tiếp tuyến (throw + truyền xoáy)
    const vrn = dot(vrel, n);
    const vt = { x: vrel.x - vrn * nx, y: vrel.y, z: vrel.z - vrn * nz };
    const vtm = Math.hypot(vt.x, vt.y, vt.z);
    if (vtm > 1e-6) {
      // khối lượng hiệu dụng tiếp tuyến của 2 quả cầu đặc = m/7
      const Jt = Math.min(PHYS.muBall * Jn, vtm / 7);
      const t = { x: (-vt.x / vtm) * Jt, y: (-vt.y / vtm) * Jt, z: (-vt.z / vtm) * Jt }; // xung lực lên A
      A.vx += t.x; A.vz += t.z; B.vx -= t.x; B.vz -= t.z;
      const tA = cross(rA, t);
      const tB = cross(rB, { x: -t.x, y: -t.y, z: -t.z });
      A.w.x += tA.x / I; A.w.y += tA.y / I; A.w.z += tA.z / I;
      B.w.x += tB.x / I; B.w.y += tB.y / I; B.w.z += tB.z / I;
    }
    this.events.push({ type: 'hit', t: this.time, a: A.id, b: B.id, speed: vn });
  }

  collideCushions() {
    for (const bl of this.balls) {
      if (bl.pocketed) continue;
      // nhanh: bỏ qua bi nằm xa thành bàn
      if (Math.abs(bl.x) < L / 2 - R * 1.5 && Math.abs(bl.z) < W / 2 - R * 1.5) continue;
      for (const s of CUSHIONS) {
        const ax = s.a[0], az = s.a[1], bx = s.b[0], bz = s.b[1];
        const ex = bx - ax, ez = bz - az;
        let t = ((bl.x - ax) * ex + (bl.z - az) * ez) / (ex * ex + ez * ez);
        t = t < 0 ? 0 : t > 1 ? 1 : t;
        const qx = ax + ex * t, qz = az + ez * t;
        const dx = bl.x - qx, dz = bl.z - qz;
        const d2 = dx * dx + dz * dz;
        if (d2 >= R * R || d2 === 0) continue;
        const d = Math.sqrt(d2);
        const nx = dx / d, nz = dz / d;
        bl.x = qx + nx * R; bl.z = qz + nz * R;
        const vn = bl.vx * nx + bl.vz * nz;
        if (vn >= 0) continue;
        this.resolveCushion(bl, nx, nz, s);
      }
    }
  }

  resolveCushion(bl, nx, nz, seg) {
    const vn = bl.vx * nx + bl.vz * nz;
    const e = Math.max(0.55, Math.min(PHYS.eCushion, PHYS.eCushion - 0.035 * (-vn - 1)));
    const Jn = -(1 + e) * vn;
    // điểm tiếp xúc: phía thành, cao hơn tâm bi
    const r = { x: -R * COS_T * nx, y: R * SIN_T, z: -R * COS_T * nz };
    const N = { x: nx, y: 0, z: nz };
    bl.vx += Jn * nx; bl.vz += Jn * nz;
    const tn = cross(r, { x: Jn * nx, y: 0, z: Jn * nz });
    bl.w.x += tn.x / I; bl.w.y += tn.y / I; bl.w.z += tn.z / I;
    // ma sát tại điểm tiếp xúc
    const c = cross(bl.w, r);
    const vc = { x: bl.vx + c.x, y: c.y, z: bl.vz + c.z };
    const vcn = dot(vc, N);
    const vt = { x: vc.x - vcn * nx, y: vc.y, z: vc.z - vcn * nz };
    const vtm = Math.hypot(vt.x, vt.y, vt.z);
    if (vtm > 1e-6) {
      const tdir = { x: vt.x / vtm, y: vt.y / vtm, z: vt.z / vtm };
      const rt = cross(r, tdir);
      const K = 1 + dot(rt, rt) / I;
      const Jt = Math.min(PHYS.muCushion * Jn, vtm / K);
      const imp = { x: -tdir.x * Jt, y: -tdir.y * Jt, z: -tdir.z * Jt };
      bl.vx += imp.x; bl.vz += imp.z;
      const tt = cross(r, imp);
      bl.w.x += tt.x / I; bl.w.y += tt.y / I; bl.w.z += tt.z / I;
    }
    this.events.push({ type: 'cushion', t: this.time, ball: bl.id, rail: seg.rail || 'jaw', speed: -vn });
  }

  checkPockets() {
    for (const bl of this.balls) {
      if (bl.pocketed) continue;
      if (Math.abs(bl.x) < L / 2 - 0.09 && Math.abs(bl.z) < W / 2 - 0.09) continue;
      for (const p of POCKETS) {
        const dx = bl.x - p.x, dz = bl.z - p.z;
        if (dx * dx + dz * dz < p.capture * p.capture) { this.pocketBall(bl, p); break; }
      }
      // an toàn: bi lọt khỏi bàn
      if (!bl.pocketed && (Math.abs(bl.x) > L / 2 + 0.06 || Math.abs(bl.z) > W / 2 + 0.06)) {
        let best = POCKETS[0], bd = Infinity;
        for (const p of POCKETS) { const dd = (bl.x - p.x) ** 2 + (bl.z - p.z) ** 2; if (dd < bd) { bd = dd; best = p; } }
        this.pocketBall(bl, best);
      }
    }
  }

  pocketBall(bl, p) {
    bl.pocketed = true; bl.pocket = p.id;
    bl.dropFrom = { x: bl.x, z: bl.z, vx: bl.vx, vz: bl.vz };
    bl.vx = bl.vz = 0; bl.w = { x: 0, y: 0, z: 0 };
    this.events.push({ type: 'pocket', t: this.time, ball: bl.id, pocket: p.id });
  }

  /** Chạy cho tới khi dừng (dùng cho kiểm thử / dự đoán). */
  runUntilRest(maxTime = 20, dt = PHYS.dt) {
    const steps = Math.ceil(maxTime / dt);
    for (let i = 0; i < steps; i++) {
      this.step(dt);
      if (i % 20 === 0 && !this.moving) break;
    }
    return this;
  }
}

function integrateQuat(q, w, dt) {
  const wm = Math.hypot(w.x, w.y, w.z);
  if (wm < 1e-9) return;
  const ang = wm * dt, s = Math.sin(ang / 2) / wm;
  const dx = w.x * s, dy = w.y * s, dz = w.z * s, dw = Math.cos(ang / 2);
  const [x, y, z, ww] = q;
  // q = dq * q (xoay theo trục thế giới)
  q[0] = dw * x + dx * ww + dy * z - dz * y;
  q[1] = dw * y - dx * z + dy * ww + dz * x;
  q[2] = dw * z + dx * y - dy * x + dz * ww;
  q[3] = dw * ww - dx * x - dy * y - dz * z;
  const m = Math.hypot(q[0], q[1], q[2], q[3]);
  q[0] /= m; q[1] /= m; q[2] /= m; q[3] /= m;
}

/** Tốc độ bi cái cần để lăn được quãng đường d (bỏ qua giai đoạn trượt): v = √(2·μr·g·d). */
export function speedForDistance(d) {
  return Math.sqrt(2 * PHYS.muRoll * G * d);
}
