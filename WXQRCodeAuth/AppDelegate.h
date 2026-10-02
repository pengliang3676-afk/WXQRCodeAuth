//
//  AppDelegate.h
//  WXQRCodeAuth
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;

/// RootHide 绕过诊断报告（诊断版用）
+ (NSString *)bypassReport;
@end
