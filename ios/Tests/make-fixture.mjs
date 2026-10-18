// Sinh dữ liệu đối chiếu từ engine web (src/*.js) để kiểm tra bản Swift cho kết quả giống hệt.
// Chạy: node ios/Tests/make-fixture.mjs > ios/Tests/fixture.json
import { DRILLS, buildStage, stageCount, solveHint, evaluate } from '../../src/drills.js';
import { Ball, Simulation } from '../../src/physics.js';

// bản sao demoShot của src/diagram.js (file đó kéo theo three.js)
function demoShot(st) {
  const pos = (id) => st.balls.find((b) => b.id === id);
  const h = solveHint(st.hint, st.cue, pos);
  if (!h) return null;
  const run = (dir) => {
    const sim = new Simulation([new Ball(0, st.cue.x, st.cue.z), ...st.balls.map((b) => new Ball(b.id, b.x, b.z))]);
    sim.trackRotation = false;
    sim.strike(0, dir, st.demo.speed, st.demo.spin[0], st.demo.spin[1], 0, 0.02);
    sim.runUntilRest(20, 1 / 1500);
    return evaluate(st, sim.events, sim.balls, {});
  };
  let best = h.dir;
  if (!run(h.dir).ok) {
    outer: for (let k = 1; k <= 20; k++) for (const s of [1, -1]) {
      const d = h.dir + (s * k * 0.1 * Math.PI) / 180;
      if (run(d).ok) { best = d; break outer; }
    }
  }
  return { dir: best, ok: run(best).ok };
}

const out = { demos: [], shots: [] };
for (const dr of DRILLS) {
  for (let i = 0; i < stageCount(dr); i++) {
    const st = buildStage(dr, i, 12345);
    const entry = { drill: dr.id, stage: i, cue: st.cue, balls: st.balls.map((b) => ({ id: b.id, x: b.x, z: b.z })) };
    const d = st.demo && st.cue ? demoShot(st) : null;
    if (d) {
      entry.dir = d.dir; entry.ok = d.ok;
      const sim = new Simulation([new Ball(0, st.cue.x, st.cue.z), ...st.balls.map((b) => new Ball(b.id, b.x, b.z))]);
      sim.trackRotation = false;
      sim.strike(0, d.dir, st.demo.speed, st.demo.spin[0], st.demo.spin[1], 0, 0.02);
      sim.runUntilRest(20, 1 / 1500);
      entry.final = sim.balls.map((b) => ({ id: b.id, x: b.x, z: b.z, pocketed: b.pocketed }));
      entry.events = sim.events.length;
    }
    out.demos.push(entry);
  }
}
// cú đơn có xoáy/massé để so engine
const cases = [
  { dir: 0.3, speed: 2.5, a: 0.4, b: -0.3, elev: 0, sq: 0.02 },
  { dir: 2.1, speed: 4.0, a: -0.5, b: 0.5, elev: 0, sq: 0.02 },
  { dir: -1.0, speed: 1.5, a: 0.2, b: -0.5, elev: 0.35, sq: 0.02 },
  { dir: 0.785, speed: 6.0, a: 0, b: 0, elev: 0, sq: 0 },
];
for (const c of cases) {
  const sim = new Simulation([new Ball(0, -0.4, 0.1), new Ball(1, 0.3, 0.25), new Ball(2, 0.6, -0.2)]);
  sim.strike(0, c.dir, c.speed, c.a, c.b, c.elev, c.sq);
  sim.runUntilRest(20);
  out.shots.push({ ...c, final: sim.balls.map((b) => ({ id: b.id, x: b.x, z: b.z, pocketed: b.pocketed, q: b.q })), events: sim.events.length });
}
console.log(JSON.stringify(out));
