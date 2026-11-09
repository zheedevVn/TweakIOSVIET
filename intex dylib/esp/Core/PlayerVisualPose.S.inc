#include "GameProfileFields.h"
// Shared state, one pose per position row. No anonymous instructions or packets.
.macro poseSave
    stp x29, x30, [sp, #-112]!
    stp x21, x22, [sp, #16]
    stp x24, x25, [sp, #32]
    stp x26, x27, [sp, #48]
    str x28, [sp, #64]
    sub x8, x22, x19
    sub x8, x8, #MODES_ROWS
    lsr x8, x8, #6
    mov x9, #POSE_SIZE
    add x21, x19, #1, lsl #12
    add x21, x21, #(MODES_POSES-4096)
    madd x21, x8, x9, x21
.endm
.macro poseReturn
    ldr x28, [sp, #64]
    ldp x26, x27, [sp, #48]
    ldp x24, x25, [sp, #32]
    ldp x21, x22, [sp, #16]
    ldp x29, x30, [sp], #112
    ret
.endm
.LposeBefore:
    cbz x22, .LposeNoRow
    poseSave
    ldr w8, [x21, #POSE_ACTIVE]
    cbz w8, .LposeBeforeReturn
    ldr w8, [x20, #0x60]
    ldr w9, [x21, #POSE_ID]
    cmp w8, w9
    b.ne .LposeBeforeForget
    ldr x8, [x20, #MIZZE_PLAYER_6D0]
    cbz x8, .LposeBeforeForget
    ldr x26, [x8, #0x10]
    ldr x9, [x21, #POSE_ROOT]
    cmp x26, x9
    b.ne .LposeBeforeForget
    cbz x26, .LposeBeforeForget
    ldr x8, [x26, #0x10]
    cbz x8, .LposeBeforeForget
    ldr x8, [x20, #MIZZE_PLAYER_760]
    cbz x8, .LposeBeforeForget
    ldr x27, [x8, #0x28]
    ldr x9, [x21, #POSE_ANIMATOR]
    cmp x27, x9
    b.ne .LposeBeforeForget
    cbz x27, .LposeBeforeForget
    ldr x8, [x27, #0x10]
    cbz x8, .LposeBeforeForget
    // Only undo the zero speed / disabled state we own. A native change wins.
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_GET_SPEED]
    blr x8
    fcmp s0, #0.0
    b.ne .LposeRestoreEnabled
    ldr s0, [x21, #POSE_SPEED]
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_SET_SPEED]
    blr x8
.LposeRestoreEnabled:
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_GET_ENABLED]
    blr x8
    cbnz w0, .LposeRestoreBones
    mov x0, x27
    ldr w1, [x21, #POSE_ENABLED]
    mov x2, #0
    ldr x8, [x19, #MODES_SET_ENABLED]
    blr x8
.LposeRestoreBones:
    ldr w25, [x21, #POSE_COUNT]
    cmp w25, #POSE_CAPACITY
    b.hi .LposeBeforeForget
    mov w24, #0
    add x28, x21, #POSE_BONES
.LposeRestoreLoop:
    cmp w24, w25
    b.hs .LposeBeforeReturn
    ldr x0, [x28, #BONE_TRANSFORM]
    cbz x0, .LposeRestoreNext
    ldr x8, [x0, #0x10]
    cbz x8, .LposeRestoreNext
    mov x1, x26
    mov x2, #0
    ldr x8, [x19, #MODES_IS_CHILD]
    blr x8
    cbz w0, .LposeRestoreNext
    ldp s0, s1, [x28, #BONE_REAL_ROT]
    ldp s2, s3, [x28, #(BONE_REAL_ROT+8)]
    ldr x0, [x28, #BONE_TRANSFORM]
    mov x1, #0
    ldr x8, [x19, #MODES_SET_ROT]
    blr x8
    ldp s0, s1, [x28, #BONE_REAL_POS]
    ldr s2, [x28, #(BONE_REAL_POS+8)]
    ldr x0, [x28, #BONE_TRANSFORM]
    mov x1, #0
    ldr x8, [x19, #MODES_SET_LOCAL_POS]
    blr x8
.LposeRestoreNext:
    add x28, x28, #BONE_SIZE
    add w24, w24, #1
    b .LposeRestoreLoop
.LposeBeforeForget:
    str wzr, [x21, #POSE_COUNT]
    str wzr, [x21, #POSE_ACTIVE]
.LposeBeforeReturn:
    poseReturn
.LposeNoRow:
    ret

.LposeAfter:
    cbz x22, .LposeNoRow
    poseSave
    ldr w8, [x22, #ROW_MODE]
    cmp w8, #1
    b.ne .LposeAbort
    ldr x8, [x22, #ROW_PLAYER]
    cmp x8, x20
    b.ne .LposeAbort
    add x8, x19, #MODES_SEQUENCE
    ldar w9, [x8]
    tbnz w9, #0, .LposeAbort
    str w9, [sp, #92]
    ldr w8, [x19, #MODES_FLAGS]
    tbz w8, #0, .LposeAbort
    ldr x8, [x19, #MODES_LOCAL]
    cmp x8, x20
    b.eq .LposeAbort
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_MODEL]
    blr x8
    mov x26, x0
    cbz x26, .LposeAbort
    ldr x8, [x26, #0x10]
    cbz x8, .LposeAbort
    ldr x1, [x20, #0x58]
    cbz x1, .LposeAbort
    cmp x26, x1
    b.eq .LposeAbort
    ldr x8, [x1, #0x10]
    cbz x8, .LposeAbort
    mov x2, #0
    ldr x8, [x19, #MODES_IS_CHILD]
    blr x8
    cbz w0, .LposeAbort
    ldr x8, [x20, #MIZZE_PLAYER_760]
    cbz x8, .LposeAbort
    ldr x27, [x8, #0x28]
    cbz x27, .LposeAbort
    ldr x8, [x27, #0x10]
    cbz x8, .LposeAbort
    mov w8, #0
    str w8, [sp, #88]
    ldr w8, [x21, #POSE_COUNT]
    cbz w8, .LposeCollect
    ldr x8, [x21, #POSE_ROOT]
    cmp x8, x26
    b.ne .LposeCollect
    ldr x8, [x21, #POSE_ANIMATOR]
    cmp x8, x27
    b.ne .LposeCollect
    ldr w8, [x20, #0x60]
    ldr w9, [x21, #POSE_ID]
    cmp w8, w9
    b.ne .LposeCollect
    ldr w8, [x19, #MODES_EPOCH]
    ldr w9, [x21, #POSE_EPOCH]
    cmp w8, w9
    b.eq .LposeReadStart
.LposeCollect:
    str wzr, [x21, #POSE_ACTIVE]
    str wzr, [x21, #POSE_COUNT]
    mov w8, #1
    str w8, [sp, #88]
    str x26, [x21, #POSE_ROOT]
    str x27, [x21, #POSE_ANIMATOR]
    ldr w8, [x20, #0x60]
    str w8, [x21, #POSE_ID]
    ldr w8, [x19, #MODES_EPOCH]
    str w8, [x21, #POSE_EPOCH]
    add x28, x21, #POSE_BONES
    str x26, [x28]
    mov w25, #1
    mov w24, #0
.LposeCollectLoop:
    cmp w24, w25
    b.hs .LposeCollected
    ldr x0, [x28]
    mov x1, #0
    ldr x8, [x19, #MODES_CHILD_COUNT]
    blr x8
    cmp w0, #POSE_CAPACITY
    b.hi .LposeAbort // Reject a corrupt or unbounded hierarchy.
    str w0, [sp, #80]
    str wzr, [sp, #84]
.LposeCollectChildren:
    ldr w8, [sp, #80]
    ldr w1, [sp, #84]
    cmp w1, w8
    b.hs .LposeCollectedNext
    ldr x0, [x28]
    mov x2, #0
    ldr x8, [x19, #MODES_GET_CHILD]
    blr x8
    cbz x0, .LposeAbort
    ldr x8, [x0, #0x10]
    cbz x8, .LposeAbort
    // Duplicate detection also bounds cycles in a malformed hierarchy.
    add x8, x21, #POSE_BONES
    mov w9, w25
.LposeDuplicate:
    ldr x10, [x8]
    cmp x10, x0
    b.eq .LposeAbort
    add x8, x8, #BONE_SIZE
    subs w9, w9, #1
    b.ne .LposeDuplicate
    cmp w25, #POSE_CAPACITY
    b.hs .LposeAbort // Never silently freeze only half a skeleton.
    str x0, [x8]
    add w25, w25, #1
    ldr w8, [sp, #84]
    add w8, w8, #1
    str w8, [sp, #84]
    b .LposeCollectChildren
.LposeCollectedNext:
    add w24, w24, #1
    add x28, x28, #BONE_SIZE
    b .LposeCollectLoop
.LposeCollected:
    str w25, [x21, #POSE_COUNT]
.LposeReadStart:
    ldr w25, [x21, #POSE_COUNT]
    cmp w25, #POSE_CAPACITY
    b.hi .LposeAbort
    mov w24, #0
    add x28, x21, #POSE_BONES
.LposeRead:
    cmp w24, w25
    b.hs .LposePause
    ldr x0, [x28]
    cbz x0, .LposeAbort
    ldr x8, [x0, #0x10]
    cbz x8, .LposeAbort
    mov x1, x26
    mov x2, #0
    ldr x8, [x19, #MODES_IS_CHILD]
    blr x8
    cbz w0, .LposeAbort
    ldr x0, [x28]
    mov x1, #0
    ldr x8, [x19, #MODES_GET_ROT]
    blr x8
    fmul s4, s0, s0
    fmadd s4, s1, s1, s4
    fmadd s4, s2, s2, s4
    fmadd s4, s3, s3, s4
    fmov s5, #0.5
    fcmp s4, s5
    b.lt .LposeAbort
    b.vs .LposeAbort
    fmov s5, #1.5
    fcmp s4, s5
    b.gt .LposeAbort
    stp s0, s1, [x28, #BONE_REAL_ROT]
    stp s2, s3, [x28, #(BONE_REAL_ROT+8)]
    ldr w8, [sp, #88]
    cbz w8, .LposeReadPosition
    stp s0, s1, [x28, #BONE_ANCHOR_ROT]
    stp s2, s3, [x28, #(BONE_ANCHOR_ROT+8)]
.LposeReadPosition:
    ldr x0, [x28]
    mov x1, #0
    ldr x8, [x19, #MODES_LOCAL_POS]
    blr x8
    fmul s4, s0, s0
    fmadd s4, s1, s1, s4
    fmadd s4, s2, s2, s4
    fcmp s4, #0.0
    b.vs .LposeAbort
    mov w8, #0x2400
    movk w8, #0x4974, lsl #16 // Finite local pose: norm squared <= 1,000,000.
    fmov s5, w8
    fcmp s4, s5
    b.gt .LposeAbort
    stp s0, s1, [x28, #BONE_REAL_POS]
    str s2, [x28, #(BONE_REAL_POS+8)]
    ldr w8, [sp, #88]
    cbz w8, .LposeReadNext
    stp s0, s1, [x28, #BONE_ANCHOR_POS]
    str s2, [x28, #(BONE_ANCHOR_POS+8)]
.LposeReadNext:
    add x28, x28, #BONE_SIZE
    add w24, w24, #1
    b .LposeRead
.LposePause:
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_GET_SPEED]
    blr x8
    fabs s1, s0
    fmov s2, #16.0
    fcmp s1, s2
    b.vs .LposeAbort
    b.gt .LposeAbort
    str s0, [x21, #POSE_SPEED]
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_GET_ENABLED]
    blr x8
    and w0, w0, #1
    str w0, [x21, #POSE_ENABLED]
    add x8, x19, #MODES_SEQUENCE
    ldar w8, [x8]
    ldr w9, [sp, #92]
    cmp w8, w9
    b.ne .LposeAbort
    // Speed=0 suppresses animation-component LateUpdate, enabled=false stops
    // Mecanim evaluation / IK between callbacks. Restore both before originals.
    mov x0, x27
    mov x1, #0
    fmov s0, wzr
    ldr x8, [x19, #MODES_SET_SPEED]
    blr x8
    mov x0, x27
    mov x1, #0
    mov x2, #0
    ldr x8, [x19, #MODES_SET_ENABLED]
    blr x8
    mov w8, #1
    str w8, [x21, #POSE_ACTIVE]
    mov w24, #0
    add x28, x21, #POSE_BONES
.LposeApply:
    cmp w24, w25
    b.hs .LposeAfterReturn
    ldp s0, s1, [x28, #BONE_ANCHOR_ROT]
    ldp s2, s3, [x28, #(BONE_ANCHOR_ROT+8)]
    ldr x0, [x28]
    mov x1, #0
    ldr x8, [x19, #MODES_SET_ROT]
    blr x8
    ldp s0, s1, [x28, #BONE_ANCHOR_POS]
    ldr s2, [x28, #(BONE_ANCHOR_POS+8)]
    ldr x0, [x28]
    mov x1, #0
    ldr x8, [x19, #MODES_SET_LOCAL_POS]
    blr x8
    add x28, x28, #BONE_SIZE
    add w24, w24, #1
    b .LposeApply
.LposeAbort:
    str wzr, [x21, #POSE_ACTIVE]
    str wzr, [x21, #POSE_COUNT]
.LposeAfterReturn:
    poseReturn
