#pragma once
#include <cstddef>
#include <cstdint>
#include "../drawing_view/offset.h"

namespace GamePRI {
// Player.get_IsFiringFromPRI in the supplied 1.132.1 IPA requests index 21
// and compares the UInt16 result with 2. Player + 0x770 is AvatarManager.
inline constexpr int FiringIndex = 21;
inline constexpr uint16_t FiringActiveValue = 2;
inline bool Firing(int value) { return value == FiringActiveValue; }

template <typename Reader, typename Validator>
bool TryUInt16(uint64_t player, int index, Reader read, Validator valid,
               uint16_t &output) {
    if (!valid(player) || index < 0 || index > 32) return false;
    uint64_t pool = 0, entries = 0, entry = 0;
    uint16_t value = 0;
    if (!read(player + kDataPool, &pool, sizeof(pool)) || !valid(pool)) return false;
    if (!read(pool + kDataPoolInner, &entries, sizeof(entries)) || !valid(entries)) return false;
    const uint64_t slot = entries + kDataPoolEntriesBase +
        static_cast<uint64_t>(index) * kDataPoolEntryStride;
    if (!read(slot, &entry, sizeof(entry)) || !valid(entry)) return false;
    if (!read(entry + kDataPoolValue, &value, sizeof(value))) return false;
    output = value;
    return true;
}
}
