#ifndef ZOKER_PRESENTATION_POLICY_H
#define ZOKER_PRESENTATION_POLICY_H

#include <stdbool.h>
#include <math.h>

// UIKit and the portable regression suite consume this same policy. No physics
// state lives here; time comes exclusively from the main display loop.
// 0.29 (owner: shorter wait after the balls stop): rest window 0.5 -> 0.3 s, return guard 0.45 -> 0.3 s.
// 0.3 s is a whole number of frames at 30/60/120 Hz, so the deadline is display-rate independent.
#define BL_SHOT_READY_SECONDS 0.3
#define BL_SHOT_RETURN_SECONDS 0.3
typedef struct {
    bool pending;
    double stableSeconds;
    double returnSeconds;
} BLShotCameraState;

static inline void BLShotCameraReset(BLShotCameraState *state) {
    state->pending = false;
    state->stableSeconds = 0;
    state->returnSeconds = 0;
}

static inline void BLShotCameraStart(BLShotCameraState *state) {
    BLShotCameraReset(state);
    state->pending = true;
}

static inline bool BLShotCameraBusy(BLShotCameraState state) {
    return state.pending || state.returnSeconds > 0;
}

// Returns true exactly once after 0.5 s of uninterrupted rest. This is an
// input-ready gate, not a request to change camera pose. Replay, spectator,
// editing, pocket animation and active camera gestures defer readiness.
static inline bool BLShotCameraTick(BLShotCameraState *state, double dt,
                                    bool moving, bool pocketsActive,
                                    bool replaying, bool localTurn, bool editing,
                                    bool cameraGestureActive) {
    if (!isfinite(dt) || dt <= 0) return false;
    dt = fmin(dt, 0.1); // Never consume a background/resume gap as stable time.
    if (replaying || !localTurn || editing) {
        state->stableSeconds = 0;
        return false;
    }
    if (state->returnSeconds > 0) {
        state->returnSeconds = fmax(0, state->returnSeconds - dt);
        return false;
    }
    if (!state->pending) return false;
    if (moving || pocketsActive || cameraGestureActive) {
        state->stableSeconds = 0;
        return false;
    }
    state->stableSeconds += dt;
    if (state->stableSeconds + 1e-9 < BL_SHOT_READY_SECONDS) return false;
    state->pending = false;
    state->stableSeconds = 0;
    state->returnSeconds = BL_SHOT_RETURN_SECONDS;
    return true;
}

static inline bool BLStrokeAllowed(bool localTurn, bool busy, bool menuOpen,
                                    bool spinExpanded, bool editing, bool cuePlayable) {
    (void)spinExpanded;   // 0.30b: the effect ball IS the lock — holding it must allow the stroke
    return localTurn && !busy && !menuOpen && !editing && cuePlayable;
}

// Incremental smoothstep weight: repeated interpolation reaches the destination
// at the stated deadline instead of exponential easing followed by a snap.
static inline double BLCameraTweenBlend(double remaining, double dt, double duration) {
    if (remaining <= 0 || duration <= 0) return 1;
    if (!isfinite(dt) || dt <= 0) return 0;
    double a = fmax(0, fmin(1, 1 - remaining / duration));
    double b = fmax(0, fmin(1, 1 - fmax(0, remaining - dt) / duration));
    a = a*a*(3-2*a);
    b = b*b*(3-2*b);
    return a >= 1-1e-12 ? 1 : fmax(0, fmin(1, (b-a)/(1-a)));
}

typedef struct {
    double spinSize;
    double railBottomInset;
} BLRightHUDMetrics;

// Premium Classic: four 44-point right shortcuts above elevation/effect.
// Coach sits above B on the left; native runtime probes verify the actual frames.
#define BL_HUD_EDGE 6.0
#define BL_HUD_BOTTOM 8.0
#define BL_HUD_RAIL_WIDTH 56.0
#define BL_HUD_RAIL_ITEMS 4
#define BL_HUD_BUTTON_HEIGHT 44.0
#define BL_HUD_BUTTON_GAP 2.0
#define BL_HUD_COACH_HEIGHT 44.0
#define BL_HUD_COACH_GAP 4.0
#define BL_HUD_ELEVATION_WIDTH 44.0
#define BL_HUD_ELEVATION_HEIGHT 96.0
static inline double BLHUDRailHeight(void) {
    return BL_HUD_RAIL_ITEMS * BL_HUD_BUTTON_HEIGHT +
           (BL_HUD_RAIL_ITEMS - 1) * BL_HUD_BUTTON_GAP;
}
static inline double BLHUDVisibleRailHeight(double safeHeight) {
    (void)safeHeight; return BLHUDRailHeight();
}
// Enlarging effect grows left/upward; it never covers the vertical controls.
static inline BLRightHUDMetrics BLRightHUDLayout(double safeHeight, bool expanded) {
    BLRightHUDMetrics result;
    result.spinSize = expanded ? fmax(52, fmin(170, safeHeight - 120)) : 52;
    result.railBottomInset = BL_HUD_BOTTOM;
    return result;
}


