#pragma once
#include <algorithm>
#include <cmath>
#include "GamePRI.h"
namespace OverlayHealth {
enum class Color { Mint, Yellow, Red };
inline float Percent(float value, float fallback) {
    return std::isfinite(value) ? std::clamp(value, 0.0f, 100.0f) : fallback;
}
inline Color Band(float ratio, float red, float yellow) {
    red = Percent(red, 25); yellow = std::max(red, Percent(yellow, 50));
    return ratio * 100 <= red ? Color::Red :
        (ratio * 100 <= yellow ? Color::Yellow : Color::Mint);
}
// Read one PRI pool and reject replacement during the snapshot. Failure must
// hide this bar, never fabricate max HP or divide by a failed read.
template<class Reader, class Validator>
bool Snapshot(uint64_t player, Reader read, Validator valid, float &ratio) {
    uint64_t pool=0, entries=0, current=0, maximum=0, check=0;
    uint16_t hp=0, maxHP=0;
    if (!valid(player) || !read(player+kDataPool, &pool, 8) || !valid(pool) ||
        !read(pool+kDataPoolInner, &entries, 8) || !valid(entries) ||
        !read(entries+kDataPoolEntriesBase, &current, 8) || !valid(current) ||
        !read(entries+kDataPoolEntriesBase+kDataPoolEntryStride, &maximum, 8) || !valid(maximum) ||
        !read(current+kDataPoolValue, &hp, 2) || !read(maximum+kDataPoolValue, &maxHP, 2) ||
        !maxHP || maxHP>10000 || !hp || hp>maxHP ||
        !read(player+kDataPool, &check, 8) || check!=pool ||
        !read(pool+kDataPoolInner, &check, 8) || check!=entries ||
        !read(entries+kDataPoolEntriesBase, &check, 8) || check!=current ||
        !read(entries+kDataPoolEntriesBase+kDataPoolEntryStride, &check, 8) || check!=maximum) return false;
    ratio = static_cast<float>(hp)/maxHP;
    return true;
}
}
