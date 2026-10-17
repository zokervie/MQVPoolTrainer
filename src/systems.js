// Hình học các hệ thống nút số (diamond systems) và công cụ ngắm.
// "Khung nút": dx 0..8 (trái → phải), dz 0..4 (băng dưới → băng trên) đo trên ĐƯỜNG NÚT (mặt gỗ, lùi sau mũi băng).

import { R, L, W, POCKETS } from './table.js';

export const DIAMOND_OFF = 0.094; // nút cách mũi băng ~3,7 in
const DX = (L + 2 * DIAMOND_OFF) / 8;
const DZ = (W + 2 * DIAMOND_OFF) / 4;

/** Điểm trên đường nút (mét). */
export function railPoint(dx, dz) {
  return { x: -L / 2 - DIAMOND_OFF + dx * DX, z: W / 2 + DIAMOND_OFF - dz * DZ };
}
export function toRailFrame(x, z) {
  return { dx: (x + L / 2 + DIAMOND_OFF) / DX, dz: (W / 2 + DIAMOND_OFF - z) / DZ };
}

// ---------- Ngắm bi ma (ghost ball) ----------
export function pocketById(id) { return POCKETS.find((p) => p.id === id); }

/** Điểm nhắm cho bi mục tiêu vào lỗ: hơi lùi vào trong miệng lỗ. */
export function pocketAimPoint(p) {
  const k = p.kind === 'corner' ? 0.012 : 0.004;
  const dx = p.x - p.mouth.x, dz = p.z - p.mouth.z, m = Math.hypot(dx, dz) || 1;
  return { x: p.mouth.x + (dx / m) * k, z: p.mouth.z + (dz / m) * k };
}

/** Vị trí bi ma: G = O − 2R·û, û là hướng từ bi mục tiêu tới điểm nhắm. */
export function ghostBall(ob, target) {
  const dx = target.x - ob.x, dz = target.z - ob.z, m = Math.hypot(dx, dz);
  return { x: ob.x - (dx / m) * 2 * R, z: ob.z - (dz / m) * 2 * R };
}

/** Góc cắt (độ) giữa đường bi cái→bi ma và đường bi mục tiêu→lỗ. */
export function cutAngle(cb, ob, target) {
  const g = ghostBall(ob, target);
  const a1 = Math.atan2(g.z - cb.z, g.x - cb.x);
  const a2 = Math.atan2(target.z - ob.z, target.x - ob.x);
  let d = Math.abs(a1 - a2) * 180 / Math.PI;
  if (d > 180) d = 360 - d;
  return d;
}

/** Độ chồng bi f (0..1) ứng với góc cắt θ: sinθ = 1 − f. */
export const overlapFromCut = (deg) => 1 - Math.sin((deg * Math.PI) / 180);
export const cutFromOverlap = (f) => (Math.asin(1 - f) * 180) / Math.PI;

/** Đặt bi cái để tạo góc cắt cho trước. side = ±1 chọn phía; dist = khoảng cách bi cái→bi ma (m). */
export function placeForCut(ob, target, deg, dist, side = 1) {
  const g = ghostBall(ob, target);
  const base = Math.atan2(target.z - ob.z, target.x - ob.x);
  const a = base + side * (deg * Math.PI) / 180;
  return { x: g.x - Math.cos(a) * dist, z: g.z - Math.sin(a) * dist };
}

// ---------- Hệ thống gương (1 băng) ----------
// Đường "tâm bi chạm băng" nằm cách mũi băng R.
const CL = { top: -W / 2 + R, bottom: W / 2 - R, left: -L / 2 + R, right: L / 2 - R };

/** Ảnh gương của điểm qua băng (theo đường tâm bi). */
export function mirrorPoint(p, rail) {
  if (rail === 'top' || rail === 'bottom') return { x: p.x, z: 2 * CL[rail] - p.z };
  return { x: 2 * CL[rail] - p.x, z: p.z };
}

/** Điểm chạm băng của đường gương: x_c = (x₁·d₂ + x₂·d₁)/(d₁+d₂). */
export function mirrorContact(a, b, rail) {
  const horiz = rail === 'top' || rail === 'bottom';
  const c = CL[rail];
  const d1 = horiz ? Math.abs(a.z - c) : Math.abs(a.x - c);
  const d2 = horiz ? Math.abs(b.z - c) : Math.abs(b.x - c);
  if (horiz) return { x: (a.x * d2 + b.x * d1) / (d1 + d2), z: c };
  return { x: c, z: (a.z * d2 + b.z * d1) / (d1 + d2) };
}

