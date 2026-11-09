#pragma once
#include "WeaponFeatures.h"

namespace RunSpeed {
constexpr uint64_t Offset=0x3c8;
inline float Value(float value) {
    return std::isfinite(value)?std::clamp(value,0.1f,30.0f):6.0f;
}
class Controller {
    WeaponFeatures::Identity identity_{};
    WeaponFeatures::FieldPatch<float> patch_;
public:
    bool Changed() const {return patch_.Changed();}
    template<class Read,class Write,class Valid,class Current>
    void Update(WeaponFeatures::Context context,bool enabled,float value,Read read,Write write,Valid valid,Current current) {
        if(!enabled&&!Changed())return;
        WeaponFeatures::Identity identity;
        if(!WeaponFeatures::Resolve(context,identity,read,valid))return;
        auto field=[&](float &v){return WeaponFeatures::ReadField(identity.attributes,Offset,v,read,valid);};
        if(!(identity==identity_)) {
            const bool sameComponent=identity.context.task==identity_.context.task&&
                identity.context.player==identity_.context.player&&identity.attributes==identity_.attributes&&identity.klass==identity_.klass;
            const bool sameMatch=identity.context.task==identity_.context.task&&identity.context.match==identity_.context.match&&identity.klass==identity_.klass;
            if(!sameComponent) {
                if(sameMatch) {if(!patch_.Retarget(field,[](float a,float b){return a==b;}))return;}
                else patch_.Forget();
            }
            identity_=identity;
        }
        patch_.Update(enabled,field,[&](float v){
            WeaponFeatures::Identity live;
            return WeaponFeatures::Resolve(current(),live,read,valid)&&live==identity&&
                write(identity.attributes+Offset,&v,sizeof(v));
        },[](float v){return std::isfinite(v)&&v>=0&&v<=1000;},
        [value](float){return Value(value);},[](float,float){return true;});
    }
};
}
