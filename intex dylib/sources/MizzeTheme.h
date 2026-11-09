#pragma once
#import <UIKit/UIKit.h>
#import "../esp/drawing_view/ESPStyle.h"
static inline UIColor *MizzeMint() { return [UIColor colorWithRed:0.46 green:0.86 blue:0.73 alpha:1]; }
static inline UIColor *MizzeBackground() { return [UIColor colorWithWhite:ESPDarkTheme() ? 0.055 : 0.96 alpha:1]; }
static inline UIColor *MizzeSurface() { return [UIColor colorWithWhite:ESPDarkTheme() ? 0.095 : 1 alpha:1]; }
static inline UIColor *MizzeRaised() { return [UIColor colorWithWhite:ESPDarkTheme() ? 0.125 : 0.95 alpha:1]; }
static inline UIColor *MizzeBorder() { return [UIColor colorWithWhite:ESPDarkTheme() ? 0.19 : 0.86 alpha:1]; }
static inline UIColor *MizzeText() { return [UIColor colorWithWhite:ESPDarkTheme() ? 0.93 : 0.1 alpha:1]; }
static inline UIColor *MizzeMuted() { return [UIColor colorWithWhite:ESPDarkTheme() ? 0.58 : 0.42 alpha:1]; }
static inline UIFont *MizzeFont(CGFloat size, UIFontWeight weight = UIFontWeightMedium) {
    NSString *name = weight >= UIFontWeightSemibold ? @"AvenirNext-DemiBold" : @"AvenirNext-Medium";
    return [UIFont fontWithName:name size:size] ?: [UIFont systemFontOfSize:size weight:weight];
}