// ---------- Phản chiếu qua góc (2 băng kề nhau) ----------
/** Góc C của hình chữ nhật tâm bi; ảnh T' = 2C − T. Đường ra song song đường vào. */
export function cornerReflect(p, corner /* 'tr' | 'tl' | 'br' | 'bl' */) {
  const cx = corner.includes('r') ? CL.right : CL.left;
  const cz = corner.includes('t') ? CL.top : CL.bottom;
  return { x: 2 * cx - p.x, z: 2 * cz - p.z, cx, cz };
}

// ---------- Corner-5 (3 băng: băng dài trên → băng ngắn phải → băng dài dưới) ----------
// Số xuất phát D: góc dưới-trái = 5; +1 mỗi nút đi lên băng ngắn trái; −½ mỗi nút đi sang phải trên băng dài dưới.
// Số băng 1 (F) trên băng trên và số băng 3 (T) trên băng dưới: 1 tại nút đầu tiên tính từ băng ngắn phải.
// Công thức: T = D − F  ⇔  F = D − T.

export function corner5OriginNumber(cb, F) {
  // kéo dài đường từ điểm F (băng trên) qua bi cái về phía băng trái / băng dưới
  const pf = railPoint(8 - F, 4);
  const dir = { x: cb.x - pf.x, z: cb.z - pf.z };
  const left = railPoint(0, 0).x, bottom = railPoint(0, 0).z;
  // giao với băng trái
  if (dir.x < 0) {
    const t = (left - pf.x) / dir.x;
    const z = pf.z + dir.z * t;
    const fr = toRailFrame(left, z);
    if (fr.dz >= 0) return { D: 5 + fr.dz, at: { x: left, z } };
  }
  if (dir.z > 0) {
    const t = (bottom - pf.z) / dir.z;
    const x = pf.x + dir.x * t;
    const fr = toRailFrame(x, bottom);
    return { D: 5 - fr.dx / 2, at: { x, z: bottom } };
  }
  return null;
}

/** Tìm số nhắm F trên băng 1 sao cho D − F = T với vị trí bi cái hiện tại. */
export function corner5Solve(cb, T) {
  let lo = 0.3, hi = 7.7;
  const f = (F) => { const o = corner5OriginNumber(cb, F); return o ? o.D - F - T : NaN; };
  let flo = f(lo), fhi = f(hi);
  if (!(flo * fhi < 0)) {
    // quét thô
    let best = null, bv = Infinity;
    for (let F = 0.3; F <= 7.7; F += 0.05) { const v = Math.abs(f(F)); if (v < bv) { bv = v; best = F; } }
    return best == null ? null : finish(best);
  }
  for (let i = 0; i < 50; i++) {
    const mid = (lo + hi) / 2, fm = f(mid);
    if (fm * flo <= 0) { hi = mid; fhi = fm; } else { lo = mid; flo = fm; }
  }
  return finish((lo + hi) / 2);
  function finish(F) {
    const o = corner5OriginNumber(cb, F);
    return { F, D: o.D, T, aim: railPoint(8 - F, 4), origin: o.at, arrival: railPoint(8 - T, 0) };
  }
}

/** Nhãn số trên các băng cho từng hệ thống (để vẽ lên bàn & sơ đồ). */
export function systemLabels(kind) {
  const out = [];
  const fmt = (n) => (Math.abs(n - Math.round(n)) < 1e-6 ? String(Math.round(n)) : n.toFixed(1).replace('.', ','));
  if (kind === 'corner5') {
    for (let i = 0; i <= 4; i++) out.push({ p: railPoint(0, i), text: fmt(5 + i), color: '#ffd166', side: 'left' });
    for (let i = 1; i <= 7; i++) out.push({ p: railPoint(i, 0), text: fmt(5 - i / 2), color: '#ffd166', side: 'bottom' });
    for (let i = 1; i <= 7; i++) out.push({ p: railPoint(8 - i, 4), text: fmt(i), color: '#7bdff2', side: 'top' });
    for (let i = 1; i <= 7; i++) out.push({ p: railPoint(8 - i, 0), text: fmt(i), color: '#ff8fab', side: 'bottom2' });
  } else {
    // đánh số nút chuẩn: băng dài 0..8, băng ngắn 0..4
    for (let i = 0; i <= 8; i++) {
      out.push({ p: railPoint(i, 0), text: String(i), color: '#e9ecef', side: 'bottom' });
      out.push({ p: railPoint(i, 4), text: String(i), color: '#e9ecef', side: 'top' });
    }
    for (let j = 1; j <= 3; j++) {
      out.push({ p: railPoint(0, j), text: String(j), color: '#e9ecef', side: 'left' });
      out.push({ p: railPoint(8, j), text: String(j), color: '#e9ecef', side: 'right' });
    }
  }
  return out;
}
