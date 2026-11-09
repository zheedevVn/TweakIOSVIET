#pragma once
#include <array>
#include <cstddef>
#include <cstdint>

namespace PlayerModesInstall {
// IEntityTicker.OnUpdate is a separate interface entry in the supplied metadata.
// Its implementation also occupies the ordinary Player.OnUpdate virtual entry.
// PostUpdate (174) runs the high-frame/avatar presentation phase after OnUpdate.
using Entries = std::array<uint64_t, 3>;
constexpr Entries Slots = {0x138 + 5 * 16, 0x138 + 26 * 16, 0x138 + 174 * 16};
inline Entries Originals(uint64_t update,uint64_t post){return {update,update,post};}
inline Entries Callbacks(uint64_t allocation){return {allocation,allocation,allocation+16};}

template<class Read, class Exchange>
bool Bind(uint64_t klass, const Entries &original, const Entries &callback, Read read, Exchange exchange) {
    std::array<uint64_t, Slots.size()> before{};
    for (std::size_t i=0; i<Slots.size(); ++i) {
        if (!read(klass+Slots[i], before[i]) ||
            (before[i]!=original[i] && before[i]!=callback[i])) return false;
    }
    for (std::size_t i=0; i<Slots.size(); ++i) {
        if (before[i]==callback[i]) continue;
        if (exchange(klass+Slots[i], before[i], callback[i])) continue;
        // Roll back only writes owned by this attempt; leave another writer alone.
        for (std::size_t j=0; j<i; ++j)
            if (before[j]!=callback[j]) exchange(klass+Slots[j], callback[j], before[j]);
        return false;
    }
    return true;
}
}
