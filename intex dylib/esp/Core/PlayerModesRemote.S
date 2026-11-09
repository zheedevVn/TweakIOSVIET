#include "GameProfileFields.h"
#include "PlayerModesLayout.h"
#ifdef __APPLE__
.section __TEXT,__playermodes,regular,pure_instructions
#else
.section .text
#endif
.p2align 14
.globl _PlayerModesRemoteStart
.globl _PlayerModesRemoteEnd
// Wrap virtual OnUpdate(self, dt, time, MethodInfo). Incoming interpolation,
    // health and weapon logic still run; held skeletons only affect presentation.
_PlayerModesRemoteStart:
    mov w16, #0
    b .Lentry
.org MODES_POST_ENTRY, 0
    mov w16, #1
    b .Lentry
.org MODES_LATE_ENTRY, 0
    mov w16, #2
    b .Lentry
.Lentry:
    stp x29, x30, [sp, #-144]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    stp d0, d1, [sp, #96]
    adr x19, .LmodesState
    mov w23, w16 // Same state/anchor, distinct original for each frame phase.
    mov x20, x0
    mov x21, x1
    str x20, [sp, #128] // #112..123 are Fly's temporary Vector3.
    cmp w23, #2
    b.ne .Llock
    // MatchGame.OnLateUpdate owns a separate signed mapping/original, but uses
    // the local Player session's pose state so OnUpdate can restore it first.
    ldr x8, [x19, #MODES_LATE_ORIGINAL]
    str x8, [sp, #136]
    ldr x19, [x19, #MODES_LATE_SHARED]
    cbz x19, .LlateTail
.Llock:
    add x8, x19, #MODES_BUSY
    ldaxr w9, [x8]
    cbnz w9, .Lreserved
    mov w9, #1
    stxr w10, w9, [x8]
    cbnz w10, .Ltail
    cmp w23, #2
    b.ne .LrestoreSpin
    ldr x20, [x19, #MODES_LOCAL]
    cbz x20, .LlateOriginal
.LrestoreSpin:
    // Undo our previous render pose before native gameplay/network updates.
    // Only restore the identical living model; never write a recycled object.
    ldr x8, [x19, #MODES_SPIN_PLAYER]
    cmp x8, x20
    b.ne .LspinRestored
    str xzr, [x19, #MODES_SPIN_PLAYER]
    ldr w8, [x20, #0x60]
    ldr w9, [x19, #MODES_SPIN_ID]
    cmp w8, w9
    b.ne .LspinRestored
    ldr x8, [x20, #MIZZE_PLAYER_6D0] // Player.get_BoneRootTransform: visual rig, not Root.
    cbz x8, .LspinRestored
    ldr x27, [x8, #0x10]
    ldr x9, [x19, #MODES_SPIN_TRANSFORM]
    cmp x27, x9
    b.ne .LspinRestored
    cbz x27, .LspinRestored
    ldr x8, [x27, #0x10]
    cbz x8, .LspinRestored
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_GET_ROT]
    blr x8
    add x16, x19, #1, lsl #12
    add x16, x16, #(MODES_SPIN_REAL-4096)
    ldp s4, s5, [x16, #16]
    ldp s6, s7, [x16, #24]
    fmul s4, s0, s4
    fmadd s4, s1, s5, s4
    fmadd s4, s2, s6, s4
    fmadd s4, s3, s7, s4
    fabs s4, s4
    mov w8, #0xff58
    movk w8, #0x3f7f, lsl #16 // 0.99999: tolerate Unity quaternion normalization.
    fmov s5, w8
    fcmp s4, s5
    b.lt .LspinRestored // Animation/native correction wins over stale data.
    b.vs .LspinRestored
    ldp s0, s1, [x16]
    ldp s2, s3, [x16, #8]
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_SET_ROT]
    blr x8
.LspinRestored:
    cmp w23, #2
    b.eq .LlateOriginal
    mov x22, #0
    mov x26, #0
    add x8, x19, #MODES_ROWS
    mov w9, #MODES_CAPACITY
.LfindRow:
    ldr x10, [x8, #ROW_PLAYER]
    cmp x10, x20
    b.eq .LfoundRow
    cbnz x10, .LnextRow
    cmp x26, #0
    csel x26, x8, x26, eq
.LnextRow:
    add x8, x8, #MODES_ROW_SIZE
    subs w9, w9, #1
    b.ne .LfindRow
    b .Loriginal
.LfoundRow:
    mov x22, x8
    bl .LposeBefore
    ldr w8, [x20, #0x60] // Entity.UniqueID distinguishes recycled instances.
    ldr w9, [x22, #ROW_ID]
    cmp w8, w9
    b.ne .LdropBefore
    ldr w8, [x22, #ROW_MODE]
    cbz w8, .Loriginal
    cmp w8, #2
    b.eq .Loriginal // Physics owns the raised position; never restore a ground pose.
    // Restore only an unchanged visual override for the same living context.
    // A newly arrived correction/teleport wins over our saved real position.
    mov x0, #0
    ldr x8, [x19, #MODES_CURRENT_MATCH]
    blr x8
    cbz x0, .LdropBefore
    ldr x8, [x22, #ROW_MATCH]
    cmp x0, x8
    b.ne .LdropBefore
    ldr x8, [x0, #0xD8]
    ldr x9, [x22, #ROW_LOCAL]
    cmp x8, x9
    b.ne .LdropBefore
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_HP]
    blr x8
    cmp w0, #0
    b.le .LdropBefore
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_GET_POS]
    blr x8
    fmov w8, s0
    fmov w9, s1
    fmov w10, s2
    ldp w11, w12, [x22, #ROW_SHOWN]
    ldr w13, [x22, #(ROW_SHOWN+8)]
    cmp w8, w11
    b.ne .LnewPosition
    cmp w9, w12
    b.ne .LnewPosition
    cmp w10, w13
    b.ne .LnewPosition
    ldp s0, s1, [x22, #ROW_REAL]
    ldr s2, [x22, #(ROW_REAL+8)]
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_SET_POS]
    blr x8
    ldr x8, [x19, #MODES_RESTORES]
    add x8, x8, #1
    str x8, [x19, #MODES_RESTORES]
    b .Loriginal
.LnewPosition:
    // Fixed ticks/interpolation can move a remote transform BETWEEN OnUpdate
    // calls. Do not restore stale normal data or recapture on each such move.
    // Keep the anchor until explicit release. UniqueID/context checks above
    // distinguish recycled entities; distance must not release a held enemy.
    ldr w8, [x22, #ROW_MODE]
    cmp w8, #1
    b.ne .LresetAnchor
    b .Loriginal
.LresetAnchor:
    str wzr, [x22, #ROW_MODE]
    b .Loriginal
.LdropBefore:
    str xzr, [x22, #ROW_PLAYER]
    str wzr, [x22, #ROW_MODE]
    mov x26, x22
    mov x22, #0
.Loriginal:
    mov x0, x20
    mov x1, x21
    ldp d0, d1, [sp, #96]
    ldr x8, [x19, #MODES_ORIGINAL]
    cbz w23, .LcallOriginal
    ldr x8, [x19, #MODES_POST_ORIGINAL]
.LcallOriginal:
    blr x8
    ldr x8, [x19, #MODES_TICKS]
    add x8, x8, #1
    str x8, [x19, #MODES_TICKS]
    cbz w23, .Lsnapshot
    ldr x8, [x19, #MODES_POST_TICKS]
    add x8, x8, #1
    str x8, [x19, #MODES_POST_TICKS]
.Lsnapshot:
    add x8, x19, #MODES_SEQUENCE
    ldar w24, [x8]
    tbnz w24, #0, .Ldefer
    ldr w25, [x19, #MODES_FLAGS]
    cbz w25, .Ldrop
    cmp w25, #7
    b.hi .Ldrop
    ldr x8, [x19, #MODES_CLOCK]
    blr x8
    ldr x8, [x19, #MODES_DEADLINE]
    cmp x0, x8
    b.hi .Ldrop
    ldr x27, [x19, #MODES_MATCH]
    ldr x28, [x19, #MODES_LOCAL]
    cbz x27, .Ldrop
    cbz x28, .Ldrop
    mov x0, #0
    ldr x8, [x19, #MODES_CURRENT_MATCH]
    blr x8
    cmp x0, x27
    b.ne .Ldrop
    ldr x8, [x27, #0xD8]
    cmp x8, x28
    b.ne .Ldrop
    add x8, x28, #0x1000
    ldrb w8, [x8, #(MIZZE_PLAYER_1258 - 0x1000)]
    cbnz w8, .Ldrop
    cmp x20, x28
    b.ne .Lenemy
    tbz w25, #1, .Ldrop
    mov w25, #2
    b .Lhealth
.Lenemy:
    tbz w25, #0, .Ldrop
    ldr w9, [x19, #MODES_COUNT]
    cbz w9, .Ldrop
    cmp w9, #MODES_CAPACITY
    b.hi .Ldrop
    add x8, x19, #MODES_PLAYERS
.LfindEnemy:
    ldr x10, [x8], #8
    cmp x10, x20
    b.eq .LenemyFound
    subs w9, w9, #1
    b.ne .LfindEnemy
    b .Ldrop
.LenemyFound:
    mov w25, #1
.Lhealth:
    add x8, x20, #0x1000
    ldrb w8, [x8, #(MIZZE_PLAYER_1258 - 0x1000)]
    cbnz w8, .Ldrop
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_HP]
    blr x8
    cmp w0, #0
    b.le .Ldrop
    // Enemy holds are presentation-only. Continue native force sync/vehicle/
    // parachute logic in the original, while retaining the same visual anchor.
    cmp w25, #1
    b.eq .Lposition
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_VEHICLE]
    blr x8
    cbnz w0, .Ldrop
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_PARACHUTE]
    blr x8
    cbnz w0, .Ldrop
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_WAIT_SYNC]
    blr x8
    cbnz w0, .Ldrop
    ldr w10, [x19, #MODES_FLY_KIND]
    ldrb w8, [x20, #MIZZE_PLAYER_260]
    cmp w10, #1
    b.ne .LunityController
    cmp w8, #1
    b.ne .Ldrop
    ldr x8, [x20, #MIZZE_PLAYER_268]
    b .LcontrollerIdentity
.LunityController:
    cmp w10, #2
    b.ne .Ldrop
    cbnz w8, .Ldrop
    ldr x8, [x20, #MIZZE_PLAYER_4D8]
.LcontrollerIdentity:
    cbz x8, .Ldrop
    ldr x9, [x19, #MODES_FLY_CCT]
    cmp x8, x9
    b.ne .Ldrop
    ldr x9, [x8]
    ldr x10, [x19, #MODES_FLY_CLASS]
    cmp x9, x10
    b.ne .Ldrop
    ldr w10, [x19, #MODES_FLY_KIND]
    cmp w10, #1
    b.ne .LunityNative
    ldr x8, [x8, #0x1c8]
    b .LcontrollerNative
.LunityNative:
    ldr x8, [x8, #0x10]
.LcontrollerNative:
    cbz x8, .Ldrop
.Lposition:
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_GET_POS]
    blr x8
    // Finite world coordinates, bounded before applying a visual override.
    // Entity.get_Position returns Vector3.zero when its Unity transform is gone.
    fmov w8, s0
    fmov w9, s1
    fmov w10, s2
    orr w8, w8, w9
    orr w8, w8, w10
    and w8, w8, #0x7fffffff
    cbz w8, .Ldrop
    mov w8, #0x2400
    movk w8, #0x4974, lsl #16
    fmov s3, w8
    fabs s4, s0
    fcmp s4, s3
    b.vs .Ldrop
    b.gt .Ldrop
    fabs s4, s1
    fcmp s4, s3
    b.vs .Ldrop
    b.gt .Ldrop
    fabs s4, s2
    fcmp s4, s3
    b.vs .Ldrop
    b.gt .Ldrop
    add x8, x19, #MODES_SEQUENCE
    ldar w8, [x8]
    cmp w8, w24
    b.ne .Ldefer
    cbnz x22, .LhaveRow
    cbz x26, .Lunlock
    mov x22, x26
.LhaveRow:
    cmp w25, #2
    b.eq .Lfly
    stp s0, s1, [x22, #ROW_REAL]
    str s2, [x22, #(ROW_REAL+8)]
    // Keep the first position in this hold epoch; normal interpolation has
    // already advanced, so latest real coordinates remain available on release.
    ldr w8, [x22, #ROW_MODE]
    cmp w8, #1
    b.ne .LcaptureShown
    ldr w8, [x22, #ROW_EPOCH]
    ldr w9, [x19, #MODES_EPOCH]
    cmp w8, w9
    b.ne .LcaptureShown
    ldr x8, [x22, #ROW_MATCH]
    cmp x8, x27
    b.ne .LcaptureShown
    ldr x8, [x22, #ROW_LOCAL]
    cmp x8, x28
    b.ne .LcaptureShown
    ldp s0, s1, [x22, #ROW_SHOWN]
    ldr s2, [x22, #(ROW_SHOWN+8)]
    b .Lapply
.Lfly:
    // Capture one base altitude and preserve horizontal native movement.
    ldr s3, [x19, #MODES_HEIGHT]
    fmov s4, #1.0
    fcmp s3, s4
    b.vs .Ldrop
    b.lo .Ldrop
    fmov s4, #6.0
    fcmp s3, s4
    b.gt .Ldrop
    fmov s4, s1
    fmov s5, s1
    ldr w8, [x22, #ROW_MODE]
    cmp w8, #2
    b.ne .LflyBase
    ldr x8, [x22, #ROW_MATCH]
    cmp x8, x27
    b.ne .LflyBase
    ldr x8, [x22, #ROW_LOCAL]
    cmp x8, x28
    b.ne .LflyBase
    ldr s6, [x22, #(ROW_SHOWN+4)]
    fsub s7, s1, s6
    fabs s7, s7
    fmov s6, #4.0
    fcmp s7, s6
    b.gt .LflyBase // A large native correction establishes a new base smoothly.
    ldr s4, [x22, #(ROW_REAL+4)]
    ldr s5, [x22, #(ROW_SHOWN+4)]
.LflyBase:
    stp s0, s4, [x22, #ROW_REAL]
    str s2, [x22, #(ROW_REAL+8)]
    fadd s1, s4, s3
    fsub s1, s1, s5
    mov w8, #0x3d800000
    fmov s6, w8
    fneg s7, s6
    fmax s1, s1, s7
    fmin s1, s1, s6
    fadd s1, s1, s5
.LcaptureShown:
    stp s0, s1, [x22, #ROW_SHOWN]
    str s2, [x22, #(ROW_SHOWN+8)]
.Lapply:
    str x20, [x22, #ROW_PLAYER]
    str x27, [x22, #ROW_MATCH]
    str x28, [x22, #ROW_LOCAL]
    ldr w8, [x19, #MODES_EPOCH]
    str w8, [x22, #ROW_EPOCH]
    str w25, [x22, #ROW_MODE]
    ldr w8, [x20, #0x60]
    str w8, [x22, #ROW_ID]
    cmp w25, #2
    b.ne .LsetVisual
    ldr w8, [x19, #MODES_FLY_KIND]
    cmp w8, #1
    b.ne .LsetVisual
    stp s0, s1, [sp, #112]
    str s2, [sp, #120]
    ldr x0, [x20, #MIZZE_PLAYER_268]
    mov x1, #0
    ldr x8, [x19, #MODES_FORCE_POS]
    blr x8
    ldp s0, s1, [sp, #112]
    ldr s2, [sp, #120]
.LsetVisual:
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_SET_POS]
    blr x8
    ldr x8, [x19, #MODES_APPLIES]
    add x8, x8, #1
    str x8, [x19, #MODES_APPLIES]
    b .Lunlock
.Ldefer:
    // A concurrent HUD publication is transient, not a scope release. Do not
    // apply a torn snapshot, but retain the owned anchor for the next tick.
    b .Lunlock
.Ldrop:
    cbz x22, .Lunlock
    str xzr, [x22, #ROW_PLAYER]
    str wzr, [x22, #ROW_MODE]
.Lunlock:
    bl .LposeAfter
    b .LspinDone
.LlateOriginal:
    ldr x0, [sp, #128]
    mov x1, x21
    ldr x8, [sp, #136]
    blr x8
    ldr x8, [x19, #MODES_LATE_TICKS]
    add x8, x8, #1
    str x8, [x19, #MODES_LATE_TICKS]
    ldr x20, [x19, #MODES_LOCAL]
    cbz x20, .LspinDone
    // Presentation only: apply after the game's complete LateUpdate chain.
    // Entity/physics root, camera, aim quaternions and packet fields are untouched.
    add x8, x19, #MODES_SEQUENCE
    ldar w24, [x8]
    tbnz w24, #0, .LspinDone
    ldr w8, [x19, #MODES_FLAGS]
    tbz w8, #2, .LspinDone
    mov w8, #1 // Awaiting a living local match / valid lease.
    str w8, [x19, #MODES_SPIN_STATUS]
    ldr x8, [x19, #MODES_LOCAL]
    cmp x8, x20
    b.ne .LspinDone
    ldr x8, [x19, #MODES_CLOCK]
    blr x8
    ldr x8, [x19, #MODES_DEADLINE]
    cmp x0, x8
    b.hi .LspinDone
    mov x0, #0
    ldr x8, [x19, #MODES_CURRENT_MATCH]
    blr x8
    cbz x0, .LspinDone
    ldr x8, [x19, #MODES_MATCH]
    cmp x0, x8
    b.ne .LspinDone
    ldr x8, [x0, #0xd8]
    cmp x8, x20
    b.ne .LspinDone
    add x8, x20, #0x1000
    ldrb w8, [x8, #(MIZZE_PLAYER_1258 - 0x1000)]
    cbnz w8, .LspinDone
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_HP]
    blr x8
    cmp w0, #0
    b.le .LspinDone
    mov w8, #2 // Awaiting a visual rig distinct from the physical root.
    str w8, [x19, #MODES_SPIN_STATUS]
    mov x0, x20
    mov x1, #0
    ldr x8, [x19, #MODES_MODEL]
    blr x8 // Initialize the verified cached BoneRoot when needed.
    mov x27, x0
    cbz x27, .LspinDone
    ldr x8, [x27, #0x10]
    cbz x8, .LspinDone
    ldr x28, [x20, #0x58] // GCommon.Entity cached physical root.
    cbz x28, .LspinDone
    cmp x27, x28
    b.eq .LspinDone
    ldr x8, [x28, #0x10]
    cbz x8, .LspinDone
    mov x0, x27
    mov x1, x28
    mov x2, #0
    ldr x8, [x19, #MODES_IS_CHILD]
    blr x8
    cbz w0, .LspinDone // A camera/root/sibling cannot be our visual pivot.
    mov w8, #3 // Awaiting a stable, finite quaternion publication.
    str w8, [x19, #MODES_SPIN_STATUS]
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_GET_ROT]
    blr x8
    // Require a finite normalized base quaternion.
    fmul s4, s0, s0
    fmadd s4, s1, s1, s4
    fmadd s4, s2, s2, s4
    fmadd s4, s3, s3, s4
    fmov s5, #0.5
    fcmp s4, s5
    b.lt .LspinDone
    b.vs .LspinDone
    fmov s5, #1.5
    fcmp s4, s5
    b.gt .LspinDone
    add x16, x19, #1, lsl #12
    add x16, x16, #(MODES_SPIN_REAL-4096)
    stp s0, s1, [x16] // Restore local pose even if the parent moves next frame.
    stp s2, s3, [x16, #8]
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_WORLD_ROT]
    blr x8
    fmul s4, s0, s0
    fmadd s4, s1, s1, s4
    fmadd s4, s2, s2, s4
    fmadd s4, s3, s3, s4
    fmov s5, #0.5
    fcmp s4, s5
    b.lt .LspinDone
    b.vs .LspinDone
    fmov s5, #1.5
    fcmp s4, s5
    b.gt .LspinDone
    add x8, x19, #MODES_SEQUENCE
    ldar w9, [x8]
    cmp w9, w24
    b.ne .LspinDone
    add x16, x19, #MODES_SPIN_SIN
    ldp s4, s5, [x16]
    fmul s6, s4, s4
    fmadd s6, s5, s5, s6
    fmov s7, #0.5
    fcmp s6, s7
    b.lt .LspinDone
    b.vs .LspinDone
    fmov s7, #1.5
    fcmp s6, s7
    b.gt .LspinDone
    // world-Y yaw * world base. Imported rigs can have a tilted local Y;
    // spinning that local axis makes the body roll instead of turn horizontally.
    str s1, [sp, #112]
    fmul s6, s0, s5
    fmadd s7, s2, s4, s6
    fmul s6, s1, s5
    fmadd s1, s3, s4, s6
    fmul s6, s2, s5
    fmsub s2, s0, s4, s6
    fmul s6, s3, s5
    ldr s0, [sp, #112]
    fmsub s3, s0, s4, s6
    fmov s0, s7
    add x8, x19, #MODES_SEQUENCE
    ldar w9, [x8]
    cmp w9, w24
    b.ne .LspinDone
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_SET_WORLD_ROT]
    blr x8
    mov x0, x27
    mov x1, #0
    ldr x8, [x19, #MODES_GET_ROT]
    blr x8
    add x16, x19, #1, lsl #12
    add x16, x16, #(MODES_SPIN_SHOWN-4096)
    stp s0, s1, [x16]
    stp s2, s3, [x16, #8]
    str x20, [x19, #MODES_SPIN_PLAYER]
    str x27, [x19, #MODES_SPIN_TRANSFORM]
    ldr w8, [x20, #0x60]
    str w8, [x19, #MODES_SPIN_ID]
    ldr x8, [x19, #MODES_SPIN_APPLIES]
    add x8, x8, #1
    str x8, [x19, #MODES_SPIN_APPLIES]
    mov w8, #4
    str w8, [x19, #MODES_SPIN_STATUS]
.LspinDone:
    add x8, x19, #MODES_BUSY
    stlr wzr, [x8]
    b .Lreturn
.Lreserved:
    clrex
.Ltail:
    cmp w23, #2
    b.eq .LlateTail
    mov x0, x20
    mov x1, x21
    ldp d0, d1, [sp, #96]
    ldr x8, [x19, #MODES_ORIGINAL]
    cbz w23, .LcallTail
    ldr x8, [x19, #MODES_POST_ORIGINAL]
.LcallTail:
    blr x8
    b .Lreturn
.LlateTail:
    ldr x0, [sp, #128]
    mov x1, x21
    ldr x8, [sp, #136]
    blr x8
.Lreturn:
    ldr x0, [sp, #128]
    mov x1, x21
    ldp d0, d1, [sp, #96]
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #144
    ret
#include "PlayerVisualPose.S.inc"
.org MODES_PAGE, 0
_PlayerModesRemoteEnd:
.LmodesState:
