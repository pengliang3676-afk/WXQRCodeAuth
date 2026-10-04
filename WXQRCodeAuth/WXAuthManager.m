//
//  WXAuthManager.m
//  WXQRCodeAuth
//

#import "WXAuthManager.h"

// 伪装成微信客户端的 User-Agent（app/qrconnect 内部接口要求）
static NSString *const kWXUserAgent =
    @"Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) "
    @"AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 "
    @"MicroMessenger/7.0.0(0x17000024) NetType/WIFI Language/zh_CN";

static NSString *const kQrConnectFormat =
    @"https://open.weixin.qq.com/connect/app/qrconnect?appid=%@&bundleid=%@&scope=%@";
static NSString *const kLongPollFormat =
    @"https://long.open.weixin.qq.com/connect/l/qrconnect?uuid=%@&f=url&_=%.0f";
static NSString *const kConfirmFormat =
    @"https://open.weixin.qq.com/connect/confirm?uuid=%@";

@interface WXAuthManager ()
@property (nonatomic, assign) WXAuthState state;
@property (nonatomic, copy, nullable) NSString *appid;
@property (nonatomic, copy, nullable) NSString *stateParam;
@property (nonatomic, copy, nullable) NSString *scope;
@property (nonatomic, copy, nullable) NSString *bundleId;
@property (nonatomic, copy, nullable) NSString *appName;
@property (nonatomic, copy, nullable) NSString *rawURLString;
@property (nonatomic, strong, nullable) UIImage *qrImage;
@property (nonatomic, copy, nullable) NSString *lastAuthCode;
@property (nonatomic, copy, nullable) NSString *lastCallbackURL;
@property (nonatomic, strong) NSMutableString *diagLog;

@property (nonatomic, copy, nullable) NSString *serverUuid;   // 微信服务器下发的二维码 uuid
@property (nonatomic, copy, nullable) NSString *clientUuid;   // 本地生成、放在请求头的 uuid
@property (nonatomic, strong, nullable) NSURLSession *session;
@property (nonatomic, strong, nullable) NSURLSessionDataTask *pollTask;
@property (nonatomic, assign) BOOL polling;
@property (nonatomic, assign) BOOL finished;
@end

@implementation WXAuthManager

+ (instancetype)shared {
    static WXAuthManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WXAuthManager alloc] initPrivate];
    });
    return instance;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _state = WXAuthStateIdle;
        _diagLog = [NSMutableString string];
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 70;
        cfg.HTTPAdditionalHeaders = @{ @"User-Agent": kWXUserAgent };
        _session = [NSURLSession sessionWithConfiguration:cfg];
    }
    return self;
}

- (void)log:(NSString *)format, ... {
    va_list args; va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[WXQR] %@", line);
}

#pragma mark - 外部 URL 入口

