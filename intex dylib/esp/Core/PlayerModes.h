#pragma once
#include <cstdint>
struct PlayerModesSnapshot {
    uint64_t ticks=0, postTicks=0, applies=0, restores=0, failedOffset=0;
    uint64_t lateTicks=0, spinApplies=0;
    uint32_t spinStatus=0;
    uint32_t fly=0, heldEnemies=0, skipped=0;
    bool running=false, presenting=false, scoped=false, fakeLag=false;
    float height=3.0f;
    const char *detail="";
};
void PlayerModesSetEnabled(bool fly, bool aimLag, bool fakeLag, float height);
void PlayerModesSetSpin(bool enabled,float turnsPerSecond);
void PlayerModesCancel();
int PlayerModesUpdate(uint64_t module);
PlayerModesSnapshot PlayerModesRead();
