#pragma once
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// A selector is interned by the runtime, so its address is shared even when
// this header is compiled into two separately loaded copies of the dylib.
static inline const void *MizzeOverlayOwnershipKey() {
    return (const void *)sel_registerName("com.mizze.injectedOverlay.owner.v1");
}

static inline id MizzeOverlayOwner(id host) {
    return objc_getAssociatedObject(host, MizzeOverlayOwnershipKey());
}

// All ownership changes run on the main queue, including startup retries.
static inline BOOL MizzeClaimOverlay(id host, id owner) {
    NSCAssert(NSThread.isMainThread, @"Overlay ownership requires the main thread");
    if (!host || !owner || MizzeOverlayOwner(host)) return NO;
    objc_setAssociatedObject(host, MizzeOverlayOwnershipKey(), owner, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static inline void MizzeReleaseOverlay(id host, id owner) {
    NSCAssert(NSThread.isMainThread, @"Overlay ownership requires the main thread");
    if (owner && MizzeOverlayOwner(host) == owner) {
        objc_setAssociatedObject(host, MizzeOverlayOwnershipKey(), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
