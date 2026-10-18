// Thư viện bài tập + hệ thống nút số. Mỗi bài có công thức/giải thích hiển thị TRƯỚC khi tập.
import { R, L, W, fromDiamond, POCKETS } from './table.js';
import {
  ghostBall, pocketAimPoint, pocketById, placeForCut, mirrorPoint, mirrorContact, cornerReflect,
  corner5Solve, railPoint,
} from './systems.js';

const d = (dx, dz) => fromDiamond(dx, dz);
const B = (id, dx, dz) => ({ id, ...d(dx, dz) });
const Bm = (id, p) => ({ id, x: p.x, z: p.z });
const rad = (deg) => (deg * Math.PI) / 180;

// Lỗ: góc trên phải = c1-1, góc trên trái = c-1-1, góc dưới phải = c11, góc dưới trái = c-11, giữa trên = s-1, giữa dưới = s1
export const POCKET_IDS = { TR: 'c1-1', TL: 'c-1-1', BR: 'c11', BL: 'c-11', ST: 's-1', SB: 's1' };

export const CATEGORIES = [
  { id: 'aim', title: 'Ngắm bi & góc cắt', icon: '🎯', desc: 'Bi ma, độ chồng bi, góc cắt, bi sát băng' },
  { id: 'cue', title: 'Điều bi cái', icon: '🎱', desc: 'Dừng, kéo, theo, quy tắc 90°/30°, lực, chạy vị trí' },
  { id: 'sys', title: 'Hệ thống nút số', icon: '💎', desc: 'Gương, chia đôi, bank, phản chiếu góc, Corner-5' },
  { id: 'game', title: 'Vào trận', icon: '🏆', desc: 'Phá bi, dọn bàn theo mẫu' },
];

// ---------- tiện ích dựng tình huống ----------
function cutStage({ ob, pocket, angle, dist, side = 1, spin = [0, 0.2], speed = 2.2, extra = [], zone = null }) {
  const p = pocketById(pocket);
  const tgt = pocketAimPoint(p);
  const cue = placeForCut(ob, tgt, angle, dist, side);
  return {
    cue, balls: [Bm(1, ob), ...extra],
    goal: { pot: [1], ...(zone ? { cueZone: zone(cue, ob, tgt) } : {}) },
    hint: { type: 'ghost', ball: 1, pocket }, demo: { spin, speed },
  };
}

/** Vùng dừng theo đường tiếp tuyến (quy tắc 90°) hoặc lệch 30° (bi lăn). */
function deflectZone(kind, dist, r = 0.13) {
  return (cue, ob, tgt) => {
    const g = ghostBall(ob, tgt);
    const ix = g.x - cue.x, iz = g.z - cue.z, im = Math.hypot(ix, iz);
    const ux = ix / im, uz = iz / im;
    const nx = (ob.x - g.x) / (2 * R), nz = (ob.z - g.z) / (2 * R);
    const dn = ux * nx + uz * nz;
    let tx = ux - dn * nx, tz = uz - dn * nz; const tm = Math.hypot(tx, tz); tx /= tm; tz /= tm;
    let ox, oz;
    if (kind === 'tangent') { ox = tx; oz = tz; } else {
      // xoay hướng tới về phía tiếp tuyến 30°
      const s = Math.sign(ux * tz - uz * tx), a = rad(30) * s;
      ox = ux * Math.cos(a) - uz * Math.sin(a); oz = ux * Math.sin(a) + uz * Math.cos(a);
    }
    return { x: g.x + ox * dist, z: g.z + oz * dist, r };
  };
}

const lineAt = (a, b, t) => ({ x: a.x + (b.x - a.x) * t, z: a.z + (b.z - a.z) * t });

function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }

