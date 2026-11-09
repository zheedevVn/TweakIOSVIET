#pragma once
#include <cmath>
#include <cstdint>

// Wait for one unchanged, active host window before attaching another window.
// Rotation, a scene transition or backgrounding starts the interval again.
namespace InjectedStartup {
class Gate {
    uintptr_t window_=0;
    double width_=0, height_=0, since_=0, previous_=0;
public:
    bool ready(bool active, bool attached, uintptr_t window, double width, double height, double now) {
        if (!active || !attached || !window || !std::isfinite(width) || !std::isfinite(height) ||
            !std::isfinite(now) || width<=0 || height<=0) { window_=0; return false; }
        if (window_!=window || width_!=width || height_!=height || now<previous_) {
            window_=window; width_=width; height_=height; since_=now;
        }
        previous_=now;
        return now-since_>=0.75;
    }
};
}
