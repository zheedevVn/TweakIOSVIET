#import "ESPPrefs.h"
#import <Foundation/Foundation.h>
#include "KabraxHide.h"

// Sử dụng bộ nhớ hệ thống (UserDefaults) thay vì file .plist
#define DEFAULTS [NSUserDefaults standardUserDefaults]

void ESPPrefsSetBool(NSString *key, BOOL value) {
    [DEFAULTS setBool:value forKey:key];
    [DEFAULTS synchronize];
}

void ESPPrefsSetFloat(NSString *key, float value) {
    [DEFAULTS setFloat:value forKey:key];
    [DEFAULTS synchronize];
}

// Hàm này không cần làm gì cả vì UserDefaults tự sync
void ESPPrefsSync(void) {
    [DEFAULTS synchronize];
}

BOOL ESPPrefsBool(NSString *key, BOOL defaultValue) {
    if ([DEFAULTS objectForKey:key] == nil) return defaultValue;
    return [DEFAULTS boolForKey:key];
}

float ESPPrefsFloat(NSString *key, float defaultValue) {
    if ([DEFAULTS objectForKey:key] == nil) return defaultValue;
    return [DEFAULTS floatForKey:key];
}

id AppSettingsObjectForKey(NSString *key) {
    return [DEFAULTS objectForKey:key];
}

void AppSettingsSetObject(NSString *key, id value) {
    [DEFAULTS setObject:value forKey:key];
    [DEFAULTS synchronize];
}

void AppSettingsRemoveKeys(NSArray<NSString *> *keys) {
    for (NSString *k in keys) [DEFAULTS removeObjectForKey:k];
    [DEFAULTS synchronize];
}