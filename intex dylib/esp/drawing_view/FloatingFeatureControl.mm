#import "FloatingFeatureControl.h"
#import "ESPPrefs.h"
#import "../../sources/MizzeTheme.h"
#import <QuartzCore/QuartzCore.h>
#include <cmath>

@interface FloatingFeatureControl ()
@property(nonatomic,copy,readwrite) NSString *featureKey;
@property(nonatomic,strong) UIView *glass;
@property(nonatomic,strong) UIView *tint;
@property(nonatomic,strong) UIImageView *icon;
@property(nonatomic,strong) UILabel *caption;
@property(nonatomic,assign) CGPoint dragCenter;
@property(nonatomic,assign) CGPoint dragPoint;
@property(nonatomic,assign) NSInteger remotePointer;
@property(nonatomic,assign) BOOL moved;
@end

@implementation FloatingFeatureControl
- (instancetype)initWithKey:(NSString *)key title:(NSString *)title symbol:(NSString *)symbol {
    if (!(self = [super initWithFrame:CGRectMake(0, 0, 76, 80)])) return nil;
    _featureKey = [key copy]; _remotePointer = -1;
    self.accessibilityLabel = title;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.layer.zPosition = 990;
    self.exclusiveTouch = YES;
    _glass = [[UIView alloc] initWithFrame:CGRectMake(10, 0, 56, 56)];
    _glass.userInteractionEnabled = NO;
    _glass.layer.cornerRadius = 28;
    _glass.layer.shadowColor = UIColor.blackColor.CGColor;
    _glass.layer.shadowOpacity = 0.2; _glass.layer.shadowRadius = 6;
    _glass.layer.shadowOffset = CGSizeMake(0, 3);
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    blur.frame = _glass.bounds; blur.layer.cornerRadius = 28; blur.clipsToBounds = YES;
    [_glass addSubview:blur];
    _tint = [[UIView alloc] initWithFrame:_glass.bounds];
    _tint.layer.cornerRadius = 28; _tint.layer.borderWidth = 0.8;
    [_glass addSubview:_tint];
    CAGradientLayer *shine = [CAGradientLayer layer];
    shine.frame = _glass.bounds; shine.cornerRadius = 28;
    shine.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.2].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0.015].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0.06].CGColor];
    shine.locations = @[@0, @0.5, @1];
    shine.startPoint = CGPointMake(0.15, 0); shine.endPoint = CGPointMake(0.85, 1);
    [_glass.layer addSublayer:shine];
    _icon = [[UIImageView alloc] initWithFrame:CGRectMake(16, 16, 24, 24)];
    _icon.image = [UIImage systemImageNamed:symbol withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium]];
    _icon.contentMode = UIViewContentModeScaleAspectFit;
    [_glass addSubview:_icon]; [self addSubview:_glass];
    _caption = [[UILabel alloc] initWithFrame:CGRectMake(0, 59, 76, 20)];
    _caption.text = title; _caption.textColor = UIColor.whiteColor;
    _caption.font = MizzeFont(12,UIFontWeightSemibold);
    _caption.textAlignment = NSTextAlignmentCenter;
    _caption.shadowColor = [UIColor colorWithWhite:0 alpha:0.85]; _caption.shadowOffset = CGSizeMake(0, 1);
    _caption.userInteractionEnabled = NO; [self addSubview:_caption];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
    [self addGestureRecognizer:pan];
    return self;
}
- (void)setFeatureActive:(BOOL)active {
    _tint.backgroundColor = active ? [MizzeMint() colorWithAlphaComponent:0.18] : [UIColor colorWithWhite:1 alpha:0.03];
    _tint.layer.borderColor = [(active ? MizzeMint() : UIColor.whiteColor) colorWithAlphaComponent:0.55].CGColor;
    _icon.tintColor = active ? MizzeMint() : [UIColor colorWithWhite:1 alpha:0.75];
    self.accessibilityValue = active ? @"Bật" : @"Tắt";
}
- (void)clampToSuperview {
    if (!self.superview) return;
    CGSize size = self.superview.bounds.size;
    CGRect frame = self.frame;
    frame.origin.x = MAX(6, MIN(frame.origin.x, MAX(6, size.width - frame.size.width - 6)));
    frame.origin.y = MAX(6, MIN(frame.origin.y, MAX(6, size.height - frame.size.height - 6)));
    self.frame = frame;
}
- (void)savePosition {
    ESPPrefsSetFloat([_featureKey stringByAppendingString:@"FloatX"], self.frame.origin.x);
    ESPPrefsSetFloat([_featureKey stringByAppendingString:@"FloatY"], self.frame.origin.y);
}
- (void)drag:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) _dragCenter = self.center;
    CGPoint delta = [pan translationInView:self.superview];
    self.center = CGPointMake(_dragCenter.x + delta.x, _dragCenter.y + delta.y);
    [self clampToSuperview];
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) [self savePosition];
}
- (BOOL)handleRemotePoint:(CGPoint)point phase:(UITouchPhase)phase pointer:(NSInteger)pointer {
    if (self.hidden) return NO;
    if (phase == UITouchPhaseBegan) {
        if (_remotePointer != -1 || !CGRectContainsPoint(CGRectInset(self.frame, -3, -3), point)) return NO;
        _remotePointer = pointer; _dragPoint = point; _dragCenter = self.center; _moved = NO;
        return YES;
    }
    if (_remotePointer != pointer) return NO;
    CGFloat dx = point.x - _dragPoint.x, dy = point.y - _dragPoint.y;
    if (phase == UITouchPhaseMoved) {
        if (fabs(dx) + fabs(dy) > 8) _moved = YES;
        if (_moved) { self.center = CGPointMake(_dragCenter.x + dx, _dragCenter.y + dy); [self clampToSuperview]; }
    } else if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
        _remotePointer = -1;
        if (_moved) [self savePosition];
        else if (phase == UITouchPhaseEnded) [self sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
    return YES;
}
- (void)didMoveToWindow { [super didMoveToWindow]; if (!self.window) _remotePointer = -1; }
- (void)cancelTracking { _remotePointer = -1; _moved = NO; }
@end
