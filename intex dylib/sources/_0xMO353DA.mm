#import "ModMenuViewController.h"
#import "../esp/drawing_view/esp.h"
#import "../esp/drawing_view/ESPStyle.h"
#import <objc/runtime.h>
#import "UIView+SecureView.h"
#import "MizzeTheme.h"
#import "MizzeMenuPrefs.h"
#include <cmath>
#import "../esp/Core/PlayerModes.h"

// ==========================================
// CLASS CÔNG TẮC (SWITCH) BO TRÒN
// ==========================================
@interface MizzeCheckBox : UIButton
@property(nonatomic,assign) BOOL on;
@property(nonatomic,strong) UIView *trackView;
@property(nonatomic,strong) UIView *thumbView;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@implementation MizzeCheckBox
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        
        self.trackView = [[UIView alloc] initWithFrame:self.bounds];
        self.trackView.layer.cornerRadius = frame.size.height / 2.0;
        self.trackView.userInteractionEnabled = NO;
        [self addSubview:self.trackView];
        
        CGFloat thumbSize = frame.size.height - 4;
        self.thumbView = [[UIView alloc] initWithFrame:CGRectMake(2, 2, thumbSize, thumbSize)];
        self.thumbView.layer.cornerRadius = thumbSize / 2.0;
        self.thumbView.backgroundColor = [UIColor whiteColor];
        self.thumbView.layer.shadowColor = [UIColor blackColor].CGColor;
        self.thumbView.layer.shadowOffset = CGSizeMake(0, 2);
        self.thumbView.layer.shadowOpacity = 0.3;
        self.thumbView.layer.shadowRadius = 2;
        self.thumbView.userInteractionEnabled = NO;
        [self addSubview:self.thumbView];
        
        [self setOn:NO animated:NO];
    }
    return self;
}
- (void)setOn:(BOOL)on { [self setOn:on animated:NO]; }
- (void)setOn:(BOOL)on animated:(BOOL)animated {
    _on = on;
    self.selected = on;
    void (^updateUI)(void) = ^{
        CGFloat thumbSize = self.bounds.size.height - 4;
        CGFloat targetX = on ? (self.bounds.size.width - thumbSize - 2) : 2;
        self.thumbView.frame = CGRectMake(targetX, 2, thumbSize, thumbSize);
        self.trackView.backgroundColor = on ? MizzeMint() : [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    };
    if (animated && !UIAccessibilityIsReduceMotionEnabled()) {
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:updateUI completion:nil];
    } else {
        updateUI();
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.trackView.frame = self.bounds;
    self.trackView.layer.cornerRadius = self.bounds.size.height / 2.0;
    CGFloat thumbSize = self.bounds.size.height - 4;
    self.thumbView.layer.cornerRadius = thumbSize / 2.0;
}
@end


// ==========================================
// CLASS CHÍNH CỦA MENU - GLASSMORPHISM
// ==========================================
@interface _0xDEADBEEE () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) NSArray<UIButton *> *navButtons;
@property (nonatomic, assign) CGFloat builtWidth;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) NSMutableArray<UIControl *> *controls;
@property (nonatomic, strong) UILabel *swatch;
@property (nonatomic, assign) NSInteger page;
@property (nonatomic, assign) NSInteger colorTarget;
@property (nonatomic, assign) BOOL aimExpanded;
@property (nonatomic, assign) BOOL floatingExpanded;
@property (nonatomic, assign) BOOL advancedExpanded;
@property (nonatomic, assign) NSInteger pointer;
@property (nonatomic, assign) CGPoint began;
@property (nonatomic, assign) CGPoint panelOrigin;
@property (nonatomic, assign) CGFloat scrollOrigin;
@property (nonatomic, assign) BOOL dragging;
@property (nonatomic, assign) BOOL scrolling;
@property (nonatomic, strong) UIControl *activeControl;
@property (nonatomic, strong) UILabel *spinStatusLabel;
@property (nonatomic, strong) NSTimer *spinStatusTimer;
@end

@implementation _0xDEADBEEE
- (UIColor *)textColor { return MizzeText(); }
- (UIColor *)mutedColor { return MizzeMuted(); }

