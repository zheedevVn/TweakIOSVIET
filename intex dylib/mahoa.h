#pragma once

#include <stdio.h>
#include <stdint.h>

#include <chrono>

static inline uint64_t now_ms() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()
    ).count();
}

#if defined(_MSC_VER)
  #define ALWAYS_INLINE __forceinline
#else
  #define ALWAYS_INLINE __attribute__((always_inline))
#endif

#ifndef CPP_SEED
constexpr int seedToInt(char c) { return c - '0'; }
const int CPP_SEED = seedToInt(__TIME__[7]) +
                     seedToInt(__TIME__[6]) * 10 +
                     seedToInt(__TIME__[4]) * 60 +
                     seedToInt(__TIME__[3]) * 600 +
                     seedToInt(__TIME__[1]) * 3600 +
                     seedToInt(__TIME__[0]) * 36000;
#endif

template <uintptr_t Const> struct vxCplConstantify { enum { Value = Const }; };
constexpr uintptr_t vxCplRandom(uintptr_t Id) {
    return (1013904223 + 1664525 * ((Id > 0) ? vxCplRandom(Id - 1) : CPP_SEED)) & 0xFFFFFFFF;
}

#define vxRAND() (vxCplConstantify<vxCplRandom(__COUNTER__ + 1)>::Value)
#define vxRANDOM(Min,Max) ( (Min) + (vxRAND() % ((Max)-(Min)+1)) )

constexpr char vxCplTolower(char Ch)  { return (Ch >= 'A' && Ch <= 'Z') ? (Ch - 'A' + 'a') : Ch; }
constexpr uintptr_t vxCplHashPart1(char Ch, uintptr_t Hash) {
    return ((Hash << 4) + vxCplTolower(Ch) ^ (((Hash << 4) + vxCplTolower(Ch)) & 0xF0000000) >> 23) & 0x0FFFFFFF;
}
constexpr uintptr_t vxCplHash(const char* Str) {
    return *Str ? vxCplHashPart1(*Str, vxCplHash(Str + 1)) : 0;
}

template <uintptr_t...> struct vxCplIndexList {};
template <typename IndexList, uintptr_t Right> struct vxCplAppend;
template <uintptr_t... Left, uintptr_t Right>
struct vxCplAppend<vxCplIndexList<Left...>, Right> {
    typedef vxCplIndexList<Left..., Right> Result;
};
template <uintptr_t N>
struct vxCplIndexes { typedef typename vxCplAppend<typename vxCplIndexes<N-1>::Result, N-1>::Result Result; };
template <> struct vxCplIndexes<0> { typedef vxCplIndexList<> Result; };

struct Egcd { long long gcd, x, y; };
constexpr Egcd extended_gcd(long long a, long long b) {
    long long old_r = a, r = b, old_s = 1, s = 0, old_t = 0, t = 1;
    while (r != 0) {
        long long q = old_r / r;
        long long tmp = r; r = old_r - q*r; old_r = tmp;
        tmp = s; s = old_s - q*s; old_s = tmp;
        tmp = t; t = old_t - q*t; old_t = tmp;
    }
    return {old_r, old_s, old_t};
}

constexpr uint8_t bit_reverse8(uint8_t b) {
    b = ((b >> 1) & 0x55u) | ((b & 0x55u) << 1);
    b = ((b >> 2) & 0x33u) | ((b & 0x33u) << 2);
    b = ((b >> 4) & 0x0Fu) | ((b & 0x0Fu) << 4);
    return b;
}

constexpr uint32_t bit_reverse32(uint32_t b) {
    b = ((b >> 1) & 0x55555555u) | ((b & 0x55555555u) << 1);
    b = ((b >> 2) & 0x33333333u) | ((b & 0x33333333u) << 2);
    b = ((b >> 4) & 0x0F0F0F0Fu) | ((b & 0x0F0F0F0Fu) << 4);
    b = ((b >> 8) & 0x00FF00FFu) | ((b & 0x00FF00FFu) << 8);
    b = (b >> 16) | (b << 16);
    return b;
}

template<uintptr_t MacroID, uintptr_t StringHash>
struct PerMacroData {
    static constexpr uintptr_t HashSalt = vxCplRandom(MacroID);

    static constexpr uintptr_t FinalHash = StringHash ^ HashSalt;

