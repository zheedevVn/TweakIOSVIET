#pragma once
#import <UIKit/UIKit.h>

static inline BOOL MizzeUsableGameWindow(UIWindow *window) {
    return window && !window.hidden && window.alpha > 0 &&
           window.windowLevel == UIWindowLevelNormal &&
           window.rootViewController && !CGRectIsEmpty(window.bounds);
}

static inline UIWindow *MizzeFindGameWindow(UIApplication *app) {
    UIWindow *fallback = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class] ||
                scene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (!MizzeUsableGameWindow(window)) continue;
                if (window.isKeyWindow) return window;
                if (!fallback) fallback = window;
            }
        }
    }
    if (fallback) return fallback;

    // Many Unity hosts use the UIApplicationDelegate lifecycle even on newer
    // iOS. Their connectedScenes set is empty; app.windows is still valid.
    for (UIWindow *window in app.windows) {
        if (@available(iOS 13.0, *)) {
            if (window.windowScene) continue; // Ignore background scenes.
        }
        if (!MizzeUsableGameWindow(window)) continue;
        if (window.isKeyWindow) return window;
        if (!fallback) fallback = window;
    }
    return fallback;
}
