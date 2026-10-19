// Điều phối: vòng lặp game, cử chỉ cảm ứng, luật chơi tự do, luồng bài tập.
import { Scene3D } from './render.js';
import { Ball, Simulation, PHYS } from './physics.js';
import { R, L, W, fromDiamond, POCKETS } from './table.js';
import { systemLabels, ghostBall, cutAngle, pocketAimPoint } from './systems.js';
import { CATEGORIES, DRILLS, buildStage, stageCount, solveHint, evaluate, rackBalls, bestPocket } from './drills.js';
import { stageSVG, demoShot } from './diagram.js';
import { sfx, setSound, unlockAudio } from './audio.js';
import { ballColor } from './textures.js';

const $ = (s) => document.querySelector(s);
const deg = (r) => (r * 180) / Math.PI;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

// ---------------- cài đặt & thống kê ----------------
const DEFAULTS = { cloth: 'blue', guide: 1, view: '3d', hand: 'right', powerMode: 'swipe', sound: true, squirt: true, autoUnlock: true, labels: true, sens: 1 };
const store = {
  get(k, d) { try { return JSON.parse(localStorage.getItem(k)) ?? d; } catch { return d; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch { /* bộ nhớ bị chặn */ } },
};
const settings = { ...DEFAULTS, ...store.get('mqv-settings', {}) };
const stats = store.get('mqv-stats', {});
const saveSettings = () => store.set('mqv-settings', settings);
const saveStats = () => store.set('mqv-stats', stats);

// ---------------- trạng thái ----------------
const view = new Scene3D($('#view'));
view.setCloth(settings.cloth);
view.setMode(settings.view);
setSound(settings.sound);

const G = {
  mode: null,          // 'free8' | 'free9' | 'drill'
  drill: null, stageIdx: 0, stage: null, stageState: {},
  sim: new Simulation([]),
  phase: 'menu',       // aim | rolling | placing | result | demo
  ballInHand: false,
  hintOn: true,
  shotEvents: 0,
  free: null,          // trạng thái chơi tự do
  snapshot: null,
};
const aim = { dir: 0, a: 0, b: 0, elev: 0, locked: false, pull: 0, lastPower: 0.35 };
let previewDirty = true, lastPreview = 0;

// ---------------- dựng bàn ----------------
function setupBalls(cue, balls) {
  const list = [];
  if (cue) list.push(new Ball(0, cue.x, cue.z));
  for (const b of balls) list.push(new Ball(b.id, b.x, b.z));
  G.sim = new Simulation(list);
  view.syncBalls(G.sim.balls);
  view.updateBalls(G.sim.balls, 0);
  G.shotEvents = 0;
}

const cueBall = () => G.sim.ball(0);

function aimAtDefault() {
  const cb = cueBall(); if (!cb) return;
  const h = currentHint();
  if (h) { aim.dir = h.dir; return; }
  // nhắm vào bi gần nhất
  let best = null, bd = Infinity;
  for (const b of G.sim.balls) if (b.id && !b.pocketed) { const d = Math.hypot(b.x - cb.x, b.z - cb.z); if (d < bd) { bd = d; best = b; } }
  if (best) aim.dir = Math.atan2(best.z - cb.z, best.x - cb.x);
}

function enterAim() {
  G.phase = G.ballInHand ? 'placing' : 'aim';
  if (settings.autoUnlock) setLock(false);
  view.cam.overview = 0;
  view.cam.yaw = aim.dir;
  previewDirty = true;
  updateHUD();
}

// ---------------- chế độ chơi tự do ----------------
function startFree(kind) {
  G.mode = kind === '8' ? 'free8' : 'free9';
  G.drill = null;
  G.free = { kind, shots: 0, fouls: 0, potted: new Set(), firstShot: true };
  setupBalls(fromDiamond(1.6, 2), rackBalls(kind));
  G.ballInHand = true;
  aim.dir = 0; aim.a = 0; aim.b = 0; updateSpinUI();
  showGame(kind === '8' ? 'Tập tự do 8 bi' : 'Tập tự do 9 bi');
  enterAim();
  toast('Kéo bi cái để đặt, rồi khoá cơ và đẩy lực để phá', '');
}

function freeAfterShot(events) {
  const F = G.free;
  F.shots++;
  const potted = events.filter((e) => e.type === 'pocket').map((e) => e.ball);
  potted.filter((id) => id).forEach((id) => F.potted.add(id));
  const scratch = potted.includes(0);
  const fh = events.find((e) => e.type === 'hit' && (e.a === 0 || e.b === 0));
  const first = fh ? (fh.a === 0 ? fh.b : fh.a) : null;
  let foul = null;
  if (scratch) foul = 'Bi cái rơi lỗ';
  else if (first == null) foul = 'Không chạm bi nào';
  if (F.kind === '9' && !foul) {
    const remaining = G.sim.balls.filter((b) => b.id && (!b.pocketed || potted.includes(b.id))).map((b) => b.id);
    const lowest = Math.min(...remaining);
    if (first !== lowest) foul = `Phải chạm bi ${lowest} trước`;
  }
  F.firstShot = false;
  if (foul) {
    F.fouls++;
    // 9 bi: bi 9 rơi khi phạm lỗi được đặt lại điểm chân
    if (F.kind === '9' && potted.includes(9)) respot(9);
    toast(`Lỗi: ${foul} – bi trong tay`, 'bad');
    if (scratch) { const cb = cueBall(); cb.pocketed = false; cb.x = fromDiamond(2, 2).x; cb.z = 0; cb.vx = cb.vz = 0; view.syncBalls(G.sim.balls); }
    G.ballInHand = true;
  } else {
    G.ballInHand = false;
    if (potted.filter((id) => id).length) toast(`Vào ${potted.filter((id) => id).map((i) => 'bi ' + i).join(', ')}`, 'ok');
  }
  const left = G.sim.balls.filter((b) => b.id && !b.pocketed).length;
  const nineDown = F.kind === '9' && G.sim.ball(9)?.pocketed;
  if (left === 0 || nineDown) {
    showCard(`<div class="head"><h2>${F.kind === '9' ? 'Hết ván 9 bi!' : 'Dọn sạch bàn!'}</h2><p class="lead">${F.shots} cú · ${F.fouls} lỗi</p></div>`,
      [['Xếp lại', () => startFree(F.kind), 'primary'], ['Về menu', openMenu]]);
  }
  enterAim();
}

function respot(id) {
  const b = G.sim.ball(id);
  const f = fromDiamond(6, 2);
  b.pocketed = false; b.pocket = null; b.x = f.x; b.z = f.z;
  while (G.sim.balls.some((o) => o !== b && !o.pocketed && Math.hypot(o.x - b.x, o.z - b.z) < 2 * R)) b.x += 0.005;
  view.syncBalls(G.sim.balls);
}

// ---------------- bài tập ----------------
function drillStats(id) { return (stats[id] = stats[id] || { att: 0, ok: 0, streak: 0, best: 0 }); }

function startDrill(drill, stageIdx = 0) {
  G.mode = 'drill'; G.drill = drill; G.stageIdx = stageIdx;
  loadStage();
  showGame(drill.title);
}

function loadStage() {
  const st = buildStage(G.drill, G.stageIdx, Date.now());
  G.stage = st; G.stageState = {};
  setupBalls(st.cue, st.balls);
  G.ballInHand = !!st.ballInHand;
  view.setZones(st.goal.cueZone ? [st.goal.cueZone] : []);
  aim.a = 0; aim.b = 0; aim.elev = 0; updateSpinUI();
  aimAtDefault();
  view.cam.yaw = aim.dir;
  refreshLabels();
  enterAim();
}

function currentHint() {
  if (G.mode !== 'drill' || !G.stage) return null;
  let hint = G.stage.hint;
  const cb = cueBall(); if (!cb || cb.pocketed) return null;
  const pos = (id) => { const b = G.sim.ball(id); return b && !b.pocketed ? b : null; };
  if (G.stage.goal.clear) {
    const left = G.stage.goal.clear.filter((id) => pos(id));
    if (!left.length) return null;
    let id = left[0];
    if (!G.stage.goal.ordered) { // bi dễ nhất
      let bs = Infinity;
      for (const i of left) { const b = pos(i); const p = bestPocket(cb, b); if (!p) continue; const s = cutAngle(cb, b, pocketAimPoint(p)) + Math.hypot(b.x - cb.x, b.z - cb.z) * 20; if (s < bs) { bs = s; id = i; } }
    }
    hint = { type: 'ghost', ball: id, pocket: null };
  }
  if (hint?.type === 'ghost' && hint.pocket == null && G.stage.rack) {
    const b = pos(1); if (!b) return null;
    return { dir: Math.atan2(b.z - cb.z, b.x - cb.x), lines: [], marks: [] };
  }
  return solveHint(hint, cb, pos);
}

function drillAfterShot(events) {
  const st = G.stage;
  const res = evaluate(st, events, G.sim.balls, G.stageState);
  if (!res.done) { toast(res.msg, res.ok ? 'ok' : ''); G.ballInHand = false; enterAim(); return; }
  const s = drillStats(G.drill.id);
  s.att++;
  if (res.ok) { s.ok++; s.streak++; s.best = Math.max(s.best, s.streak); sfx.ok(); } else s.streak = 0;
  saveStats();
  toast(res.msg, res.ok ? 'ok' : 'bad');
  G.phase = 'result';
  updateHUD();
  const last = G.stageIdx >= stageCount(G.drill) - 1;
  setTimeout(() => {
    if (G.phase !== 'result') return;
    if (res.ok && !last) { G.stageIdx++; loadStage(); toast(`Chặng ${G.stageIdx + 1}/${stageCount(G.drill)}`, ''); }
    else if (res.ok && last && stageCount(G.drill) > 1) {
      showCard(`<div class="head"><h2>Hoàn thành bài!</h2><p class="lead">${G.drill.title} – cả ${stageCount(G.drill)} chặng.</p>
        <p class="stats">Tổng: ${s.ok}/${s.att} lần thành công · chuỗi tốt nhất ${s.best}</p></div>`,
        [['Tập lại từ đầu', () => { G.stageIdx = 0; loadStage(); }, 'primary'], ['Bài khác', openMenu]]);
    } else loadStage();
  }, res.ok ? 1300 : 1700);
}

// ---------------- đánh ----------------
const powerToSpeed = (p) => 0.25 + 8.75 * p * p;

function shoot(power) {
  if (G.phase !== 'aim' && G.phase !== 'placing') return;
  const cb = cueBall(); if (!cb || cb.pocketed) return;
  unlockAudio();
  power = clamp(power, 0.02, 1);
  aim.lastPower = power;
  G.snapshot = G.sim.balls.map((b) => b.clone());
  G.sim.events = [];
  G.sim.strike(0, aim.dir, powerToSpeed(power), aim.a, aim.b, (aim.elev * Math.PI) / 180, settings.squirt ? 0.02 : 0);
  sfx.cue(power);
  G.phase = 'rolling';
  G.ballInHand = false;
  view.setPaths([]); view.setGhost(null);
  aim.pull = 0;
  updateHUD();
  showPower(power, true);
}

function onShotEnd() {
  const events = G.sim.events;
  if (G.phase === 'demo') { endDemo(); return; }
  if (G.mode === 'drill') drillAfterShot(events); else freeAfterShot(events);
}

// ---------------- xem cú mẫu ----------------
function playDemo() {
  if (G.mode !== 'drill' || !G.stage?.demo || G.phase === 'rolling') return;
  loadStage();
  const d = demoShot(G.stage);
  if (!d) { toast('Bài này không có cú mẫu', ''); return; }
  aim.dir = d.dir; aim.a = G.stage.demo.spin[0]; aim.b = G.stage.demo.spin[1]; updateSpinUI();
  view.cam.yaw = aim.dir;
  toast(`Cú mẫu: lực ${(G.stage.demo.speed).toFixed(1)} m/s, điểm đánh ${fmtSpin()}`, '');
  setTimeout(() => {
    G.sim.events = [];
    G.sim.strike(0, aim.dir, G.stage.demo.speed, aim.a, aim.b, 0, 0.02);
    sfx.cue(0.4);
    G.phase = 'demo';
    view.setPaths([]); view.setGhost(null);
    updateHUD();
  }, 900);
}
function endDemo() { G.phase = 'result'; setTimeout(() => { loadStage(); toast('Đến lượt bạn', ''); }, 1100); }

// ---------------- dự đoán đường đi ----------------
function computePreview() {
  const cb = cueBall();
  const paths = [];
  let ghost = null;
  const showGuide = settings.guide > 0 && (G.phase === 'aim' || G.phase === 'placing') && cb && !cb.pocketed;
  if (showGuide) {
    const sim = G.sim.clone();
    sim.events = [];
    sim.strike(0, aim.dir, powerToSpeed(aim.lastPower), aim.a, aim.b, (aim.elev * Math.PI) / 180, settings.squirt ? 0.02 : 0);
    const full = settings.guide === 2;
    const cbPts = [[cb.x, cb.z]], obPts = [];
    let hitId = null, hitT = 0, cbEvents = 0, obEvents = 0, k = 0;
    const scb = sim.ball(0);
    const dt = 1 / 1000;
    for (let i = 0; i < 5000; i++) {
      const n0 = sim.events.length;
      sim.step(dt);
      for (let e = n0; e < sim.events.length; e++) {
        const ev = sim.events[e];
        if (ev.type === 'hit' && (ev.a === 0 || ev.b === 0)) {
          cbEvents++;
          if (hitId == null) { hitId = ev.a === 0 ? ev.b : ev.a; hitT = sim.time; ghost = { x: scb.x, z: scb.z }; const ob = sim.ball(hitId); obPts.push([ob.x, ob.z]); }
        } else if (ev.type === 'cushion' && ev.ball === 0) cbEvents++;
        else if (hitId != null && (ev.ball === hitId) && (ev.type === 'cushion' || ev.type === 'pocket')) obEvents++;
        if (ev.type === 'pocket' && ev.ball === 0) cbEvents = 99;
      }
      if (++k % 6 === 0) {
        if (!scb.pocketed) cbPts.push([scb.x, scb.z]);
        if (hitId != null) { const ob = sim.ball(hitId); if (!ob.pocketed) obPts.push([ob.x, ob.z]); }
      }
      if (!full) {
        if (cbEvents >= 1 && hitId == null) { cbPts.push([scb.x, scb.z]); break; }
        if (hitId != null && sim.time - hitT > 0.35) break;
      } else {
        if ((cbEvents >= 4 || scb.pocketed) && (hitId == null || obEvents >= 2 || sim.ball(hitId).pocketed)) break;
        if (!sim.moving) break;
      }
    }
    if (!scb.pocketed) cbPts.push([scb.x, scb.z]);
    if (hitId != null) { const ob = sim.ball(hitId); obPts.push(ob.pocketed ? [ob.dropFrom.x, ob.dropFrom.z] : [ob.x, ob.z]); }
    // đường bi cái: đến chỗ chạm (liền), sau chạm (đứt nét)
    if (ghost) {
      const cut = cbPts.findIndex(([x, z]) => Math.abs(x - ghost.x) < 1e-9 && Math.abs(z - ghost.z) < 1e-9);
      const idx = cut >= 0 ? cut : cbPts.reduce((bi, p, i) => (Math.hypot(p[0] - ghost.x, p[1] - ghost.z) < Math.hypot(cbPts[bi][0] - ghost.x, cbPts[bi][1] - ghost.z) ? i : bi), 0);
      paths.push({ pts: [...cbPts.slice(0, idx + 1), [ghost.x, ghost.z]], color: '#ffffff', width: 0.006, opacity: 0.9 });
      paths.push({ pts: [[ghost.x, ghost.z], ...cbPts.slice(idx + 1)], color: '#d7ecff', width: 0.005, opacity: 0.65, dash: [0.02, 0.015] });
      paths.push({ pts: obPts, color: '#ffd166', width: 0.007, opacity: 0.95 });
    } else paths.push({ pts: cbPts, color: '#ffffff', width: 0.006, opacity: 0.9 });
  }
  // gợi ý hệ thống
  if (G.mode === 'drill' && G.hintOn && (G.phase === 'aim' || G.phase === 'placing')) {
    const h = currentHint();
    if (h) {
      for (const [a, b, kind] of h.lines) {
        if (kind === 'sys') paths.push({ pts: [[a.x, a.z], [b.x, b.z]], color: '#ff9f1c', width: 0.007, opacity: 0.9, dash: [0.04, 0.025] });
        else if (kind === 'ob' && !settings.guide) paths.push({ pts: [[a.x, a.z], [b.x, b.z]], color: '#ffd166', width: 0.003, opacity: 0.5, dash: [0.02, 0.02] });
      }
      for (const m of h.marks) if (m.kind === 'image' || m.kind === 'contact') paths.push({ pts: circlePts(m.p, m.kind === 'image' ? R : 0.012), color: '#ff9f1c', width: 0.003, opacity: 0.9 });
      const info = $('#sysInfo');
      info.hidden = !h.info; if (h.info) info.textContent = h.info;
    }
  } else $('#sysInfo').hidden = true;
  view.setPaths(paths);
  view.setGhost(ghost);
}

function circlePts(p, r) { const out = []; for (let i = 0; i <= 40; i++) { const a = (i / 40) * Math.PI * 2; out.push([p.x + Math.cos(a) * r, p.z + Math.sin(a) * r]); } return out; }

function refreshLabels() {
  const kind = G.drill?.labels || (settings.labels ? 'std' : null);
  view.setLabels(kind ? systemLabels(kind) : []);
}

// ---------------- vòng lặp ----------------
let lastT = performance.now();
function frame(t) {
  const dt = Math.min(0.05, (t - lastT) / 1000); lastT = t;
  const sim = G.sim;
  if (G.phase === 'rolling' || G.phase === 'demo') {
    const steps = Math.min(400, Math.round(dt / PHYS.dt));
    const n0 = sim.events.length;
    for (let i = 0; i < steps; i++) sim.step();
    for (let e = n0; e < sim.events.length; e++) {
      const ev = sim.events[e];
      if (ev.type === 'hit') sfx.ball(ev.speed); else if (ev.type === 'cushion') sfx.cushion(ev.speed); else if (ev.type === 'pocket') sfx.pocket();
    }
    view.cam.overview = Math.min(1, view.cam.overview + dt * 1.5);
    if (!sim.moving) onShotEnd();
  } else if (G.phase === 'aim' || G.phase === 'placing') {
    view.cam.overview = Math.max(0, view.cam.overview - dt * 2);
    if (!aim.locked || !camLookAround) view.cam.yaw = aim.dir + camYawOffset;
    if (previewDirty && t - lastPreview > 60) { previewDirty = false; lastPreview = t; computePreview(); updateBallStrip(); }
  }
  view.updateBalls(sim.balls, dt);
  const cb = cueBall();
  const aiming = (G.phase === 'aim' || G.phase === 'placing') && cb && !cb.pocketed;
  view.setCue(aiming, cb, aim.dir, aim.a, aim.b, aim.pull, (aim.elev * Math.PI) / 180);
  view.updateCamera(dt, cb && !cb.pocketed ? cb : null);
  view.render();
  requestAnimationFrame(frame);
}

// ---------------- điều khiển cảm ứng trên bàn ----------------
let camYawOffset = 0, camLookAround = false;
const pointers = new Map();
let gesture = null;
const canvas = $('#view');

canvas.addEventListener('pointerdown', (e) => {
  if (G.phase === 'menu') return;
  canvas.setPointerCapture(e.pointerId);
  pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
  unlockAudio();
  if (pointers.size === 2) { const [a, b] = [...pointers.values()]; gesture = { type: 'pinch', d0: Math.hypot(a.x - b.x, a.y - b.y), dist0: view.cam.dist, zoom0: view.ortho.zoom }; return; }
  const cb = cueBall();
  const pt = view.pick(e.clientX, e.clientY);
  if ((G.phase === 'placing' || G.ballInHand) && cb && pt && Math.hypot(pt.x - cb.x, pt.z - cb.z) < 0.09 && (G.phase === 'aim' || G.phase === 'placing')) {
    gesture = { type: 'place' }; G.phase = 'placing'; return;
  }
  gesture = { type: 'drag', x: e.clientX, y: e.clientY, dir0: aim.dir, pitch0: view.cam.pitch, yaw0: camYawOffset };
  if (view.mode === '2d' && !aim.locked && (G.phase === 'aim' || G.phase === 'placing') && pt && cb) { aim.dir = Math.atan2(pt.z - cb.z, pt.x - cb.x); previewDirty = true; updateAimVal(); }
});

canvas.addEventListener('pointermove', (e) => {
  if (!pointers.has(e.pointerId)) return;
  pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (!gesture) return;
  if (gesture.type === 'pinch' && pointers.size >= 2) {
    const [a, b] = [...pointers.values()]; const k = Math.hypot(a.x - b.x, a.y - b.y) / gesture.d0;
    if (view.mode === '2d') { view.ortho.zoom = clamp(gesture.zoom0 * k, 1, 4); view.ortho.updateProjectionMatrix(); }
    else view.cam.dist = clamp(gesture.dist0 / k, 0.3, 3.4);
    return;
  }
  const cb = cueBall();
  if (gesture.type === 'place') {
    const pt = view.pick(e.clientX, e.clientY); if (pt && cb) placeCue(pt);
    return;
  }
  if (gesture.type === 'drag') {
    const dx = e.clientX - gesture.x, dy = e.clientY - gesture.y;
    const canAim = !aim.locked && (G.phase === 'aim' || G.phase === 'placing');
    if (view.mode === '2d') {
      if (canAim && cb) { const pt = view.pick(e.clientX, e.clientY); if (pt) { aim.dir = Math.atan2(pt.z - cb.z, pt.x - cb.x); previewDirty = true; updateAimVal(); } }
    } else {
      const sens = 0.0042 * settings.sens * (0.6 + 0.4 * view.cam.dist);
      if (canAim) { aim.dir = gesture.dir0 + dx * sens; previewDirty = true; updateAimVal(); }
      else { camLookAround = true; camYawOffset = gesture.yaw0 + dx * 0.006; view.cam.yaw = aim.dir + camYawOffset; }
      view.cam.pitch = clamp(gesture.pitch0 + dy * 0.004, 0.06, 1.45);
    }
  }
});
const endPtr = (e) => {
  pointers.delete(e.pointerId);
  if (gesture?.type === 'place') { G.phase = 'placing'; previewDirty = true; }
  if (pointers.size === 0) gesture = null;
};
canvas.addEventListener('pointerup', endPtr);
canvas.addEventListener('pointercancel', endPtr);
canvas.addEventListener('wheel', (e) => {
  e.preventDefault();
  if (view.mode === '2d') { view.ortho.zoom = clamp(view.ortho.zoom * (e.deltaY < 0 ? 1.1 : 0.9), 1, 4); view.ortho.updateProjectionMatrix(); }
  else view.cam.dist = clamp(view.cam.dist * (e.deltaY < 0 ? 0.9 : 1.1), 0.3, 3.4);
}, { passive: false });

function placeCue(pt) {
  const cb = cueBall();
  const x = clamp(pt.x, -L / 2 + R + 0.002, L / 2 - R - 0.002), z = clamp(pt.z, -W / 2 + R + 0.002, W / 2 - R - 0.002);
  const blocked = G.sim.balls.some((b) => b.id && !b.pocketed && Math.hypot(b.x - x, b.z - z) < 2 * R + 0.001);
  if (blocked) return;
  cb.x = x; cb.z = z; cb.pocketed = false;
  previewDirty = true;
}

// ---------------- khoá cơ ----------------
function setLock(on) {
  aim.locked = on;
  const b = $('#btnLock');
  b.setAttribute('aria-pressed', String(on));
  $('#lockLbl').textContent = on ? 'Đã khoá' : 'Khoá cơ';
  document.body.classList.toggle('locked', on);
  if (!on) { camYawOffset = 0; camLookAround = false; }
}
$('#btnLock').addEventListener('click', () => { setLock(!aim.locked); if (navigator.vibrate) navigator.vibrate(12); });

// ---------------- vi chỉnh ----------------
const FINE = 0.0004; // rad / px (~0,023°)
function nudge(rad) { if (aim.locked || (G.phase !== 'aim' && G.phase !== 'placing')) return; aim.dir += rad; previewDirty = true; updateAimVal(); }
(() => {
  const strip = $('#fineStrip'), ticks = strip.querySelector('.ticks');
  let x0 = null, off = 0;
  strip.addEventListener('pointerdown', (e) => { strip.setPointerCapture(e.pointerId); x0 = e.clientX; });
  strip.addEventListener('pointermove', (e) => {
    if (x0 == null) return; const dx = e.clientX - x0; x0 = e.clientX;
    if (aim.locked) return;
    nudge(dx * FINE); off += dx; ticks.style.transform = `translateX(${off % 40}px)`;
  });
  const up = () => { x0 = null; };
  strip.addEventListener('pointerup', up); strip.addEventListener('pointercancel', up);
  const hold = (btn, sign) => {
    let timer = null;
    const start = (e) => { e.preventDefault(); nudge(sign * 0.0009); let n = 0; timer = setInterval(() => nudge(sign * 0.0009 * (++n > 12 ? 4 : 1)), 70); };
    const stop = () => clearInterval(timer);
    btn.addEventListener('pointerdown', start); btn.addEventListener('pointerup', stop); btn.addEventListener('pointerleave', stop); btn.addEventListener('pointercancel', stop);
  };
  hold($('#fineL'), -1); hold($('#fineR'), 1);
})();

// ---------------- điểm đánh ----------------
(() => {
  const pad = $('#spinPad');
  const set = (e) => {
    const r = pad.getBoundingClientRect();
    let a = ((e.clientX - r.left) / r.width - 0.5) * 2, b = -((e.clientY - r.top) / r.height - 0.5) * 2;
    const m = Math.hypot(a, b); if (m > 1) { a /= m; b /= m; }
    aim.a = +(a * 0.6).toFixed(2); aim.b = +(b * 0.6).toFixed(2);
    updateSpinUI(); previewDirty = true;
  };
  let down = false, lastTap = 0;
  pad.addEventListener('pointerdown', (e) => {
    pad.setPointerCapture(e.pointerId); down = true;
    const now = performance.now();
    if (now - lastTap < 300) { aim.a = 0; aim.b = 0; updateSpinUI(); previewDirty = true; down = false; return; }
    lastTap = now; set(e);
  });
  pad.addEventListener('pointermove', (e) => { if (down) set(e); });
  pad.addEventListener('pointerup', () => { down = false; });
  pad.addEventListener('keydown', (e) => {
    const k = { ArrowUp: [0, 0.05], ArrowDown: [0, -0.05], ArrowLeft: [-0.05, 0], ArrowRight: [0.05, 0] }[e.key];
    if (k) { aim.a = clamp(aim.a + k[0], -0.6, 0.6); aim.b = clamp(aim.b + k[1], -0.6, 0.6); updateSpinUI(); previewDirty = true; e.preventDefault(); }
  });
  $('#elev').addEventListener('input', (e) => { aim.elev = +e.target.value; $('#elevVal').textContent = `${aim.elev}°`; previewDirty = true; });
})();

function fmtSpin() {
  const f = (v) => (v > 0 ? '+' : '') + v.toFixed(2).replace('.', ',');
  if (!aim.a && !aim.b) return 'tâm bi';
  const parts = [];
  if (aim.b) parts.push(`${aim.b > 0 ? 'theo' : 'kéo'} ${f(aim.b)}R`);
  if (aim.a) parts.push(`${aim.a > 0 ? 'phải' : 'trái'} ${f(aim.a)}R`);
  return parts.join(' · ');
}
function updateSpinUI() {
  const dot = $('#spinDot');
  dot.style.left = `${50 + (aim.a / 0.6) * 40}%`; dot.style.top = `${50 - (aim.b / 0.6) * 40}%`;
  const t = fmtSpin(); $('#spinVal').textContent = t === 'tâm bi' ? 'Tâm bi' : t;
  $('#elev').value = aim.elev; $('#elevVal').textContent = `${aim.elev}°`;
}
function updateAimVal() { let d = deg(aim.dir) % 360; if (d < 0) d += 360; $('#aimVal').textContent = `Hướng ${d.toFixed(2).replace('.', ',')}°`; }

// ---------------- lực: kéo lùi rồi đẩy tới ----------------
(() => {
  const pad = $('#powerPad');
  let st = null;
  const H = () => pad.getBoundingClientRect();
  pad.addEventListener('pointerdown', (e) => {
    if (G.phase !== 'aim' && G.phase !== 'placing') return;
    unlockAudio();
    pad.setPointerCapture(e.pointerId);
    st = { y0: e.clientY, maxPull: 0, samples: [{ y: e.clientY, t: performance.now() }], fired: false };
    pad.classList.add('active');
  });
  pad.addEventListener('pointermove', (e) => {
    if (!st || st.fired) return;
    const now = performance.now();
    st.samples.push({ y: e.clientY, t: now });
    while (st.samples.length > 2 && now - st.samples[0].t > 90) st.samples.shift();
    const h = H().height;
    const pull = clamp((e.clientY - st.y0) / (h * 0.65), 0, 1);
    st.maxPull = Math.max(st.maxPull, pull);
    aim.pull = pull * 0.22;
    $('#pullFill').style.height = `${pull * 70}%`;
    // tốc độ đẩy lên (px/s)
    const a = st.samples[0], b = st.samples[st.samples.length - 1];
    const v = b.t > a.t ? (a.y - b.y) / ((b.t - a.t) / 1000) : 0;
    const p = speedToPower(v, h);
    if (v > 0) showPower(p, false);
    // bắn khi đầu cơ quay về vạch xuất phát mà vẫn đang đẩy lên
    if (st.maxPull > 0.04 && e.clientY <= st.y0 && v > 40) { st.fired = true; finish(p); }
  });
  const up = (e) => {
    if (!st) return;
    if (!st.fired) {
      const a = st.samples[0], b = st.samples[st.samples.length - 1];
      const v = b.t > a.t ? (a.y - b.y) / ((b.t - a.t) / 1000) : 0;
      if (st.maxPull > 0.04 && v > 120) finish(speedToPower(v, H().height));
      else { aim.pull = 0; toast('Kéo xuống rồi đẩy lên dứt khoát để đánh', ''); }
    }
    st = null; pad.classList.remove('active');
    $('#pullFill').style.height = '0';
  };
  pad.addEventListener('pointerup', up); pad.addEventListener('pointercancel', up);
  function finish(p) { aim.pull = 0; $('#pullFill').style.height = '0'; shoot(p); }
  function speedToPower(v, h) { const vmax = Math.max(1400, h * 5.5) * settings.sens; return clamp(v / vmax, 0, 1); }
  // chế độ thanh trượt
  $('#powSlider').addEventListener('input', (e) => { aim.lastPower = +e.target.value / 100; showPower(aim.lastPower, false); previewDirty = true; });
  $('#btnShoot').addEventListener('click', () => shoot(+$('#powSlider').value / 100));
})();

function showPower(p, final) {
  $('#powFill').style.height = `${p * 100}%`;
  const v = powerToSpeed(p);
  $('#powVal').textContent = `Lực ${Math.round(p * 100)}% · ${v.toFixed(1).replace('.', ',')} m/s`;
  if (final) setTimeout(() => { $('#powFill').style.height = '0'; }, 900);
}

// ---------------- HUD ----------------
function showGame(title) {
  $('#menu').hidden = true; $('#hud').hidden = false;
  $('#hudTitle').textContent = title;
  const isDrill = G.mode === 'drill';
  $('#btnFormula').hidden = !isDrill; $('#btnHint').hidden = !isDrill; $('#btnDemo').hidden = !isDrill || !G.stage?.demo;
  $('#btnHint').classList.toggle('on', G.hintOn);
  view.cam.pitch = 0.3; view.cam.dist = 1.0;
  view.snapCamera(cueBall());
  refreshLabels();
  updateHUD();
}

function updateHUD() {
  const sub = $('#hudSub');
  if (G.mode === 'drill') {
    const s = drillStats(G.drill.id);
    const n = stageCount(G.drill);
    sub.textContent = `${n > 1 ? `Chặng ${G.stageIdx + 1}/${n} · ` : ''}Thành công ${s.ok}/${s.att} · Chuỗi ${s.streak}`;
    $('#btnDemo').hidden = !G.stage?.demo;
  } else if (G.free) sub.textContent = `${G.free.shots} cú · ${G.free.fouls} lỗi`;
  $('#btnHand').hidden = !G.ballInHand;
  $('#btnHand').classList.toggle('on', G.phase === 'placing');
  updateAimVal();
  updateBallStrip();
}

function updateBallStrip() {
  const el = $('#ballStrip');
  const ids = G.sim.balls.filter((b) => b.id).map((b) => b);
  el.innerHTML = ids.map((b) => {
    const c = ballColor(b.id);
    const bg = b.id > 8 ? `linear-gradient(${'#f7f3ea'} 25%, ${c} 25% 75%, ${'#f7f3ea'} 75%)` : c;
    return `<i class="${b.pocketed ? 'gone' : ''}" style="background:${bg}">${b.id}</i>`;
  }).join('');
}

let toastTimer = null;
function toast(msg, kind) {
  const t = $('#toast'); t.textContent = msg; t.className = `toast show ${kind || ''}`;
  clearTimeout(toastTimer); toastTimer = setTimeout(() => { t.className = 'toast'; }, 1900);
}

// ---------------- nút trên thanh công cụ ----------------
$('#btnMenu').addEventListener('click', openMenu);
$('#btnView').addEventListener('click', () => {
  settings.view = view.mode === '3d' ? '2d' : '3d'; saveSettings();
  view.setMode(settings.view); $('#viewLbl').textContent = settings.view === '3d' ? '3D' : '2D';
  view.snapCamera(cueBall());
});
$('#btnGuide').addEventListener('click', () => {
  settings.guide = (settings.guide + 1) % 3; saveSettings(); previewDirty = true;
  $('#guideBadge').textContent = ['Tắt', '1', 'Đủ'][settings.guide];
  toast(['Tắt hỗ trợ ngắm', 'Hỗ trợ ngắm: cơ bản (tới điểm chạm)', 'Hỗ trợ ngắm: đầy đủ (dự đoán vật lý)'][settings.guide], '');
});
$('#btnHint').addEventListener('click', () => { G.hintOn = !G.hintOn; $('#btnHint').classList.toggle('on', G.hintOn); previewDirty = true; toast(G.hintOn ? 'Hiện đường hệ thống' : 'Ẩn đường hệ thống', ''); });
$('#btnReset').addEventListener('click', () => {
  if (G.mode === 'drill') loadStage();
  else if (G.free) startFree(G.free.kind);
});
$('#btnHand').addEventListener('click', () => { if (G.ballInHand) { G.phase = G.phase === 'placing' ? 'aim' : 'placing'; toast(G.phase === 'placing' ? 'Kéo bi cái tới vị trí mới' : 'Xong đặt bi', ''); updateHUD(); } });
$('#btnFormula').addEventListener('click', () => G.drill && openDrillCard(G.drill, true));
$('#btnDemo').addEventListener('click', playDemo);

// phím tắt bàn phím (máy tính)
window.addEventListener('keydown', (e) => {
  if (G.phase === 'menu' || e.target.tagName === 'INPUT') return;
  if (e.key === 'l' || e.key === 'L') setLock(!aim.locked);
  if (e.key === 'ArrowLeft') nudge(e.shiftKey ? -0.0002 : -0.002);
  if (e.key === 'ArrowRight') nudge(e.shiftKey ? 0.0002 : 0.002);
  if (e.key === ' ') { e.preventDefault(); shoot(+$('#powSlider').value / 100); }
});

// ---------------- menu & phiếu bài tập ----------------
let curCat = 'aim';
function openMenu() {
  G.phase = 'menu';
  $('#hud').hidden = true; $('#menu').hidden = false;
  if ($('#card').open) $('#card').close();
  renderMenu();
}

function renderMenu() {
  $('#catList').innerHTML = CATEGORIES.map((c) => `<button class="cat" role="tab" aria-selected="${c.id === curCat}" data-cat="${c.id}">${c.title}</button>`).join('');
  const list = DRILLS.filter((d) => d.cat === curCat);
  $('#drillList').innerHTML = list.map((d) => {
    const s = stats[d.id];
    const st = buildStage(d, 0, 7);
    return `<button class="drill" data-id="${d.id}">
      <div class="thumb">${stageSVG(st, { labels: d.labels || 'std', title: d.title })}</div>
      <div class="meta"><h3>${d.title}</h3><p>${d.summary}</p>
      <div class="row"><span class="lvl" aria-label="Độ khó ${d.level}/3">${'◆'.repeat(d.level)}${'◇'.repeat(3 - d.level)}</span>
      <span>${s ? `${s.ok}/${s.att} thành công` : `${stageCount(d)} chặng`}</span></div></div></button>`;
  }).join('');
}
$('#catList').addEventListener('click', (e) => { const b = e.target.closest('[data-cat]'); if (b) { curCat = b.dataset.cat; renderMenu(); } });
$('#drillList').addEventListener('click', (e) => { const b = e.target.closest('[data-id]'); if (b) openDrillCard(DRILLS.find((d) => d.id === b.dataset.id)); });
document.querySelectorAll('[data-free]').forEach((b) => b.addEventListener('click', () => startFree(b.dataset.free)));

const demoCache = new Map();
function openDrillCard(drill, inGame = false) {
  const idx = inGame ? G.stageIdx : 0;
  const st = inGame && G.stage ? G.stage : buildStage(drill, idx, 7);
  const key = `${drill.id}:${idx}`;
  let demo = demoCache.get(key);
  if (demo === undefined && !drill.generate) { demo = demoShot(st); demoCache.set(key, demo); }
  if (drill.generate) demo = demoShot(st);
  const s = stats[drill.id];
  const yt = `https://www.youtube.com/results?search_query=${encodeURIComponent(drill.video)}`;
  const html = `<div class="head"><h2>${drill.title}</h2><p class="lead">${drill.summary}</p></div>
    <div class="body">
      <div class="fig">${stageSVG(st, { labels: drill.labels || 'std', demo, title: drill.title })}
        <div class="legend"><span><i></i>bi cái</span><span><i class="ob"></i>bi mục tiêu</span>${drill.cat === 'sys' ? '<span><i class="sys"></i>đường hệ thống</span>' : ''}<span>Đường đi lấy từ mô phỏng cú mẫu</span></div></div>
      <h3>Công thức</h3>
      <div class="formulabox">${drill.formula}</div>
      <h3>Cách tập</h3><ol>${drill.steps.map((x) => `<li>${x}</li>`).join('')}</ol>
      <h3>Mẹo</h3><ul>${drill.tips.map((x) => `<li>${x}</li>`).join('')}</ul>
      ${demo && drill.stages?.[idx]?.demo ? `<p class="stats">Cú mẫu: ${drill.stages[idx].demo.speed.toFixed(1).replace('.', ',')} m/s · điểm đánh ngang ${drill.stages[idx].demo.spin[0]}R, dọc ${drill.stages[idx].demo.spin[1]}R</p>` : ''}
      <p><a class="video" href="${yt}" target="_blank" rel="noopener">Tìm video hướng dẫn miễn phí trên YouTube</a></p>
      ${s ? `<p class="stats">Kết quả của bạn: ${s.ok}/${s.att} thành công · chuỗi tốt nhất ${s.best}</p>` : ''}
    </div>`;
  showCard(html, inGame
    ? [['Tiếp tục tập', null, 'primary'], ['Tập lại chặng', () => loadStage()]]
    : [['Bắt đầu tập', () => startDrill(drill), 'primary'], ['Đóng', null, 'ghost']]);
}

function showCard(html, buttons) {
  const d = $('#card');
  d.innerHTML = `<div class="wrap">${html}<div class="foot">${buttons.map(([t, , cls], i) => `<button class="btn ${cls || ''}" data-i="${i}">${t}</button>`).join('')}</div></div>`;
  d.querySelectorAll('.foot .btn').forEach((b) => b.addEventListener('click', () => { d.close(); const fn = buttons[+b.dataset.i][1]; if (fn) fn(); }));
  if (!d.open) d.showModal();
}

$('#btnSettings').addEventListener('click', () => {
  const sel = (id, opts, val) => `<select id="${id}">${opts.map(([v, t]) => `<option value="${v}" ${String(v) === String(val) ? 'selected' : ''}>${t}</option>`).join('')}</select>`;
  showCard(`<div class="head"><h2>Cài đặt</h2></div><div class="body">
    <div class="setrow"><label for="sCloth">Màu nỉ</label>${sel('sCloth', [['blue', 'Xanh giải đấu'], ['green', 'Xanh lá'], ['teal', 'Xanh ngọc'], ['red', 'Đỏ rượu'], ['grey', 'Xám']], settings.cloth)}</div>
    <div class="setrow"><label for="sHand">Tay đẩy lực<small>Tay còn lại giữ phím khoá cơ và chỉnh điểm đánh</small></label>${sel('sHand', [['right', 'Tay phải'], ['left', 'Tay trái']], settings.hand)}</div>
    <div class="setrow"><label for="sPower">Cách chỉnh lực</label>${sel('sPower', [['swipe', 'Vuốt đẩy (theo tốc độ tay)'], ['slider', 'Thanh lực + nút Đánh']], settings.powerMode)}</div>
    <div class="setrow"><label for="sSens">Độ nhạy<small>Ngắm 3D và tốc độ đẩy lực</small></label>${sel('sSens', [[0.6, 'Thấp'], [1, 'Vừa'], [1.4, 'Cao']], settings.sens)}</div>
    <div class="setrow"><label for="sSquirt">Lệch hướng khi đánh english (squirt)</label>${sel('sSquirt', [[1, 'Bật – như cơ thật'], [0, 'Tắt']], settings.squirt ? 1 : 0)}</div>
    <div class="setrow"><label for="sAuto">Tự mở khoá sau mỗi cú</label>${sel('sAuto', [[1, 'Có'], [0, 'Không']], settings.autoUnlock ? 1 : 0)}</div>
    <div class="setrow"><label for="sLabels">Hiện số nút trên băng</label>${sel('sLabels', [[1, 'Có'], [0, 'Không']], settings.labels ? 1 : 0)}</div>
    <div class="setrow"><label for="sSound">Âm thanh</label>${sel('sSound', [[1, 'Bật'], [0, 'Tắt']], settings.sound ? 1 : 0)}</div>
  </div>`, [['Lưu', () => {
    settings.cloth = $('#sCloth').value; settings.hand = $('#sHand').value; settings.powerMode = $('#sPower').value;
    settings.sens = +$('#sSens').value; settings.squirt = $('#sSquirt').value === '1'; settings.autoUnlock = $('#sAuto').value === '1';
    settings.labels = $('#sLabels').value === '1'; settings.sound = $('#sSound').value === '1';
    saveSettings(); applySettings();
  }, 'primary'], ['Huỷ', null, 'ghost']]);
});

$('#btnHelp').addEventListener('click', () => showCard(`<div class="head"><h2>Cách điều khiển</h2></div><div class="body"><dl class="help">
  <dt>Ngắm</dt><dd>Kéo một ngón trên bàn. Ở góc nhìn 2D, cơ chỉ thẳng tới chỗ ngón tay; ở 3D, kéo ngang để xoay, kéo dọc để đổi độ cao camera. Hai ngón để phóng to/thu nhỏ.</dd>
  <dt>Vi chỉnh</dt><dd>Kéo thanh vạch ở giữa (mỗi điểm ảnh ≈ 0,02°) hoặc giữ nút ‹ ›.</dd>
  <dt>Khoá cơ</dt><dd>Chạm nút <b>Khoá cơ</b> để giữ nguyên hướng. Khi khoá, kéo trên bàn chỉ xoay camera để quan sát. Chạm lần nữa để mở.</dd>
  <dt>Lực đánh</dt><dd>Đặt ngón tay còn lại lên ô lực, <b>kéo xuống</b> (lùi cơ) rồi <b>đẩy lên</b>. Tốc độ đẩy quyết định lực: đẩy chậm = đánh nhẹ, đẩy nhanh và dứt khoát = đánh mạnh. Thả tay mà không đẩy thì huỷ cú.</dd>
  <dt>Điểm đánh</dt><dd>Kéo chấm xanh trên quả bi trắng: trên = theo, dưới = kéo, trái/phải = english. Chạm đúp để về tâm. Thanh nhỏ phía trên chỉnh độ nâng cơ (massé).</dd>
  <dt>Hỗ trợ ngắm</dt><dd>Biểu tượng con mắt: Tắt / Cơ bản (tới điểm chạm, hướng bi mục tiêu) / Đầy đủ (dự đoán vật lý cả xoáy, băng). Dự đoán dùng lực của cú trước.</dd>
  <dt>Bàn phím</dt><dd>L: khoá · ← →: xoay (giữ Shift để chỉnh rất nhỏ) · Space: đánh theo thanh lực.</dd>
</dl></div>`, [['Đã hiểu', null, 'primary']]));

$('#btnSources').addEventListener('click', () => showCard(`<div class="head"><h2>Nguồn tham khảo</h2></div><div class="body">
  <p>Bài tập được biên soạn lại từ các kiến thức và bài giảng miễn phí phổ biến; sơ đồ được vẽ lại từ mô phỏng trong ứng dụng.</p>
  <ul>
    <li><a class="video" href="https://drdavepoolinfo.com/FAQ/bank-kick/diamond-systems/" target="_blank" rel="noopener">Dr. Dave Alciatore – các hệ thống nút số</a></li>
    <li><a class="video" href="https://billiards.colostate.edu/bd_articles/2010/nov10.pdf" target="_blank" rel="noopener">Billiards Digest (11/2010) – Corner-5</a></li>
    <li><a class="video" href="https://drdavepoolinfo.com/?p=2349" target="_blank" rel="noopener">Thông số vật lý thiết bị bi-a</a></li>
    <li><a class="video" href="https://www.youtube.com/results?search_query=dr+dave+pool+drills" target="_blank" rel="noopener">Video bài tập miễn phí trên YouTube</a></li>
    <li><a class="video" href="https://www.poolshot.org" target="_blank" rel="noopener">PoolShot – phần mềm tạo bài tập (tham khảo phong cách sơ đồ)</a></li>
  </ul></div>`, [['Đóng', null, 'primary']]));

function applySettings() {
  document.body.classList.toggle('hand-left', settings.hand === 'left');
  document.body.classList.toggle('hand-right', settings.hand !== 'left');
  document.body.classList.toggle('slider', settings.powerMode === 'slider');
  $('#sliderMode').hidden = settings.powerMode !== 'slider';
  view.setCloth(settings.cloth);
  setSound(settings.sound);
  $('#viewLbl').textContent = settings.view === '3d' ? '3D' : '2D';
  $('#guideBadge').textContent = ['Tắt', '1', 'Đủ'][settings.guide];
  refreshLabels();
  previewDirty = true;
}

window.addEventListener('resize', () => { view.resize(); });

// khởi động
applySettings();
// bàn mẫu phía sau menu
setupBalls(fromDiamond(2, 2), rackBalls('9'));
view.cam.pitch = 0.5; view.cam.dist = 2.2;
renderMenu();
requestAnimationFrame(frame);

if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(() => {});

// cho phép kiểm thử tự động
window.__mqv = { G, aim, view, shoot, startDrill, startFree, DRILLS, setLock, openMenu };
