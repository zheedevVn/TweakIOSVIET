#pragma once
#define MODES_PAGE 0x4000
#define MODES_POST_ENTRY 16
#define MODES_LATE_ENTRY 32
#define MODES_ORIGINAL 0
#define MODES_CLOCK 8
#define MODES_CURRENT_MATCH 16
#define MODES_GET_POS 24
#define MODES_SET_POS 32
#define MODES_HP 40
#define MODES_VEHICLE 48
#define MODES_PARACHUTE 56
#define MODES_WAIT_SYNC 64
#define MODES_SEQUENCE 72
#define MODES_FLAGS 76
#define MODES_DEADLINE 80
#define MODES_MATCH 88
#define MODES_LOCAL 96
#define MODES_EPOCH 104
#define MODES_COUNT 108
#define MODES_HEIGHT 112
#define MODES_FLY_KIND 116
#define MODES_PLAYERS 120
#define MODES_FLY_CCT 632
#define MODES_FLY_CLASS 640
#define MODES_SPIN_SIN 648
#define MODES_SPIN_COS 652
#define MODES_BUSY 656
#define MODES_TICKS 664
#define MODES_APPLIES 672
#define MODES_RESTORES 680
#define MODES_MAGIC 688
#define MODES_POST_ORIGINAL 704
#define MODES_POST_TICKS 712
#define MODES_FORCE_POS 720
#define MODES_ROWS 728
#define MODES_GET_ROT 4824
#define MODES_SET_ROT 4832
#define MODES_IS_CHILD 4840
#define MODES_SPIN_PLAYER 4848
#define MODES_SPIN_TRANSFORM 4856
#define MODES_SPIN_ID 4864
#define MODES_SPIN_REAL 4872
#define MODES_SPIN_SHOWN 4888
#define MODES_MODEL 4904
#define MODES_LOCAL_POS 4912
#define MODES_SET_LOCAL_POS 4920
#define MODES_CHILD_COUNT 4928
#define MODES_GET_CHILD 4936
#define MODES_GET_SPEED 4944
#define MODES_SET_SPEED 4952
#define MODES_GET_ENABLED 4960
#define MODES_SET_ENABLED 4968
#define MODES_LATE_SHARED 4976
#define MODES_LATE_ORIGINAL 4984
#define MODES_LATE_TICKS 4992
#define MODES_SPIN_APPLIES 5000
#define MODES_SPIN_STATUS 5008
#define MODES_WORLD_ROT 5016
#define MODES_SET_WORLD_ROT 5024
#define MODES_POSES 5032
#define MODES_STATE_SIZE 0x94000
#define POSE_CAPACITY 128
#define POSE_SIZE 9264
#define POSE_ROOT 0
#define POSE_ANIMATOR 8
#define POSE_COUNT 16
#define POSE_ACTIVE 20
#define POSE_ID 24
#define POSE_EPOCH 28
#define POSE_SPEED 32
#define POSE_ENABLED 36
#define POSE_BONES 48
#define BONE_SIZE 72
#define BONE_TRANSFORM 0
#define BONE_ANCHOR_ROT 8
#define BONE_ANCHOR_POS 24
#define BONE_REAL_ROT 40
#define BONE_REAL_POS 56
#define MODES_CAPACITY 64
#define MODES_ROW_SIZE 64
#define ROW_PLAYER 0
#define ROW_MATCH 8
#define ROW_LOCAL 16
#define ROW_EPOCH 24
#define ROW_MODE 28
#define ROW_REAL 32
#define ROW_ID 44
#define ROW_SHOWN 48
#ifndef __ASSEMBLER__
#include <cstddef>
#include <cstdint>
namespace PlayerModesRemote {
constexpr uint64_t Magic = 0x504c4d4f4445303cULL;
struct BonePose {
    uint64_t transform=0;
    float anchorRotation[4]={},anchorPosition[3]={};uint32_t pad=0;
    float realRotation[4]={},realPosition[3]={};uint32_t pad2=0;
};
struct Pose {
    uint64_t root=0,animator=0;
    uint32_t count=0,active=0,identity=0,epoch=0;
    float speed=1;uint32_t enabled=1;uint64_t pad=0;
    BonePose bones[POSE_CAPACITY];
};
struct Row {
    uint64_t player=0, match=0, local=0;
    uint32_t epoch=0, mode=0;
    float real[3]={}; uint32_t identity=0;
    float shown[3]={}; uint32_t pad2=0;
};
struct Input {
    uint32_t flags=0;
    uint64_t deadline=0, match=0, local=0;
    uint32_t epoch=0, count=0;
    float height=4.0f; uint32_t flyKind=0;
    uint64_t players[MODES_CAPACITY]={};
    uint64_t flyCCT=0, flyClass=0;
    float spinSin=0,spinCos=1;
} __attribute__((packed));
struct State {
    uint64_t original=0, clock=0, currentMatch=0, getPos=0, setPos=0, hp=0;
    uint64_t vehicle=0, parachute=0, waitSync=0;
    uint32_t sequence=0;
    Input input;
    uint32_t busy=0, pad=0;
    uint64_t ticks=0, applies=0, restores=0, magic=Magic, pad2=0;
    uint64_t originalPost=0, postTicks=0;
    uint64_t forcePos=0;
    Row rows[MODES_CAPACITY];
    uint64_t getRot=0,setRot=0,isChild=0;
    uint64_t spinPlayer=0,spinTransform=0;
    uint32_t spinID=0,spinPad=0;
    float spinReal[4]={},spinShown[4]={};
    uint64_t model=0,localPos=0,setLocalPos=0,childCount=0,getChild=0;
    uint64_t getSpeed=0,setSpeed=0,getEnabled=0,setEnabled=0;
    uint64_t lateShared=0,lateOriginal=0,lateTicks=0,spinApplies=0;
    uint32_t spinStatus=0,spinStatusPad=0;
    uint64_t worldRot=0,setWorldRot=0;
};
static_assert(offsetof(State, input)==MODES_FLAGS);
static_assert(offsetof(State, input)+offsetof(Input, players)==MODES_PLAYERS);
static_assert(offsetof(State, input)+offsetof(Input, height)==MODES_HEIGHT);
static_assert(offsetof(State, input)+offsetof(Input, flyKind)==MODES_FLY_KIND);
static_assert(offsetof(State, input)+offsetof(Input, flyCCT)==MODES_FLY_CCT);
static_assert(offsetof(State, forcePos)==MODES_FORCE_POS);
static_assert(offsetof(State, busy)==MODES_BUSY);
static_assert(offsetof(State, ticks)==MODES_TICKS);
static_assert(offsetof(State, applies)==MODES_APPLIES);
static_assert(offsetof(State, restores)==MODES_RESTORES);
static_assert(offsetof(State, magic)==MODES_MAGIC);
static_assert(offsetof(State, originalPost)==MODES_POST_ORIGINAL);
static_assert(offsetof(State, postTicks)==MODES_POST_TICKS);
static_assert(offsetof(State, rows)==MODES_ROWS);
static_assert(offsetof(State, input)+offsetof(Input,spinSin)==MODES_SPIN_SIN);
static_assert(offsetof(State,getRot)==MODES_GET_ROT);
static_assert(offsetof(State,spinPlayer)==MODES_SPIN_PLAYER);
static_assert(offsetof(State,spinReal)==MODES_SPIN_REAL && offsetof(State,spinShown)==MODES_SPIN_SHOWN);
static_assert(sizeof(Row)==MODES_ROW_SIZE);
static_assert(offsetof(Row, real)==ROW_REAL && offsetof(Row, shown)==ROW_SHOWN);
static_assert(offsetof(Row, identity)==ROW_ID);
static_assert(sizeof(State)<MODES_PAGE);
static_assert(sizeof(State)==MODES_POSES && offsetof(State,model)==MODES_MODEL);
static_assert(offsetof(State,lateShared)==MODES_LATE_SHARED && offsetof(State,spinStatus)==MODES_SPIN_STATUS);
static_assert(offsetof(State,worldRot)==MODES_WORLD_ROT && offsetof(State,setWorldRot)==MODES_SET_WORLD_ROT);
static_assert(sizeof(Pose)==POSE_SIZE && offsetof(Pose,bones)==POSE_BONES);
static_assert(sizeof(BonePose)==BONE_SIZE && offsetof(BonePose,realRotation)==BONE_REAL_ROT);
static_assert(MODES_POSES+MODES_CAPACITY*sizeof(Pose)<MODES_STATE_SIZE);
}
#endif
