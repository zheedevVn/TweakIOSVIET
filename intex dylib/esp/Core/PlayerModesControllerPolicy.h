#pragma once
#include "WeaponFeatures.h"
namespace PlayerModesController {
constexpr uint32_t Physical=1, Unity=2;
struct Identity { uint64_t object=0, klass=0; uint32_t kind=0; };
template<class Reader,class Valid>
bool Resolve(uint64_t player,Identity &out,Reader read,Valid valid) {
    using namespace WeaponFeatures;
    out={};uint8_t physical=0;
    if(!ReadField(player,MIZZE_PLAYER_260,physical,read,valid)||physical>1)return false;
    uint64_t object=0,klass=0,name=0,namespc=0,native=0;
    if(!ReadField(player,physical?MIZZE_PLAYER_268:MIZZE_PLAYER_4D8,object,read,valid)||
       !ReadField(object,0,klass,read,valid)||!valid(klass)||
       !ReadField(klass,0x10,name,read,valid)||!ReadField(klass,0x18,namespc,read,valid))return false;
    if(physical) {
        if(!NameEquals(name,"PhysicalCCT",read,valid)||!NameEquals(namespc,"COW.GamePlay",read,valid)||
           !ReadField(object,0x1c8,native,read,valid)||!valid(native))return false;
    } else {
        if(!NameEquals(name,"CharacterController",read,valid)||!NameEquals(namespc,"UnityEngine",read,valid)||
           !ReadField(object,0x10,native,read,valid)||!valid(native))return false;
    }
    out={object,klass,physical?Physical:Unity};return true;
}
}
