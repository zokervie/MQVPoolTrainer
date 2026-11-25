"""Zokervie intro C sound (6.0 s, 48 kHz stereo). Fully synthesised (own asset):
modal synthesis for cue tip / ball / cushion / gold metal, filtered noise for roll and
slides, a generated stereo room reverb, and a three-note brand chime."""
import numpy as np, wave, sys
from scipy.signal import butter, sosfilt, fftconvolve
SR = 48000; T = 6.0; N = int(SR * T)
rng = np.random.default_rng(23)
L = np.zeros(N); R = np.zeros(N)       # dry
WL = np.zeros(N); WR = np.zeros(N)     # reverb send

def put(sig, t0, pan=0.0, gain=1.0, send=0.2):
    i = int(t0 * SR); j = min(N, i + len(sig)); s = sig[:j - i] * gain
    gl, gr = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    L[i:j] += s * gl; R[i:j] += s * gr; WL[i:j] += s * gl * send; WR[i:j] += s * gr * send
def bp(x, lo, hi, o=2): return sosfilt(butter(o, [lo, hi], btype="band", fs=SR, output="sos"), x)
def lp(x, f, o=2): return sosfilt(butter(o, f, fs=SR, output="sos"), x)
def hp(x, f, o=2): return sosfilt(butter(o, f, btype="high", fs=SR, output="sos"), x)
def modal(freqs, decays, amps, dur, jitter=0.0):
    t = np.arange(int(dur * SR)) / SR; y = np.zeros_like(t)
    for f, d, a in zip(freqs, decays, amps):
        f = f * (1 + rng.uniform(-jitter, jitter)); y += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / d)
    return y
def click(dur=0.003, f=4000, total=None):
    n = int(dur * SR); c = hp(rng.uniform(-1, 1, n), f) * np.linspace(1, 0, n) ** 2
    return c if total is None else np.pad(c, (0, total - n))
def env(n, a, r):
    e = np.ones(n); ai = max(1, int(a * SR)); ri = max(1, int(r * SR)); e[:ai] = np.linspace(0, 1, ai); e[-ri:] *= np.linspace(1, 0, ri); return e
def sweep_noise(dur, f0, f1, q=1.5, block=256):
    n = int(dur * SR); x = rng.uniform(-1, 1, n); y = np.zeros(n); zi = None
    for k in range((n + block - 1) // block):
        fc = f0 * (f1 / f0) ** (k * block / n); lo, hi = fc / (1 + 1 / q), min(SR / 2 - 200, fc * (1 + 1 / q))
        sos = butter(2, [lo, hi], btype="band", fs=SR, output="sos")
        if zi is None or zi.shape[0] != sos.shape[0]: zi = np.zeros((sos.shape[0], 2))
        seg, zi = sosfilt(sos, x[k * block:(k + 1) * block], zi=zi); y[k * block:k * block + len(seg)] = seg
    return y
def sine_glide(f0, f1, dur, decay):
    t = np.arange(int(dur * SR)) / SR; f = f0 * (f1 / f0) ** (t / dur); return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / decay)

# room tone + low slow-motion drone
put(lp(rng.uniform(-1, 1, N), 380) * 0.035, 0, 0, 1, 0)
dt = np.arange(int(1.7 * SR)) / SR
drone = (np.sin(2 * np.pi * 55 * dt) * .5 + np.sin(2 * np.pi * 82.4 * dt) * .3) * np.minimum(1, dt / .8) * np.exp(-np.maximum(0, dt - .9) / .3)
put(lp(drone, 400) * .16, 0.0, 0, 1, .2)
# cue approach, one feathering stroke, backswing
put(bp(rng.uniform(-1, 1, int(.45 * SR)), 500, 1600) * env(int(.45 * SR), .2, .2) * .05, 0.05, -.5)
put(bp(rng.uniform(-1, 1, int(.25 * SR)), 600, 1800) * np.sin(np.linspace(0, np.pi, int(.25 * SR))) * .045, 0.5, -.45)
# STRIKE in slow motion: pitched-down tip/ball tock with a long tail
tock = modal([880, 1610, 2490, 3780], [.06, .04, .025, .015], [1, .55, .3, .15], .3, .01) + .4 * click(.003, 2200, int(.3 * SR))
body = sine_glide(150, 95, .3, .09) * .7
strike = np.zeros(int(.35 * SR)); strike[:len(tock)] += tock; strike[:len(body)] += body
ir_s = rng.uniform(-1, 1, int(1.0 * SR)) * np.exp(-np.arange(int(1.0 * SR)) / SR / .25)
rev = fftconvolve(strike, lp(ir_s, 5000))[: int(.7 * SR)][::-1]; rev /= np.max(np.abs(rev)) + 1e-9
put(rev * np.linspace(0, 1, len(rev)) ** 2 * .35, 0.9 - len(rev) / SR, -.2, 1, .1)
put(strike * .95, 0.9, -.2, 1, .45)
put(sine_glide(70, 33, .9, .3) * .6, 0.9, 0, 1, .1)
# chalk dust: airy shimmer while the puff hangs in the light
put(hp(rng.uniform(-1, 1, int(.75 * SR)), 5000) * np.exp(-np.arange(int(.75 * SR)) / SR / .25) * .06, 0.92, -.3, 1, .6)
# cut to top view: whoosh, then fast roll
put(sweep_noise(.35, 700, 3200, 1.8) * env(int(.35 * SR), .25, .1) * .14, 1.3, -.6, 1, .2)
t = np.arange(N) / SR
def speed(tt):
    if 1.6 <= tt < 2.4: return 1.0
    if 2.4 <= tt < 3.2: return .85 * (1 - (tt - 2.4) / .8) ** .6 + .25
    if 3.2 <= tt < 3.7: return .3 * (1 - (tt - 3.2) / .5) ** 2
    return 0.0
