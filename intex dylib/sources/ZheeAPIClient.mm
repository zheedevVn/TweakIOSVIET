// ZheeAPIClient.mm — Key client thay thế cho libAPIClient.a.
// Kiểm tra key qua server https://jsonapivn.vercel.app/check (key ZK_).
// Giữ nguyên toàn bộ giao diện C trong APIClient.h để các file khác không phải sửa.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#include <Block.h>
#include "APIClient.h"

#define ZKC_VIS __attribute__((visibility("default")))

static NSString *const kZKServer = @"https://jsonapivn.vercel.app";
static NSString *const kZKKeyDefaults = @"ZheeAPIClient.Key";

static apiclient_callback sPaidCallback = nil;
static BOOL sPaidFired = NO;
static BOOL sFlowStarted = NO;
static NSDictionary *sLastCheck = nil;
static NSString *sDescription = nil;
static NSString *sContactTitle = nil;

// ---------- helpers ----------

static NSString *ZKString(id v) {
    if (!v || v == [NSNull null]) return @"";
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    return [v description];
}

static NSString *ZKPick(NSDictionary *d, NSArray<NSString *> *keys) {
    for (NSString *k in keys) {
        NSString *s = ZKString(d[k]);
        if (s.length) return s;
    }
    return @"";
}

static const char *ZKBuffer(NSString *s) {
    static char buf[1024];
    memset(buf, 0, sizeof(buf));
    if (s) strncpy(buf, s.UTF8String ?: "", sizeof(buf) - 1);
    return buf;
}

static NSString *ZKSavedKey(void) {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kZKKeyDefaults] ?: @"";
}

static NSString *ZKDeviceId(void) {
    NSString *u = [UIDevice currentDevice].identifierForVendor.UUIDString;
    return u ?: @"";
}

static void ZKFirePaid(void) {
    if (sPaidFired || !sPaidCallback) return;
    sPaidFired = YES;
    apiclient_callback cb = sPaidCallback;
    dispatch_async(dispatch_get_main_queue(), ^{ cb(); });
}

// GET {server}/check?key=... -> parsed JSON dict (nil on network/parse error)
static void ZKCheckKey(NSString *key, void (^done)(NSDictionary *json)) {
    NSString *q = [key stringByAddingPercentEncodingWithAllowedCharacters:
                   [NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/check?key=%@", kZKServer, q ?: @""]];
    if (!url) { done(nil); return; }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"GET";
    req.timeoutInterval = 15;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSDictionary *json = nil;
            if (data && !err) {
                id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([obj isKindOfClass:[NSDictionary class]]) json = obj;
            }
            dispatch_async(dispatch_get_main_queue(), ^{ done(json); });
        }];
    [task resume];
}

static BOOL ZKIsValid(NSDictionary *json) {
    return [json[@"valid"] respondsToSelector:@selector(boolValue)] && [json[@"valid"] boolValue];
}

// ---------- Cửa sổ riêng cho popup key ----------
// Không mượn cửa sổ của app chủ: tự dựng UIWindow đè lên trên cùng (kiểu cửa sổ
// cảnh báo), bám theo scene đang active. Cách này hiện được cả trong game lẫn
// app thường, kể cả khi app chủ chưa có key window hoặc đang bận trình diễn.

static UIWindow *sKeyWindow = nil;
static int sSceneRetries = 0;

static UIWindowScene *ZKActiveScene(void) {
    NSSet *scenes = [UIApplication sharedApplication].connectedScenes;
    for (UIScene *s in scenes) {
        if (s.activationState == UISceneActivationStateForegroundActive &&
            [s isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)s;
        }
    }
    for (UIScene *s in scenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)s;
    }
    return nil;
}

static void ZKHideKeyWindow(void) {
    if (!sKeyWindow) return;
    sKeyWindow.hidden = YES;
    sKeyWindow = nil;
}