- (void)viewDidLoad {
    [super viewDidLoad];
    MizzePrepareMenuPrefs();
    __weak _0xDEADBEEE *weakSelf=self;
    self.spinStatusTimer=[NSTimer scheduledTimerWithTimeInterval:.5 repeats:YES block:^(NSTimer *timer){
        _0xDEADBEEE *owner=weakSelf;
        if(owner.isViewLoaded&&owner.view.window&&!owner.view.hidden&&owner.spinStatusLabel)
            [owner updateSpinStatus];
    }];
    self.view.backgroundColor = UIColor.clearColor;
    self.pointer = -1;
    self.controls = [NSMutableArray array];
    
    // Hiệu ứng nền mờ kính (Blur)
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]];
    self.blurView.layer.cornerRadius = 24;
    self.blurView.clipsToBounds = YES;
    [self.view addSubview:self.blurView];
    
    self.panel = [[UIView alloc] initWithFrame:CGRectZero];
    self.panel.backgroundColor = [UIColor clearColor];
    self.panel.layer.cornerRadius = 24;
    self.panel.layer.borderWidth = 0.8;
    self.panel.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15].CGColor;
    self.panel.clipsToBounds = YES;
    [self.view addSubview:self.panel];
    
    self.header = [[UIView alloc] initWithFrame:CGRectZero];
    self.header.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.03];
    [self.panel addSubview:self.header];
    
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0, 57.5, 440, 0.5)];
    separator.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.1];
    separator.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.header addSubview:separator];
    
    UILabel *brand = [[UILabel alloc] initWithFrame:CGRectMake(18, 11, 220, 23)];
    brand.text = @"TWEAK IOS VIET";
    brand.font = MizzeFont(19, UIFontWeightBold);
    brand.adjustsFontSizeToFitWidth = YES; brand.minimumScaleFactor = 0.7;
    brand.tag = 10;
    [self.header addSubview:brand];
    
    UILabel *caption = [[UILabel alloc] initWithFrame:CGRectMake(18, 35, 220, 14)];
    caption.text = @"Dev: Zhee Dev (@zheedevVn)";
    caption.font = MizzeFont(9, UIFontWeightMedium);
    caption.tag = 11;
    [self.header addSubview:caption];
    
    UILabel *logo = [self label:@"Z" frame:CGRectMake(14, 12, 34, 34) size:23];
    logo.tag = 13; logo.textAlignment = NSTextAlignmentCenter;
    logo.layer.cornerRadius = 10; logo.clipsToBounds = YES;
    logo.backgroundColor = [MizzeMint() colorWithAlphaComponent:0.15];
    logo.textColor = MizzeMint();
    [self.header addSubview:logo];
    
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.frame = CGRectMake(268, 10, 32, 36);
    close.tag = 12;
    close.layer.cornerRadius = 10;
    [close setTitle:@"×" forState:UIControlStateNormal];
    close.titleLabel.font = MizzeFont(26, UIFontWeightMedium);
    [close addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.header addSubview:close];
    
    NSMutableArray *navigation = [NSMutableArray array];
    NSArray *names = @[@"Aim", @"ESP", @"Màu sắc", @"Thiết lập"];
    for (NSInteger i = 0; i < 4; ++i) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = 200 + i; button.accessibilityLabel = names[i];
        [button setTitle:names[i] forState:UIControlStateNormal];
        button.titleLabel.font = MizzeFont(13, UIFontWeightSemibold);
        button.layer.cornerRadius = 16;
        [button addTarget:self action:@selector(changePage:) forControlEvents:UIControlEventTouchUpInside];
        [self.panel addSubview:button]; [navigation addObject:button];
    }
    self.navButtons = navigation;
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragHeader:)];
    pan.delegate = self; [self.header addGestureRecognizer:pan];
    
    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scroll.showsVerticalScrollIndicator = NO;
    self.scroll.bounces = YES;
    [self.panel addSubview:self.scroll];
    [self buildPage];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat screenW = self.view.bounds.size.width;
    CGFloat screenH = self.view.bounds.size.height;
    if (screenW <= 0) screenW = 320.0f;
    if (screenH <= 0) screenH = 480.0f;

    CGFloat w = MIN(400.0f, MAX(200.0f, screenW - 24.0f));
    CGFloat h = MIN(560.0f, MAX(250.0f, screenH - 24.0f));
    
    CGRect f = self.panel.frame;
    if (f.size.width == 0) { 
        f.size = CGSizeMake(w, h);
        f.origin.x = (screenW - w) / 2;
        f.origin.y = (screenH - h) / 2;
    } else {
        f.size = CGSizeMake(w, h);
        f.origin.x = MAX(12.0f, MIN(f.origin.x, screenW - w - 12.0f));
        f.origin.y = MAX(12.0f, MIN(f.origin.y, screenH - h - 12.0f));
    }
    
    self.panel.frame = f;
    self.blurView.frame = f;
    
    self.header.frame = CGRectMake(0, 0, w, 58);
    [self.header viewWithTag:10].frame = CGRectMake(58, 10, MAX(10, w - 116), 24);
    [self.header viewWithTag:11].frame = CGRectMake(58, 35, MAX(10, w - 116), 13);
    
    UIView *closeBtn = [self.header viewWithTag:12];
    if (closeBtn) closeBtn.frame = CGRectMake(MAX(0.0f, w - 48.0f), 11, 36, 36);
    
    CGFloat navPadding = 14;
    CGFloat navGap = 6;
    CGFloat navStep = (w - navPadding * 2 - navGap * 3) / 4;
    for (NSInteger i = 0; i < 4; ++i)
        self.navButtons[i].frame = CGRectMake(navPadding + i * (navStep + navGap), 68, navStep, 32);
    
    self.scroll.frame = CGRectMake(14, 114, MAX(10, w - 28), MAX(10, h - 128));
    if (fabs(self.builtWidth - self.scroll.bounds.size.width) > 0.5) [self buildPage];
}

- (void)closeMenu { if (self.onCloseBlock) self.onCloseBlock(); }

- (void)changePage:(UIButton *)sender {
    if (self.page == sender.tag - 200) return;
    self.page = sender.tag - 200;
    self.scroll.contentOffset = CGPointZero;
    [self rebuildAnimated];
}

- (void)rebuildAnimated {
    if (UIAccessibilityIsReduceMotionEnabled()) { [self buildPage]; return; }
    [UIView transitionWithView:self.scroll duration:.2
        options:UIViewAnimationOptionTransitionCrossDissolve|UIViewAnimationOptionAllowUserInteraction
        animations:^{[self buildPage];} completion:nil];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    for (UIView *view = touch.view; view && view != gesture.view; view = view.superview)
        if ([view isKindOfClass:UIControl.class]) return NO;
    return YES;
}

- (void)dragHeader:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) self.panelOrigin = self.panel.frame.origin;
    CGPoint delta = [pan translationInView:self.view];
    CGRect frame = self.panel.frame;
    frame.origin = CGPointMake(self.panelOrigin.x + delta.x, self.panelOrigin.y + delta.y);
    self.panel.frame = frame;
    self.blurView.frame = frame;
    [self viewDidLayoutSubviews];
}

- (CGFloat)contentWidth { return self.scroll.bounds.size.width > 10 ? self.scroll.bounds.size.width : 360; }

- (NSString *)colorPrefix {
    NSArray *prefixes = @[@"BoxColor", @"FovColor"];
    NSInteger idx = MAX(0, MIN((NSInteger)prefixes.count - 1, self.colorTarget));
    return prefixes[idx];
}

- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text; label.textColor = [self textColor];
    label.font = MizzeFont(size, UIFontWeightMedium);
    return label;
}

