import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DRILLS, buildStage, solveHint, evaluate, stageCount } from '../src/drills.js';
import { Ball, Simulation } from '../src/physics.js';

/** Mô phỏng cú gợi ý; trả về độ lệch góc nhỏ nhất (độ) quanh hướng gợi ý cho kết quả thành công. */
export function findWorkingOffset(st, maxDeg = 2, step = 0.05) {
  const pos = (id) => st.balls.find((b) => b.id === id);
  const h = solveHint(st.hint, st.cue, pos);
  if (!h) return { off: null };
  const tryDir = (dir) => {
    const sim = new Simulation([new Ball(0, st.cue.x, st.cue.z), ...st.balls.map((b) => new Ball(b.id, b.x, b.z))]);
    sim.trackRotation = false;
    sim.strike(0, dir, st.demo.speed, st.demo.spin[0], st.demo.spin[1], 0, 0.02);
    sim.runUntilRest(25);
    return evaluate(st, sim.events, sim.balls, {});
  };
  const r0 = tryDir(h.dir);
  if (r0.ok) return { off: 0, msg: r0.msg };
  for (let k = 1; k * step <= maxDeg; k++) for (const s of [1, -1]) {
    const r = tryDir(h.dir + (s * k * step * Math.PI) / 180);
    if (r.ok) return { off: s * k * step, first: r0.msg };
  }
  return { off: null, first: r0.msg };
}

for (const dr of DRILLS) {
  for (let i = 0; i < stageCount(dr); i++) {
    const st = buildStage(dr, i, 12345);
    if (!st.demo || st.goal.clear) continue;
    test(`${dr.id} chặng ${i + 1}: cú gợi ý khả thi theo vật lý`, () => {
      const isSys = dr.cat === 'sys';
      const r = findWorkingOffset(st, isSys ? 3 : 1.5);
      if (process.env.VERBOSE) console.log(dr.id, i + 1, r);
      assert.ok(r.off !== null, `không có hướng nào thành công (${r.first})`);
      assert.ok(Math.abs(r.off) <= (isSys ? 3 : 1.0), `lệch ${r.off}°`);
    });
  }
}
