#!/usr/bin/env python3
"""0.44-mm: judder score of what the renderer drew (Documents/perf-qa/*.json from a --perf-qa run).

For every moving ball, the drawn step per refresh should change slowly (the solver's speed changes slowly except at
impacts, which hit live and replay equally because both segments show the same shot). A frame is JUDDER when its step,
normalised by the number of refreshes it spans, is < 0.5x or > 1.5x the mean of its two neighbours; REPEAT when a ball
moving > 1 mm/refresh is drawn at the same place twice. Camera judder uses the same rule on the camera position.
Also summarises main-thread CPU per tick (ms). Usage: perf_judder.py FILE... [--json]
"""
import json, sys, statistics


def pct(values, q):
    if not values:
        return 0.0
    v = sorted(values)
    return v[min(len(v) - 1, int(len(v) * q))]


def step_series(frames, key):
    """Per-frame (time, position) for one track; None where the track is absent."""
    out = []
    for f in frames:
        p = f['camera'] if key == 'camera' else f['balls'].get(key)
        out.append((f['t'], p))
    return out


def judder(frames, period):
    moving = judders = repeats = 0
    ratios = []
    keys = sorted({k for f in frames for k in f['balls']}) + ['camera']
    per_track = {}
    for key in keys:
        series = step_series(frames, key)
        steps = []  # (normalised step m/refresh, refreshes spanned)
        for (t0, p0), (t1, p1) in zip(series, series[1:]):
            if p0 is None or p1 is None:
                steps.append(None)
                continue
            n = max(1, round((t1 - t0) / period))
            d = ((p1[0] - p0[0]) ** 2 + (p1[1] - p0[1]) ** 2 + (p1[2] - p0[2]) ** 2) ** 0.5
            steps.append(d / n)
        tm = tj = tr = 0
        for i in range(1, len(steps) - 1):
            a, b, c = steps[i - 1], steps[i], steps[i + 1]
            if a is None or b is None or c is None:
                continue
            ref = (a + c) / 2
            if ref < 0.001:  # < 1 mm per refresh: not moving enough to judge
                continue
            tm += 1
            r = b / ref
            ratios.append(abs(r - 1))
            if b < 0.0001:
                tr += 1
            if r < 0.5 or r > 1.5:
                tj += 1
        moving += tm; judders += tj; repeats += tr
        if tm:
            per_track[key] = {'moving': tm, 'judder': tj, 'repeat': tr}
    return {'movingFrames': moving, 'judderFrames': judders, 'repeatFrames': repeats,
            'judderPct': round(100.0 * judders / moving, 2) if moving else 0.0,
            'stepErrorP95': round(pct(ratios, 0.95), 3), 'tracks': per_track}


def summarise(path):
    r = json.load(open(path))
    frames = r['frames']
    period = 1.0 / r.get('frameRate', 60)
    intervals = [b['t'] - a['t'] for a, b in zip(frames, frames[1:]) if b['t'] > a['t']]
    missed = sum(1 for x in intervals if x > 1.5 * period)
    ms = lambda v: {'p50': round(pct(v, 0.5) * 1000, 2), 'p95': round(pct(v, 0.95) * 1000, 2), 'max': round(max(v) * 1000, 2) if v else 0}
    out = {'file': path.split('/')[-1], 'kind': r['kind'], 'renderFrames': len(frames), 'missedRefresh': missed,
           'renderIntervalMs': ms(intervals), 'tickCpuMs': ms(r['tick']), 'matchCpuMs': ms(r['match']),
           'motionCpuMs': ms(r['motion']), 'cameraCpuMs': ms(r['camera']), 'audioCpuMs': ms(r['audio']),
           'audioCalls': r['audioCalls'], 'tickDtMs': ms([d for d in r['dt'] if d > 0]),
           'layoutPasses': r['layoutPasses'], 'hudRelayouts': r['hudRelayouts'], 'pacing': r.get('pacing')}
    out.update(judder(frames, period))
    return out


def main(argv):
    as_json = '--json' in argv
    rows = [summarise(p) for p in argv if not p.startswith('--')]
    if as_json:
        print(json.dumps(rows, indent=1))
        return 0
    for s in rows:
        print('%-22s render=%d missed=%d judder=%.2f%% repeat=%d stepErrP95=%.3f | tick p50/p95/max %s/%s/%s ms | motion p95 %s | match p95 %s | audio p95 %s (%d) | layout %d/%d' % (
            s['file'], s['renderFrames'], s['missedRefresh'], s['judderPct'], s['repeatFrames'], s['stepErrorP95'],
            s['tickCpuMs']['p50'], s['tickCpuMs']['p95'], s['tickCpuMs']['max'], s['motionCpuMs']['p95'],
            s['matchCpuMs']['p95'], s['audioCpuMs']['p95'], s['audioCalls'], s['layoutPasses'], s['hudRelayouts']))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