// ---- 0.30b HUD (owner acceptance of 0.30 build 103, 04/11/2026) ----------------------------------------------------
// Right-handed (default):
//   bottom-left : effect ball, the 4 cue icons (Đánh · Jump · Massé · Break) in a row above it
//   right edge  : shortcut column, top to bottom Xem lại · Lùi cú (practice) · Đặt bi · Thêm bi · Bao cơ · Camera
//   bottom-right: horizontal fine-aim wheel left of the column, elevation fan on top of the wheel
//   top-left    : Menu + Coach
// Touching the effect ball latches the aim lock (no B); then everything except the effect ball and the wheel hides
// and a stroke anywhere on the empty table fires. Left-handed mirrors every x.
typedef struct { double x, y, w, h; } BLRect;
typedef struct {
    BLRect rail, spin, wheel, elevation, menu, coach, panel, cues, lock;   // lock = B (0.36)
    double button;      // shortcut button height (also its width minus padding)
    double cueIcon;     // side of one cue icon square
    int items;          // shortcut count
    int railScrolls;    // 1 when the column is shorter than its content (scroll to reveal)
} BLHUDFrames;

static inline BLRect BLRectMake(double x, double y, double w, double h) { BLRect r; r.x = x; r.y = y; r.w = w; r.h = h; return r; }
static inline BLRect BLMirror(BLRect r, double x0, double w) { BLRect m = r; m.x = x0 + w - (r.x - x0) - r.w; return m; }
#define BL_CUE_ICONS 4

static inline BLHUDFrames BLHUDLayout(double x0, double y0, double w, double h, int pad, int leftHanded, int practice, int expanded) {
    BLHUDFrames f;
    const double edge = 6, gap = pad ? 10 : 8, bh = pad ? 56 : 44, bgap = 4, railW = pad ? 64 : 54;
    const double spinS = pad ? 100 : 76, fanS = pad ? 84 : 64, wheelW = pad ? 192 : 148, wheelH = pad ? 48 : 40, icon = pad ? 52 : 44, igap = 4;
    f.items = practice ? 6 : 5; f.button = bh; f.cueIcon = icon;
    const double content = f.items * bh + (f.items - 1) * bgap;
    const double railH = fmin(content, h - 2 * edge);
    f.railScrolls = railH + 1e-9 < content;
    const double bottom = y0 + h - edge;
    f.rail = BLRectMake(x0 + w - edge - railW, bottom - railH, railW, railH);
    f.wheel = BLRectMake(f.rail.x - gap - wheelW, bottom - wheelH, wheelW, wheelH);
    f.elevation = BLRectMake(f.wheel.x + (wheelW - fanS) / 2, f.wheel.y - gap - fanS, fanS, fanS);
    // 0.36 (owner): bottom-left cluster = a row of the 4 cue icons on top; below it the square B (outer side) and
    // the round effect ball next to it. The pair is centred under the row.
    const double lockS = pad ? 72 : 56, clusterX = x0 + edge;
    const double rowW = BL_CUE_ICONS * icon + (BL_CUE_ICONS - 1) * igap, pairW = lockS + gap + spinS;
    const double width = fmax(rowW, pairW), pairX = clusterX + (width - pairW) / 2;
    f.lock = BLRectMake(pairX, bottom - spinS + (spinS - lockS) / 2, lockS, lockS);
    f.spin = BLRectMake(pairX + lockS + gap, bottom - spinS, spinS, spinS);
    f.cues = BLRectMake(clusterX + (width - rowW) / 2, f.spin.y - gap - icon, rowW, icon);
    if (expanded) {   // grows up/right from the bottom-left corner: big enough to aim, not hiding the table
        const double big = fmax(spinS, fmin(pad ? 200 : 150, bottom - (y0 + edge + 50)));
        f.spin = BLRectMake(f.spin.x, bottom - big, big, big);
    }
    f.menu = BLRectMake(x0 + 12, y0 + 10, pad ? 92 : 78, 44);
    f.coach = BLRectMake(f.menu.x + f.menu.w + 8, y0 + 10, pad ? 92 : 76, 44);
    f.panel = BLRectMake(f.menu.x, f.menu.y + f.menu.h + 8, pad ? 360 : 318, h - (f.menu.h + 8 + 10) - 12);
    if (leftHanded) {
        f.rail = BLMirror(f.rail, x0, w); f.spin = BLMirror(f.spin, x0, w); f.wheel = BLMirror(f.wheel, x0, w);
        f.elevation = BLMirror(f.elevation, x0, w); f.menu = BLMirror(f.menu, x0, w); f.coach = BLMirror(f.coach, x0, w);
        f.panel = BLMirror(f.panel, x0, w); f.cues = BLMirror(f.cues, x0, w); f.lock = BLMirror(f.lock, x0, w);
    }
    return f;
}

