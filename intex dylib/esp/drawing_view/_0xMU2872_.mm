#import "menu.h"
#import "icons.h"
#import "ModMenuViewController.h"
#import "ESPPrefs.h"
#import "esp.h"
#import "FloatingFeatureControl.h"
#import "../../sources/MizzeTheme.h"
#import "../../mahoa.h"
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#include "KabraxHide.h"
#include <cmath>

static const CGFloat kMenuButtonSize = 44.0f;

@interface _0xB1872A2 ()
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, assign) NSInteger trackingPointerId;
@property (nonatomic, assign) BOOL touchOnButton;
@property (nonatomic, assign) BOOL buttonDragging;
@property (nonatomic, assign) CGPoint buttonDragStartCenter;
@property (nonatomic, assign) CGPoint buttonDragStartPoint;
@property (nonatomic, strong) _0xDEADBEEE *presentedModMenu;
@property (nonatomic, strong) NSMutableDictionary<NSString *, FloatingFeatureControl *> *quickControls;
#ifdef MIZZE_INJECTED
@property (nonatomic, assign) NSUInteger menuVisibilityGeneration;
#endif
@end

@implementation _0xB1872A2

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (self.superview && _menuButton) {
        CGSize size = self.bounds.size;
        if (size.width < kMenuButtonSize || size.height < kMenuButtonSize) return;
        CGRect frame = _menuButton.frame;
        
        frame.size.width = kMenuButtonSize;
        frame.size.height = kMenuButtonSize;
        
        if (CGRectGetMaxX(frame) > size.width) frame.origin.x = size.width - frame.size.width;
        if (CGRectGetMaxY(frame) > size.height) frame.origin.y = size.height - frame.size.height;
        if (frame.origin.x < 0) frame.origin.x = 0;
        if (frame.origin.y < 0) frame.origin.y = 0;
        
        _menuButton.frame = frame;
    }
    if (_presentedModMenu && _presentedModMenu.view) {
        _presentedModMenu.view.frame = self.bounds;
    }
    for (FloatingFeatureControl *control in self.quickControls.allValues) [control clampToSuperview];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        _trackingPointerId = -1;
#ifdef MIZZE_INJECTED
        self.hidden = YES;
        NSNotificationCenter *notifications = NSNotificationCenter.defaultCenter;
        [notifications addObserver:self selector:@selector(refreshInjectedMenuVisibility)
                              name:ESPMatchReadyChangedNotification object:nil];
        [notifications addObserver:self selector:@selector(refreshInjectedMenuVisibility)
                              name:UIApplicationDidBecomeActiveNotification object:nil];
        [notifications addObserver:self selector:@selector(suspendInjectedMenu)
                              name:UIApplicationWillResignActiveNotification object:nil];
        [notifications addObserver:self selector:@selector(suspendInjectedMenu)
                              name:UIApplicationDidEnterBackgroundNotification object:nil];
#endif

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(resetTouchState)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(resetTouchState)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        [self setupMenuButton];
        self.quickControls = [NSMutableDictionary dictionary];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(quickPrefsChanged:)
            name:NSUserDefaultsDidChangeNotification object:nil];
        [self reloadFloatingAuxButtonsFromPrefs];
#ifdef MIZZE_INJECTED
        [self refreshInjectedMenuVisibility];
#endif
    }
    return self;
}

- (void)setupMenuButton {
    _menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _menuButton.frame = CGRectMake(20, 100, kMenuButtonSize, kMenuButtonSize);
    _menuButton.backgroundColor = [UIColor colorWithWhite:0.095 alpha:0.96];
    _menuButton.layer.cornerRadius = 13;
    _menuButton.layer.borderWidth = 0.5;
    _menuButton.layer.borderColor = [MizzeMint() colorWithAlphaComponent:0.5].CGColor;
    _menuButton.layer.shadowColor = [UIColor blackColor].CGColor;
    _menuButton.layer.shadowOffset = CGSizeMake(0, 2);
    _menuButton.layer.shadowOpacity = 0;
    _menuButton.layer.shadowRadius = 4.0f;
    _menuButton.layer.zPosition = 999.0f;
    _menuButton.clipsToBounds = YES;
    
    [_menuButton setTitle:@"Z" forState:UIControlStateNormal];
    [_menuButton setTitleColor:MizzeMint() forState:UIControlStateNormal];
    _menuButton.titleLabel.font = [UIFont systemFontOfSize:27 weight:UIFontWeightMedium];
    _menuButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    [_menuButton addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragNativeButton:)];
    [_menuButton addGestureRecognizer:pan];
    
    [self addSubview:_menuButton];
    [self loadMenuButtonPosition];
}

