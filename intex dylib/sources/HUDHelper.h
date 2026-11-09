
#include "KabraxHide.h"
#import <Foundation/Foundation.h>

BOOL IsHUDEnabled(void);
BOOL StartHUD(NSError **error);
void StopHUD(void);
void StopHUDWithMessage(NSString *message);
NSString *HUDLastStatusMessage(void);
void HUDMarkStarting(void);
void HUDMarkReady(void);
void HUDRecordFrame(double milliseconds, int players, NSString *aimState);
void RequestExitHUDWithMessage(NSString *message);
void _0xFFFADK2(BOOL isEnabled);

void RequestExitHUD(void);
