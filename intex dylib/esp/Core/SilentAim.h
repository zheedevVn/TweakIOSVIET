#pragma once
#include <cstdint>
#include "Vector3.h"

// Returns a diagnostic state, not confirmation that a bullet hit its target.
void SilentAimSetEnabled(bool enabled);
void SilentAimClearTarget(void);
int SilentAimUpdate(uint64_t moduleBase, uint64_t match, uint64_t local,
                    uint64_t target, const Vector3 &head, const Vector3 &body, uint32_t headPercent);
uint64_t SilentAimRedirectCount(void);
// Address in the game task of a scoped, weapon-specific automatic-shot marker.
// AutoFire writes it only around a native shot call, then clears it.
uint64_t SilentAimAutoFireGate(void);
struct SilentAimFailure {
    const char *operation = "";
    int code = 0;
};
SilentAimFailure SilentAimLastFailure(void);
