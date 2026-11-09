// IntegrityChecker.h
#import <Foundation/Foundation.h>

@interface AntiHook : NSObject

// Kiểm tra file thực thi còn nguyên vẹn không (chưa bị hex edit)
+ (void)runDefaultChecksWithCallback:(void (^)(NSString *))onHookDetected;
+ (void *)originalImplementationForFunction:(void *)functionAddr;


@end