static void ZKWithKeyRoot(void (^block)(UIViewController *root)) {
    if (sKeyWindow) { block(sKeyWindow.rootViewController); return; }
    UIWindowScene *scene = ZKActiveScene();
    if (!scene && [UIApplication sharedApplication].windows.count == 0 && sSceneRetries < 60) {
        sSceneRetries++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ ZKWithKeyRoot(block); });
        return;
    }
    UIWindow *w = scene ? [[UIWindow alloc] initWithWindowScene:scene]
                        : [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor clearColor];
    w.rootViewController = root;
    w.backgroundColor = [UIColor clearColor];
    w.windowLevel = UIWindowLevelAlert + 50;
    sKeyWindow = w;
    [w makeKeyAndVisible];
    block(root);
}

static void ZKShowKeyPrompt(NSString *note);

static void ZKPresentKeyAlert(UIViewController *root, NSString *note) {
    NSString *msg = note.length ? note
        : (sDescription.length ? sDescription : @"Nhập key bản quyền để tiếp tục");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Kích hoạt Key"
        message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"ZK_...";
        tf.text = ZKSavedKey();
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    __weak UIAlertController *weakAlert = alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Kích hoạt" style:UIAlertActionStyleDefault
        handler:^(__unused UIAlertAction *a) {
            NSString *key = [weakAlert.textFields.firstObject.text
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!key.length) { ZKShowKeyPrompt(@"Chưa nhập key"); return; }
            ZKCheckKey(key, ^(NSDictionary *json) {
                if (!json) { ZKShowKeyPrompt(@"Không kết nối được server — kiểm tra mạng rồi thử lại"); return; }
                if (ZKIsValid(json)) {
                    sLastCheck = json;
                    [[NSUserDefaults standardUserDefaults] setObject:key forKey:kZKKeyDefaults];
                    [root dismissViewControllerAnimated:YES completion:^{
                        ZKHideKeyWindow();
                        ZKFirePaid();
                    }];
                } else {
                    NSString *m = ZKString(json[@"message"]);
                    ZKShowKeyPrompt(m.length ? m : @"Key không hợp lệ");
                }
            });
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel
        handler:^(__unused UIAlertAction *a) { ZKHideKeyWindow(); }]];
    [root presentViewController:alert animated:YES completion:nil];
}

static void ZKShowKeyPrompt(NSString *note) {
    ZKWithKeyRoot(^(UIViewController *root) {
        if (root.presentedViewController) {
            [root dismissViewControllerAnimated:NO completion:nil];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ ZKPresentKeyAlert(root, note); });
        } else {
            ZKPresentKeyAlert(root, note);
        }
    });
}

static void ZKStartFlow(void) {
    if (sFlowStarted) return;
    sFlowStarted = YES;
    NSString *saved = ZKSavedKey();
    if (!saved.length) { ZKShowKeyPrompt(nil); return; }
    ZKCheckKey(saved, ^(NSDictionary *json) {
        if (json && ZKIsValid(json)) {
            sLastCheck = json;
            ZKFirePaid();
        } else { // key hết hạn / bị xoá — bắt nhập lại
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kZKKeyDefaults];
            NSString *m = json ? ZKString(json[@"message"]) : nil;
            ZKShowKeyPrompt(m.length ? m : nil);
        }
    });
}

// ---------- APIClient.h implementation ----------

