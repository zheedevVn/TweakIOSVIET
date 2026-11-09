// ProxyChecker.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface _0xPO34326 : NSObject

/**
 Checks whether the device is using an HTTP/HTTPS proxy.
 Optionally treats VPN connections as proxies.

 @param considerVPN YES to consider typical VPN interfaces (tap, tun, ppp, ipsec, utun) as proxy.
 @return YES if a proxy (or VPN, depending on `considerVPN`) is detected, NO otherwise.
 */
+ (BOOL)_0x4544DAN:(BOOL)_0x3873X;

@end

NS_ASSUME_NONNULL_END