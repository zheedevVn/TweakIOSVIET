// HUDMainWindow.h - sửa header để khai báo đúng
#include "KabraxHide.h"

#import "UIAutoRotatingWindow.h"

@interface HUDMainWindow : UIAutoRotatingWindow
@property (nonatomic, assign) BOOL passThroughExcept3Fingers;
// Không khai báo thêm gì
@end