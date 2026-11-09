#pragma once
#include "WeaponFeatures.h"

namespace AvatarVisibility {
// Renderer visibility only. A visible avatar can still be occluded by physics.
// SetVisible in both supplied images accesses UmaAvatarSimple +0x101.
template<class Reader, class Valid>
bool IsVisible(uint64_t player, Reader read, Valid valid) {
    using namespace WeaponFeatures;
    uint64_t manager=0,avatar=0,klass=0,name=0,namespc=0;
    uint8_t visible=0;
    return ReadField(player,MIZZE_PLAYER_770,manager,read,valid) &&
        ReadField(manager,0x138,avatar,read,valid) &&
        ReadField(avatar,0,klass,read,valid) &&
        ReadField(klass,0x10,name,read,valid) &&
        ReadField(klass,0x18,namespc,read,valid) &&
        NameEquals(name,"UmaAvatarSimple",read,valid) &&
        NameEquals(namespc,"UMA.Simple",read,valid) &&
        ReadField(avatar,0x101,visible,read,valid) && visible==1;
}
}
