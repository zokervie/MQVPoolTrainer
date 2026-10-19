// Sơ đồ bài tập dạng SVG (kiểu phiếu bài tập): bàn, nút đánh số, bi, vùng đích,
// đường hệ thống và đường đi THỰC TẾ lấy từ mô phỏng vật lý của cú mẫu.
import { R, L, W, POCKETS } from './table.js';
import { systemLabels, railPoint } from './systems.js';
import { solveHint, evaluate } from './drills.js';
import { Ball, Simulation } from './physics.js';
import { ballColor } from './textures.js';

const S = 1000; // mét → đơn vị SVG
const BR = R * 1.45; // bi vẽ to hơn thực tế để dễ đọc
const CB = 0.05, RW = 0.115;

/** Mô phỏng cú mẫu, có tinh chỉnh nhỏ quanh hướng gợi ý. Trả về {dir, traces, ok}. */
export function demoShot(st) {
  if (!st.demo || !st.cue) return null;
  const pos = (id) => st.balls.find((b) => b.id === id);
  const h = solveHint(st.hint, st.cue, pos);
  if (!h) return null;
  const focus = new Set([0]);
  if (st.hint.ball) focus.add(st.hint.ball);
  const run = (dir, trace) => {
    const sim = new Simulation([new Ball(0, st.cue.x, st.cue.z), ...st.balls.map((b) => new Ball(b.id, b.x, b.z))]);
    sim.trackRotation = false;
    if (trace) { sim.trace = { ids: focus, pts: new Map([...focus].map((id) => [id, []])) }; for (const id of focus) sim.trace.pts.get(id).push([pos(id)?.x ?? st.cue.x, pos(id)?.z ?? st.cue.z]); }
    sim.strike(0, dir, st.demo.speed, st.demo.spin[0], st.demo.spin[1], 0, 0.02);
    sim.runUntilRest(20, 1 / 1500);
    if (trace) for (const id of focus) { const b = sim.ball(id); if (b) sim.trace.pts.get(id).push(b.pocketed ? [b.dropFrom.x, b.dropFrom.z] : [b.x, b.z]); }
    return { sim, res: evaluate(st, sim.events, sim.balls, {}) };
  };
  let best = h.dir;
  if (!run(h.dir).res.ok) {
    outer: for (let k = 1; k <= 20; k++) for (const s of [1, -1]) {
      const d = h.dir + (s * k * 0.1 * Math.PI) / 180;
      if (run(d).res.ok) { best = d; break outer; }
    }
  }
  const { sim, res } = run(best, true);
  return { dir: best, traces: sim.trace.pts, ok: res.ok, hint: h };
}

const f = (n) => (n * S).toFixed(1);