    static constexpr uint8_t EncryptCharKey = (uint8_t)vxCplRandom(MacroID + 1);
    static constexpr uint8_t EncryptXorKey   = (uint8_t)vxCplRandom(MacroID + 2);
    static constexpr uint8_t EncryptAddKey   = (uint8_t)vxCplRandom(MacroID + 3);
    static constexpr uint8_t RotateKey       = (uint8_t)(vxCplRandom(MacroID + 4) % 7 + 1);
    static constexpr uint8_t EncryptXorKey2  = (uint8_t)vxCplRandom(MacroID + 5);
    static constexpr uint8_t EncryptAddKey2  = (uint8_t)vxCplRandom(MacroID + 6);
    static constexpr uint8_t EncryptSubKey   = (uint8_t)vxCplRandom(MacroID + 7);
    static constexpr uint8_t RotateKey2      = (uint8_t)(vxCplRandom(MacroID + 8) % 7 + 1);
    static constexpr uint8_t EncryptXorKey3  = (uint8_t)vxCplRandom(MacroID + 9);
    static constexpr uint8_t EncryptAddKey3  = (uint8_t)vxCplRandom(MacroID + 10);
    static constexpr uint8_t EncryptSubKey2  = (uint8_t)vxCplRandom(MacroID + 11);
    static constexpr uint8_t RotateKey3      = (uint8_t)(vxCplRandom(MacroID + 12) % 7 + 1);
    static constexpr uint8_t EncryptXorKey4  = (uint8_t)vxCplRandom(MacroID + 13);
    static constexpr uint8_t EncryptAddKey4  = (uint8_t)vxCplRandom(MacroID + 14);
    static constexpr uint8_t EncryptSubKey3  = (uint8_t)vxCplRandom(MacroID + 15);
    static constexpr uint8_t RotateKey4      = (uint8_t)(vxCplRandom(MacroID + 16) % 7 + 1);
    static constexpr uint8_t EncryptXorKey5  = (uint8_t)vxCplRandom(MacroID + 17);
    static constexpr uint8_t EncryptAddKey5  = (uint8_t)vxCplRandom(MacroID + 18);

    static constexpr uint8_t IndexDependentAddKey = (uint8_t)vxCplRandom(MacroID + 19);

    static constexpr uint8_t MultKey1    = (uint8_t)((vxCplRandom(MacroID + 20) % 128) * 2 + 1);
    static constexpr uint8_t InvMultKey1 = (uint8_t)(((extended_gcd(MultKey1, 256).x % 256) + 256) % 256);
    static constexpr uint8_t MultKey2    = (uint8_t)((vxCplRandom(MacroID + 21) % 128) * 2 + 1);
    static constexpr uint8_t InvMultKey2 = (uint8_t)(((extended_gcd(MultKey2, 256).x % 256) + 256) % 256);
};

template<typename MacroData>
constexpr ALWAYS_INLINE char vxCplEncryptChar(const char Ch, uintptr_t Idx)
{
    uint8_t temp = (uint8_t)Ch;
    temp ^= (uint8_t)(MacroData::EncryptCharKey + Idx);
    temp ^= MacroData::EncryptXorKey;
    temp = (uint8_t)(temp + MacroData::EncryptAddKey);
    temp = (uint8_t)(~temp);
    temp ^= 0xA5u;
    temp = (uint8_t)((temp << MacroData::RotateKey) | (temp >> (8 - MacroData::RotateKey)));
    if (Idx & 1) temp ^= (uint8_t)(MacroData::EncryptAddKey * 3);
    if ((Idx % 3) == 0) temp ^= (uint8_t)(MacroData::FinalHash & 0xFF);

    temp ^= MacroData::EncryptXorKey2;
    temp = (uint8_t)(temp + MacroData::EncryptAddKey2);
    temp = (uint8_t)(temp - MacroData::EncryptSubKey);
    temp = (uint8_t)((temp << MacroData::RotateKey2) | (temp >> (8 - MacroData::RotateKey2)));
    temp ^= MacroData::EncryptXorKey3;
    temp = (uint8_t)(temp + MacroData::EncryptAddKey3);
    temp = (uint8_t)(temp - MacroData::EncryptSubKey2);
    temp = (uint8_t)((temp >> MacroData::RotateKey3) | (temp << (8 - MacroData::RotateKey3)));

    temp = (uint8_t)((temp >> 4) | (temp << 4));

    temp ^= MacroData::EncryptXorKey4;
    temp = (uint8_t)(temp + MacroData::EncryptAddKey4);
    temp = (uint8_t)(temp - MacroData::EncryptSubKey3);
    temp = (uint8_t)((temp << MacroData::RotateKey4) | (temp >> (8 - MacroData::RotateKey4)));
    temp = (uint8_t)(((uint16_t)temp * MacroData::MultKey1) & 0xFF);
    temp ^= MacroData::EncryptXorKey5;
    temp = (uint8_t)(((uint16_t)temp * MacroData::MultKey2 + MacroData::EncryptAddKey5) & 0xFF);

    if (Idx & 1) {
        temp = (uint8_t)(temp + MacroData::IndexDependentAddKey);
    } else {
        temp = (uint8_t)(temp - MacroData::IndexDependentAddKey);
    }

    temp = (char)bit_reverse8(temp);
    return (char)temp;
}