- (void)handleIncomingURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
    if (!url) return;
    NSString *absolute = url.absoluteString ?: @"";
    self.rawURLString = absolute;

    // 1) 标准 query 解析
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSURLComponents *comp = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in comp.queryItems) {
        if (item.name && item.value) params[item.name] = item.value;
    }

    // 同时准备一份 percent-decode 后的全文，兜底扫描被编码的参数
    NSString *decoded = [absolute stringByRemovingPercentEncoding] ?: absolute;

    // 2) appid：优先 query 参数，兜底从整条 URL（含 path/resourceSpecifier、解码后）正则提取
    NSString *appid = params[@"appid"];
    if (appid.length == 0) {
        appid = [self firstMatchIn:absolute pattern:@"wx[a-fA-F0-9]{16,18}" group:0];
    }
    if (appid.length == 0) {
        appid = [self firstMatchIn:decoded pattern:@"wx[a-fA-F0-9]{16,18}" group:0];
    }

    // 3) state：优先 query，兜底从全文正则提取 state=xxx
    NSString *stateParam = params[@"state"];
    if (stateParam.length == 0) {
        stateParam = [self firstMatchIn:absolute pattern:@"[?&]state=([^&]+)" group:1];
    }
    if (stateParam.length == 0) {
        stateParam = [self firstMatchIn:decoded pattern:@"[?&]state=([^&]+)" group:1];
    }
    stateParam = stateParam ?: @"";

    // 4) bundleid：优先来源 App 的 Bundle ID，其次 URL 参数
    NSString *bundleId = sourceApplication.length
        ? sourceApplication
        : (params[@"bundleid"] ?: params[@"bundleId"] ?:
           [self firstMatchIn:decoded pattern:@"wechat_app_bundleId=([^&]+)" group:1] ?: @"");

    // 5) scope：优先来源 URL 自带，默认 snsapi_userinfo（必须与来源 App 请求一致）
    NSString *scope = params[@"scope"];
    if (scope.length == 0) {
        scope = [self firstMatchIn:decoded pattern:@"[?&]scope=([^&]+)" group:1];
    }
    if (scope.length == 0) scope = @"snsapi_userinfo";

    if (appid.length == 0) {
        [self log:@"❌ 解析失败，原始 URL：%@", absolute];
        [self updateState:WXAuthStateError message:@"未能从跳转链接中解析出 appid"];
        return;
    }

    [self stop];
    @synchronized (self.diagLog) { [self.diagLog setString:@""]; }
    self.appid = appid;
    self.stateParam = stateParam;
    self.scope = scope;
    self.bundleId = bundleId;
    self.serverUuid = nil;
    self.qrImage = nil;
    self.lastAuthCode = nil;
    self.lastCallbackURL = nil;
    self.finished = NO;

    [self log:@"收到跳转：%@", absolute];
    [self log:@"解析 → appid=%@", appid];
    [self log:@"        state=%@", stateParam.length ? stateParam : @"(空)"];
    [self log:@"        scope=%@", scope];
    [self log:@"        bundleid=%@", bundleId.length ? bundleId : @"(空,将留空)"];
    [self log:@"        sourceApp=%@", sourceApplication ?: @"(空)"];

    [self updateState:WXAuthStateReceived
              message:[NSString stringWithFormat:@"已接收授权请求\n%@", bundleId.length ? bundleId : appid]];
}

#pragma mark - 显码

- (void)startShowCode {
    if (self.appid.length == 0) {
        [self updateState:WXAuthStateIdle message:@"还没有授权请求，请先从百度发起微信提现"];
        return;
    }
    [self fetchQRCode];
}

- (void)refreshQRCode {
    if (self.appid.length == 0) return;
    [self stop];
    self.finished = NO;
    [self fetchQRCode];
}

- (void)fetchQRCode {
    [self updateState:WXAuthStateFetching message:@"正在获取二维码…"];

    self.clientUuid = [self randomClientUuid];
    NSString *bundleid = self.bundleId.length ? self.bundleId : @"";
    NSString *scope = self.scope.length ? self.scope : @"snsapi_userinfo";
    NSString *path = [NSString stringWithFormat:kQrConnectFormat,
                      [self urlEncode:self.appid],
                      [self urlEncode:bundleid],
                      [self urlEncode:scope]];
    [self log:@"请求 qrconnect（scope=%@, bundleid=%@）", scope, bundleid.length?bundleid:@"(空)"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
    req.HTTPMethod = @"GET";
    [req setValue:kWXUserAgent forHTTPHeaderField:@"User-Agent"];
    [req setValue:[NSString stringWithFormat:@"\"%@\"", self.clientUuid] forHTTPHeaderField:@"uuid"];
    [req setValue:self.appid forHTTPHeaderField:@"appid"];
    [req setValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
    [req setValue:@"zh-cn" forHTTPHeaderField:@"Accept-Language"];
    req.timeoutInterval = 20;

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSInteger httpCode = [(NSHTTPURLResponse *)response statusCode];
        if (error || data.length == 0) {
            [self log:@"❌ qrconnect 网络错误 HTTP=%ld：%@", (long)httpCode, error.localizedDescription ?: @"无数据"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateState:WXAuthStateError message:[NSString stringWithFormat:@"获取二维码失败：%@", error.localizedDescription ?: @"无数据"]];
            });
            return;
        }
        [self log:@"qrconnect HTTP=%ld，%ld 字节", (long)httpCode, (long)data.length];
        // 微信页面是 utf-8
        NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!html) html = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];

        NSString *uuid = [self firstMatchIn:html pattern:@"uuid:\\s*\"([^\"]+)\"" group:1];
        NSString *name = [self firstMatchIn:html pattern:@"auth_nickname\">([\\s\\S]*?)</strong>" group:1];
        name = [name stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@" "];
        name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (uuid.length == 0) {
            [self log:@"❌ 未取到 uuid，HTML 前 500 字：%@", [html substringToIndex:MIN(500, html.length)]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateState:WXAuthStateError message:@"二维码解析失败（未取到 uuid）"];
            });
            return;
        }

        self.serverUuid = uuid;
        if (name.length) self.appName = name;
        [self log:@"✅ 服务器 uuid=%@ 应用名=%@", uuid, name ?: @"(无)"];

        // 二维码内容 = confirm?uuid=xxx（已通过解码服务器二维码图片验证）
        NSString *qrContent = [NSString stringWithFormat:kConfirmFormat, uuid];
        [self log:@"二维码内容：%@", qrContent];
        UIImage *qr = [self generateQRCode:qrContent];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.qrImage = qr;
            if (self.onQRCodeReady) self.onQRCodeReady(qr);
            [self updateState:WXAuthStateWaitingScan message:@"请用另一台手机的微信扫码授权"];
            [self startPolling];
        });
    }];
    [task resume];
}

