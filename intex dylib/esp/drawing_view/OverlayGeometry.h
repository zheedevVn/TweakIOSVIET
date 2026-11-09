#pragma once
#include <algorithm>
#include <cmath>

namespace OverlayGeometry {
// Clip in screen space before sending geometry to Core Animation. In particular,
// a point just in front of the camera may project far beyond the screen edges.
inline bool ClipSegment(double &x0, double &y0, double &x1, double &y1,
                        double width, double height) {
    if (!std::isfinite(x0) || !std::isfinite(y0) || !std::isfinite(x1) ||
        !std::isfinite(y1) || !std::isfinite(width) || !std::isfinite(height) ||
        width <= 0 || height <= 0) return false;
    const double dx = x1 - x0, dy = y1 - y0;
    if (!std::isfinite(dx) || !std::isfinite(dy)) return false;
    double begin = 0, end = 1;
    auto clip = [&](double p, double q) {
        if (p == 0) return q >= 0;
        const double r = q / p;
        if (p < 0) begin = std::max(begin, r);
        else end = std::min(end, r);
        return begin <= end;
    };
    if (!clip(-dx, x0) || !clip(dx, width - x0) ||
        !clip(-dy, y0) || !clip(dy, height - y0)) return false;
    x1 = std::max(0.0, std::min(width, x0 + end * dx));
    y1 = std::max(0.0, std::min(height, y0 + end * dy));
    x0 = std::max(0.0, std::min(width, x0 + begin * dx));
    y0 = std::max(0.0, std::min(height, y0 + begin * dy));
    return true;
}
}