- (void)loadMenuButtonPosition {
    CGFloat x = [[NSUserDefaults standardUserDefaults] floatForKey:KH_NS("FloatingMenuBtnX")];
    CGFloat y = [[NSUserDefaults standardUserDefaults] floatForKey:KH_NS("FloatingMenuBtnY")];
    
    if (x > 10.0f && y > 10.0f) {
        _menuButton.frame = CGRectMake(x, y, kMenuButtonSize, kMenuButtonSize);
    } else {
        _menuButton.frame = CGRectMake(20, 100, kMenuButtonSize, kMenuButtonSize);
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || (_presentedModMenu && hit == _presentedModMenu.view)) return nil;
    return hit;
}
- (void)dragNativeButton:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) _buttonDragStartCenter = _menuButton.center;
    CGPoint delta = [pan translationInView:self];
    _menuButton.center = CGPointMake(_buttonDragStartCenter.x + delta.x, _buttonDragStartCenter.y + delta.y);
    [self setNeedsLayout]; [self layoutIfNeeded];
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        [NSUserDefaults.standardUserDefaults setFloat:_menuButton.frame.origin.x forKey:@"FloatingMenuBtnX"];
        [NSUserDefaults.standardUserDefaults setFloat:_menuButton.frame.origin.y forKey:@"FloatingMenuBtnY"];
    }
}

- (UIViewController *)viewControllerForView:(UIView *)view {
    UIResponder *r = view;
    while (r && ![r isKindOfClass:[UIViewController class]]) r = [r nextResponder];
    return [r isKindOfClass:[UIViewController class]] ? (UIViewController *)r : nil;
}

- (void)resetTouchState {
    for (FloatingFeatureControl *control in self.quickControls.allValues) [control cancelTracking];
    _touchOnButton = NO;
    _buttonDragging = NO;
    _trackingPointerId = -1;
}

#ifdef MIZZE_INJECTED
- (void)suspendInjectedMenu {
    // Invalidate an opening queued before leaving the match or backgrounding.
    ++_menuVisibilityGeneration;
    self.hidden = YES;
    [self resetTouchState];
    [self dismissModMenu];
}

- (void)refreshInjectedMenuVisibility {
    if (ESPMatchReady() &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive) {
        self.hidden = NO;
    } else {
        [self suspendInjectedMenu];
    }
}
#endif

- (void)presentModMenu {
    if (self->_presentedModMenu) return;
#ifdef MIZZE_INJECTED
    if (self.hidden || !self.window || !ESPMatchReady() ||
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    const NSUInteger generation = _menuVisibilityGeneration;
#endif
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_presentedModMenu) return;
#ifdef MIZZE_INJECTED
        if (generation != self->_menuVisibilityGeneration || self.hidden ||
            !self.window || !ESPMatchReady() ||
            UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
#endif
        
        UIViewController *parentVC = [self viewControllerForView:self];
        if (!parentVC) return;
        
        [self resetTouchState];
        
        _0xDEADBEEE *vc = [[_0xDEADBEEE alloc] init];
        CGRect b = self.bounds;
        if (b.size.width <= 0 || b.size.height <= 0) {
            b = [UIScreen mainScreen].bounds;
        }
        vc.view.frame = b;
        vc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        vc.view.alpha = 1.0f;
        vc.view.transform = CGAffineTransformIdentity;
        
        __weak _0xB1872A2 *wself = self;
        vc.onCloseBlock = ^{
            [wself dismissModMenu];
        };
        vc.onExitHUDRequested = ^{
            if (wself && wself.onExitHUDRequested) {
                wself.onExitHUDRequested();
            }
        };
        self->_presentedModMenu = vc;
        
        [parentVC addChildViewController:vc];
        [self addSubview:vc.view];
        [vc didMoveToParentViewController:parentVC];
        [self bringSubviewToFront:vc.view];
        
        self.menuButton.hidden = YES;
        for (FloatingFeatureControl *control in self.quickControls.allValues) control.hidden = YES;
    });
}

