#include "GameProfileFields.h"
#include "SilentAimRemoteLayout.h"
// A relocatable ARM64 handler: all calls come from the remote state page.
// Only this page is copied; none of the TIPA's function pointers enter the game.
#ifdef __APPLE__
.section __TEXT,__silent,regular,pure_instructions
#else
.section .text
#endif
.p2align 14
.globl _SilentAimRemoteStart
.globl _SilentAimRemoteEnd
_SilentAimRemoteStart:
    stp x29, x30, [sp, #-192]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    adr x19, .Lstate
    mov x20, x0
    mov x21, x1
    mov x27, #0                 // direction was changed
    mov x28, #0                 // owns the nonblocking dispatch lock
    add x8, x19, #SILENT_REMOTE_SEQUENCE
    ldar w25, [x8]
    tbnz w25, #0, .Lnative
    ldr w8, [x19, #SILENT_REMOTE_ENABLED]
    cbz w8, .Lnative
    ldr x8, [x19, #SILENT_REMOTE_HANDLER]
    cmp x8, x20
    b.ne .Lnative
    ldr x24, [x19, #SILENT_REMOTE_LOCAL]
    cbz x24, .Lnative
    ldr x26, [x19, #SILENT_REMOTE_DEADLINE]
    ldp w8, w9, [x19, #SILENT_REMOTE_HEAD]
    ldr w10, [x19, #(SILENT_REMOTE_HEAD + 8)]
    stp w8, w9, [sp, #128]
    str w10, [sp, #136]
    ldr x8, [x19, #SILENT_REMOTE_CLOCK]
    cbz x8, .Lnative
    blr x8
    cmp x0, x26
    b.hi .Lnative
    add x8, x19, #SILENT_REMOTE_SEQUENCE
    ldar w8, [x8]
    cmp w8, w25
    b.ne .Lnative
    ldr x8, [x19, #SILENT_REMOTE_MATCH]
    cbz x8, .Lnative
    ldr x8, [x8, #0xD8]
    cmp x8, x24
    b.ne .Lnative
    ldr x23, [x20, #0x10]       // handler's weapon
    cbz x23, .Lnative
    ldr x8, [x23, #0x60]
    cmp x8, x24
    b.ne .Lnative
    ldr x8, [x23, #0x80]
    cmp x8, x20
    b.ne .Lnative
    add x8, x24, #0x1000
    ldrb w8, [x8, #(MIZZE_PLAYER_1258 - 0x1000)]      // local knock
    cbnz w8, .Lnative
    // Native shot events may run without the manual trigger's PRI21. Only
    // a scoped AutoFire call for this exact local weapon can bypass that gate.
    add x8, x19, #SILENT_REMOTE_AUTO_WEAPON
    ldar x8, [x8]
    cmp x8, x23
    b.eq .LshotInfo
    ldr x8, [x24, #0x70]       // firing PRI 21 == UInt16(2)
    cbz x8, .Lnative
    ldr x8, [x8, #0x10]
    cbz x8, .Lnative
    ldr x8, [x8, #0xC8]
    cbz x8, .Lnative
    ldrh w8, [x8, #0x18]
    cmp w8, #2
    b.ne .Lnative
.LshotInfo:
    ldr x22, [x20, #0x28]
    cbz x22, .Lnative
    ldr x8, [x22]
    cbz x8, .Lnative
    ldr x9, [x19, #SILENT_REMOTE_INFO_CLASS]
    cbz x9, .LfirstShotClass
    cmp x8, x9
    b.ne .Lnative
    b .LinfoVerified
.LfirstShotClass:
    // CGKJLKPMGDJ metadata can become available during this first shot.
    // Check the live class name rather than writing into an unknown layout.
    ldr x9, [x8, #0x10]
    cbz x9, .Lnative
    ldr x10, [x9]
    mov x11, #0x4743
    movk x11, #0x4a4b, lsl #16
    movk x11, #0x4b4c, lsl #32
    movk x11, #0x4d50, lsl #48
    cmp x10, x11
    b.ne .Lnative
    ldr w10, [x9, #8]
    mov w11, #0x4447
    movk w11, #0x004a, lsl #16
    cmp w10, w11
    b.ne .Lnative
.LinfoVerified:
    add x8, x19, #SILENT_REMOTE_BUSY
    ldaxr w9, [x8]
    cbnz w9, .Lreserved
    mov w9, #1
    stxr w10, w9, [x8]
    cbnz w10, .Lnative
    mov x28, #1
    // Select at shot dispatch, not on each overlay frame. Preserve phase
    // until a valid direction is committed under the publication check.
    ldr w26, [x19, #SILENT_REMOTE_PHASE]
    ldr w8, [x19, #SILENT_REMOTE_HEAD_PERCENT]
    cmp w8, #100
    b.hi .Lnative
    add w26, w26, w8
    cmp w26, #100
    b.hs .Lhead
    ldp w8, w9, [x19, #SILENT_REMOTE_BODY]
    ldr w10, [x19, #(SILENT_REMOTE_BODY + 8)]
    stp w8, w9, [sp, #128]
    str w10, [sp, #136]
    b .Lselected
.Lhead:
    sub w26, w26, #100
.Lselected:
    // Reject nonfinite head, origin and original direction by exponent bits.
    mov w15, #0x7f800000
    ldp w8, w9, [sp, #128]
    ldr w10, [sp, #136]
    and w11, w8, #0x7f800000
    cmp w11, w15
    b.eq .Lnative
    and w11, w9, #0x7f800000
    cmp w11, w15
    b.eq .Lnative
    and w11, w10, #0x7f800000
    cmp w11, w15
    b.eq .Lnative
    ldp w11, w12, [x22, #0x4C]
    ldr w13, [x22, #0x54]
    and w14, w11, #0x7f800000
    cmp w14, w15
    b.eq .Lnative
    and w14, w12, #0x7f800000
    cmp w14, w15
    b.eq .Lnative
    and w14, w13, #0x7f800000
    cmp w14, w15
    b.eq .Lnative
    fmov s0, w8
    fmov s1, w9
    fmov s2, w10
    fmov s3, w11
    fmov s4, w12
    fmov s5, w13
    fcvt d0, s0
    fcvt d1, s1
    fcvt d2, s2
    fcvt d3, s3
    fcvt d4, s4
    fcvt d5, s5
    fsub d0, d0, d3
    fsub d1, d1, d4
    fsub d2, d2, d5
    fmul d3, d0, d0
    fmadd d3, d1, d1, d3
    fmadd d3, d2, d2, d3
    fsqrt d3, d3
    ldr d4, .Lminimum
    fcmp d3, d4
    b.le .Lnative
    fdiv d0, d0, d3
    fdiv d1, d1, d3
    fdiv d2, d2, d3
    fcvt s0, d0
    fcvt s1, d1
    fcvt s2, d2
    stp s0, s1, [sp, #112]
    str s2, [sp, #120]
    ldp w8, w9, [x22, #0x40]
    ldr w10, [x22, #0x48]
    and w11, w8, #0x7f800000
    cmp w11, w15
    b.eq .Lnative
    and w11, w9, #0x7f800000
    cmp w11, w15
    b.eq .Lnative
    and w11, w10, #0x7f800000
    cmp w11, w15
    b.eq .Lnative
    stp w8, w9, [sp, #96]
    str w10, [sp, #104]
    // A second publication check closes the window while computing direction.
    add x8, x19, #SILENT_REMOTE_SEQUENCE
    ldar w8, [x8]
    cmp w8, w25
    b.ne .Lnative
    stp s0, s1, [x22, #0x40]
    str s2, [x22, #0x48]
    mov x27, #1
    str w26, [x19, #SILENT_REMOTE_PHASE]
    ldr x8, [x19, #SILENT_REMOTE_REDIRECTS]
    add x8, x8, #1
    str x8, [x19, #SILENT_REMOTE_REDIRECTS]
    b .Lnative
.Lreserved:
    clrex
.Lnative:
    cbnz x27, .Lcall
    // An unchanged dispatch is a tail call, preserving native exception unwind.
    cbz x28, .Ltail
    add x8, x19, #SILENT_REMOTE_BUSY
    stlr wzr, [x8]
.Ltail:
    ldr x16, [x19, #SILENT_REMOTE_ORIGINAL]
    mov x0, x20
    mov x1, x21
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x25, x26, [sp, #64]
    ldp x27, x28, [sp, #80]
    ldp x29, x30, [sp], #192
    br x16
.Lcall:
    ldr x8, [x19, #SILENT_REMOTE_ORIGINAL]
    mov x0, x20
    mov x1, x21
    blr x8
    ldr x8, [x20, #0x28]
    cmp x8, x22
    b.ne .Ldone
    ldr x8, [x20, #0x10]
    cmp x8, x23
    b.ne .Ldone
    ldp w8, w9, [x22, #0x40]
    ldr w10, [x22, #0x48]
    ldp w11, w12, [sp, #112]
    ldr w13, [sp, #120]
    cmp w8, w11
    b.ne .Ldone
    cmp w9, w12
    b.ne .Ldone
    cmp w10, w13
    b.ne .Ldone
    ldp w8, w9, [sp, #96]
    ldr w10, [sp, #104]
    stp w8, w9, [x22, #0x40]
    str w10, [x22, #0x48]
.Ldone:
    add x8, x19, #SILENT_REMOTE_BUSY
    stlr wzr, [x8]
    ldp x19, x20, [sp, #16]
    ldp x21, x22, [sp, #32]
    ldp x23, x24, [sp, #48]
    ldp x25, x26, [sp, #64]
    ldp x27, x28, [sp, #80]
    ldp x29, x30, [sp], #192
    ret
.p2align 3
.Lminimum:
    .double 0.01
    // This dedicated section starts at offset zero. Pad to exactly one page
    // without symbol subtraction, which older Mach-O assemblers cannot resolve.
    // .org also rejects a handler that grows beyond the copied page.
    .org SILENT_REMOTE_PAGE, 0
_SilentAimRemoteEnd:
.Lstate:
