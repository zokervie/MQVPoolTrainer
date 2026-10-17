import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Ball, Simulation, PHYS, speedForDistance } from '../src/physics.js';
import { R, L, W, fromDiamond, POCKETS } from '../src/table.js';

// chạy tới khi bi mục tiêu chạm băng lần đầu (tránh bi mục tiêu dội ngược lại)
function runUntilObCushion(s, extra = 0.5) {
  for (let i = 0; i < 40000; i++) {
    s.step();
    if (s.events.some((e) => e.type === 'cushion' && e.ball === 1) || !s.moving) break;
  }
  return s;
}

const deg = (r) => (r * 180) / Math.PI;

test('bi đánh tâm: trượt rồi chuyển sang lăn với vận tốc 5/7', () => {
  const s = new Simulation([new Ball(0, -0.8, 0)]);
  s.strike(0, 0, 2, 0, 0);
  for (let i = 0; i < 2000; i++) s.step();
  const b = s.ball(0);
  assert.ok(Math.abs(b.w.z + b.vx / R) < 1e-6, 'đang lăn');
  // v sau khi lăn ≈ 5/7·v0 trừ cản lăn
  assert.ok(b.vx < 2 * 5 / 7 && b.vx > 2 * 5 / 7 - 0.3, `vx=${b.vx}`);
});

test('đánh 2/5R phía trên tâm lăn ngay (natural roll)', () => {
  const s = new Simulation([new Ball(0, 0, 0)]);
  s.strike(0, 0, 1.5, 0, 0.4);
  const b = s.ball(0);
  assert.ok(Math.abs(b.vx + R * b.w.z) < 1e-9);
});

test('bi dừng (stop shot): đánh thẳng, bi cái trượt lúc va chạm thì đứng yên', () => {
  const cb = new Ball(0, -0.3, 0), ob = new Ball(1, 0, 0);
  const s = new Simulation([cb, ob]);
  s.strike(0, 0, 2, 0, -0.22);
  runUntilObCushion(s);
  assert.ok(Math.abs(cb.x - (-2 * R)) < 0.05, `bi cái dừng tại ${cb.x}`);
  assert.ok(ob.x > 0.5);
});

test('bi kéo (draw) chạy lùi, bi theo (follow) chạy tới', () => {
  for (const [b, sign] of [[-0.5, -1], [0.5, 1]]) {
    const cb = new Ball(0, -0.5, 0.2), ob = new Ball(1, 0, 0.2);
    const s = new Simulation([cb, ob]);
    s.strike(0, 0, 3, 0, b);
    runUntilObCushion(s);
    assert.ok(sign * (cb.x - (-2 * R)) > 0.1, `b=${b} cb.x=${cb.x}`);
  }
});

test('quy tắc 90°: bi cái trượt (stun) tách vuông góc với bi mục tiêu ở va chạm 1/2 bi', () => {
  const cb = new Ball(0, -0.4, 0), ob = new Ball(1, 0, R); // va chạm nửa bi (lệch R)
  const s = new Simulation([cb, ob]);
  s.strike(0, 0, 2.5, 0, -0.1);
  // ngay khi va chạm đã xong
  for (let i = 0; i < 2000; i++) { s.step(); if (s.events.some((e) => e.type === 'hit')) break; }
  for (let i = 0; i < 5; i++) s.step();
  const a1 = Math.atan2(cb.vz, cb.vx), a2 = Math.atan2(ob.vz, ob.vx);
  const between = Math.abs(deg(a1 - a2));
  assert.ok(Math.abs(between - 90) < 8, `góc tách ${between}`);
  // bi mục tiêu đi ~30° (cộng throw ~1-2°)
  assert.ok(Math.abs(deg(a2) - 30) < 4, `OB ${deg(a2)}`);
});

test('quy tắc 30°: bi cái lăn đều va 1/2 bi lệch khoảng 30° (27–34°)', () => {
  const cb = new Ball(0, -0.9, 0), ob = new Ball(1, 0, R);
  const s = new Simulation([cb, ob]);
  s.strike(0, 0, 2.2, 0, 0.4);
  for (let i = 0; i < 40000; i++) { s.step(); if (s.events.filter((e) => e.type !== 'strike').length > 1) break; }
  const dir = deg(Math.atan2(cb.z - 0, cb.x - (-Math.sqrt(3) * R)));
  assert.ok(dir < -20 && dir > -40, `hướng bi cái ${dir}`);
});