- (void)dismissModMenu {
#ifdef MIZZE_INJECTED
    _0xDEADBEEE *closingMenu = self->_presentedModMenu;
    if (!closingMenu) return;
#endif
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self->_presentedModMenu) return;
#ifdef MIZZE_INJECTED
        if (self->_presentedModMenu != closingMenu) return;
#endif
        
        _0xDEADBEEE *vc = self->_presentedModMenu;
        self->_presentedModMenu = nil;
        
        [vc willMoveToParentViewController:nil];
        [vc.view removeFromSuperview];
        [vc removeFromParentViewController];
        
        // Khôi phục hiển thị chuẩn cho nút menu
        self.menuButton.transform = CGAffineTransformIdentity;
        self.menuButton.alpha = 1.0f;
        self.menuButton.hidden = NO;
        self.menuButton.layer.zPosition = 999.0f;
        [self.menuButton.layer removeAllAnimations];
        
        // Kiểm tra toạ độ an toàn
        CGRect currentFrame = self.menuButton.frame;
        if (currentFrame.size.width < 10.0f || currentFrame.size.height < 10.0f ||
            currentFrame.origin.x < 0 || currentFrame.origin.y < 0) {
            [self loadMenuButtonPosition];
        }
        
        [self bringSubviewToFront:self.menuButton];
        [self reloadFloatingAuxButtonsFromPrefs];
        [self resetTouchState];
        [self setNeedsLayout];
    });
}

- (void)showMenu {
    if (_presentedModMenu) return;
    [self presentModMenu];
}

- (void)hideMenu {
#ifdef MIZZE_INJECTED
    ++_menuVisibilityGeneration;
#endif
    if (_presentedModMenu) {
        [self dismissModMenu];
    }
}

- (BOOL)handleTouchAtWindowPoint:(CGPoint)windowPoint phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId {
    if (self.hidden) return NO;
    CGPoint local = [self convertPoint:windowPoint fromView:self.window];
    if (!_presentedModMenu) for (FloatingFeatureControl *control in self.quickControls.allValues)
        if ([control handleRemotePoint:local phase:phase pointer:pointerId]) return YES;
    const CGFloat kInset = 12.0f;
    CGRect btnHit = CGRectInset(_menuButton.frame, -kInset, -kInset);
    BOOL insideBtn = CGRectContainsPoint(btnHit, local);

    // KHI BẢNG MENU ĐANG MỞ
    if (_presentedModMenu) {
        CGPoint inMenuView = [self convertPoint:local toView:_presentedModMenu.view];
        if ([_presentedModMenu _0xF010:inMenuView phase:(NSInteger)phase pointerId:pointerId]) {
            return YES;
        }
        // Chạm vào bất kỳ điểm nào bên ngoài menu (màn hình game Free Fire Max) để đóng
        if (!insideBtn && phase == UITouchPhaseBegan) {
            [self dismissModMenu];
            return YES;
        }
        return YES;
    }

    // KHI MENU ĐANG ĐÓNG: Xử lý kéo thả nút
    switch (phase) {
        case UITouchPhaseBegan: {
            if (insideBtn && !_touchOnButton) {
                _touchOnButton = YES;
                _buttonDragging = NO;
                _trackingPointerId = pointerId;
                _buttonDragStartCenter = _menuButton.center;
                _buttonDragStartPoint = local;
                return YES;
            }
            return NO;
        }
        case UITouchPhaseMoved: {
            if (_touchOnButton && pointerId == _trackingPointerId) {
                const CGFloat kDragThreshold = 10.0f;
                CGFloat dx = local.x - _buttonDragStartPoint.x;
                CGFloat dy = local.y - _buttonDragStartPoint.y;
                
                if (!_buttonDragging && (fabs(dx) + fabs(dy) > kDragThreshold)) {
                    _buttonDragging = YES;
                }
                
                if (_buttonDragging) {
                    _menuButton.center = CGPointMake(_buttonDragStartCenter.x + dx, _buttonDragStartCenter.y + dy);
                    [self setNeedsLayout];
                    [self layoutIfNeeded];
                    _buttonDragStartCenter = _menuButton.center;
                    _buttonDragStartPoint = local;
                }
                return YES;
            }
            return NO;
        }
        case UITouchPhaseEnded:
        case UITouchPhaseCancelled: {
            if (_touchOnButton && pointerId == _trackingPointerId) {
                BOOL wasDrag = _buttonDragging;
                [self resetTouchState];

                if (!wasDrag && phase == UITouchPhaseEnded) {
                    [self togglePanel];
                } else {
                    // CHỈ LƯU TỌA ĐỘ KHI ĐÃ KÉO THẢ XONG (tránh lưu đè khi bấm mở menu)
                    CGRect btnFrame = _menuButton.frame;
                    if (btnFrame.origin.x >= 0 && btnFrame.origin.y >= 0 && btnFrame.size.width >= kMenuButtonSize) {
                        [[NSUserDefaults standardUserDefaults] setFloat:(float)btnFrame.origin.x forKey:KH_NS("FloatingMenuBtnX")];
                        [[NSUserDefaults standardUserDefaults] setFloat:(float)btnFrame.origin.y forKey:KH_NS("FloatingMenuBtnY")];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                    }
                }
                return YES;
            }
            return NO;
        }
        default:
            return NO;
    }
}

