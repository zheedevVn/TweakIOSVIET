#pragma once
#import "../esp/drawing_view/ESPPrefs.h"
#include "../esp/Core/AimModePolicy.h"

static inline void MizzePrepareMenuPrefs(void) {
    if (!ESPPrefsBool(@"ExplicitAimMenuV1", NO)) {
        const auto type = ESPPrefsBool(@"SilentAim", NO) ? AimModePolicy::Type::Silent :
            (ESPPrefsBool(@"AimNeck", NO) ? AimModePolicy::Type::Neck : AimModePolicy::Type::Head);
        ESPPrefsSetFloat(@"AimType", static_cast<int>(type));
        ESPPrefsSetFloat(@"AimActivation", static_cast<int>(AimModePolicy::Activation::Off));
        for (NSString *key in @[@"AimbotFire", @"AimbotScope", @"AimHipAlways", @"SilentAim"])
            ESPPrefsSetBool(key, NO);
        // Existing floating-button choices stay available after the menu upgrade.
        for (NSString *key in @[@"GhostMode", @"FakeLag"])
            if (!AppSettingsObjectForKey([key stringByAppendingString:@"Floating"]))
                ESPPrefsSetBool([key stringByAppendingString:@"Floating"], ESPPrefsBool(key, NO));
        ESPPrefsSetBool(@"ExplicitAimMenuV1", YES);
    }
}
