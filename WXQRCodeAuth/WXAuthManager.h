//
//  WXAuthManager.h
//  WXQRCodeAuth
//
//  微信授权中转核心：接管 weixin:// 跳转 -> 拉取微信扫码登录二维码 ->
//  长轮询扫码状态 -> 授权成功后把 code 回跳给来源 App（如百度）。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WXAuthState) {
    WXAuthStateIdle = 0,        // 空闲，等待外部跳转
    WXAuthStateReceived,        // 已收到授权跳转，等待用户点“显码”
    WXAuthStateFetching,        // 正在向微信服务器请求二维码
    WXAuthStateWaitingScan,     // 二维码已显示，等待扫码
    WXAuthStateScanned,         // 已扫码，等待手机端确认
    WXAuthStateSuccess,         // 授权成功，正在跳回来源 App
    WXAuthStateCancelled,       // 用户取消授权
    WXAuthStateExpired,         // 二维码过期，需重新获取
    WXAuthStateError,           // 出错
};

@interface WXAuthManager : NSObject

@property (nonatomic, assign, readonly) WXAuthState state;
@property (nonatomic, copy, readonly, nullable) NSString *appid;
@property (nonatomic, copy, readonly, nullable) NSString *stateParam;
@property (nonatomic, copy, readonly, nullable) NSString *scope;
@property (nonatomic, copy, readonly, nullable) NSString *bundleId;
@property (nonatomic, copy, readonly, nullable) NSString *appName;
@property (nonatomic, copy, readonly, nullable) NSString *rawURLString;
@property (nonatomic, strong, readonly, nullable) UIImage *qrImage;
/// 最近一次授权码（调试可见）
@property (nonatomic, copy, readonly, nullable) NSString *lastAuthCode;
/// 最终回跳给来源 App 的 URL（调试可见）
@property (nonatomic, copy, readonly, nullable) NSString *lastCallbackURL;

/// 状态变化回调（主线程）
@property (nonatomic, copy, nullable) void (^onStateChange)(WXAuthState state, NSString *message);
/// 二维码生成回调（主线程）
@property (nonatomic, copy, nullable) void (^onQRCodeReady)(UIImage *image);
/// 诊断日志更新回调（主线程）——临时排查用
@property (nonatomic, copy, nullable) void (^onDiagnostic)(NSString *text);

+ (instancetype)shared;

/// RootHide 越狱黑名单会通过容器内的 _TrollStore 标记识别并屏蔽本 App，
/// 导致第三方 App 无法通过 weixin:// 唤起本 App。
/// 执行标记改名并返回完整诊断报告（定位是否成功、失败原因）。
+ (NSString *)applyRootHideBypass;

/// 处理外部通过 URL Scheme 传入的微信授权请求
- (void)handleIncomingURL:(NSURL *)url sourceApplication:(nullable NSString *)sourceApplication;

/// 用户点击“显码”：请求二维码并开始轮询
- (void)startShowCode;

/// 重新获取二维码
- (void)refreshQRCode;

/// 停止轮询
- (void)stop;

@end

NS_ASSUME_NONNULL_END