// ---------- danh sách bài ----------
const F = {
  ghost: `<div class="formula">G = O − 2R · û</div>
    <p>O: tâm bi mục tiêu · û: hướng từ bi mục tiêu tới lỗ · R: bán kính bi (28,6 mm). Nhắm tâm bi cái vào bi ma G.</p>`,
  fraction: `<div class="formula">sin θ = 1 − f</div>
    <table class="ftable"><tr><th>Độ chồng f</th><td>Đầy</td><td>¾</td><td>½</td><td>¼</td><td>⅛</td></tr>
    <tr><th>Góc cắt θ</th><td>0°</td><td>14,5°</td><td>30°</td><td>48,6°</td><td>61°</td></tr></table>`,
  slide: `<div class="formula">d<sub>trượt</sub> = 12·v₀² / (49·μ·g)</div>
    <p>Đánh tâm, bi cái trượt hết quãng d<sub>trượt</sub> rồi mới lăn (μ ≈ 0,2 ⇒ v₀ = 2 m/s trượt ~0,5 m). Đánh dưới tâm để kéo dài giai đoạn trượt; bi cái chỉ DỪNG khi lúc chạm còn trượt thuần (không xoáy tới/lui).</p>`,
  rule90: `<div class="formula">Bi cái trượt (stun) ⇒ góc tách = 90°</div>
    <p>Bi cái đi theo <b>đường tiếp tuyến</b>, vuông góc với hướng bi mục tiêu. Xoáy theo đẩy bi cái ra phía trước tiếp tuyến, xoáy kéo đưa về phía sau.</p>`,
  rule30: `<div class="formula">Bi lăn đều + va ½ bi ⇒ bi cái lệch ≈ 30°</div>
    <p>Đúng cho dải độ chồng ¼ → ¾ (27°–34°). Mẹo tay chữ V: ngón trỏ chỉ hướng bi ma, ngón giữa mở ~30° là hướng bi cái.</p>`,
  speed: `<div class="formula">v = √(2 · μ<sub>lăn</sub> · g · d)</div>
    <p>μ<sub>lăn</sub> ≈ 0,011 ⇒ muốn bi lăn d = 4 m cần v ≈ 0,93 m/s (≈ 3,3 km/h). Mỗi lần chạm băng mất ~20–30% tốc độ. Quãng đường tỉ lệ với <b>bình phương</b> tốc độ: gấp đôi lực ⇒ đi xa gấp bốn.</p>`,
  mirror: `<div class="formula">x<sub>c</sub> = (x₁·d₂ + x₂·d₁) / (d₁ + d₂)</div>
    <p>Phản chiếu bi mục tiêu qua băng (đường tâm bi cách mũi băng 1R) rồi nhắm thẳng ảnh đó. x₁, x₂: vị trí theo nút của bi cái và bi mục tiêu; d₁, d₂: khoảng cách của chúng tới băng.</p>`,
  equal: `<div class="formula">d₁ = d₂ ⇒ x<sub>c</sub> = (x₁ + x₂) / 2</div>
    <p>Hai bi cách băng bằng nhau thì điểm chạm băng nằm chính giữa (theo số nút). Bi lăn mạnh, có xoáy theo sẽ nảy "dài" hơn một chút.</p>`,
  bank: `<div class="formula">P' = ảnh gương của lỗ qua băng · G = O − 2R·û(P' − O)</div>
    <p>Bi mục tiêu đi tới ảnh P' của lỗ. Thực tế cú bank bi cắt / đánh mạnh thường bị "ngắn" (góc nảy hẹp) – nhắm dài hơn một chút hoặc đánh chậm hơn.</p>`,
  corner: `<div class="formula">T' = 2C − T</div>
    <p>Đánh 2 băng kề nhau (qua một góc bàn): đường ra <b>song song</b> đường vào. C là góc của hình chữ nhật tâm bi (cách mũi băng 1R). Nhắm vào ảnh đối xứng tâm T' của bi mục tiêu qua C.</p>`,
  corner5: `<div class="formula">T = D − F</div>
    <p><b>D</b> (số xuất phát, vàng): góc dưới-trái = 5; +1 mỗi nút đi lên băng ngắn trái; −½ mỗi nút đi sang phải trên băng dưới.
    <b>F</b> (băng 1, xanh) và <b>T</b> (băng 3, hồng): số 1 ở nút đầu tiên tính từ băng ngắn bên phải.
    Đường chuẩn <b>5 − 3 = 2</b>. Chỉ đúng cho bi cái lăn, lực vừa, có <b>english xuôi</b> (running english). Xoay cơ quanh bi cái tới khi D − F bằng số T cần.</p>`,
};