template <typename MacroData, typename IndexList> struct vxCplEncryptedString;
template <typename MacroData, uintptr_t... Idx>
struct vxCplEncryptedString<MacroData, vxCplIndexList<Idx...>>
{
    char Value[sizeof...(Idx) + 1];

    constexpr ALWAYS_INLINE vxCplEncryptedString(const char* const Str)
        : Value{ vxCplEncryptChar<MacroData>(Str[Idx], Idx)... } {}

    inline char* decrypt()
    {
        static volatile int vxCplNever = 0;
        if (vxCplNever) {
            for (uintptr_t j = 0; j < sizeof...(Idx); ++j) {
                volatile uint8_t z = (uint8_t)Value[j];
                z ^= (uint8_t)(MacroData::EncryptCharKey + j);
            }
        }

        volatile uint8_t v65[11];
        int v55 = 0;
        volatile uint64_t v56 = vxCplRandom(42) & 0xB94240;
        uint8_t v57, v58, v59;
        int v60;
        uint8_t v61;
        int v62;
        do
        {
            v57 = ((Value[v55 % sizeof...(Idx)] ^ (v55 - 109) ^ 0x29) - 61) ^ 0xA5;
            v58 = (v57 >> 1) | (v57 << 7);
            v59 = v58 ^ 0xB7;
            if ( (v55 & 1) == 0 ) v59 = v58;
            if ( (uint8_t)(-85 * v55) >= 0x56u ) v60 = 0;
            else v60 = -1;
            v61 = ((((uint8_t)((v59 ^ v60 ^ 0x77) - 87) >> 3) | (32 * ((v59 ^ v60 ^ 0x77) - 87))) ^ 0x9B) - 71;
            v62 = 85 * (((uint8_t)((v61 >> 1) | (v61 << 7)) + 62) ^ (v55 + 82)) + 163;
            uint32_t temp_calc = ((16 * v62) | ((uint8_t)v62 >> 4)) ^ 0x6A;
            uint32_t reversed = bit_reverse32(temp_calc);
            v65[v55++] = (reversed >> 24) ^ 0xCD;
        }
        while ( v55 != 11 );
        long v66 = -1434932611;
        int v67 = -4155;
        int v68 = 57;

        uintptr_t i = 0;
        volatile uint8_t dummy = 0;
        int state = 0;
        while (true) {
            switch (state) {
                case 0: { i = 0; state = 1; break; }
                case 1: {
                    if (i < sizeof...(Idx)) {
                        uint8_t tmp = (uint8_t)Value[i];

                        auto undo_bit_reverse_and_new_layer2 = [&](uint8_t t, uintptr_t idx) -> uint8_t {
                            t = bit_reverse8(t);

                            if (idx & 1) {
                                t = (uint8_t)(t - MacroData::IndexDependentAddKey);
                            } else {
                                t = (uint8_t)(t + MacroData::IndexDependentAddKey);
                            }
                            return t;
                        };

                        auto undo_super1 = [&](uint8_t t) -> uint8_t {
                            t = (uint8_t)((t + (256 - MacroData::EncryptAddKey5)) & 0xFF);
                            t = (uint8_t)((t * MacroData::InvMultKey2) & 0xFF);
                            t ^= MacroData::EncryptXorKey5;
                            dummy ^= t ^ (v65[i % 11] + v66 % v67 + v68);
                            return t;
                        };
                        auto undo_super2_and_new_layer1 = [&](uint8_t t) -> uint8_t {
                            t = (uint8_t)((t * MacroData::InvMultKey1) & 0xFF);
                            t = (uint8_t)((t >> MacroData::RotateKey4) | (t << (8 - MacroData::RotateKey4)));
                            t = (uint8_t)(t + MacroData::EncryptSubKey3);
                            t = (uint8_t)(t - MacroData::EncryptAddKey4);
                            t ^= MacroData::EncryptXorKey4;

                            t = (uint8_t)((t >> 4) | (t << 4));
                            return t;
                        };
                        auto undo_layer3 = [&](uint8_t t) -> uint8_t {
                            t = (uint8_t)((t << MacroData::RotateKey3) | (t >> (8 - MacroData::RotateKey3)));
                            t = (uint8_t)(t + MacroData::EncryptSubKey2);
                            t = (uint8_t)(t - MacroData::EncryptAddKey3);
                            t ^= MacroData::EncryptXorKey3;
                            dummy ^= (t >> 3);
                            return t;
                        };
                        auto undo_layer2 = [&](uint8_t t) -> uint8_t {
                            t = (uint8_t)((t >> MacroData::RotateKey2) | (t << (8 - MacroData::RotateKey2)));
                            t = (uint8_t)(t + MacroData::EncryptSubKey);
                            t = (uint8_t)(t - MacroData::EncryptAddKey2);
                            t ^= MacroData::EncryptXorKey2;
                            return t;
                        };
                        auto undo_junk_conditional = [&](uint8_t t, uintptr_t idx) -> uint8_t {
                            if ((idx % 3) == 0) t ^= (uint8_t)(MacroData::FinalHash & 0xFF);
                            if (idx & 1)       t ^= (uint8_t)(MacroData::EncryptAddKey * 3);
                            dummy ^= (t ^ v65[idx % 11]);
                            return t;
                        };
                        auto undo_base = [&](uint8_t t, uintptr_t idx) -> uint8_t {
                            t = (uint8_t)((t >> MacroData::RotateKey) | (t << (8 - MacroData::RotateKey)));
                            t ^= 0xA5u;
                            t = (uint8_t)(~t);
                            t = (uint8_t)(t - MacroData::EncryptAddKey);
                            t ^= MacroData::EncryptXorKey;
                            t ^= (uint8_t)(MacroData::EncryptCharKey + idx);
                            if ((dummy & 0xCC) == 0xCC && (idx % 7) == 0) {
                                dummy ^= (uint8_t)vxCplHash("junk_code");
                            }
                            return t;
                        };

                        tmp = undo_bit_reverse_and_new_layer2(tmp, i);
                        tmp = undo_super1(tmp);
                        tmp = undo_super2_and_new_layer1(tmp);
                        tmp = undo_layer3(tmp);
                        tmp = undo_layer2(tmp);
                        tmp = undo_junk_conditional(tmp, i);
                        tmp = undo_base(tmp, i);

                        Value[i] = (char)tmp;
                        dummy ^= tmp;
                        i++;
                        state = 1;
                        break;
                    } else {
                        state = 2;
                        break;
                    }
                }
                case 2: {
                    Value[sizeof...(Idx)] = '\0';
                    return Value;
                }
            }
        }
    }
};




