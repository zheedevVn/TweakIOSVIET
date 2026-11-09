#pragma once
#import <UIKit/UIKit.h>
#import "ESPPrefs.h"
#include <cmath>

static inline CGFloat ESPColorComponent(float value, CGFloat fallback) {
    if (!std::isfinite(value)) return fallback;
    return MAX(0.0, MIN(1.0, value));
}

static inline UIColor *ESPColor(NSString *prefix, CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:ESPColorComponent(ESPPrefsFloat([prefix stringByAppendingString:@"R"], r), r)
                           green:ESPColorComponent(ESPPrefsFloat([prefix stringByAppendingString:@"G"], g), g)
                            blue:ESPColorComponent(ESPPrefsFloat([prefix stringByAppendingString:@"B"], b), b) alpha:1];
}
static inline BOOL ESPDarkTheme() { return ESPPrefsBool(@"DarkTheme", YES); }
