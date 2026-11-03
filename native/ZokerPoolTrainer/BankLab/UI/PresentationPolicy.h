#ifndef ZOKER_PRESENTATION_POLICY_H
#define ZOKER_PRESENTATION_POLICY_H

#include <stdbool.h>
#include <math.h>

// UIKit and the portable regression suite consume this same policy. No physics
// state lives here; time comes exclusively from the main display loop.
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
    if (state->stableSeconds + 1e-9 < 0.5) return false;
    state->pending = false;
    state->stableSeconds = 0;
    state->returnSeconds = 0.45;
    return true;
}

static inline bool BLStrokeAllowed(bool localTurn, bool busy, bool menuOpen,
                                    bool spinExpanded, bool editing, bool cuePlayable) {
    return localTurn && !busy && !menuOpen && !spinExpanded && !editing && cuePlayable;
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


// ---- 0.22 HUD (owner acceptance 03/11/2026) -------------------------------------------------------------------
// Thumb-first landscape layout. Right-handed (default): shortcut column on the right edge, top to bottom
// Xem lại · Lùi cú (practice only) · Đặt bi · Thêm bi · Bao cơ · Camera, bottom-aligned so the most used (Camera)
// sits under the thumb. Left of the column, bottom: elevation | effect ball, fine-aim wheel under the effect ball.
// Menu + Coach top-left, B (bridge/lock) bottom-left. Left-handed mirrors every x. All rects are in the safe area.
typedef struct { double x, y, w, h; } BLRect;
typedef struct {
    BLRect rail, spin, wheel, elevation, menu, coach, bridge, panel;
    double button;      // shortcut button height (also its width minus padding)
    int items;          // shortcut count
    int railScrolls;    // 1 when the column is shorter than its content (scroll to reveal)
} BLHUDFrames;

static inline BLRect BLRectMake(double x, double y, double w, double h) { BLRect r; r.x = x; r.y = y; r.w = w; r.h = h; return r; }
static inline BLRect BLMirror(BLRect r, double x0, double w) { BLRect m = r; m.x = x0 + w - (r.x - x0) - r.w; return m; }

static inline BLHUDFrames BLHUDLayout(double x0, double y0, double w, double h, int pad, int leftHanded, int practice, int expanded) {
    BLHUDFrames f;
    const double edge = 6, gap = pad ? 10 : 8, bh = pad ? 56 : 44, bgap = 4, railW = pad ? 64 : 54;
    const double spinS = pad ? 100 : 76, elevW = pad ? 52 : 44, elevH = pad ? 120 : 96;
    const double wheelW = pad ? 124 : 100, wheelH = pad ? 48 : 40, bridgeS = pad ? 92 : 72;
    f.items = practice ? 6 : 5; f.button = bh;
    const double content = f.items * bh + (f.items - 1) * bgap;
    const double railH = fmin(content, h - 2 * edge);
    f.railScrolls = railH + 1e-9 < content;
    f.rail = BLRectMake(x0 + w - edge - railW, y0 + h - edge - railH, railW, railH);
    const double clusterRight = f.rail.x - gap;
    f.wheel = BLRectMake(clusterRight - spinS / 2 - wheelW / 2, y0 + h - edge - wheelH, wheelW, wheelH);
    if (f.wheel.x + f.wheel.w > clusterRight) f.wheel.x = clusterRight - f.wheel.w;
    f.spin = BLRectMake(clusterRight - spinS, f.wheel.y - gap - spinS, spinS, spinS);
    f.elevation = BLRectMake(f.spin.x - gap - elevW, f.spin.y + spinS - elevH, elevW, elevH);
    if (expanded) {   // grows up/left from the same bottom-right corner; elevation and wheel are hidden meanwhile
        const double big = fmax(spinS, fmin(pad ? 240 : 190, fmin(h - 2 * edge - 60, clusterRight - x0 - bridgeS - 3 * gap)));
        f.spin = BLRectMake(clusterRight - big, f.spin.y + spinS - big, big, big);
    }
    f.menu = BLRectMake(x0 + 12, y0 + 10, pad ? 92 : 78, 44);
    f.coach = BLRectMake(f.menu.x + f.menu.w + 8, y0 + 10, pad ? 92 : 76, 44);
    f.bridge = BLRectMake(x0 + 12, y0 + h - 12 - bridgeS, bridgeS, bridgeS);
    f.panel = BLRectMake(f.menu.x, f.menu.y + f.menu.h + 8, pad ? 360 : 318, h - (f.menu.h + 8 + 10) - 12);
    if (leftHanded) {
        f.rail = BLMirror(f.rail, x0, w); f.spin = BLMirror(f.spin, x0, w); f.wheel = BLMirror(f.wheel, x0, w);
        f.elevation = BLMirror(f.elevation, x0, w); f.menu = BLMirror(f.menu, x0, w); f.coach = BLMirror(f.coach, x0, w);
        f.bridge = BLMirror(f.bridge, x0, w); f.panel = BLMirror(f.panel, x0, w);
    }
    return f;
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

#endif
