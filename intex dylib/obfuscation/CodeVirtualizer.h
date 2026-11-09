#ifndef CODE_VIRTUALIZER_H
#define CODE_VIRTUALIZER_H

/* Bounded interpreter for compile-time obfuscated bytecode.
 * All code sections are executable __TEXT sections on Apple platforms. */

#include <cstdint>
#include <cstddef>
#include <cstring>
#include "ObfuscationPlatform.h"

#if defined(__clang__) || defined(__GNUC__)
  #define CVIRT_SECTION OBF_CODE_SECTION("__cv_text")
  #define CVIRT_NOINLINE   __attribute__((noinline))
  #define CVIRT_HIDDEN     OBF_HIDDEN
  #define CVIRT_USED       __attribute__((used))
  #define CVIRT_INLINE     inline __attribute__((always_inline))
#else
  #define CVIRT_SECTION
  #define CVIRT_NOINLINE
  #define CVIRT_HIDDEN
  #define CVIRT_USED
  #define CVIRT_INLINE     inline
#endif

namespace _cv_ {

// ─── Compile-time opcode generation ───────────────────────────
// Each build shuffles opcode assignments via the shared build seed
static constexpr uint64_t _cv_seed() { return _obf_::BuildSeed; }

static constexpr uint64_t CVIRT_SEED = _cv_seed();

constexpr uint64_t _cv_mix(uint64_t a, uint64_t b) {
    uint64_t h = a ^ (b * 0x9E3779B97F4A7C15ULL);
    h ^= h >> 30;
    h *= 0xBF58476D1CE4E5B9ULL;
    h ^= h >> 27;
    h *= 0x94D049BB133111EBULL;
    return h ^ (h >> 31);
}

// Opcode table – remapped per build
constexpr uint8_t cv_opcode(unsigned index) {
    return (uint8_t)(index * ((_cv_mix(CVIRT_SEED, 50) & 0xFE) | 1) +
                     (_cv_mix(CVIRT_SEED, 51) & 0xFF));
}
static constexpr size_t CVIRT_MAX_STEPS = 4096;
static constexpr size_t CVIRT_MAX_BYTECODE = 4096;

enum CVOpcode : uint8_t {
    CVIRT_NOP      = cv_opcode(0),
    CVIRT_LOAD     = cv_opcode(1),
    CVIRT_STORE    = cv_opcode(2),
    CVIRT_XOR      = cv_opcode(3),
    CVIRT_ADD      = cv_opcode(4),
    CVIRT_SUB      = cv_opcode(5),
    CVIRT_ROT      = cv_opcode(6),
    CVIRT_JMP      = cv_opcode(7),
    CVIRT_JZ       = cv_opcode(8),
    CVIRT_CMP      = cv_opcode(9),
    CVIRT_CALL     = cv_opcode(10),
    CVIRT_RET      = cv_opcode(11),
    CVIRT_MUL      = cv_opcode(12),
    CVIRT_NOT      = cv_opcode(13),
    CVIRT_AND      = cv_opcode(14),
    CVIRT_OR       = cv_opcode(15),
    CVIRT_SHL      = cv_opcode(16),
    CVIRT_SHR      = cv_opcode(17),
    CVIRT_PUSH     = cv_opcode(18),
    CVIRT_POP      = cv_opcode(19),
    CVIRT_HALT     = cv_opcode(20),
};

// ─── Virtual Machine State ────────────────────────────────────
struct CVMState {
    uint64_t regs[16];       // 16 general-purpose virtual registers
    uint64_t stack[256];     // Virtual stack
    uint32_t sp;             // Stack pointer
    uint32_t ip;             // Instruction pointer
    uint64_t flags;          // Condition flags
    volatile uint64_t junk;  // Anti-optimization junk accumulator
};

// ─── Bytecode encryption key (per-build) ──────────────────────
static constexpr uint8_t CVIRT_BYTECODE_KEY  = (uint8_t)(_cv_mix(CVIRT_SEED, 100) & 0xFF);
static constexpr uint8_t CVIRT_BYTECODE_KEY2 = (uint8_t)(_cv_mix(CVIRT_SEED, 101) & 0xFF);
static constexpr uint8_t CVIRT_BYTECODE_ROT  = (uint8_t)((_cv_mix(CVIRT_SEED, 102) % 7) + 1);

// ─── Bytecode Encryptor (compile-time) ────────────────────────
constexpr uint8_t cv_encrypt_byte(uint8_t b, size_t idx) {
    uint8_t t = b;
    t ^= CVIRT_BYTECODE_KEY;
    t = (uint8_t)(t + (uint8_t)(idx * 7));
    t ^= CVIRT_BYTECODE_KEY2;
    t = (uint8_t)((t << CVIRT_BYTECODE_ROT) | (t >> (8 - CVIRT_BYTECODE_ROT)));
    return t;
}

// ─── Bytecode Decryptor (runtime) ─────────────────────────────
CVIRT_NOINLINE CVIRT_HIDDEN CVIRT_SECTION
static uint8_t cv_decrypt_byte(uint8_t b, size_t idx) {
    volatile uint8_t t = b;
    t = (uint8_t)((t >> CVIRT_BYTECODE_ROT) | (t << (8 - CVIRT_BYTECODE_ROT)));
    t ^= CVIRT_BYTECODE_KEY2;
    t = (uint8_t)(t - (uint8_t)(idx * 7));
    t ^= CVIRT_BYTECODE_KEY;
    return t;
}

// ─── VM Interpreter (executable __TEXT section) ──────────────────
CVIRT_NOINLINE CVIRT_HIDDEN CVIRT_SECTION
static uint64_t cv_execute(const uint8_t* bytecode, size_t len,
                           uint64_t arg0 = 0, uint64_t arg1 = 0,
                           uint64_t arg2 = 0, uint64_t arg3 = 0, bool* valid = nullptr) {
    if (valid) *valid = false;
    if (!bytecode || !len || len > CVIRT_MAX_BYTECODE) return 0;
    CVMState vm;
    __builtin_memset(&vm, 0, sizeof(vm));
    vm.regs[0] = arg0;
    vm.regs[1] = arg1;
    vm.regs[2] = arg2;
    vm.regs[3] = arg3;
    vm.sp = 0;
    vm.ip = 0;
    vm.junk = 0xDEADC0DEULL;

    // Mix bytecode into local interpreter noise (not an integrity comparison).
    volatile uint32_t checksum = 0;
    for (size_t i = 0; i < len; ++i) {
        checksum = (checksum * 31U) + bytecode[i];
    }
    vm.junk ^= checksum;

    size_t steps = 0;
    while (vm.ip < len) {
        if (++steps > CVIRT_MAX_STEPS) return 0;
        uint8_t raw = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
        vm.ip++;

        // Junk computation to confuse pattern matching
        vm.junk = (vm.junk * 0x5DEECE66DULL + 0xBULL) ^ raw;

        if (raw == CVIRT_NOP) {
            vm.junk ^= vm.regs[0];
            continue;
        }
        else if (raw == CVIRT_LOAD && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t val = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
            vm.ip++;
            vm.regs[dst] = val;
        }
        else if (raw == CVIRT_STORE && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] = vm.regs[src];
        }
        else if (raw == CVIRT_XOR && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] ^= vm.regs[src];
        }
        else if (raw == CVIRT_ADD && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] += vm.regs[src];
        }
        else if (raw == CVIRT_SUB && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] -= vm.regs[src];
        }
        else if (raw == CVIRT_ROT && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t bits = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x3F;
            vm.ip++;
            vm.regs[dst] = _obf_::rotate_left(vm.regs[dst], bits);
        }
        else if (raw == CVIRT_MUL && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] *= vm.regs[src];
        }
        else if (raw == CVIRT_NOT && vm.ip + 1 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] = ~vm.regs[dst];
        }
        else if (raw == CVIRT_AND && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] &= vm.regs[src];
        }
        else if (raw == CVIRT_OR && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.regs[dst] |= vm.regs[src];
        }
        else if (raw == CVIRT_SHL && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t bits = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x3F;
            vm.ip++;
            vm.regs[dst] <<= bits;
        }
        else if (raw == CVIRT_SHR && vm.ip + 2 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t bits = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x3F;
            vm.ip++;
            vm.regs[dst] >>= bits;
        }
        else if (raw == CVIRT_PUSH && vm.ip + 1 <= len) {
            uint8_t src = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            if (vm.sp >= 256) return 0;
            vm.stack[vm.sp++] = vm.regs[src];
        }
        else if (raw == CVIRT_POP && vm.ip + 1 <= len) {
            uint8_t dst = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            if (!vm.sp) return 0;
            vm.regs[dst] = vm.stack[--vm.sp];
        }
        else if (raw == CVIRT_JMP && vm.ip + 1 <= len) {
            uint8_t target = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
            if (target >= len) return 0;
            vm.ip = target;
        }
        else if (raw == CVIRT_JZ && vm.ip + 2 <= len) {
            uint8_t reg = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t target = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
            vm.ip++;
            if (target >= len) return 0;
            if (vm.regs[reg] == 0) vm.ip = target;
        }
        else if (raw == CVIRT_CMP && vm.ip + 2 <= len) {
            uint8_t a = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            uint8_t b = cv_decrypt_byte(bytecode[vm.ip], vm.ip) & 0x0F;
            vm.ip++;
            vm.flags = (vm.regs[a] == vm.regs[b]) ? 1 : 0;
        }
        else if (raw == CVIRT_CALL && vm.ip + 1 <= len) {
            uint8_t target = cv_decrypt_byte(bytecode[vm.ip], vm.ip);
            vm.ip++;
            if (vm.sp >= 256 || target >= len) return 0;
            vm.stack[vm.sp++] = vm.ip;
            vm.ip = target;
        }
        else if (raw == CVIRT_RET) {
            if (!vm.sp) { if (valid) *valid = true; return vm.regs[0]; }
            uint64_t target = vm.stack[--vm.sp];
            if (target >= len) return 0;
            vm.ip = (uint32_t)target;
        }
        else if (raw == CVIRT_HALT) {
            if (valid) *valid = true;
            return vm.regs[0];
        }
        else { return 0; } // Unknown or truncated instruction.

        // Anti-tamper junk mix after each instruction
        vm.junk = (vm.junk ^ vm.regs[vm.ip & 0x0F]) + 0x1337CAFEULL;
    }

    return 0; // Explicit termination is required.

}

