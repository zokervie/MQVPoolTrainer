#!/usr/bin/env python3
"""0.44.1 M5: intro sound. Writes the SYNTHESISED layers (each its own WAV, so the owner can replace any of them with
his own recording without touching code) and the mix sheet the app plays:

  IntroRiser0441   wind riser under the cue draw-back (0.6–1.6 s)
  IntroBoom0441    low thump under the break (1.6 s)
  IntroJingle0441  logo chime (3.9 s; the 2nd-launch sting plays only this)
  IntroMix0441     JSON: every layer (synthesised + the real samples PoolBall0…3, PoolCue0, PoolRail0, PoolPocket0
                   already in the app), its start time, gain and playback rate (pitch). The break stacks the ball
                   samples at several pitches.

The script renders the same mix offline, measures integrated loudness (ITU-R BS.1770-4: K-weighting, 400 ms blocks,
75 % overlap, −70 LUFS absolute and −10 LU relative gates) and sample peak, then sets one master gain so the mix is
−16 ±1 LUFS with the peak ≤ −1 dBFS, and prints both. Pure Python (wave + math), deterministic.
Usage: python3 Tools/gen_intro_audio.py
"""
import json, math, os, random, struct, wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'BankLab', 'Assets.xcassets')
FS = 44100
DROP_WALL = 2.85   # first corner drop in the intro timeline (Tests/IntroBreakTests.cpp prints it)