export const DRILLS = [
  // ===== NGẮM =====
  {
    id: 'a-straight', cat: 'aim', level: 1, title: 'Bi thẳng – đánh dừng',
    summary: 'Ăn bi thẳng vào lỗ góc và giữ bi cái dừng tại chỗ.',
    formula: F.ghost + F.slide,
    steps: ['Xếp bi cái, bi mục tiêu và lỗ thẳng hàng.', 'Đặt điểm đánh hơi dưới tâm (≈ −0,2R).', 'Lực vừa, ra cơ thẳng, giữ yên người sau cú đánh.'],
    tips: ['Nếu bi cái lăn theo: hạ điểm đánh hoặc tăng lực.', 'Nếu bi cái lùi: nâng điểm đánh hoặc giảm lực.'],
    video: 'stop shot drill pool lesson',
    stages: [{
      cue: d(4, 2), balls: [B(1, 6, 3)],
      goal: { pot: [1], cueZone: { ...d(5.92, 2.96), r: 0.09 } },
      hint: { type: 'ghost', ball: 1, pocket: POCKET_IDS.TR }, demo: { spin: [0, -0.25], speed: 1.2 },
    }],
  },
  {
    id: 'a-long', cat: 'aim', level: 2, title: 'Bi dài dọc bàn',
    summary: 'Cú thẳng dài gần hết chiều dài bàn – kiểm tra độ thẳng của cú ra cơ.',
    formula: F.ghost + `<p>Sai số góc ε (rad) ở bi cái lệch điểm chạm một đoạn ≈ D·ε. Với D = 2 m, lệch 0,5° ⇒ ~1,7 cm – đủ trượt lỗ.</p>`,
    steps: ['Nhìn bi mục tiêu ở cuối cú ra cơ.', 'Đánh tâm hoặc hơi trên tâm, lực vừa.'],
    tips: ['Dùng phím Khoá cơ khi đã ngắm xong để tay còn lại chỉ tập trung vào lực.'],
    video: 'long straight in shot drill pool',
    stages: [{
      cue: d(1, 0.5), balls: [B(1, 7, 3.5)], goal: { pot: [1] },
      hint: { type: 'ghost', ball: 1, pocket: POCKET_IDS.TR }, demo: { spin: [0, 0.2], speed: 2.6 },
    }],
  },
  {
    id: 'a-half', cat: 'aim', level: 1, title: 'Cắt ½ bi (30°)',
    summary: 'Góc cắt chuẩn 30°: mép bi cái nhắm vào tâm bi mục tiêu.',
    formula: F.fraction + F.ghost,
    steps: ['Ngắm mép bi cái vào tâm bi mục tiêu (độ chồng ½).', 'Lực vừa, đánh hơi trên tâm.'],
    tips: ['Bi cái chậm và trượt sẽ "kéo" (throw) bi mục tiêu về phía đường đi bi cái ~1–2°: cắt dày hơn chút.'],
    video: 'half ball hit aiming pool fractional aiming',
    stages: [cutStage({ ob: d(6, 3), pocket: POCKET_IDS.TR, angle: 30, dist: 0.6, side: 1 })],
  },
  {
    id: 'a-ladder', cat: 'aim', level: 2, title: 'Thang độ chồng ¾ – ½ – ¼ – ⅛',
    summary: '4 cú cắt liên tiếp với 4 độ chồng chuẩn.',
    formula: F.fraction + F.ghost,
    steps: ['Mỗi chặng ước lượng độ chồng trước, rồi mới bật hỗ trợ ngắm để kiểm tra.', 'Hoàn thành cả 4 chặng.'],
    tips: ['Cắt mỏng (⅛) cần lực mạnh hơn vì bi mục tiêu nhận ít năng lượng: v<sub>OB</sub> = v·cosθ.'],
    video: 'fractional ball aiming system pool',
    stages: [14.5, 30, 48.6, 61].map((a, i) => cutStage({ ob: d(5.6, 3.1), pocket: POCKET_IDS.TR, angle: a, dist: 0.55, side: i % 2 ? -1 : 1, speed: 2 + i * 0.3 })),
  },
  {
    id: 'a-random', cat: 'aim', level: 2, title: 'Bi ma ngẫu nhiên',
    summary: 'Mỗi lần một thế bi mới. Ước lượng góc cắt bằng mắt.',
    formula: F.ghost + F.fraction,
    steps: ['Tắt hỗ trợ ngắm để tự ước lượng, bật lại để kiểm tra.', 'Ăn 10 bi, xem tỉ lệ thành công.'],
    tips: ['Đứng sau đường bi mục tiêu → lỗ để "thấy" bi ma, rồi mới vào tư thế.'],
    video: 'ghost ball aiming method pool',
    generate(seed) {
      const r = rng(seed);
      const ids = Object.values(POCKET_IDS);
      for (let k = 0; k < 200; k++) {
        const ob = d(1.5 + r() * 5, 0.8 + r() * 2.4);
        const pocket = ids[Math.floor(r() * ids.length)];
        const angle = r() * 55, dist = 0.35 + r() * 0.8, side = r() < 0.5 ? -1 : 1;
        const st = cutStage({ ob, pocket, angle, dist, side, speed: 2.2 });
        const c = st.cue;
        const p = pocketById(pocket);
        const dirIn = Math.atan2(p.mouth.z - ob.z, p.mouth.x - ob.x);
        const toP = Math.hypot(p.mouth.x - ob.x, p.mouth.z - ob.z);
        if (p.kind === 'side' && Math.abs(Math.sin(dirIn)) < 0.6) continue; // góc vào lỗ giữa quá hẹp
        if (toP < 0.25) continue;
        if (Math.abs(c.x) < L / 2 - 0.08 && Math.abs(c.z) < W / 2 - 0.08) return st;
      }
      return cutStage({ ob: d(6, 3), pocket: POCKET_IDS.TR, angle: 20, dist: 0.6 });
    },
  },
  {
    id: 'a-rail', cat: 'aim', level: 2, title: 'Bi sát băng',
    summary: 'Bi mục tiêu dính băng trên, ăn vào lỗ góc dọc theo băng.',
    formula: F.ghost + `<p>Bi dính băng: điểm tiếp xúc nằm trên đường song song băng. Có thể nhắm cho bi cái chạm băng và bi mục tiêu <b>cùng lúc</b>. Thêm một chút english phía băng (english xuôi) để giảm throw.</p>`,
    steps: ['Ngắm bi ma nằm sát băng.', 'Lực vừa – mạnh quá bi dễ nảy ra ở hàm lỗ.'],
    tips: ['Bi chạm hàm lỗ khi tới quá lệch: lỗ góc "hiệu dụng" hẹp lại theo góc tới.'],
    video: 'frozen rail cut shot technique pool',
    stages: [{
      cue: d(4, 2.2), balls: [Bm(1, { x: d(6.5, 4).x, z: -W / 2 + R + 0.001 })], goal: { pot: [1] },
      hint: { type: 'ghost', ball: 1, pocket: POCKET_IDS.TR }, demo: { spin: [0, 0.1], speed: 1.8 },
    }],
  },
  {
    id: 'a-side', cat: 'aim', level: 2, title: 'Cắt vào lỗ giữa',
    summary: 'Lỗ giữa nhận bi tốt khi góc tới gần vuông góc, khó dần khi bi đi chéo.',
    formula: F.ghost + `<p>Góc tới lỗ giữa (so với pháp tuyến băng) nên ≤ ~40°. Lớn hơn, cửa lỗ hiệu dụng ≈ miệng·cos(α) thu hẹp nhanh.</p>`,
    steps: ['Ngắm bi ma theo đường bi mục tiêu → giữa miệng lỗ.', 'Lực nhẹ – vừa.'],
    tips: ['Đánh nhẹ thì lỗ "rộng" hơn: bi chậm ít bị hàm lỗ đẩy ra.'],
    video: 'side pocket cut shot pool',
    stages: [cutStage({ ob: d(3.4, 3.2), pocket: POCKET_IDS.ST, angle: 25, dist: 0.55, side: -1, speed: 1.6 })],
  },

  // ===== ĐIỀU BI CÁI =====
  {
    id: 'c-stop', cat: 'cue', level: 1, title: 'Thang bi dừng (1 → 4 nút)',
    summary: 'Bi dừng ở 4 khoảng cách tăng dần – hạ điểm đánh khi xa hơn.',
    formula: F.slide,
    steps: ['Mỗi chặng xa thêm 1 nút.', 'Bi cái phải dừng trong vòng tròn vàng.'],
    tips: ['Khoảng cách càng xa, xoáy kéo càng bị vải "ăn" bớt: cần điểm đánh thấp hơn và lực mạnh hơn.'],
    video: 'stop shot ladder drill pool',
    stages: [1, 2, 3, 4].map((k) => ({
      cue: d(6 - k, 3 - k / 2), balls: [B(1, 6, 3)],
      goal: { pot: [1], cueZone: { ...d(5.9, 2.95), r: 0.12 } },
      hint: { type: 'ghost', ball: 1, pocket: POCKET_IDS.TR },
      demo: { spin: [0, [-0.12, -0.25, -0.36, -0.45][k - 1]], speed: [1.7, 2.1, 2.5, 2.9][k - 1] },
    })),
  },
  {
    id: 'c-draw', cat: 'cue', level: 2, title: 'Kéo bi về vùng',
    summary: 'Ăn bi thẳng và kéo bi cái lùi về vòng tròn.',
    formula: `<div class="formula">ω·R / v > 1 lúc chạm ⇒ bi cái lùi</div>
      <p>Điểm đánh b (theo R) tạo xoáy ω = 5·v·b / (2R). Đánh −0,5R ⇒ ωR/v = 1,25 ban đầu; vải làm xoáy giảm dần trên đường đi, nên bi càng xa càng phải kéo thấp/mạnh.</p>`,
    steps: ['Điểm đánh −0,4R đến −0,6R.', 'Ra cơ dài, đều, không "giật".'],
    tips: ['Kéo quá 0,6R dễ trượt cơ (miscue).'],
    video: 'draw shot technique pool lesson',
    stages: [{
      cue: d(4.5, 2.25), balls: [B(1, 6, 3)],
      goal: { pot: [1], cueZone: { ...d(3.4, 1.7), r: 0.15 } },
      hint: { type: 'ghost', ball: 1, pocket: POCKET_IDS.TR }, demo: { spin: [0, -0.5], speed: 2.3 },
    }],
  },
  {
    id: 'c-follow', cat: 'cue', level: 1, title: 'Theo bi vừa đủ',
    summary: 'Ăn bi thẳng, bi cái theo tới vòng tròn nhưng không rơi lỗ.',
    formula: `<div class="formula">b = 0,4R ⇒ lăn đều ngay (ω·R = v)</div>
      <p>Bi lăn đều khi chạm thẳng sẽ truyền gần hết vận tốc rồi bị xoáy tới kéo đi theo ≈ 2/7 vận tốc ban đầu.</p>`,
    steps: ['Điểm đánh +0,3R đến +0,4R.', 'Lực nhẹ – vừa, đủ cho bi cái theo ~½ nút.'],
    tips: ['Theo bi luôn xảy ra khi bi cái lăn: chỉ cần chỉnh lực để kiểm soát quãng đường.'],
    video: 'follow shot drill pool',
    stages: [{
      cue: d(3.6, 1.8), balls: [B(1, 6, 3)],
      goal: { pot: [1], cueZone: { ...d(6.55, 3.27), r: 0.11 } },
      hint: { type: 'ghost', ball: 1, pocket: POCKET_IDS.TR }, demo: { spin: [0, 0.2], speed: 1.0 },
    }],
  },
  {
    id: 'c-90', cat: 'cue', level: 2, title: 'Quy tắc 90° (bi trượt)',
    summary: 'Cắt ½ bi với bi cái trượt, bi cái đi theo đường tiếp tuyến vào vòng tròn.',
    formula: F.rule90 + F.fraction,
    steps: ['Đánh tâm/hơi dưới tâm để bi cái còn trượt khi chạm.', 'Lực vừa.'],
    tips: ['Muốn bi cái chạy đúng tiếp tuyến ở cú xa: hạ điểm đánh nhiều hơn.'],
    video: '90 degree rule pool stun shot',
    stages: [cutStage({ ob: d(6, 3), pocket: POCKET_IDS.TR, angle: 30, dist: 0.5, side: 1, spin: [0, -0.5], speed: 1.6, zone: deflectZone('tangent', 0.42) })],
  },
  {
    id: 'c-30', cat: 'cue', level: 2, title: 'Quy tắc 30° (bi lăn)',
    summary: 'Cắt ½ bi với bi cái lăn đều, bi cái lệch ~30° vào vòng tròn.',
    formula: F.rule30,
    steps: ['Đánh tâm hoặc hơi trên tâm, lực nhẹ để bi cái lăn đều trước khi chạm.', 'Chạm ½ bi.'],
    tips: ['Cú cắt mỏng/dày hơn ½ bi thì góc lệch vẫn gần 30° nhưng quãng đi thay đổi.'],
    video: '30 degree rule pool peace sign',
    stages: [cutStage({ ob: d(6, 3), pocket: POCKET_IDS.TR, angle: 30, dist: 0.7, side: -1, spin: [0, 0.05], speed: 1.0, zone: deflectZone('roll', 0.3, 0.15) })],
  },
  {
    id: 'c-lag', cat: 'cue', level: 1, title: 'Kiểm soát lực – Lag',
    summary: 'Đánh bi cái lên băng cuối bàn và về dừng gần băng đầu bàn.',
    formula: F.speed,
    steps: ['Đánh tâm/hơi trên tâm, hướng thẳng.', 'Bi cái phải chạm băng xa rồi dừng trong vòng tròn.'],
    tips: ['Quãng đường ≈ 2 chiều dài bàn ~4,5 m ⇒ v ≈ 1,0 m/s, cộng phần mất ở băng ⇒ ~1,4 m/s.'],
    video: 'lag shot speed control drill pool',
    stages: [{
      cue: d(1, 2), balls: [], aim: 0,
      goal: { cueZone: { ...d(0.6, 2), r: 0.16 }, minRails: 1 },
      hint: { type: 'dir', dir: 0 }, demo: { spin: [0, 0.3], speed: 1.4 },
    }],
  },
  {
    id: 'c-two', cat: 'cue', level: 2, title: 'Chạy vị trí 2 bi',
    summary: 'Ăn bi 1 rồi bi 2 trong 2 cú, phải để vị trí sau cú đầu.',
    formula: F.rule30 + F.rule90,
    steps: ['Trước khi đánh bi 1, chọn vùng đặt bi cái cho bi 2.', 'Dùng quy tắc 90°/30° để dự đoán đường bi cái.'],
    tips: ['Chọn góc cắt "đúng phía" cho bi sau – đừng để bi thẳng tuyệt đối.'],
    video: 'pool position play drill two balls',
    stages: [{
      cue: d(4.2, 1.8), balls: [B(1, 6, 3), B(2, 2.4, 3.2)],
      goal: { clear: [1, 2], maxShots: 2 },
      hint: { type: 'ghost', ball: 1, pocket: POCKET_IDS.TR }, demo: { spin: [0, -0.3], speed: 2.4 },
    }],
  },
  {
    id: 'c-line', cat: 'cue', level: 3, title: 'Line-up 6 bi',
    summary: '6 bi trên đường giữa bàn. Bi trong tay ở cú đầu, dọn sạch không trượt.',
    formula: F.rule90 + F.rule30,
    steps: ['Dọn theo thứ tự tuỳ ý.', 'Không được trượt bi nào.'],
    tips: ['Ưu tiên giữ góc cắt nhỏ, di chuyển bi cái ngắn.'],
    video: 'line up drill pool practice',
    stages: [{
      cue: d(1.3, 1.4), ballInHand: true,
      balls: [2.4, 3.1, 3.8, 4.5, 5.2, 5.9].map((x, i) => B(i + 1, x, 2)),
      goal: { clear: [1, 2, 3, 4, 5, 6], maxMisses: 0 },
      hint: { type: 'ghost', ball: 1, pocket: POCKET_IDS.TL },
    }],
  },
  {
    id: 'c-x', cat: 'cue', level: 3, title: 'Mighty X',
    summary: '8 bi trên hai đường chéo. Dọn sạch, tối đa 2 cú trượt.',
    formula: F.rule90 + F.rule30,
    steps: ['Bi trong tay ở cú đầu.', 'Dọn sạch, trượt quá 2 lần là hỏng.'],
    tips: ['Bi gần lỗ trước để mở đường cho bi ở giữa.'],
    video: 'mighty x drill pool',
    stages: [{
      cue: d(4, 2.8), ballInHand: true,
      balls: [[2.4, 1.2], [3.2, 1.6], [4.8, 2.4], [5.6, 2.8], [2.4, 2.8], [3.2, 2.4], [4.8, 1.6], [5.6, 1.2]].map(([x, z], i) => B(i + 1, x, z)),
      goal: { clear: [1, 2, 3, 4, 5, 6, 7, 8], maxMisses: 2 },
      hint: { type: 'ghost', ball: 1, pocket: POCKET_IDS.BL },
    }],
  },

  // ===== HỆ THỐNG NÚT SỐ =====
  {
    id: 's-mirror', cat: 'sys', level: 2, title: 'Hệ thống Gương – kick 1 băng',
    summary: 'Bi chắn đường thẳng. Kick bi cái 1 băng (băng trên) chạm bi mục tiêu.',
    formula: F.mirror,
    steps: ['Ước lượng ảnh gương của bi 1 bên ngoài băng trên.', 'Đánh lực vừa, không english, bi cái hơi trượt (stun) để góc nảy đúng gương.'],
    tips: ['Bi lăn mạnh có xoáy theo nảy "dài"; english xuôi cũng làm dài góc. Bật hỗ trợ để thấy ảnh gương.'],
    video: 'mirror system kick shot pool',
    labels: 'std',
    stages: [{
      cue: d(2.5, 3.0), balls: [B(1, 5.5, 3.3), B(2, 4.0, 3.18)],
      goal: { firstHit: 1, minRails: 1 },
      hint: { type: 'mirror', rail: 'top', ball: 1 }, demo: { spin: [0, 0], speed: 1.8 },
    }, {
      cue: d(1.6, 2.4), balls: [B(1, 6.2, 3.2), B(2, 4.0, 2.85), B(3, 4.4, 3.0)],
      goal: { firstHit: 1, minRails: 1 },
      hint: { type: 'mirror', rail: 'top', ball: 1 }, demo: { spin: [0, 0], speed: 2.0 },
    }],
  },
  {
    id: 's-equal', cat: 'sys', level: 1, title: 'Chia đôi khoảng cách',
    summary: 'Hai bi cách băng bằng nhau: nhắm đúng nút chính giữa.',
    formula: F.equal + F.mirror,
    steps: ['Đọc số nút của bi cái (x₁) và bi mục tiêu (x₂).', 'Nhắm điểm (x₁ + x₂)/2 trên băng dưới.'],
    tips: ['Chặng 2 hai bi cách băng khác nhau: dùng công thức tổng quát.'],
    video: 'one rail kick system diamonds pool',
    labels: 'std',
    stages: [{
      cue: d(2, 1), balls: [B(1, 6, 1), B(2, 4, 1)],
      goal: { firstHit: 1, minRails: 1 },
      hint: { type: 'mirror', rail: 'bottom', ball: 1 }, demo: { spin: [0, 0], speed: 2.0 },
    }, {
      cue: d(1.5, 0.8), balls: [B(1, 6.5, 1.6), B(2, 4, 1.2)],
      goal: { firstHit: 1, minRails: 1 },
      hint: { type: 'mirror', rail: 'bottom', ball: 1 }, demo: { spin: [0, 0], speed: 2.2 },
    }],
  },
  {
    id: 's-bank', cat: 'sys', level: 3, title: 'Bank 1 băng vào lỗ giữa',
    summary: 'Đánh bi mục tiêu chạm băng trên rồi về lỗ giữa dưới (cross-side).',
    formula: F.bank,
    steps: ['Lấy ảnh gương của lỗ giữa dưới qua băng trên.', 'Cắt bi mục tiêu về phía ảnh đó.'],
    tips: ['Đánh vừa lực. Mạnh quá bi bank bị "ngắn" (góc nảy hẹp lại).'],
    video: 'cross side bank shot system pool',
    labels: 'std',
    stages: [{
      cue: null, balls: [B(1, 3.55, 2.6)],
      goal: { pot: [1], minRailsBall: 1 },
      hint: { type: 'bank', ball: 1, rail: 'top', pocket: POCKET_IDS.SB }, demo: { spin: [0, 0.3], speed: 1.5 },
      place: { cut: 12, dist: 0.5, side: -1 },
    }],
  },
  {
    id: 's-corner', cat: 'sys', level: 2, title: 'Phản chiếu qua góc – 2 băng',
    summary: 'Kick 2 băng (băng phải → băng trên) chạm bi mục tiêu bị che.',
    formula: F.corner,
    steps: ['Lấy ảnh đối xứng tâm của bi mục tiêu qua góc trên-phải.', 'Nhắm thẳng ảnh đó, lực vừa, không english.'],
    tips: ['Lực mạnh làm bi nảy "ngắn" hơn ở băng đầu; english xuôi làm dài góc.'],
    video: 'two rail kick system pool corner',
    labels: 'std',
    stages: [{
      cue: d(6.3, 1.2), balls: [B(1, 5.6, 3.2), B(2, 5.95, 2.2)],
      goal: { firstHit: 1, minRails: 2 },
      hint: { type: 'cornerReflect', corner: 'tr', ball: 1 }, demo: { spin: [0, 0], speed: 2.2 },
    }],
  },
  {
    id: 's-c5ref', cat: 'sys', level: 2, title: 'Corner-5: đường chuẩn 5-3-2',
    summary: 'Ghi nhớ đường chuẩn 5 − 3 = 2 của hệ thống 3 băng Corner-5.',
    formula: F.corner5,
    steps: ['Bi cái nằm trên đường từ góc (D = 5) tới nút F = 3 của băng trên.', 'Bi lăn, lực vừa, english xuôi (phải) ~0,3R.', 'Bi cái chạm 3 băng rồi trúng bi 1 ở nút T = 2.'],
    tips: ['Trên đa số bàn, đường 5-3-2 về hơi ngắn so với lý thuyết: hiệu chỉnh theo bàn bạn tập.'],
    video: 'corner 5 diamond system three rail kick',
    labels: 'corner5',
    stages: [{
      cue: lineAt(railPoint(0, 0), railPoint(5, 4), 0.2), balls: [B(1, 6.05, 0.22)],
      goal: { firstHit: 1, minRails: 3 },
      hint: { type: 'corner5', T: 2 }, demo: { spin: [0.3, 0.3], speed: 2.5 },
    }],
  },
  {
    id: 's-c5', cat: 'sys', level: 3, title: 'Corner-5: tính số nhắm',
    summary: 'Kick 3 băng trúng bi bị che hoàn toàn. Tự tính F = D − T.',
    formula: F.corner5,
    steps: ['Đọc số T nơi cần tới ở băng 3 (băng dưới).', 'Xoay cơ quanh bi cái tới khi D − F = T.', 'Bi lăn, english xuôi, lực vừa.'],
    tips: ['Bi xa băng: dịch đường 5-3-2 song song qua bi để ước lượng T cần.'],
    video: 'corner 5 system kick explained',
    labels: 'corner5',
    stages: [{
      cue: d(0.9, 0.9), balls: [B(1, 5.1, 0.25), B(2, 3.0, 0.6), B(3, 3.4, 0.35)],
      goal: { firstHit: 1, minRails: 3 },
      hint: { type: 'corner5', T: 3 }, demo: { spin: [0.3, 0.3], speed: 2.5 },
    }, {
      cue: d(1.4, 1.6), balls: [B(1, 6.6, 0.25), B(2, 4.0, 0.9)],
      goal: { firstHit: 1, minRails: 3 },
      hint: { type: 'corner5', T: 1.5 }, demo: { spin: [0.3, 0.3], speed: 2.5 },
    }],
  },

  // ===== VÀO TRẬN =====
  {
    id: 'g-break9', cat: 'game', level: 2, title: 'Phá bi 9 bi',
    summary: 'Phá bi 9 bi: phải có bi vào lỗ và bi cái không rơi.',
    formula: `<div class="formula">E = ½·m·v²</div><p>Phá bi cần tốc độ cao (7–9 m/s) nhưng bi cái phải chạm <b>đầy</b> bi số 1. Đánh hơi dưới tâm để bi cái dừng giữa bàn sau va chạm.</p>`,
    steps: ['Đặt bi cái gần băng đầu, hơi lệch tâm.', 'Kéo lùi tay đẩy thật dài rồi đẩy nhanh (lực mạnh nhất).'],
    tips: ['Chính xác quan trọng hơn sức mạnh: chạm lệch làm mất năng lượng.'],
    video: '9 ball break technique',
    stages: [{ rack: '9', cue: d(1.5, 2.6), ballInHand: true, goal: { potAny: true }, hint: { type: 'ghost', ball: 1, pocket: null }, demo: null }],
  },
  {
    id: 'g-run9', cat: 'game', level: 3, title: 'Dọn bàn 9 bi theo mẫu',
    summary: 'Thế bi cố định, dọn theo thứ tự 1 → 9, không trượt.',
    formula: F.rule90 + F.rule30,
    steps: ['Luôn chạm bi số nhỏ nhất trước.', 'Lên kế hoạch 3 bi trước.'],
    tips: ['Chọn góc cắt để bi cái đi theo hướng bi kế tiếp.'],
    video: '9 ball run out pattern play',
    stages: [{
      cue: d(2, 1), ballInHand: true,
      balls: [[3, 3.1], [5.5, 1.1], [6.8, 3.3], [4.6, 2.8], [1.6, 3.4], [2.6, 0.8], [5.2, 3.5], [7.1, 1.0], [4.0, 1.4]].map(([x, z], i) => B(i + 1, x, z)),
      goal: { clear: [1, 2, 3, 4, 5, 6, 7, 8, 9], ordered: true, maxMisses: 0 },
      hint: { type: 'ghost', ball: 1, pocket: null },
    }],
  },
];

