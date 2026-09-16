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
@property (nonatomic, strong) UITextView *diagView;   // 临时诊断日志
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupUI];
    [self bindManager];
}

- (void)setupUI {
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;

    // 状态文字
    UILabel *statusLabel = [[UILabel alloc] init];
    statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    statusLabel.numberOfLines = 0;
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.font = [UIFont systemFontOfSize:15];
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
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    btn.backgroundColor = [UIColor systemGreenColor];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 10;
    btn.contentEdgeInsets = UIEdgeInsetsMake(12, 40, 12, 40);
    [btn addTarget:self action:@selector(showCodeTapped) forControlEvents:UIControlEventTouchUpInside];
    btn.enabled = NO;
    btn.alpha = 0.4;
    [self.view addSubview:btn];
    self.showButton = btn;

    // 诊断日志（临时排查用，可滚动小字）
    UITextView *diag = [[UITextView alloc] init];
    diag.translatesAutoresizingMaskIntoConstraints = NO;
    diag.editable = NO;
    diag.scrollEnabled = YES;
    diag.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    diag.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    diag.textColor = [UIColor colorWithRed:0.5 green:1.0 blue:0.6 alpha:1.0];
    diag.layer.cornerRadius = 6;
    diag.textContainerInset = UIEdgeInsetsMake(6, 6, 6, 6);
    diag.text = @"诊断日志：\n（扫码确认后，把这一屏截图发回）\n";
    [self.view addSubview:diag];
    self.diagView = diag;

    [NSLayoutConstraint activateConstraints:@[
        [statusLabel.topAnchor constraintEqualToAnchor:guide.topAnchor constant:14],
        [statusLabel.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:20],
        [statusLabel.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-20],

        [qr.topAnchor constraintEqualToAnchor:statusLabel.bottomAnchor constant:12],
        [qr.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [qr.widthAnchor constraintEqualToConstant:170],
        [qr.heightAnchor constraintEqualToConstant:170],

        [spinner.centerXAnchor constraintEqualToAnchor:qr.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:qr.centerYAnchor],

        [btn.topAnchor constraintEqualToAnchor:qr.bottomAnchor constant:14],
        [btn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [btn.widthAnchor constraintGreaterThanOrEqualToConstant:160],

        [diag.topAnchor constraintEqualToAnchor:btn.bottomAnchor constant:12],
        [diag.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:10],
        [diag.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-10],
        [diag.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-10],
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
            if (state == WXAuthStateReceived) {
                self.qrImageView.image = nil;
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
    m.onDiagnostic = ^(NSString *text) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.diagView.text = text;
            // 自动滚动到底部
            if (text.length > 0) {
                NSRange bottom = NSMakeRange(text.length - 1, 1);
                [self.diagView scrollRangeToVisible:bottom];
            }
        });
    };
}

- (void)refreshButtonForState:(WXAuthState)state {
    BOOL enabled = (state == WXAuthStateReceived ||
                    state == WXAuthStateExpired ||
                    state == WXAuthStateError);
    self.showButton.enabled = enabled;
    self.showButton.alpha = enabled ? 1.0 : 0.4;
    [self.showButton setTitle:@"显  码" forState:UIControlStateNormal];
}

- (void)showCodeTapped {
    self.qrImageView.image = nil;
    [[WXAuthManager shared] startShowCode];
}

@end
