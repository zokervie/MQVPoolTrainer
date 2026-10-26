// EXACT excerpt transcribed from zokervie/MQVPoolTrainer/src/table.js
// Source commit 555af3c76916607bddc931da68dff81f0ab47963
export const R = 0.028575;
export const L = 2.54;
export const W = 1.27;
export const DIAMOND = L / 8;
export const CUSHION_H = 0.0365;
export const CORNER_MOUTH = 0.118;
export const SIDE_MOUTH = 0.132;
export function fromDiamond(dx, dz) {
  return { x: (dx / 8 - 0.5) * L, z: (0.5 - dz / 4) * W };
}
export function toDiamond(x, z) {
  return { dx: (x / L + 0.5) * 8, dz: (0.5 - z / W) * 4 };
}
