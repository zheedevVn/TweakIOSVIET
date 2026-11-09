#ifndef VDATA_STORE_H
#define VDATA_STORE_H

/* Obfuscated constants, buffers, pointers and sequenced runtime values.
 * Reversible encoding reduces plain literals; it is not cryptographic encryption. */

#include <cstdint>
#include <cstddef>
#include <cstring>
#include <mutex>
#include "ObfuscationPlatform.h"

#if defined(__clang__) || defined(__GNUC__)
  #define VDATA_SECTION OBF_CODE_SECTION("__vd_text")
  #define VDATA_NOINLINE   __attribute__((noinline))
  #define VDATA_HIDDEN     OBF_HIDDEN
  #define VDATA_USED       __attribute__((used))
  #define VDATA_INLINE     inline __attribute__((always_inline))
#else
  #define VDATA_SECTION
  #define VDATA_NOINLINE
  #define VDATA_HIDDEN
  #define VDATA_USED
  #define VDATA_INLINE     inline
#endif

#define VDATA_DATA_SECTION OBF_DATA_SECTION("__vdata")

namespace _vdata_ {

// ─── Compile-time seed ────────────────────────────────────────
static constexpr uint64_t _vd_seed() { return _obf_::BuildSeed; }
static constexpr uint64_t VDATA_SEED = _vd_seed();

constexpr uint64_t _vd_mix(uint64_t a, uint64_t b) {
    uint64_t h = a ^ (b * 0x517CC1B727220A95ULL);
    h ^= h >> 30;
    h *= 0xBF58476D1CE4E5B9ULL;
    h ^= h >> 27;
    h *= 0x94D049BB133111EBULL;
    return h ^ (h >> 31);
}

// ─── Encryption keys (per-build) ──────────────────────────────
static constexpr uint64_t VDATA_KEY1 = _vd_mix(VDATA_SEED, 0x1111111111111111ULL);
static constexpr uint64_t VDATA_KEY2 = _vd_mix(VDATA_SEED, 0x2222222222222222ULL);
static constexpr uint64_t VDATA_KEY3 = _vd_mix(VDATA_SEED, 0x3333333333333333ULL);
static constexpr uint64_t VDATA_KEY4 = _vd_mix(VDATA_SEED, 0x4444444444444444ULL);

static constexpr uint8_t  VDATA_BYTE_KEY1 = (uint8_t)(VDATA_KEY1 & 0xFF);
static constexpr uint8_t  VDATA_BYTE_KEY2 = (uint8_t)((VDATA_KEY1 >> 8) & 0xFF);
static constexpr uint8_t  VDATA_BYTE_ROT  = (uint8_t)(((VDATA_KEY1 >> 16) % 7) + 1);
static constexpr uint8_t  VDATA_SBOX_KEY  = (uint8_t)((VDATA_KEY2 >> 24) & 0xFF);

// ─── Encrypt a 64-bit value at compile time ───────────────────
constexpr uint64_t vd_encrypt_u64(uint64_t val, uint64_t slot_id) {
    uint64_t k = _vd_mix(VDATA_KEY1, slot_id);
    val ^= k;
    val = (val << 17) | (val >> 47);
    val ^= _vd_mix(VDATA_KEY2, slot_id);
    val += _vd_mix(VDATA_KEY3, slot_id);
    val = (val << 23) | (val >> 41);
    val ^= _vd_mix(VDATA_KEY4, slot_id);
    return val;
}

// ─── Decrypt a 64-bit value at runtime ────────────────────────
VDATA_NOINLINE VDATA_HIDDEN VDATA_SECTION
static uint64_t vd_decrypt_u64(uint64_t enc, uint64_t slot_id) {
    volatile uint64_t junk = VDATA_KEY1 ^ VDATA_KEY2; // anti-optimization

    uint64_t val = enc;
    val ^= _vd_mix(VDATA_KEY4, slot_id);
    val = (val >> 23) | (val << 41);
    val -= _vd_mix(VDATA_KEY3, slot_id);
    val ^= _vd_mix(VDATA_KEY2, slot_id);
    val = (val >> 17) | (val << 47);
    uint64_t k = _vd_mix(VDATA_KEY1, slot_id);
    val ^= k;

    junk ^= val; // prevent dead code elimination
    return val;
}

// ─── Encrypt a byte buffer at compile time ────────────────────
constexpr uint8_t vd_encrypt_byte(uint8_t b, size_t idx, uint64_t slot_id) {
    uint8_t t = b;
    uint8_t k = (uint8_t)(_vd_mix(VDATA_KEY1, slot_id + idx) & 0xFF);
    t ^= k;
    t ^= VDATA_BYTE_KEY1;
    t = (uint8_t)(t + VDATA_BYTE_KEY2);
    t = (uint8_t)((t << VDATA_BYTE_ROT) | (t >> (8 - VDATA_BYTE_ROT)));
    t ^= VDATA_SBOX_KEY;
    t ^= (uint8_t)(idx * 0x37);
    return t;
}

// ─── Decrypt a byte buffer at runtime ─────────────────────────
VDATA_NOINLINE VDATA_HIDDEN VDATA_SECTION
static uint8_t vd_decrypt_byte(uint8_t b, size_t idx, uint64_t slot_id) {
    volatile uint8_t t = b;
    t ^= (uint8_t)(idx * 0x37);
    t ^= VDATA_SBOX_KEY;
    t = (uint8_t)((t >> VDATA_BYTE_ROT) | (t << (8 - VDATA_BYTE_ROT)));
    t = (uint8_t)(t - VDATA_BYTE_KEY2);
    t ^= VDATA_BYTE_KEY1;
    uint8_t k = (uint8_t)(_vd_mix(VDATA_KEY1, slot_id + idx) & 0xFF);
    t ^= k;
    return t;
}

// ─── Compile-time encrypted data slot (uint64_t) ──────────────
template <uint64_t Value, uint64_t SlotID>
struct VDSlot {
    static constexpr uint64_t encrypted = vd_encrypt_u64(Value, SlotID);

