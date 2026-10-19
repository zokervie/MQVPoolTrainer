// Âm thanh tổng hợp bằng WebAudio (không cần file âm thanh).
let ctx = null, enabled = true;
export function setSound(on) { enabled = on; }
function ac() {
  if (!ctx) { try { ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch { return null; } }
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}
export function unlockAudio() { ac(); }

function burst({ freq = 2000, q = 1, dur = 0.05, gain = 0.5, type = 'bandpass', decay = 0.03 }) {
  if (!enabled) return;
  const c = ac(); if (!c) return;
  const n = Math.floor(c.sampleRate * dur);
  const buf = c.createBuffer(1, n, c.sampleRate), d = buf.getChannelData(0);
  for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * Math.exp(-i / (c.sampleRate * decay));
  const src = c.createBufferSource(); src.buffer = buf;
  const f = c.createBiquadFilter(); f.type = type; f.frequency.value = freq; f.Q.value = q;
  const g = c.createGain(); g.gain.value = gain;
  src.connect(f).connect(g).connect(c.destination); src.start();
}

export const sfx = {
  ball(speed) { const v = Math.min(1, speed / 4); if (v > 0.02) burst({ freq: 2600 + v * 1800, q: 6, dur: 0.06, gain: 0.15 + v * 0.7, decay: 0.008 }); },
  cushion(speed) { const v = Math.min(1, speed / 4); if (v > 0.03) burst({ freq: 260, q: 1.2, dur: 0.09, gain: 0.25 + v * 0.6, type: 'lowpass', decay: 0.02 }); },
  cue(power) { burst({ freq: 1500, q: 3, dur: 0.05, gain: 0.25 + power * 0.6, decay: 0.006 }); },
  pocket() {
    burst({ freq: 180, q: 1, dur: 0.25, gain: 0.7, type: 'lowpass', decay: 0.06 });
    setTimeout(() => burst({ freq: 900, q: 4, dur: 0.06, gain: 0.25, decay: 0.01 }), 120);
  },
  ok() {
    if (!enabled) return; const c = ac(); if (!c) return;
    [660, 880].forEach((fq, i) => {
      const o = c.createOscillator(), g = c.createGain(); o.frequency.value = fq; o.type = 'sine';
      g.gain.setValueAtTime(0.0001, c.currentTime + i * 0.09); g.gain.exponentialRampToValueAtTime(0.18, c.currentTime + i * 0.09 + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, c.currentTime + i * 0.09 + 0.25);
      o.connect(g).connect(c.destination); o.start(c.currentTime + i * 0.09); o.stop(c.currentTime + i * 0.09 + 0.3);
    });
  },
};