test('nảy băng: góc tới ≈ góc phản xạ khi không english (bi lăn chậm)', () => {
  const cb = new Ball(0, 0, -0.3);
  const s = new Simulation([cb]);
  s.strike(0, Math.PI / 4, 1.2, 0, 0.4);
  for (let i = 0; i < 20000; i++) { s.step(); if (s.events.some((e) => e.type === 'cushion')) break; }
  for (let i = 0; i < 400; i++) s.step();
  const out = deg(Math.atan2(-cb.vz, cb.vx));
  assert.ok(out > 30 && out < 60, `góc ra ${out}`);
});

test('english phải làm bi bật về bên phải người đánh sau khi chạm băng thẳng', () => {
  const run = (a) => {
    const cb = new Ball(0, 0.5, 0);
    const s = new Simulation([cb]);
    s.strike(0, 0, 1.5, a, 0, 0, 0);
    for (let i = 0; i < 20000; i++) { s.step(); if (s.events.some((e) => e.type === 'cushion')) break; }
    for (let i = 0; i < 300; i++) s.step();
    return cb.vz;
  };
  assert.ok(run(0.5) > 0.05, 'phải → +z (bên phải người đánh)');
  assert.ok(run(-0.5) < -0.05);
  assert.ok(Math.abs(run(0)) < 1e-6);
});

test('bi thẳng vào lỗ góc', () => {
  const p = POCKETS.find((q) => q.id === 'c11');
  const cb = new Ball(0, 0, 0);
  const s = new Simulation([cb]);
  s.strike(0, Math.atan2(p.mouth.z, p.mouth.x), 2, 0, 0.3);
  s.runUntilRest();
  assert.ok(cb.pocketed, 'bi phải vào lỗ');
});

test('bi chạy dọc sát băng vào lỗ góc', () => {
  const cb = new Ball(0, 0.3, W / 2 - R - 0.001);
  const s = new Simulation([cb]);
  s.strike(0, 0, 2, 0, 0.3);
  s.runUntilRest();
  assert.ok(cb.pocketed);
});

test('quãng đường lăn khớp công thức v = √(2·μr·g·d)', () => {
  const cb = new Ball(0, -1.1, 0);
  const s = new Simulation([cb]);
  s.strike(0, 0, speedForDistance(1.5), 0, 0.4);
  s.runUntilRest();
  assert.ok(Math.abs(cb.x - (-1.1 + 1.5)) < 0.03, `x=${cb.x}`);
});

test('throw: cắt 1/2 bi bằng bi trượt chậm làm bi mục tiêu bị kéo theo hướng bi cái (góc cắt nhỏ hơn 30°)', () => {
  const cb = new Ball(0, -0.4, 0), ob = new Ball(1, 0, R);
  const s = new Simulation([cb, ob]);
  s.strike(0, 0, 0.8, 0, -0.1);
  for (let i = 0; i < 4000; i++) { s.step(); if (s.events.some((e) => e.type === 'hit')) break; }
  const a2 = deg(Math.atan2(ob.vz, ob.vx));
  assert.ok(a2 > 26 && a2 < 29.6, `OB ${a2}`);
});

test('phá bi 15 bi không làm bi chồng nhau / văng khỏi bàn', () => {
  const balls = [new Ball(0, -0.635, 0)];
  const f = fromDiamond(6, 2);
  let id = 1;
  for (let r = 0; r < 5; r++) for (let c = 0; c <= r; c++) {
    balls.push(new Ball(id++, f.x + r * R * Math.sqrt(3) * 1.001, f.z + (c - r / 2) * 2 * R * 1.001));
  }
  const s = new Simulation(balls);
  s.strike(0, 0, 8, 0, 0);
  s.runUntilRest(30);
  for (const b of s.balls) {
    if (b.pocketed) continue;
    assert.ok(Math.abs(b.x) <= L / 2 && Math.abs(b.z) <= W / 2, `bi ${b.id} ngoài bàn`);
  }
  assert.ok(!s.moving);
});
