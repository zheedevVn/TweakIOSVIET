#import <Foundation/Foundation.h>
#include "KabraxHide.h"

@interface FBSOrientationObserver : NSObject
- (long long)activeInterfaceOrientation;
- (void)activeInterfaceOrientationWithCompletion:(id)arg1;
- (void)invalidate;
- (void)setHandler:(id)arg1;
- (id)handler;
@end