#pragma mark - 长轮询

- (void)startPolling {
    self.polling = YES;
    self.finished = NO;
    [self pollOnce];
}

- (void)pollOnce {
    if (!self.polling || self.finished || self.serverUuid.length == 0) return;

    NSString *path = [NSString stringWithFormat:kLongPollFormat,
                      self.serverUuid,
                      [[NSDate date] timeIntervalSince1970] * 1000.0];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:path]];
    [req setValue:kWXUserAgent forHTTPHeaderField:@"User-Agent"];
    req.timeoutInterval = 70;

    __weak typeof(self) weakSelf = self;
    self.pollTask = [self.session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || !self.polling || self.finished) return;

        if (error) {
            [self log:@"轮询请求错误（2s 后重试）：%@", error.localizedDescription];
            // 超时/网络抖动，稍后继续
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self pollOnce];
            });
            return;
        }

        NSString *js = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        NSString *codeStr = [self firstMatchIn:js pattern:@"wx_errcode=(\\d+)" group:1];
        NSString *redirect = [self firstMatchIn:js pattern:@"wx_redirecturl='([^']*)'" group:1];
        NSString *nickname = [self firstMatchIn:js pattern:@"wx_nickname='([^']*)'" group:1];
        int errcode = codeStr.intValue;

        if (errcode != 408) {
            [self log:@"轮询返回 errcode=%d，原始：%@", errcode,
             [js length] ? [js stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"(空)"];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            switch (errcode) {
                case 405: {
                    // 授权成功：从 wx_redirecturl 解析 code，再用标准格式自行拼接回跳，保证 state 正确
                    self.finished = YES;
                    self.polling = NO;
                    [self updateState:WXAuthStateSuccess
                              message:[NSString stringWithFormat:@"%@授权成功，正在跳回…",
                                       nickname.length ? [nickname stringByAppendingString:@" "] : @""]];

                    // 从微信回传 redirect 中解析 code 与 state（两者由服务器配对生成）
                    NSString *code = @"";
                    NSString *stateBack = @"";
                    if (redirect.length) {
                        NSURLComponents *rc = [NSURLComponents componentsWithString:redirect];
                        for (NSURLQueryItem *it in rc.queryItems) {
                            if ([it.name isEqualToString:@"code"] && it.value.length && !code.length) code = it.value;
                            if ([it.name isEqualToString:@"state"] && it.value.length && !stateBack.length) stateBack = it.value;
                        }
                    }
                    // state 优先用微信回传的（与 code 配对），其次用来源 App 传入的
                    NSString *finalState = stateBack.length ? stateBack : (self.stateParam ?: @"");
                    self.lastAuthCode = code;
                    [self log:@"✅ 405 微信原始 redirect=%@", redirect.length ? redirect : @"(空)"];
                    [self log:@"解析 code=%@", code.length ? code : @"(空！)"];
                    [self log:@"state：微信回传=%@ / 来源传入=%@", stateBack.length?stateBack:@"(无)", self.stateParam.length?self.stateParam:@"(无)"];

                    NSString *target = nil;
                    if (code.length) {
                        // 标准微信 SDK 回调：wxAPPID://oauth?code=CODE&state=STATE
                        target = [NSString stringWithFormat:@"%@://oauth?code=%@&state=%@",
                                  self.appid, code, [self urlEncode:finalState]];
                    } else if (redirect.length) {
                        // 解析不到 code 时，原样回跳兜底
                        target = redirect;
                    } else {
                        target = [NSString stringWithFormat:@"%@://oauth?code=&state=%@",
                                  self.appid, [self urlEncode:finalState]];
                    }
                    self.lastCallbackURL = target;
                    [self log:@"回跳 URL：%@", target];
                    [self openURLString:target];
                    break;
                }
                case 404:
                    // 已扫码，等待手机端确认
                    [self log:@"⏳ 404 已扫码，等待手机确认"];
                    [self updateState:WXAuthStateScanned message:@"已扫码，请在手机微信上点击确认"];
                    [self scheduleNextPoll:1.0];
                    break;
                case 403:
                    // 用户取消
                    self.finished = YES;
                    self.polling = NO;
                    [self log:@"用户取消（403）"];
                    [self updateState:WXAuthStateCancelled message:@"已取消授权"];
                    [self openURLString:[NSString stringWithFormat:@"%@://oauth?code=", self.appid]];
                    break;
                case 402:
                case 500:
                    // 二维码过期 / 服务错误，自动重新获取
                    self.polling = NO;
                    [self updateState:WXAuthStateExpired message:@"二维码已过期，正在重新获取…"];
                    [self refreshQRCode];
                    break;
                case 408:
                default:
                    // 超时，继续轮询
                    [self scheduleNextPoll:1.0];
                    break;
            }
        });
    }];
    [self.pollTask resume];
}

