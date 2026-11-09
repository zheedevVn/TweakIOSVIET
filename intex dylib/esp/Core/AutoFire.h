#pragma once
#include <cstdint>
#include "Vector3.h"
// Shoot only after Silent accepts the target. Presentation and optional swaps
// stay active without a target. Native input runs on the game's update thread.
int AutoFireUpdate(uint64_t base, uint64_t match, uint64_t local, uint64_t target,
                   const Vector3 &origin, const Vector3 &head, const Vector3 &body,
                   uint32_t headPercent, bool swap=false);
void AutoFireClear();
uint64_t AutoFireStartCount();
uint64_t AutoFireTickCount();
