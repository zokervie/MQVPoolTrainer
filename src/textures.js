// Texture vẽ bằng canvas: bi, vải, gỗ, chữ.
import * as THREE from 'three';

export const BALL_COLORS = {
  1: '#f2b705', 2: '#1747a6', 3: '#d42a20', 4: '#53308a', 5: '#f26a1b', 6: '#13804a', 7: '#8a1f22', 8: '#141414',
};
export const ballColor = (id) => (id === 0 ? '#f7f3ea' : BALL_COLORS[id > 8 ? id - 8 : id]);

function canvas(w, h) {
  const c = document.createElement('canvas'); c.width = w; c.height = h; return c;
}

export function ballTexture(id, renderer) {
  const W = 1024, H = 512;
  const c = canvas(W, H), g = c.getContext('2d');
  const ivory = '#f7f3ea';
  if (id === 0) {
    g.fillStyle = ivory; g.fillRect(0, 0, W, H);
    // chấm đỏ để nhìn thấy xoáy
    g.fillStyle = '#c1121f';
    for (const [u, v] of [[0.0, 0.5], [0.25, 0.5], [0.5, 0.5], [0.75, 0.5], [0.125, 0.18], [0.625, 0.82]]) {
      g.beginPath(); g.ellipse(u * W, v * H, 26, 26, 0, 0, Math.PI * 2); g.fill();
      if (u === 0) { g.beginPath(); g.ellipse(W, v * H, 26, 26, 0, 0, Math.PI * 2); g.fill(); }
    }
    g.fillRect(0, 0, W, 10); g.fillRect(0, H - 10, W, 10);
  } else {
    const col = ballColor(id);
    if (id > 8) {
      g.fillStyle = ivory; g.fillRect(0, 0, W, H);
      g.fillStyle = col; g.fillRect(0, H * 0.27, W, H * 0.46);
    } else { g.fillStyle = col; g.fillRect(0, 0, W, H); }
    for (const u of [0.25, 0.75]) {
      const x = u * W, y = H / 2;
      g.fillStyle = ivory; g.beginPath(); g.ellipse(x, y, 68, 68, 0, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#121212';
      g.font = `700 ${id > 9 ? 78 : 92}px "Be Vietnam Pro", system-ui, sans-serif`;
      g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText(String(id), x, y + 4);
      if (id === 6 || id === 9) { g.fillRect(x - 22, y + 46, 44, 6); }
    }
  }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = renderer.capabilities.getMaxAnisotropy();
  return t;
}

export function clothTexture() {
  const S = 256, c = canvas(S, S), g = c.getContext('2d');
  const img = g.createImageData(S, S);
  for (let i = 0; i < S * S; i++) {
    const n = 225 + Math.random() * 30 - ((i % S) % 2) * 6;
    img.data[i * 4] = img.data[i * 4 + 1] = img.data[i * 4 + 2] = n; img.data[i * 4 + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(18, 9);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

export function woodTexture(base = '#5a3720') {
  const W = 1024, H = 256, c = canvas(W, H), g = c.getContext('2d');
  g.fillStyle = base; g.fillRect(0, 0, W, H);
  for (let i = 0; i < 140; i++) {
    const y = Math.random() * H, a = 0.04 + Math.random() * 0.1;
    g.strokeStyle = Math.random() < 0.5 ? `rgba(20,8,2,${a})` : `rgba(255,220,170,${a * 0.6})`;
    g.lineWidth = 0.6 + Math.random() * 2.2;
    g.beginPath(); g.moveTo(0, y);
    for (let x = 0; x <= W; x += 32) g.lineTo(x, y + Math.sin(x * 0.01 + i) * 4 + Math.sin(x * 0.043 + i * 3) * 1.5);
    g.stroke();
  }
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(3, 1);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

export function textTexture(text, color = '#f2ede3', size = 64) {
  const c = canvas(128, 128), g = c.getContext('2d');
  g.font = `700 ${size}px "Be Vietnam Pro", system-ui, sans-serif`;
  g.textAlign = 'center'; g.textBaseline = 'middle';
  g.lineWidth = 8; g.strokeStyle = 'rgba(10,14,18,0.75)'; g.strokeText(text, 64, 68);
  g.fillStyle = color; g.fillText(text, 64, 68);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
