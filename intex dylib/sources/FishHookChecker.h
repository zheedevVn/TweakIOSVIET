//
//  FishHookChecker.h
//  AntiFishHook (ObjC)
//
//  Converted from Swift by assistant.
//  Original: https://github.com/TannerJin/anti-fishhook
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface _0x2828DAB : NSObject

/**
 Call this to prevent fishhook on the given symbol.
 It walks all loaded images and restores the original symbol address.
 */
+ (void)_0x2828DAA:(NSString *)symbol;

@end

NS_ASSUME_NONNULL_END