export function drillById(id) { return DRILLS.find((x) => x.id === id); }

/** Dựng chặng: trả về {cue, balls, goal, hint, demo, ...} đã đủ toạ độ. */
export function buildStage(drill, idx, seed = Date.now()) {
  const st = drill.generate ? drill.generate(seed) : structuredClone(drill.stages[idx]);
  if (st.rack) st.balls = rackBalls(st.rack);
  if (!st.cue && st.place && st.hint.type === 'bank') {
    const ob = st.balls.find((b) => b.id === st.hint.ball);
    const img = bankImage(st.hint);
    st.cue = placeForCut(ob, img, st.place.cut, st.place.dist, st.place.side);
  }
  return st;
}

export function stageCount(drill) { return drill.generate ? 1 : drill.stages.length; }

function bankImage(h) {
  const p = pocketById(h.pocket);
  return mirrorPoint(pocketAimPoint(p), h.rail);
}

// ---------- Xếp bi ----------
export function rackBalls(kind) {
  const f = fromDiamond(6, 2);
  const dx = R * Math.sqrt(3) * 1.002, dz = 2 * R * 1.002;
  const pos = [];
  if (kind === '9') {
    const rows = [1, 2, 3, 2, 1];
    rows.forEach((n, r) => { for (let c = 0; c < n; c++) pos.push({ x: f.x + r * dx, z: f.z + (c - (n - 1) / 2) * dz }); });
    const order = [1, 2, 3, 4, 9, 5, 6, 7, 8]; // 1 ở đỉnh, 9 ở giữa
    return pos.map((p, i) => ({ id: order[i], ...p }));
  }
  for (let r = 0; r < 5; r++) for (let c = 0; c <= r; c++) pos.push({ x: f.x + r * dx, z: f.z + (c - r / 2) * dz });
  const ids = [1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15];
  return pos.map((p, i) => ({ id: ids[i], ...p }));
}

