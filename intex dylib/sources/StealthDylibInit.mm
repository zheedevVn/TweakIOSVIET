#import <UIKit/UIKit.h>
#import "InjectedMenuController.h"
#import "InjectedOverlayOwnership.h"
#import "InjectedWindowSelection.h"
#import "InjectedOverlayAttachment.h"
#include "InjectedStartupPolicy.h"
#import "APIClient.h"

@interface MizzeOverlayContainer : UIView
@property(nonatomic,weak) UIView *contentView;
@end
@implementation MizzeOverlayContainer
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.contentView) ? nil : hit;
}
@end

// All state is confined to the main queue. Coalesce window/scene notifications
// so a game loading several scenes never starts parallel retry chains.
static BOOL setupPending = NO;
static NSUInteger setupAttempts = 0;
static const NSUInteger kMaxSetupAttempts = 60;
static InjectedStartup::Gate startupGate;
static void ScheduleInjectedOverlay(NSTimeInterval delay);

static void SetupInjectedOverlayMenu() {
    NSCAssert(NSThread.isMainThread, @"Overlay setup requires the main thread");
    UIApplication *app = UIApplication.sharedApplication;
    if (!app || MizzeOverlayOwner(app)) return;
    const NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    UIWindow *gameWindow = MizzeFindGameWindow(app);
    UIViewController *host = gameWindow.rootViewController;
    const BOOL attached = host.isViewLoaded && host.view.window == gameWindow &&
        !host.isBeingPresented && !host.isBeingDismissed && !host.transitionCoordinator;
    if (!startupGate.ready(app.applicationState == UIApplicationStateActive, attached,
        reinterpret_cast<uintptr_t>((__bridge void *)gameWindow), gameWindow.bounds.size.width,
        gameWindow.bounds.size.height, now)) {
        if (++setupAttempts < kMaxSetupAttempts) ScheduleInjectedOverlay(1.0);
        return;
    }

    MizzeOverlayContainer *overlay = nil;
    @try {
        overlay = [[MizzeOverlayContainer alloc] initWithFrame:host.view.bounds];
        overlay.backgroundColor = UIColor.clearColor;
        overlay.userInteractionEnabled = YES;
        if (!MizzeClaimOverlay(app, overlay)) return;

        InjectedMenuController *root = [InjectedMenuController new];
        root.gameWindow = gameWindow;
        overlay.contentView=root.view;
        if(!MizzeAttachChildOverlay(host,overlay,root)){
            MizzeReleaseOverlay(app,overlay);
            if(++setupAttempts<kMaxSetupAttempts)ScheduleInjectedOverlay(2.0);
            return;
        }
        NSLog(@"[Mizze] Overlay ready after host activation");
    } @catch (NSException *exception) {
        [overlay removeFromSuperview];
        MizzeReleaseOverlay(app, overlay);
        if(++setupAttempts<kMaxSetupAttempts)ScheduleInjectedOverlay(2.0);
        NSLog(@"[Mizze] Overlay setup failed: %@", exception.name);
    }
}

static void ScheduleInjectedOverlay(NSTimeInterval delay) {
    if (setupPending) return;
    setupPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        setupPending = NO;
        SetupInjectedOverlayMenu();
    });
}

static void __attribute__((constructor)) StealthDylibEntryPoint() {
    // Loader callbacks run before UIApplicationMain. Only enqueue here: no
    // UIKit objects, synthetic touches, system hooks, or integrity scans.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        @autoreleasepool {
            apiclient_set_token("b2GzBzvDVfMBlP96tm5q2XUtWgVuJgTAJTNkZ6q7uk+Ni0nwolEDstMEOrlEsxHyiUUj4M/7hRwYD6VApIf9c3kkgQYy6dWE/B69+eT5F0g=");
            apiclient_paid(^{
            NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
            for (NSNotificationName name in @[UIApplicationDidFinishLaunchingNotification,
                                               UIApplicationDidBecomeActiveNotification,
                                               UIWindowDidBecomeKeyNotification]) {
                [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                                usingBlock:^(NSNotification *notification) {
                    setupAttempts = 0;
                    ScheduleInjectedOverlay(0.25);
                }];
            }
            // Also covers a dylib loaded after the game's launch notification.
            ScheduleInjectedOverlay(0.25);

            });
        }
    });
}
