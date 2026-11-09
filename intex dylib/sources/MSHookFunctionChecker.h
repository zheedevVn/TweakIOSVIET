// MSHookFunctionChecker.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSHookFunctionChecker : NSObject

/**
 Checks whether the function at `functionAddr` has been hooked by MSHookFunction
 (Cydia Substrate / Substitute style).

 @param functionAddr The address of the function to check.
 @return YES if the function appears to be hooked, NO otherwise.
 */
+ (BOOL)amIMSHooked:(void *)functionAddr;

/**
 Attempts to retrieve the original function address if it has been hooked
 by MSHookFunction. If not hooked, returns NULL.

 @param functionAddr The address of the (potentially hooked) function.
 @return The address of the original function, or NULL if not hooked or the
         original address could not be located.
 */
+ (void * _Nullable)denyMSHook:(void *)functionAddr;

@end

NS_ASSUME_NONNULL_END
