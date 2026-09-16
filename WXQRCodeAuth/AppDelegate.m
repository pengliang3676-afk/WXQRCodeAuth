//
//  AppDelegate.m
//  WXQRCodeAuth
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "WXAuthManager.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    ViewController *vc = [[ViewController alloc] init];
    // 极简单页，直接用 ViewController 作为根，不显示导航栏
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];

    // 冷启动时由 URL 拉起
    NSURL *url = launchOptions[UIApplicationLaunchOptionsURLKey];
    NSString *sourceApp = launchOptions[UIApplicationLaunchOptionsSourceApplicationKey];
    if (url) {
        // 延迟一点，等主界面就绪
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[WXAuthManager shared] handleIncomingURL:url sourceApplication:sourceApp];
        });
    }
    return YES;
}

// iOS 9+ URL Scheme 回调（前台/后台被拉起时走这里）
- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    NSString *sourceApp = options[UIApplicationOpenURLOptionsSourceApplicationKey];
    [[WXAuthManager shared] handleIncomingURL:url sourceApplication:sourceApp];
    return YES;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    [[WXAuthManager shared] handleIncomingURL:url sourceApplication:sourceApplication];
    return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    [[WXAuthManager shared] handleIncomingURL:url sourceApplication:nil];
    return YES;
}

@end
