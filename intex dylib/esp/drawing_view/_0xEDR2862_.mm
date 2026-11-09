#import "esp.h"
#import "ESPPrefs.h"
#include "OverlayGeometry.h"
#include "../Core/OverlayHealth.h"
#include "KabraxHide.h"
#include <algorithm>
#include <cmath>
#include <limits>

UIFont *VietnameseFontForLayer(CGFloat size) {
    return [UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
}

static bool ValidPosition(const Vector3 &v) {
    return std::isfinite(v.x) && std::isfinite(v.y) && std::isfinite(v.z) &&
           (v.x != 0 || v.y != 0 || v.z != 0);
}
static void AddLine(CGMutablePathRef path, CGPoint a, CGPoint b, float width, float height) {
    if (!path) return;
    double x0 = a.x, y0 = a.y, x1 = b.x, y1 = b.y;
    if (!OverlayGeometry::ClipSegment(x0, y0, x1, y1, width, height)) return;
    CGPathMoveToPoint(path, nullptr, x0, y0);
    CGPathAddLineToPoint(path, nullptr, x1, y1);
}
static void AddRoundedRect(CGMutablePathRef path, CGRect rect, CGFloat radius) {
    if (!path || !std::isfinite(rect.origin.x) || !std::isfinite(rect.origin.y) ||
        !std::isfinite(rect.size.width) || !std::isfinite(rect.size.height) ||
        rect.size.width <= 0 || rect.size.height <= 0) return;
    CGPathAddRoundedRect(path, nullptr, rect, radius, radius);
}

#include "WorldAxes.h"

void RenderXYZAxes(ESPGeometryBuffers *buffers, const Vector3 &origin,
                   const float *matrix, float width, float height) {
    if (!isLine || !buffers || !ValidPosition(origin)) return;
    const auto triad=WorldAxes::Project({origin.x,origin.y,origin.z},matrix,width,height);
    if (!triad.valid) return;
    if (buffers->snaplinePath) {
        const auto point=triad.axes[0].from;
        AddLine(buffers->snaplinePath,CGPointMake(width*.5,height*.08),CGPointMake(point.x,point.y),width,height);
        buffers->snaplineDirty=true;
    }
    CGMutablePathRef paths[]={buffers->axisXPath,buffers->axisYPath,buffers->axisZPath};
    bool *dirty[]={&buffers->axisXDirty,&buffers->axisYDirty,&buffers->axisZDirty};
    for (int i=0;i<3;++i) {
        const auto &axis=triad.axes[i];
        if (!paths[i] || !axis.valid) continue;
        const CGPoint a=CGPointMake(axis.from.x,axis.from.y),b=CGPointMake(axis.to.x,axis.to.y);
        AddLine(paths[i],a,b,width,height);
        const double dx=b.x-a.x,dy=b.y-a.y,len=std::hypot(dx,dy);
        if (len>8) {
            const double ux=dx/len,uy=dy/len;
            AddLine(paths[i],b,CGPointMake(b.x-ux*4+uy*2,b.y-uy*4-ux*2),width,height);
            AddLine(paths[i],b,CGPointMake(b.x-ux*4-uy*2,b.y-uy*4+ux*2),width,height);
        } else if (len<2) {
            CGPathAddEllipseInRect(paths[i],nullptr,CGRectMake(b.x-1.2,b.y-1.2,2.4,2.4));
        }
        *dirty[i]=true;
    }
}

static void AddSkeleton(ESPGeometryBuffers *buffers, uint64_t pawn,
                        const Vector3 &head, const Vector3 &hip, float *matrix,
                        float width, float height, float vpWidth, float vpHeight) {
    if (!isBone || !buffers->bonePath) return;
    // One bounded set of joint reads and one shared path for all players.
    // Reuse the existing per-frame transform cache; no per-joint UI layers.
    using Reader = uint64_t (*)(uint64_t);
    const Reader readers[] = {getLeftShoulder, getRightShoulder,
        getLeftElbow, getRightElbow, getLeftHand, getRightHand,
        getLeftAnkle, getRightAnkle, getLeftToeNode, getRightToeNode};
    Vector3 world[13] = {head, hip};
    Vector3 screen[13]{};
    bool valid[13]{};
    for (int i = 0; i < 10; ++i) world[i + 2] = getPositionExt(readers[i](pawn));
    // No verified neck/spine/knee nodes were supplied. Use the shoulder
    // midpoint for the torso and direct hip-to-ankle segments for the legs.
    for (int i = 0; i < 12; ++i)
        valid[i] = ValidPosition(world[i]) && Vector3::Distance(world[i], hip) <= 3.0f;
    if (valid[2] && valid[3]) {
        world[12] = (world[2] + world[3]) * 0.5f;
        valid[12] = true;
    }
    for (int i = 0; i < 13; ++i) {
        if (!valid[i]) continue;
        screen[i] = WorldToScreenLayer(world[i], matrix, vpWidth, vpHeight, width, height);
        valid[i] = ValidPosition(screen[i]) && screen[i].z > 0.001f;
    }
    const int edges[][2] = {{0,12}, {12,1}, {2,3}, {2,4}, {4,6},
        {3,5}, {5,7}, {1,8}, {1,9}, {8,10}, {9,11}};
    for (const auto &edge : edges) {
        const int a = edge[0], b = edge[1];
        if (!valid[a] || !valid[b]) continue;
        AddLine(buffers->bonePath, CGPointMake(screen[a].x, screen[a].y),
                CGPointMake(screen[b].x, screen[b].y), width, height);
        buffers->boneDirty = true;
    }
}

BOOL RenderFOVCirclePath(CGMutablePathRef path, float w, float h, BOOL enabled, float radius) {
    if (!path || !enabled || radius <= 0 || w <= 0 || h <= 0) return NO;
    CGPathAddEllipseInRect(path, nullptr, CGRectMake(w / 2 - radius, h / 2 - radius, radius * 2, radius * 2));
    return YES;
}

void _0x35572DA(ESPGeometryBuffers *buffers, ESPAddTextCallback textCallback,
               void *context, uint64_t pawn, int hp, float distance, const Vector3 &hip,
               bool knocked, bool bot, float *matrix,
               float width, float height, float vpWidth, float vpHeight) {
    if (!buffers || !matrix || !isVaildPtr(pawn) || hp <= 0 ||
        !std::isfinite(distance) || width <= 0 || height <= 0 ||
        (!isBox && !isBone && !isHeadRedDot && !isLine && !isHealth && !isDis && !isName)) return;

    const Vector3 head = getPositionExt(getHead(pawn));
    if (!ValidPosition(head) || !ValidPosition(hip)) return;
    auto project = [&](Vector3 v) {
        return WorldToScreenLayer(v, matrix, vpWidth, vpHeight, width, height);
    };
    const Vector3 headScreen = project(head);
    const bool headOnScreen  = ValidPosition(headScreen) && headScreen.z > 0.001f &&
                               headScreen.x >= 0 && headScreen.x <= width &&
                               headScreen.y >= 0 && headScreen.y <= height;

    // Phần còn lại chỉ vẽ khi đầu địch thực sự trong FOV
    if (!headOnScreen) return;

    AddSkeleton(buffers, pawn, head, hip, matrix, width, height, vpWidth, vpHeight);
    if (!isBox && !isHealth && !isDis && !isName) {
        if (isHeadRedDot && headOnScreen && buffers->boxKnockPath) {
            CGPathAddEllipseInRect(buffers->boxKnockPath, nullptr,
                CGRectMake(headScreen.x - 3, headScreen.y - 3, 6, 6));
            buffers->boxKnockDirty = true;
        }
        return;
    }
    const Vector3 left = getPositionExt(getLeftAnkle(pawn));
    const Vector3 right = getPositionExt(getRightAnkle(pawn));
    Vector3 feet = hip;
    feet.y -= 0.85f;
    if (ValidPosition(left) && ValidPosition(right)) feet = (left + right) * 0.5f;
    else if (ValidPosition(left)) feet = left;
    else if (ValidPosition(right)) feet = right;
    feet.y -= 0.08f;

    // Project all eight world-space corners, rather than offsetting a 2D rectangle.
    const float lowY = std::min(feet.y, head.y - 0.20f);
    const float highY = std::max(head.y + 0.18f, lowY + 0.35f);
    const float halfWidth = knocked ? 0.48f : 0.30f;
    const float halfDepth = knocked ? 0.48f : 0.23f;
    Vector3 corners[8];
    CGFloat minX = std::numeric_limits<CGFloat>::infinity();
    CGFloat minY = minX, maxX = -minX, maxY = -minX;
    if (!isBox3D) {
        // An upright screen-space box is stable while rotating the camera and
        // needs two projections instead of eight world-space corner projections.
        Vector3 top = head; top.y += 0.14f;
        const Vector3 topScreen = project(top), feetScreen = project(feet);
        if (!ValidPosition(topScreen) || !ValidPosition(feetScreen) ||
            topScreen.z <= 0.001f || feetScreen.z <= 0.001f) return;
        minY = std::min(topScreen.y, feetScreen.y);
        maxY = std::max(topScreen.y, feetScreen.y);
        const CGFloat half = (maxY - minY) * (knocked ? 0.4f : 0.23f);
        const CGFloat center = (topScreen.x + feetScreen.x) * 0.5f;
        minX = center - half; maxX = center + half;
    } else for (int i = 0; i < 8; ++i) {
        Vector3 world(hip.x + ((i & 1) ? halfWidth : -halfWidth),
                      (i & 2) ? highY : lowY,
                      hip.z + ((i & 4) ? halfDepth : -halfDepth));
        corners[i] = project(world);
        if (!ValidPosition(corners[i]) || corners[i].z <= 0.001f) return;
        minX = std::min(minX, (CGFloat)corners[i].x);
        minY = std::min(minY, (CGFloat)corners[i].y);
        maxX = std::max(maxX, (CGFloat)corners[i].x);
        maxY = std::max(maxY, (CGFloat)corners[i].y);
    }
    if (maxX < 0 || minX > width || maxY < 0 || minY > height) return;
    const CGFloat boxHeight = maxY - minY;
    const CGFloat boxWidth = maxX - minX;
    if (!std::isfinite(boxHeight) || !std::isfinite(boxWidth) ||
        boxHeight < 2 || boxHeight > height * 3 || boxWidth < 1 || boxWidth > width * 3) return;

    // Render Player Name above head
    if (isName && textCallback) {
        NSString *nick = GetNickName(pawn);
        if (!nick || nick.length == 0) {
            nick = bot ? @"[BOT]" : @"Player";
        }
        UIColor *nameColor = knocked ? [UIColor colorWithRed:0.9 green:0.55 blue:0.55 alpha:0.85]
                                      : [UIColor colorWithRed:0.84 green:0.91 blue:0.88 alpha:0.9];
        if (nick.length > 20) nick = [[nick substringToIndex:20] stringByAppendingString:@"…"];
        textCallback(context, nick, CGRectMake((minX + maxX) / 2.0f - 85.0f, minY - 23.0f, 170.0f, 19.0f),
                     nameColor, 12.5f, NO);
    }

    CGMutablePathRef boxPath = knocked ? buffers->boxKnockPath : (bot ? buffers->boxBotPath : buffers->boxPlayerPath);
    if (isBox && boxPath) {
        if (isBox3D) {
            for (int i = 0; i < 8; ++i) {
                for (int bit = 1; bit <= 4; bit <<= 1) {
                    if (i & bit) continue;
                    const Vector3 a = corners[i], b = corners[i | bit];
                    AddLine(boxPath, CGPointMake(a.x, a.y), CGPointMake(b.x, b.y), width, height);
                }
            }
        } else if (isCleanESP) {
            const CGFloat length = std::min(boxWidth * 0.25, boxHeight * 0.15);
            for (int edge = 0; edge < 4; ++edge) {
                const CGFloat x = (edge & 1) ? maxX : minX;
                const CGFloat y = (edge & 2) ? maxY : minY;
                const CGFloat sx = (edge & 1) ? -1 : 1, sy = (edge & 2) ? -1 : 1;
                AddLine(boxPath, CGPointMake(x, y + sy * length), CGPointMake(x, y), width, height);
                AddLine(boxPath, CGPointMake(x, y), CGPointMake(x + sx * length, y), width, height);
            }
        } else {
            AddRoundedRect(boxPath, CGRectMake(minX, minY, boxWidth, boxHeight),
                           std::min(3.0, (double)boxWidth * 0.08));
        }
        if (knocked) buffers->boxKnockDirty = true;
        else if (bot) buffers->boxBotDirty = true;
        else buffers->boxPlayerDirty = true;
    }
    if (isHeadRedDot && buffers->boxKnockPath) {
        const CGFloat radius = std::max(2.0, std::min(4.0, (double)boxHeight * 0.025));
        CGPathAddEllipseInRect(buffers->boxKnockPath, nullptr,
            CGRectMake(headScreen.x - radius, headScreen.y - radius, radius * 2, radius * 2));
        buffers->boxKnockDirty = true;
    }
    if (isHealth && buffers->hpBackgroundPath) {
        float ratio = 0;
        if (OverlayHealth::Snapshot(pawn, [](uint64_t a, void *p, size_t n) {
                return _read((long)a, p, static_cast<int>(n));
            }, [](uint64_t a) { return isVaildPtr(a); }, ratio)) {
            const CGFloat barX = minX - 7, barWidth = 3.5f;
            const CGFloat filled = boxHeight * ratio;
            auto addBar = [&](CGMutablePathRef path, CGRect rect) {
                if (!path) return false;
                rect = CGRectIntersection(rect, CGRectMake(0,0,width,height));
                if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) return false;
                CGPathAddRect(path, nullptr, rect);
                return true;
            };
            buffers->hpBackgroundDirty |= addBar(buffers->hpBackgroundPath,
                CGRectMake(barX - 1, minY - 1, barWidth + 2, boxHeight + 2));
            if (filled >= 0.5f) {
                const auto band = OverlayHealth::Band(ratio, ESPPrefsFloat(@"HealthRedPercent",25),
                    ESPPrefsFloat(@"HealthYellowPercent",50));
                CGMutablePathRef fill = band == OverlayHealth::Color::Mint ? buffers->hpFillPath :
                    (band == OverlayHealth::Color::Yellow ? buffers->hpWarningPath : buffers->hpCriticalPath);
                if (addBar(fill, CGRectMake(barX, maxY - filled, barWidth, filled))) {
                    if (band == OverlayHealth::Color::Mint) buffers->hpFillDirty = true;
                    else if (band == OverlayHealth::Color::Yellow) buffers->hpWarningDirty = true;
                    else buffers->hpCriticalDirty = true;
                }
            }
        }
    }
    if (isDis && textCallback) {
        static NSArray<NSString *> *labels;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSMutableArray<NSString *> *items = [NSMutableArray arrayWithCapacity:501];
            for (int meters = 0; meters <= 500; ++meters)
                [items addObject:[NSString stringWithFormat:@"%d m", meters]];
            labels = [items copy];
        });
        NSString *label = labels[std::max(0, std::min(500, (int)distance))];
        textCallback(context, label, CGRectMake((minX + maxX) / 2 - 32, maxY + 4, 64, 17),
                     [UIColor colorWithWhite:0.95 alpha:1], 11.5, NO);
    }
}
