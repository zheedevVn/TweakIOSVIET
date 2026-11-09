#pragma once
#define AUTO_PAGE 0x4000
#define AUTO_EFFECT_ENTRY 16
#define AUTO_TRACER_ENTRY 32
#define AUTO_SHOT_ENTRY 48
#define AUTO_ORIGINAL 0
#define AUTO_CLOCK 8
#define AUTO_GET_WEAPON 16
#define AUTO_START 24
#define AUTO_STOP 32
#define AUTO_SEQUENCE 40
#define AUTO_ENABLED 44
#define AUTO_DEADLINE 48
#define AUTO_LOCAL 56
#define AUTO_MATCH 64
#define AUTO_WEAPON 72
#define AUTO_HELD 80
#define AUTO_BUSY 88
#define AUTO_STARTS 96
#define AUTO_MAGIC 104
#define AUTO_TICKS 112
#define AUTO_INTERVAL 120
#define AUTO_ELAPSED 128
#define AUTO_SILENT_GATE 136
#define AUTO_EFFECT_ORIGINAL 144
#define AUTO_EFFECT_SKIPS 152
#define AUTO_TRACER_ORIGINAL 160
#define AUTO_TRACER_SKIPS 168
#define AUTO_METADATA_INIT 176
#define AUTO_TRACER_TYPEINFO 184
#define AUTO_METADATA_READY 192
#define AUTO_SHOT_ORIGINAL 200
#define AUTO_SHOT_SKIPS 208
#define AUTO_SHOT_HIT 216
#define AUTO_PRESENTATION 224
#define AUTO_SWAP_ENABLED 228
#define AUTO_SWAP_ELAPSED 232
#define AUTO_SWAP_FUNCTION 240
#define AUTO_SWAP_SLOT 248
#define AUTO_SWAP_WEAPON 256
#define AUTO_SWAP_COOLDOWN 264
#define AUTO_RAYCAST 272
#define AUTO_HIT_COLLIDER 280
#define AUTO_COMPONENT_TRANSFORM 288
#define AUTO_IS_CHILD 296
#define AUTO_ROOT_TRANSFORM 304
#define AUTO_TARGET 312
#define AUTO_ORIGIN 320
#define AUTO_HEAD 332
#define AUTO_BODY 344
#define AUTO_HEAD_PERCENT 356
#ifndef __ASSEMBLER__
#include <cstddef>
#include <cstdint>
namespace AutoFireRemote {
inline constexpr uint64_t Magic = 0x4155544f46495245ULL; // AUTOFIRE: native physics visibility
struct Point { float x=0, y=0, z=0; };
struct Aim { uint64_t target=0; Point origin{}, head{}, body{}; uint32_t headPercent=100; };
struct State {
    uint64_t original=0, clock=0, getter=0, start=0, stop=0;
    uint32_t sequence=0, enabled=0;
    uint64_t deadline=0, local=0, match=0, weapon=0, held=0;
    uint32_t busy=0, padding=0;
    uint64_t starts=0, magic=Magic, ticks=0;
    uint64_t interval=0;
    float elapsed=0;
    uint32_t reserved=0;
    uint64_t silentGate=0;
    uint64_t effectOriginal=0, effectSkips=0;
    uint64_t tracerOriginal=0, tracerSkips=0, metadataInit=0, tracerTypeInfo=0;
    uint32_t metadataReady=0, padding2=0;
    uint64_t shotOriginal=0, shotSkips=0, shotHit=0;
    uint32_t presentation=0, swapEnabled=0;
    float swapElapsed=0;
    uint32_t padding3=0;
    uint64_t swapFunction=0;
    uint32_t swapSlot=0, padding4=0;
    uint64_t swapWeapon=0;
    uint64_t swapCooldown=0;
    uint64_t raycast=0, hitCollider=0, componentTransform=0, isChild=0, rootTransform=0;
    Aim aim{};
};
static_assert(offsetof(State, sequence)==AUTO_SEQUENCE);
static_assert(offsetof(State, enabled)==AUTO_ENABLED);
static_assert(offsetof(State, held)==AUTO_HELD);
static_assert(offsetof(State, starts)==AUTO_STARTS);
static_assert(offsetof(State, magic)==AUTO_MAGIC);
static_assert(offsetof(State, ticks)==AUTO_TICKS);
static_assert(offsetof(State, interval)==AUTO_INTERVAL);
static_assert(offsetof(State, elapsed)==AUTO_ELAPSED);
static_assert(offsetof(State, silentGate)==AUTO_SILENT_GATE);
static_assert(offsetof(State, effectOriginal)==AUTO_EFFECT_ORIGINAL);
static_assert(offsetof(State, effectSkips)==AUTO_EFFECT_SKIPS);
static_assert(offsetof(State, tracerOriginal)==AUTO_TRACER_ORIGINAL);
static_assert(offsetof(State, tracerSkips)==AUTO_TRACER_SKIPS);
static_assert(offsetof(State, metadataInit)==AUTO_METADATA_INIT);
static_assert(offsetof(State, tracerTypeInfo)==AUTO_TRACER_TYPEINFO);
static_assert(offsetof(State, metadataReady)==AUTO_METADATA_READY);
static_assert(offsetof(State, shotOriginal)==AUTO_SHOT_ORIGINAL);
static_assert(offsetof(State, shotSkips)==AUTO_SHOT_SKIPS);
static_assert(offsetof(State, shotHit)==AUTO_SHOT_HIT);
static_assert(offsetof(State, presentation)==AUTO_PRESENTATION);
static_assert(offsetof(State, swapElapsed)==AUTO_SWAP_ELAPSED);
static_assert(offsetof(State, swapFunction)==AUTO_SWAP_FUNCTION);
static_assert(offsetof(State, swapSlot)==AUTO_SWAP_SLOT);
static_assert(offsetof(State, swapWeapon)==AUTO_SWAP_WEAPON);
static_assert(offsetof(State, swapCooldown)==AUTO_SWAP_COOLDOWN);
static_assert(offsetof(State, raycast)==AUTO_RAYCAST);
static_assert(offsetof(State, hitCollider)==AUTO_HIT_COLLIDER);
static_assert(offsetof(State, componentTransform)==AUTO_COMPONENT_TRANSFORM);
static_assert(offsetof(State, isChild)==AUTO_IS_CHILD);
static_assert(offsetof(State, rootTransform)==AUTO_ROOT_TRANSFORM);
static_assert(offsetof(State, aim)==AUTO_TARGET);
static_assert(offsetof(State, aim)+offsetof(Aim, origin)==AUTO_ORIGIN);
static_assert(offsetof(State, aim)+offsetof(Aim, head)==AUTO_HEAD);
static_assert(offsetof(State, aim)+offsetof(Aim, body)==AUTO_BODY);
static_assert(offsetof(State, aim)+offsetof(Aim, headPercent)==AUTO_HEAD_PERCENT);
}
#endif
