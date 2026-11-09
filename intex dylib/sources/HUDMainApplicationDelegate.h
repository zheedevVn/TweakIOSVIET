
#include "KabraxHide.h"
#import <UIKit/UIKit.h>

@interface HUDMainApplicationDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
- (BOOL)handleTouchAtScreenPoint:(CGPoint)screenPoint phase:(UITouchPhase)phase pointerId:(NSInteger)pointerId;
- (void)restoreWindowHosting;
@end