// ---------- Lời giải ngắm (dùng cho đường gợi ý, sơ đồ, kiểm tra tự động) ----------
/** balls: Map/obj id → {x,z} hiện tại; trả về {dir, lines:[[p,q,kind]], marks:[{p,kind,label}]} */
export function solveHint(hint, cue, ballPos) {
  if (!hint || !cue) return null;
  const bp = (id) => ballPos(id);
  if (hint.type === 'dir') return { dir: hint.dir, lines: [], marks: [] };
  if (hint.type === 'ghost') {
    const ob = bp(hint.ball);
    if (!ob) return null;
    let pocket = hint.pocket ? pocketById(hint.pocket) : bestPocket(cue, ob);
    if (!pocket) return null;
    const tgt = pocketAimPoint(pocket);
    const g = ghostBall(ob, tgt);
    return {
      dir: Math.atan2(g.z - cue.z, g.x - cue.x),
      lines: [[cue, g, 'cue'], [ob, tgt, 'ob']], marks: [{ p: g, kind: 'ghost' }],
    };
  }
  if (hint.type === 'mirror') {
    const ob = bp(hint.ball);
    const img = mirrorPoint(ob, hint.rail);
    const c = mirrorContact(cue, ob, hint.rail);
    return {
      dir: Math.atan2(img.z - cue.z, img.x - cue.x),
      lines: [[cue, c, 'cue'], [c, ob, 'cue'], [c, img, 'sys']], marks: [{ p: img, kind: 'image' }, { p: c, kind: 'contact' }],
    };
  }
  if (hint.type === 'cornerReflect') {
    const ob = bp(hint.ball);
    const img = cornerReflect(ob, hint.corner);
    // điểm chạm 2 băng theo đường thẳng cue → img
    const pts = polyReflect(cue, img, hint.corner);
    return {
      dir: Math.atan2(img.z - cue.z, img.x - cue.x),
      lines: [[cue, pts[0], 'cue'], [pts[0], pts[1], 'cue'], [pts[1], ob, 'cue'], [{ x: img.cx, z: img.cz }, img, 'sys'], [pts[0], img, 'sys']],
      marks: [{ p: img, kind: 'image' }, { p: { x: img.cx, z: img.cz }, kind: 'contact' }],
    };
  }
  if (hint.type === 'bank') {
    const ob = bp(hint.ball);
    const p = pocketById(hint.pocket);
    const tgt = pocketAimPoint(p);
    const img = mirrorPoint(tgt, hint.rail);
    const g = ghostBall(ob, img);
    const c = mirrorContact(ob, tgt, hint.rail);
    return {
      dir: Math.atan2(g.z - cue.z, g.x - cue.x),
      lines: [[cue, g, 'cue'], [ob, c, 'ob'], [c, tgt, 'ob'], [c, img, 'sys']],
      marks: [{ p: g, kind: 'ghost' }, { p: img, kind: 'image' }],
    };
  }
  if (hint.type === 'corner5') {
    const s = corner5Solve(cue, hint.T);
    if (!s) return null;
    return {
      dir: Math.atan2(s.aim.z - cue.z, s.aim.x - cue.x),
      lines: [[s.origin, s.aim, 'sys']],
      marks: [{ p: s.aim, kind: 'contact', label: `F ${fmt1(s.F)}` }, { p: s.origin, kind: 'contact', label: `D ${fmt1(s.D)}` }, { p: s.arrival, kind: 'contact', label: `T ${fmt1(s.T)}` }],
      info: `D ${fmt1(s.D)} − F ${fmt1(s.F)} = T ${fmt1(s.T)}`,
    };
  }
  return null;
}