- (void)scheduleNextPoll:(NSTimeInterval)delay {
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [weakSelf pollOnce];
    });
}

#pragma mark - 回跳来源 App

- (void)openURLString:(NSString *)urlString {
    if (urlString.length == 0) return;
    // wx_redirecturl 由服务端给出，本身就是可直接打开的明文 URL（state 已在内部编码）。
    // 切勿整体 percent-decode，否则会破坏 state/code 中的编码字符。
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        // 仅在明文构造失败时，尝试编码后重试一次
        NSString *encoded = [urlString stringByAddingPercentEncodingWithAllowedCharacters:
                             [NSCharacterSet URLFragmentAllowedCharacterSet]];
        url = [NSURL URLWithString:encoded];
    }
    if (!url) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplication *app = [UIApplication sharedApplication];
        // 回调 scheme 是动态的（wx+appid://），无法全部加入 canOpenURL 白名单，
        // 因此直接 openURL，由 completionHandler 反馈结果。
        [app openURL:url options:@{} completionHandler:^(BOOL success) {
            [self log:success ? @"✅ 已 openURL 跳回来源 App" : @"❌ openURL 失败（来源 App 未安装/未注册该 scheme）"];
            if (!success) {
                [self updateState:WXAuthStateError message:@"无法跳回来源 App（未安装？）"];
            }
        }];
    });
}

#pragma mark - 二维码生成

- (UIImage *)generateQRCode:(NSString *)content {
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setValue:data forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *ciImage = filter.outputImage;

    // 放大到清晰尺寸
    CGFloat scale = 10.0;
    CIImage *scaled = [ciImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:scaled fromRect:scaled.extent];
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return image;
}

#pragma mark - 工具

- (void)stop {
    self.polling = NO;
    [self.pollTask cancel];
    self.pollTask = nil;
}

- (void)updateState:(WXAuthState)state message:(NSString *)message {
    self.state = state;
    if (self.onStateChange) {
        void (^cb)(WXAuthState, NSString *) = self.onStateChange;
        if ([NSThread isMainThread]) {
            cb(state, message);
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{ cb(state, message); });
        }
    }
}

- (NSString *)randomClientUuid {
    // 16 字节随机数的十六进制（32 字符），与微信客户端一致
    NSMutableString *s = [NSMutableString stringWithCapacity:32];
    for (int i = 0; i < 16; i++) {
        [s appendFormat:@"%02x", arc4random_uniform(256)];
    }
    return s;
}

- (NSString *)firstMatchIn:(NSString *)text pattern:(NSString *)pattern group:(NSInteger)group {
    if (text.length == 0) return @"";
    NSError *err = nil;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                        options:NSRegularExpressionDotMatchesLineSeparators
                                                                          error:&err];
    NSTextCheckingResult *m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (!m || m.numberOfRanges <= group) return @"";
    NSRange r = [m rangeAtIndex:group];
    if (r.location == NSNotFound) return @"";
    return [text substringWithRange:r];
}

- (NSString *)urlEncode:(NSString *)s {
    if (s.length == 0) return @"";
    NSMutableCharacterSet *set = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [set removeCharactersInString:@"!*'();:@&=+$,/?%#[]"];
    return [s stringByAddingPercentEncodingWithAllowedCharacters:set] ?: s;
}

@end