extern "C" {

ZKC_VIS void apiclient_set_token(const char *token) { (void)token; } // token cũ của tác giả gốc — không dùng nữa
ZKC_VIS void apiclient_set_udid(const char *udid) { (void)udid; }
ZKC_VIS void apiclient_set_language(const char *language) { (void)language; }
ZKC_VIS void apiclient_set_contact_button_title(const char *title) {
    sContactTitle = title ? @(title) : nil; (void)sContactTitle;
}
ZKC_VIS void apiclient_set_description(const char *description) {
    sDescription = description ? @(description) : nil;
}
ZKC_VIS void apiclient_hide_ui(bool isHide) { (void)isHide; }
ZKC_VIS void apiclient_strict_mode(bool isStrictMode) { (void)isStrictMode; }
ZKC_VIS void apiclient_silent_mode(bool isSilentMode) { (void)isSilentMode; }
ZKC_VIS void apiclient_show_udid_guide(bool showGuide) { (void)showGuide; }
ZKC_VIS void apiclient_set_window_mode(int mode) { (void)mode; }

ZKC_VIS void apiclient_paid(apiclient_callback callback) {
    if (callback) {
        sPaidCallback = [callback copy];
    }
    dispatch_async(dispatch_get_main_queue(), ^{ ZKStartFlow(); });
}

ZKC_VIS const char *apiclient_request_udid(void) { return ZKBuffer(ZKDeviceId()); }
ZKC_VIS const char *apiclient_get_key(void) { return ZKBuffer(ZKSavedKey()); }
ZKC_VIS const char *apiclient_get_udid(void) { return ZKBuffer(ZKDeviceId()); }
ZKC_VIS const char *apiclient_get_expired_at(void) {
    return ZKBuffer(ZKPick(sLastCheck, @[@"expires_at", @"expired_at", @"expiry", @"expiresAt", @"end_date", @"expiry_date"]));
}
ZKC_VIS const char *apiclient_get_expired_at_local(void) { return apiclient_get_expired_at(); }
ZKC_VIS const char *apiclient_get_activated_at(void) {
    return ZKBuffer(ZKPick(sLastCheck, @[@"activated_at", @"created_at", @"start_date", @"activatedAt"]));
}
ZKC_VIS const char *apiclient_get_activated_at_local(void) { return apiclient_get_activated_at(); }
ZKC_VIS const char *apiclient_get_device_model(void) {
    struct utsname u; uname(&u);
    return ZKBuffer([NSString stringWithUTF8String:u.machine]);
}
ZKC_VIS const char *apiclient_get_login_ip(void) { return ZKBuffer(@""); }
ZKC_VIS const char *apiclient_get_package_name(void) {
    return ZKBuffer(ZKPick(sLastCheck, @[@"package_name", @"name", @"package"]));
}
ZKC_VIS const char *apiclient_get_package_data(const char *key) {
    if (!key) return ZKBuffer(@"");
    return ZKBuffer(ZKString(sLastCheck[@(key)]));
}

static void ZKRunCheck(NSString *key, apiclient_dict_callback success, apiclient_dict_callback failure) {
    ZKCheckKey(key, ^(NSDictionary *json) {
        NSData *raw = json ? [NSJSONSerialization dataWithJSONObject:json options:0 error:nil] : nil;
        NSString *text = raw ? [[NSString alloc] initWithData:raw encoding:NSUTF8StringEncoding] : @"";
        if (json && ZKIsValid(json)) {
            sLastCheck = json;
            if (success) success(text.UTF8String ?: "");
        } else if (failure) {
            failure(text.UTF8String ?: "");
        }
    });
}

ZKC_VIS void apiclient_on_check_package(apiclient_dict_callback success, apiclient_dict_callback failure) {
    ZKRunCheck(ZKSavedKey(), success, failure);
}
ZKC_VIS void apiclient_on_check_device(apiclient_dict_callback success, apiclient_dict_callback failure) {
    ZKRunCheck(ZKSavedKey(), success, failure);
}
ZKC_VIS void apiclient_on_login(const char *inputKey, apiclient_dict_callback success, apiclient_dict_callback failure) {
    NSString *key = inputKey ? @(inputKey) : @"";
    ZKCheckKey(key, ^(NSDictionary *json) {
        NSData *raw = json ? [NSJSONSerialization dataWithJSONObject:json options:0 error:nil] : nil;
        NSString *text = raw ? [[NSString alloc] initWithData:raw encoding:NSUTF8StringEncoding] : @"";
        if (json && ZKIsValid(json)) {
            sLastCheck = json;
            [[NSUserDefaults standardUserDefaults] setObject:key forKey:kZKKeyDefaults];
            ZKFirePaid();
            if (success) success(text.UTF8String ?: "");
        } else if (failure) {
            failure(text.UTF8String ?: "");
        }
    });
}

} // extern "C"