const fmt1 = (n) => n.toFixed(1).replace('.', ',');

function polyReflect(a, img, corner) {
  // phản xạ đường a→img lần lượt qua hai đường băng (đường tâm bi)
  const cx = img.cx, cz = img.cz;
  const dx = img.x - a.x, dz = img.z - a.z;
  const tx = (cx - a.x) / dx, tz = (cz - a.z) / dz;
  const first = tx < tz ? { x: cx, z: a.z + dz * tx } : { x: a.x + dx * tz, z: cz };
  // điểm thứ 2: phản xạ phần còn lại
  const second = tx < tz ? { x: 2 * cx - (a.x + dx * tz), z: cz } : { x: cx, z: 2 * cz - (a.z + dz * tx) };
  return [first, second];
}

/** Chọn lỗ dễ nhất cho bi mục tiêu (góc cắt nhỏ, đường ngắn). */
export function bestPocket(cue, ob, blockers = []) {
  let best = null, bs = Infinity;
  for (const p of POCKETS) {
    const t = pocketAimPoint(p);
    const g = ghostBall(ob, t);
    const a1 = Math.atan2(g.z - cue.z, g.x - cue.x), a2 = Math.atan2(t.z - ob.z, t.x - ob.x);
    let cut = Math.abs(a1 - a2); if (cut > Math.PI) cut = 2 * Math.PI - cut;
    if (cut > rad(80)) continue;
    if (p.kind === 'side') {
      const ang = Math.abs(Math.atan2(t.x - ob.x, Math.abs(t.z - ob.z)));
      if (ang > rad(55)) continue;
    }
    const dist = Math.hypot(t.x - ob.x, t.z - ob.z);
    const score = cut * 2 + dist * 0.6;
    if (score < bs) { bs = score; best = p; }
  }
  return best;
}

