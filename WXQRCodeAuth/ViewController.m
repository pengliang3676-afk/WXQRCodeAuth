//
//  ViewController.m
//  WXQRCodeAuth
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "WXAuthManager.h"

@interface ViewController ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIImageView *qrImageView;
@property (nonatomic, strong) UIButton *showButton;
@property (nonatomic, strong) UIButton *fixButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupUI];
    [self bindManager];
}

- (void)fixRootHideTapped {
    // 手动触发：执行改名并显示诊断报告
    NSString *report = [WXAuthManager applyRootHideBypass];
    [self showReport:report];
}

- (void)showReport:(NSString *)report {
    UIViewController *d = [UIViewController new];
    d.view.backgroundColor = [UIColor whiteColor];
    d.title = @"RootHide 修复诊断";

    UITextView *tv = [[UITextView alloc] initWithFrame:d.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.font = [UIFont fontWithName:@"Menlo" size:11];
    tv.text = report ?: @"(无报告)";
    tv.editable = NO;
    [d.view addSubview:tv];

    d.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(closeDiagnostic)];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:d];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)closeDiagnostic {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)setupUI {
    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;

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
    qr.layer.cornerRadius = 10;
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
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:19];
    btn.backgroundColor = [UIColor systemGreenColor];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 12;
    btn.contentEdgeInsets = UIEdgeInsetsMake(15, 48, 15, 48);
    [btn addTarget:self action:@selector(showCodeTapped) forControlEvents:UIControlEventTouchUpInside];
    btn.enabled = NO;
    btn.alpha = 0.4;
    [self.view addSubview:btn];
    self.showButton = btn;

    // 诊断版：RootHide 修复按钮（手动触发）
    UIButton *fixBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    fixBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [fixBtn setTitle:@"修复 RootHide（诊断）" forState:UIControlStateNormal];
    fixBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [fixBtn setTitleColor:[UIColor secondaryLabelColor] forState:UIControlStateNormal];
    [fixBtn addTarget:self action:@selector(fixRootHideTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:fixBtn];
    self.fixButton = fixBtn;

    [NSLayoutConstraint activateConstraints:@[
        [qr.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [qr.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-70],
        [qr.widthAnchor constraintEqualToConstant:270],
        [qr.heightAnchor constraintEqualToConstant:270],

        [spinner.centerXAnchor constraintEqualToAnchor:qr.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:qr.centerYAnchor],

        [statusLabel.bottomAnchor constraintEqualToAnchor:qr.topAnchor constant:-28],
        [statusLabel.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:28],
        [statusLabel.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-28],

        [btn.topAnchor constraintEqualToAnchor:qr.bottomAnchor constant:40],
        [btn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [btn.widthAnchor constraintGreaterThanOrEqualToConstant:200],

        [fixBtn.topAnchor constraintEqualToAnchor:btn.bottomAnchor constant:24],
        [fixBtn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
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
