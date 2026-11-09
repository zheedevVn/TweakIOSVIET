#ifndef VTIZER_ENGINE_H
#define VTIZER_ENGINE_H

/* Reversible opcode dispatch and pure arithmetic handlers.
 * Uses executable __TEXT sections; never changes memory permissions. */

#include <cstdint>
#include <cstddef>
#include <cstring>
#include "ObfuscationPlatform.h"

#if defined(__clang__) || defined(__GNUC__)
  #define VTIZER_SECTION OBF_CODE_SECTION("__vtizer")
  #define VTIZER_NOINLINE    __attribute__((noinline))
  #define VTIZER_HIDDEN      OBF_HIDDEN
  #define VTIZER_USED        __attribute__((used))
  #define VTIZER_INLINE      inline __attribute__((always_inline))
#else
  #define VTIZER_SECTION
  #define VTIZER_NOINLINE
  #define VTIZER_HIDDEN
  #define VTIZER_USED
  #define VTIZER_INLINE      inline
#endif

namespace _vtizer_ {

// ─── Build-time key generation ────────────────────────────────
static constexpr uint64_t _vt_seed() { return _obf_::BuildSeed; }
static constexpr uint64_t VTIZER_SEED = _vt_seed();

constexpr uint64_t _vt_hash(uint64_t x) {
    x ^= x >> 33;
    x *= 0xFF51AFD7ED558CCDULL;
    x ^= x >> 33;
    x *= 0xC4CEB9FE1A85EC53ULL;
    x ^= x >> 33;
    return x;
}

// ─── Handler dispatch key (shuffled per build) ────────────────
static constexpr uint64_t VTIZER_DISPATCH_KEY    = _vt_hash(VTIZER_SEED ^ 0xCAFEBABEULL);
static constexpr uint64_t VTIZER_HANDLER_MASK    = _vt_hash(VTIZER_SEED ^ 0xDEADBEEFULL);
static constexpr uint8_t  VTIZER_XOR_LAYER1      = (uint8_t)(VTIZER_DISPATCH_KEY & 0xFF);
static constexpr uint8_t  VTIZER_XOR_LAYER2      = (uint8_t)((VTIZER_DISPATCH_KEY >> 8) & 0xFF);
static constexpr uint8_t  VTIZER_ADD_LAYER       = (uint8_t)((VTIZER_DISPATCH_KEY >> 16) & 0xFF);
static constexpr uint8_t  VTIZER_ROT_BITS        = (uint8_t)(((VTIZER_DISPATCH_KEY >> 24) % 7) + 1);
static constexpr uint64_t VTIZER_INTEGRITY_MAGIC = _vt_hash(VTIZER_SEED ^ 0x1337C0DEULL);

// ─── Anti-tamper: Opaque predicate generators ─────────────────
// These always evaluate to a known value but are hard to resolve statically
VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static bool _vt_opaque_true() {
    volatile uint32_t a = 7, b = 3;
    volatile uint32_t c = (a * a - b * b);
    return (c == 40); // always true: 49 - 9 = 40
}

VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static bool _vt_opaque_false() {
    volatile uint32_t x = 5, y = 5;
    volatile uint32_t z = (x * y);
    return (z == 26); // always false: 25 != 26
}

// ─── Stream cipher for handler table ──────────────────────────
VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static uint64_t _vt_stream_cipher(uint64_t input, uint64_t key, uint32_t round) {
    volatile uint64_t state = input ^ key;
    for (uint32_t i = 0; i < (round & 0x0F) + 4; ++i) {
        state ^= (state << 13);
        state ^= (state >> 7);
        state ^= (state << 17);
        state += 0x9E3779B97F4A7C15ULL;
        // Opaque predicate injection
        if (_vt_opaque_false()) state ^= 0xFFFFFFFFFFFFFFFFULL;
    }
    return state;
}

// ─── Handler table entry ──────────────────────────────────────
typedef uint64_t (*VTHandlerFn)(uint64_t* regs, uint64_t arg, volatile uint64_t* junk);

struct VTHandlerEntry {
    uint64_t    encrypted_id;   // Encrypted handler identifier
    VTHandlerFn handler;        // Function pointer
    uint32_t    checksum;       // Anti-tamper checksum
};

// ─── Built-in VM handlers ─────────────────────────────────────
VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static uint64_t _vt_handler_xor_cascade(uint64_t* regs, uint64_t arg, volatile uint64_t* junk) {
    uint8_t dst = (arg >> 8) & 0x0F;
    uint8_t src = arg & 0x0F;
    // Multi-pass XOR to confuse pattern matching
    volatile uint64_t temp = regs[dst];
    temp ^= regs[src];
    if (_vt_opaque_true()) {
        temp ^= *junk;
        temp ^= *junk; // cancels out, but confuses analysis
    }
    regs[dst] = temp;
    *junk = (*junk * 0x5851F42D4C957F2DULL + 0x14057B7EF767814FULL) ^ temp;
    return regs[dst];
}

VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static uint64_t _vt_handler_add_chain(uint64_t* regs, uint64_t arg, volatile uint64_t* junk) {
    uint8_t dst = (arg >> 8) & 0x0F;
    uint8_t src = arg & 0x0F;
    volatile uint64_t tmp1 = regs[dst] + regs[src];
    volatile uint64_t tmp2 = tmp1;
    // Equivalent identity transform to add confusion
    if (_vt_opaque_true()) {
        tmp2 = tmp1 + *junk;
        tmp2 -= *junk;
    }
    regs[dst] = tmp2;
    *junk ^= tmp2 + 0xBEEFCAFEULL;
    return regs[dst];
}

VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static uint64_t _vt_handler_sub_rot(uint64_t* regs, uint64_t arg, volatile uint64_t* junk) {
    uint8_t dst = (arg >> 8) & 0x0F;
    uint8_t src = arg & 0x0F;
    regs[dst] -= regs[src];
    // Rotate result for extra diffusion
    uint8_t rot = (uint8_t)((*junk & 0x3F) | 1);
    volatile uint64_t rotated = (regs[dst] << rot) | (regs[dst] >> (64 - rot));
    regs[dst] = (regs[dst] << rot) | (regs[dst] >> (64 - rot));
    // Undo rotation (identity) but generates more code
    regs[dst] = (regs[dst] >> rot) | (regs[dst] << (64 - rot));
    regs[dst] -= regs[src]; // actual subtraction was already done
    regs[dst] += regs[src]; // undo the double subtract
    *junk ^= rotated;
    return regs[dst];
}

VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static uint64_t _vt_handler_mul_mix(uint64_t* regs, uint64_t arg, volatile uint64_t* junk) {
    uint8_t dst = (arg >> 8) & 0x0F;
    uint8_t src = arg & 0x0F;
    regs[dst] *= regs[src];
    *junk = (*junk ^ regs[dst]) * 0x100000001B3ULL;
    return regs[dst];
}

VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static uint64_t _vt_handler_not_inv(uint64_t* regs, uint64_t arg, volatile uint64_t* junk) {
    uint8_t dst = (arg >> 8) & 0x0F;
    regs[dst] = ~regs[dst];
    // Double NOT is identity but adds noise
    if (_vt_opaque_false()) regs[dst] = ~regs[dst];
    *junk ^= regs[dst];
    return regs[dst];
}

VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static uint64_t _vt_handler_sbox_transform(uint64_t* regs, uint64_t arg, volatile uint64_t* junk) {
    uint8_t dst = (arg >> 8) & 0x0F;
    // Apply S-box byte-by-byte to register value
    uint64_t val = regs[dst];
    uint64_t result = 0;
    for (int i = 0; i < 8; ++i) {
        uint8_t byte = (uint8_t)(val >> (i * 8));
        byte = _obf_::sbox[byte];
        result |= ((uint64_t)byte) << (i * 8);
    }
    regs[dst] = result;
    *junk ^= result + 0xA5A5A5A5ULL;
    return result;
}

// ─── Virtualizer Engine: Main Dispatch ────────────────────────
enum VTOpcode : uint8_t {
    VT_XOR = 0 ^ VTIZER_XOR_LAYER1, VT_ADD = 1 ^ VTIZER_XOR_LAYER1,
    VT_SUB = 2 ^ VTIZER_XOR_LAYER1, VT_MUL = 3 ^ VTIZER_XOR_LAYER1,
    VT_NOT = 4 ^ VTIZER_XOR_LAYER1, VT_SBOX = 5 ^ VTIZER_XOR_LAYER1,
};
VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static uint64_t vt_dispatch(uint8_t handler_id, uint64_t* regs,
                            uint64_t arg, volatile uint64_t* junk, bool* valid = nullptr) {
    if (valid) *valid = false;
    if (!regs || !junk || (arg >> 16) || ((arg >> 8) & 0xFF) >= 16 || (arg & 0xFF) >= 16) return 0;
    uint8_t resolved = handler_id ^ VTIZER_XOR_LAYER1;
    if (resolved >= 6) return 0;
    if (valid) *valid = true;
    switch (resolved) {
        case 0: return _vt_handler_xor_cascade(regs, arg, junk);
        case 1: return _vt_handler_add_chain(regs, arg, junk);
        case 2: return _vt_handler_sub_rot(regs, arg, junk);
        case 3: return _vt_handler_mul_mix(regs, arg, junk);
        case 4: return _vt_handler_not_inv(regs, arg, junk);
        default: return _vt_handler_sbox_transform(regs, arg, junk);
    }
}
VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static bool vt_verify_integrity() {
    uint64_t regs[16] = {0x12345678, 0x5A};
    volatile uint64_t junk = VTIZER_INTEGRITY_MAGIC;
    bool valid = false;
    if (vt_dispatch(VT_ADD, regs, 1, &junk, &valid) != 0x123456D2 || !valid) return false;
    if (vt_dispatch(VT_SUB, regs, 1, &junk, &valid) != 0x12345678 || !valid) return false;
    if (vt_dispatch(VT_XOR, regs, 1, &junk, &valid) != (0x12345678 ^ 0x5A) || !valid) return false;
    return true;
}

VTIZER_NOINLINE VTIZER_HIDDEN VTIZER_SECTION
static uint64_t vt_run_sequence(const uint8_t* ops, const uint64_t* args,
                                size_t count, uint64_t initial_value) {
    if ((!ops || !args) && count) return 0;
    if (count > 4096) return 0;
    uint64_t regs[16] = {};
    regs[0] = initial_value;
    volatile uint64_t junk = VTIZER_INTEGRITY_MAGIC ^ initial_value;

    for (size_t i = 0; i < count; ++i) {
        bool valid = false;
        vt_dispatch(ops[i], regs, args[i], &junk, &valid);
        if (!valid) return 0;
    }

    return regs[0] ^ (junk & 0);  // junk ANDed with 0 = 0, but compiler can't know
}

} // namespace _vtizer_

// ─── High-level macros ────────────────────────────────────────
#define VTIZER_PROTECT(expr) \
    ([&]() -> decltype(expr) { \
        if (!_vtizer_::vt_verify_integrity()) { \
            /* Integrity check failed — silently return default, no crash */ \
            return decltype(expr){}; \
        } \
        return (expr); \
    }())

#define VTIZER_DISPATCH(handler_id, regs, arg, junk) \
    _vtizer_::vt_dispatch((handler_id), (regs), (arg), (junk))

#endif // VTIZER_ENGINE_H