    VDATA_NOINLINE static uint64_t get() {
        return vd_decrypt_u64(encrypted, SlotID);
    }
};

// ─── Compile-time encrypted byte array ────────────────────────
template <size_t N, uint64_t SlotID>
struct VDBuffer {
    uint8_t data[N];

    template <size_t... I>
    constexpr VDBuffer(const uint8_t (&src)[N], _obf_::Seq<I...>)
        : data{ vd_encrypt_byte(src[I], I, SlotID)... } {}

    VDATA_NOINLINE bool decrypt_to(uint8_t* out, size_t capacity = N) const {
        if (!out || capacity < N) return false;
        for (size_t i = 0; i < N; ++i) {
            out[i] = vd_decrypt_byte(data[i], i, SlotID);
        }
        return true;
    }
};

// ─── Rolling key: mutates encryption key each access ──────────
// Each packet retains its matching decode sequence.
struct VDSealedValue {
    uint64_t encrypted;
    uint64_t sequence;
    uint64_t tag;
};

class VDRollingKey {
    std::mutex mutex_;
    uint64_t master_ = 0;
    uint64_t sequence_ = 0;
    bool ready_ = false;
    VDSealedValue legacy_{};
    bool has_legacy_ = false;

    uint64_t key(uint64_t sequence) const { return _vd_mix(master_, sequence); }
    uint64_t tag(const VDSealedValue& value) const {
        return _vd_mix(key(value.sequence) ^ value.encrypted, VDATA_KEY2);
    }
    VDSealedValue seal_locked(uint64_t value) {
        uint64_t sequence = ++sequence_;
        uint64_t k = key(sequence);
        VDSealedValue packet{_obf_::rotate_left(value ^ k, 13) ^ _vd_mix(k, VDATA_KEY2), sequence, 0};
        packet.tag = tag(packet);
        return packet;
    }
    bool open_locked(const VDSealedValue& packet, uint64_t& value) const {
        if (!ready_ || !packet.sequence || packet.tag != tag(packet)) return false;
        uint64_t k = key(packet.sequence);
        value = _obf_::rotate_left(packet.encrypted ^ _vd_mix(k, VDATA_KEY2), 51) ^ k;
        return true;
    }
public:
    VDATA_NOINLINE void init(uint64_t seed) {
        std::lock_guard<std::mutex> lock(mutex_);
        master_ = _vd_mix(seed, VDATA_KEY1);
        sequence_ = 0;
        ready_ = true;
        has_legacy_ = false;
    }
    // Thread-safe packets keep their own sequence, so out-of-order reads work.
    // Tag is a corruption check, not a cryptographic authentication guarantee.
    VDATA_NOINLINE VDSealedValue seal(uint64_t value) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!ready_ || sequence_ == UINT64_MAX) return {};
        return seal_locked(value);
    }
    VDATA_NOINLINE bool open(const VDSealedValue& packet, uint64_t& value) {
        std::lock_guard<std::mutex> lock(mutex_);
        return open_locked(packet, value);
    }
    VDATA_NOINLINE uint64_t next() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!ready_ || sequence_ == UINT64_MAX) return 0;
        return key(++sequence_);
    }
    // Legacy API supports only the latest value. Prefer seal/open for new code.
    VDATA_NOINLINE uint64_t encrypt_with_rolling(uint64_t value) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!ready_ || sequence_ == UINT64_MAX) return 0;
        legacy_ = seal_locked(value);
        has_legacy_ = true;
        return legacy_.encrypted;
    }
    VDATA_NOINLINE uint64_t decrypt_with_rolling(uint64_t encrypted) {
        std::lock_guard<std::mutex> lock(mutex_);
        uint64_t value = 0;
        if (!has_legacy_ || encrypted != legacy_.encrypted) return 0;
        return open_locked(legacy_, value) ? value : 0;
    }
};

// ─── Anti-dump: Encrypted pointer storage ─────────────────────
VDATA_NOINLINE VDATA_HIDDEN VDATA_SECTION
static uintptr_t vd_encrypt_ptr(uintptr_t ptr) {
    volatile uintptr_t p = ptr;
    p ^= (uintptr_t)VDATA_KEY1;
    p = (p << 7) | (p >> (sizeof(uintptr_t) * 8 - 7));
    p ^= (uintptr_t)VDATA_KEY2;
    return p;
}

VDATA_NOINLINE VDATA_HIDDEN VDATA_SECTION
static uintptr_t vd_decrypt_ptr(uintptr_t enc) {
    volatile uintptr_t p = enc;
    p ^= (uintptr_t)VDATA_KEY2;
    p = (p >> 7) | (p << (sizeof(uintptr_t) * 8 - 7));
    p ^= (uintptr_t)VDATA_KEY1;
    return p;
}

} // namespace _vdata_

// ─── Convenience Macros ───────────────────────────────────────

// Store a compile-time encrypted 64-bit constant
#define VDATA_CONST(value) \
    (_vdata_::VDSlot<(uint64_t)(value), (uint64_t)__COUNTER__ * 0x100ULL + __LINE__>::get())

// Encrypt a pointer at runtime
#define VDATA_ENC_PTR(ptr) \
    _vdata_::vd_encrypt_ptr((uintptr_t)(ptr))

// Decrypt a pointer at runtime
#define VDATA_DEC_PTR(type, enc) \
    ((type)_vdata_::vd_decrypt_ptr((uintptr_t)(enc)))

#endif // VDATA_STORE_H
