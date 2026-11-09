#import <Foundation/Foundation.h>
#include "KabraxHide.h"

@interface FBSOrientationUpdate : NSObject
- (unsigned long long)sequenceNumber;
- (long long)rotationDirection;
- (long long)orientation;
- (double)duration;
@end