- (BOOL)handleTouchAtLocalPoint:(CGPoint)localPoint phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId {
    return [self handleTouchAtWindowPoint:[self convertPoint:localPoint toView:self.window] phase:phase pointerId:pointerId];
}

- (void)togglePanel {
    if (_presentedModMenu) {
        [self dismissModMenu];
    } else {
        [self presentModMenu];
    }
}

- (void)reloadFloatingAuxButtonsFromPrefs {
    if (!NSThread.isMainThread) {
        __weak _0xB1872A2 *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf reloadFloatingAuxButtonsFromPrefs]; });
        return;
    }
    NSArray *keys = @[@"GhostMode", @"FakeLag", @"RunSpeed", @"AutoFire", @"Fly"];
    NSArray *titles = @[@"Ghost", @"FakeLag", @"Speed", @"AimKill", @"Fly"];
    NSArray *symbols = @[@"person.fill", @"pause.circle.fill", @"figure.walk", @"scope", @"airplane"];
    for (NSString *key in self.quickControls.allKeys)
        if (![keys containsObject:key]) {
            [self.quickControls[key] removeFromSuperview];[self.quickControls removeObjectForKey:key];
        }
    const NSUInteger rows = MAX(1, MIN(keys.count, (NSUInteger)MAX(1, std::floor((self.bounds.size.height - 12) / 88))));
    for (NSUInteger i = 0; i < keys.count; ++i) {
        NSString *key = keys[i], *shownKey = [key stringByAppendingString:@"Floating"];
        const BOOL shown = !ESPPrefsBool(@"HideFeatureButtons", NO) && ESPPrefsBool(shownKey, ESPPrefsBool(key, NO));
        FloatingFeatureControl *control = self.quickControls[key];
        if (!shown) { [control removeFromSuperview]; [self.quickControls removeObjectForKey:key]; continue; }
        if (!control) {
            control = [[FloatingFeatureControl alloc] initWithKey:key title:titles[i] symbol:symbols[i]];
            CGFloat x = ESPPrefsFloat([key stringByAppendingString:@"FloatX"], MAX(8, self.bounds.size.width - 90 - (i / rows) * 84));
            CGFloat top = MAX(8, MIN(70, self.bounds.size.height - rows * 88 - 12));
            CGFloat y = ESPPrefsFloat([key stringByAppendingString:@"FloatY"], top + (i % rows) * 88);
            control.frame = CGRectMake(x, y, 76, 80);
            [control addTarget:self action:@selector(toggleQuickFeature:) forControlEvents:UIControlEventTouchUpInside];
            self.quickControls[key] = control; [self addSubview:control];
        }
        BOOL active = ESPPrefsBool(key, NO);
        [control setFeatureActive:active];
        control.hidden = _presentedModMenu != nil;
        [control clampToSuperview];
    }
}
- (void)quickPrefsChanged:(NSNotification *)notification { [self reloadFloatingAuxButtonsFromPrefs]; }
- (void)toggleQuickFeature:(FloatingFeatureControl *)control {
    NSString *key = control.featureKey;
    BOOL active = ESPPrefsBool(key, NO);
    // Keep the quick button after tapping OFF so it can be turned back ON.
    ESPPrefsSetBool([key stringByAppendingString:@"Floating"], YES);
    ESPPrefsSetBool(key, !active); ESPSyncFromPrefs();
    [self reloadFloatingAuxButtonsFromPrefs];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