export function stageSVG(st, opts = {}) {
  const labelsKind = opts.labels || 'std';
  const OX = L / 2 + CB + RW, OZ = W / 2 + CB + RW;
  const vb = `${f(-OX - 0.02)} ${f(-OZ - 0.02)} ${f(2 * OX + 0.04)} ${f(2 * OZ + 0.04)}`;
  const out = [];
  out.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb}" class="diagram" role="img" aria-label="${opts.title || 'Sơ đồ bài tập'}">`);
  out.push(`<defs><radialGradient id="cl" cx="50%" cy="45%" r="70%"><stop offset="0" stop-color="#2a6db3"/><stop offset="1" stop-color="#1a4f86"/></radialGradient>
    <marker id="ah" viewBox="0 0 10 10" refX="7" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="context-stroke"/></marker></defs>`);
  out.push(`<rect x="${f(-OX)}" y="${f(-OZ)}" width="${f(2 * OX)}" height="${f(2 * OZ)}" rx="40" fill="#5c3a22"/>`);
  out.push(`<rect x="${f(-L / 2 - CB)}" y="${f(-W / 2 - CB)}" width="${f(L + 2 * CB)}" height="${f(W + 2 * CB)}" fill="#174a80"/>`);
  out.push(`<rect x="${f(-L / 2)}" y="${f(-W / 2)}" width="${f(L)}" height="${f(W)}" fill="url(#cl)"/>`);
  for (const p of POCKETS) out.push(`<circle cx="${f(p.x)}" cy="${f(p.z)}" r="${f(p.r)}" fill="#0c0c0d"/>`);
  // nút
  const dm = (p) => `<path d="M${f(p.x)} ${f(p.z - 0.011)}l${f(0.007)} ${f(0.011)}l${f(-0.007)} ${f(0.011)}l${f(-0.007)} ${f(-0.011)}z" fill="#e9dcc0"/>`;
  for (let i = 1; i < 8; i++) if (i !== 4) { out.push(dm(railPoint(i, 0)), dm(railPoint(i, 4))); }
  for (let j = 1; j < 4; j++) out.push(dm(railPoint(0, j)), dm(railPoint(8, j)));
  // số nút
  for (const lb of systemLabels(labelsKind)) {
    let { x, z } = lb.p; const o = 0.05;
    if (lb.side === 'top') z -= o; else if (lb.side === 'bottom') z += o; else if (lb.side === 'left') x -= o; else if (lb.side === 'right') x += o;
    else if (lb.side === 'bottom2') z -= 0.13;
    out.push(`<text x="${f(x)}" y="${f(z)}" fill="${lb.color}" font-size="${lb.side === 'bottom2' ? 40 : 48}" font-weight="700" text-anchor="middle" dominant-baseline="central">${lb.text}</text>`);
  }
  // vùng đích
  if (st.goal?.cueZone) {
    const z = st.goal.cueZone;
    out.push(`<circle cx="${f(z.x)}" cy="${f(z.z)}" r="${f(z.r)}" fill="rgba(255,209,102,.18)" stroke="#ffd166" stroke-width="5" stroke-dasharray="18 12"/>`);
  }
  // đường hệ thống / gợi ý
  const demo = opts.demo;
  const h = demo?.hint;
  if (h) {
    for (const [a, b, kind] of h.lines) {
      if (kind !== 'sys') continue;
      out.push(`<line x1="${f(a.x)}" y1="${f(a.z)}" x2="${f(b.x)}" y2="${f(b.z)}" stroke="#ff9f1c" stroke-width="5" stroke-dasharray="20 14"/>`);
    }
    for (const m of h.marks) {
      if (m.kind === 'image') out.push(`<circle cx="${f(m.p.x)}" cy="${f(m.p.z)}" r="${f(BR)}" fill="none" stroke="#ff9f1c" stroke-width="5" stroke-dasharray="10 8"/>`);
      if (m.label) {
        // nhãn đặt vào phía trong mặt bàn để không đè số nút
        const lx = Math.max(-L / 2 + 0.12, Math.min(L / 2 - 0.12, m.p.x)), lz = Math.max(-W / 2 + 0.07, Math.min(W / 2 - 0.07, m.p.z));
        out.push(`<text x="${f(lx)}" y="${f(lz)}" fill="#ffbf69" stroke="#10304f" stroke-width="8" paint-order="stroke" font-size="44" font-weight="800" text-anchor="middle" dominant-baseline="central">${m.label}</text>`);
      }
    }
  }
  // đường đi mô phỏng
  if (demo?.traces) {
    for (const [id, pts] of demo.traces) {
      if (pts.length < 2) continue;
      const d = pts.map(([x, z], i) => `${i ? 'L' : 'M'}${f(x)} ${f(z)}`).join('');
      out.push(`<path d="${d}" fill="none" stroke="${id === 0 ? '#ffffff' : '#ffd166'}" stroke-width="${id === 0 ? 6 : 6}" ${id === 0 ? 'stroke-dasharray="16 10"' : ''} stroke-linejoin="round" marker-end="url(#ah)" opacity=".92"/>`);
    }
  }
  // bi
  const ball = (id, p) => {
    const col = ballColor(id);
    let s = `<g transform="translate(${f(p.x)} ${f(p.z)})"><circle r="${f(BR)}" fill="${id > 8 ? '#f7f3ea' : col}" stroke="#0b1520" stroke-width="4"/>`;
    if (id > 8) s += `<rect x="${f(-BR * 0.97)}" y="${f(-BR * 0.5)}" width="${f(2 * BR * 0.97)}" height="${f(BR)}" fill="${col}"/><circle r="${f(BR)}" fill="none" stroke="#0b1520" stroke-width="4"/>`;
    if (id) s += `<circle r="${f(BR * 0.55)}" fill="#f7f3ea"/><text font-size="${id > 9 ? 32 : 40}" font-weight="800" text-anchor="middle" dominant-baseline="central" fill="#111">${id}</text>`;
    return s + '</g>';
  };
  for (const b of st.balls || []) out.push(ball(b.id, b));
  if (st.cue) out.push(ball(0, st.cue));
  out.push('</svg>');
  return out.join('');
}