def read(name):
    with wave.open(os.path.join(ROOT, name + '.dataset', 'audio.wav')) as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2
        data = w.readframes(w.getnframes())
        rate = w.getframerate()
    x = [v / 32768 for v in struct.unpack('<%dh' % (len(data) // 2), data)]
    if rate != FS: x = resample(x, rate / FS)
    return x

def write(name, x):
    folder = os.path.join(ROOT, name + '.dataset'); os.makedirs(folder, exist_ok=True)
    with wave.open(os.path.join(folder, 'audio.wav'), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(FS)
        w.writeframes(struct.pack('<%dh' % len(x), *[max(-32767, min(32767, int(round(v * 32767)))) for v in x]))
    with open(os.path.join(folder, 'Contents.json'), 'w') as f:
        json.dump({"data": [{"filename": "audio.wav", "idiom": "universal", "universal-type-identifier": "com.microsoft.waveform-audio"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)

def resample(x, rate):
    """Playback at `rate` (2 = an octave up), linear interpolation — matches AVAudioUnitVarispeed closely enough."""
    n = int(len(x) / rate); out = []
    for i in range(n):
        t = i * rate; k = int(t); f = t - k
        out.append(x[k] * (1 - f) + (x[k + 1] if k + 1 < len(x) else 0) * f)
    return out

# ---- synthesised layers -------------------------------------------------------------------------------------------
def riser(seconds=1.15):
    rnd = random.Random(3); out = []; lp = 0.0
    for i in range(int(seconds * FS)):
        t = i / (seconds * FS)
        cutoff = 0.02 + 0.25 * t ** 2            # brightening wind
        lp += cutoff * (rnd.uniform(-1, 1) - lp)
        env = (t ** 1.6) * (1 - max(0, (t - 0.92) / 0.08))
        out.append(lp * env * 1.6)
    return out

def boom(seconds=0.9):
    out = []
    for i in range(int(seconds * FS)):
        t = i / FS; f = 62 * math.exp(-t * 2.2) + 38
        out.append(math.sin(2 * math.pi * f * t) * math.exp(-t * 5.5) * (1 - math.exp(-t * 400)))
    return out

def jingle(seconds=1.6):
    notes = [(0.00, 659.25), (0.12, 830.61), (0.24, 987.77), (0.36, 1318.5)]   # E5 G#5 B5 E6: bright major arpeggio
    out = [0.0] * int(seconds * FS)
    for start, f in notes:
        for i in range(int(start * FS), len(out)):
            t = i / FS - start
            env = math.exp(-t * 2.4) * (1 - math.exp(-t * 300))
            out[i] += 0.25 * env * (math.sin(2 * math.pi * f * t) + 0.35 * math.sin(4 * math.pi * f * t) + 0.12 * math.sin(6 * math.pi * f * t))
    return out

# ---- loudness (ITU-R BS.1770-4) --------------------------------------------------------------------------------------
def biquad(x, b, a):
    b0, b1, b2 = (v / a[0] for v in b); a1, a2 = a[1] / a[0], a[2] / a[0]
    y = []; x1 = x2 = y1 = y2 = 0.0
    for v in x:
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o; y.append(o)
    return y

def k_weight(x):
    G, Q, fc = 3.99984385397, 0.7071752369554193, 1681.9744509555319
    A = 10 ** (G / 40); w0 = 2 * math.pi * fc / FS; c = math.cos(w0); al = math.sin(w0) / (2 * Q); sA = math.sqrt(A)
    x = biquad(x, [A * ((A + 1) + (A - 1) * c + 2 * sA * al), -2 * A * ((A - 1) + (A + 1) * c), A * ((A + 1) + (A - 1) * c - 2 * sA * al)],
               [(A + 1) - (A - 1) * c + 2 * sA * al, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - 2 * sA * al])
    Q, fc = 0.5003270373253953, 38.13547087613982
    w0 = 2 * math.pi * fc / FS; c = math.cos(w0); al = math.sin(w0) / (2 * Q)
    return biquad(x, [(1 + c) / 2, -(1 + c), (1 + c) / 2], [1 + al, -2 * c, 1 - al])

def lufs(x):
    y = k_weight(x); block, hop = int(0.4 * FS), int(0.1 * FS)
    z = [sum(v * v for v in y[i:i + block]) / block for i in range(0, max(1, len(y) - block + 1), hop)]
    z = [v for v in z if v > 0 and -0.691 + 10 * math.log10(v) > -70]
    if not z: return -float('inf')
    rel = -0.691 + 10 * math.log10(sum(z) / len(z)) - 10
    z = [v for v in z if -0.691 + 10 * math.log10(v) > rel]
    return -0.691 + 10 * math.log10(sum(z) / len(z))

# ---- mix sheet -----------------------------------------------------------------------------------------------------
LAYERS = [  # name, start (s, intro timeline), relative gain, playback rate
    ("IntroRiser0441", 0.38, 1.0, 1.0),
    ("PoolCue0", 1.58, 0.35, 1.0),
    ("PoolBall0", 1.60, 0.30, 1.00), ("PoolBall1", 1.618, 0.26, 0.92), ("PoolBall2", 1.637, 0.24, 1.08),
    ("PoolBall3", 1.655, 0.22, 0.86), ("PoolBall1", 1.71, 0.18, 1.15), ("PoolBall2", 1.79, 0.15, 0.97),
    ("IntroBoom0441", 1.60, 0.75, 1.0),
    ("PoolRail0", 1.95, 0.18, 1.0), ("PoolRail0", 2.30, 0.14, 0.9),
    ("PoolRail0", DROP_WALL - 0.03, 0.2, 1.12),     # jaw of the corner pocket
    ("PoolPocket0", DROP_WALL, 0.45, 1.0),
    ("IntroJingle0441", 3.90, 1.5, 1.0),
]
STING = [("IntroJingle0441", 0.0, 0.8, 1.0)]

def render(layers, sounds, seconds):
    out = [0.0] * int(seconds * FS)
    for name, at, gain, rate in layers:
        s = sounds[name] if rate == 1.0 else resample(sounds[name], rate)
        k0 = int(at * FS)
        for i, v in enumerate(s):
            if k0 + i < len(out): out[k0 + i] += v * gain
    return out

def master(layers, sounds, seconds, target=-16.0):
    mix = render(layers, sounds, seconds)
    loud = lufs(mix); gain = 10 ** ((target - loud) / 20)
    peak = max(abs(v) for v in mix) * gain
    if peak > 10 ** (-1 / 20): gain *= 10 ** (-1 / 20) / peak   # never above −1 dBFS
    final = [v * gain for v in mix]
    return gain, lufs(final), 20 * math.log10(max(abs(v) for v in final))

if __name__ == '__main__':
    write('IntroRiser0441', riser()); write('IntroBoom0441', boom()); write('IntroJingle0441', jingle())
    names = {l[0] for l in LAYERS}
    sounds = {n: read(n) for n in names}
    g, L, P = master(LAYERS, sounds, 6.0)
    gs, Ls, Ps = master(STING, sounds, 1.6)
    sheet = {"note": "Generated by Tools/gen_intro_audio.py. Replace any layer's audio.wav with a recording and re-run to re-level.",
             "full": {"master": g, "lufs": round(L, 2), "peakDBFS": round(P, 2),
                      "layers": [{"sound": n, "at": a, "gain": gn, "rate": r} for n, a, gn, r in LAYERS]},
             "sting": {"master": gs, "lufs": round(Ls, 2), "peakDBFS": round(Ps, 2),
                       "layers": [{"sound": n, "at": a, "gain": gn, "rate": r} for n, a, gn, r in STING]}}
    folder = os.path.join(ROOT, 'IntroMix0441.dataset'); os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, 'mix.json'), 'w') as f: json.dump(sheet, f, indent=2)
    with open(os.path.join(folder, 'Contents.json'), 'w') as f:
        json.dump({"data": [{"filename": "mix.json", "idiom": "universal", "universal-type-identifier": "public.json"}], "info": {"author": "xcode", "version": 1}}, f, indent=2)
    ok = all(-17 <= x <= -15 for x in (L, Ls)) and max(P, Ps) <= -1.0 + 1e-6
    print(f"{'PASS' if ok else 'FAIL'} intro audio: full mix {L:.2f} LUFS, peak {P:.2f} dBFS · sting {Ls:.2f} LUFS, peak {Ps:.2f} dBFS (target −16 ±1 LUFS, peak ≤ −1 dBFS)")
    raise SystemExit(0 if ok else 1)
