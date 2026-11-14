#!/usr/bin/env python3
"""0.43 intro sound — the same score as BankLab/UI/Intro043.swift (IntroScore), rendered to WAV stems.
Synthesised placeholder (no recordings, no licences needed). Usage: intro_audio.py OUT_DIR
Writes full/sting × {foley, cinematic, ambience, mix} as 48 kHz 16-bit stereo WAV, peak-limited to 0.8."""
import sys, wave, math, random
from pathlib import Path
import numpy as np

SR = 48000
def events(full):
    return ([(0, 0), (1, .55), (2, 1.5), (3, 1.94), (4, 2.0), (5, 4.6), (6, 4.72)] if full
            else [(3, .04), (5, .10), (6, .20)])
GROUP = {0: 'ambience', 1: 'foley', 2: 'foley', 3: 'foley', 4: 'foley', 5: 'foley', 6: 'cinematic'}

def render(full):
    n = int(SR * (5.9 if full else 1.0)); t = np.arange(n) / SR
    rng = np.random.default_rng(11); noise = rng.uniform(-1, 1, n)
    def lp(x, a):
        y = np.empty_like(x); acc = 0.0
        for i, v in enumerate(x): acc += (v - acc) * a; y[i] = acc
        return y
    low, mid = lp(noise, .02), lp(noise, .25)
    stems = {k: np.zeros((n, 2)) for k in ('foley', 'cinematic', 'ambience')}
    for kind, at in events(full):
        u = t - at; on = u >= 0; uu = np.where(on, u, 0)
        m = np.zeros(n); l = np.zeros(n); r = np.zeros(n); cine = np.zeros(n)
        if kind == 0: m = low * .10 * np.minimum(1, uu / .4) * np.maximum(0, 1 - np.maximum(0, t - 1.15) / .25)
        if kind == 1: m = np.where(uu < .03, mid * .22 * np.exp(-uu * 160), 0)
        if kind == 2: m = np.where(uu < .08, noise * .35 * np.exp(-uu * 700) + np.sin(2*np.pi*1150*uu) * .30 * np.exp(-uu * 90), 0)
        if kind == 3:
            m = np.where(uu < .35, noise * .45 * np.exp(-uu * 900) + np.sin(2*np.pi*3300*uu) * .35 * np.exp(-uu * 70) + np.sin(2*np.pi*720*uu) * .22 * np.exp(-uu * 40), 0)
            cine = np.where(uu < .35, np.sin(2*np.pi*58*uu) * .40 * np.exp(-uu * 14) * np.minimum(1, uu / .004), 0)
        if kind == 4:
            m = low * .16 * np.maximum(0, 1 - uu / 2.2)
            s = np.clip((uu - 1.0) / .8, 0, 1) * np.maximum(0, 1 - np.maximum(0, uu - 2.4) / .4)
            for k, f in enumerate([880.0, 1318.5, 1760.0]):
                a = .05 / (k + 1) * s; l += np.sin(2*np.pi*(f-1.5)*uu) * a; r += np.sin(2*np.pi*(f+1.5)*uu) * a
        if kind == 5: m = np.where(uu < .05, noise * .4 * np.exp(-uu * 600) + np.sin(2*np.pi*2600*uu) * .25 * np.exp(-uu * 120), 0)
        if kind == 6:
            env = np.minimum(1, uu / .006) * np.exp(-uu * 3.4)
            cine = np.where(uu < 1.2, env * (np.sin(2*np.pi*1568*uu) * .30 + np.sin(2*np.pi*2352*uu) * .12 + np.sin(2*np.pi*4330*uu) * .05), 0)
        m, l, r, cine = (x * on for x in (m, l, r, cine))
        stems[GROUP[kind]] += np.stack([m, m], 1)
        stems['cinematic'] += np.stack([l + cine, r + cine], 1)
    stems['mix'] = stems['foley'] + stems['cinematic'] + stems['ambience']
    if not full:
        for k in stems: stems[k] *= .9   # same sting gain as the app
    return stems

def write(path, x):
    x = np.clip(x, -.8, .8); data = (x * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as w: w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

if __name__ == '__main__':
    out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    for full in (True, False):
        for name, x in render(full).items():
            write(out / f"zoker-intro-{'full' if full else 'sting'}-{name}.wav", x)
            print(f"{name:10s} {'full' if full else 'sting'} peak {np.abs(x).max():.2f} mono-sum peak {np.abs(x.mean(1)).max():.2f}")