#define ENCRYPT(Str) (vxCplEncryptedString< \
    PerMacroData<__COUNTER__, vxCplHash(Str)>, \
    typename vxCplIndexes<sizeof(Str) - 1>::Result \
>(Str).decrypt())

#ifdef __APPLE__
  #define NSSENCRYPT(Str) @(ENCRYPT(Str))
#endif

#define ENCRYPTOFFSET(Str) strtoull(ENCRYPT(Str), NULL, 0)
#define ENCRYPTHEX(Str) ENCRYPT(Str)

namespace _vx_obf_int
{
    constexpr uint64_t rotl64(uint64_t x, int r)
    {
        return (x << r) | (x >> (64 - r));
    }

    constexpr uint64_t rotr64(uint64_t x, int r)
    {
        return (x >> r) | (x << (64 - r));
    }

    constexpr uint64_t mix64(uint64_t x)
    {
        x += 0x9E3779B97F4A7C15ULL;
        x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9ULL;
        x = (x ^ (x >> 27)) * 0x94D049BB133111EBULL;
        return x ^ (x >> 31);
    }

    template<uint64_t V, uint64_t S>
    struct EncU64
    {
        static constexpr uint64_t K1 = mix64(S ^ 0xA5A5A5A5A5A5A5A5ULL);
        static constexpr uint64_t K2 = mix64(S ^ 0x5A5A5A5A5A5A5A5AULL);
        static constexpr uint64_t K3 = mix64(S ^ 0xC3C3C3C3C3C3C3C3ULL);

        static constexpr int R1 = (K1 & 31) + 5;
        static constexpr int R2 = (K2 & 15) + 17;

        static constexpr uint64_t enc =
            rotl64(
                ((V ^ K1) + K2),
                R1
            ) ^ K3;

        __attribute__((always_inline))
        static uint64_t decode()
        {
            volatile uint64_t junk =
                (K1 ^ K2 ^ K3);

            uint64_t v = enc;

            v ^= K3;
            v = rotr64(v, R1);
            v -= K2;
            v ^= K1;

            junk ^= v;

            return v;
        }
    };
}

#define ENCR_U64(U64_LITERAL) \
    (_vx_obf_int::EncU64< \
        (uint64_t)(U64_LITERAL), \
        (uint64_t)vxRAND() \
    >::decode())