// UI: Hàng cài đặt mỏng (46px)
- (CGFloat)toggle:(NSString *)title key:(NSString *)key fallback:(BOOL)fallback y:(CGFloat)y {
    CGFloat width = [self contentWidth];
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 46)];
    row.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    row.layer.cornerRadius = 10;
    
    UILabel *titleLabel = [self label:title frame:CGRectMake(14, 0, MAX(10, width - 86), 46) size:14.5];
    titleLabel.adjustsFontSizeToFitWidth = YES; titleLabel.minimumScaleFactor = 0.75;
    [row addSubview:titleLabel];
    
    MizzeCheckBox *sw = [[MizzeCheckBox alloc] initWithFrame:CGRectMake(width - 60, 10, 46, 26)];
    sw.accessibilityLabel = title;
    sw.on = ESPPrefsBool(key, fallback);
    objc_setAssociatedObject(sw, "key", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [sw addTarget:self action:@selector(checkboxPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleRow:)];
    tap.delegate = self;
    objc_setAssociatedObject(tap, "switch", sw, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [row addGestureRecognizer:tap];
    
    [row addSubview:sw]; [self.controls addObject:sw]; [self.scroll addSubview:row];
    return y + 52;
}

- (void)toggleRow:(UITapGestureRecognizer *)tap {
    MizzeCheckBox *sw = objc_getAssociatedObject(tap, "switch");
    if (sw.enabled) [sw sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (void)checkboxPressed:(MizzeCheckBox *)sender {
    NSString *key=objc_getAssociatedObject(sender,"key");
    NSNumber *choice=objc_getAssociatedObject(sender,"choice");
    if (choice) {
        if ([key isEqualToString:@"AimType"]) {
            self.aimExpanded=NO;
            if ((int)AimModePolicy::ReadType(ESPPrefsFloat(key,0)) == choice.intValue) {
                [self rebuildAnimated];return;
            }
            ESPPrefsSetFloat(key,choice.floatValue);
            ESPPrefsSetFloat(@"AimActivation",static_cast<int>(AimModePolicy::AfterTypeSelection(
                AimModePolicy::ReadType(choice.floatValue))));
            ESPPrefsSetBool(@"SilentAim",NO);
        } else {
            ESPPrefsSetFloat(key,sender.on ? 0 : choice.floatValue);
            const NSInteger active=static_cast<int>(AimModePolicy::ReadActivation(ESPPrefsFloat(key,0)));
            for (UIControl *control in self.controls) {
                if (![control isKindOfClass:MizzeCheckBox.class] ||
                    ![objc_getAssociatedObject(control,"key") isEqualToString:key]) continue;
                NSNumber *value=objc_getAssociatedObject(control,"choice");
                [(MizzeCheckBox *)control setOn:value.integerValue==active animated:YES];
            }
            ESPClearAimLock();ESPSyncFromPrefs();return;
        }
        ESPClearAimLock();ESPSyncFromPrefs();[self rebuildAnimated];
        return;
    }
    [sender setOn:!sender.on animated:YES];[self toggleChanged:sender];
}

- (CGFloat)choice:(NSString *)title key:(NSString *)key value:(NSInteger)value selected:(NSInteger)selected y:(CGFloat)y {
    CGFloat next=[self toggle:title key:key fallback:NO y:y];
    MizzeCheckBox *box=(MizzeCheckBox *)self.controls.lastObject;
    box.on=value==selected;
    objc_setAssociatedObject(box,"choice",@(value),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return next;
}

- (CGFloat)activationPicker:(CGFloat)y {
    NSArray *names=@[@"Khi bắn",@"Khi mở ngắm",@"Luôn luôn",@"Fire + Scope\n(cùng lúc)"];
    const NSInteger mode=static_cast<int>(AimModePolicy::ReadActivation(ESPPrefsFloat(@"AimActivation",0)));
    const CGFloat width=([self contentWidth]-8)*.5;
    for (NSUInteger i=0;i<names.count;++i) {
        [self choice:names[i] key:@"AimActivation" value:i+1 selected:mode y:y];
        MizzeCheckBox *box=(MizzeCheckBox *)self.controls.lastObject;
        UIView *row=box.superview;
        row.frame=CGRectMake((i%2)*(width+8),y+(i/2)*52,width,46);
        box.frame=CGRectMake(width-60,10,46,26);
        UILabel *label=(UILabel *)row.subviews.firstObject;
        label.frame=CGRectMake(12,0,width-70,46);label.numberOfLines=2;
        label.font=MizzeFont(12.5,UIFontWeightSemibold);
    }
    return y+110;
}

- (CGFloat)slider:(NSString *)title key:(NSString *)key min:(float)minimum max:(float)maximum fallback:(float)fallback y:(CGFloat)y {
    CGFloat width = [self contentWidth];
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, width, 70)];
    row.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    row.layer.cornerRadius = 10;
    
    UILabel *label = [self label:title frame:CGRectMake(14, 8, width - 28, 20) size:13];
    [row addSubview:label];
    
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(14, 30, width - 28, 30)];
    slider.minimumValue = minimum; slider.maximumValue = maximum;
    slider.value = ESPPrefsFloat(key, fallback);
    slider.minimumTrackTintColor = MizzeMint();
    slider.maximumTrackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    slider.thumbTintColor = MizzeMint();
    objc_setAssociatedObject(slider, "key", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(slider, "label", label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slider, "title", title, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:self action:@selector(fovSliderTouchUp:)
        forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    [row addSubview:slider]; [self.controls addObject:slider]; [self.scroll addSubview:row];
    [self updateSliderLabel:slider];
    return y + 78;
}

- (CGFloat)note:(NSString *)text y:(CGFloat)y {
    UILabel *label = [self label:text frame:CGRectMake(8, y, [self contentWidth] - 16, 36) size:12];
    label.textColor = [self mutedColor]; label.numberOfLines = 0;
    [self.scroll addSubview:label]; return y + 40;
}

- (CGFloat)section:(NSString *)title y:(CGFloat)y {
    UILabel *label = [self label:title frame:CGRectMake(6, y + 8, [self contentWidth] - 12, 20) size:12];
    label.textColor = [self mutedColor];
    label.font = MizzeFont(12, UIFontWeightBold);
    label.text = [title uppercaseString];
    [self.scroll addSubview:label];
    return y + 34;
}

- (void)chooseAim { self.aimExpanded=!self.aimExpanded;[self rebuildAnimated]; }

- (CGFloat)numberInput:(NSString *)title key:(NSString *)key fallback:(float)fallback y:(CGFloat)y {
    UIView *row=[[UIView alloc] initWithFrame:CGRectMake(0,y,[self contentWidth],50)];
    row.backgroundColor=[[UIColor whiteColor] colorWithAlphaComponent:0.05];
    row.layer.cornerRadius=10;
    
    [row addSubview:[self label:title frame:CGRectMake(14,0,[self contentWidth]-132,50) size:14]];
    UITextField *field=[[UITextField alloc] initWithFrame:CGRectMake([self contentWidth]-110,8,96,34)];
    field.text=[NSString stringWithFormat:@"%.2f",ESPPrefsFloat(key,fallback)];
    field.keyboardType=UIKeyboardTypeDecimalPad;field.textAlignment=NSTextAlignmentCenter;
    field.textColor=MizzeMint();field.backgroundColor=[[UIColor blackColor] colorWithAlphaComponent:0.2];field.layer.cornerRadius=8;
    field.font=MizzeFont(15,UIFontWeightSemibold);
    field.accessibilityLabel=title;
    objc_setAssociatedObject(field,"key",key,OBJC_ASSOCIATION_COPY_NONATOMIC);
    [field addTarget:self action:@selector(numberChanged:) forControlEvents:UIControlEventEditingChanged];
    UIToolbar *toolbar=[[UIToolbar alloc] initWithFrame:CGRectMake(0,0,[self contentWidth],44)];
    toolbar.items=@[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        [[UIBarButtonItem alloc] initWithTitle:@"Xong" style:UIBarButtonItemStyleDone target:self action:@selector(finishNumber)]];
    field.inputAccessoryView=toolbar;
    [row addSubview:field];[self.controls addObject:field];[self.scroll addSubview:row];return y+58;
}

- (void)finishNumber { [self.view endEditing:YES]; }

- (CGFloat)disclosure:(NSString *)title tag:(NSInteger)tag expanded:(BOOL)expanded y:(CGFloat)y {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    button.frame=CGRectMake(0,y,[self contentWidth],46);button.tag=tag;
    button.backgroundColor=[[UIColor whiteColor] colorWithAlphaComponent:0.05];button.layer.cornerRadius=10;
    [button setTitle:[NSString stringWithFormat:@"%@  %@",title,expanded?@"▴":@"▾"] forState:UIControlStateNormal];
    [button setTitleColor:MizzeText() forState:UIControlStateNormal];
    button.titleLabel.font=MizzeFont(14.5, UIFontWeightSemibold);
    [button addTarget:self action:@selector(disclosureChanged:) forControlEvents:UIControlEventTouchUpInside];
    [self.scroll addSubview:button];[self.controls addObject:button];return y+54;
}

- (void)disclosureChanged:(UIButton *)button {
    if(button.tag==701)self.floatingExpanded=!self.floatingExpanded;
    else self.advancedExpanded=!self.advancedExpanded;
    [self rebuildAnimated];
}

- (void)numberChanged:(UITextField *)field {
    NSString *text=[field.text stringByReplacingOccurrencesOfString:@"," withString:@"."];
    NSScanner *scanner=[NSScanner scannerWithString:text];scanner.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    double value=0;
    if (![scanner scanDouble:&value] || !scanner.isAtEnd || !std::isfinite(value) || value<0.1 || value>30) return;
    ESPPrefsSetFloat(objc_getAssociatedObject(field,"key"),(float)value);ESPSyncFromPrefs();
}

- (CGFloat)aimChooser:(CGFloat)y {
    NSArray *names=@[@"Aim đầu",@"Aim cổ",@"Silent Aim"];
    const NSInteger type=static_cast<int>(AimModePolicy::ReadType(ESPPrefsFloat(@"AimType",0)));
    NSString *summary=names[type];
    UIButton *chooser=[UIButton buttonWithType:UIButtonTypeSystem];chooser.tag=302;
    chooser.frame=CGRectMake(0,y,[self contentWidth],50);chooser.layer.cornerRadius=10;
    chooser.backgroundColor=[[UIColor whiteColor] colorWithAlphaComponent:0.05];
    chooser.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    chooser.contentEdgeInsets=UIEdgeInsetsMake(0,14,0,14);
    [chooser setTitle:[NSString stringWithFormat:@"Loại aim   %@  %@",summary,self.aimExpanded ? @"▴" : @"▾"] forState:UIControlStateNormal];
    [chooser setTitleColor:MizzeMint() forState:UIControlStateNormal];
    chooser.titleLabel.font=MizzeFont(14, UIFontWeightSemibold);
    chooser.titleLabel.adjustsFontSizeToFitWidth=YES;
    [chooser addTarget:self action:@selector(chooseAim) forControlEvents:UIControlEventTouchUpInside];
    [self.scroll addSubview:chooser];[self.controls addObject:chooser];y+=58;
    if(self.aimExpanded) for(NSUInteger i=0;i<names.count;++i)
        y=[self choice:names[i] key:@"AimType" value:i selected:type y:y];
    return y;
}

- (void)buildPage {
    const CGFloat offset = self.scroll.contentOffset.y;
    for (UIView *v in self.scroll.subviews) [v removeFromSuperview];
    [self.controls removeAllObjects]; self.swatch = nil; self.spinStatusLabel=nil;
    self.builtWidth = [self contentWidth];
    
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        self.blurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
    }
    
    ((UILabel *)[self.header viewWithTag:10]).textColor = UIColor.whiteColor;
    ((UILabel *)[self.header viewWithTag:11]).textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    [(UIButton *)[self.header viewWithTag:12] setTitleColor:[UIColor colorWithWhite:0.7 alpha:1.0] forState:UIControlStateNormal];
    
    for (NSInteger i = 0; i < 4; ++i) {
        UIButton *button = self.navButtons[i];
        if (i == self.page) {
            [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
            button.backgroundColor = MizzeMint();
        } else {
            [button setTitleColor:[UIColor colorWithWhite:0.7 alpha:1.0] forState:UIControlStateNormal];
            button.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
        }
    }
    
    CGFloat y = 0;
    if (self.page == 0) {
        y = [self aimChooser:y];
        const BOOL silent=AimModePolicy::ReadType(ESPPrefsFloat(@"AimType",0))==AimModePolicy::Type::Silent;
        const BOOL aimKill=ESPPrefsBool(@"AutoFire",NO);
        if (silent) {
            y = [self toggle:@"Bật Silent Aim" key:@"SilentAim" fallback:NO y:y];
        } else {
            y=[self section:@"Kích hoạt" y:y];
            y=[self activationPicker:y];
        }
        y = [self toggle:@"Aimlag khi ngắm" key:@"AimLag" fallback:NO y:y];
        y = [self toggle:@"Dây tới mục tiêu" key:@"AimTargetLine" fallback:YES y:y];
        y = [self slider:@"FOV" key:(silent || aimKill) ? @"SilentFovSize" : @"FovSize"
            min:5 max:48 fallback:(silent || aimKill) ? 18 : 40 y:y];
        y = [self toggle:@"Hiện vòng FOV" key:@"ShowFov" fallback:YES y:y];
        y = [self toggle:@"AimKill" key:@"AutoFireFloating" fallback:NO y:y];
        if (silent || ESPPrefsBool(@"AutoFireFloating", NO))
            y = [self slider:@"Tỷ lệ headshot" key:@"SilentHeadPercent" min:0 max:100 fallback:75 y:y];
        y = [self section:@"Súng" y:y];
        y = [self toggle:@"Bắn nhanh (2×)" key:@"FastFire" fallback:NO y:y];
        y = [self toggle:@"Không nạp đạn" key:@"ShootNoReload" fallback:NO y:y];
        y = [self disclosure:@"Cài đặt nâng cao" tag:702 expanded:self.advancedExpanded y:y];
        if(self.advancedExpanded) {
            if (silent) y = [self toggle:@"Tự chọn tầm Silent" key:@"SilentAutoConfig" fallback:YES y:y];
            if (silent && !ESPPrefsBool(@"SilentAutoConfig", YES)) {
                y = [self slider:@"Tầm chọn Silent" key:@"SilentMaxDistance" min:10 max:150 fallback:100 y:y];
            }
        }
    } else if (self.page == 1) {
        y = [self toggle:@"Bật ESP" key:@"ESPEnabled" fallback:YES y:y];
        
        UIButton *preset = [UIButton buttonWithType:UIButtonTypeSystem];
        preset.frame = CGRectMake(0, y, [self contentWidth], 46); preset.tag = 300;
        preset.layer.cornerRadius = 12; 
        preset.backgroundColor = [MizzeMint() colorWithAlphaComponent:0.15];
        [preset setTitle:@"⚡ Áp dụng ESP tối giản" forState:UIControlStateNormal];
        [preset setTitleColor:MizzeMint() forState:UIControlStateNormal];
        preset.titleLabel.font = MizzeFont(14, UIFontWeightSemibold);
        [preset addTarget:self action:@selector(applyMinimalESP) forControlEvents:UIControlEventTouchUpInside];
        [self.scroll addSubview:preset]; [self.controls addObject:preset]; y += 54;
        
        y = [self toggle:@"Khung góc mảnh" key:@"CleanESP" fallback:YES y:y];
        y = [self toggle:@"Tên người chơi" key:@"Name" fallback:YES y:y];
        y = [self toggle:@"Thanh máu" key:@"Health" fallback:YES y:y];
        y = [self toggle:@"Trục XYZ" key:@"Line" fallback:NO y:y];
        y = [self toggle:@"Khung người chơi" key:@"Box" fallback:YES y:y];
        y = [self toggle:@"Xương người chơi" key:@"Skeleton" fallback:NO y:y];
        y = [self toggle:@"Điểm đánh dấu đầu" key:@"HeadRedDot" fallback:NO y:y];
        y = [self toggle:@"Khoảng cách" key:@"Dis" fallback:YES y:y];
        
        y = [self section:@"Tùy chỉnh khung" y:y];
        UISegmentedControl *boxStyle = [[UISegmentedControl alloc] initWithItems:@[@"2D", @"3D"]];
        boxStyle.frame = CGRectMake(0, y, [self contentWidth], 40);
        boxStyle.tag = 101;
        boxStyle.selectedSegmentIndex = ESPPrefsBool(@"Box3D", NO) ? 1 : 0;
        [boxStyle addTarget:self action:@selector(boxStyleChanged:) forControlEvents:UIControlEventValueChanged];
        [self.scroll addSubview:boxStyle]; [self.controls addObject:boxStyle];
        y += 50;
        
        y = [self slider:@"Tầm hiển thị ESP" key:@"ESPMaxDistance" min:50 max:500 fallback:150 y:y];
        y = [self slider:@"Vàng khi máu ≤" key:@"HealthYellowPercent" min:10 max:90 fallback:50 y:y];
        y = [self slider:@"Đỏ khi máu ≤" key:@"HealthRedPercent" min:5 max:80 fallback:25 y:y];
    } else if (self.page == 2) {
        UISegmentedControl *target = [[UISegmentedControl alloc] initWithItems:@[@"Box", @"FOV"]];
        target.frame = CGRectMake(0, y, [self contentWidth], 40); target.selectedSegmentIndex = self.colorTarget;
        [target addTarget:self action:@selector(colorTargetChanged:) forControlEvents:UIControlEventValueChanged];
        [self.scroll addSubview:target]; [self.controls addObject:target];
        y += 50;
        
        self.swatch = [self label:@"" frame:CGRectMake(0, y, [self contentWidth], 50) size:16];
        self.swatch.textAlignment = NSTextAlignmentCenter; self.swatch.layer.cornerRadius = 12; self.swatch.clipsToBounds = YES;
        self.swatch.font = MizzeFont(16, UIFontWeightBold);
        [self.scroll addSubview:self.swatch]; y += 62;
        
        NSString *prefix = [self colorPrefix];
        float defaults[3] = {0.46f, 0.86f, 0.73f};
        NSArray *names = @[@"Đỏ", @"Lục", @"Lam"], *suffixes = @[@"R", @"G", @"B"];
        for (int i = 0; i < 3; ++i) y = [self slider:names[i] key:[prefix stringByAppendingString:suffixes[i]] min:0 max:1 fallback:defaults[i] y:y];
        [self updateSwatch];
    } else {
        y = [self section:@"Nút nổi" y:y];
        y = [self toggle:@"Ghost" key:@"GhostModeFloating" fallback:NO y:y];
        y = [self toggle:@"FakeLag" key:@"FakeLagFloating" fallback:NO y:y];
        y = [self toggle:@"Fly" key:@"FlyFloating" fallback:NO y:y];
        y = [self toggle:@"Ẩn nút chức năng" key:@"HideFeatureButtons" fallback:NO y:y];
        y = [self toggle:@"Nút Speed" key:@"RunSpeedFloating" fallback:ESPPrefsBool(@"RunSpeed",NO) y:y];
        
        y = [self section:@"Di chuyển" y:y];
        if (ESPPrefsBool(@"FlyFloating", NO))
            y = [self slider:@"Độ cao Fly" key:@"FlyHeight" min:1 max:6 fallback:4 y:y];
        y = [self toggle:@"Speed" key:@"RunSpeed" fallback:NO y:y];
        y = [self numberInput:@"Tốc độ (m/s)" key:@"RunSpeedValue" fallback:6 y:y];
        
        y = [self section:@"Hiệu ứng & Khác" y:y];
        y = [self toggle:@"Spin · chỉ mình thấy" key:@"VisualSpin" fallback:NO y:y];
        if (ESPPrefsBool(@"VisualSpin",NO)) {
            y = [self slider:@"Vòng / giây" key:@"VisualSpinSpeed" min:0.1 max:3 fallback:0.5 y:y];
            self.spinStatusLabel=[self label:@"" frame:CGRectMake(8,y,[self contentWidth]-16,38) size:12];
            self.spinStatusLabel.textColor=MizzeMuted();self.spinStatusLabel.numberOfLines=2;
            [self.scroll addSubview:self.spinStatusLabel];[self updateSpinStatus];y+=44;
        }
        y = [self toggle:@"Ẩn khi chụp / quay" key:@"AnLive" fallback:NO y:y];
        y = [self toggle:@"Giao diện tối" key:@"DarkTheme" fallback:YES y:y];
        y = [self toggle:@"Tiết kiệm pin (30 FPS)" key:@"BalancedRender" fallback:NO y:y];
    }
    
    UILabel *credit=[self label:@"TweakIOSVIET by Zhee Dev" frame:CGRectMake(8,y+16,[self contentWidth]-16,20) size:10];
    credit.textColor=[[UIColor whiteColor] colorWithAlphaComponent:0.3];credit.textAlignment=NSTextAlignmentCenter;
    [self.scroll addSubview:credit];y+=50;
    
    for (UIControl *control in self.controls) {
        if (![control isKindOfClass:UISegmentedControl.class]) continue;
        UISegmentedControl *segment=(UISegmentedControl *)control;
        segment.selectedSegmentTintColor=MizzeMint();
        [segment setTitleTextAttributes:@{NSFontAttributeName:MizzeFont(14,UIFontWeightSemibold),
            NSForegroundColorAttributeName:[UIColor colorWithWhite:0.7 alpha:1.0]} forState:UIControlStateNormal];
        [segment setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.blackColor} forState:UIControlStateSelected];
    }
    
    self.scroll.contentSize = CGSizeMake([self contentWidth], y + 8);
    self.scroll.contentOffset = CGPointMake(0, MAX(0, MIN(offset, y + 8 - self.scroll.bounds.size.height)));
}

- (void)toggleChanged:(MizzeCheckBox *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    if ([@[@"GhostModeFloating",@"FakeLagFloating",@"AutoFireFloating",@"FlyFloating"] containsObject:key]) {
        NSString *feature=[key stringByReplacingOccurrencesOfString:@"Floating" withString:@""];
        ESPPrefsSetBool(feature,sender.on);
        if (sender.on) {
            ESPPrefsSetBool(@"HideFeatureButtons",NO);
            for (UIControl *control in self.controls)
                if ([control isKindOfClass:MizzeCheckBox.class] &&
                    [objc_getAssociatedObject(control,"key") isEqualToString:@"HideFeatureButtons"])
                    [(MizzeCheckBox *)control setOn:NO animated:YES];
        }
    }
    if ([key isEqualToString:@"CleanESP"] && sender.on) ESPPrefsSetBool(@"Box3D", NO);
    ESPPrefsSetBool(key, sender.on); ESPSyncFromPrefs();
    if ([@[@"RunSpeed"] containsObject:key] &&
        !AppSettingsObjectForKey([key stringByAppendingString:@"Floating"]))
        ESPPrefsSetBool([key stringByAppendingString:@"Floating"], YES);
    if ([key isEqualToString:@"AnLive"] && ![UIView applyCaptureProtectionToRegisteredViews:sender.on]) {
        sender.on = NO; ESPPrefsSetBool(key, NO);
        [UIView applyCaptureProtectionToRegisteredViews:NO];
        [self note:@"iOS này không hỗ trợ cơ chế ẩn hiện tại." y:self.scroll.contentSize.height];
        self.scroll.contentSize = CGSizeMake([self contentWidth], self.scroll.contentSize.height + 48);
    }
    if ([key isEqualToString:@"CleanESP"] && sender.on)
        for (UIControl *control in self.controls)
            if ([control isKindOfClass:UISegmentedControl.class] && control.tag==101)
                ((UISegmentedControl *)control).selectedSegmentIndex=0;
    if ([@[@"DarkTheme",@"SilentAutoConfig",@"AutoFireFloating",@"FlyFloating",@"VisualSpin"] containsObject:key]) [self rebuildAnimated];
}

- (void)updateSpinStatus {
    const auto state=PlayerModesRead();
    NSString *text=@"Spin: chờ nhịp cuối của game";
    if(state.detail&&state.detail[0])text=[NSString stringWithUTF8String:state.detail];
    else if(state.spinStatus==1)text=@"Spin: chờ nhân vật trong trận";
    else if(state.spinStatus==2)text=@"Spin: chưa có mô hình xoay phù hợp";
    else if(state.spinStatus==3)text=@"Spin: chờ góc xoay ổn định";
    else if(state.spinStatus==4)text=[NSString stringWithFormat:@"Spin: đã áp dụng · %llu",(unsigned long long)state.spinApplies];
    self.spinStatusLabel.text=text;
}

- (void)dealloc { [self.spinStatusTimer invalidate]; }

- (void)applyMinimalESP {
    for (NSString *key in @[@"ESPEnabled", @"Box", @"Health", @"Name", @"Dis", @"CleanESP"])
        ESPPrefsSetBool(key, YES);
    for (NSString *key in @[@"Line", @"Skeleton", @"HeadRedDot", @"Box3D", @"BalancedRender"])
        ESPPrefsSetBool(key, NO);
    for (NSString *prefix in @[@"BoxColor", @"LineColor", @"FovColor"]) {
        ESPPrefsSetFloat([prefix stringByAppendingString:@"R"], 0.46);
        ESPPrefsSetFloat([prefix stringByAppendingString:@"G"], 0.86);
        ESPPrefsSetFloat([prefix stringByAppendingString:@"B"], 0.73);
    }
    ESPSyncFromPrefs(); [self buildPage];
}

- (void)colorTargetChanged:(UISegmentedControl *)sender {
    self.colorTarget = sender.selectedSegmentIndex; [self buildPage];
}

- (void)boxStyleChanged:(UISegmentedControl *)sender {
    ESPPrefsSetBool(@"Box3D", sender.selectedSegmentIndex == 1);
    ESPPrefsSetBool(@"Box", YES);
    if (sender.selectedSegmentIndex == 1) ESPPrefsSetBool(@"CleanESP", NO);
    for (UIControl *control in self.controls) {
        if (![control isKindOfClass:MizzeCheckBox.class]) continue;
        NSString *key = objc_getAssociatedObject(control, "key");
        if ([key isEqualToString:@"Box"] || [key isEqualToString:@"CleanESP"])
            ((MizzeCheckBox *)control).on = ESPPrefsBool(key, NO);
    }
    ESPSyncFromPrefs();
}

- (void)updateSliderLabel:(UISlider *)sender {
    UILabel *label = objc_getAssociatedObject(sender, "label");
    NSString *key = objc_getAssociatedObject(sender, "key"), *title = objc_getAssociatedObject(sender, "title");
    if ([key isEqualToString:@"FovSize"] || [key isEqualToString:@"SilentFovSize"] ||
        [key isEqualToString:@"SilentHeadPercent"] || [key isEqualToString:@"HealthYellowPercent"] ||
        [key isEqualToString:@"HealthRedPercent"]) {
        label.text = [NSString stringWithFormat:@"%@   %.0f%%", title, sender.value];
    } else if ([key isEqualToString:@"VisualSpinSpeed"]) {
        label.text = [NSString stringWithFormat:@"%@   %.1f", title, sender.value];
    } else if ([key isEqualToString:@"FlyHeight"]) {
        label.text = [NSString stringWithFormat:@"%@   %.2f m", title, sender.value];
    } else if ([key isEqualToString:@"ESPMaxDistance"] || [key isEqualToString:@"SilentMaxDistance"]) {
        label.text = [NSString stringWithFormat:@"%@   %.0fm", title, sender.value];
    } else {
        label.text = [NSString stringWithFormat:@"%@   %.0f", title, sender.value * 255];
    }
}

- (void)sliderChanged:(UISlider *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    ESPPrefsSetFloat(key, sender.value);
    if ([key isEqualToString:@"HealthRedPercent"] || [key isEqualToString:@"HealthYellowPercent"]) {
        float red = ESPPrefsFloat(@"HealthRedPercent", 25), yellow = ESPPrefsFloat(@"HealthYellowPercent", 50);
        if (red > yellow) {
            NSString *other = [key isEqualToString:@"HealthRedPercent"] ? @"HealthYellowPercent" : @"HealthRedPercent";
            const float value = sender.value;
            ESPPrefsSetFloat(other, value);
            for (UIControl *control in self.controls) {
                if (![control isKindOfClass:UISlider.class] ||
                    ![objc_getAssociatedObject(control, "key") isEqualToString:other]) continue;
                UISlider *slider = (UISlider *)control; slider.value = value;
                [self updateSliderLabel:slider];
            }
        }
    }
    if ([key isEqualToString:@"FovSize"] || [key isEqualToString:@"SilentFovSize"]) {
        NSNumber *savedFov = objc_getAssociatedObject(sender, "origShowFov");
        if (!savedFov) {
            BOOL orig = ESPPrefsBool(@"ShowFov", YES);
            objc_setAssociatedObject(sender, "origShowFov", @(orig), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (!orig) {
                ESPPrefsSetBool(@"ShowFov", YES);
            }
        }
        ESPClearAimLock();
    }
    ESPSyncFromPrefs(); [self updateSliderLabel:sender]; [self updateSwatch];
}

- (void)updateSwatch {
    if (!self.swatch) return;
    NSString *prefix = [self colorPrefix];
    if (!prefix) return;
    UIColor *color = ESPColor(prefix, 0.46, 0.86, 0.73);
    if (!color) return;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        self.swatch.backgroundColor = color;
        self.swatch.textColor = (r * 0.299 + g * 0.587 + b * 0.114) > 0.6 ? UIColor.blackColor : UIColor.whiteColor;
        self.swatch.text = [NSString stringWithFormat:@"#%02X%02X%02X", (int)round(r * 255), (int)round(g * 255), (int)round(b * 255)];
    }
}

- (void)setSlider:(UISlider *)slider point:(CGPoint)point {
    CGPoint p = [slider convertPoint:point fromView:self.view];
    CGFloat ratio = MAX(0, MIN(1, (p.x - 16) / MAX(1, slider.bounds.size.width - 32)));
    slider.value = slider.minimumValue + ratio * (slider.maximumValue - slider.minimumValue);
    [self sliderChanged:slider];
}

- (void)fovSliderTouchUp:(UISlider *)sender {
    NSNumber *savedFov = objc_getAssociatedObject(sender, "origShowFov");
    if (savedFov && ![savedFov boolValue]) {
        ESPPrefsSetBool(@"ShowFov", NO);
        ESPSyncFromPrefs();
    }
    objc_setAssociatedObject(sender, "origShowFov", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)_0xF010:(CGPoint)point phase:(NSInteger)phase pointerId:(NSInteger)pointerId {
    if (phase == UITouchPhaseBegan) {
        if (!CGRectContainsPoint(self.panel.frame, point)) return NO;
        if (self.pointer != -1) return YES;
        self.pointer = pointerId; self.began = point; self.panelOrigin = self.panel.frame.origin;
        self.scrollOrigin = self.scroll.contentOffset.y; self.scrolling = NO; self.activeControl = nil;
        CGPoint local = [self.panel convertPoint:point fromView:self.view];
        self.dragging = local.y < 58 && local.x < self.panel.bounds.size.width - 58;
        if (self.dragging) return YES;
        NSMutableArray *fixed = [NSMutableArray array];
        [fixed addObjectsFromArray:self.navButtons];
        UIView *closeBtn = [self.header viewWithTag:12];
        if ([closeBtn isKindOfClass:[UIControl class]]) [fixed addObject:closeBtn];
        for (UIControl *c in fixed) if (CGRectContainsPoint(c.bounds, [c convertPoint:point fromView:self.view])) self.activeControl = c;
        if (CGRectContainsPoint(self.scroll.bounds, [self.scroll convertPoint:point fromView:self.view])) {
            for (UIControl *c in self.controls) {
                if (!c.enabled) continue;
                CGRect hit = c.bounds;
                if ([c isKindOfClass:MizzeCheckBox.class]) hit = [c convertRect:c.superview.bounds fromView:c.superview];
                if (CGRectContainsPoint(hit, [c convertPoint:point fromView:self.view])) { self.activeControl = c; break; }
            }
        }
        if ([self.activeControl isKindOfClass:UIButton.class]) ((UIButton *)self.activeControl).highlighted=YES;
        if ([self.activeControl isKindOfClass:UISlider.class]) [self setSlider:(UISlider *)self.activeControl point:point];
        return YES;
    }
    if (self.pointer != pointerId) return NO;
    CGFloat dx = point.x - self.began.x, dy = point.y - self.began.y;
    if (phase == UITouchPhaseMoved) {
        if (self.dragging) {
            CGRect f = self.panel.frame; f.origin = CGPointMake(self.panelOrigin.x + dx, self.panelOrigin.y + dy); self.panel.frame = f;
            self.blurView.frame = f;
            [self viewDidLayoutSubviews];
        } else if ([self.activeControl isKindOfClass:UISlider.class]) {
            [self setSlider:(UISlider *)self.activeControl point:point];
        } else if (fabs(dy) > 7 || self.scrolling) {
            self.scrolling = YES;
            if ([self.activeControl isKindOfClass:UIButton.class]) ((UIButton *)self.activeControl).highlighted=NO;
            CGFloat maxY = MAX(0, self.scroll.contentSize.height - self.scroll.bounds.size.height);
            self.scroll.contentOffset = CGPointMake(0, MAX(0, MIN(maxY, self.scrollOrigin - dy)));
        }
        return YES;
    }
    if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
        UIControl *control = self.activeControl;
        BOOL activate = phase == UITouchPhaseEnded && !self.dragging && !self.scrolling && fabs(dx) < 24 && fabs(dy) < 24;
        self.pointer = -1; self.activeControl = nil;
        if (activate && !control.enabled) activate = NO;
        if ([control isKindOfClass:UIButton.class]) ((UIButton *)control).highlighted=NO;
        if (activate && [control isKindOfClass:UISegmentedControl.class]) {
            UISegmentedControl *seg = (UISegmentedControl *)control;
            CGPoint p = [seg convertPoint:point fromView:self.view];
            seg.selectedSegmentIndex = MAX(0, MIN(seg.numberOfSegments - 1, (NSInteger)(p.x / (seg.bounds.size.width / seg.numberOfSegments))));
            [seg sendActionsForControlEvents:UIControlEventValueChanged];
        } else if (activate && [control isKindOfClass:UIButton.class]) {
            [control sendActionsForControlEvents:UIControlEventTouchUpInside];
        } else if (activate && [control isKindOfClass:UITextField.class]) {
            [control becomeFirstResponder];
        }
        if ([control isKindOfClass:UISlider.class]) [self fovSliderTouchUp:(UISlider *)control];
        return YES;
    }
    return YES;
}
@end
