#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace PlayerModesControl {
constexpr uint32_t AimLag=1, Fly=2, FakeLag=4, Spin=8;
constexpr float DefaultHeight=4.0f, MinimumHeight=1.0f, MaximumHeight=6.0f;
constexpr double ScopeGrace=0.18;
constexpr uint64_t LeaseNanoseconds=1000000000ULL;
inline float Height(float value) {
    return std::isfinite(value) ? std::max(MinimumHeight,std::min(value,MaximumHeight)) : DefaultHeight;
}
struct State {
    double scopeUntil=0;
    bool scoped=false;
    void Reset(){scopeUntil=0;scoped=false;}
    uint32_t Flags(uint32_t wanted,bool scope,double now) {
        if(!(wanted&AimLag))scopeUntil=0;
        else if(scope)scopeUntil=now+ScopeGrace;
        scoped=(wanted&AimLag)&&scopeUntil>0&&now<scopeUntil;
        return (wanted&Fly)|((wanted&Spin)?4u:0u)|(((wanted&FakeLag)||scoped)?1u:0u);
    }
};
inline bool NewEpoch(uint64_t oldMatch,uint64_t oldLocal,uint32_t oldFlags,
                     uint64_t match,uint64_t local,uint32_t flags) {
    // Fly and height changes do not release an unrelated enemy hold.
    return match!=oldMatch||local!=oldLocal||((flags^oldFlags)&1u);
}
}
