//
//  ViewController.m
//  WXQRCodeAuth
//

#import "ViewController.h"
#import "WXAuthManager.h"

@interface ViewController ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIImageView *qrImageView;
@property (nonatomic, strong) UIButton *showButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"微信显码";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupUI];
    [self bindManager];
}

- (void)setupUI {
    // 状态文字
    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.numberOfLines = 0;
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.font = [UIFont systemFontOfSize:16];
    statusLabel.textColor = [UIColor secondaryLabelColor];
    statusLabel.text = @"等待微信授权跳转…";
    [self.view addSubview:statusLabel];
    self.statusLabel = statusLabel;

    // 二维码图片
    UIImageView *qr = [[UIImageView alloc] init];
    qr.translatesAutoresizingMaskIntoConstraints = NO;
    qr.contentMode = UIViewContentModeScaleAspectFit;
    qr.backgroundColor = [UIColor whiteColor];
    qr.layer.borderColor = [UIColor separatorColor].CGColor;
    qr.layer.borderWidth = 0.5;
    qr.layer.cornerRadius = 8;
    qr.clipsToBounds = YES;
    [self.view addSubview:qr];
    self.qrImageView = qr;

    // 加载菊花
    UIActivityIndicatorView *spinner =
        [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.hidesWhenStopped = YES;
    [self.qrImageView addSubview:spinner];
    self.spinner = spinner;

    // 显码按钮
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn setTitle:@"显  码" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    btn.backgroundColor = [UIColor systemGreenColor];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 10;
    btn.contentEdgeInsets = UIEdgeInsetsMake(14, 40, 14, 40);
    [btn addTarget:self action:@selector(showCodeTapped) forControlEvents:UIControlEventTouchUpInside];
    btn.enabled = NO;
    btn.alpha = 0.4;
    [self.view addSubview:btn];
    self.showButton = btn;

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [statusLabel.topAnchor constraintEqualToAnchor:guide.topAnchor constant:40],
        [statusLabel.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:24],
        [statusLabel.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-24],

        [qr.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [qr.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-30],
        [qr.widthAnchor constraintEqualToConstant:260],
        [qr.heightAnchor constraintEqualToConstant:260],

        [spinner.centerXAnchor constraintEqualToAnchor:qr.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:qr.centerYAnchor],

        [btn.topAnchor constraintEqualToAnchor:qr.bottomAnchor constant:36],
        [btn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [btn.widthAnchor constraintGreaterThanOrEqualToConstant:180],
    ]];
}

- (void)bindManager {
    WXAuthManager *m = [WXAuthManager shared];
    __weak typeof(self) weakSelf = self;
    m.onStateChange = ^(WXAuthState state, NSString *message) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = message;
            [self refreshButtonForState:state];
            if (state == WXAuthStateFetching) {
                [self.spinner startAnimating];
            } else {
                [self.spinner stopAnimating];
            }
        });
    };
    m.onQRCodeReady = ^(UIImage *image) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.qrImageView.image = image;
        });
    };
}

- (void)refreshButtonForState:(WXAuthState)state {
    BOOL canShow = (state == WXAuthStateReceived ||
                    state == WXAuthStateExpired ||
                    state == WXAuthStateError ||
                    state == WXAuthStateIdle);
    // 只有收到请求后才允许点显码；出错/过期时可重试
    if (state == WXAuthStateReceived || state == WXAuthStateExpired) {
        self.showButton.enabled = YES;
        self.showButton.alpha = 1.0;
        [self.showButton setTitle:@"显  码" forState:UIControlStateNormal];
    } else if (state == WXAuthStateWaitingScan ||
               state == WXAuthStateScanned ||
               state == WXAuthStateFetching) {
        self.showButton.enabled = NO;
        self.showButton.alpha = 0.4;
    } else if (state == WXAuthStateSuccess) {
        self.showButton.enabled = NO;
        self.showButton.alpha = 0.4;
    } else {
        self.showButton.enabled = NO;
        self.showButton.alpha = 0.4;
    }
}

- (void)showCodeTapped {
    self.qrImageView.image = nil;
    [[WXAuthManager shared] startShowCode];
}

@end
