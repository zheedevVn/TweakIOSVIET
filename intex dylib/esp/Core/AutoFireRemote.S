#include "GameProfileFields.h"
#include "AutoFireRemoteLayout.h"
#ifdef __APPLE__
.section __TEXT,__autofire,regular,pure_instructions
#else
.section .text
#endif
.p2align 14
.globl _AutoFireRemoteStart
.globl _AutoFireRemoteEnd
_AutoFireRemoteStart:
    b .LautoMain
    .p2align 4
    b .LautoEffect
    .p2align 4
    b .LautoTracer
    .p2align 4
    b .LautoShot
.LautoTracer:
    adr x16, .LautoState
    ldr x16, [x16, #AUTO_TRACER_ORIGINAL]
    br x16
.LautoShot:
    adr x16, .LautoState
    ldr x16, [x16, #AUTO_SHOT_ORIGINAL]
    br x16
.LautoEffect:
    adr x16, .LautoState
    ldr x16, [x16, #AUTO_EFFECT_ORIGINAL]
    br x16
.LautoMain:
    // Weapon.MAMFDNEJAPF(self, float dt, float time, MethodInfo*).
    // Player.PostUpdate calls this virtual slot even while the gun is idle.
    // Preserve the caller ABI and issue input only for the current local gun.
    stp x29, x30, [sp, #-112]!
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp d0, d1, [sp, #80]
    adr x19, .LautoState
    mov x20, x0
    mov x21, x1
    // Resolve the exact TypeInfo on a game thread before the first shot.
    // The host can bind its visual slot next frame without requiring manual fire.
    ldr w8, [x19, #AUTO_METADATA_READY]
    cbnz w8, .LautoPrepared
    ldr x8, [x19, #AUTO_METADATA_INIT]
    cbz x8, .LautoPrepared
    ldr x0, [x19, #AUTO_TRACER_TYPEINFO]
    cbz x0, .LautoPrepared
    blr x8
    mov w8, #1
    str w8, [x19, #AUTO_METADATA_READY]
.LautoPrepared:
    mov x0, x20
    mov x1, x21
    ldp d0, d1, [sp, #80]
    // Advance native gun/handler state before trying a shot. The start method
    // can reject a command while the previous tick's state is still active.
    ldr x8, [x19, #AUTO_ORIGINAL]
    blr x8
    ldr x25, [x19, #AUTO_LOCAL]
    cbz x25, .LautoTail
    ldr x8, [x20, #0x60]
    cmp x8, x25
    b.ne .LautoTail
    ldr x8, [x19, #AUTO_WEAPON]
    cmp x8, x20
    b.eq .LautoRelevant
    ldr x8, [x19, #AUTO_HELD]
    cmp x8, x20
    b.ne .LautoTail
.LautoRelevant:
    ldr w8, [x19, #AUTO_ENABLED]
    ldr w10, [x19, #AUTO_SWAP_ENABLED]
    orr w8, w8, w10
    ldr x9, [x19, #AUTO_HELD]
    orr x8, x8, x9
    cbz x8, .LautoTail          // OFF with no owned hold: no native getter work
    ldr x8, [x19, #AUTO_TICKS]
    add x8, x8, #1
    str x8, [x19, #AUTO_TICKS]
    add x8, x19, #AUTO_BUSY
    ldaxr w9, [x8]
    cbnz w9, .LautoReserved
    mov w9, #1
    stxr w10, w9, [x8]
    cbnz w10, .LautoTail
    mov x0, x25
    mov x1, #0
    ldr x8, [x19, #AUTO_GET_WEAPON]
    blr x8
    mov x22, x0
    // Only use a current weapon. Never dereference a saved weapon after a swap.
    cbz x22, .LautoForget
    cmp x22, x20
    b.ne .LautoForget
    ldr x8, [x22, #0x60]
    cmp x8, x25
    b.ne .LautoForget
    ldr x8, [x19, #AUTO_HELD]
    cmp x8, x22
    b.eq .LautoSnapshot
    str xzr, [x19, #AUTO_HELD]
.LautoSnapshot:
    add x8, x19, #AUTO_SEQUENCE
    ldar w23, [x8]
    tbnz w23, #0, .LautoRelease
    ldr x8, [x19, #AUTO_WEAPON]
    cmp x8, x22
    b.ne .LautoRelease
    ldr x8, [x19, #AUTO_MATCH]
    cbz x8, .LautoRelease
    ldr x8, [x8, #0xD8]
    cmp x8, x25
    b.ne .LautoRelease
    add x8, x25, #0x1000
    ldrb w8, [x8, #(MIZZE_PLAYER_1258 - 0x1000)]
    cbnz w8, .LautoRelease
    ldr x24, [x19, #AUTO_DEADLINE]
    ldr x8, [x19, #AUTO_CLOCK]
    blr x8
    cmp x0, x24
    b.hi .LautoRelease
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRelease
    ldr w8, [x19, #AUTO_SWAP_ENABLED]
    cbz w8, .LautoNoSwap
    ldr s0, [sp, #80]
    fcmp s0, #0.0
    b.vs .LautoRelease
    b.le .LautoCheckFire
    fmov s1, #1.0
    fcmp s0, s1
    b.gt .LautoRelease
    ldr s2, [x19, #AUTO_SWAP_ELAPSED]
    fadd s0, s0, s2
    str s0, [x19, #AUTO_SWAP_ELAPSED]
    fcmp s0, s1
    b.lt .LautoCheckFire
    str wzr, [x19, #AUTO_SWAP_ELAPSED]
    ldr x8, [x19, #AUTO_SWAP_COOLDOWN]
    cbz x8, .LautoCheckFire
    mov x0, x25
    mov x1, #0
    blr x8
    cbnz w0, .LautoCheckFire
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRelease
    // Revalidate the published inventory entry on the game thread.
    ldr x8, [x25]
    ldr x9, [x8, #0xDC8]
    ldr x10, [x19, #AUTO_SWAP_FUNCTION]
    cmp x9, x10
    b.ne .LautoCheckFire
    cbz x9, .LautoCheckFire
    ldr x8, [x25, #MIZZE_PLAYER_740]
    cbz x8, .LautoCheckFire
    ldr x9, [x8, #0x30]
    cmp x9, x25
    b.ne .LautoCheckFire
    ldr x8, [x8, #0x88]
    cbz x8, .LautoCheckFire
    ldr w9, [x19, #AUTO_SWAP_SLOT]
    cmp w9, #67
    b.hs .LautoCheckFire
    ldr w10, [x8, #0x18]
    cmp w9, w10
    b.hs .LautoCheckFire
    add x8, x8, x9, lsl #3
    ldr x8, [x8, #0x20]
    ldr x9, [x19, #AUTO_SWAP_WEAPON]
    cmp x8, x9
    b.ne .LautoCheckFire
    cbz x8, .LautoCheckFire
    cmp x8, x22
    b.eq .LautoCheckFire
    ldr x8, [x8, #0x60]
    cbz x8, .LswapInventoryOwned
    cmp x8, x25
    b.ne .LautoCheckFire
.LswapInventoryOwned:
    ldr x8, [x19, #AUTO_HELD]
    cmp x8, x22
    cset w24, eq
    b.ne .LautoSwapExecute
    ldr x8, [x22]
    ldr x9, [x8, #0xE88]
    ldr x10, [x19, #AUTO_STOP]
    cmp x9, x10
    b.ne .LautoRelease
    str xzr, [x19, #AUTO_HELD]
    mov x0, x22
    ldr x1, [x8, #0xE90]
    blr x9
.LautoSwapExecute:
    // Stop callbacks may run a hotfix; recheck publication and method.
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRelease
    ldr x8, [x25]
    ldr x9, [x8, #0xDC8]
    ldr x10, [x19, #AUTO_SWAP_FUNCTION]
    cmp x9, x10
    b.ne .LautoRelease
    mov x0, x25
    ldr w1, [x19, #AUTO_SWAP_SLOT]
    // Complete the swap instead of queueing the request-only input path.
    // The native cooldown was checked above before releasing our own fire.
    mov w2, #1
    ldr x3, [x8, #0xDD0]
    str wzr, [x19, #AUTO_SWAP_ELAPSED]
    str wzr, [x19, #AUTO_ELAPSED]
    blr x9
    mov x0, x25
    mov x1, #0
    ldr x8, [x19, #AUTO_GET_WEAPON]
    blr x8
    cmp x0, x22
    b.ne .LautoForget
    // Retain only our own cadence after a rejected swap. Wait for the next
    // native update; don't issue a fresh start in the same tick as stop/swap.
    cbz w24, .LautoUnlock
    str x22, [x19, #AUTO_HELD]
    b .LautoUnlock
.LautoNoSwap:
    str wzr, [x19, #AUTO_SWAP_ELAPSED]
.LautoCheckFire:
    ldr w8, [x19, #AUTO_ENABLED]
    cbz w8, .LautoRelease
    // Query physics on the game's update thread. Camera visibility alone
    // cannot distinguish an enemy behind solid cover.
    ldr x8, [x19, #AUTO_TARGET]
    cbz x8, .LautoRelease
    ldr w8, [x19, #AUTO_HEAD_PERCENT]
    cmp w8, #100
    b.hi .LautoRelease
    cbz w8, .LautoBodyRay
    add x0, x19, #AUTO_HEAD
    bl .LautoRay
    cbz w0, .LautoRelease
    ldr w8, [x19, #AUTO_HEAD_PERCENT]
    cmp w8, #100
    b.eq .LautoRayDone
.LautoBodyRay:
    add x0, x19, #AUTO_BODY
    bl .LautoRay
    cbz w0, .LautoRelease
.LautoRayDone:
    // Physics/transform getters can run game hotfixes. Never fire using a
    // changed or expired publication after returning from native queries.
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRelease
    ldr x8, [x19, #AUTO_CLOCK]
    blr x8
    ldr x24, [x19, #AUTO_DEADLINE]
    cmp x0, x24
    b.hi .LautoRelease
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRelease
    // A shot event is not a persistent trigger. Leave manual fire alone, but
    // repeat owned shots at Weapon.LDKCJEMDAMC's native interval, as the game's
    // firing-state ticks do. PRI21 == 2 must not suppress our next owned shot.
    ldr x8, [x19, #AUTO_HELD]
    cmp x8, x22
    b.eq .LautoCadence
    ldr x8, [x25, #0x70]
    cbz x8, .LautoRelease
    ldr x8, [x8, #0x10]
    cbz x8, .LautoRelease
    ldr x8, [x8, #0xC8]
    cbz x8, .LautoRelease
    ldrh w8, [x8, #0x18]
    cmp w8, #2
    b.eq .LautoUnlock
    str wzr, [sp, #96]        // first shot has no carried cadence time
    b .LautoMethods
.LautoCadence:
    ldr s0, [sp, #80]          // caller's dt, saved before any native call
    fcmp s0, #0.0
    b.vs .LautoRelease
    b.le .LautoUnlock
    fmov s1, #1.0
    fcmp s0, s1
    b.gt .LautoRelease         // reject invalid/stale simulation deltas
    ldr s1, [x19, #AUTO_ELAPSED]
    fadd s0, s0, s1
    str s0, [x19, #AUTO_ELAPSED]
    mov x0, x22
    mov x1, #0
    ldr x8, [x19, #AUTO_INTERVAL]
    blr x8
    fmov w8, s0
    ubfx w8, w8, #23, #8
    cmp w8, #255
    b.eq .LautoRelease         // reject NaN/infinite native intervals
    fcmp s0, #0.0
    b.vs .LautoRelease
    b.le .LautoRelease
    // Gentle automatic cadence: max(native interval, 0.35 seconds).
    // A saved manual speed modifier cannot make AimKill issue rapid commands.
    mov w8, #0x3333
    movk w8, #0x3EB3, lsl #16
    fmov s2, w8
    fmax s0, s0, s2
    ldr s1, [x19, #AUTO_ELAPSED]
    fcmp s1, s0
    b.lt .LautoUnlock
    // Discard overshoot: no shortened gap or catch-up burst on the next tick.
    str wzr, [sp, #96]
    // The interval method may run a hotfix. Recheck publication after it.
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRelease
.LautoMethods:
    ldr x8, [x19, #AUTO_CLOCK]
    blr x8
    ldr x24, [x19, #AUTO_DEADLINE]
    cmp x0, x24
    b.hi .LautoRelease
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRelease
    // Ensure the weapon still uses the statically verified input methods.
    ldr x8, [x22]
    ldr x9, [x8, #0xC98]       // virtual 182: ALJMFCJMDCF()
    ldr x10, [x19, #AUTO_START]
    cmp x9, x10
    b.ne .LautoRelease
    ldr x9, [x8, #0xE88]       // virtual 213: NFFJEBKJCAK()
    ldr x10, [x19, #AUTO_STOP]
    cmp x9, x10
    b.ne .LautoRelease
    ldr x26, [x19, #AUTO_SILENT_GATE]
    cbz x26, .LautoRelease
    stlr x22, [x26]            // only this native shot may bypass manual PRI21
    mov x0, x22
    ldr x1, [x8, #0xCA0]
    ldr x8, [x19, #AUTO_START]
    blr x8
    stlr xzr, [x26]
    ldr w8, [sp, #96]
    str w8, [x19, #AUTO_ELAPSED]
    str x22, [x19, #AUTO_HELD]
    ldr x8, [x19, #AUTO_STARTS]
    add x8, x8, #1
    str x8, [x19, #AUTO_STARTS]
    b .LautoUnlock
.LautoRelease:
    str wzr, [x19, #AUTO_ELAPSED]
    // Keep a valid swap timer while waiting for an aim target.
    ldr x8, [x19, #AUTO_HELD]
    cmp x8, x22
    b.ne .LautoUnlock
    str xzr, [x19, #AUTO_HELD]
    ldr x8, [x22]
    ldr x9, [x8, #0xE88]
    ldr x10, [x19, #AUTO_STOP]
    cmp x9, x10
    b.ne .LautoUnlock
    mov x0, x22
    ldr x1, [x8, #0xE90]
    blr x9
    b .LautoUnlock
.LautoForget:
    str xzr, [x19, #AUTO_HELD]
    str wzr, [x19, #AUTO_ELAPSED]
.LautoUnlock:
    add x8, x19, #AUTO_BUSY
    stlr wzr, [x8]
    b .LautoTail
.LautoReserved:
    clrex
.LautoTail:
    mov x0, x20
    mov x1, x21
    ldp d0, d1, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret

// x0 points to the endpoint; x19 is our publication. Return 1 only when
// the full segment is clear or its first solid collider belongs to the target.
// The helper preserves every callee-saved register used by the main callback.
.LautoRay:
    stp x29, x30, [sp, #-96]!
    stp x27, x28, [sp, #16]
    ldp s3, s4, [x0]
    ldr s5, [x0, #8]
    ldr s0, [x19, #AUTO_ORIGIN]
    ldr s1, [x19, #AUTO_ORIGIN+4]
    ldr s2, [x19, #AUTO_ORIGIN+8]
    fsub s3, s3, s0
    fsub s4, s4, s1
    fsub s5, s5, s2
    fmul s6, s3, s3
    fmadd s6, s4, s4, s6
    fmadd s6, s5, s5, s6
    fsqrt s6, s6
    fmov w8, s6
    ubfx w8, w8, #23, #8
    cmp w8, #255
    b.eq .LautoRayBlocked
    fcmp s6, #0.0
    b.le .LautoRayBlocked
    // RaycastHit is 44 bytes, with collider instance ID at +0x28.
    stp xzr, xzr, [sp, #48]
    stp xzr, xzr, [sp, #64]
    str xzr, [sp, #80]
    str wzr, [sp, #88]
    add x0, sp, #48
    mov w1, #-1              // all solid layers
    mov w2, #1               // QueryTriggerInteraction.Ignore
    mov x3, #0
    ldr x8, [x19, #AUTO_RAYCAST]
    cbz x8, .LautoRayBlocked
    blr x8
    cbz w0, .LautoRayClear
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRayBlocked
    add x0, sp, #48
    mov x1, #0
    ldr x8, [x19, #AUTO_HIT_COLLIDER]
    cbz x8, .LautoRayBlocked
    blr x8
    cbz x0, .LautoRayBlocked
    ldr x8, [x0, #0x10]       // Unity's native cached pointer
    cbz x8, .LautoRayBlocked
    mov x1, #0
    ldr x8, [x19, #AUTO_COMPONENT_TRANSFORM]
    cbz x8, .LautoRayBlocked
    blr x8
    cbz x0, .LautoRayBlocked
    mov x27, x0
    ldr x8, [x27, #0x10]
    cbz x8, .LautoRayBlocked
    ldr x0, [x19, #AUTO_TARGET]
    cbz x0, .LautoRayBlocked
    add x8, x19, #AUTO_SEQUENCE
    ldar w8, [x8]
    cmp w8, w23
    b.ne .LautoRayBlocked
    // An uninitialised/despawned target root can throw in the native getter.
    ldr x8, [x0, #MIZZE_PLAYER_6C8]
    cbz x8, .LautoRayBlocked
    mov x1, #0
    ldr x8, [x19, #AUTO_ROOT_TRANSFORM]
    cbz x8, .LautoRayBlocked
    blr x8
    cbz x0, .LautoRayBlocked
    mov x28, x0
    ldr x8, [x28, #0x10]
    cbz x8, .LautoRayBlocked
    mov x0, x27
    mov x1, x28
    mov x2, #0
    ldr x8, [x19, #AUTO_IS_CHILD]
    cbz x8, .LautoRayBlocked
    blr x8
    b .LautoRayReturn
.LautoRayClear:
    mov w0, #1
    b .LautoRayReturn
.LautoRayBlocked:
    mov w0, #0
.LautoRayReturn:
    ldp x27, x28, [sp, #16]
    ldp x29, x30, [sp], #96
    ret
    .org AUTO_PAGE, 0
_AutoFireRemoteEnd:
.LautoState:
