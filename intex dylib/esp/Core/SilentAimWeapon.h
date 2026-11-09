#include "GameOffsets.h"
#pragma once
#include <cstdint>
namespace SilentAimWeapon {
// GetWeaponOnHand -> GMOCOOEIFMK getter, from the supplied 1.132.1 native image.
inline constexpr uint64_t ManagerGetter = GameOffsets::Rva(0x5AC970C);
template <typename Reader, typename Validator>
uint64_t OnHand(uint64_t local, Reader read, Validator valid) {
    uint64_t manager = 0, owner = 0, weapon = 0;
    uint8_t combined = 0;
    if (!valid(local) || !read(local + MIZZE_PLAYER_740, manager) || !valid(manager) ||
        !read(manager + 0x30, owner) || owner != local ||
        !read(manager + 0x148, combined) || combined > 1 ||
        !read(manager + (combined ? 0xA8 : 0xA0), weapon) || !valid(weapon) ||
        !read(weapon + 0x60, owner) || owner != local) return 0;
    return weapon;
}
} // namespace SilentAimWeapon
