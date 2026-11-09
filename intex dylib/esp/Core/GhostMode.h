#pragma once
#include <cstdint>
#include "Vector3.h"
struct GhostModeSnapshot {
    bool active = false;
    uint32_t status = 1;
    uint64_t match = 0, local = 0, ticks = 0, packets = 0, axes = 0, returns = 0;
    Vector3 anchor{};
};
void GhostModeSetEnabled(bool enabled);
void GhostModeCancel(); // Invalidate context without teleporting an old player.
int GhostModeUpdate(uint64_t module);
GhostModeSnapshot GhostModeRead();