sp = np.array([speed(x) for x in t[::64]]); sp = np.interp(np.arange(N), np.arange(0, N, 64), sp)
roll = lp(bp(rng.uniform(-1, 1, N), 60, 900), 420) * (0.7 + 0.3 * np.sin(2 * np.pi * 27 * t)) * sp * .5
xb = np.interp(t, [1.6, 2.4, 3.2, 3.7], [-.7, .7, -.6, -.3])
gl, gr = np.cos((xb + 1) * np.pi / 4), np.sin((xb + 1) * np.pi / 4)
L += roll * gl; R += roll * gr; WL += roll * gl * .1; WR += roll * gr * .1
# THE SIGNATURE: two cushion knocks
def cushion(f):
    return modal([f, f * 1.82, f * 3.06], [.09, .05, .025], [1, .5, .25], .3) + lp(rng.uniform(-1, 1, int(.3 * SR)), 1100) * np.exp(-np.arange(int(.3 * SR)) / SR / .018) * .7
for t0, f, pan in ((2.4, 170, .65), (3.2, 196, -.6)):
    put(cushion(f) * .95, t0, pan, 1, .3)
    put(hp(rng.uniform(-1, 1, int(.45 * SR)), 6000) * np.exp(-np.arange(int(.45 * SR)) / SR / .09) * .09, t0, pan, 1, .45)
# riser into the flash
put(sweep_noise(.5, 900, 9000, 2.4) * np.linspace(0, 1, int(.5 * SR)) ** 2 * .16, 3.45, 0, 1, .4)
# THE LOCK at the cut to the logo
gold = lambda f0, dur, a: modal([f0, f0 * 2.76, f0 * 5.40, f0 * 8.93], [1.1, .7, .4, .25], [1, .45, .25, .12], dur) * a
boom = sine_glide(92, 31, 1.6, .55) + lp(rng.uniform(-1, 1, int(1.6 * SR)), 180) * np.exp(-np.arange(int(1.6 * SR)) / SR / .08) * .8
put(boom, 3.95, 0, 1, .15); put(gold(220, 2.2, .28), 3.95, 0, 1, .55)
# bars and gold cue rise and lock
for t0, f, pan in ((4.0, 620, .2), (4.15, 700, .3), (4.3, 880, -.1)):
    put(sweep_noise(.3, 1800, 6500, 2.2) * env(int(.3 * SR), .2, .06) * .08, t0, pan, 1, .35)
    put(gold(f, 1.2, .12) + click(.002, 5000, int(1.2 * SR)) * .3, t0 + .32, pan, 1, .45)
# brand chime: D5 A5 D6 over a soft D pad
def bell(f, dur, a):
    tt = np.arange(int(dur * SR)) / SR; mod = np.sin(2 * np.pi * f * 1.4 * tt) * 2.2 * np.exp(-tt / .35)
    return np.sin(2 * np.pi * f * tt + mod) * np.exp(-tt / .9) * a
for k, (f, t0) in enumerate(((587.33, 4.75), (880.0, 4.91), (1174.66, 5.07))):
    put(bell(f, 1.2, .16), t0, (-.3, .0, .3)[k], 1, .6)
pt = np.arange(int(1.3 * SR)) / SR
pad = sum(np.sin(2 * np.pi * f * pt) * a for f, a in ((146.83, .5), (220.0, .35), (369.99, .2), (587.33, .1)))
put(lp(pad, 1500) * env(len(pad), .45, .6) * .10, 4.7, 0, 1, .5)

# stereo room reverb (2.2 s), early reflections + diffuse tail
n = int(2.2 * SR); tt = np.arange(n) / SR
def ir():
    x = rng.uniform(-1, 1, n) * np.exp(-tt / .42); x = lp(x, 6500) * .9 + lp(x, 1800) * .4
    for d, g in ((.011, .5), (.017, .35), (.023, .3), (.031, .25)): x[int(d * SR)] += g
    return x / np.sqrt(np.sum(x ** 2))
outL = L + fftconvolve(WL, ir())[:N] * .9; outR = R + fftconvolve(WR, ir())[:N] * .9
fo = int(.35 * SR); outL[-fo:] *= np.linspace(1, 0, fo); outR[-fo:] *= np.linspace(1, 0, fo)
st = np.stack([outL, outR], 1); st = np.tanh(st * 1.15 / np.max(np.abs(st)))  # gentle soft clip
st *= 10 ** (-1 / 20) / np.max(np.abs(st))
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((st * 32767).astype("<i2").tobytes())
print("peak dBFS", round(20 * np.log10(np.max(np.abs(st))), 2), "rms dBFS", round(20 * np.log10(np.sqrt(np.mean(st ** 2))), 1))
