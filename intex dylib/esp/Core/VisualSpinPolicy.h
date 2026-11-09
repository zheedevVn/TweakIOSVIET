#pragma once
#include <algorithm>
#include <cmath>

namespace VisualSpin {
constexpr float DefaultSpeed=0.5f; // revolutions per second
inline float Speed(float value) {
    return std::isfinite(value) ? std::clamp(value,0.1f,3.0f) : DefaultSpeed;
}
struct Phase {
    double turns=0, last=-1;
    void Reset(){turns=0;last=-1;}
    void Step(double now,float speed) {
        if(!std::isfinite(now)){Reset();return;}
        if(last>=0 && now>=last && now-last<=0.25)
            turns=std::fmod(turns+(now-last)*Speed(speed),1.0);
        last=now;
    }
    float Sin()const{return std::sin(turns*3.14159265358979323846);}
    float Cos()const{return std::cos(turns*3.14159265358979323846);}
};
}
