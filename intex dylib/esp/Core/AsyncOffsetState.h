#pragma once
#include <cstdint>

// Accessed only on the main queue. Pending reads return immediately and only
// one request per key can be in flight, even when called on every frame.
struct AsyncOffsetState {
    uintptr_t value = 0;
    bool pending = false;
    double retryAt = 0;
    bool begin(double now) {
        if (value || pending || now < retryAt) return false;
        pending = true;
        return true;
    }
    void finish(uintptr_t result, double now) {
        value = result;
        pending = false;
        retryAt = result ? 0 : now + 10.0;
    }
};
