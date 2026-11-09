#pragma once
#import <UIKit/UIKit.h>

@interface FloatingFeatureControl : UIControl
@property(nonatomic,copy,readonly) NSString *featureKey;
- (instancetype)initWithKey:(NSString *)key title:(NSString *)title symbol:(NSString *)symbol;
- (void)setFeatureActive:(BOOL)active;
- (void)clampToSuperview;
- (void)cancelTracking;
- (BOOL)handleRemotePoint:(CGPoint)point phase:(UITouchPhase)phase pointer:(NSInteger)pointer;
@end
