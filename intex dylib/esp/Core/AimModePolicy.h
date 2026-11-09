#pragma once
#include <cmath>

namespace AimModePolicy {
enum class Type { Head = 0, Neck = 1, Silent = 2 };
enum class Activation { Off = 0, Fire = 1, Scope = 2, Always = 3, FireScope = 4 };

inline Type ReadType(float value) {
    if (value == 1) return Type::Neck;
    if (value == 2) return Type::Silent;
    return Type::Head;
}
inline Activation ReadActivation(float value) {
    if (!std::isfinite(value) || value < 0 || value > 4 || std::floor(value) != value)
        return Activation::Off;
    return static_cast<Activation>(static_cast<int>(value));
}
inline bool Triggered(Activation mode, bool firing, bool scoped) {
    switch (mode) {
        case Activation::Fire: return firing;
        case Activation::Scope: return scoped;
        case Activation::Always: return true;
        case Activation::FireScope: return firing && scoped;
        default: return false;
    }
}
// Selecting a type only changes the options shown; activation is a separate choice.
inline Activation AfterTypeSelection(Type) { return Activation::Off; }
}
