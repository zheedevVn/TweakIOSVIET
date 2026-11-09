
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <stdint.h>
#include "KabraxHide.h"

#import "../Core/GameLogic.h"

typedef struct {
    CGMutablePathRef boxPath;
    CGMutablePathRef bonePath;
    CGMutablePathRef snaplinePath;
    CGMutablePathRef hpBackgroundPath;
    CGMutablePathRef hpFillPath;
    CGMutablePathRef hpWarningPath;
    CGMutablePathRef hpCriticalPath;
    CGMutablePathRef hpHighlightPath;
    CGMutablePathRef aimAssistPath;
    CGMutablePathRef alertPath;

CGMutablePathRef boxBotPath;
CGMutablePathRef boxPlayerPath;

CGMutablePathRef axisYPath;
CGMutablePathRef axisXPath;

CGMutablePathRef boxKnockPath;
CGMutablePathRef axisZPath;

bool boxBotDirty;
bool boxPlayerDirty;
bool boxKnockDirty;

bool axisYDirty;
bool axisXDirty;
bool axisZDirty;


    bool boxDirty;
    bool boneDirty;
    bool snaplineDirty;
    bool hpBackgroundDirty;
    bool hpFillDirty;
    bool hpWarningDirty;
    bool hpCriticalDirty;
    bool hpHighlightDirty;
    bool aimAssistDirty;
    bool alertDirty;
} ESPGeometryBuffers;

typedef void (*ESPAddTextCallback)(
    void *context,
    NSString *string,
    CGRect frame,
    UIColor *color,
    CGFloat fontSize,
    BOOL leftAligned
);

extern bool isHeadRedDot;
extern bool isBox;
extern bool isBox3D;
extern bool isCleanESP;
extern bool isBone;
extern bool isHealth;
extern bool isName;
extern bool isDis;
extern bool isLine;
extern bool isEspBot;
extern bool isWeapon;
extern bool isAimIgnoreBot;
extern bool isAimIgnoreKnock;
extern bool isAimCheckVisible;
extern bool isAimRage;
extern bool isLineAim;

extern bool isAimbot;
extern int  box;
extern int  triggerMode;
extern int  aimPosition;
extern int  aimTargetMode;
extern float aimFov;
extern float aimDistance;
extern float aimSpeed;

bool get_IsBot(uint64_t PawnObject);
bool get_IsKnockedDown(uint64_t PawnObject);

UIFont *VietnameseFontForLayer(CGFloat size);

BOOL RenderFOVCirclePath(
    CGMutablePathRef path,
    float viewWidth,
    float viewHeight,
    BOOL aimbotEnabled,
    float fovRadius
);

void RenderXYZAxes(ESPGeometryBuffers *buffers, const Vector3 &origin,
                   const float *matrix, float width, float height);

void _0x35572DA(
    ESPGeometryBuffers *buffers,
    ESPAddTextCallback textCallback,
    void *callbackContext,
    uint64_t PawnObject,
    int CurHP,
    float dis,
    const Vector3 &hip,
    bool knocked,
    bool bot,
    float *matrix,
    float layerWidth,
    float layerHeight,
    float matrixVpWidth,
    float matrixVpHeight
);

void ESPSyncFromPrefs(void);
// Nhả aim lock để render frame kế tiếp đánh giá lại theo FOV mới
void ESPClearAimLock(void);
BOOL ESPMatchReady(void);
FOUNDATION_EXPORT NSNotificationName const ESPMatchReadyChangedNotification;


@interface _0xDAB2826 : UIView
- (instancetype)initWithFrame:(CGRect)frame;
- (void)hideMenu;
- (void)showMenu;
- (void)handlePan:(UIPanGestureRecognizer *)gesture;
- (void)layoutSubviews;
- (void)centerMenu;
@end

@interface _0x953DA13 : UIView
- (instancetype)initWithFrame:(CGRect)frame;
@end