// ---------- Đánh giá cú đánh ----------
/**
 * Trả về {done, ok, msg}. state: {shots, misses, potted:Set} – trạng thái nhiều cú trong 1 chặng.
 * events: sự kiện vật lý của cú vừa đánh. balls: Simulation.balls.
 */
export function evaluate(stage, events, balls, state) {
  const g = stage.goal;
  const cue = balls.find((b) => b.id === 0);
  const pottedNow = events.filter((e) => e.type === 'pocket').map((e) => e.ball);
  const scratch = pottedNow.includes(0);
  const firstHitEv = events.find((e) => e.type === 'hit' && (e.a === 0 || e.b === 0));
  const firstHit = firstHitEv ? (firstHitEv.a === 0 ? firstHitEv.b : firstHitEv.a) : null;
  const railsBefore = events.filter((e) => e.type === 'cushion' && e.ball === 0 && (!firstHitEv || e.t < firstHitEv.t)).length;
  state.shots = (state.shots || 0) + 1;
  state.potted = state.potted || new Set();
  pottedNow.filter((id) => id !== 0).forEach((id) => state.potted.add(id));

  if (scratch) return { done: true, ok: false, msg: 'Bi cái rơi lỗ (scratch)!' };

  if (g.clear) {
    const left = g.clear.filter((id) => !state.potted.has(id));
    if (g.ordered) {
      const lowest = Math.min(...g.clear.filter((id) => !state.potted.has(id) || pottedNow.includes(id)));
      if (firstHit !== lowest) return { done: true, ok: false, msg: `Lỗi: phải chạm bi ${lowest} trước.` };
    }
    const potThis = pottedNow.some((id) => id !== 0);
    if (!potThis) {
      state.misses = (state.misses || 0) + 1;
      if (g.maxMisses != null && state.misses > g.maxMisses) return { done: true, ok: false, msg: 'Trượt quá số lần cho phép.' };
    }
    if (!left.length) return { done: true, ok: true, msg: `Dọn sạch trong ${state.shots} cú!` };
    if (g.maxShots && state.shots >= g.maxShots) return { done: true, ok: false, msg: 'Hết lượt.' };
    return { done: false, ok: potThis, msg: potThis ? `Vào! Còn ${left.length} bi.` : `Trượt. Còn ${left.length} bi.` };
  }

  if (g.firstHit != null) {
    if (firstHit !== g.firstHit) return { done: true, ok: false, msg: firstHit == null ? 'Không chạm bi nào.' : `Chạm nhầm bi ${firstHit}.` };
    if (g.minRails && railsBefore < g.minRails) return { done: true, ok: false, msg: `Cần chạm ${g.minRails} băng trước (mới ${railsBefore}).` };
  }
  if (g.pot) {
    const miss = g.pot.filter((id) => !pottedNow.includes(id));
    if (miss.length) return { done: true, ok: false, msg: 'Bi không vào lỗ.' };
    if (g.minRailsBall) {
      const id = g.pot[0];
      const hitT = firstHitEv ? firstHitEv.t : 0;
      const rails = events.filter((e) => e.type === 'cushion' && e.ball === id && e.t > hitT && e.rail !== 'jaw').length;
      if (rails < g.minRailsBall) return { done: true, ok: false, msg: 'Bi phải chạm băng trước khi vào lỗ.' };
    }
  }
  if (g.potAny && !pottedNow.some((id) => id !== 0)) return { done: true, ok: false, msg: 'Không có bi nào vào lỗ.' };
  if (g.minRails && g.firstHit == null) {
    const rails = events.filter((e) => e.type === 'cushion' && e.ball === 0).length;
    if (rails < g.minRails) return { done: true, ok: false, msg: 'Bi cái phải chạm băng.' };
  }
  if (g.cueZone) {
    const dz = Math.hypot(cue.x - g.cueZone.x, cue.z - g.cueZone.z);
    if (dz > g.cueZone.r) return { done: true, ok: false, msg: `Bi cái cách vùng ${(dz * 100).toFixed(0)} cm.` };
  }
  return { done: true, ok: true, msg: 'Thành công!' };
}