// Cue icon k (0 Đánh, 1 Jump, 2 Massé, 3 Break) in one row inside f.cues, left to right in that order (0.36);
// same reading order in both hands, the row itself mirrors.
static inline BLRect BLHUDCueIcon(BLHUDFrames f, int k) {
    const double s = f.cueIcon, step = (f.cues.w - s) / (BL_CUE_ICONS - 1);
    return BLRectMake(f.cues.x + k * step, f.cues.y, s, s);
}
// Icon order -> shot kind (ShotKindPolicy: 0 play, 1 jump, 2 break, 3 massé) and its default elevation (deg).
static inline int BLCueIconKind(int k) { return k == 1 ? 1 : (k == 2 ? 3 : (k == 3 ? 2 : 0)); }
static inline double BLCueIconElevation(int k) { return k == 1 ? 45.0 : (k == 2 ? 70.0 : 0.0); }

// 0.30 elevation fan: quarter circle, pivot at the bottom corner nearest the effect ball side opposite
// (bottom-left for right hand). Touch angle above the horizontal = cue elevation, 0-90 deg, whole degrees.
static inline double BLFanDegrees(double px, double py, double w, double h, int leftHanded) {
    const double dx = leftHanded ? (w - px) : px, dy = h - py;
    if (dx <= 0 && dy <= 0) return 0;
    double a = atan2(fmax(0.0, dy), fmax(0.0, dx)) * 180 / 3.14159265358979323846;
    return fmin(90.0, fmax(0.0, round(a)));
}

// 0.22 "Đặt bi": the cue ball goes to the free spot nearest the table centre (never on top of another ball).
// Searches rings of radius step R/2 outward; returns 1 and the spot, 0 if the table is full.
static inline int BLFreeSpotNearCentre(const double *xs, const double *ys, int n, double radius,
                                       double halfWidth, double halfLength, double *outX, double *outY) {
    const double clear = 2 * radius + 0.004, step = radius / 2;
    const double maxX = halfWidth - radius - 0.01, maxY = halfLength - radius - 0.01;
    for (int ring = 0; ring * step <= maxY + step; ++ring) {
        const double r = ring * step;
        const int samples = ring == 0 ? 1 : (int)ceil(2 * 3.14159265358979323846 * r / step);
        for (int k = 0; k < samples; ++k) {
            const double a = samples == 1 ? 0 : 2 * 3.14159265358979323846 * k / samples;
            const double x = r * cos(a), y = r * sin(a);
            if (fabs(x) > maxX || fabs(y) > maxY) continue;
            int ok = 1;
            for (int j = 0; j < n && ok; ++j) if (hypot(xs[j] - x, ys[j] - y) < clear) ok = 0;
            if (ok) { *outX = x; *outY = y; return 1; }
        }
    }
    return 0;
}

// 0.29 race-to-N scoreboard (owner: agree the number of racks before the match, show the score like a pro
// broadcast). Returns the match winner (0/1) or -1 while the match continues. Alternate break (WPA default for
// 9/10-ball race play): the next rack is broken by the player who did not break this one.
static inline int BLRaceRecordRack(int *frames0, int *frames1, int raceTo, int rackWinner) {
    if (raceTo < 1) raceTo = 1;
    if (rackWinner == 0) ++*frames0; else if (rackWinner == 1) ++*frames1;
    if (*frames0 >= raceTo) return 0;
    if (*frames1 >= raceTo) return 1;
    return -1;
}
static inline int BLRaceNextBreaker(int lastBreaker) { return lastBreaker == 0 ? 1 : 0; }
static inline int BLRaceClamp(int raceTo) { return raceTo < 1 ? 1 : (raceTo > 25 ? 25 : raceTo); }

#endif
