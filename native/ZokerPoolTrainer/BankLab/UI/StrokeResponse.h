#ifndef ZOKER_STROKE_RESPONSE_H
#define ZOKER_STROKE_RESPONSE_H
#include <math.h>
// Input is UIKit points/second, independent of touch callback/display frequency.
// Normalise to the short screen edge so phone/tablet strokes have comparable feel.
static inline double BLStrokeSpeed(double velocity, double shortEdge, double sensitivity) {
    if (!isfinite(velocity) || !isfinite(shortEdge) || !isfinite(sensitivity) || velocity <= 0 || shortEdge <= 0) return 0;
    double amount = fmin(1, velocity * fmax(.4, fmin(2, sensitivity)) / (fmax(240, shortEdge) * 5));
    return 8 * pow(amount, 1.15);
}
#endif
