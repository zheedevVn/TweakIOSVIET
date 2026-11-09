#include "GameProfileFields.h"
#include "GhostRemoteLayout.h"
#ifdef __APPLE__
.section __TEXT,__ghost,regular,pure_instructions
#else
.section .text
#endif
.p2align 14
.globl _GhostRemoteStart
.globl _GhostRemoteEnd
// All entries share one signed RX page and one private RW state page.
.macro ghost_save
    stp x29, x30, [sp, #-224]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    stp d0, d1, [sp, #96]
    adr x19, .LghostState
    mov x20, x0
    mov x21, x1
    mov x22, x2
.endm
.macro ghost_restore
    mov x0, x20
    mov x1, x21
    mov x2, x22
    ldp d0, d1, [sp, #96]
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #224
.endm
.macro ghost_lock failure
    add x8, x19, #GHOST_BUSY
    ldaxr w9, [x8]
    cbnz w9, \failure
    mov w9, #1
    stxr w10, w9, [x8]
    cbnz w10, \failure
.endm
.macro ghost_out_begin
    ldr w8, [x19, #GHOST_OUT_SEQUENCE]
    add w8, w8, #1
    orr w8, w8, #1
    str w8, [x19, #GHOST_OUT_SEQUENCE]
    dmb ish // Publish odd sequence before modifying any output fields.
.endm
.macro ghost_out_end
    ldr w8, [x19, #GHOST_OUT_SEQUENCE]
    add w8, w8, #1
    add x9, x19, #GHOST_OUT_SEQUENCE
    stlr w8, [x9]
.endm
.macro ghost_unlock
    add x8, x19, #GHOST_BUSY
    stlr wzr, [x8]
.endm
.macro ghost_bool offset, failure
    mov x0, x23
    mov x1, #0
    ldr x8, [x19, #\offset]
    blr x8
    cbnz w0, \failure
.endm
_GhostRemoteStart:
    ghost_save
    ldr x8, [x19, #GHOST_MATCH]
    cmp x8, x20
    b.ne .LtickTail
    ghost_lock .LtickReserved
    ghost_out_begin
    ldr x8, [x19, #GHOST_TICKS]
    add x8, x8, #1
    str x8, [x19, #GHOST_TICKS]
    add x8, x19, #GHOST_SEQUENCE
    ldar w24, [x8]
    tbnz w24, #0, .LtickExpired
    ldr w25, [x19, #GHOST_COMMAND]
    cbz w25, .LtickCancel
    // Only the verified match update calls Unity APIs. Serializers never do.
    mov x0, #0
    ldr x8, [x19, #GHOST_CURRENT_MATCH]
    blr x8
    cmp x0, x20
    b.ne .LtickDiscard
    ldr x23, [x20, #0xD8]
    ldr x8, [x19, #GHOST_LOCAL]
    cmp x23, x8
    b.ne .LtickDiscard
    cbz x23, .LtickDiscard
    mov x0, x23
    mov x1, #0
    ldr x8, [x19, #GHOST_HP]
    blr x8
    cmp w0, #0
    b.le .LtickDiscard
    add x8, x23, #0x1000
    ldrb w8, [x8, #(MIZZE_PLAYER_1258 - 0x1000)]
    cbnz w8, .LtickDiscard
    ldr x8, [x19, #GHOST_CLOCK]
    blr x8
    ldr x8, [x19, #GHOST_DEADLINE]
    cmp x0, x8
    b.hi .LtickExpired
    ghost_bool GHOST_WAIT_SYNC, .LtickPause
    ghost_bool GHOST_VEHICLE, .LtickPause
    ghost_bool GHOST_CATAPULT, .LtickPause
    ghost_bool GHOST_CANNON, .LtickPause
    ghost_bool GHOST_CHAIR, .LtickPause
    ghost_bool GHOST_CHAIR_ALT, .LtickPause
    ghost_bool GHOST_PARACHUTE, .LtickPause
    ghost_bool GHOST_STROP, .LtickPause
    ghost_bool GHOST_RAIL, .LtickPause
    ghost_bool GHOST_SEESAW, .LtickPause
    ghost_bool GHOST_PLATFORM, .LtickPause
    add x8, x19, #GHOST_SEQUENCE
    ldar w8, [x8]
    cmp w8, w24
    b.ne .LtickExpired
    ldr w8, [x19, #GHOST_COMMAND]
    cmp w8, w25
    b.ne .LtickExpired
    cmp w25, #2
    b.eq .LtickReturn
    cmp w25, #1
    b.ne .LtickCancel
    ldr x8, [x19, #GHOST_ANCHOR_MATCH]
    cmp x8, x20
    b.ne .LtickCapture
    ldr x8, [x19, #GHOST_ANCHOR_LOCAL]
    cmp x8, x23
    b.ne .LtickCapture
    ldr w8, [x19, #GHOST_ANCHOR_EPOCH]
    ldr w9, [x19, #GHOST_EPOCH]
    cmp w8, w9
    b.eq .LtickArm // Resume a lease/vehicle pause at the same saved anchor.
.LtickCapture:
    mov x0, x23
    mov x1, #0
    ldr x8, [x19, #GHOST_GET_POS]
    blr x8
    // Reject non-finite/implausible coordinates before integer quantization.
    mov w8, #0x2400
    movk w8, #0x4974, lsl #16 // 1,000,000.0
    fmov s3, w8
    fabs s4, s0
    fcmp s4, s3
    b.vs .LtickDiscard
    b.gt .LtickDiscard
    fabs s4, s1
    fcmp s4, s3
    b.vs .LtickDiscard
    b.gt .LtickDiscard
    fabs s4, s2
    fcmp s4, s3
    b.vs .LtickDiscard
    b.gt .LtickDiscard
    add x8, x19, #GHOST_SEQUENCE
    ldar w8, [x8]
    cmp w8, w24
    b.ne .LtickExpired
    stp s0, s1, [x19, #GHOST_ANCHOR]
    str s2, [x19, #(GHOST_ANCHOR+8)]
    // LMCBHLCPAJD.DJNIOABIFCA: float bias, float *1000, double round-to-even.
    mov w8, #0xb717
    movk w8, #0x38d1, lsl #16
    fmov s3, w8
    mov w8, #0x447a0000
    fmov s4, w8
    fadd s0, s0, s3
    fadd s1, s1, s3
    fadd s2, s2, s3
    fmul s0, s0, s4
    fmul s1, s1, s4
    fmul s2, s2, s4
    fcvt d0, s0
    fcvt d1, s1
    fcvt d2, s2
    frintn d0, d0
    frintn d1, d1
    frintn d2, d2
    fcvtzs w8, d0
    fcvtzs w9, d1
    fcvtzs w10, d2
    add x12, x19, #GHOST_ENCODED
    stp w8, w9, [x12]
    str w10, [x19, #(GHOST_ENCODED+8)]
    str x20, [x19, #GHOST_ANCHOR_MATCH]
    str x23, [x19, #GHOST_ANCHOR_LOCAL]
    ldr w8, [x19, #GHOST_EPOCH]
    str w8, [x19, #GHOST_ANCHOR_EPOCH]
    str wzr, [x19, #GHOST_POSE_CAPTURED]
    str xzr, [x19, #GHOST_PACKETS]
    str xzr, [x19, #GHOST_AXES]
.LtickArm:
    mov w8, #1
    str w8, [x19, #GHOST_ACTIVE]
    mov w8, #3
    b .LtickStatus
.LtickReturn:
    // Disable belongs to the immediately preceding enabled epoch only.
    ldr w8, [x19, #GHOST_ANCHOR_EPOCH]
    ldr w9, [x19, #GHOST_EPOCH]
    add w8, w8, #1
    cmp w8, w9
    b.ne .LtickCancel
    ldr x8, [x19, #GHOST_ANCHOR_MATCH]
    cmp x8, x20
    b.ne .LtickCancel
    ldr x8, [x19, #GHOST_ANCHOR_LOCAL]
    cmp x8, x23
    b.ne .LtickCancel
    str wzr, [x19, #GHOST_ACTIVE]
    mov x0, x23
    mov x1, #0
    ldp s0, s1, [x19, #GHOST_ANCHOR]
    ldr s2, [x19, #(GHOST_ANCHOR+8)]
    ldr x8, [x19, #GHOST_SET_POS]
    blr x8
    str xzr, [x19, #GHOST_ANCHOR_MATCH]
    str xzr, [x19, #GHOST_ANCHOR_LOCAL]
    ldr x8, [x19, #GHOST_RETURNS]
    add x8, x8, #1
    str x8, [x19, #GHOST_RETURNS]
    mov w8, #6
    b .LtickStatus
.LtickDiscard:
    mov w8, #11
    b .LtickForget
.LtickCancel:
    mov w8, #1
.LtickForget:
    str xzr, [x19, #GHOST_ANCHOR_MATCH]
    str xzr, [x19, #GHOST_ANCHOR_LOCAL]
    str wzr, [x19, #GHOST_ACTIVE]
    b .LtickStatus
.LtickPause:
    mov w8, #7
    b .LtickInactive
.LtickExpired:
    mov w8, #8
.LtickInactive:
    str wzr, [x19, #GHOST_ACTIVE]
.LtickStatus:
    str w8, [x19, #GHOST_STATUS]
    ghost_out_end
    ghost_unlock
    b .LtickTail
.LtickReserved:
    clrex
.LtickTail:
    ldr x16, [x19, #GHOST_TICK]
    ghost_restore
    br x16

// Pure data guard shared by the two serializers; no Unity API calls.
.LserializerGuard:
    add x8, x19, #GHOST_SEQUENCE
    ldar w28, [x8]
    tbnz w28, #0, .LguardFail
    ldr w8, [x19, #GHOST_COMMAND]
    cmp w8, #1
    b.ne .LguardFail
    ldr w8, [x19, #GHOST_ACTIVE]
    cbz w8, .LguardFail
    ldr w8, [x19, #GHOST_EPOCH]
    ldr w9, [x19, #GHOST_ANCHOR_EPOCH]
    cmp w8, w9
    b.ne .LguardFail
    stp x29, x30, [sp, #-16]!
    ldr x8, [x19, #GHOST_CLOCK]
    blr x8
    ldp x29, x30, [sp], #16
    ldr x8, [x19, #GHOST_DEADLINE]
    cmp x0, x8
    b.hi .LguardFail
    ldr x8, [x19, #GHOST_MATCH]
    ldr x9, [x19, #GHOST_ANCHOR_MATCH]
    cmp x8, x9
    b.ne .LguardFail
    cbz x8, .LguardFail
    ldr x9, [x8, #0xD8]
    ldr x10, [x19, #GHOST_ANCHOR_LOCAL]
    cmp x9, x10
    b.ne .LguardFail
    cbz x9, .LguardFail
    add x9, x9, #0x1000
    ldrb w9, [x9, #(MIZZE_PLAYER_1258 - 0x1000)]
    cbnz w9, .LguardFail
    add x9, x19, #GHOST_SEQUENCE
    ldar w9, [x9]
    cmp w9, w28
    b.ne .LguardFail
    mov w0, #1
    ret
.LguardFail:
    mov w0, #0
    ret
.macro ghost_vec_save ptr, offset
    ldp w9, w10, [\ptr, #0x14]
    ldr w11, [\ptr, #0x1C]
    stp w9, w10, [sp, #\offset]
    str w11, [sp, #(\offset+8)]
.endm
.macro ghost_vec_restore ptr, offset
    ldp w9, w10, [sp, #\offset]
    ldr w11, [sp, #(\offset+8)]
    stp w9, w10, [\ptr, #0x14]
    str w11, [\ptr, #0x1C]
.endm
.org GHOST_POSITION_ENTRY, 0
.LpositionStart:
    ghost_save
    ldr x8, [x19, #GHOST_PACKET]
    cmp x8, x20
    b.ne .LpositionTail
    ghost_lock .LpositionReserved
    bl .LserializerGuard
    cbz w0, .LpositionUnlock
    ldr x8, [x19, #GHOST_MATCH]
    ldr x8, [x8, #0x660]
    cmp x8, x20
    b.ne .LpositionUnlock
    ldr x23, [x20, #0x18]
    cbz x23, .LpositionUnlock
    ldr x8, [x23]
    ldr x9, [x19, #GHOST_BODY_CLASS]
    cmp x8, x9
    b.ne .LpositionUnlock
    ldr x24, [x23, #0x18]
    cbz x24, .LpositionUnlock
    ldr x8, [x24]
    ldr x9, [x19, #GHOST_POS_CLASS]
    cmp x8, x9
    b.ne .LpositionUnlock
    ldr x25, [x23, #0x30]
    cbz x25, .LpositionUnlock
    ldr x8, [x25]
    ldr x9, [x19, #GHOST_VEL_CLASS]
    cmp x8, x9
    b.ne .LpositionUnlock
    ghost_vec_save x24, 112
    ldur w9, [x25, #0x12]
    ldrh w10, [x25, #0x16]
    str w9, [sp, #128]
    strh w10, [sp, #132]
    ldrh w9, [x23, #0x38]
    strh w9, [sp, #136]
    ghost_out_begin
    ldr w8, [x19, #GHOST_POSE_CAPTURED]
    cbnz w8, .LpositionApply
    str w9, [x19, #GHOST_POSE]
    mov w8, #1
    str w8, [x19, #GHOST_POSE_CAPTURED]
.LpositionApply:
    add x12, x19, #GHOST_ENCODED
    ldp w9, w10, [x12]
    ldr w11, [x19, #(GHOST_ENCODED+8)]
    stp w9, w10, [x24, #0x14]
    str w11, [x24, #0x1C]
    stur wzr, [x25, #0x12]
    strh wzr, [x25, #0x16]
    ldr w9, [x19, #GHOST_POSE]
    strh w9, [x23, #0x38]
    mov x0, x20
    mov x1, x21
    mov x2, x22
    ldr x8, [x19, #GHOST_POSITION]
    blr x8
    // Restore precisely the numeric fields of these pooled objects.
    ghost_vec_restore x24, 112
    ldr w9, [sp, #128]
    ldrh w10, [sp, #132]
    stur w9, [x25, #0x12]
    strh w10, [x25, #0x16]
    ldrh w9, [sp, #136]
    strh w9, [x23, #0x38]
    ldr x8, [x19, #GHOST_PACKETS]
    add x8, x8, #1
    str x8, [x19, #GHOST_PACKETS]
    mov w8, #4
    str w8, [x19, #GHOST_STATUS]
    ghost_out_end
    ghost_unlock
    ghost_restore
    ret
.LpositionUnlock:
    ghost_unlock
    b .LpositionTail
.LpositionReserved:
    clrex
.LpositionTail:
    ldr x16, [x19, #GHOST_POSITION]
    ghost_restore
    br x16

.macro ghost_axis_check ptr, offset
    ldr \ptr, [x23, #\offset]
    cbz \ptr, .LaxisUnlock
    ldr x8, [\ptr]
    ldr x9, [x19, #GHOST_POS_CLASS]
    cmp x8, x9
    b.ne .LaxisUnlock
.endm
.macro ghost_vec_zero ptr
    stp wzr, wzr, [\ptr, #0x14]
    str wzr, [\ptr, #0x1C]
.endm
.org GHOST_AXIS_ENTRY, 0
.LaxisStart:
    ghost_save
    ldr x8, [x19, #GHOST_AXIS_PACKET]
    cmp x8, x20
    b.ne .LaxisTail
    ghost_lock .LaxisReserved
    bl .LserializerGuard
    cbz w0, .LaxisUnlock
    ldr x8, [x19, #GHOST_MATCH]
    ldr x8, [x8, #0x668]
    cmp x8, x20
    b.ne .LaxisUnlock
    ldr x23, [x20, #0x18]
    cbz x23, .LaxisUnlock
    ldr x8, [x23]
    ldr x9, [x19, #GHOST_AXIS_CLASS]
    cmp x8, x9
    b.ne .LaxisUnlock
    ghost_axis_check x24, 0x18
    ghost_axis_check x25, 0x20
    ghost_axis_check x26, 0x28
    ghost_axis_check x27, 0x30
    ghost_vec_save x24, 112
    ghost_vec_save x25, 128
    ghost_vec_save x26, 144
    ghost_vec_save x27, 160
    ghost_out_begin
    ghost_vec_zero x24
    ghost_vec_zero x25
    ghost_vec_zero x26
    ghost_vec_zero x27
    mov x0, x20
    mov x1, x21
    mov x2, x22
    ldr x8, [x19, #GHOST_AXIS]
    blr x8
    ghost_vec_restore x24, 112
    ghost_vec_restore x25, 128
    ghost_vec_restore x26, 144
    ghost_vec_restore x27, 160
    ldr x8, [x19, #GHOST_AXES]
    add x8, x8, #1
    str x8, [x19, #GHOST_AXES]
    ghost_out_end
    ghost_unlock
    ghost_restore
    ret
.LaxisUnlock:
    ghost_unlock
    b .LaxisTail
.LaxisReserved:
    clrex
.LaxisTail:
    ldr x16, [x19, #GHOST_AXIS]
    ghost_restore
    br x16
.org GHOST_PAGE, 0
_GhostRemoteEnd:
.LghostState:
