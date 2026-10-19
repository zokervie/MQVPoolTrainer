// Kích thước bàn và hình học băng / lỗ (đơn vị: mét). Bàn 9 ft chuẩn WPA.
// Hệ trục (tay phải, giống Three.js): x theo chiều dài bàn (trái → phải), y hướng lên,
// z theo chiều rộng và hướng XUỐNG dưới màn hình khi nhìn từ trên (2D). Nút dz = 0 là băng dưới (z = +W/2).

export const R = 0.028575;            // bán kính bi (2.25 in)
export const L = 2.54;                // chiều dài mặt chơi (100 in)
export const W = 1.27;                // chiều rộng mặt chơi (50 in)
export const DIAMOND = L / 8;         // khoảng cách giữa 2 nút (12.5 in)
export const CUSHION_H = 0.0365;      // chiều cao mũi băng so với mặt vải (~64% đường kính bi)
export const CORNER_MOUTH = 0.118;    // miệng lỗ góc (~4.65 in)
export const SIDE_MOUTH = 0.132;      // miệng lỗ giữa (~5.2 in)

const HL = L / 2, HW = W / 2;
const cA = CORNER_MOUTH / Math.SQRT2; // khoảng lùi mũi băng tính từ góc
const sA = SIDE_MOUTH / 2;

/** Đổi toạ độ nút (0..8 theo chiều dài, 0..4 theo chiều rộng) sang mét. */
export function fromDiamond(dx, dz) {
  return { x: (dx / 8 - 0.5) * L, z: (0.5 - dz / 4) * W };
}
/** Đổi mét sang toạ độ nút. */
export function toDiamond(x, z) {
  return { dx: (x / L + 0.5) * 8, dz: (0.5 - z / W) * 4 };
}

function jaw(nx, nz, dirx, dirz, len) {
  const m = Math.hypot(dirx, dirz);
  return { a: [nx, nz], b: [nx + (dirx / m) * len, nz + (dirz / m) * len], jaw: true };
}

/** Danh sách đoạn băng (mũi băng + hàm lỗ). Tâm bi va chạm khi cách đoạn < R. */
export function buildCushions() {
  const segs = [];
  const J = 0.07; // chiều dài hàm lỗ
  const c38 = Math.cos((38 * Math.PI) / 180), s38 = Math.sin((38 * Math.PI) / 180);
  const c76 = Math.cos((76 * Math.PI) / 180), s76 = Math.sin((76 * Math.PI) / 180);
  for (const sz of [1, -1]) {
    // hai đoạn băng dài (trái/phải lỗ giữa)
    for (const sx of [1, -1]) {
      segs.push({ a: [sx * sA, sz * HW], b: [sx * (HL - cA), sz * HW], rail: sz > 0 ? 'bottom' : 'top' });
      // hàm lỗ góc phía băng dài
      segs.push(jaw(sx * (HL - cA), sz * HW, sx * c38, sz * s38, J));
      // hàm lỗ giữa (hơi thu hẹp vào trong)
      segs.push(jaw(sx * sA, sz * HW, -sx * c76, sz * s76, J * 0.75));
    }
  }
  for (const sx of [1, -1]) {
    segs.push({ a: [sx * HL, -(HW - cA)], b: [sx * HL, HW - cA], rail: sx > 0 ? 'right' : 'left' });
    for (const sz of [1, -1]) segs.push(jaw(sx * HL, sz * (HW - cA), sx * s38, sz * c38, J));
  }
  return segs;
}

/** Lỗ: tâm, bán kính bắt bi, bán kính hiển thị. */
export function buildPockets() {
  const pockets = [];
  const names = { '1,1': 'Góc dưới phải', '-1,1': 'Góc dưới trái', '1,-1': 'Góc trên phải', '-1,-1': 'Góc trên trái' };
  for (const sx of [1, -1]) for (const sz of [1, -1]) {
    const d = 0.046; // lùi vào trong theo đường chéo từ trung điểm miệng
    const mx = sx * (HL - cA / 2), mz = sz * (HW - cA / 2);
    pockets.push({ id: `c${sx}${sz}`, name: names[`${sx},${sz}`], kind: 'corner',
      x: mx + sx * d * Math.SQRT1_2, z: mz + sz * d * Math.SQRT1_2, capture: 0.05, r: 0.066,
      mouth: { x: mx, z: mz } });
  }
  for (const sz of [1, -1]) {
    pockets.push({ id: `s${sz}`, name: sz > 0 ? 'Giữa dưới' : 'Giữa trên', kind: 'side',
      x: 0, z: sz * (HW + 0.036), capture: 0.05, r: 0.064, mouth: { x: 0, z: sz * HW } });
  }
  return pockets;
}

export const CUSHIONS = buildCushions();
export const POCKETS = buildPockets();

/** Vị trí các nút trên thành bàn (để vẽ + đánh số). rail: top/bottom/left/right, n: chỉ số nút 0..8 / 0..4. */
export function diamondPositions(offset = 0.11) {
  const out = [];
  for (let i = 0; i <= 8; i++) {
    if (i === 0 || i === 4 || i === 8) continue; // vị trí lỗ
    const x = (i / 8 - 0.5) * L;
    out.push({ rail: 'bottom', n: i, x, z: HW + offset });
    out.push({ rail: 'top', n: i, x, z: -HW - offset });
  }
  for (let j = 1; j <= 3; j++) {
    const z = (0.5 - j / 4) * W;
    out.push({ rail: 'left', n: j, x: -HL - offset, z });
    out.push({ rail: 'right', n: j, x: HL + offset, z });
  }
  return out;
}

// Vị trí chuẩn
export const HEAD_SPOT = fromDiamond(2, 2);
export const FOOT_SPOT = fromDiamond(6, 2);