// ─── Helper: Build encrypted bytecode at compile time ─────────
template <size_t N>
struct CVBytecode {
    uint8_t data[N];
    static constexpr size_t size = N;

    template <size_t... I>
    constexpr CVBytecode(const uint8_t (&src)[N], _obf_::Seq<I...>)
        : data{ cv_encrypt_byte(src[I], I)... } {}

    CVIRT_INLINE uint64_t run(uint64_t a0 = 0, uint64_t a1 = 0,
                              uint64_t a2 = 0, uint64_t a3 = 0) const {
        return cv_execute(data, N, a0, a1, a2, a3);
    }
};

// ─── Macro to virtualize an integrity-check value ─────────────
// Usage: CVIRT_PROTECT_VALUE(my_check, { CVIRT_LOAD, 0, 42, CVIRT_XOR, 0, 1, CVIRT_HALT })
#define CVIRT_PROTECT_VALUE(name, ...) \
    static constexpr uint8_t _cv_raw_##name[] = __VA_ARGS__; \
    static constexpr auto name = _cv_::CVBytecode<sizeof(_cv_raw_##name)>( \
        _cv_raw_##name, typename _obf_::MakeSeq<sizeof(_cv_raw_##name)>::type())

} // namespace _cv_

// ─── Convenience macros ───────────────────────────────────────
#define CVIRT_VIRTUALIZE_BEGIN   /* marker for virtualizer pass */
#define CVIRT_VIRTUALIZE_END     /* marker for virtualizer pass */

#endif // CODE_VIRTUALIZER_H
