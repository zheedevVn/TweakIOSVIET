#import "UIView+SecureView.h"
#import <objc/runtime.h>

static char OriginalCaptureMaskKey;
static NSHashTable<UIView *> *ProtectedViews(void) {
    static NSHashTable<UIView *> *views;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ views = [NSHashTable weakObjectsHashTable]; });
    return views;
}

@implementation UIView (SecureView)

+ (BOOL)applyCaptureProtectionToRegisteredViews:(BOOL)hide {
    if (!NSThread.isMainThread) return NO;
    NSArray<UIView *> *views = ProtectedViews().allObjects;
    BOOL applied = views.count > 0;
    for (UIView *view in views) if (![view hideViewFromCapture:hide]) applied = NO;
    return applied;
}

- (BOOL)hideViewFromCapture:(BOOL)hide
{
    if (!NSThread.isMainThread) return NO;
    [ProtectedViews() addObject:self];
    // Private compositor support varies by iOS. Never hide the local view as
    // a fallback, and never report unavailable protection as successful.
    if (![self.layer respondsToSelector:NSSelectorFromString(@"setDisableUpdateMask:")] ||
        ![self.layer respondsToSelector:NSSelectorFromString(@"disableUpdateMask")]) return NO;
    @try {
        NSNumber *original = objc_getAssociatedObject(self, &OriginalCaptureMaskKey);
        if (!original) {
            original = [self.layer valueForKey:@"disableUpdateMask"];
            if (![original isKindOfClass:NSNumber.class]) return NO;
            objc_setAssociatedObject(self, &OriginalCaptureMaskKey, original, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        NSInteger mask = hide ? (original.integerValue | (1 << 1) | (1 << 4)) : original.integerValue;
        [self.layer setValue:@(mask) forKey:@"disableUpdateMask"];
        return [[self.layer valueForKey:@"disableUpdateMask"] integerValue] == mask;
    } @catch (NSException *exception) { return NO; }
}

- (BOOL)showViewForCapture
{
    return [self hideViewFromCapture:NO];
}

@end
