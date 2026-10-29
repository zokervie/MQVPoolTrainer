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

// Returns true exactly once after 0.5 s of uninterrupted rest. Replay,
// spectator, editing, pocket fall and active camera gestures defer the return.
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

// 0.17: two rows of three shortcuts at bottom-right, beside effect/elevation.
#define BL_HUD_EDGE 6.0
#define BL_HUD_RAIL_WIDTH 186.0
#define BL_HUD_RAIL_ITEMS 6
#define BL_HUD_ELEVATION_WIDTH 44.0
#define BL_HUD_ELEVATION_HEIGHT 120.0
static inline double BLHUDRailHeight(void) { return 110.0; }
// Effect pad lớn dần sang trái/lên trên; không bao giờ đè thanh độ dốc hay thanh phím tắt.
static inline BLRightHUDMetrics BLRightHUDLayout(double safeHeight, bool expanded) {
    BLRightHUDMetrics result;
    result.spinSize = expanded ? fmax(78, fmin(190, safeHeight - 130)) : 78;
    result.railBottomInset = 20 + fmax(120, result.spinSize);
    return result;
}

#endif

