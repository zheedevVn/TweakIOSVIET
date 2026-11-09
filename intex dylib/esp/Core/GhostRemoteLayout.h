#pragma once
#define GHOST_PAGE 0x4000
#define GHOST_POSITION_ENTRY 0x1000
#define GHOST_AXIS_ENTRY 0x2000
#define GHOST_TICK 0
#define GHOST_POSITION 8
#define GHOST_AXIS 16
#define GHOST_CLOCK 24
#define GHOST_CURRENT_MATCH 32
#define GHOST_GET_POS 40
#define GHOST_SET_POS 48
#define GHOST_HP 56
#define GHOST_WAIT_SYNC 64
#define GHOST_VEHICLE 72
#define GHOST_CATAPULT 80
#define GHOST_CANNON 88
#define GHOST_CHAIR 96
#define GHOST_CHAIR_ALT 104
#define GHOST_PARACHUTE 112
#define GHOST_SEQUENCE 120
#define GHOST_COMMAND 124
#define GHOST_DEADLINE 128
#define GHOST_MATCH 136
#define GHOST_LOCAL 144
#define GHOST_PACKET 152
#define GHOST_AXIS_PACKET 160
#define GHOST_BODY_CLASS 168
#define GHOST_POS_CLASS 176
#define GHOST_VEL_CLASS 184
#define GHOST_AXIS_CLASS 192
#define GHOST_EPOCH 200
#define GHOST_OUT_SEQUENCE 208
#define GHOST_ACTIVE 212
#define GHOST_ANCHOR_MATCH 216
#define GHOST_ANCHOR_LOCAL 224
#define GHOST_ANCHOR_EPOCH 232
#define GHOST_POSE_CAPTURED 236
#define GHOST_ANCHOR 240
#define GHOST_ENCODED 256
#define GHOST_POSE 268
#define GHOST_TICKS 272
#define GHOST_PACKETS 280
#define GHOST_AXES 288
#define GHOST_RETURNS 296
#define GHOST_STATUS 304
#define GHOST_BUSY 308
#define GHOST_MAGIC 312
#define GHOST_STROP 320
#define GHOST_RAIL 328
#define GHOST_SEESAW 336
#define GHOST_PLATFORM 344
#ifndef __ASSEMBLER__
#include <cstddef>
#include <cstdint>
namespace GhostRemote {
constexpr uint64_t Magic = 0x47484f5354303031ULL;
struct State {
    uint64_t tick=0, position=0, axis=0, clock=0, currentMatch=0, getPos=0, setPos=0, hp=0;
    uint64_t waitSync=0, vehicle=0, catapult=0, cannon=0, chair=0, chairAlt=0, parachute=0;
    uint32_t sequence=0, command=0; // 0 cancel, 1 enable, 2 return once
    uint64_t deadline=0, match=0, local=0, packet=0, axisPacket=0;
    uint64_t bodyClass=0, posClass=0, velClass=0, axisClass=0;
    uint32_t epoch=0, padding=0;
    uint32_t outSequence=0, active=0;
    uint64_t anchorMatch=0, anchorLocal=0;
    uint32_t anchorEpoch=0, poseCaptured=0;
    float anchor[3]={}; uint32_t padding2=0;
    int32_t encoded[3]={}; uint32_t pose=0;
    uint64_t ticks=0, packets=0, axes=0, returns=0;
    uint32_t status=1, busy=0;
    uint64_t magic=Magic;
    uint64_t strop=0, rail=0, seesaw=0, platform=0;
};
#define GHOST_CHECK(field, offset) static_assert(offsetof(State, field)==offset)
GHOST_CHECK(tick,GHOST_TICK); GHOST_CHECK(position,GHOST_POSITION); GHOST_CHECK(axis,GHOST_AXIS);
GHOST_CHECK(clock,GHOST_CLOCK); GHOST_CHECK(currentMatch,GHOST_CURRENT_MATCH);
GHOST_CHECK(getPos,GHOST_GET_POS); GHOST_CHECK(setPos,GHOST_SET_POS); GHOST_CHECK(hp,GHOST_HP);
GHOST_CHECK(waitSync,GHOST_WAIT_SYNC); GHOST_CHECK(vehicle,GHOST_VEHICLE);
GHOST_CHECK(catapult,GHOST_CATAPULT); GHOST_CHECK(cannon,GHOST_CANNON);
GHOST_CHECK(chair,GHOST_CHAIR); GHOST_CHECK(chairAlt,GHOST_CHAIR_ALT);
GHOST_CHECK(sequence,GHOST_SEQUENCE); GHOST_CHECK(command,GHOST_COMMAND);
GHOST_CHECK(deadline,GHOST_DEADLINE); GHOST_CHECK(match,GHOST_MATCH); GHOST_CHECK(local,GHOST_LOCAL);
GHOST_CHECK(packet,GHOST_PACKET); GHOST_CHECK(axisPacket,GHOST_AXIS_PACKET);
GHOST_CHECK(bodyClass,GHOST_BODY_CLASS); GHOST_CHECK(posClass,GHOST_POS_CLASS);
GHOST_CHECK(velClass,GHOST_VEL_CLASS); GHOST_CHECK(axisClass,GHOST_AXIS_CLASS); GHOST_CHECK(epoch,GHOST_EPOCH);
GHOST_CHECK(outSequence,GHOST_OUT_SEQUENCE); GHOST_CHECK(active,GHOST_ACTIVE);
GHOST_CHECK(anchorMatch,GHOST_ANCHOR_MATCH); GHOST_CHECK(anchorLocal,GHOST_ANCHOR_LOCAL);
GHOST_CHECK(anchorEpoch,GHOST_ANCHOR_EPOCH); GHOST_CHECK(poseCaptured,GHOST_POSE_CAPTURED);
GHOST_CHECK(anchor,GHOST_ANCHOR); GHOST_CHECK(encoded,GHOST_ENCODED); GHOST_CHECK(pose,GHOST_POSE);
GHOST_CHECK(ticks,GHOST_TICKS); GHOST_CHECK(packets,GHOST_PACKETS); GHOST_CHECK(axes,GHOST_AXES);
GHOST_CHECK(returns,GHOST_RETURNS); GHOST_CHECK(status,GHOST_STATUS); GHOST_CHECK(busy,GHOST_BUSY);
GHOST_CHECK(magic,GHOST_MAGIC); GHOST_CHECK(parachute,GHOST_PARACHUTE);
GHOST_CHECK(strop,GHOST_STROP); GHOST_CHECK(rail,GHOST_RAIL);
GHOST_CHECK(seesaw,GHOST_SEESAW); GHOST_CHECK(platform,GHOST_PLATFORM);
static_assert(sizeof(State)==352);
#undef GHOST_CHECK
}
#endif
