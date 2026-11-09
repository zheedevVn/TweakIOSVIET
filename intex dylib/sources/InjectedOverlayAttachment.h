#pragma once
#import <UIKit/UIKit.h>

// Reuse the host's view/window hierarchy. A second UIWindow can cause Unity
// focus, scene activation and orientation changes while the host is launching.
static inline BOOL MizzeAttachChildOverlay(UIViewController *host, UIView *container, UIViewController *root) {
    if (!host || !container || !root || root == host || root.parentViewController || !host.view.window) return NO;
    BOOL appearing=NO;
    @try {
        container.frame=host.view.bounds;
        container.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [host addChildViewController:root];
        root.view.frame=container.bounds;
        root.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [root beginAppearanceTransition:YES animated:NO];appearing=YES;
        [container addSubview:root.view];
        [host.view addSubview:container];
        [root didMoveToParentViewController:host];
        appearing=NO;[root endAppearanceTransition];
        return YES;
    } @catch (NSException *exception) {
        // Cleanup must not escape back into the host if a lifecycle callback
        // was the source of the exception.
        @try { if(appearing) [root endAppearanceTransition]; } @catch (NSException *ignored) {}
        @try { [root willMoveToParentViewController:nil]; } @catch (NSException *ignored) {}
        @try { [root.view removeFromSuperview]; } @catch (NSException *ignored) {}
        @try { [root removeFromParentViewController]; } @catch (NSException *ignored) {}
        @try { [container removeFromSuperview]; } @catch (NSException *ignored) {}
        return NO;
    }
}
